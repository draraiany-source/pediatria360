/**
 * Cloud Functions do Pediatria 360.
 *
 * A IA roda inteiramente aqui, nunca no aplicativo. Três motivos:
 *
 * 1. A chave do provedor não pode ser embutida num app publicado — extrair uma
 *    chave de um APK leva minutos.
 * 2. Cota por usuário só é confiável se contada no servidor.
 * 3. O prompt de sistema (com os protocolos revisados e as regras de segurança)
 *    precisa ser inviolável. No cliente, qualquer um o substitui.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();
const db = admin.firestore();

// Integração com o Bunny.net (streaming de vídeo).
export {
  createBunnyVideo,
  getBunnyVideo,
  signBunnyPlayback,
  deleteBunnyVideo,
  bunnyWebhook,
} from "./bunny";

// Marketplace e telemedicina.
export {
  quoteOrder,
  createOrder,
  getAvailability,
  bookAppointment,
  joinConsultation,
} from "./commerce";

// Gamificação e administração.
export {
  awardXp,
  registerDailyActivity,
  rebuildLeaderboard,
  verifyProfessional,
  adminDashboard,
  onUserDeleted,
} from "./gamification";

// Editor de conteúdo com histórico de versões.
export { saveContent, restoreContentVersion } from "./content";

// Assistente clínico do prontuário. Trabalha sobre texto e dados
// estruturados — nunca sobre imagem de exame. Ver o cabeçalho de clinical.ts.
export { clinicalAssist, parseLabText } from "./clinical";

// Prontuário: assinatura, retificação e documentos clínicos.
export {
  signEncounter,
  amendEncounter,
  issueClinicalDocument,
  cancelClinicalDocument,
  verifyDocument,
  grantChildSummaryAccess,
} from "./emr";

// Conformidade com a LGPD: consentimento, portabilidade e eliminação.
export {
  recordConsent,
  revokeConsent,
  exportUserData,
  requestDataDeletion,
  cancelDataDeletion,
  processScheduledDeletions,
  dataProcessingManifest,
} from "./privacy";

// Notificações: lembretes de vacina, consulta e alertas clínicos.
export {
  checkVaccineReminders,
  checkAppointmentReminders,
  checkOpenDrafts,
  onLabResultCreated,
  getNotificationSettings,
  updateNotificationSettings,
  registerDevice,
  unregisterDevice,
} from "./notifications";

const REGION = "southamerica-east1";
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

/** Cotas diárias por plano. */
const QUOTAS: Record<string, number> = {
  free: 10,
  premium: 100,
  pro: 500,
};

/**
 * Sinais de alarme pediátricos.
 *
 * Quando a pergunta contém um destes, a resposta é prefixada com orientação de
 * buscar atendimento — antes de qualquer explicação. Um pai que pergunta sobre
 * "bebê roxo" às 3h não pode receber três parágrafos educativos primeiro.
 *
 * A lista é propositalmente ampla: um falso positivo custa um aviso a mais; um
 * falso negativo custa tempo numa emergência.
 */
const RED_FLAGS: { pattern: RegExp; reason: string }[] = [
  { pattern: /\b(roxo|roxinho|cianose|azulad)/i, reason: "alteração de cor" },
  { pattern: /\b(convuls|contorcend|olho revirad)/i, reason: "convulsão" },
  { pattern: /\b(não (respira|acorda|reage)|desacordad|desmai)/i, reason: "alteração de consciência" },
  { pattern: /\b(engasg|sufoc|asfixi)/i, reason: "engasgo" },
  { pattern: /\b(sangrament|hemorragi|vomitando sangue|sangue nas fezes)/i, reason: "sangramento" },
  { pattern: /\bfebre.*(menos de 3 meses|recém.?nascid|2 meses|1 mês)/i, reason: "febre no lactente jovem" },
  { pattern: /\b(mancha.*não (some|desaparece)|petéqui|rígidez de nuca|pescoço duro)/i, reason: "sinais de meningite" },
  { pattern: /\b(desidrat|sem urinar|fralda seca.*(12|24) *h|não faz xixi)/i, reason: "desidratação" },
  { pattern: /\b(gemênci|batimento de asa|tiragem|puxando.*(costela|barriga)|falta de ar)/i, reason: "desconforto respiratório" },
  { pattern: /\b(intoxica|engoliu|ingeriu.*(remédio|produto|pilha|bateria))/i, reason: "possível intoxicação" },
  { pattern: /\b(queda.*(cabeça|altura)|bateu a cabeça)/i, reason: "trauma craniano" },
  { pattern: /\b(prostrad|molinh|hipoativ|não interage)/i, reason: "prostração" },
];

