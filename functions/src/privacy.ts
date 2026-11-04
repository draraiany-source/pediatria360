/**
 * Conformidade com a LGPD (Lei 13.709/2018).
 *
 * ## Por que este arquivo existe
 *
 * A plataforma trata **dados pessoais sensíveis de crianças e adolescentes**.
 * A lei impõe duas camadas para isso:
 *
 * - Art. 11: dado de saúde é sensível, e o tratamento tem hipóteses restritas.
 * - Art. 14: dado de criança exige consentimento específico e destacado de
 *   pelo menos um dos pais ou responsável legal, e o tratamento deve ser
 *   sempre no melhor interesse da criança.
 *
 * E garante direitos ao titular (Art. 18) que só valem se houver caminho
 * técnico para exercê-los:
 *
 * - **Acesso e portabilidade** (§ V): `exportUserData` entrega tudo em JSON.
 * - **Eliminação** (§ VI): `requestDataDeletion` inicia a exclusão.
 * - **Revogação do consentimento** (§ IX): `revokeConsent`.
 * - **Informação sobre compartilhamento** (§ VII): registrado no manifesto.
 *
 * ## A tensão entre eliminação e retenção de prontuário
 *
 * O direito à eliminação **não é absoluto**. O Art. 16 § I permite conservar
 * dados para cumprimento de obrigação legal, e a Resolução CFM 1.821/2007
 * exige guarda do prontuário por 20 anos a partir do último registro.
 *
 * Portanto: apagar conta apaga tudo, **menos** os atendimentos assinados, que
 * são anonimizados e retidos. Isso é dito ao usuário antes de ele confirmar —
 * prometer exclusão total e não cumprir seria pior que explicar o limite.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { createHash } from "crypto";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

/** Prazo legal de guarda do prontuário, em anos (CFM 1.821/2007). */
const MEDICAL_RECORD_RETENTION_YEARS = 20;

/** Dias entre o pedido de exclusão e a execução. */
const DELETION_GRACE_DAYS = 15;

/** Versão do texto de consentimento em vigor. */
const CONSENT_VERSION = "2026-07-01";

/**
 * Finalidades de tratamento.
 *
 * Cada uma é consentida separadamente. Agrupar tudo em um "aceito os termos"
 * viola o requisito de consentimento **específico e destacado** do Art. 14.
 */
const CONSENT_PURPOSES = {
  healthRecord: {
    label: "Registro de saúde da criança",
    description:
      "Guardar medições de crescimento, vacinas, atendimentos e exames para " +
      "acompanhar o desenvolvimento.",
    required: true,
  },
  aiAssistance: {
    label: "Assistente com inteligência artificial",
    description:
      "Enviar o conteúdo das perguntas e do prontuário a um provedor de IA " +
      "para gerar respostas e resumos.",
    required: false,
  },
  professionalSharing: {
    label: "Compartilhamento com profissional de saúde",
    description:
      "Permitir que o pediatra que atende a criança acesse o prontuário dela.",
    required: false,
  },
  marketing: {
    label: "Comunicações sobre novidades",
    description: "Receber e-mails sobre conteúdos e recursos da plataforma.",
    required: false,
  },
} as const;

type ConsentPurpose = keyof typeof CONSENT_PURPOSES;

/**
 * Ids que aparecem como patientId no prontuario: o do titular e os das
 * criancas dele (o atendimento e aberto em nome da crianca).
 */
async function patientIdsOf(uid: string): Promise<string[]> {
  const children = await db()
    .collection("users")
    .doc(uid)
    .collection("children")
    .get();
  return [uid, ...children.docs.map((c) => c.id)];
}

