#!/usr/bin/env node
/**
 * Diagnóstico SOMENTE LEITURA de vínculos e autorizações (etapa 2).
 *
 * Não grava, não corrige e não migra nada. Lista o que ficou incompatível
 * com a regra de autorização explícita do responsável:
 *
 *  - concessões (authorized_professionals) inválidas, antigas, automáticas
 *    (familyAppointment), vencidas ou revogadas; concessão cujo autor não é o
 *    titular; concessão em criança sem child_registry ou de outro titular;
 *  - consultas sem origem registrada pelo servidor (`origin`), com
 *    `requestedBy` sem prova (registro antigo), titular diferente do dono da
 *    criança, sem criança, ou com id provisório `pending_`;
 *  - registros clínicos com id de criança provisório ou sem registro;
 *  - crianças sem child_registry ou com dono divergente;
 *  - vínculos de clínica com as duas pontas divergentes ou papel clínico em
 *    conta que não é de profissional.
 *
 * Saída: JSON com contagens e caminhos dos documentos (só ids; nenhum nome,
 * e-mail ou dado clínico).
 *
 * Uso:
 *   Emulador:  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *              node tools/diagnostics/child_access_diagnostic.js --project demo-pediatria360
 *   Projeto:   GOOGLE_APPLICATION_CREDENTIALS=... \
 *              node tools/diagnostics/child_access_diagnostic.js --project <id> --confirm-read-only
 *   Opcional:  --out relatorio.json
 *
 * `requestedBy` de registro antigo NÃO é prova de pedido da família, e nada
 * aqui transforma concessão antiga em consentimento novo: o resultado só
 * orienta o pedido de reautorização ao responsável.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const admin = require(require.resolve("firebase-admin", {
  paths: [path.join(__dirname, "..", "..", "functions", "node_modules"), __dirname],
}));

const VALID_SOURCES = new Set(["guardian", "guardianInvite"]);
const VALID_SCOPES = new Set(["summary", "chartWrite"]);
const SERVER_ORIGINS = new Set(["familyBooking", "clinicIntake", "familyRequest", "clinicStaff"]);
const CLINICAL_ROLES = new Set(["physician", "healthProfessional", "nursing"]);
const CHILD_RECORD_COLLECTIONS = [
  ["encounters", "patientId"],
  ["clinical_documents", "patientId"],
  ["visit_summaries", "patientId"],
  ["lab_results", "patientId"],
  ["triage_records", "childId"],
  ["development_records", "childId"],
  ["supplement_prescriptions", "childId"],
  ["supplement_lab_results", "childId"],
  ["supplement_timeline", "childId"],
  ["supplement_clinical_notes", "childId"],
  ["supplement_ai_drafts", "childId"],
];

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

function main() {
  const project = arg("--project");
  const emulator = !!process.env.FIRESTORE_EMULATOR_HOST;
  if (!project) {
    console.error("Informe --project.");
    process.exit(2);
  }
  if (!emulator && !process.argv.includes("--confirm-read-only")) {
    console.error(
      "Fora do emulador é preciso --confirm-read-only (o script só lê, mas o alvo precisa ser explícito)."
    );
    process.exit(2);
  }
  admin.initializeApp({ projectId: project });
  return run(admin.firestore(), { project, emulator });
}

const toMs = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : null);

async function run(db, meta) {
  const now = Date.now();
  const report = {
    meta: { ...meta, generatedAt: new Date(now).toISOString(), readOnly: true },
    counts: {},
    items: {},
  };
  const add = (key, item) => {
    (report.items[key] = report.items[key] || []).push(item);
    report.counts[key] = (report.counts[key] || 0) + 1;
  };

  // child_registry: dono de cada criança.
  const registry = new Map();
  for (const d of (await db.collection("child_registry").get()).docs) {
    registry.set(d.id, d.get("ownerUid") || null);
  }

  // Crianças cadastradas.
  for (const d of (await db.collectionGroup("children").get()).docs) {
    const owner = d.ref.parent.parent && d.ref.parent.parent.id;
    if (!d.ref.parent.parent || d.ref.parent.parent.parent.id !== "users") continue;
    if (!registry.has(d.id)) add("criancaSemRegistro", { path: d.ref.path });
    else if (registry.get(d.id) !== owner) add("criancaComDonoDivergente", { path: d.ref.path });
  }

  // Concessões.
  for (const d of (await db.collectionGroup("authorized_professionals").get()).docs) {
    const childRef = d.ref.parent.parent;
    const owner = childRef && childRef.parent.parent && childRef.parent.parent.id;
    const childId = childRef && childRef.id;
    const g = d.data();
    const scopes = Array.isArray(g.scopes) ? g.scopes : null;
    const exp = toMs(g.expiresAt);
    const base = { path: d.ref.path, source: g.source || null };

    if (g.source === "familyAppointment") add("concessaoAutomaticaPorConsulta", base);
    else if (!VALID_SOURCES.has(g.source)) add("concessaoSemOrigemValida", base);
    if (!scopes || scopes.length === 0 || scopes.some((s) => !VALID_SCOPES.has(s))) {
      add("concessaoSemEscopoValido", base);
    } else if (scopes.includes("chartWrite") && !scopes.includes("summary")) {
      add("concessaoProntuarioSemResumo", base);
    }
    if (exp == null) add("concessaoSemValidade", base);
    else if (toMs(g.grantedAt) != null && exp - toMs(g.grantedAt) > 366 * 864e5) add("concessaoValidadeAcimaDoLimite", base);
    if (g.revokedAt) add("concessaoRevogada", base);
    else if (exp != null && exp <= now) add("concessaoVencida", base);
    if (g.authorizedBy && g.authorizedBy !== owner) add("concessaoAutorNaoTitular", base);
    if (!registry.has(childId)) add("concessaoEmCriancaSemRegistro", base);
    else if (registry.get(childId) !== owner) add("concessaoEmCriancaDeOutroTitular", base);
  }

  // Consultas.
  for (const d of (await db.collection("appointments").get()).docs) {
    const a = d.data();
    const base = { path: d.ref.path };
    if (!a.origin) add("consultaSemOrigemRegistrada", base);
    else if (!SERVER_ORIGINS.has(a.origin)) add("consultaComOrigemDesconhecida", { ...base, origin: a.origin });
    if (a.requestedBy && !a.origin) add("consultaComRequestedBySemProva", base);
    if (!a.childId) add("consultaSemCrianca", base);
    else if (String(a.childId).startsWith("pending_")) add("consultaComIdProvisorio", base);
    else if (!registry.has(a.childId)) add("consultaCriancaSemRegistro", base);
    else if (registry.get(a.childId) !== a.patientId) add("consultaTitularDivergente", base);
  }

  // Registros clínicos com id de criança provisório ou sem registro.
  for (const [col, field] of CHILD_RECORD_COLLECTIONS) {
    for (const d of (await db.collection(col).get()).docs) {
      const childId = d.get(field);
      if (typeof childId !== "string" || !childId) continue;
      if (childId.startsWith("pending_")) add("registroClinicoComIdProvisorio", { path: d.ref.path });
      else if (!registry.has(childId)) add("registroClinicoCriancaSemRegistro", { path: d.ref.path });
    }
  }

  // Vínculos de clínica: espelho do usuário x documento da clínica.
  const users = new Map();
  for (const d of (await db.collection("users").get()).docs) {
    users.set(d.id, { role: d.get("role") || null, verified: d.get("professionalVerified") === true });
  }
  for (const d of (await db.collectionGroup("clinic_memberships").get()).docs) {
    const uid = d.ref.parent.parent && d.ref.parent.parent.id;
    const clinicId = d.id;
    const m = d.data();
    const sideId = typeof m.id === "string" && m.id ? m.id : uid;
    const side = await db.collection("clinics").doc(clinicId).collection("memberships").doc(sideId).get();
    const base = { path: d.ref.path, clinicSide: side.ref.path };
    if (!side.exists) { add("vinculoSemDocumentoNaClinica", base); continue; }
    const s = side.data();
    if (s.userId !== uid || m.userId !== uid || m.clinicId !== clinicId) add("vinculoComIdsDivergentes", base);
    if (!!s.active !== !!m.active) add("vinculoAtivoDivergente", base);
    if (s.role !== m.role) add("vinculoPapelDivergente", base);
    const u = users.get(uid);
    if (s.active && CLINICAL_ROLES.has(s.role) && (!u || u.role !== "professional")) {
      add("papelClinicoEmContaNaoProfissional", base);
    }
    if (s.active && CLINICAL_ROLES.has(s.role) && u && u.role === "professional" && !u.verified) {
      add("papelClinicoSemVerificacao", base);
    }
  }

  const out = arg("--out");
  const json = JSON.stringify(report, null, 2);
  if (out) fs.writeFileSync(out, json);
  console.log(JSON.stringify(report.counts, null, 2));
  return report;
}

module.exports = { run };

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((e) => {
      console.error("Falha no diagnóstico:", e && e.message ? e.message : e);
      process.exit(1);
    });
}