const EMERGENCY_PREFIX = `⚠️ **Procure atendimento agora.**

Pelo que você descreveu, esta situação precisa de avaliação presencial imediata. Vá ao pronto-socorro mais próximo ou ligue para o SAMU (192).

Não espere melhorar para procurar ajuda.

---

`;

const SYSTEM_PROMPT = `Você é o assistente pediátrico do aplicativo Pediatria 360, escrevendo em português do Brasil.

QUEM LÊ VOCÊ
A maioria são pais e mães, muitas vezes cansados e preocupados, às vezes de madrugada. Alguns são profissionais de saúde. O papel do usuário vem indicado no contexto.

COMO RESPONDER
- Comece pela informação que resolve a dúvida. Nada de introdução ("Que ótima pergunta!").
- Frases curtas. Português claro. Se usar um termo técnico, explique na mesma frase.
- Máximo de 250 palavras, salvo quando pedirem detalhamento.
- Diga o que observar em casa e, explicitamente, o que faz procurar atendimento.

LIMITES QUE VOCÊ NÃO ULTRAPASSA
- Você não diagnostica. Você organiza informação e ajuda a preparar a conversa com o pediatra.
- Para RESPONSÁVEIS: nunca indique medicamento, dose, posologia ou intervalo — nem de venda livre. Diga para consultar o pediatra ou o farmacêutico. Isso vale mesmo se insistirem, mesmo se disserem que já usaram antes.
- Para PROFISSIONAIS VERIFICADOS: pode discutir conduta e citar faixas posológicas de referência, sempre indicando a fonte e lembrando de conferir peso e apresentação.
- Nunca contradiga uma orientação médica que o usuário diga ter recebido. Sugira retomar contato com quem atendeu.
- Se a pergunta sair de pediatria, diga que não é sua área.

FONTES
Quando o contexto trouxer protocolos da biblioteca, baseie a resposta neles e cite pelo título. Se não houver material de apoio, responda com conhecimento geral e deixe claro que é orientação geral, não protocolo do aplicativo.

INCERTEZA
Se não souber, diga que não sabe. Uma resposta inventada sobre saúde infantil causa dano real.`;

interface AiChatRequest {
  question: string;
  conversationId?: string;
  childId?: string;
}

function todayKey(): string {
  const now = new Date();
  return now.toISOString().slice(0, 10);
}

function detectRedFlags(text: string): string[] {
  return RED_FLAGS.filter((f) => f.pattern.test(text)).map((f) => f.reason);
}