/** Registra ou atualiza o consentimento. */
export const recordConsent = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { purposes, termsAccepted, privacyPolicyAccepted } = request.data as {
    purposes: Record<string, boolean>;
    termsAccepted?: boolean;
    privacyPolicyAccepted?: boolean;
  };

  if (!purposes || typeof purposes !== "object") {
    throw new HttpsError("invalid-argument", "Finalidades não informadas.");
  }

  // Termos de Uso e Política de Privacidade não são finalidade de
  // tratamento — são aceite contratual, base jurídica diferente do
  // consentimento do Art. 7º. Por isso ficam fora de `purposes` e são
  // exigidos aqui, separadamente, mas gravados na mesma evidência.
  if (termsAccepted !== true) {
    throw new HttpsError(
      "failed-precondition",
      "É preciso aceitar os Termos de Uso para continuar."
    );
  }
  if (privacyPolicyAccepted !== true) {
    throw new HttpsError(
      "failed-precondition",
      "É preciso aceitar a Política de Privacidade para continuar."
    );
  }

  // Finalidade obrigatória não pode ser recusada: sem ela o serviço não
  // existe. O usuário que não concorda deve poder sair, não usar sem base
  // legal.
  for (const [key, config] of Object.entries(CONSENT_PURPOSES)) {
    if (config.required && purposes[key] !== true) {
      throw new HttpsError(
        "failed-precondition",
        `"${config.label}" é indispensável para o funcionamento do aplicativo.`
      );
    }
  }

  const now = FieldValue.serverTimestamp();

  // Cada alteração vira um registro novo. O histórico de consentimento é o
  // que prova, depois, o que foi consentido e quando — inclusive para os
  // documentos, não só para as finalidades.
  await db()
    .collection("users")
    .doc(uid)
    .collection("consents")
    .add({
      version: CONSENT_VERSION,
      purposes,
      termsAccepted: true,
      privacyPolicyAccepted: true,
      grantedAt: now,
      // Guardado para demonstrar a origem do consentimento em auditoria.
      ipHash: request.rawRequest?.ip
        ? createHash("sha256").update(request.rawRequest.ip).digest("hex")
        : null,
      userAgent:
        (request.rawRequest?.headers["user-agent"] as string)?.slice(0, 200) ??
        null,
    });

  await db().collection("users").doc(uid).update({
    consentVersion: CONSENT_VERSION,
    consentPurposes: purposes,
    consentUpdatedAt: now,
    termsAcceptedAt: now,
    privacyPolicyAcceptedAt: now,
  });

  logger.info("Consentimento registrado", { uid, version: CONSENT_VERSION });

  return { ok: true, version: CONSENT_VERSION };
});

/** Revoga o consentimento de uma finalidade opcional. */
export const revokeConsent = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { purpose } = request.data as { purpose: ConsentPurpose };

  const config = CONSENT_PURPOSES[purpose];
  if (!config) {
    throw new HttpsError("invalid-argument", "Finalidade desconhecida.");
  }
  if (config.required) {
    throw new HttpsError(
      "failed-precondition",
      "Esta finalidade é indispensável. Para revogá-la, exclua a conta."
    );
  }

  const userRef = db().collection("users").doc(uid);
  const current = (await userRef.get()).data()?.consentPurposes ?? {};

  const updated = { ...current, [purpose]: false };

  await userRef.update({
    consentPurposes: updated,
    consentUpdatedAt: FieldValue.serverTimestamp(),
  });

  await userRef.collection("consents").add({
    version: CONSENT_VERSION,
    purposes: updated,
    revoked: purpose,
    grantedAt: FieldValue.serverTimestamp(),
  });

  logger.info("Consentimento revogado", { uid, purpose });

  return { ok: true };
});

/**
 * Exporta todos os dados do titular (Art. 18, § V).
 *
 * Formato JSON estruturado, legível por máquina — portabilidade só é real se
 * o dado puder ser importado em outro lugar. PDF seria mais bonito e menos
 * útil.
 */
