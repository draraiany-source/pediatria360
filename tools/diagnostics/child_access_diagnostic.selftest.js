#!/usr/bin/env node
/**
 * Autoteste do diagnóstico, só no emulador (FIRESTORE_EMULATOR_HOST).
 * Semeia dados fictícios com os casos antigos, roda o diagnóstico e confere
 * as contagens e que nenhum documento foi alterado.
 *
 *   firebase emulators:exec --only firestore --project demo-pediatria360 \
 *     "node tools/diagnostics/child_access_diagnostic.selftest.js"
 */
"use strict";

const path = require("path");
const admin = require(require.resolve("firebase-admin", {
  paths: [path.join(__dirname, "..", "..", "functions", "node_modules"), __dirname],
}));
const { run } = require("./child_access_diagnostic");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("Só roda no emulador.");
  process.exit(2);
}

admin.initializeApp({ projectId: "demo-pediatria360" });
const db = admin.firestore();
const T = admin.firestore.Timestamp;
const DIA = 864e5;

async function seed() {
  const set = (p, d) => db.doc(p).set(d);
  await set("users/ana", { role: "parent" });
  await set("users/bruno", { role: "parent" });
  await set("users/dra", { role: "professional", professionalVerified: true });
  await set("users/rec", { role: "parent" });
  await set("child_registry/filha", { ownerUid: "ana" });
  await set("child_registry/filho", { ownerUid: "bruno" });
  await set("users/ana/children/filha", { name: "Ficticia" });
  await set("users/bruno/children/filho", { name: "Ficticio" });
  await set("users/ana/children/sem-registro", { name: "Ficticia 2" });

  const g = (extra) => ({
    scopes: ["summary"], source: "guardian", authorizedBy: "ana",
    grantedAt: T.fromMillis(Date.now() - DIA), expiresAt: T.fromMillis(Date.now() + 30 * DIA),
    revokedAt: null, ...extra,
  });
  const ap = "users/ana/children/filha/authorized_professionals/";
  await set(ap + "valida", g());
  await set(ap + "automatica", g({ source: "familyAppointment", authorizedBy: "dra" }));
  await set(ap + "antiga", { grantedAt: T.now() });
  await set(ap + "vencida", g({ expiresAt: T.fromMillis(Date.now() - DIA) }));
  await set(ap + "revogada", g({ revokedAt: T.now() }));
  await set("users/ana/children/sem-registro/authorized_professionals/dra", g());

  const a = (extra) => ({ patientId: "ana", childId: "filha", professionalId: "dra", status: "confirmed", ...extra });
  await set("appointments/ok", a({ origin: "clinicIntake" }));
  await set("appointments/sem-origem", a({}));
  await set("appointments/requested-by-antigo", a({ requestedBy: "ana" }));
  await set("appointments/titular-errado", a({ origin: "clinicStaff", patientId: "bruno" }));
  await set("appointments/provisorio", a({ origin: "clinicStaff", childId: "pending_123" }));

  await set("encounters/e-provisorio", { patientId: "pending_123", professionalId: "dra" });
  await set("supplement_clinical_notes/n1", { childId: "pending_patient", professionalId: "dra" });
  await set("encounters/e-ok", { patientId: "filha", professionalId: "dra" });

  const m = (uid, role, extra = {}) => ({ id: uid, userId: uid, clinicId: "c1", role, active: true, ...extra });
  await set("clinics/c1", { name: "Clinica Ficticia" });
  await set("clinics/c1/memberships/dra", m("dra", "physician"));
  await set("users/dra/clinic_memberships/c1", m("dra", "physician"));
  await set("clinics/c1/memberships/rec", m("rec", "physician"));
  await set("users/rec/clinic_memberships/c1", m("rec", "receptionist"));
  await set("users/bruno/clinic_memberships/c1", m("bruno", "finance"));
}

async function snapshotAll() {
  const out = {};
  async function walk(ref) {
    for (const c of await ref.listCollections()) {
      for (const d of (await c.get()).docs) {
        out[d.ref.path] = JSON.stringify(d.data());
        await walk(d.ref);
      }
    }
  }
  for (const c of await db.listCollections()) {
    for (const d of (await c.get()).docs) {
      out[d.ref.path] = JSON.stringify(d.data());
      await walk(d.ref);
    }
  }
  return out;
}

(async () => {
  await seed();
  const before = await snapshotAll();
  const report = await run(db, { project: "demo-pediatria360", emulator: true });
  const after = await snapshotAll();

  const expected = {
    criancaSemRegistro: 1,
    concessaoAutomaticaPorConsulta: 1,
    concessaoSemOrigemValida: 1,
    concessaoSemEscopoValido: 1,
    concessaoSemValidade: 1,
    concessaoVencida: 1,
    concessaoRevogada: 1,
    concessaoAutorNaoTitular: 1,
    concessaoEmCriancaSemRegistro: 1,
    consultaSemOrigemRegistrada: 2,
    consultaComRequestedBySemProva: 1,
    consultaTitularDivergente: 1,
    consultaComIdProvisorio: 1,
    registroClinicoComIdProvisorio: 2,
    vinculoPapelDivergente: 1,
    papelClinicoEmContaNaoProfissional: 1,
    vinculoSemDocumentoNaClinica: 1,
  };
  let fail = 0;
  for (const [k, v] of Object.entries(expected)) {
    const got = report.counts[k] || 0;
    const ok = got === v;
    if (!ok) fail++;
    console.log((ok ? "OK    " : "DIVERG") + " " + k + " esperado=" + v + " obtido=" + got);
  }
  for (const k of Object.keys(report.counts)) {
    if (!(k in expected)) {
      fail++;
      console.log("DIVERG contagem inesperada " + k + "=" + report.counts[k]);
    }
  }
  const unchanged = JSON.stringify(before) === JSON.stringify(after);
  console.log((unchanged ? "OK    " : "DIVERG") + " nenhum documento alterado (" + Object.keys(after).length + " documentos)");
  if (!unchanged) fail++;
  console.log("divergencias " + fail);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
