/**
 * Etapa 3 (26/10/2026): gestão integrada — agenda, CRM, anamnese,
 * automações, financeiro, marketing e Central de IA.
 *
 * - Tudo que muda agenda, fila de mensagens, financeiro e CRM é gravado
 *   pelas Functions; o aparelho só lê o que o papel permite.
 * - Recepção organiza agenda e CRM sem ler conteúdo clínico (anamnese).
 * - Gestão não ganha acesso clínico por ser gestão.
 * - Travas de agenda, eventos de provedores, contadores e propostas do
 *   assistente ficam fora do alcance do app.
 * - Preferências de comunicação e consentimentos de marketing são do
 *   servidor (com histórico).
 *
 * Dados fictícios; roda só no emulador.
 */
const path = require("path");
const { readFileSync } = require("fs");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  Timestamp,
} = require("firebase/firestore");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

const PROJECT_ID = "pediatria360-rules-test";

const ANA = "uid_ana";
const BRUNO = "uid_bruno";
const DRA = "uid_dra";
const OUTRO_PROF = "uid_outro_prof";
const REC = "uid_recepcao";
const FIN = "uid_financeiro";
const GESTOR = "uid_gestor";
const OUTRA = "uid_outra_clinica";

const CLIN = "clinica-dra";
const CLIN_B = "clinica-b";
const DIA = 24 * 60 * 60 * 1000;

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: readFileSync(path.resolve(__dirname, "../../storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

function as(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

async function vinculoClinica(db, clinicId, uid, role, active = true) {
  await setDoc(doc(db, "clinics", clinicId, "memberships", uid), {
    id: uid, userId: uid, clinicId, role, active,
  });
  await setDoc(doc(db, "users", uid, "clinic_memberships", clinicId), {
    id: uid, userId: uid, clinicId, role, active,
  });
}

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    const conta = (name) => ({ name, role: "parent", plan: "free", xp: 0 });
    const pro = (name) => ({ name, role: "professional", professionalVerified: true, plan: "pro", xp: 0 });
    await setDoc(doc(db, "users", ANA), conta("Ana (ficticia)"));
    await setDoc(doc(db, "users", BRUNO), conta("Bruno (ficticio)"));
    await setDoc(doc(db, "users", DRA), pro("Dra. Exemplo"));
    await setDoc(doc(db, "users", OUTRO_PROF), pro("Outro Prof (ficticio)"));
    await setDoc(doc(db, "users", REC), conta("Recepcao (ficticia)"));
    await setDoc(doc(db, "users", FIN), conta("Financeiro (ficticio)"));
    await setDoc(doc(db, "users", GESTOR), conta("Gestao (ficticia)"));
    await setDoc(doc(db, "users", OUTRA), conta("Outra clinica (ficticia)"));

    await setDoc(doc(db, "clinics", CLIN), { name: "Clinica da Dra", ownerUserId: GESTOR });
    await vinculoClinica(db, CLIN, GESTOR, "clinicAdmin");
    await vinculoClinica(db, CLIN, DRA, "physician");
    await vinculoClinica(db, CLIN, OUTRO_PROF, "physician");
    await vinculoClinica(db, CLIN, REC, "receptionist");
    await vinculoClinica(db, CLIN, FIN, "finance");
    await setDoc(doc(db, "clinics", CLIN_B), { name: "Clinica B", ownerUserId: OUTRA });
    await vinculoClinica(db, CLIN_B, OUTRA, "clinicAdmin");

    const c = (sub, id, data) => setDoc(doc(db, "clinics", CLIN, sub, id), data);
    await c("settings", "scheduling", { policy: { minLeadMinutes: 120 } });
    await c("professional_schedules", DRA, { weekly: { "1": ["08:00-12:00"] } });
    await c("services", "consulta", { name: "Consulta", appointmentType: "consulta", durationMinutes: 30, priceCents: 25000, active: true });
    await c("waitlist", "w1", { patientId: ANA, childId: "filha", professionalId: DRA, status: "waiting" });
    await c("automations", "appointmentReminder", { enabled: true });
    await c("automation_runs", "r1", { jobId: "j1", result: "sent" });
    await c("whatsapp_inbox", "i1", { from: "telefone mascarado", status: "open" });
    await c("anamnesis_templates", "t1", { name: "Modelo", version: 1 });
    await c("crm_contacts", `${ANA}_filha`, { stage: "agendado", ownerUid: ANA, childId: "filha" });
    await setDoc(doc(db, "clinics", CLIN, "crm_contacts", `${ANA}_filha`, "notes", "n1"), { text: "Prefere manhã (administrativo)" });
    await c("crm_tasks", "t1", { title: "Ligar para confirmar", status: "open" });
    await c("crm_merge_requests", "m1", { status: "pending" });
    await c("campaigns", "cmp1", { status: "draft", title: "Campanha fictícia" });
    await c("ai_hub_log", "l1", { intent: "noShows", sufficient: true });

    await setDoc(doc(db, "schedule_locks", "prof_x_1"), { appointmentId: "a1" });
    await setDoc(doc(db, "schedule_holds", "h1"), { status: "offered" });
    await setDoc(doc(db, "payment_events", "e1"), { type: "paid" });
    await setDoc(doc(db, "whatsapp_events", "e1"), { status: "delivered" });
    await setDoc(doc(db, "usage_counters", "c1"), { aiRequests: 1 });
    await setDoc(doc(db, "assistant_proposals", "p1"), { uid: GESTOR, action: "book" });
    await setDoc(doc(db, "marketing_suppression", ANA), { reason: "optOut" });

    await setDoc(doc(db, "message_queue", "q1"), {
      clinicId: CLIN, recipientUid: ANA, kind: "appointmentReminder", channel: "inApp", status: "queued",
    });
    await setDoc(doc(db, "message_queue", "q2"), {
      clinicId: CLIN_B, recipientUid: BRUNO, kind: "appointmentReminder", channel: "inApp", status: "queued",
    });
    await setDoc(doc(db, "appointment_series", "s1"), { clinicId: CLIN, professionalId: DRA });
    await setDoc(doc(db, "finance_operations", "op1"), { clinicId: CLIN, type: "payment", amountCents: 25000 });

    await setDoc(doc(db, "anamnesis_responses", "rascunho"), {
      ownerUid: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN, status: "draft",
    });
    await setDoc(doc(db, "anamnesis_responses", "enviada"), {
      ownerUid: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN, status: "submitted",
      submittedAt: Timestamp.fromMillis(Date.now() - DIA),
    });
    await setDoc(doc(db, "anamnesis_responses", "enviada", "revisions", "1"), { answers: {} });
  });
});

