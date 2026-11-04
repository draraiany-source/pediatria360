/**
 * Verificacao de Functions no emulador (dados ficticios, projeto demo-).
 *
 * Uso (na raiz do repo, com Java no PATH e functions compiladas):
 *   npm --prefix functions run build
 *   set NODE_PATH=tools/fase10-homolog/node_modules
 *   set FUNCTIONS_DISCOVERY_TIMEOUT=120
 *   firebase emulators:exec --project demo-pediatria360 \
 *     --only functions,firestore,auth,storage \
 *     "node tools/functions-emulator-check/check_lgpd_emr.js"
 *
 * Precisa de functions/.env.local e functions/.secret.local com valores
 * falsos (BUNNY_LIBRARY_ID, BUNNY_CDN_HOSTNAME, ANTHROPIC_API_KEY,
 * BUNNY_STREAM_API_KEY, BUNNY_TOKEN_KEY) so para o emulador carregar.
 *
 * Cobre: grantChildSummaryAccess (dono x agendamento forjado),
 * requestDataDeletion (conta atendimentos assinados da crianca),
 * exportUserData (arquivo inclui prontuario da crianca) e
 * applyVoiceDraftToEncounter (campos ignorados, texto do medico preservado).
 */
const admin = require("firebase-admin");

const PROJECT = process.env.GCLOUD_PROJECT || "demo-pediatria360";
const REGION = "southamerica-east1";
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const FN_HOST = "127.0.0.1:5001";
const SENHA = "Ficticia!2026";

admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();

let falhas = 0;
function check(nome, ok, detalhe) {
  console.log(`${ok ? "PASSOU" : "FALHOU"}  ${nome}${detalhe ? "  -- " + detalhe : ""}`);
  if (!ok) falhas++;
}

async function criarUsuario(uid, email) {
  await admin.auth().createUser({ uid, email, password: SENHA, emailVerified: true });
  const r = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: SENHA, returnSecureToken: true }),
    }
  );
  const j = await r.json();
  if (!j.idToken) throw new Error(`login falhou para ${email}: ${JSON.stringify(j)}`);
  return j.idToken;
}