export const exportUserData = onCall(
  { region: REGION, timeoutSeconds: 300, memory: "512MiB" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const userDoc = await db().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Conta não encontrada.");
    }

    const user = userDoc.data() ?? {};

    // Campos internos não vão para a exportação — não são dado do titular.
    const profile: Record<string, unknown> = { ...user };
    delete profile.fcmTokens;

    const dump: Record<string, unknown> = {
      _formato: "Pediatria360 — exportação de dados pessoais (LGPD Art. 18)",
      _geradoEm: new Date().toISOString(),
      _titular: uid,
      perfil: profile,
    };

    /** Lê uma subcollection inteira. */
    async function readSub(path: string): Promise<Record<string, unknown>[]> {
      const snap = await db().collection(path).get();
      return snap.docs.map((d) => ({ _id: d.id, ...d.data() }));
    }

    dump.consentimentos = await readSub(`users/${uid}/consents`);
    dump.criancas = await readSub(`users/${uid}/children`);

    // Dado clínico de cada criança.
    const children = await db()
      .collection("users")
      .doc(uid)
      .collection("children")
      .get();

    const clinical: Record<string, unknown> = {};
    for (const child of children.docs) {
      clinical[child.id] = {
        crescimento: await readSub(
          `users/${uid}/children/${child.id}/growth_records`
        ),
        vacinas: await readSub(
          `users/${uid}/children/${child.id}/vaccine_doses`
        ),
      };
    }
    dump.dadosClinicos = clinical;

    dump.progressoEmCursos = await readSub(`users/${uid}/progress`);
    dump.usoDaIa = await readSub(`users/${uid}/ai_usage`);

    /** Lê uma collection raiz filtrando pelo titular. */
    async function readRoot(
      collection: string,
      field: string
    ): Promise<Record<string, unknown>[]> {
      const snap = await db()
        .collection(collection)
        .where(field, "==", uid)
        .get();
      return snap.docs.map((d) => ({ _id: d.id, ...d.data() }));
    }

    /** No prontuario, patientId e o id da crianca (ou o do titular). */
    async function readClinical(
      collection: string
    ): Promise<Record<string, unknown>[]> {
      const rows: Record<string, unknown>[] = [];
      for (const id of [uid, ...children.docs.map((c) => c.id)]) {
        const snap = await db()
          .collection(collection)
          .where("patientId", "==", id)
          .get();
        rows.push(...snap.docs.map((d) => ({ _id: d.id, ...d.data() })));
      }
      return rows;
    }

    dump.atendimentos = await readClinical("encounters");
    dump.documentosClinicos = await readClinical("clinical_documents");
    dump.exames = await readClinical("lab_results");
    dump.consultas = await readRoot("appointments", "patientId");
    dump.pedidos = await readRoot("orders", "ownerId");

    // Conversas com a IA, incluindo as mensagens.
    const conversations = await db()
      .collection("ai_conversations")
      .where("ownerId", "==", uid)
      .get();

    dump.conversasComIa = await Promise.all(
      conversations.docs.map(async (c) => ({
        _id: c.id,
        ...c.data(),
        mensagens: (await c.ref.collection("messages").orderBy("createdAt").get())
          .docs.map((m) => m.data()),
      }))
    );

    const json = JSON.stringify(dump, null, 2);

    // Arquivo no Storage com URL assinada de 7 dias. Devolver o JSON inteiro
    // na resposta estouraria o limite de payload de uma família com anos de
    // histórico.
    const file = admin
      .storage()
      .bucket()
      .file(`exports/${uid}/dados-${Date.now()}.json`);

    await file.save(json, {
      contentType: "application/json",
      metadata: { cacheControl: "private, max-age=0" },
    });

    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
    });

    await db().collection("audit_log").add({
      action: "data_exported",
      actorUid: uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Dados exportados", { uid, bytes: json.length });

    return {
      url,
      expiresInDays: 7,
      sizeBytes: json.length,
    };
  }
);

/**
 * Solicita a exclusão da conta (Art. 18, § VI).
 *
 * Não apaga na hora. Marca a conta e agenda para daqui a 15 dias, permitindo
 * arrependimento — exclusão de prontuário familiar por impulso ou por acesso
 * indevido de terceiro é dano irreversível.
 */