describe("configuração da agenda e serviços", () => {
  test("membros leem configuração; ninguém grava pelo app", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "settings", "scheduling")));
    await assertFails(getDoc(doc(as(ANA), "clinics", CLIN, "settings", "scheduling")));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "settings", "scheduling"), { policy: {} }));
  });

  test("horários do profissional: equipe da agenda lê, financeiro e família não", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "professional_schedules", DRA)));
    await assertFails(getDoc(doc(as(FIN), "clinics", CLIN, "professional_schedules", DRA)));
    await assertFails(getDoc(doc(as(ANA), "clinics", CLIN, "professional_schedules", DRA)));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "professional_schedules", DRA), { weekly: {} }));
  });

  test("gestão cadastra serviço com formato válido; recepção não", async () => {
    const ok = { name: "Retorno", appointmentType: "retorno", durationMinutes: 20, priceCents: 0, active: true };
    await assertSucceeds(setDoc(doc(as(GESTOR), "clinics", CLIN, "services", "retorno"), ok));
    await assertFails(setDoc(doc(as(REC), "clinics", CLIN, "services", "retorno2"), ok));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "services", "ruim"), { ...ok, durationMinutes: 7 }));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "services", "ruim2"), { ...ok, priceCents: -1 }));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "services", "ruim3"), { ...ok, diagnosis: "x" }));
    await assertFails(setDoc(doc(as(OUTRA), "clinics", CLIN, "services", "invasor"), ok));
  });
});

describe("travas e controle interno do servidor", () => {
  test.each([
    ["schedule_locks", "prof_x_1"],
    ["schedule_holds", "h1"],
    ["payment_events", "e1"],
    ["whatsapp_events", "e1"],
    ["usage_counters", "c1"],
    ["assistant_proposals", "p1"],
    ["marketing_suppression", ANA],
  ])("%s: ninguém lê nem grava pelo app", async (col, id) => {
    for (const uid of [ANA, REC, GESTOR, DRA]) {
      await assertFails(getDoc(doc(as(uid), col, id)));
      await assertFails(setDoc(doc(as(uid), col, `${id}-novo`), { x: 1 }));
    }
  });
});

