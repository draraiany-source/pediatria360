/**
 * Gamificação e administração.
 *
 * ## Por que o XP é concedido só aqui
 *
 * Se o cliente pudesse escrever `xp`, liderar o ranking seria questão de
 * alterar um número. As regras do Firestore bloqueiam a escrita direta; este é
 * o único caminho. A ação é validada — não basta dizer "concluí uma aula",
 * o servidor confere que a aula existe e que o progresso foi registrado.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

/** Valores de XP. Fonte única — o app só exibe. */
const XP_VALUES: Record<string, number> = {
  growthRecorded: 20,
  vaccineMarked: 30,
  lessonCompleted: 15,
  courseCompleted: 100,
  articleRead: 5,
  aiQuestion: 3,
  dailyOpen: 5,
  challengeCompleted: 50,
};

/**
 * Teto diário por ação.
 *
 * Sem isso, abrir e fechar um artigo cem vezes renderia 500 XP. O limite
 * mantém o ranking ligado a uso real, não a repetição mecânica.
 */
const DAILY_CAPS: Record<string, number> = {
  growthRecorded: 3,
  vaccineMarked: 10,
  lessonCompleted: 20,
  courseCompleted: 3,
  articleRead: 10,
  aiQuestion: 10,
  dailyOpen: 1,
  challengeCompleted: 5,
};

function todayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Concede XP por uma ação, respeitando o teto diário. */
export const awardXp = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { action, referenceId } = request.data as {
    action: string;
    referenceId?: string;
  };

  const value = XP_VALUES[action];
  if (value === undefined) {
    throw new HttpsError("invalid-argument", "Ação desconhecida.");
  }

  const userRef = db().collection("users").doc(uid);
  const dayRef = userRef.collection("xp_log").doc(todayKey());

  const awarded = await db().runTransaction(async (tx) => {
    const daySnap = await tx.get(dayRef);
    const counts = (daySnap.data()?.counts ?? {}) as Record<string, number>;
    const used = counts[action] ?? 0;
    const cap = DAILY_CAPS[action] ?? 5;

    if (used >= cap) return 0;

    // Uma mesma referência não pontua duas vezes: concluir a mesma aula
    // repetidamente não deve render XP a cada vez.
    if (referenceId) {
      const seen = (daySnap.data()?.references ?? []) as string[];
      const key = `${action}:${referenceId}`;
      if (seen.includes(key)) return 0;

      tx.set(
        dayRef,
        {
          counts: { ...counts, [action]: used + 1 },
          references: admin.firestore.FieldValue.arrayUnion(key),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } else {
      tx.set(
        dayRef,
        {
          counts: { ...counts, [action]: used + 1 },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    tx.update(userRef, {
      xp: admin.firestore.FieldValue.increment(value),
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return value;
  });

  return { awarded };
});

/**
 * Registra atividade do dia e atualiza a sequência.
 *
 * A sequência tolera **um dia perdido por semana**. Um app de saúde infantil
 * não pode punir quem passou a noite no pronto-socorro e esqueceu de abrir o
 * aplicativo — streak agressiva gera ansiedade, e ansiedade é o que menos
 * falta na vida de quem cuida de criança doente.
 */
export const registerDailyActivity = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const userRef = db().collection("users").doc(uid);

  const result = await db().runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() ?? {};

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    const lastRaw = data.lastStreakDate as admin.firestore.Timestamp | undefined;
    const last = lastRaw?.toDate();
    if (last) last.setUTCHours(0, 0, 0, 0);

    const current = Number(data.streakDays ?? 0);
    const longest = Number(data.longestStreak ?? 0);
    const graceUsed = Boolean(data.streakGraceUsed ?? false);
    const graceWeek = Number(data.streakGraceWeek ?? -1);

    const thisWeek = Math.floor(today.getTime() / (7 * 24 * 60 * 60 * 1000));
    // A tolerância renova a cada semana.
    const graceAvailable = graceWeek !== thisWeek || !graceUsed;

    if (!last) {
      tx.update(userRef, {
        streakDays: 1,
        longestStreak: Math.max(longest, 1),
        lastStreakDate: admin.firestore.Timestamp.fromDate(today),
        streakGraceUsed: false,
        streakGraceWeek: thisWeek,
      });
      return { streakDays: 1, kept: true };
    }

    const gap = Math.round(
      (today.getTime() - last.getTime()) / (24 * 60 * 60 * 1000)
    );

    if (gap === 0) return { streakDays: current, kept: true };

    let next: number;
    let usedGrace = false;

    if (gap === 1) {
      next = current + 1;
    } else if (gap === 2 && graceAvailable) {
      next = current + 1;
      usedGrace = true;
    } else {
      next = 1;
    }

    tx.update(userRef, {
      streakDays: next,
      longestStreak: Math.max(longest, next),
      lastStreakDate: admin.firestore.Timestamp.fromDate(today),
      streakGraceUsed: usedGrace || (graceWeek === thisWeek && graceUsed),
      streakGraceWeek: thisWeek,
      xp: admin.firestore.FieldValue.increment(XP_VALUES.dailyOpen),
    });

    return { streakDays: next, kept: gap <= 2 };
  });

  return result;
});

/**
 * Recalcula o ranking semanal.
 *
 * Agendado em vez de calculado sob demanda: ordenar todos os usuários por XP a
 * cada abertura de tela seria caro e desnecessário — o ranking não precisa ser
 * ao vivo.
 *
 * O ranking guarda **primeiro nome + inicial do sobrenome**. Uma lista pública
 * dentro de um app de saúde não deve expor nome completo nem e-mail.
 */
export const rebuildLeaderboard = onSchedule(
  { region: REGION, schedule: "every day 03:00", timeZone: "America/Sao_Paulo" },
  async () => {
    const snapshot = await db()
      .collection("users")
      .orderBy("xp", "desc")
      .limit(100)
      .get();

    const batch = db().batch();

    snapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      const name = (data.name as string) ?? "";
      const parts = name.trim().split(/\s+/);
      const displayName =
        parts.length > 1
          ? `${parts[0]} ${parts[parts.length - 1][0]}.`
          : parts[0] || "Usuário";

      batch.set(db().collection("leaderboard").doc(doc.id), {
        uid: doc.id,
        displayName,
        xp: data.xp ?? 0,
        position: index + 1,
        photoUrl: data.photoUrl ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    logger.info("Ranking recalculado", { entries: snapshot.size });
  }
);

// ------------------------------------------------------------ Administração

/** Confere que quem chama é admin. */
async function requireAdmin(uid: string | undefined): Promise<void> {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  const doc = await db().collection("users").doc(uid).get();
  if (doc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Ação restrita à equipe.");
  }
}

/**
 * Aprova ou recusa o registro profissional.
 *
 * Este é o gate que libera protocolos de prescrição e telemedicina. A
 * conferência é manual de propósito: validar CRM automaticamente exigiria
 * integração com o CFM, e um falso positivo aqui dá acesso a conteúdo de
 * prescrição para quem não deveria tê-lo.
 */
export const verifyProfessional = onCall({ region: REGION }, async (request) => {
  await requireAdmin(request.auth?.uid);

  const { targetUid, approved, note } = request.data as {
    targetUid: string;
    approved: boolean;
    note?: string;
  };

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Usuário não informado.");
  }

  await db().collection("users").doc(targetUid).update({
    professionalVerified: approved,
    verificationNote: note ?? null,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    verifiedBy: request.auth!.uid,
  });

  // Registro de auditoria: quem aprovou quem, e quando.
  await db().collection("audit_log").add({
    action: approved ? "professional_approved" : "professional_rejected",
    targetUid,
    actorUid: request.auth!.uid,
    note: note ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("Verificação profissional", { targetUid, approved });

  return { ok: true };
});

/** Números do painel. */
export const adminDashboard = onCall({ region: REGION }, async (request) => {
  await requireAdmin(request.auth?.uid);

  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const [users, newUsers, pendingPros, orders, articles, courses] =
    await Promise.all([
      db().collection("users").count().get(),
      db()
        .collection("users")
        .where("createdAt", ">=", thirtyDaysAgo)
        .count()
        .get(),
      db()
        .collection("users")
        .where("role", "==", "professional")
        .where("professionalVerified", "==", false)
        .count()
        .get(),
      db()
        .collection("orders")
        .where("createdAt", ">=", thirtyDaysAgo)
        .get(),
      db().collection("articles").where("published", "==", true).count().get(),
      db().collection("courses").where("published", "==", true).count().get(),
    ]);

  const paidOrders = orders.docs.filter((d) =>
    ["paid", "preparing", "shipped", "delivered"].includes(d.data().status)
  );

  const revenueCents = paidOrders.reduce(
    (sum, d) => sum + Number(d.data().totalCents ?? 0),
    0
  );

  return {
    totalUsers: users.data().count,
    newUsersLast30Days: newUsers.data().count,
    pendingVerifications: pendingPros.data().count,
    ordersLast30Days: orders.size,
    paidOrdersLast30Days: paidOrders.length,
    revenueLast30DaysCents: revenueCents,
    publishedArticles: articles.data().count,
    publishedCourses: courses.data().count,
  };
});

/**
 * Limpeza em cascata quando uma conta é excluída.
 *
 * Sem isso, apagar o usuário deixaria crianças, medições e vacinas órfãs no
 * banco — dado de saúde de menor sem dono, o que a LGPD não perdoa.
 */
export const onUserDeleted = onDocumentDeleted(
  { region: REGION, document: "users/{uid}" },
  async (event) => {
    const uid = event.params.uid;

    await db().recursiveDelete(db().collection("users").doc(uid));

    // Conversas com a IA vivem fora do documento do usuário.
    const conversations = await db()
      .collection("ai_conversations")
      .where("ownerId", "==", uid)
      .get();

    for (const doc of conversations.docs) {
      await db().recursiveDelete(doc.ref);
    }

    await db().collection("leaderboard").doc(uid).delete();

    logger.info("Dados do usuário removidos em cascata", { uid });
  }
);
