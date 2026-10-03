/**
 * Regras do cuidado multidisciplinar (care_teams e care/ no Storage).
 *
 * Cenário fictício: a Luna, filha da Ana, é atendida por pediatra,
 * psicóloga e fisioterapeuta da Clínica A. Outro psicólogo da mesma clínica,
 * a gestão da clínica e um pediatra da Clínica B existem, mas sem vínculo.
 *
 *   cd test/rules
 *   npm install
 *   npm test
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
  writeBatch,
  Timestamp,
} = require("firebase/firestore");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

const PROJECT_ID = "pediatria360-rules-test";

const ANA = "uid_ana"; // responsável pela Luna
const BRUNO = "uid_bruno"; // outro responsável
const PED = "uid_ped"; // pediatra com vínculo
const PSI = "uid_psi"; // psicóloga com vínculo
const FIS = "uid_fis"; // fisioterapeuta com vínculo
const PSI2 = "uid_psi2"; // psicólogo da mesma clínica, sem vínculo
const GESTOR = "uid_gestor"; // gestão da Clínica A
const PED_B = "uid_ped_b"; // pediatra da Clínica B
const NAO_VERIFICADO = "uid_nao_verificado";
const CHILD = "luna";
const TEAM = `care_teams/${CHILD}`;

let testEnv;

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const storage = (uid) => testEnv.authenticatedContext(uid).storage();

async function seedMember(fs, uid, specialty, clinicId, status = "active") {
  await setDoc(doc(fs, `${TEAM}/members/${uid}`), {
    specialty,
    clinicId,
    status,
    reason: "Motivo fictício",
    requestedBy: GESTOR,
    since: Timestamp.now(),
  });
}

async function seedClinicMember(fs, uid, clinicId, role) {
  await setDoc(doc(fs, `users/${uid}/clinic_memberships/${clinicId}`), {
    id: uid,
    userId: uid,
    clinicId,
    role,
    active: true,
  });
  await setDoc(doc(fs, `clinics/${clinicId}/memberships/${uid}`), {
    id: uid,
    userId: uid,
    clinicId,
    role,
    active: true,
  });
}

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

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const fs = context.firestore();
    const pro = (careSpecialty, verified = true) => ({
      role: "professional",
      plan: "pro",
      professionalVerified: verified,
      careSpecialty,
      xp: 0,
    });
    await setDoc(doc(fs, `users/${ANA}`), { role: "parent", plan: "free", xp: 0 });
    await setDoc(doc(fs, `users/${BRUNO}`), { role: "parent", plan: "free", xp: 0 });
    await setDoc(doc(fs, `users/${PED}`), pro("pediatria"));
    await setDoc(doc(fs, `users/${PSI}`), pro("psicologia"));
    await setDoc(doc(fs, `users/${FIS}`), pro("fisioterapia"));
    await setDoc(doc(fs, `users/${PSI2}`), pro("psicologia"));
    await setDoc(doc(fs, `users/${GESTOR}`), pro("pediatria"));
    await setDoc(doc(fs, `users/${PED_B}`), pro("pediatria"));
    await setDoc(doc(fs, `users/${NAO_VERIFICADO}`), pro("psicologia", false));

    await setDoc(doc(fs, `users/${ANA}/children/${CHILD}`), { name: "Luna (fictícia)" });
    await setDoc(doc(fs, `child_registry/${CHILD}`), { ownerUid: ANA });

    await seedClinicMember(fs, GESTOR, "clinica-a", "clinicAdmin");
    await seedClinicMember(fs, PSI2, "clinica-a", "healthProfessional");
    await seedClinicMember(fs, PSI, "clinica-a", "healthProfessional");
    await seedClinicMember(fs, FIS, "clinica-a", "healthProfessional");
    await seedClinicMember(fs, PED, "clinica-a", "physician");
    await seedClinicMember(fs, PED_B, "clinica-b", "physician");

    await setDoc(doc(fs, TEAM), { ownerUid: ANA, createdAt: Timestamp.now() });
    await seedMember(fs, PED, "pediatria", "clinica-a");
    await seedMember(fs, PSI, "psicologia", "clinica-a");
    await seedMember(fs, FIS, "fisioterapia", "clinica-a");

    const base = { clinicId: "clinica-a", revision: 1, createdAt: Timestamp.now() };
    await setDoc(doc(fs, `${TEAM}/records/reservado1`), {
      ...base,
      authorUid: PSI,
      specialty: "psicologia",
      kind: "sessao",
      visibility: "reservado",
      body: "Anotação reservada fictícia",
    });
    await setDoc(doc(fs, `${TEAM}/records/equipe1`), {
      ...base,
      authorUid: FIS,
      specialty: "fisioterapia",
      kind: "evolucao",
      visibility: "equipe",
      body: "Evolução fictícia",
    });
    await setDoc(doc(fs, `${TEAM}/records/familia1`), {
      ...base,
      authorUid: FIS,
      specialty: "fisioterapia",
      kind: "atividadeCasa",
      visibility: "familia",
      releasedAt: Timestamp.now(),
      body: "Exercício fictício",
    });
    await setDoc(doc(fs, `${TEAM}/messages/msg1`), {
      authorUid: PED,
      authorSpecialty: "pediatria",
      clinicId: "clinica-a",
      kind: "mensagem",
      status: "aberto",
      subject: "Horário",
      body: "Mensagem fictícia",
    });
    await setDoc(doc(fs, `${TEAM}/messages/ref1`), {
      authorUid: PED,
      authorSpecialty: "pediatria",
      clinicId: "clinica-a",
      kind: "encaminhamento",
      toSpecialty: "psicologia",
      status: "aberto",
      subject: "Encaminhamento",
      body: "Encaminhamento fictício",
    });
    await setDoc(doc(fs, `${TEAM}/documents/rascunho`), {
      authorUid: PSI,
      specialty: "psicologia",
      clinicId: "clinica-a",
      kind: "relatorioPsicologico",
      status: "draft",
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(fs, `${TEAM}/documents/emitido`), {
      authorUid: PSI,
      specialty: "psicologia",
      clinicId: "clinica-a",
      kind: "declaracaoComparecimento",
      status: "issued",
      createdAt: Timestamp.now(),
    });

    const st = context.storage();
    const png = new Uint8Array([137, 80, 78, 71]);
    await uploadBytes(ref(st, `care/${CHILD}/reservado1/desenho.png`), png, {
      contentType: "image/png",
    });
    await uploadBytes(ref(st, `care/${CHILD}/familia1/exercicio.pdf`), png, {
      contentType: "application/pdf",
    });
  });
});

const newRecord = (overrides) => ({
  clinicId: "clinica-a",
  revision: 1,
  createdAt: serverTimestamp(),
  visibility: "equipe",
  title: "Registro fictício",
  body: "Texto fictício",
  ...overrides,
});

describe("registro reservado", () => {
  test("a psicóloga autora lê", async () => {
    await assertSucceeds(getDoc(doc(db(PSI), `${TEAM}/records/reservado1`)));
  });

  test.each([
    ["pediatra da equipe", PED],
    ["fisioterapeuta da equipe", FIS],
    ["psicólogo da mesma clínica sem vínculo", PSI2],
    ["gestão da clínica", GESTOR],
    ["responsável", ANA],
  ])("%s não lê", async (_, uid) => {
    await assertFails(getDoc(doc(db(uid), `${TEAM}/records/reservado1`)));
  });
});

describe("registro da equipe e da família", () => {
  test("equipe com vínculo lê o registro da equipe", async () => {
    await assertSucceeds(getDoc(doc(db(PED), `${TEAM}/records/equipe1`)));
    await assertSucceeds(getDoc(doc(db(PSI), `${TEAM}/records/equipe1`)));
  });

  test("mesma clínica sem vínculo, gestão e família não leem o registro da equipe", async () => {
    await assertFails(getDoc(doc(db(PSI2), `${TEAM}/records/equipe1`)));
    await assertFails(getDoc(doc(db(GESTOR), `${TEAM}/records/equipe1`)));
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/records/equipe1`)));
  });

  test("família lê o que foi liberado; outra família não", async () => {
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/records/familia1`)));
    await assertFails(getDoc(doc(db(BRUNO), `${TEAM}/records/familia1`)));
  });
});

describe("registros compatíveis com a especialidade", () => {
  test("fisioterapeuta registra evolução da fisioterapia", async () => {
    await assertSucceeds(
      setDoc(
        doc(db(FIS), `${TEAM}/records/novo`),
        newRecord({ authorUid: FIS, specialty: "fisioterapia", kind: "evolucao" })
      )
    );
  });

  test("fisioterapeuta não registra sessão de psicologia nem reservado", async () => {
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x1`),
        newRecord({ authorUid: FIS, specialty: "fisioterapia", kind: "sessao" })
      )
    );
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x2`),
        newRecord({
          authorUid: FIS,
          specialty: "fisioterapia",
          kind: "evolucao",
          visibility: "reservado",
        })
      )
    );
  });

  test("fisioterapeuta não se declara psicóloga", async () => {
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x3`),
        newRecord({ authorUid: FIS, specialty: "psicologia", kind: "sessao" })
      )
    );
  });

  test("psicóloga cria registro reservado", async () => {
    await assertSucceeds(
      setDoc(
        doc(db(PSI), `${TEAM}/records/r2`),
        newRecord({
          authorUid: PSI,
          specialty: "psicologia",
          kind: "sessao",
          visibility: "reservado",
        })
      )
    );
  });

  test("só orientação e atividade para casa vão para a família", async () => {
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x4`),
        newRecord({
          authorUid: FIS,
          specialty: "fisioterapia",
          kind: "evolucao",
          visibility: "familia",
          releasedAt: serverTimestamp(),
        })
      )
    );
  });

  test("sem vínculo não cria registro", async () => {
    await assertFails(
      setDoc(
        doc(db(PSI2), `${TEAM}/records/x5`),
        newRecord({ authorUid: PSI2, specialty: "psicologia", kind: "sessao" })
      )
    );
  });

  test("texto da IA só entra revisado por quem grava", async () => {
    await assertFails(
      setDoc(
        doc(db(PED), `${TEAM}/records/ia1`),
        newRecord({
          authorUid: PED,
          specialty: "pediatria",
          kind: "resumoEquipe",
          aiGenerated: true,
        })
      )
    );
    await assertSucceeds(
      setDoc(
        doc(db(PED), `${TEAM}/records/ia2`),
        newRecord({
          authorUid: PED,
          specialty: "pediatria",
          kind: "resumoEquipe",
          aiGenerated: true,
          reviewedBy: PED,
        })
      )
    );
  });
});

describe("alteração com histórico", () => {
  test("autora altera gravando a revisão no mesmo lote", async () => {
    const fs = db(FIS);
    const batch = writeBatch(fs);
    batch.update(doc(fs, `${TEAM}/records/equipe1`), {
      body: "Evolução corrigida",
      revision: 2,
    });
    batch.set(doc(fs, `${TEAM}/records/equipe1/revisions/2`), {
      actorUid: FIS,
      at: serverTimestamp(),
      note: "Correção",
      previousBody: "Evolução fictícia",
    });
    await assertSucceeds(batch.commit());
  });

  test("sem a revisão, a alteração é recusada", async () => {
    await assertFails(
      updateDoc(doc(db(FIS), `${TEAM}/records/equipe1`), {
        body: "Sem histórico",
        revision: 2,
      })
    );
  });

  test("outro profissional não altera nem troca o autor", async () => {
    const fs = db(PED);
    const batch = writeBatch(fs);
    batch.update(doc(fs, `${TEAM}/records/equipe1`), { body: "x", revision: 2 });
    batch.set(doc(fs, `${TEAM}/records/equipe1/revisions/2`), {
      actorUid: PED,
      at: serverTimestamp(),
      note: "x",
      previousBody: "x",
    });
    await assertFails(batch.commit());
  });

  test("registro não se apaga", async () => {
    await assertFails(deleteDoc(doc(db(FIS), `${TEAM}/records/equipe1`)));
  });
});

describe("vínculo autorizado pela família", () => {
  const pending = (specialty = "psicologia", clinicId = "clinica-a", by = GESTOR) => ({
    specialty,
    clinicId,
    status: "pending",
    reason: "Assume a psicologia (fictício)",
    requestedBy: by,
    since: serverTimestamp(),
  });

  test("gestão designa; só depois da autorização da família há acesso", async () => {
    await assertSucceeds(setDoc(doc(db(GESTOR), `${TEAM}/members/${PSI2}`), pending()));
    await assertFails(getDoc(doc(db(PSI2), `${TEAM}/records/equipe1`)));
    await assertFails(
      updateDoc(doc(db(PSI2), `${TEAM}/members/${PSI2}`), { reason: "Alterado" })
    );
    await assertFails(
      updateDoc(doc(db(PSI2), `${TEAM}/members/${PSI2}`), { status: "active" })
    );
    await assertFails(
      updateDoc(doc(db(PSI2), `${TEAM}/members/${PSI2}`), {
        status: "active",
        authorizedAt: serverTimestamp(),
        authorizedBy: PSI2,
      })
    );
    await assertSucceeds(
      updateDoc(doc(db(ANA), `${TEAM}/members/${PSI2}`), {
        status: "active",
        authorizedAt: serverTimestamp(),
        authorizedBy: ANA,
      })
    );
    await assertSucceeds(getDoc(doc(db(PSI2), `${TEAM}/records/equipe1`)));
    await assertFails(getDoc(doc(db(PSI2), `${TEAM}/records/reservado1`)));
  });

  test("especialidade diferente da conferida e profissional não verificado são recusados", async () => {
    await assertFails(
      setDoc(doc(db(GESTOR), `${TEAM}/members/${PSI2}`), pending("pediatria"))
    );
    await assertFails(
      setDoc(doc(db(GESTOR), `${TEAM}/members/${NAO_VERIFICADO}`), pending())
    );
  });

  test("profissional de outra clínica não se vincula à Clínica A", async () => {
    await assertFails(
      setDoc(
        doc(db(PED_B), `${TEAM}/members/${PED_B}`),
        pending("pediatria", "clinica-a", PED_B)
      )
    );
  });

  test("troca de profissional: vínculo encerrado perde a equipe e mantém os próprios", async () => {
    await assertSucceeds(
      updateDoc(doc(db(GESTOR), `${TEAM}/members/${PSI}`), {
        status: "ended",
        endedAt: serverTimestamp(),
        endedBy: GESTOR,
        endReason: "Troca de profissional",
      })
    );
    await assertSucceeds(getDoc(doc(db(PSI), `${TEAM}/records/reservado1`)));
    await assertFails(getDoc(doc(db(PSI), `${TEAM}/records/equipe1`)));
    await assertFails(
      setDoc(
        doc(db(PSI), `${TEAM}/records/x6`),
        newRecord({ authorUid: PSI, specialty: "psicologia", kind: "sessao" })
      )
    );
  });

  test("troca de clínica: nova equipe não vê os registros da anterior", async () => {
    await assertSucceeds(
      updateDoc(doc(db(ANA), `${TEAM}/members/${PED}`), {
        status: "ended",
        endedAt: serverTimestamp(),
        endedBy: ANA,
        endReason: "Troca de clínica",
      })
    );
    await assertSucceeds(
      setDoc(
        doc(db(PED_B), `${TEAM}/members/${PED_B}`),
        pending("pediatria", "clinica-b", PED_B)
      )
    );
    await assertSucceeds(
      updateDoc(doc(db(ANA), `${TEAM}/members/${PED_B}`), {
        status: "active",
        authorizedAt: serverTimestamp(),
        authorizedBy: ANA,
      })
    );
    await assertFails(getDoc(doc(db(PED), `${TEAM}/records/equipe1`)));
    await assertFails(getDoc(doc(db(PED_B), `${TEAM}/records/equipe1`)));
    await assertFails(getDoc(doc(db(PED_B), `${TEAM}/records/familia1`)));
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/records/familia1`)));
  });
});

describe("comunicação da equipe", () => {
  test("família e mesma clínica sem vínculo não leem mensagens", async () => {
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/messages/msg1`)));
    await assertFails(getDoc(doc(db(PSI2), `${TEAM}/messages/msg1`)));
    await assertSucceeds(getDoc(doc(db(FIS), `${TEAM}/messages/msg1`)));
  });

  test("encaminhamento: psicólogo da clínica lê e aceita; fisioterapeuta não aceita", async () => {
    await assertSucceeds(getDoc(doc(db(PSI2), `${TEAM}/messages/ref1`)));
    await assertFails(
      updateDoc(doc(db(FIS), `${TEAM}/messages/ref1`), {
        status: "aceito",
        statusBy: FIS,
        statusAt: serverTimestamp(),
      })
    );
    await assertSucceeds(
      updateDoc(doc(db(PSI2), `${TEAM}/messages/ref1`), {
        status: "aceito",
        statusBy: PSI2,
        statusAt: serverTimestamp(),
      })
    );
  });

  test("mensagem nova com autor e especialidade do vínculo", async () => {
    const msg = {
      authorUid: FIS,
      authorSpecialty: "fisioterapia",
      clinicId: "clinica-a",
      kind: "parecer",
      toSpecialty: "pediatria",
      status: "aberto",
      at: serverTimestamp(),
      subject: "Parecer",
      body: "Fictício",
    };
    await assertSucceeds(setDoc(doc(db(FIS), `${TEAM}/messages/m2`), msg));
    await assertFails(
      setDoc(doc(db(FIS), `${TEAM}/messages/m3`), { ...msg, authorSpecialty: "pediatria" })
    );
    await assertFails(deleteDoc(doc(db(PED), `${TEAM}/messages/msg1`)));
  });
});

describe("documentos por especialidade", () => {
  const draft = (kind) => ({
    authorUid: PSI,
    specialty: "psicologia",
    clinicId: "clinica-a",
    kind,
    status: "draft",
    createdAt: serverTimestamp(),
  });

  test("psicóloga não prepara receituário nem atestado médico", async () => {
    await assertFails(setDoc(doc(db(PSI), `${TEAM}/documents/d1`), draft("receituario")));
    await assertFails(setDoc(doc(db(PSI), `${TEAM}/documents/d2`), draft("atestadoMedico")));
    await assertSucceeds(
      setDoc(doc(db(PSI), `${TEAM}/documents/d3`), draft("relatorioPsicologico"))
    );
  });

  test("rascunho é da autora; emitido vai à equipe; família só depois de liberado", async () => {
    await assertFails(getDoc(doc(db(PED), `${TEAM}/documents/rascunho`)));
    await assertSucceeds(getDoc(doc(db(PED), `${TEAM}/documents/emitido`)));
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/documents/emitido`)));
    await assertFails(
      updateDoc(doc(db(PSI), `${TEAM}/documents/rascunho`), { status: "issued" })
    );
    await assertSucceeds(
      updateDoc(doc(db(PSI), `${TEAM}/documents/emitido`), {
        releasedAt: serverTimestamp(),
      })
    );
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/documents/emitido`)));
  });
});

describe("trilha de acessos", () => {
  const entry = (uid) => ({
    actorUid: uid,
    action: "visualizou registros",
    target: "Fisioterapia",
    at: serverTimestamp(),
    allowed: true,
    clinicId: "clinica-a",
  });

  test("append-only: grava, não altera, não apaga", async () => {
    await assertSucceeds(setDoc(doc(db(PED), `${TEAM}/access_log/a1`), entry(PED)));
    await assertFails(
      updateDoc(doc(db(PED), `${TEAM}/access_log/a1`), { allowed: false })
    );
    await assertFails(deleteDoc(doc(db(PED), `${TEAM}/access_log/a1`)));
    await assertFails(setDoc(doc(db(PED), `${TEAM}/access_log/a2`), entry(PSI)));
  });

  test("família e gestão leem; profissional não", async () => {
    await assertSucceeds(setDoc(doc(db(PED), `${TEAM}/access_log/a1`), entry(PED)));
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/access_log/a1`)));
    await assertSucceeds(getDoc(doc(db(GESTOR), `${TEAM}/access_log/a1`)));
    await assertFails(getDoc(doc(db(PSI), `${TEAM}/access_log/a1`)));
  });
});

describe("modelos próprios e especialidade conferida", () => {
  test("modelo só do tipo permitido e só o dono lê", async () => {
    await assertFails(
      setDoc(doc(db(PSI), "care_templates/t1"), {
        ownerUid: PSI,
        kind: "receituario",
        title: "x",
      })
    );
    await assertSucceeds(
      setDoc(doc(db(PSI), "care_templates/t2"), {
        ownerUid: PSI,
        kind: "declaracaoComparecimento",
        title: "Comparecimento",
      })
    );
    await assertFails(getDoc(doc(db(FIS), "care_templates/t2")));
  });

  test("profissional não troca a própria especialidade", async () => {
    await assertFails(
      updateDoc(doc(db(PSI), `users/${PSI}`), { careSpecialty: "pediatria" })
    );
  });
});

describe("anexos no Storage", () => {
  const reserved = `care/${CHILD}/reservado1/desenho.png`;
  const released = `care/${CHILD}/familia1/exercicio.pdf`;

  test("anexo de registro reservado: só a autora", async () => {
    await assertSucceeds(getBytes(ref(storage(PSI), reserved)));
    await assertFails(getBytes(ref(storage(PED), reserved)));
    await assertFails(getBytes(ref(storage(FIS), reserved)));
    await assertFails(getBytes(ref(storage(ANA), reserved)));
  });

  test("anexo liberado: a família lê; outra família não", async () => {
    await assertSucceeds(getBytes(ref(storage(ANA), released)));
    await assertFails(getBytes(ref(storage(BRUNO), released)));
  });

  test("só a autora anexa, e só imagem ou PDF", async () => {
    const bytes = new Uint8Array([1, 2, 3]);
    await assertFails(
      uploadBytes(ref(storage(PED), `care/${CHILD}/reservado1/x.pdf`), bytes, {
        contentType: "application/pdf",
      })
    );
    await assertSucceeds(
      uploadBytes(ref(storage(PSI), `care/${CHILD}/reservado1/y.pdf`), bytes, {
        contentType: "application/pdf",
      })
    );
    await assertFails(
      uploadBytes(ref(storage(PSI), `care/${CHILD}/reservado1/z.txt`), bytes, {
        contentType: "text/plain",
      })
    );
  });
});