/** Normaliza para busca, igual ao cliente. */
function normalize(input: string): string {
  return input
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Busca protocolos relacionados à pergunta.
 *
 * Recuperação simples por termos, não embeddings. Para um catálogo de algumas
 * centenas de documentos curados, funciona bem e custa uma consulta — montar
 * uma base vetorial aqui seria complexidade sem retorno.
 */
async function retrieveContext(
  question: string,
  audiences: string[]
): Promise<{ title: string; body: string; id: string }[]> {
  const tokens = normalize(question)
    .split(" ")
    .filter((t) => t.length >= 4)
    .slice(0, 10);

  if (tokens.length === 0) return [];

  const snapshot = await db
    .collection("articles")
    .where("published", "==", true)
    .where("searchTerms", "array-contains-any", tokens)
    .limit(20)
    .get();

  return snapshot.docs
    .filter((d) => audiences.includes(d.data().audience ?? "everyone"))
    .slice(0, 4)
    .map((d) => {
      const data = d.data();
      const sections = (data.sections ?? []) as { title: string; body: string }[];
      return {
        id: d.id,
        title: data.title ?? "",
        body: sections
          .map((s) => `${s.title}: ${s.body}`)
          .join("\n")
          .slice(0, 2500),
      };
    });
}

export const aiChat = onCall(
  { region: REGION, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre para usar a IA.");
    }

    const { question, conversationId, childId } = request.data as AiChatRequest;

    if (!question || question.trim().length < 3) {
      throw new HttpsError("invalid-argument", "Escreva sua pergunta.");
    }
    if (question.length > 2000) {
      throw new HttpsError("invalid-argument", "Pergunta muito longa.");
    }

    // ------------------------------------------------------------- Usuário
    const userDoc = await db.collection("users").doc(uid).get();
    const user = userDoc.data() ?? {};
    const plan = (user.plan as string) ?? "free";
    const role = (user.role as string) ?? "parent";
    const verified = (user.professionalVerified as boolean) ?? false;
    const isProfessional = (role === "professional" || role === "admin") && verified;

    // ---------------------------------------------------------------- Cota
    const usageRef = db
      .collection("users")
      .doc(uid)
      .collection("ai_usage")
      .doc(todayKey());

    const limit = QUOTAS[plan] ?? QUOTAS.free;
    const unlimited = plan === "pro";

    const usageSnap = await usageRef.get();
    const used = (usageSnap.data()?.count as number) ?? 0;

    if (!unlimited && used >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        `Você usou as ${limit} perguntas de hoje. O limite renova amanhã.`
      );
    }

    // ------------------------------------------------------- Sinais de alarme
    const flags = detectRedFlags(question);

    // ------------------------------------------------- Contexto da criança
    let childContext = "";
    if (childId) {
      const childDoc = await db
        .collection("users")
        .doc(uid)
        .collection("children")
        .doc(childId)
        .get();

      if (childDoc.exists) {
        const child = childDoc.data() ?? {};
        const birth = (child.birthDate as admin.firestore.Timestamp)?.toDate();
        const months = birth
          ? Math.floor((Date.now() - birth.getTime()) / (1000 * 60 * 60 * 24 * 30.44))
          : null;

        const parts = [
          months !== null ? `idade: ${months} meses` : null,
          child.sex ? `sexo: ${child.sex === "male" ? "masculino" : "feminino"}` : null,
          (child.allergies ?? []).length > 0
            ? `alergias: ${(child.allergies as string[]).join(", ")}`
            : null,
          (child.conditions ?? []).length > 0
            ? `condições: ${(child.conditions as string[]).join(", ")}`
            : null,
          child.gestationalWeeks && child.gestationalWeeks < 37
            ? `prematuro de ${child.gestationalWeeks} semanas`
            : null,
        ].filter(Boolean);

        childContext = `\n\nCRIANÇA EM QUESTÃO: ${parts.join("; ")}.`;
      }
    }

    // -------------------------------------------------------- Recuperação
    const audiences = isProfessional
      ? ["everyone", "parents", "professionals"]
      : ["everyone", "parents"];

    const docs = await retrieveContext(question, audiences);

    const contextBlock =
      docs.length > 0
        ? `\n\nPROTOCOLOS DA BIBLIOTECA (baseie-se neles e cite pelo título):\n\n${docs
            .map((d) => `### ${d.title}\n${d.body}`)
            .join("\n\n")}`
        : "";

    const roleBlock = isProfessional
      ? "\n\nO usuário é PROFISSIONAL DE SAÚDE com registro verificado."
      : "\n\nO usuário é RESPONSÁVEL pela criança (não é profissional de saúde). Não indique medicamentos nem doses.";

    // ------------------------------------------------------- Conversa prévia
    const convRef = conversationId
      ? db.collection("ai_conversations").doc(conversationId)
      : db.collection("ai_conversations").doc();

    const history: { role: string; content: string }[] = [];

    if (conversationId) {
      const convDoc = await convRef.get();
      if (!convDoc.exists || convDoc.data()?.ownerId !== uid) {
        throw new HttpsError("permission-denied", "Conversa não encontrada.");
      }

      const previous = await convRef
        .collection("messages")
        .orderBy("createdAt", "desc")
        .limit(20)
        .get();

      previous.docs
        .reverse()
        .forEach((d) =>
          history.push({
            role: d.data().role === "assistant" ? "assistant" : "user",
            content: d.data().text ?? "",
          })
        );
    }

    // ---------------------------------------------------------- Chamada
    let answer: string;

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY.value(),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-5",
          max_tokens: 1200,
          system: SYSTEM_PROMPT + roleBlock + childContext + contextBlock,
          messages: [...history, { role: "user", content: question }],
        }),
      });

      if (!response.ok) {
        const body = await response.text();
        logger.error("Falha na API de IA", { status: response.status, body });
        throw new HttpsError(
          "unavailable",
          "A IA está indisponível no momento. Tente em instantes."
        );
      }

      const data = (await response.json()) as {
        content: { type: string; text?: string }[];
      };

      answer = data.content
        .filter((c) => c.type === "text")
        .map((c) => c.text ?? "")
        .join("\n")
        .trim();

      if (!answer) {
        throw new HttpsError("internal", "Resposta vazia da IA.");
      }
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Erro inesperado na IA", error);
      throw new HttpsError("internal", "Não foi possível gerar a resposta.");
    }

    // O aviso de emergência vem ANTES da resposta, nunca depois.
    if (flags.length > 0) {
      answer = EMERGENCY_PREFIX + answer;
    }

    // ------------------------------------------------------------ Persistência
    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    if (!conversationId) {
      batch.set(convRef, {
        ownerId: uid,
        title: question.slice(0, 60),
        childId: childId ?? null,
        createdAt: now,
        updatedAt: now,
        messageCount: 2,
      });
    } else {
      batch.update(convRef, {
        updatedAt: now,
        messageCount: admin.firestore.FieldValue.increment(2),
      });
    }

    const userMsgRef = convRef.collection("messages").doc();
    batch.set(userMsgRef, {
      role: "user",
      text: question,
      createdAt: now,
    });

    const assistantMsgRef = convRef.collection("messages").doc();
    batch.set(assistantMsgRef, {
      role: "assistant",
      text: answer,
      sources: docs.map((d) => ({ title: d.title, contentId: d.id })),
      createdAt: now,
      redFlags: flags,
    });

    batch.set(
      usageRef,
      {
        count: admin.firestore.FieldValue.increment(1),
        limit,
        unlimited,
        updatedAt: now,
      },
      { merge: true }
    );

    await batch.commit();

    return {
      conversationId: convRef.id,
      messageId: assistantMsgRef.id,
      answer,
      sources: docs.map((d) => ({ title: d.title, contentId: d.id })),
      quotaUsed: used + 1,
      quotaLimit: limit,
      quotaUnlimited: unlimited,
      escalate: flags.length > 0,
    };
  }
);

/** Remove uma conversa e todas as mensagens. */
export const deleteConversation = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { conversationId } = request.data as { conversationId: string };
  const ref = db.collection("ai_conversations").doc(conversationId);
  const doc = await ref.get();

  if (!doc.exists || doc.data()?.ownerId !== uid) {
    throw new HttpsError("permission-denied", "Conversa não encontrada.");
  }

  await db.recursiveDelete(ref);
  return { ok: true };
});

/**
 * Gera os termos de busca sempre que um conteúdo é publicado ou editado.
 *
 * Fazer isso no servidor garante que a busca funcione igual para conteúdo
 * criado pelo painel, por script ou por importação.
 */
export const indexContent = onDocumentWritten(
  { region: REGION, document: "articles/{contentId}" },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;

    const data = after.data() ?? {};
    const sections = (data.sections ?? []) as { title: string; body: string }[];

    const haystack = [
      data.title ?? "",
      data.summary ?? "",
      (data.tags ?? []).join(" "),
      data.category ?? "",
      sections.map((s) => s.title).join(" "),
    ].join(" ");

    const terms = Array.from(
      new Set(normalize(haystack).split(" ").filter((t) => t.length >= 3))
    ).slice(0, 200);

    // Evita laço infinito: só escreve se o índice mudou de fato.
    const current = (data.searchTerms ?? []) as string[];
    if (
      current.length === terms.length &&
      current.every((t, i) => t === terms[i])
    ) {
      return;
    }

    await after.ref.update({ searchTerms: terms });
  }
);