describe("lista de espera e fila de mensagens", () => {
  test("família vê só a própria entrada; recepção vê a da clínica", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "clinics", CLIN, "waitlist", "w1")));
    await assertFails(getDoc(doc(as(BRUNO), "clinics", CLIN, "waitlist", "w1")));
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "waitlist", "w1")));
    await assertFails(setDoc(doc(as(ANA), "clinics", CLIN, "waitlist", "w2"), { patientId: ANA, status: "waiting" }));
  });

  test("mensagem: destinatário e recepção da clínica leem; ninguém grava", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "message_queue", "q1")));
    await assertSucceeds(getDoc(doc(as(REC), "message_queue", "q1")));
    await assertFails(getDoc(doc(as(BRUNO), "message_queue", "q1")));
    await assertFails(getDoc(doc(as(REC), "message_queue", "q2")));
    await assertFails(updateDoc(doc(as(REC), "message_queue", "q1"), { status: "sent" }));
    await assertFails(updateDoc(doc(as(ANA), "message_queue", "q1"), { status: "cancelled" }));
  });

  test("automações e caixa do WhatsApp: recepção/gestão leem, ninguém grava", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "automations", "appointmentReminder")));
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "whatsapp_inbox", "i1")));
    await assertFails(getDoc(doc(as(DRA), "clinics", CLIN, "whatsapp_inbox", "i1")));
    await assertFails(getDoc(doc(as(REC), "clinics", CLIN, "automation_runs", "r1")));
    await assertSucceeds(getDoc(doc(as(GESTOR), "clinics", CLIN, "automation_runs", "r1")));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "automations", "appointmentReminder"), { enabled: false }));
    await assertFails(getDoc(doc(as(OUTRA), "clinics", CLIN, "automations", "appointmentReminder")));
  });
});

describe("CRM sem conteúdo clínico", () => {
  test("recepção e gestão leem contato, notas e tarefas; profissional e financeiro não", async () => {
    const contato = doc(as(REC), "clinics", CLIN, "crm_contacts", `${ANA}_filha`);
    await assertSucceeds(getDoc(contato));
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "crm_contacts", `${ANA}_filha`, "notes", "n1")));
    await assertSucceeds(getDoc(doc(as(GESTOR), "clinics", CLIN, "crm_tasks", "t1")));
    await assertFails(getDoc(doc(as(FIN), "clinics", CLIN, "crm_contacts", `${ANA}_filha`)));
    await assertFails(getDoc(doc(as(ANA), "clinics", CLIN, "crm_contacts", `${ANA}_filha`)));
    await assertFails(getDoc(doc(as(OUTRA), "clinics", CLIN, "crm_contacts", `${ANA}_filha`)));
  });

  test("ninguém grava CRM, notas ou mesclagem direto pelo app", async () => {
    await assertFails(updateDoc(doc(as(REC), "clinics", CLIN, "crm_contacts", `${ANA}_filha`), { stage: "atendido" }));
    await assertFails(setDoc(doc(as(REC), "clinics", CLIN, "crm_contacts", `${ANA}_filha`, "notes", "n2"), { text: "x" }));
    await assertFails(updateDoc(doc(as(GESTOR), "clinics", CLIN, "crm_merge_requests", "m1"), { status: "approved" }));
  });

  test("vínculo inativo perde a leitura (revogação)", async () => {
    await seed((db) => vinculoClinica(db, CLIN, REC, "receptionist", false));
    await assertFails(getDoc(doc(as(REC), "clinics", CLIN, "crm_contacts", `${ANA}_filha`)));
    await assertFails(getDoc(doc(as(REC), "message_queue", "q1")));
  });
});

describe("anamnese", () => {
  test("família lê as próprias (rascunho e enviada)", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "anamnesis_responses", "rascunho")));
    await assertSucceeds(getDoc(doc(as(ANA), "anamnesis_responses", "enviada")));
    await assertFails(getDoc(doc(as(BRUNO), "anamnesis_responses", "enviada")));
  });

  test("profissional da consulta lê só a enviada, nunca rascunho", async () => {
    await assertSucceeds(getDoc(doc(as(DRA), "anamnesis_responses", "enviada")));
    await assertFails(getDoc(doc(as(DRA), "anamnesis_responses", "rascunho")));
    await assertFails(getDoc(doc(as(OUTRO_PROF), "anamnesis_responses", "enviada")));
  });

  test("recepção, financeiro e gestão NÃO leem respostas", async () => {
    for (const uid of [REC, FIN, GESTOR]) {
      await assertFails(getDoc(doc(as(uid), "anamnesis_responses", "enviada")));
    }
  });

  test("ninguém grava ou sobrescreve resposta e versões pelo app", async () => {
    await assertFails(updateDoc(doc(as(ANA), "anamnesis_responses", "enviada"), { status: "draft" }));
    await assertFails(setDoc(doc(as(ANA), "anamnesis_responses", "nova"), { ownerUid: ANA, status: "submitted" }));
    await assertFails(getDoc(doc(as(ANA), "anamnesis_responses", "enviada", "revisions", "1")));
    await assertFails(setDoc(doc(as(DRA), "anamnesis_responses", "enviada", "revisions", "2"), { answers: {} }));
  });

  test("modelos: membros leem, ninguém grava pelo app", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "clinics", CLIN, "anamnesis_templates", "t1")));
    await assertFails(setDoc(doc(as(GESTOR), "clinics", CLIN, "anamnesis_templates", "t2"), { name: "x" }));
  });
});

