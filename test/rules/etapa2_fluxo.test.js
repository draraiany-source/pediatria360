/**
 * Etapa 2 (25/10/2026): fluxo da clínica com autorização explícita.
 *
 * - Concessão só vale com origem `guardian` (gravada pelo titular no app) ou
 *   `guardianInvite` (gravada pela Function acceptClinicIntake depois que o
 *   titular aceita o convite). Concessão automática por consulta
 *   (`familyAppointment`) deixou de existir e não abre nada.
 * - Recepção, financeiro e gestão valem pelo papel no vínculo com a clínica,
 *   sem a marca de profissional verificado, e nenhum deles ganha acesso
 *   clínico por isso.
 * - Solicitação provisória (clinic_intakes) é só leitura para a equipe; código
 *   de convite e contagem de tentativas ficam fora do alcance do app.
 * - `origin` e `intakeId` da consulta não são forjados nem trocados.
 * - Revogação: o que deixa de valer e o que o autor continua lendo.
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
  getDocs,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");

const PROJECT_ID = "pediatria360-rules-test";

const ANA = "uid_ana";             // titular da "filha"
const BRUNO = "uid_bruno";         // outra família, titular do "filho"
const DRA = "uid_dra";             // médica verificada da clínica
const INVASOR = "uid_invasor";     // profissional verificado sem vínculo
const REC = "uid_recepcao";        // recepção, conta comum (não verificada)
const FIN = "uid_financeiro";      // financeiro, conta comum (não verificada)
const GESTOR = "uid_gestor";       // gestão da clínica, conta comum
const OUTRA = "uid_outra_clinica"; // gestão de outra clínica

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

function grantDoc(scopes, { expiresInDays = 30, revoked = false, clinicId = null, source = "guardian" } = {}) {
  return {
    scopes,
    source,
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

function consultaEquipe(extra = {}) {
  return {
    patientId: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN,
    status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + 3 * DIA), ...extra,
  };
}

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    const conta = (name) => ({ name, role: "parent", plan: "free", xp: 0 });
    const pro = (name) => ({ name, role: "professional", professionalVerified: true, plan: "pro", xp: 0 });
    await setDoc(doc(db, "users", ANA), conta("Ana (ficticia)"));
    await setDoc(doc(db, "users", BRUNO), conta("Bruno (ficticio)"));
    await setDoc(doc(db, "users", DRA), pro("Dra. Exemplo"));
    await setDoc(doc(db, "users", INVASOR), pro("Invasor (ficticio)"));
    await setDoc(doc(db, "users", REC), conta("Recepcao (ficticia)"));
    await setDoc(doc(db, "users", FIN), conta("Financeiro (ficticio)"));
    await setDoc(doc(db, "users", GESTOR), conta("Gestao (ficticia)"));
    await setDoc(doc(db, "users", OUTRA), conta("Outra clinica (ficticia)"));

    await setDoc(doc(db, "users", ANA, "children", "filha"), {
      ownerId: ANA, name: "Luna Exemplo", allergies: ["dipirona (ficticio)"],
    });
    await setDoc(doc(db, "child_registry", "filha"), { ownerUid: ANA });
    await setDoc(doc(db, "users", ANA, "children", "filha", "growth_records", "m1"), { weightKg: 9 });
    await setDoc(doc(db, "users", ANA, "children", "filha", "vaccine_doses", "v1"), { vaccine: "BCG (ficticio)" });
    await setDoc(doc(db, "users", BRUNO, "children", "filho"), { ownerId: BRUNO, name: "Theo Exemplo" });
    await setDoc(doc(db, "child_registry", "filho"), { ownerUid: BRUNO });

    await setDoc(doc(db, "clinics", CLIN), { name: "Clinica da Dra", ownerUserId: GESTOR });
    await vinculoClinica(db, CLIN, GESTOR, "clinicAdmin");
    await vinculoClinica(db, CLIN, DRA, "physician");
    await vinculoClinica(db, CLIN, REC, "receptionist");
    await vinculoClinica(db, CLIN, FIN, "finance");
    await setDoc(doc(db, "clinics", CLIN_B), { name: "Clinica B", ownerUserId: OUTRA });
    await vinculoClinica(db, CLIN_B, OUTRA, "clinicAdmin");

    await setDoc(doc(db, "appointments", "consulta-clinica"), {
      patientId: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN,
      origin: "clinicIntake", intakeId: "intake-1", status: "confirmed",
      startsAt: Timestamp.fromMillis(Date.now() + DIA), durationMinutes: 30, paid: false,
    });

    await setDoc(doc(db, "clinic_intakes", "intake-1"), {
      clinicId: CLIN, professionalId: DRA, createdBy: REC, status: "pendingGuardian",
      childName: "Bebe Exemplo", guardianName: "Responsavel Exemplo",
    });
    await setDoc(doc(db, "clinic_intakes", "intake-1", "private", "invite"), { codeHash: "hash-ficticio" });
    await setDoc(doc(db, "clinic_intake_codes", "hash-ficticio"), { intakeId: "intake-1" });
    await setDoc(doc(db, "intake_attempts", ANA), { failures: 1 });
  });
});

// ===========================================================================
// Origem da concessão
// ===========================================================================

describe("origem da concessão", () => {
  test("convite aceito pelo titular (guardianInvite) vale", async () => {
    await conceder(DRA, ["summary"], { source: "guardianInvite" });
    await assertSucceeds(getDoc(cadastro(DRA)));
  });

  test("concessão automática antiga (familyAppointment) NÃO vale", async () => {
    await conceder(DRA, ["summary", "chartWrite"], { source: "familyAppointment" });
    await assertFails(getDoc(cadastro(DRA)));
    await assertFails(
      setDoc(doc(as(DRA), "encounters", "por-consulta"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
  });

  test("titular NÃO grava origem guardianInvite pelo app (é do servidor)", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "users", ANA, "children", "filha", "authorized_professionals", DRA), {
        ...grantDoc(["summary"], { source: "guardianInvite" }), grantedAt: serverTimestamp(),
      })
    );
  });

  test("titular grava concessão com nome do profissional e da clínica", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "users", ANA, "children", "filha", "authorized_professionals", DRA), {
        ...grantDoc(["summary"], { clinicId: CLIN }),
        grantedAt: serverTimestamp(),
        professionalName: "Dra. Exemplo",
        clinicName: "Clinica da Dra",
      })
    );
  });
});

// ===========================================================================
// Recepção sem a marca de verificado
// ===========================================================================

describe("recepção (conta comum, papel receptionist)", () => {
  test("NÃO marca consulta direto pelo app, nem com autorização (só pela Function com travas)", async () => {
    // O caminho autorizado é scheduleAppointment, coberto no e2e do emulador.
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-ok"), consultaEquipe()));
  });

  test("NÃO marca consulta sem autorização do titular", async () => {
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-sem"), consultaEquipe()));
  });

  test("NÃO marca com autorização vencida ou revogada", async () => {
    await conceder(DRA, ["summary"], { expiresInDays: -1 });
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-vencida"), consultaEquipe()));
    await conceder(DRA, ["summary"], { revoked: true });
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-revogada"), consultaEquipe()));
  });

  test.each([
    ["origin de convite", { origin: "clinicIntake" }],
    ["origin de pedido da família", { origin: "familyRequest" }],
    ["intakeId forjado", { intakeId: "intake-1" }],
    ["pagamento já marcado", { paid: true }],
  ])("NÃO forja na criação: %s", async (_nome, extra) => {
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-forjada"), consultaEquipe(extra)));
  });

  test("NÃO marca consulta em outra clínica", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "rec-b"), consultaEquipe({ clinicId: CLIN_B })));
  });

  test("faz check-in; remarcar direto pelo app é negado (só pela Function)", async () => {
    const ref = doc(as(REC), "appointments", "consulta-clinica");
    await assertSucceeds(updateDoc(ref, { workflowStatus: "arrived", arrivedAt: serverTimestamp() }));
    await assertFails(
      updateDoc(ref, { startsAt: Timestamp.fromMillis(Date.now() + 2 * DIA), rescheduledBy: REC })
    );
    await assertFails(updateDoc(ref, { durationMinutes: 90 }));
    await assertFails(updateDoc(ref, { roomId: "sala-2" }));
  });

  test("NÃO reativa consulta cancelada direto pelo app", async () => {
    await seed((db) =>
      updateDoc(doc(db, "appointments", "consulta-clinica"), { status: "cancelled" })
    );
    const ref = doc(as(REC), "appointments", "consulta-clinica");
    await assertFails(updateDoc(ref, { status: "confirmed" }));
    await assertFails(updateDoc(doc(as(DRA), "appointments", "consulta-clinica"), { status: "confirmed" }));
  });

  test("família NÃO cancela consulta da clínica direto (vale o prazo da Function)", async () => {
    await assertFails(
      updateDoc(doc(as(ANA), "appointments", "consulta-clinica"), { status: "cancelled" })
    );
  });

  test("família NÃO cria pedido já com horário ou travas", async () => {
    const base = { patientId: ANA, childId: "filha", status: "requested", origin: "familyRequest" };
    await assertSucceeds(setDoc(doc(as(ANA), "appointments", "pedido-sem-horario"), base));
    await assertFails(setDoc(doc(as(ANA), "appointments", "pedido-com-horario"), {
      ...base, startsAt: Timestamp.fromMillis(Date.now() + DIA),
    }));
    await assertFails(setDoc(doc(as(ANA), "appointments", "pedido-com-trava"), {
      ...base, lockIds: ["prof_x_1"], scheduleVersion: 1,
    }));
  });

  test("NÃO marca como pago, NÃO troca origem nem solicitação", async () => {
    const ref = doc(as(REC), "appointments", "consulta-clinica");
    await assertFails(updateDoc(ref, { paid: true }));
    await assertFails(updateDoc(ref, { origin: "clinicStaff" }));
    await assertFails(updateDoc(ref, { intakeId: "outro" }));
  });

  test("NÃO lê cadastro, crescimento nem prontuário", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    await seed((db) =>
      setDoc(doc(db, "encounters", "e1"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
    await assertFails(getDoc(cadastro(REC)));
    await assertFails(getDoc(doc(as(REC), "users", ANA, "children", "filha", "growth_records", "m1")));
    await assertFails(getDoc(doc(as(REC), "encounters", "e1")));
    await assertFails(
      getDocs(query(collection(as(REC), "encounters"), where("patientId", "==", "filha")))
    );
  });
});

// ===========================================================================
// Financeiro sem a marca de verificado
// ===========================================================================

describe("financeiro (conta comum, papel finance)", () => {
  const conta = (extra = {}) => ({ ownerId: FIN, clinicId: CLIN, amountCents: 15000, description: "consulta (ficticia)", ...extra });

  test("lança e lê conta a receber da clínica", async () => {
    await assertSucceeds(setDoc(doc(as(FIN), "finance_receivables", "r1"), conta()));
    await assertSucceeds(getDoc(doc(as(FIN), "finance_receivables", "r1")));
  });

  test("registra auditoria financeira da clínica", async () => {
    await assertSucceeds(
      setDoc(doc(as(FIN), "finance_audit_logs", "a1"), { ownerId: FIN, clinicId: CLIN, action: "create" })
    );
  });

  test("NÃO lança em outra clínica nem no livro próprio sem verificação", async () => {
    await assertFails(setDoc(doc(as(FIN), "finance_receivables", "r2"), conta({ clinicId: CLIN_B })));
    await assertFails(setDoc(doc(as(FIN), "finance_receivables", "r3"), conta({ clinicId: null })));
  });

  test("marca a consulta como paga, mas não mexe no andamento", async () => {
    const ref = doc(as(FIN), "appointments", "consulta-clinica");
    await assertSucceeds(updateDoc(ref, { paid: true }));
    await assertFails(updateDoc(ref, { status: "cancelled" }));
    await assertFails(updateDoc(ref, { paid: false, childId: "filho" }));
  });

  test("recepção NÃO lança no financeiro", async () => {
    await assertFails(
      setDoc(doc(as(REC), "finance_receivables", "r4"), { ...conta(), ownerId: REC })
    );
  });

  test("NÃO lê cadastro nem prontuário", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    await assertFails(getDoc(cadastro(FIN)));
    await assertFails(
      setDoc(doc(as(FIN), "encounters", "fin"), { patientId: "filha", professionalId: FIN, status: "draft" })
    );
  });

  test("NÃO vê as solicitações provisórias (dado de atendimento)", async () => {
    await assertFails(getDoc(doc(as(FIN), "clinic_intakes", "intake-1")));
  });
});

// ===========================================================================
// Gestão da clínica sem acesso clínico
// ===========================================================================

describe("gestão (clinicAdmin) sem autorização do titular", () => {
  test("vê a agenda e as solicitações da própria clínica", async () => {
    await assertSucceeds(getDoc(doc(as(GESTOR), "appointments", "consulta-clinica")));
    await assertSucceeds(getDoc(doc(as(GESTOR), "clinic_intakes", "intake-1")));
  });

  test("NÃO lê cadastro, crescimento, vacinas nem prontuário", async () => {
    await conceder(DRA, ["summary", "chartWrite"]);
    await seed((db) =>
      setDoc(doc(db, "encounters", "e1"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
    await assertFails(getDoc(cadastro(GESTOR)));
    await assertFails(getDoc(doc(as(GESTOR), "users", ANA, "children", "filha", "growth_records", "m1")));
    await assertFails(getDoc(doc(as(GESTOR), "users", ANA, "children", "filha", "vaccine_doses", "v1")));
    await assertFails(getDoc(doc(as(GESTOR), "encounters", "e1")));
  });

  test("NÃO concede a si mesma nem à equipe", async () => {
    const ref = (prof) => doc(as(GESTOR), "users", ANA, "children", "filha", "authorized_professionals", prof);
    await assertFails(setDoc(ref(GESTOR), { ...grantDoc(["summary"]), authorizedBy: GESTOR, grantedAt: serverTimestamp() }));
    await assertFails(setDoc(ref(DRA), { ...grantDoc(["summary"]), authorizedBy: GESTOR, grantedAt: serverTimestamp() }));
  });
});

// ===========================================================================
// Solicitação provisória (paciente novo)
// ===========================================================================

describe("solicitação provisória (clinic_intakes)", () => {
  test("recepção e profissional da solicitação leem", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "clinic_intakes", "intake-1")));
    await assertSucceeds(getDoc(doc(as(DRA), "clinic_intakes", "intake-1")));
  });

  test("outra clínica, família e profissional sem vínculo NÃO leem", async () => {
    for (const uid of [OUTRA, ANA, BRUNO, INVASOR]) {
      await assertFails(getDoc(doc(as(uid), "clinic_intakes", "intake-1")));
    }
  });

  test("ninguém grava pelo app (criação e aceite são da Function)", async () => {
    await assertFails(
      setDoc(doc(as(REC), "clinic_intakes", "intake-2"), {
        clinicId: CLIN, professionalId: DRA, createdBy: REC, status: "pendingGuardian",
      })
    );
    await assertFails(updateDoc(doc(as(REC), "clinic_intakes", "intake-1"), { status: "linked" }));
    await assertFails(
      updateDoc(doc(as(ANA), "clinic_intakes", "intake-1"), { status: "linked", linkedOwnerUid: ANA })
    );
  });

  test("código do convite e tentativas ficam fora do app", async () => {
    for (const uid of [REC, GESTOR, ANA, DRA]) {
      await assertFails(getDoc(doc(as(uid), "clinic_intakes", "intake-1", "private", "invite")));
      await assertFails(getDoc(doc(as(uid), "clinic_intake_codes", "hash-ficticio")));
    }
    await assertFails(getDoc(doc(as(ANA), "intake_attempts", ANA)));
    await assertFails(setDoc(doc(as(ANA), "intake_attempts", ANA), { failures: 0 }));
    await assertFails(setDoc(doc(as(ANA), "clinic_intake_codes", "outro"), { intakeId: "intake-1" }));
  });
});

// ===========================================================================
// Origem da consulta e pedido da família
// ===========================================================================

describe("origem da consulta", () => {
  test("família pede consulta para a própria criança (sem gerar acesso)", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "appointments", "pedido"), {
        patientId: ANA, childId: "filha", professionalId: DRA, status: "requested",
        requestedBy: ANA, origin: "familyRequest",
      })
    );
    await assertFails(getDoc(cadastro(DRA)));
  });

  test.each([
    ["origin de convite", { origin: "clinicIntake" }],
    ["origin de equipe", { origin: "clinicStaff" }],
    ["intakeId", { intakeId: "intake-1" }],
  ])("família NÃO forja %s", async (_nome, extra) => {
    await assertFails(
      setDoc(doc(as(ANA), "appointments", "pedido-forjado"), {
        patientId: ANA, childId: "filha", professionalId: DRA, status: "requested", ...extra,
      })
    );
  });

  test("família NÃO pede consulta para a criança de outra família", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "appointments", "pedido-alheio"), {
        patientId: ANA, childId: "filho", professionalId: DRA, status: "requested",
      })
    );
  });

  test("profissional da consulta NÃO troca origem nem solicitação", async () => {
    const ref = doc(as(DRA), "appointments", "consulta-clinica");
    await assertFails(updateDoc(ref, { origin: "familyRequest" }));
    await assertFails(updateDoc(ref, { intakeId: null }));
  });
});

// ===========================================================================
// Somente resumo
// ===========================================================================

describe("autorização somente resumo", () => {
  beforeEach(() => conceder(DRA, ["summary"]));

  test("lê o cadastro", async () => {
    await assertSucceeds(getDoc(cadastro(DRA)));
  });

  test("NÃO lê crescimento nem vacinas", async () => {
    await assertFails(getDoc(doc(as(DRA), "users", ANA, "children", "filha", "growth_records", "m1")));
    await assertFails(getDoc(doc(as(DRA), "users", ANA, "children", "filha", "vaccine_doses", "v1")));
  });

  test.each([
    ["encounters", { patientId: "filha", status: "draft" }],
    ["lab_results", { patientId: "filha", analyte: "Hb (ficticio)" }],
    ["triage_records", { childId: "filha", weightKg: 9 }],
    ["visit_summaries", { patientId: "filha", status: "draft" }],
    ["development_records", { childId: "filha", milestone: "senta (ficticio)" }],
    ["supplement_ai_drafts", { childId: "filha" }],
  ])("NÃO grava em %s", async (col, data) => {
    await assertFails(setDoc(doc(as(DRA), col, "so-resumo-" + col), { ...data, professionalId: DRA }));
  });

  test("documentos clínicos não se gravam pelo app", async () => {
    await assertFails(
      setDoc(doc(as(DRA), "clinical_documents", "d1"), { patientId: "filha", professionalId: DRA })
    );
  });
});

// ===========================================================================
// Revogação: o que deixa de valer e o que o autor ainda lê
// ===========================================================================

describe("revogação", () => {
  async function registrosAntesDaRevogacao() {
    await conceder(DRA, ["summary", "chartWrite"]);
    await assertSucceeds(
      setDoc(doc(as(DRA), "encounters", "antes"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
    await assertSucceeds(
      setDoc(doc(as(DRA), "lab_results", "lab-antes"), { patientId: "filha", professionalId: DRA, analyte: "Hb (ficticio)" })
    );
    await seed((db) =>
      setDoc(doc(db, "clinical_documents", "doc-antes"), { patientId: "filha", professionalId: DRA, kind: "atestado" })
    );
    await conceder(DRA, ["summary", "chartWrite"], { revoked: true });
  }

  test("cadastro, novas gravações e edição de rascunho deixam de valer", async () => {
    await registrosAntesDaRevogacao();
    await assertFails(getDoc(cadastro(DRA)));
    await assertFails(updateDoc(doc(as(DRA), "encounters", "antes"), { plan: "depois (ficticio)" }));
    await assertFails(
      setDoc(doc(as(DRA), "encounters", "depois"), { patientId: "filha", professionalId: DRA, status: "draft" })
    );
    await assertFails(
      setDoc(doc(as(DRA), "lab_results", "lab-depois"), { patientId: "filha", professionalId: DRA })
    );
  });

  test("listagem pela criança fica negada", async () => {
    await registrosAntesDaRevogacao();
    for (const col of ["encounters", "lab_results", "clinical_documents"]) {
      await assertFails(getDocs(query(collection(as(DRA), col), where("patientId", "==", "filha"))));
    }
  });

  // Política atual, documentada como decisão pendente: o autor continua
  // lendo o que ele mesmo registrou (regra `professionalId == uid`). Não é
  // ampliação de acesso; o teste fixa o comportamento para não mudar sem
  // decisão explícita.
  test("autor continua lendo o que registrou (política atual)", async () => {
    await registrosAntesDaRevogacao();
    await assertSucceeds(getDoc(doc(as(DRA), "encounters", "antes")));
    await assertSucceeds(getDoc(doc(as(DRA), "lab_results", "lab-antes")));
    await assertSucceeds(getDoc(doc(as(DRA), "clinical_documents", "doc-antes")));
    await assertSucceeds(
      getDocs(query(collection(as(DRA), "encounters"), where("professionalId", "==", DRA)))
    );
  });

  test("ninguém além do autor e da família lê esses registros", async () => {
    await registrosAntesDaRevogacao();
    for (const uid of [INVASOR, REC, FIN, GESTOR, BRUNO]) {
      await assertFails(getDoc(doc(as(uid), "encounters", "antes")));
      await assertFails(getDoc(doc(as(uid), "clinical_documents", "doc-antes")));
    }
    await assertSucceeds(getDoc(doc(as(ANA), "encounters", "antes")));
  });

  test("profissional NÃO desfaz a revogação", async () => {
    await registrosAntesDaRevogacao();
    await assertFails(
      updateDoc(doc(as(DRA), "users", ANA, "children", "filha", "authorized_professionals", DRA), { revokedAt: null })
    );
  });
});

// ===========================================================================
// Entre famílias e entre clínicas, troca de ids e autoconcessão
// ===========================================================================

describe("isolamento", () => {
  test("titular NÃO concede acesso à criança de outra família", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "users", BRUNO, "children", "filho", "authorized_professionals", DRA), {
        ...grantDoc(["summary"]), grantedAt: serverTimestamp(),
      })
    );
  });

  test("conhecer o id da criança NÃO abre o cadastro para outra família", async () => {
    await assertFails(getDoc(cadastro(BRUNO)));
    await assertFails(getDoc(doc(as(ANA), "users", BRUNO, "children", "filho")));
  });

  test("autorização restrita à clínica B não vale na clínica da Dra", async () => {
    await conceder(DRA, ["summary"], { clinicId: CLIN_B });
    await assertFails(setDoc(doc(as(REC), "appointments", "clin-b"), consultaEquipe()));
  });

  test("gestão de outra clínica NÃO lê nem marca na clínica da Dra", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(getDoc(doc(as(OUTRA), "appointments", "consulta-clinica")));
    await assertFails(setDoc(doc(as(OUTRA), "appointments", "outra"), consultaEquipe()));
  });

  test("recepção NÃO troca a criança ou o responsável da consulta", async () => {
    const ref = doc(as(REC), "appointments", "consulta-clinica");
    await assertFails(updateDoc(ref, { childId: "filho" }));
    await assertFails(updateDoc(ref, { patientId: BRUNO }));
    await assertFails(updateDoc(ref, { professionalId: INVASOR }));
  });

  test("recepção NÃO marca para criança com responsável trocado", async () => {
    await conceder(DRA, ["summary"]);
    await assertFails(setDoc(doc(as(REC), "appointments", "troca"), consultaEquipe({ patientId: BRUNO })));
    await assertFails(setDoc(doc(as(REC), "appointments", "troca-2"), consultaEquipe({ childId: "filho" })));
  });

  test("ninguém da equipe se autoconcede acesso", async () => {
    for (const uid of [DRA, REC, FIN, GESTOR, INVASOR]) {
      await assertFails(
        setDoc(doc(as(uid), "users", ANA, "children", "filha", "authorized_professionals", uid), {
          ...grantDoc(["summary", "chartWrite"]), authorizedBy: uid, grantedAt: serverTimestamp(),
        })
      );
    }
  });
});