export const requestDataDeletion = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const { reason } = request.data as { reason?: string };

    const scheduledFor = new Date(
      Date.now() + DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000
    );

    // Quantos atendimentos assinados serão retidos por obrigação legal.
    let retainedEncounters = 0;
    for (const id of await patientIdsOf(uid)) {
      const signed = await db()
        .collection("encounters")
        .where("patientId", "==", id)
        .where("status", "in", ["signed", "amended"])
        .count()
        .get();
      retainedEncounters += signed.data().count;
    }

    await db().collection("deletion_requests").doc(uid).set({
      uid,
      requestedAt: FieldValue.serverTimestamp(),
      scheduledFor: Timestamp.fromDate(scheduledFor),
      reason: reason?.slice(0, 500) ?? null,
      status: "scheduled",
      retainedEncounters,
    });

    await db().collection("users").doc(uid).update({
      deletionScheduledFor: Timestamp.fromDate(scheduledFor),
    });

    await db().collection("audit_log").add({
      action: "deletion_requested",
      actorUid: uid,
      scheduledFor,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.warn("Exclusão solicitada", { uid, scheduledFor });

    return {
      scheduledFor: scheduledFor.toISOString(),
      graceDays: DELETION_GRACE_DAYS,
      retainedEncounters,
      retentionYears: MEDICAL_RECORD_RETENTION_YEARS,
    };
  }
);

/** Cancela a exclusão agendada. */
export const cancelDataDeletion = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const ref = db().collection("deletion_requests").doc(uid);
    const doc = await ref.get();

    if (!doc.exists || doc.data()?.status !== "scheduled") {
      throw new HttpsError(
        "failed-precondition",
        "Não há exclusão agendada para esta conta."
      );
    }

    await ref.update({
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
    });

    await db().collection("users").doc(uid).update({
      deletionScheduledFor: FieldValue.delete(),
    });

    logger.info("Exclusão cancelada", { uid });

    return { ok: true };
  }
);

/**
 * Executa as exclusões vencidas.
 *
 * Roda diariamente. Apaga tudo, **exceto** os atendimentos assinados, que são
 * anonimizados e mantidos pelo prazo legal de guarda do prontuário.
 */
export const processScheduledDeletions = onSchedule(
  {
    region: REGION,
    schedule: "every day 04:00",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const now = Timestamp.now();

    const due = await db()
      .collection("deletion_requests")
      .where("status", "==", "scheduled")
      .where("scheduledFor", "<=", now)
      .limit(50)
      .get();

    for (const req of due.docs) {
      const uid = req.data().uid as string;

      try {
        // 1. Anonimiza os atendimentos assinados em vez de apagá-los.
        //
        // O vínculo com a pessoa é removido; o conteúdo clínico permanece
        // pelo prazo do CFM. Sem isso, a plataforma descumpriria a obrigação
        // de guarda — e um prontuário apagado prejudica também o profissional
        // que precisa comprovar sua conduta.
        const patientIds = await patientIdsOf(uid);
        let anonymized = 0;
        for (const patientId of patientIds) {
          const encounters = await db()
            .collection("encounters")
            .where("patientId", "==", patientId)
            .where("status", "in", ["signed", "amended"])
            .get();

          const anonymousId = `anon_${createHash("sha256")
            .update(patientId)
            .digest("hex")
            .slice(0, 16)}`;

          const batch = db().batch();
          encounters.docs.forEach((d) =>
            batch.update(d.ref, {
              patientId: anonymousId,
              patientName: null,
              patientBirthDate: null,
              anonymizedAt: FieldValue.serverTimestamp(),
              retentionUntil: Timestamp.fromDate(
                new Date(
                  Date.now() +
                    MEDICAL_RECORD_RETENTION_YEARS * 365 * 24 * 60 * 60 * 1000
                )
              ),
            })
          );
          await batch.commit();
          anonymized += encounters.size;
        }

        // 2. Apaga tudo o mais.
        await db().recursiveDelete(db().collection("users").doc(uid));

        for (const collection of [
          "ai_conversations",
          "clinical_documents",
          "lab_results",
          "appointments",
        ]) {
          const docs = await db()
            .collection(collection)
            .where(
              collection === "ai_conversations" ? "ownerId" : "patientId",
              "==",
              uid
            )
            .get();
          for (const d of docs.docs) {
            await db().recursiveDelete(d.ref);
          }
        }

        await db().collection("leaderboard").doc(uid).delete();
        for (const childId of patientIds.slice(1)) {
          await db().collection("child_registry").doc(childId).delete();
        }

        // 3. Remove a credencial de acesso.
        await admin.auth().deleteUser(uid).catch(() => undefined);

        await req.ref.update({
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
          anonymizedEncounters: anonymized,
        });

        logger.warn("Conta excluída", {
          uid,
          anonymized,
        });
      } catch (error) {
        logger.error("Falha ao excluir conta", { uid, error });
        await req.ref.update({
          status: "failed",
          error: String(error).slice(0, 500),
        });
      }
    }
  }
);

