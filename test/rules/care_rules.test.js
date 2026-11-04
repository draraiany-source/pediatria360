/**
 * Regras do cuidado multidisciplinar (care_teams e care/ no Storage), com
 * compartilhamento seletivo: o registro completo é do autor; a equipe recebe
 * só o resumo que o autor escolheu e endereçou.
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
const DAY = 24 * 60 * 60 * 1000;

const SESSION = `${TEAM}/records/sessao1`;
const SUMMARY = `${TEAM}/summaries/sessao1`;
const PRIVATE_FILE = `care/${CHILD}/registros/${PSI}/sessao1/desenho.png`;
const FAMILY_FILE = `care/${CHILD}/familia/familia1/exercicio.pdf`;
const PNG = new Uint8Array([137, 80, 78, 71]);

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

function endLink(by, uid, reason = "Encerramento fictício") {
  return updateDoc(doc(db(by), `${TEAM}/members/${uid}`), {
    status: "ended",
    endedAt: serverTimestamp(),
    endedBy: by,
    endReason: reason,
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
    // Sessão privada da psicóloga, com partes clínica, privada e transcrição.
    await setDoc(doc(fs, SESSION), {
      ...base,
      authorUid: PSI,
      specialty: "psicologia",
      kind: "sessao",
      visibility: "privado",
      title: "Sessão (fictícia)",
      body: "Evolução completa fictícia",
    });
    const section = (kind, text) => ({ kind, label: kind, text, createdAt: Timestamp.now() });
    await setDoc(doc(fs, `${SESSION}/sections/clin`), section("clinica", "Conteúdo clínico fictício"));
    await setDoc(doc(fs, `${SESSION}/sections/priv`), section("anotacaoPrivada", "Anotação privada fictícia"));
    await setDoc(doc(fs, `${SESSION}/sections/trans`), section("transcricao", "Transcrição fictícia"));

    await setDoc(doc(fs, `${TEAM}/records/fis1`), {
      ...base,
      authorUid: FIS,
      specialty: "fisioterapia",
      kind: "evolucao",
      visibility: "privado",
      body: "Evolução fictícia da fisioterapia",
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
    await setDoc(doc(fs, `${TEAM}/plan/clinica-a/goals/g1`), {
      objective: "Equilíbrio em um pé por 10 segundos (fictício)",
      responsibleUid: FIS,
      responsibleSpecialty: "fisioterapia",
      dueDate: Timestamp.fromMillis(Date.now() + 45 * DAY),
      reassessAt: Timestamp.fromMillis(Date.now() + 15 * DAY),
      status: "emAndamento",
      reassessCount: 0,
      createdBy: FIS,
      createdAt: Timestamp.now(),
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
    await uploadBytes(ref(st, PRIVATE_FILE), PNG, { contentType: "image/png" });
    await uploadBytes(ref(st, FAMILY_FILE), PNG, { contentType: "application/pdf" });
  });
});

// ------------------------------------------------------------- auxiliares

const summaryData = (overrides = {}) => ({
  authorUid: PSI,
  clinicId: "clinica-a",
  specialty: "psicologia",
  recordTitle: "Sessão (fictícia)",
  status: "publicado",
  audience: "selecionados",
  recipients: [PED],
  items: [{ label: "Conteúdo clínico", text: "Resumo fictício para a equipe" }],
  attachments: [],
  note: "",
  version: 1,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const versionOf = (s, uid) => ({
  version: s.version,
  actorUid: uid,
  at: serverTimestamp(),
  status: s.status,
  audience: s.audience,
  recipients: s.recipients,
  items: s.items,
  attachments: s.attachments,
  ...(s.reason ? { reason: s.reason } : {}),
});

/** Publica a versão 1 no mesmo lote que o histórico. */
function publish(uid = PSI, rid = "sessao1", overrides = {}) {
  const fs = db(uid);
  const s = summaryData(overrides);
  const b = writeBatch(fs);
  b.set(doc(fs, `${TEAM}/summaries/${rid}`), s);
  b.set(doc(fs, `${TEAM}/summaries/${rid}/versions/${s.version}`), versionOf(s, uid));
  return b.commit();
}

