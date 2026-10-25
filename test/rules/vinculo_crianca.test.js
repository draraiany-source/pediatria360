/**
 * Vínculo profissional–criança (etapa 1 da correção de 25/10/2026).
 *
 * Cenário da auditoria: um profissional verificado, sem nenhuma relação com a
 * família, cria a própria clínica, marca uma consulta para a criança de
 * outra família e usa essa consulta para abrir o cadastro e escrever no
 * prontuário. Ser verificado, ser dono de clínica, conhecer os ids ou criar
 * uma consulta não pode bastar.
 *
 * Política testada aqui:
 * - A concessão (users/{dono}/children/{c}/authorized_professionals/{prof})
 *   tem escopo (`summary` lê o cadastro; `chartWrite` grava no prontuário),
 *   validade (`expiresAt`) e revogação (`revokedAt`). Concessão antiga, sem
 *   escopo ou sem validade, não vale.
 * - Só o responsável titular grava a concessão pelo app; a Function
 *   grantChildSummaryAccess grava a partir de consulta pedida pela família.
 * - Registros clínicos exigem `chartWrite` ativo para a criança.
 * - Ids de criança, responsável, profissional e clínica de uma consulta não
 *   mudam pelo app.
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
  deleteDoc,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");

const PROJECT_ID = "pediatria360-rules-test";

const ANA = "uid_ana";             // responsável titular da "filha"
const BRUNO = "uid_bruno";         // outra família
const DRA = "uid_dra";             // profissional verificada, autorizada
const INVASOR = "uid_invasor";     // profissional verificado, sem vínculo
const REC = "uid_recepcao";        // recepção da clínica da Dra
const FIN = "uid_financeiro";      // financeiro da clínica da Dra
const OUTRA = "uid_outra_clinica"; // gestão de outra clínica

const CLIN = "clinica-dra";
const CLIN_B = "clinica-b";
const CLIN_INV = "clinica-invasora";

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

async function vinculoClinica(db, clinicId, uid, role) {
  await setDoc(doc(db, "clinics", clinicId, "memberships", uid), {
    id: uid, userId: uid, clinicId, role, active: true,
  });
  await setDoc(doc(db, "users", uid, "clinic_memberships", clinicId), {
    id: uid, userId: uid, clinicId, role, active: true,
  });
}

function grantDoc(scopes, { expiresInDays = 30, revoked = false, clinicId = null } = {}) {
  return {
    scopes,
    source: "guardian",
    authorizedBy: ANA,
    grantedAt: Timestamp.fromMillis(Date.now() - DIA),
    expiresAt: Timestamp.fromMillis(Date.now() + expiresInDays * DIA),
    revokedAt: revoked ? Timestamp.fromMillis(Date.now() - 1000) : null,
    clinicId,
  };
}

async function conceder(profUid, scopes, opts) {
  await seed((db) =>
    setDoc(
      doc(db, "users", ANA, "children", "filha", "authorized_professionals", profUid),
      grantDoc(scopes, opts)
    )
  );
}

function cadastro(uid) {
  return doc(as(uid), "users", ANA, "children", "filha");
}

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    const pro = (name) => ({ name, role: "professional", professionalVerified: true, plan: "pro", xp: 0 });
    await setDoc(doc(db, "users", ANA), { name: "Ana (ficticia)", role: "parent", plan: "free", xp: 0 });
    await setDoc(doc(db, "users", BRUNO), { name: "Bruno (ficticio)", role: "parent", plan: "free", xp: 0 });
    await setDoc(doc(db, "users", DRA), pro("Dra. Exemplo"));
    await setDoc(doc(db, "users", INVASOR), pro("Invasor (ficticio)"));
    // Recepção e financeiro também como "profissional verificado": é o caso
    // mais permissivo que existe hoje, e mesmo assim não abre prontuário.
    await setDoc(doc(db, "users", REC), pro("Recepcao (ficticia)"));
    await setDoc(doc(db, "users", FIN), pro("Financeiro (ficticio)"));
    await setDoc(doc(db, "users", OUTRA), pro("Outra clinica (ficticia)"));

    await setDoc(doc(db, "users", ANA, "children", "filha"), {
      ownerId: ANA, name: "Luna Exemplo", allergies: ["dipirona (ficticio)"],
    });
    await setDoc(doc(db, "child_registry", "filha"), { ownerUid: ANA });
    await setDoc(doc(db, "users", ANA, "children", "filha", "growth_records", "m1"), { weightKg: 9 });

    await setDoc(doc(db, "clinics", CLIN), { name: "Clinica da Dra", ownerUserId: DRA });
    await vinculoClinica(db, CLIN, DRA, "clinicAdmin");
    await vinculoClinica(db, CLIN, REC, "receptionist");
    await vinculoClinica(db, CLIN, FIN, "finance");
    await setDoc(doc(db, "clinics", CLIN_B), { name: "Clinica B", ownerUserId: OUTRA });
    await vinculoClinica(db, CLIN_B, OUTRA, "clinicAdmin");

    await setDoc(doc(db, "appointments", "consulta-familia"), {
      patientId: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN,
      requestedBy: ANA, status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + DIA),
      durationMinutes: 30,
    });
  });
});

// ===========================================================================
// Cenário do invasor: verificado, dono de clínica, conhece os ids
// ===========================================================================

describe("profissional sem vínculo, dono da própria clínica", () => {
  async function montarClinicaInvasora() {
    const db = as(INVASOR);
    await setDoc(doc(db, "clinics", CLIN_INV), { name: "Clinica Invasora", ownerUserId: INVASOR });
    await setDoc(doc(db, "clinics", CLIN_INV, "memberships", INVASOR), {
      id: INVASOR, userId: INVASOR, clinicId: CLIN_INV, role: "clinicAdmin", active: true,
    });
    await setDoc(doc(db, "users", INVASOR, "clinic_memberships", CLIN_INV), {
      id: INVASOR, userId: INVASOR, clinicId: CLIN_INV, role: "clinicAdmin", active: true,
    });
  }

  test("criar a própria clínica continua permitido (não é a falha)", async () => {
    await assertSucceeds(montarClinicaInvasora());
  });

  test("NÃO marca consulta para a criança de outra família", async () => {
    await montarClinicaInvasora();
    await assertFails(
      setDoc(doc(as(INVASOR), "appointments", "forjada"), {
        patientId: ANA, childId: "filha", professionalId: INVASOR, clinicId: CLIN_INV,
        status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + DIA),
      })
    );
  });

  test("NÃO marca consulta para a família sem indicar a criança", async () => {
    await montarClinicaInvasora();
    await assertFails(
      setDoc(doc(as(INVASOR), "appointments", "forjada-sem-crianca"), {
        patientId: ANA, professionalId: INVASOR, clinicId: CLIN_INV,
        status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + DIA),
      })
    );
  });

  test("NÃO se passa pela família ao marcar (requestedBy forjado)", async () => {
    await montarClinicaInvasora();
    await assertFails(
      setDoc(doc(as(INVASOR), "appointments", "forjada-pedido"), {
        patientId: ANA, childId: "filha", professionalId: INVASOR, clinicId: CLIN_INV,
        requestedBy: ANA, status: "requested", startsAt: Timestamp.fromMillis(Date.now() + DIA),
      })
    );
  });

  test("NÃO grava a própria concessão (nem com escopo e validade)", async () => {
    await assertFails(
      setDoc(
        doc(as(INVASOR), "users", ANA, "children", "filha", "authorized_professionals", INVASOR),
        { ...grantDoc(["summary", "chartWrite"]), authorizedBy: INVASOR, grantedAt: serverTimestamp() }
      )
    );
  });

  test("NÃO lê cadastro e alergias", async () => {
    await assertFails(getDoc(cadastro(INVASOR)));
  });

  const registros = [
    ["encounters", { patientId: "filha", status: "draft" }],
    ["lab_results", { patientId: "filha", analyte: "Hb (ficticio)" }],
    ["triage_records", { childId: "filha", weightKg: 9 }],
    ["development_records", { childId: "filha", milestone: "senta (ficticio)" }],
    ["supplement_prescriptions", { childId: "filha", status: "confirmed" }],
    ["supplement_lab_results", { childId: "filha" }, "recordedBy"],
    ["supplement_timeline", { childId: "filha" }, "createdBy"],
    ["supplement_clinical_notes", { childId: "filha", text: "nota (ficticia)" }],
    ["supplement_ai_drafts", { childId: "filha" }],
    ["visit_summaries", { patientId: "filha", status: "draft" }],
  ];

  test.each(registros)("NÃO cria registro em %s", async (col, data, autor = "professionalId") => {
    await assertFails(
      setDoc(doc(as(INVASOR), col, "forjado-" + col), { ...data, [autor]: INVASOR })
    );
  });

  test("concessão no formato antigo (sem escopo nem validade) não abre nada", async () => {
    await seed((db) =>
      setDoc(
        doc(db, "users", ANA, "children", "filha", "authorized_professionals", INVASOR),
        { grantedAt: Timestamp.now() }
      )
    );
    await assertFails(getDoc(cadastro(INVASOR)));
    await assertFails(
      setDoc(doc(as(INVASOR), "encounters", "forjado-antigo"), {
        patientId: "filha", professionalId: INVASOR, status: "draft",
      })
    );
  });
});

// ===========================================================================
// Consultas: ids protegidos e campos editáveis por perfil
// ===========================================================================

describe("consulta existente — identificadores protegidos", () => {
  const ref = (uid) => doc(as(uid), "appointments", "consulta-familia");

  test.each([
    ["childId", "outra-crianca"],
    ["patientId", BRUNO],
    ["professionalId", INVASOR],
    ["clinicId", CLIN_B],
    ["requestedBy", DRA],
  ])("profissional da consulta NÃO troca %s", async (campo, valor) => {
    await assertFails(updateDoc(ref(DRA), { [campo]: valor }));
  });

  test.each([
    ["childId", "outra-crianca"],
    ["patientId", BRUNO],
    ["professionalId", INVASOR],
    ["clinicId", CLIN_B],
  ])("recepção NÃO troca %s", async (campo, valor) => {
    await assertFails(updateDoc(ref(REC), { [campo]: valor }));
  });

  test("profissional da consulta confirma e remarca", async () => {
    await assertSucceeds(
      updateDoc(ref(DRA), { status: "confirmed", confirmedAt: serverTimestamp(), confirmedBy: DRA })
    );
    await assertSucceeds(
      updateDoc(ref(DRA), {
        startsAt: Timestamp.fromMillis(Date.now() + 2 * DIA), durationMinutes: 40,
        rescheduledAt: serverTimestamp(), rescheduledBy: DRA,
      })
    );
  });

  test("profissional da consulta NÃO marca como paga (é do financeiro)", async () => {
    // A Dra também é gestora da clínica, e a gestão responde pelo financeiro;
    // como só médica da equipe ela não marca pagamento.
    await seed((db) => vinculoClinica(db, CLIN, DRA, "physician"));
    await assertFails(updateDoc(ref(DRA), { paid: true }));
  });

  test("recepção faz check-in e remarca", async () => {
    await assertSucceeds(
      updateDoc(ref(REC), { workflowStatus: "arrived", status: "confirmed", arrivedAt: serverTimestamp(), checkInNotes: "ok" })
    );
  });

  test("financeiro só marca como pago", async () => {
    await assertSucceeds(updateDoc(ref(FIN), { paid: true }));
    await assertFails(updateDoc(ref(FIN), { paid: true, childId: "outra-crianca" }));
  });

  test("gestão de outra clínica NÃO lê nem altera a consulta", async () => {
    await assertFails(getDoc(ref(OUTRA)));
    await assertFails(updateDoc(ref(OUTRA), { status: "cancelled" }));
  });
});

describe("criação de consulta pela equipe", () => {
  const nova = (extra = {}) => ({
    patientId: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN,
    status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + 3 * DIA), ...extra,
  });

  test("recepção NÃO marca para criança sem vínculo autorizado com o profissional", async () => {
    await assertFails(setDoc(doc(as(REC), "appointments", "sem-vinculo"), nova()));
  });

  test("recepção marca para criança com vínculo autorizado do profissional", async () => {
    await conceder(DRA, ["summary"]);
    await assertSucceeds(setDoc(doc(as(REC), "appointments", "com-vinculo"), nova()));
  });

  test("vínculo restrito a outra clínica não vale nesta", async () => {
    await conceder(DRA, ["summary"], { clinicId: CLIN_B });
    await assertFails(setDoc(doc(as(REC), "appointments", "outra-clinica"), nova()));
  });

  test("responsável da consulta precisa ser o titular da criança", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "titular-errado"), nova({ patientId: BRUNO })));
  });

  test("profissional da consulta precisa pertencer à clínica", async () => {
    await assertFails(setDoc(doc(as(REC), "appointments", "fora-da-clinica"), nova({ professionalId: INVASOR })));
  });

  test("equipe NÃO grava requestedBy da família", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "pedido-forjado"), nova({ requestedBy: ANA })));
  });
});

describe("solicitação pela família", () => {
  test("responsável pede consulta para a própria criança, em nome próprio", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "appointments", "pedido-ana"), {
        patientId: ANA, childId: "filha", professionalId: DRA, status: "requested", requestedBy: ANA,
      })
    );
  });

  test("responsável NÃO registra o pedido em nome de outra pessoa", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "appointments", "pedido-terceiro"), {
        patientId: ANA, childId: "filha", professionalId: DRA, status: "requested", requestedBy: DRA,
      })
    );
  });

  test("outra família NÃO pede consulta para esta criança", async () => {
    await assertFails(
      setDoc(doc(as(BRUNO), "appointments", "pedido-bruno"), {
        patientId: BRUNO, childId: "filha", professionalId: DRA, status: "requested", requestedBy: BRUNO,
      })
    );
  });

  test("família acessa só a própria criança", async () => {
    await assertSucceeds(getDoc(cadastro(ANA)));
    await assertFails(getDoc(cadastro(BRUNO)));
  });
});

// ===========================================================================
// Escopo, validade e revogação da concessão
// ===========================================================================

describe("concessão com escopo", () => {
  test("escopo summary: lê o cadastro, mas NÃO grava no prontuário", async () => {
    await conceder(DRA, ["summary"]);
    await assertSucceeds(getDoc(cadastro(DRA)));
    await assertFails(
      setDoc(doc(as(DRA), "encounters", "so-resumo"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
  });

  test("escopo chartWrite: abre e edita atendimento em rascunho", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    const ref = doc(as(DRA), "encounters", "autorizado");
    await assertSucceeds(setDoc(ref, { patientId: "filha", professionalId: DRA, status: "draft" }));
    await assertSucceeds(updateDoc(ref, { plan: "retorno em 30 dias (ficticio)" }));
    await assertSucceeds(
      setDoc(doc(as(DRA), "triage_records", "t-ok"), { childId: "filha", professionalId: DRA, weightKg: 9 })
    );
  });

  test("nenhum escopo abre crescimento e vacinas da família", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    await assertFails(getDoc(doc(as(DRA), "users", ANA, "children", "filha", "growth_records", "m1")));
  });

  test("atendimento autorizado NÃO pode ser transferido para outra criança", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    const ref = doc(as(DRA), "encounters", "autorizado-2");
    await assertSucceeds(setDoc(ref, { patientId: "filha", professionalId: DRA, status: "draft" }));
    await assertFails(updateDoc(ref, { patientId: "outra-crianca" }));
  });

  test("concessão vencida bloqueia leitura e novas gravações", async () => {
    await conceder(DRA, ["summary", "chartWrite"], { expiresInDays: -1 });
    await assertFails(getDoc(cadastro(DRA)));
    await assertFails(
      setDoc(doc(as(DRA), "encounters", "vencida"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
  });

  test("concessão revogada bloqueia leitura, novas gravações e edição do rascunho", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    const ref = doc(as(DRA), "encounters", "antes-da-revogacao");
    await assertSucceeds(setDoc(ref, { patientId: "filha", professionalId: DRA, status: "draft" }));
    await conceder(DRA, ["summary", "chartWrite"], { revoked: true });
    await assertFails(getDoc(cadastro(DRA)));
    await assertFails(updateDoc(ref, { plan: "depois da revogacao" }));
    await assertFails(
      setDoc(doc(as(DRA), "encounters", "revogada"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
  });

  test("recepção e financeiro não ganham acesso clínico", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    for (const uid of [REC, FIN]) {
      await assertFails(getDoc(cadastro(uid)));
      await assertFails(
        setDoc(doc(as(uid), "encounters", "staff-" + uid), { patientId: "filha", professionalId: uid, status: "draft" })
      );
    }
  });
});

describe("concessão gravada pelo responsável", () => {
  const ref = (uid, prof = DRA) =>
    doc(as(uid), "users", ANA, "children", "filha", "authorized_professionals", prof);
  const valida = (extra = {}) => ({
    scopes: ["summary"],
    source: "guardian",
    authorizedBy: ANA,
    grantedAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 30 * DIA),
    revokedAt: null,
    clinicId: null,
    ...extra,
  });

  test("titular concede com escopo e validade", async () => {
    await assertSucceeds(setDoc(ref(ANA), valida()));
  });

  test.each([
    ["escopo desconhecido", { scopes: ["fullChart"] }],
    ["sem escopo", { scopes: [] }],
    ["validade acima de um ano", { expiresAt: Timestamp.fromMillis(Date.now() + 400 * DIA) }],
    ["validade no passado", { expiresAt: Timestamp.fromMillis(Date.now() - DIA) }],
    ["data de concessão forjada", { grantedAt: Timestamp.fromMillis(Date.now() - 10 * DIA) }],
    ["autor diferente do titular", { authorizedBy: DRA }],
    ["origem diferente de guardian", { source: "familyAppointment" }],
  ])("titular NÃO grava concessão inválida: %s", async (_nome, extra) => {
    await assertFails(setDoc(ref(ANA), valida(extra)));
  });

  test("titular revoga", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    await assertSucceeds(updateDoc(ref(ANA), { revokedAt: serverTimestamp(), revokedBy: ANA }));
  });

  test("profissional NÃO estende, amplia nem desfaz revogação da própria concessão", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(updateDoc(ref(DRA), { scopes: ["summary", "chartWrite"] }));
    await assertFails(updateDoc(ref(DRA), { expiresAt: Timestamp.fromMillis(Date.now() + 300 * DIA) }));
    await conceder(DRA, ["summary"], { revoked: true });
    await assertFails(updateDoc(ref(DRA), { revokedAt: null }));
  });

  test("outra família NÃO concede acesso a esta criança", async () => {
    await assertFails(setDoc(ref(BRUNO), { ...valida(), authorizedBy: BRUNO }));
  });

  test("profissional NÃO apaga a concessão de outro", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(deleteDoc(ref(INVASOR, DRA)));
  });
});