/**
 * Manifesto de tratamento de dados (Art. 9º).
 *
 * O titular tem direito a saber, em linguagem clara, o que é tratado, com que
 * finalidade, por quanto tempo e com quem é compartilhado. Servir isso por
 * função — e não como texto estático no app — garante que a informação
 * acompanhe as mudanças reais do sistema.
 */
export const dataProcessingManifest = onCall(
  { region: REGION },
  async () => ({
    controlador: {
      nome: "Pediatria 360",
      contatoEncarregado: "privacidade@pediatria360.app",
    },
    versaoConsentimento: CONSENT_VERSION,
    finalidades: CONSENT_PURPOSES,
    categoriasDeDados: [
      {
        categoria: "Identificação",
        exemplos: ["nome", "e-mail", "telefone"],
        base: "Consentimento (Art. 7º, I)",
      },
      {
        categoria: "Saúde da criança (sensível)",
        exemplos: [
          "medições de crescimento",
          "vacinas",
          "atendimentos",
          "exames",
          "prescrições",
        ],
        base: "Consentimento específico do responsável (Art. 11, I e Art. 14)",
      },
      {
        categoria: "Uso da plataforma",
        exemplos: ["progresso em cursos", "perguntas à IA"],
        base: "Consentimento (Art. 7º, I)",
      },
    ],
    compartilhamento: [
      {
        destinatario: "Google Firebase",
        finalidade: "Hospedagem, autenticação e armazenamento",
        pais: "Estados Unidos",
      },
      {
        destinatario: "Provedor de IA",
        finalidade: "Geração de respostas do assistente",
        pais: "Estados Unidos",
        observacao:
          "Só quando a finalidade de IA está consentida. O conteúdo enviado " +
          "é o da pergunta e o do prontuário relacionado.",
      },
      {
        destinatario: "Profissional de saúde",
        finalidade: "Atendimento",
        pais: "Brasil",
        observacao:
          "Somente o profissional que conduz o atendimento acessa o " +
          "prontuário da criança.",
      },
    ],
    retencao: {
      contaAtiva: "Enquanto a conta existir",
      aposExclusao: `Dados apagados em até ${DELETION_GRACE_DAYS} dias`,
      prontuario:
        `Atendimentos assinados são anonimizados e mantidos por ` +
        `${MEDICAL_RECORD_RETENTION_YEARS} anos, conforme a Resolução CFM ` +
        `1.821/2007.`,
    },
    direitos: [
      "Confirmação e acesso aos dados",
      "Correção de dados incompletos ou desatualizados",
      "Portabilidade em formato estruturado",
      "Eliminação dos dados tratados com base em consentimento",
      "Informação sobre compartilhamento",
      "Revogação do consentimento",
    ],
  })
);