describe("financeiro, marketing e Central de IA", () => {
  test("operações financeiras: só gestão e financeiro leem; ninguém grava", async () => {
    await assertSucceeds(getDoc(doc(as(FIN), "finance_operations", "op1")));
    await assertSucceeds(getDoc(doc(as(GESTOR), "finance_operations", "op1")));
    await assertFails(getDoc(doc(as(REC), "finance_operations", "op1")));
    await assertFails(getDoc(doc(as(DRA), "finance_operations", "op1")));
    await assertFails(getDoc(doc(as(OUTRA), "finance_operations", "op1")));
    await assertFails(setDoc(doc(as(FIN), "finance_operations", "op2"), { clinicId: CLIN, amountCents: 1 }));
  });

  test("campanhas e registro da Central de IA: só gestão lê; ninguém grava", async () => {
    await assertSucceeds(getDoc(doc(as(GESTOR), "clinics", CLIN, "campaigns", "cmp1")));
    await assertFails(getDoc(doc(as(REC), "clinics", CLIN, "campaigns", "cmp1")));
    await assertFails(updateDoc(doc(as(GESTOR), "clinics", CLIN, "campaigns", "cmp1"), { status: "approved" }));
    await assertSucceeds(getDoc(doc(as(GESTOR), "clinics", CLIN, "ai_hub_log", "l1")));
    await assertFails(getDoc(doc(as(FIN), "clinics", CLIN, "ai_hub_log", "l1")));
    await assertFails(getDoc(doc(as(OUTRA), "clinics", CLIN, "ai_hub_log", "l1")));
  });

  test("série de consultas: recepção/gestão leem, ninguém grava", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "appointment_series", "s1")));
    await assertFails(getDoc(doc(as(ANA), "appointment_series", "s1")));
    await assertFails(setDoc(doc(as(REC), "appointment_series", "s2"), { clinicId: CLIN }));
  });
});

describe("anexos da anamnese (Storage)", () => {
  const pdf = { contentType: "application/pdf" };
  const bytes = new Uint8Array([37, 80, 68, 70]);
  const st = (uid) => testEnv.authenticatedContext(uid).storage();

  test("titular anexa só em rascunho próprio e não sobrescreve", async () => {
    await assertSucceeds(uploadBytes(ref(st(ANA), `anamnesis/${ANA}/rascunho/exame.pdf`), bytes, pdf));
    await assertFails(uploadBytes(ref(st(ANA), `anamnesis/${ANA}/rascunho/exame.pdf`), bytes, pdf));
    await assertFails(uploadBytes(ref(st(ANA), `anamnesis/${ANA}/enviada/novo.pdf`), bytes, pdf));
    await assertFails(uploadBytes(ref(st(BRUNO), `anamnesis/${BRUNO}/rascunho/x.pdf`), bytes, pdf));
    await assertFails(
      uploadBytes(ref(st(ANA), `anamnesis/${ANA}/rascunho/script.txt`), bytes, { contentType: "text/plain" })
    );
  });

  test("profissional lê anexo só de resposta enviada; recepção nunca", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), `anamnesis/${ANA}/enviada/exame.pdf`), bytes, pdf);
      await uploadBytes(ref(ctx.storage(), `anamnesis/${ANA}/rascunho/foto.pdf`), bytes, pdf);
    });
    await assertSucceeds(getBytes(ref(st(ANA), `anamnesis/${ANA}/enviada/exame.pdf`)));
    await assertSucceeds(getBytes(ref(st(DRA), `anamnesis/${ANA}/enviada/exame.pdf`)));
    await assertFails(getBytes(ref(st(DRA), `anamnesis/${ANA}/rascunho/foto.pdf`)));
    await assertFails(getBytes(ref(st(REC), `anamnesis/${ANA}/enviada/exame.pdf`)));
    await assertFails(getBytes(ref(st(OUTRO_PROF), `anamnesis/${ANA}/enviada/exame.pdf`)));
  });
});

describe("preferências e consentimentos de comunicação", () => {
  test("titular NÃO grava communicationPrefs nem lastMarketingAt direto", async () => {
    await assertFails(updateDoc(doc(as(ANA), "users", ANA), { communicationPrefs: { marketing: true } }));
    await assertFails(updateDoc(doc(as(ANA), "users", ANA), { lastMarketingAt: Timestamp.now() }));
  });

  test("histórico de consentimento: titular lê, ninguém grava pelo app", async () => {
    await seed((db) => setDoc(doc(db, "users", ANA, "communication_consents", "c1"), { marketing: false }));
    await assertSucceeds(getDoc(doc(as(ANA), "users", ANA, "communication_consents", "c1")));
    await assertFails(getDoc(doc(as(GESTOR), "users", ANA, "communication_consents", "c1")));
    await assertFails(setDoc(doc(as(ANA), "users", ANA, "communication_consents", "c2"), { marketing: true }));
  });
});