async function chamar(nome, token, data) {
  const r = await fetch(`http://${FN_HOST}/${PROJECT}/${REGION}/${nome}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  });
  return r.json();
}

async function main() {
  const G = "guardiao-ficticio";
  const P = "medica-ficticia";
  const Q = "outro-profissional-ficticio";
  const KID = "crianca-ficticia-1";

  const tG = await criarUsuario(G, "guardiao@homolog.pediatria360.test");
  const tP = await criarUsuario(P, "medica@homolog.pediatria360.test");
  const tQ = await criarUsuario(Q, "outro@homolog.pediatria360.test");

  await db.doc(`users/${G}`).set({ role: "parent", name: "Responsavel Ficticio", plan: "free" });
  await db.doc(`users/${G}/children/${KID}`).set({ name: "Crianca Ficticia", ownerId: G });
  await db.doc(`child_registry/${KID}`).set({ ownerUid: G });
  for (const uid of [P, Q]) {
    await db.doc(`users/${uid}`).set({ role: "professional", professionalVerified: true, name: uid });
  }
  await db.doc("appointments/ap-ok").set({
    professionalId: P, patientId: G, childId: KID, status: "confirmed", startsAt: new Date(),
  });
  // Agendamento forjado: childId da familia G, mas "responsavel" e o proprio Q.
  await db.doc("appointments/ap-forjado").set({
    professionalId: Q, patientId: Q, childId: KID, status: "confirmed", startsAt: new Date(),
  });
  await db.doc("encounters/enc-assinado").set({
    patientId: KID, professionalId: P, status: "signed", startedAt: new Date(),
  });
  await db.doc("lab_results/lab-1").set({
    patientId: KID, professionalId: P, examName: "Exame ficticio", collectedAt: new Date(),
  });

  // grantChildSummaryAccess
  const okP = await chamar("grantChildSummaryAccess", tP, { childId: KID });
  const conc = await db.doc(`users/${G}/children/${KID}/authorized_professionals/${P}`).get();
  check("grant: medica com agendamento do responsavel", okP.result?.ok === true && conc.exists,
    JSON.stringify(okP));

  const negQ = await chamar("grantChildSummaryAccess", tQ, { childId: KID });
  const concQ = await db.doc(`users/${G}/children/${KID}/authorized_professionals/${Q}`).get();
  check("grant: agendamento forjado e recusado",
    negQ.error?.status === "PERMISSION_DENIED" && !concQ.exists, JSON.stringify(negQ));

  // requestDataDeletion: deve contar o atendimento assinado da crianca.
  const del = await chamar("requestDataDeletion", tG, { reason: "teste ficticio" });
  check("exclusao: conta atendimento assinado da crianca", del.result?.retainedEncounters === 1,
    JSON.stringify(del));
  await chamar("cancelDataDeletion", tG, {});

  // exportUserData: a URL assinada falha no emulador (sem conta de servico);
  // o arquivo e salvo antes e e o que se confere aqui.
  const exp = await chamar("exportUserData", tG, {});
  const [files] = await admin.storage().bucket().getFiles({ prefix: `exports/${G}/` });
  if (files.length === 0) {
    check("exportacao: arquivo gerado", false, JSON.stringify(exp));
  } else {
    const [buf] = await files[0].download();
    const dump = JSON.parse(buf.toString("utf8"));
    const temEnc = (dump.atendimentos || []).some((e) => e._id === "enc-assinado");
    const temLab = (dump.exames || []).some((e) => e._id === "lab-1");
    check("exportacao: inclui atendimento e exame da crianca", temEnc && temLab,
      `atendimentos=${(dump.atendimentos || []).length} exames=${(dump.exames || []).length}`);
    check("exportacao: sem fcmTokens", !("fcmTokens" in (dump.perfil || {})));
  }

  // applyVoiceDraftToEncounter: respeita campos ignorados e o texto do medico.
  await db.doc("encounters/enc-voz").set({
    patientId: KID, professionalId: P, status: "draft",
    anamnesis: { chiefComplaint: "Tosse (digitado pela medica)", allergies: ["Amoxicilina"] },
    plan: "", assessment: "",
  });
  await db.doc("voice_sessions/voz-1").set({
    professionalId: P, childId: KID, encounterId: "enc-voz", status: "draftReady",
    draft: {
      chiefComplaint: "Febre (IA)", allergies: ["Dipirona"],
      assessment: "Avaliacao da IA", plan: "Plano da IA",
    },
  });
  const ap = await chamar("applyVoiceDraftToEncounter", tP, {
    sessionId: "voz-1", ignoredFields: ["assessment", "signedAt"],
  });
  const enc = (await db.doc("encounters/enc-voz").get()).data() || {};
  check("voz: texto da medica mantido e informado ao app",
    enc.anamnesis?.chiefComplaint === "Tosse (digitado pela medica)" &&
      (ap.result?.keptFields || []).includes("chiefComplaint"), JSON.stringify(ap));
  check("voz: campo ignorado nao gravado", enc.assessment === "Nao informado", enc.assessment);
  check("voz: campo aceito gravado", enc.plan === "Plano da IA", enc.plan);
  check("voz: alergias somadas",
    JSON.stringify(enc.anamnesis?.allergies) === JSON.stringify(["Amoxicilina", "Dipirona"]),
    JSON.stringify(enc.anamnesis?.allergies));
  check("voz: continua rascunho e sem assinatura",
    enc.status === "draft" && !enc.signedAt && !enc.signatureHash);
  const negVoz = await chamar("applyVoiceDraftToEncounter", tQ, { sessionId: "voz-1" });
  check("voz: sessao de outro profissional recusada",
    negVoz.error?.status === "PERMISSION_DENIED", JSON.stringify(negVoz));

  console.log(falhas === 0 ? "RESULTADO: tudo passou" : `RESULTADO: ${falhas} falha(s)`);
  process.exit(falhas === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
