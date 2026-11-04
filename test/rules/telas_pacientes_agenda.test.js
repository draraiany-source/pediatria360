/**
 * Consultas exatas das telas de Pacientes e Agenda (29/10/2026).
 *
 * Reproduz o erro "Sua sessão não tem permissão para estes dados" relatado
 * na homologação e prova o que as regras aceitam e recusam:
 *
 * - Pacientes (`professionalPatientsProvider`): encounters do próprio
 *   profissional, ordenados por `startedAt`.
 * - Agenda do profissional (`watchProfessionalAgenda`): appointments do
 *   próprio profissional, ordenados por `startsAt`.
 * - Agenda da clínica (`watchClinicAgenda`, recepção/gestão/enfermagem):
 *   appointments da clínica ativa.
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
  setDoc,
  getDocs,
  collection,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} = require("firebase/firestore");

const PROJECT_ID = "pediatria360-rules-test";
const DIA = 24 * 60 * 60 * 1000;

const DRA = "uid_dra";          // médica verificada da clínica A
const DIEGO = "uid_diego";      // médico verificado da clínica B
const REC = "uid_recepcao";     // recepção da clínica A (conta comum)
const ENF = "uid_enfermagem";   // enfermagem da clínica A
const FIN = "uid_financeiro";   // financeiro da clínica A
const GESTOR_B = "uid_gestor_b"; // gestão da clínica B
const ANA = "uid_ana";          // responsável

const CLIN = "clinica-a";
const CLIN_B = "clinica-b";

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

async function vinculo(db, clinicId, uid, role, { ladoClinica = true, ativo = true } = {}) {
  if (ladoClinica) {
    await setDoc(doc(db, "clinics", clinicId, "memberships", uid), {
      id: uid, userId: uid, clinicId, role, active: ativo,
    });
  }
  await setDoc(doc(db, "users", uid, "clinic_memberships", clinicId), {
    id: uid, userId: uid, clinicId, role, active: true,
  });
}

function agendaProfissional(uid) {
  return query(
    collection(as(uid), "appointments"),
    where("professionalId", "==", uid),
    orderBy("startsAt"),
    limit(100)
  );
}

function agendaClinica(uid, clinicId) {
  return query(
    collection(as(uid), "appointments"),
    where("clinicId", "==", clinicId),
    orderBy("startsAt"),
    limit(200)
  );
}

function pacientesDoProfissional(uid) {
  return query(
    collection(as(uid), "encounters"),
    where("professionalId", "==", uid),
    orderBy("startedAt", "desc"),
    limit(100)
  );
}

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    const pro = (name) => ({ name, role: "professional", professionalVerified: true, plan: "pro", xp: 0 });
    const conta = (name) => ({ name, role: "parent", plan: "free", xp: 0 });
    await setDoc(doc(db, "users", DRA), pro("Dra. Exemplo"));
    await setDoc(doc(db, "users", DIEGO), pro("Dr. Outra Clinica"));
    for (const [uid, nome] of [[REC, "Recepcao"], [ENF, "Enfermagem"], [FIN, "Financeiro"], [GESTOR_B, "Gestao B"], [ANA, "Ana"]]) {
      await setDoc(doc(db, "users", uid), conta(`${nome} (ficticio)`));
    }
    await setDoc(doc(db, "clinics", CLIN), { id: CLIN, name: "Clinica A (ficticia)", active: true });
    await setDoc(doc(db, "clinics", CLIN_B), { id: CLIN_B, name: "Clinica B (ficticia)", active: true });
    await vinculo(db, CLIN, DRA, "physician");
    await vinculo(db, CLIN, REC, "receptionist");
    await vinculo(db, CLIN, ENF, "nursing");
    await vinculo(db, CLIN, FIN, "financial");
    await vinculo(db, CLIN_B, DIEGO, "physician");
    await vinculo(db, CLIN_B, GESTOR_B, "clinicAdmin");

    await setDoc(doc(db, "users", ANA, "children", "filha"), { ownerId: ANA, name: "Luna Exemplo" });
    await setDoc(doc(db, "child_registry", "filha"), { ownerUid: ANA });

    await setDoc(doc(db, "appointments", "a1"), {
      patientId: ANA, childId: "filha", professionalId: DRA, clinicId: CLIN,
      status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + DIA),
    });
    await setDoc(doc(db, "appointments", "b1"), {
      patientId: ANA, childId: "filha", professionalId: DIEGO, clinicId: CLIN_B,
      status: "confirmed", startsAt: Timestamp.fromMillis(Date.now() + 2 * DIA),
    });
    await setDoc(doc(db, "encounters", "e1"), {
      patientId: "filha", professionalId: DRA, clinicId: CLIN, status: "draft",
      startedAt: Timestamp.fromMillis(Date.now() - DIA),
    });
    await setDoc(doc(db, "encounters", "e2"), {
      patientId: "filha", professionalId: DIEGO, clinicId: CLIN_B, status: "signed",
      startedAt: Timestamp.fromMillis(Date.now() - 2 * DIA),
    });
  });
});

describe("Pacientes: atendimentos do próprio profissional", () => {
  test("profissional autenticado lista só os próprios atendimentos", async () => {
    const snap = await assertSucceeds(getDocs(pacientesDoProfissional(DRA)));
    expect(snap.docs.map((d) => d.id)).toEqual(["e1"]);
  });

  test("profissional de outra clínica não lista atendimentos da Dra.", async () => {
    await assertFails(getDocs(query(
      collection(as(DIEGO), "encounters"),
      where("professionalId", "==", DRA),
      orderBy("startedAt", "desc")
    )));
  });

  test("recepção não lista prontuários da clínica", async () => {
    await assertFails(getDocs(query(
      collection(as(REC), "encounters"),
      where("clinicId", "==", CLIN)
    )));
  });

  test("sem login a consulta é recusada", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(query(
      collection(anon, "encounters"),
      where("professionalId", "==", DRA),
      orderBy("startedAt", "desc")
    )));
  });
});

describe("Agenda do profissional", () => {
  test("profissional autenticado carrega a própria agenda", async () => {
    const snap = await assertSucceeds(getDocs(agendaProfissional(DRA)));
    expect(snap.docs.map((d) => d.id)).toEqual(["a1"]);
  });

  test("profissional não carrega a agenda de outro profissional", async () => {
    await assertFails(getDocs(query(
      collection(as(DIEGO), "appointments"),
      where("professionalId", "==", DRA),
      orderBy("startsAt")
    )));
  });
});

describe("Agenda da clínica (recepção, enfermagem, gestão)", () => {
  test("recepção com vínculo ativo nos dois lados carrega a agenda da clínica", async () => {
    const snap = await assertSucceeds(getDocs(agendaClinica(REC, CLIN)));
    expect(snap.docs.map((d) => d.id)).toEqual(["a1"]);
  });

  test("enfermagem com vínculo ativo carrega a agenda da clínica", async () => {
    await assertSucceeds(getDocs(agendaClinica(ENF, CLIN)));
  });

  test("financeiro não carrega a agenda (fora do papel)", async () => {
    await assertFails(getDocs(agendaClinica(FIN, CLIN)));
  });

  test("gestão da clínica B não carrega a agenda da clínica A", async () => {
    await assertFails(getDocs(agendaClinica(GESTOR_B, CLIN)));
  });

  test("vínculo só no perfil do usuário (sem o lado da clínica) é recusado", async () => {
    const SO_USUARIO = "uid_rec_dessincronizada";
    await seed(async (db) => {
      await setDoc(doc(db, "users", SO_USUARIO), { name: "Rec. (ficticia)", role: "parent", plan: "free", xp: 0 });
      await vinculo(db, CLIN, SO_USUARIO, "receptionist", { ladoClinica: false });
    });
    await assertFails(getDocs(agendaClinica(SO_USUARIO, CLIN)));
  });

  test("vínculo desativado pela clínica é recusado", async () => {
    const INATIVA = "uid_rec_inativa";
    await seed(async (db) => {
      await setDoc(doc(db, "users", INATIVA), { name: "Rec. (ficticia)", role: "parent", plan: "free", xp: 0 });
      await vinculo(db, CLIN, INATIVA, "receptionist", { ativo: false });
    });
    await assertFails(getDocs(agendaClinica(INATIVA, CLIN)));
  });
});