/** Atualiza ou encerra: muda só os campos indicados e grava a versão. */
function revise(uid, changes, current, rid = "sessao1", { withVersion = true } = {}) {
  const fs = db(uid);
  const next = { ...summaryData(current), ...changes };
  const b = writeBatch(fs);
  const { reason, ...fields } = changes;
  b.update(doc(fs, `${TEAM}/summaries/${rid}`), { ...fields, updatedAt: serverTimestamp() });
  if (withVersion) {
    b.set(
      doc(fs, `${TEAM}/summaries/${rid}/versions/${next.version}`),
      versionOf({ ...next, reason }, uid)
    );
  }
  return b.commit();
}

const grantData = (overrides = {}) => ({
  granteeUid: PED,
  clinicId: "clinica-a",
  justification: "Avaliar a medicação em uso (fictício)",
  grantedAt: serverTimestamp(),
  grantedBy: PSI,
  round: 1,
  ...overrides,
});

const grant = (uid = PSI, grantee = PED, overrides = {}) =>
  setDoc(
    doc(db(uid), `${SESSION}/grants/${grantee}`),
    grantData({ granteeUid: grantee, grantedBy: uid, ...overrides })
  );

const revoke = (uid = PSI, grantee = PED) =>
  updateDoc(doc(db(uid), `${SESSION}/grants/${grantee}`), {
    revokedAt: serverTimestamp(),
    revokedBy: uid,
    revokeReason: "Avaliação concluída (fictício)",
  });

const readAll = (uid) => ({
  record: () => getDoc(doc(db(uid), SESSION)),
  clinical: () => getDoc(doc(db(uid), `${SESSION}/sections/clin`)),
  privateNote: () => getDoc(doc(db(uid), `${SESSION}/sections/priv`)),
  transcript: () => getDoc(doc(db(uid), `${SESSION}/sections/trans`)),
  file: () => getBytes(ref(storage(uid), PRIVATE_FILE)),
});

async function expectNoFullRecord(uid) {
  const r = readAll(uid);
  await assertFails(r.record());
  await assertFails(r.clinical());
  await assertFails(r.privateNote());
  await assertFails(r.transcript());
  await assertFails(r.file());
}

const newRecord = (overrides) => ({
  clinicId: "clinica-a",
  revision: 1,
  createdAt: serverTimestamp(),
  visibility: "privado",
  title: "Registro fictício",
  body: "Texto fictício",
  ...overrides,
});

// ------------------------------------------------- cenário pedido no teste

describe("cenário: psicóloga, pediatra, fisioterapeuta e família", () => {
  test("1. a psicóloga registra a sessão privada: só ela lê registro, partes e anexo", async () => {
    const r = readAll(PSI);
    await assertSucceeds(r.record());
    await assertSucceeds(r.clinical());
    await assertSucceeds(r.privateNote());
    await assertSucceeds(r.transcript());
    await assertSucceeds(r.file());
    for (const uid of [PED, FIS, PSI2, GESTOR, PED_B, ANA]) {
      await expectNoFullRecord(uid);
    }
  });

  test("2. a psicóloga compartilha só um resumo com o pediatra", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(getDoc(doc(db(PED), SUMMARY)));
    await expectNoFullRecord(PED);
  });

  test("3. a fisioterapeuta não lê o resumo endereçado só ao pediatra", async () => {
    await assertSucceeds(publish());
    for (const uid of [FIS, PSI2, GESTOR, PED_B, ANA, BRUNO]) {
      await assertFails(getDoc(doc(db(uid), SUMMARY)));
    }
  });

  test("4. a fisioterapeuta vê apenas o que foi compartilhado com ela", async () => {
    await assertSucceeds(publish());
    await assertFails(getDoc(doc(db(FIS), SUMMARY)));
    await assertSucceeds(revise(PSI, { recipients: [PED, FIS], version: 2 }, {}));
    await assertSucceeds(getDoc(doc(db(FIS), SUMMARY)));
    await expectNoFullRecord(FIS);
    // O resumo da fisioterapeuta, endereçado ao pediatra, não chega à psicóloga.
    await assertSucceeds(
      publish(FIS, "fis1", {
        authorUid: FIS,
        specialty: "fisioterapia",
        recordTitle: "Evolução (fictícia)",
        recipients: [PED],
      })
    );
    await assertSucceeds(getDoc(doc(db(PED), `${TEAM}/summaries/fis1`)));
    await assertFails(getDoc(doc(db(PSI), `${TEAM}/summaries/fis1`)));
  });

  test("5. a família vê somente as orientações liberadas", async () => {
    await assertSucceeds(publish(PSI, "sessao1", { recipients: [PED, FIS] }));
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/records/familia1`)));
    await assertSucceeds(getBytes(ref(storage(ANA), FAMILY_FILE)));
    await assertFails(getDoc(doc(db(ANA), SUMMARY)));
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/records/fis1`)));
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/plan/clinica-a/goals/g1`)));
    await assertFails(getDoc(doc(db(ANA), `${TEAM}/documents/emitido`)));
    await expectNoFullRecord(ANA);
    await assertFails(getDoc(doc(db(BRUNO), `${TEAM}/records/familia1`)));
    await assertFails(getBytes(ref(storage(BRUNO), FAMILY_FILE)));
  });

  test("6. retirada do acesso: o pediatra deixa de ler e as versões ficam no histórico", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(getDoc(doc(db(PED), SUMMARY)));
    await assertSucceeds(
      revise(PSI, { status: "encerrado", version: 2, reason: "Conduta revista" }, {})
    );
    await assertFails(getDoc(doc(db(PED), SUMMARY)));
    await assertSucceeds(getDoc(doc(db(PSI), SUMMARY)));
    await assertSucceeds(getDoc(doc(db(PSI), `${SUMMARY}/versions/1`)));
    await assertSucceeds(getDoc(doc(db(PSI), `${SUMMARY}/versions/2`)));
    await assertFails(getDoc(doc(db(PED), `${SUMMARY}/versions/1`)));
    await assertFails(
      setDoc(doc(db(PED), `${SUMMARY}/access/depois`), {
        readerUid: PED,
        at: serverTimestamp(),
        version: 2,
      })
    );
    await assertFails(deleteDoc(doc(db(PSI), SUMMARY)));
    await assertFails(deleteDoc(doc(db(PSI), `${SUMMARY}/versions/1`)));
    await assertFails(updateDoc(doc(db(PSI), `${SUMMARY}/versions/1`), { items: [] }));
  });

  test("7. republicar depois de encerrar volta a liberar, em nova versão", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(revise(PSI, { status: "encerrado", version: 2 }, {}));
    await assertSucceeds(revise(PSI, { status: "publicado", version: 3 }, { version: 2 }));
    await assertSucceeds(getDoc(doc(db(PED), SUMMARY)));
  });

  test("8. vínculo encerrado também retira a leitura do resumo", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(endLink(GESTOR, PED));
    await assertFails(getDoc(doc(db(PED), SUMMARY)));
  });
});

describe("quem compartilhou, com quem, quando e quem acessou", () => {
  const access = (uid, overrides = {}) =>
    setDoc(doc(db(uid), `${SUMMARY}/access/${uid}-1`), {
      readerUid: uid,
      at: serverTimestamp(),
      version: 1,
      ...overrides,
    });

  test("o destinatário grava o próprio acesso; só a autora consulta", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(access(PED));
    await assertSucceeds(getDoc(doc(db(PSI), `${SUMMARY}/access/${PED}-1`)));
    await assertFails(getDoc(doc(db(PED), `${SUMMARY}/access/${PED}-1`)));
    await assertFails(getDoc(doc(db(FIS), `${SUMMARY}/access/${PED}-1`)));
    await assertFails(
      updateDoc(doc(db(PED), `${SUMMARY}/access/${PED}-1`), { version: 9 })
    );
    await assertFails(deleteDoc(doc(db(PSI), `${SUMMARY}/access/${PED}-1`)));
  });

  test("não se grava acesso em nome de outro, de versão antiga ou sem ser destinatário", async () => {
    await assertSucceeds(publish());
    await assertFails(access(PED, { readerUid: PSI }));
    await assertFails(access(PED, { version: 2 }));
    await assertFails(access(FIS));
  });

  test("a versão guarda quem compartilhou, com quem e quando", async () => {
    await assertSucceeds(publish());
    const v = await getDoc(doc(db(PSI), `${SUMMARY}/versions/1`));
    expect(v.get("actorUid")).toBe(PSI);
    expect(v.get("recipients")).toEqual([PED]);
    expect(v.get("at")).toBeInstanceOf(Timestamp);
  });
});

describe("resumo: só o autor publica, com versão e destinatários", () => {
  test("outro profissional não publica nem altera o resumo da psicóloga", async () => {
    await assertFails(publish(PED, "sessao1", { authorUid: PED }));
    await assertSucceeds(publish());
    await assertFails(revise(FIS, { recipients: [PED, FIS], version: 2 }, {}));
    await assertFails(revise(PED, { status: "encerrado", version: 2 }, {}));
  });

  test("sem a versão no mesmo lote, ou pulando versão, é recusado", async () => {
    await assertFails(setDoc(doc(db(PSI), SUMMARY), summaryData()));
    await assertSucceeds(publish());
    await assertFails(revise(PSI, { version: 3 }, {}));
    await assertFails(revise(PSI, { version: 2 }, {}, "sessao1", { withVersion: false }));
  });

  test("destinatários: ao menos um, sem o próprio autor", async () => {
    await assertFails(publish(PSI, "sessao1", { recipients: [] }));
    await assertFails(publish(PSI, "sessao1", { recipients: [PSI, PED] }));
  });

  test("campos fora do resumo e texto da IA sem revisão são recusados", async () => {
    await assertFails(publish(PSI, "sessao1", { privateNotes: "não deveria ir" }));
    await assertFails(publish(PSI, "sessao1", { aiAssisted: true }));
    await assertSucceeds(publish(PSI, "sessao1", { aiAssisted: true, reviewedBy: PSI }));
  });

  test("encerrar vale mesmo com o vínculo da autora encerrado; atualizar não", async () => {
    await assertSucceeds(publish());
    await assertSucceeds(endLink(GESTOR, PSI));
    await assertFails(revise(PSI, { recipients: [PED, FIS], version: 2 }, {}));
    await assertSucceeds(revise(PSI, { status: "encerrado", version: 2 }, {}));
  });

  test("destinatário de outra clínica não lê, mesmo listado", async () => {
    await assertSucceeds(publish(PSI, "sessao1", { recipients: [PED, PED_B, PSI2] }));
    await assertFails(getDoc(doc(db(PED_B), SUMMARY)));
    await assertFails(getDoc(doc(db(PSI2), SUMMARY)));
  });
});

describe("acesso ao registro completo concedido com justificativa", () => {
  test("só a autora concede, com justificativa, a colega com vínculo ativo", async () => {
    await assertFails(grant(PSI, PED, { justification: "curta" }));
    await assertFails(grant(PSI, PSI2));
    await assertFails(grant(PSI, PED_B));
    await assertFails(grant(PSI, PSI));
    await assertFails(grant(PED, PED));
    await assertFails(grant(FIS, PED));
    await assertFails(grant(PSI, PED, { clinicId: "clinica-b" }));
    await assertSucceeds(grant(PSI, PED));
  });

  test("com acesso: registro, parte clínica e anexo; nunca anotação privada nem transcrição", async () => {
    await assertSucceeds(grant(PSI, PED));
    const r = readAll(PED);
    await assertSucceeds(r.record());
    await assertSucceeds(r.clinical());
    await assertFails(r.privateNote());
    await assertFails(r.transcript());
    await assertSucceeds(r.file());
    await expectNoFullRecord(FIS);
    await assertSucceeds(getDoc(doc(db(PED), `${SESSION}/grants/${PED}`)));
    await assertFails(getDoc(doc(db(FIS), `${SESSION}/grants/${PED}`)));
  });

  test("retirada: o pediatra perde registro e anexo; só a autora retira", async () => {
    await assertSucceeds(grant(PSI, PED));
    await assertFails(revoke(PED, PED));
    await assertFails(deleteDoc(doc(db(PSI), `${SESSION}/grants/${PED}`)));
    await assertSucceeds(revoke(PSI, PED));
    await expectNoFullRecord(PED);
    const g = await getDoc(doc(db(PSI), `${SESSION}/grants/${PED}`));
    expect(g.get("revokedBy")).toBe(PSI);
    expect(g.get("justification")).toBe("Avaliar a medicação em uso (fictício)");
  });

  test("nova concessão guarda a anterior no histórico", async () => {
    await assertSucceeds(grant(PSI, PED));
    await assertSucceeds(revoke(PSI, PED));
    await assertFails(grant(PSI, PED, { round: 2 }));
    const fs = db(PSI);
    const b = writeBatch(fs);
    b.set(doc(fs, `${SESSION}/grants/${PED}/history/1`), {
      justification: "Avaliar a medicação em uso (fictício)",
      grantedAt: Timestamp.now(),
      revokedAt: Timestamp.now(),
      revokedBy: PSI,
      revokeReason: "Avaliação concluída (fictício)",
    });
    b.set(doc(fs, `${SESSION}/grants/${PED}`), grantData({ round: 2 }));
    await assertSucceeds(b.commit());
    await assertSucceeds(getDoc(doc(db(PED), SESSION)));
  });

  test("acesso concedido não sobrevive ao fim do vínculo de quem recebeu", async () => {
    await assertSucceeds(grant(PSI, PED));
    await assertSucceeds(endLink(ANA, PED));
    await expectNoFullRecord(PED);
  });
});

describe("registros privados por padrão", () => {
  test("fisioterapeuta registra evolução privada da fisioterapia", async () => {
    await assertSucceeds(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x1`),
        newRecord({ authorUid: FIS, specialty: "fisioterapia", kind: "evolucao" })
      )
    );
    await assertFails(getDoc(doc(db(PED), `${TEAM}/records/x1`)));
  });

  test("visibilidades antigas (equipe, reservado) não existem mais", async () => {
    for (const visibility of ["equipe", "reservado"]) {
      await assertFails(
        setDoc(
          doc(db(PSI), `${TEAM}/records/v-${visibility}`),
          newRecord({ authorUid: PSI, specialty: "psicologia", kind: "sessao", visibility })
        )
      );
    }
  });

  test("tipo e especialidade conferem com o vínculo", async () => {
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x2`),
        newRecord({ authorUid: FIS, specialty: "fisioterapia", kind: "sessao" })
      )
    );
    await assertFails(
      setDoc(
        doc(db(FIS), `${TEAM}/records/x3`),
        newRecord({ authorUid: FIS, specialty: "psicologia", kind: "sessao" })
      )
    );
    await assertFails(
      setDoc(
        doc(db(PSI), `${TEAM}/records/x4`),
        newRecord({ authorUid: PSI, specialty: "psicologia", kind: "resumoEquipe" })
      )
    );
  });

  test("só orientação e atividade para casa vão para a família", async () => {
    await assertFails(
      setDoc(
        doc(db(PSI), `${TEAM}/records/x5`),
        newRecord({ authorUid: PSI, specialty: "psicologia", kind: "sessao", visibility: "familia" })
      )
    );
    await assertSucceeds(
      setDoc(
        doc(db(PSI), `${TEAM}/records/x6`),
        newRecord({
          authorUid: PSI,
          specialty: "psicologia",
          kind: "orientacao",
          visibility: "familia",
        })
      )
    );
  });

  test("sem vínculo não cria registro; texto da IA só entra revisado", async () => {
    await assertFails(
      setDoc(
        doc(db(PSI2), `${TEAM}/records/x7`),
        newRecord({ authorUid: PSI2, specialty: "psicologia", kind: "sessao" })
      )
    );
    const ai = newRecord({
      authorUid: PSI,
      specialty: "psicologia",
      kind: "sessao",
      aiGenerated: true,
    });
    await assertFails(setDoc(doc(db(PSI), `${TEAM}/records/x8`), ai));
    await assertSucceeds(
      setDoc(doc(db(PSI), `${TEAM}/records/x9`), { ...ai, reviewedBy: PSI })
    );
  });

  test("partes do registro: só a autora cria e altera", async () => {
    const part = (kind) => ({ kind, label: "Parte", text: "Fictício", createdAt: serverTimestamp() });
    await assertSucceeds(setDoc(doc(db(PSI), `${SESSION}/sections/nova`), part("conversa")));
    await assertFails(setDoc(doc(db(PSI), `${SESSION}/sections/outra`), part("resumo")));
    await assertFails(setDoc(doc(db(PED), `${SESSION}/sections/ped`), part("clinica")));
    await assertFails(
      updateDoc(doc(db(PSI), `${SESSION}/sections/priv`), { kind: "clinica" })
    );
    await assertSucceeds(
      updateDoc(doc(db(PSI), `${SESSION}/sections/priv`), { text: "Atualizada (fictícia)" })
    );
    await assertFails(deleteDoc(doc(db(PSI), `${SESSION}/sections/priv`)));
  });
});

describe("alteração com histórico", () => {
  test("autora altera gravando a revisão no mesmo lote", async () => {
    const fs = db(PSI);
    const b = writeBatch(fs);
    b.update(doc(fs, SESSION), { body: "Novo texto fictício", revision: 2 });
    b.set(doc(fs, `${SESSION}/revisions/2`), {
      actorUid: PSI,
      at: serverTimestamp(),
      note: "Correção",
      previousBody: "Evolução completa fictícia",
    });
    await assertSucceeds(b.commit());
    await assertFails(getDoc(doc(db(PED), `${SESSION}/revisions/2`)));
  });

  test("sem a revisão, a alteração é recusada; outro profissional não altera", async () => {
    await assertFails(updateDoc(doc(db(PSI), SESSION), { body: "x", revision: 2 }));
    await assertFails(updateDoc(doc(db(PED), SESSION), { body: "x", revision: 2 }));
    await assertFails(updateDoc(doc(db(PSI), SESSION), { authorUid: PED, revision: 2 }));
  });

  test("registro não se apaga", async () => {
    await assertFails(deleteDoc(doc(db(PSI), SESSION)));
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

  test("gestão designa; só depois da autorização da família há equipe, e vínculo não abre registros", async () => {
    await assertSucceeds(setDoc(doc(db(GESTOR), `${TEAM}/members/${PSI2}`), pending()));
    await assertFails(getDoc(doc(db(PSI2), `${TEAM}/messages/msg1`)));
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
    await assertSucceeds(getDoc(doc(db(PSI2), `${TEAM}/messages/msg1`)));
    await assertSucceeds(getDoc(doc(db(PSI2), `${TEAM}/plan/clinica-a/goals/g1`)));
    await expectNoFullRecord(PSI2);
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
    await assertSucceeds(endLink(GESTOR, PSI, "Troca de profissional"));
    await assertSucceeds(getDoc(doc(db(PSI), SESSION)));
    await assertSucceeds(getDoc(doc(db(PSI), `${SESSION}/sections/priv`)));
    await assertSucceeds(getBytes(ref(storage(PSI), PRIVATE_FILE)));
    await assertFails(getDoc(doc(db(PSI), `${TEAM}/messages/msg1`)));
    await assertFails(getDoc(doc(db(PSI), `${TEAM}/plan/clinica-a/goals/g1`)));
    await assertFails(
      setDoc(
        doc(db(PSI), `${TEAM}/records/x10`),
        newRecord({ authorUid: PSI, specialty: "psicologia", kind: "sessao" })
      )
    );
  });

  test("troca de clínica: nova equipe não vê resumos, plano nem registros da anterior", async () => {
    await assertSucceeds(publish(PSI, "sessao1", { recipients: [PED, FIS] }));
    await assertSucceeds(endLink(ANA, PED, "Troca de clínica"));
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
    await assertFails(getDoc(doc(db(PED), SUMMARY)));
    await assertFails(getDoc(doc(db(PED_B), SUMMARY)));
    await assertFails(getDoc(doc(db(PED_B), `${TEAM}/plan/clinica-a/goals/g1`)));
    await assertFails(getDoc(doc(db(PED_B), `${TEAM}/records/familia1`)));
    await expectNoFullRecord(PED_B);
    await assertSucceeds(getDoc(doc(db(ANA), `${TEAM}/records/familia1`)));
  });
});

describe("plano terapêutico conjunto", () => {
  const GOAL = `${TEAM}/plan/clinica-a/goals/g1`;
  const goal = (overrides = {}) => ({
    objective: "Dormir no próprio quarto (fictício)",
    responsibleUid: PSI,
    responsibleSpecialty: "psicologia",
    dueDate: Timestamp.fromMillis(Date.now() + 60 * DAY),
    reassessAt: Timestamp.fromMillis(Date.now() + 20 * DAY),
    status: "emAndamento",
    reassessCount: 0,
    createdBy: PED,
    createdAt: serverTimestamp(),
    ...overrides,
  });

  test("objetivo com responsável da equipe, prazo e reavaliação", async () => {
    const goals = `${TEAM}/plan/clinica-a/goals`;
    await assertSucceeds(setDoc(doc(db(PED), `${goals}/g2`), goal()));
    await assertFails(setDoc(doc(db(PED), `${goals}/g3`), goal({ responsibleUid: PSI2 })));
    await assertFails(
      setDoc(doc(db(PED), `${goals}/g4`), goal({ responsibleSpecialty: "pediatria" }))
    );
    await assertFails(
      setDoc(
        doc(db(PED), `${goals}/g5`),
        goal({ dueDate: Timestamp.fromMillis(Date.now() - DAY) })
      )
    );
    await assertFails(
      setDoc(
        doc(db(PED), `${goals}/g6`),
        goal({ reassessAt: Timestamp.fromMillis(Date.now() + 90 * DAY) })
      )
    );
    await assertFails(setDoc(doc(db(PSI2), `${goals}/g7`), goal({ createdBy: PSI2 })));
    await assertFails(setDoc(doc(db(PED), `${TEAM}/plan/clinica-a`), { text: "Plano" }));
  });

  test("cada profissional contribui com o que escolhe escrever, em nome próprio", async () => {
    const contribution = (uid, specialty, overrides = {}) => ({
      authorUid: uid,
      authorSpecialty: specialty,
      kind: "informacao",
      text: "Informação compartilhada (fictícia)",
      at: serverTimestamp(),
      ...overrides,
    });
    await assertSucceeds(
      setDoc(doc(db(PED), `${GOAL}/contributions/c1`), contribution(PED, "pediatria"))
    );
    await assertFails(
      setDoc(doc(db(FIS), `${GOAL}/contributions/c2`), contribution(PED, "pediatria"))
    );
    await assertFails(
      setDoc(doc(db(FIS), `${GOAL}/contributions/c3`), contribution(FIS, "psicologia"))
    );
    await assertFails(
      setDoc(
        doc(db(FIS), `${GOAL}/contributions/c4`),
        contribution(FIS, "fisioterapia", { kind: "registroCompleto" })
      )
    );
    await assertSucceeds(getDoc(doc(db(PSI), `${GOAL}/contributions/c1`)));
    await assertFails(getDoc(doc(db(ANA), `${GOAL}/contributions/c1`)));
    await assertFails(
      updateDoc(doc(db(PED), `${GOAL}/contributions/c1`), { text: "Alterado" })
    );
  });

  test("só a responsável reavalia, gravando a reavaliação no mesmo lote", async () => {
    const reassess = (uid, { withEntry = true } = {}) => {
      const fs = db(uid);
      const b = writeBatch(fs);
      b.update(doc(fs, GOAL), {
        status: "revisar",
        reassessAt: Timestamp.fromMillis(Date.now() + 30 * DAY),
        reassessCount: 1,
      });
      if (withEntry) {
        b.set(doc(fs, `${GOAL}/reassessments/1`), {
          actorUid: uid,
          at: serverTimestamp(),
          status: "revisar",
          note: "Ajustar frequência (fictício)",
          nextReassessAt: Timestamp.fromMillis(Date.now() + 30 * DAY),
        });
      }
      return b.commit();
    };
    await assertFails(reassess(PED));
    await assertFails(reassess(FIS, { withEntry: false }));
    await assertSucceeds(reassess(FIS));
    await assertFails(updateDoc(doc(db(FIS), GOAL), { objective: "Outro" }));
    await assertFails(deleteDoc(doc(db(FIS), GOAL)));
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

  test("documentos são da autora; a equipe não lê; a família só depois de liberado", async () => {
    await assertFails(getDoc(doc(db(PED), `${TEAM}/documents/rascunho`)));
    await assertFails(getDoc(doc(db(PED), `${TEAM}/documents/emitido`)));
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
    await assertFails(getDoc(doc(db(PED), `${TEAM}/documents/emitido`)));
  });
});

describe("trilha de acessos", () => {
  const entry = (uid) => ({
    actorUid: uid,
    action: "acessou resumo",
    target: "Sessão (fictícia)",
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

describe("arquivos no Storage", () => {
  const bytes = new Uint8Array([1, 2, 3]);
  const pdf = { contentType: "application/pdf" };

  test("anexo privado: só a autora envia, no próprio caminho e no próprio registro", async () => {
    await assertSucceeds(
      uploadBytes(ref(storage(PSI), `care/${CHILD}/registros/${PSI}/sessao1/y.pdf`), bytes, pdf)
    );
    await assertFails(
      uploadBytes(ref(storage(PED), `care/${CHILD}/registros/${PSI}/sessao1/x.pdf`), bytes, pdf)
    );
    await assertFails(
      uploadBytes(ref(storage(PSI), `care/${CHILD}/registros/${PSI}/fis1/x.pdf`), bytes, pdf)
    );
    await assertFails(
      uploadBytes(ref(storage(PSI), `care/${CHILD}/registros/${PSI}/sessao1/z.txt`), bytes, {
        contentType: "text/plain",
      })
    );
    await assertFails(uploadBytes(ref(storage(PSI), PRIVATE_FILE), bytes, pdf));
  });

  test("material da família: o autor e a responsável leem; mais ninguém", async () => {
    await assertSucceeds(getBytes(ref(storage(FIS), FAMILY_FILE)));
    await assertSucceeds(getBytes(ref(storage(ANA), FAMILY_FILE)));
    await assertFails(getBytes(ref(storage(BRUNO), FAMILY_FILE)));
    await assertFails(getBytes(ref(storage(PED), FAMILY_FILE)));
  });

  test("anexo copiado para o resumo: só destinatário, só o escolhido, só enquanto publicado", async () => {
    const copy = `care/${CHILD}/resumos/sessao1/1/desenho-copia.png`;
    const other = `care/${CHILD}/resumos/sessao1/1/outro.png`;
    await assertFails(uploadBytes(ref(storage(PED), copy), PNG, { contentType: "image/png" }));
    await assertSucceeds(uploadBytes(ref(storage(PSI), copy), PNG, { contentType: "image/png" }));
    await assertSucceeds(uploadBytes(ref(storage(PSI), other), PNG, { contentType: "image/png" }));
    await assertSucceeds(publish(PSI, "sessao1", { attachments: ["desenho-copia.png"] }));
    await assertSucceeds(getBytes(ref(storage(PED), copy)));
    await assertFails(getBytes(ref(storage(PED), other)));
    await assertFails(getBytes(ref(storage(FIS), copy)));
    await assertFails(getBytes(ref(storage(ANA), copy)));
    await assertSucceeds(
      revise(PSI, { status: "encerrado", version: 2 }, { attachments: ["desenho-copia.png"] })
    );
    await assertFails(getBytes(ref(storage(PED), copy)));
    await assertSucceeds(getBytes(ref(storage(PSI), copy)));
  });
});
