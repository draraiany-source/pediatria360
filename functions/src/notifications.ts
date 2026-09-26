/**
 * Envio de notificações.
 *
 * ## O princípio que governa a frequência
 *
 * Notificação de saúde infantil tem um limite estreito: pouca demais e a
 * vacina atrasa; demais e o aplicativo é silenciado — e aí nenhuma chega.
 *
 * A régua adotada: **avisar quando há ação a tomar, e parar quando não há**.
 * Vacina vencida avisa no dia, aos 7 dias e aos 30. Depois disso o problema
 * não é falta de lembrete.
 *
 * ## Horário
 *
 * Nada é enviado entre 21h e 8h. Um aviso de vacina às 3 da manhã acorda uma
 * família que talvez tenha acabado de fazer o bebê dormir — e é assim que um
 * aplicativo de saúde vira aplicativo desinstalado.
 *
 * Alerta clínico para profissional é exceção: consulta começando em 15 minutos
 * avisa na hora, porque o horário do aviso é o horário do fato.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const messaging = () => admin.messaging();

/** Tipos de notificação. Cada um é ativável separadamente. */
const NOTIFICATION_TYPES = {
  vaccineDue: {
    label: "Vacinas",
    description: "Aviso quando uma vacina vence ou está atrasada.",
    default: true,
    audience: "parent",
  },
  appointmentReminder: {
    label: "Consultas",
    description: "Lembrete véspera e 1 hora antes.",
    default: true,
    audience: "both",
  },
  growthReminder: {
    label: "Acompanhamento de crescimento",
    description: "Sugestão de nova medição conforme a idade.",
    default: true,
    audience: "parent",
  },
  labResult: {
    label: "Resultados de exames",
    description: "Aviso quando um resultado é registrado.",
    default: true,
    audience: "both",
  },
  openDraft: {
    label: "Atendimentos em aberto",
    description: "Lembrete de atendimento não assinado.",
    default: true,
    audience: "professional",
  },
  content: {
    label: "Conteúdo novo",
    description: "Artigos e cursos publicados.",
    default: false,
    audience: "both",
  },
} as const;

type NotificationType = keyof typeof NOTIFICATION_TYPES;

/** Janela de silêncio, em horas locais. */
const QUIET_START = 21;
const QUIET_END = 8;

/** Verifica se o horário atual está na janela de silêncio (São Paulo). */
function inQuietHours(): boolean {
  const hour = Number(
    new Intl.DateTimeFormat("pt-BR", {
      timeZone: "America/Sao_Paulo",
      hour: "numeric",
      hour12: false,
    }).format(new Date())
  );
  return hour >= QUIET_START || hour < QUIET_END;
}

interface Push {
  uid: string;
  type: NotificationType;
  title: string;
  body: string;
  route?: string;
  urgent?: boolean;
}

/**
 * Envia para todos os aparelhos do usuário.
 *
 * Respeita a preferência do tipo e a janela de silêncio. Tokens inválidos são
 * removidos: acumular token morto degrada a entrega e infla o custo.
 */
async function push({ uid, type, title, body, route, urgent }: Push): Promise<boolean> {
  const userDoc = await db().collection("users").doc(uid).get();
  if (!userDoc.exists) return false;

  const user = userDoc.data() ?? {};

  // Preferência do usuário vence o padrão.
  const prefs = (user.notificationPrefs ?? {}) as Record<string, boolean>;
  const enabled = prefs[type] ?? NOTIFICATION_TYPES[type].default;
  if (!enabled) return false;

  if (!urgent && inQuietHours()) {
    // Reagendar seria melhor que descartar, mas exigiria fila própria. Como
    // as verificações rodam de manhã, o caso é raro.
    logger.debug("Notificação adiada pela janela de silêncio", { uid, type });
    return false;
  }

  const tokens = (user.fcmTokens ?? []) as string[];
  if (tokens.length === 0) return false;

  const response = await messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type,
      ...(route ? { route } : {}),
    },
    android: {
      priority: urgent ? "high" : "normal",
      notification: {
        channelId: "p360_default",
        // Vibra só no urgente. Lembrete de vacina não precisa sacudir o
        // bolso de quem está numa reunião.
        defaultVibrateTimings: urgent === true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: urgent ? "default" : undefined,
          badge: 1,
        },
      },
    },
  });

  // Limpa tokens que o Firebase reportou como inválidos.
  const dead: string[] = [];
  response.responses.forEach((r, i) => {
    if (
      !r.success &&
      ["messaging/invalid-registration-token",
       "messaging/registration-token-not-registered"].includes(
        r.error?.code ?? ""
      )
    ) {
      dead.push(tokens[i]);
    }
  });

  if (dead.length > 0) {
    await userDoc.ref.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
    });
  }

  // Cópia no app: notificação do sistema é efêmera, e quem viu de relance
  // precisa poder reencontrar o aviso.
  await db()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({
      type,
      title,
      body,
      route: route ?? null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return response.successCount > 0;
}

/** Dias de atraso em que o aviso é repetido. */
const VACCINE_REMINDER_DAYS = [0, 7, 30];

/**
 * Verifica vacinas vencidas e avisa os responsáveis.
 *
 * Roda de manhã, uma vez por dia. Percorre as doses não aplicadas cuja data
 * prevista caia exatamente nos marcos de repetição — sem isso, o aviso
 * chegaria todos os dias e seria silenciado na primeira semana.
 */
export const checkVaccineReminders = onSchedule(
  {
    region: REGION,
    schedule: "every day 09:00",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let sent = 0;

    for (const daysOverdue of VACCINE_REMINDER_DAYS) {
      const target = new Date(today);
      target.setDate(target.getDate() - daysOverdue);

      const next = new Date(target);
      next.setDate(next.getDate() + 1);

      const doses = await db()
        .collectionGroup("vaccine_doses")
        .where("appliedAt", "==", null)
        .where("dueAt", ">=", admin.firestore.Timestamp.fromDate(target))
        .where("dueAt", "<", admin.firestore.Timestamp.fromDate(next))
        .limit(500)
        .get();

      for (const dose of doses.docs) {
        // Caminho: users/{uid}/children/{childId}/vaccine_doses/{doseId}
        const uid = dose.ref.parent.parent?.parent.parent?.id;
        const childRef = dose.ref.parent.parent;
        if (!uid || !childRef) continue;

        const child = (await childRef.get()).data() ?? {};
        const childName = (child.name as string)?.split(" ")[0] ?? "sua criança";

        const title =
          daysOverdue === 0
            ? `Vacina de ${childName} hoje`
            : `Vacina de ${childName} em atraso`;

        const body =
          daysOverdue === 0
            ? "Uma dose está prevista para hoje. Confira na caderneta."
            : `Uma dose está ${daysOverdue} dias atrasada. Procure a unidade de saúde.`;

        if (
          await push({
            uid,
            type: "vaccineDue",
            title,
            body,
            route: `/criancas/${childRef.id}/vacinas`,
          })
        ) {
          sent++;
        }
      }
    }

    logger.info("Lembretes de vacina enviados", { sent });
  }
);

/**
 * Lembretes de consulta.
 *
 * Dois momentos: véspera às 18h (para organizar o dia seguinte) e 1 hora antes
 * (para sair de casa). O de 1 hora ignora a janela de silêncio — consulta às
 * 8h precisa avisar às 7h.
 */
export const checkAppointmentReminders = onSchedule(
  { region: REGION, schedule: "every 30 minutes", timeZone: "America/Sao_Paulo" },
  async () => {
    const now = new Date();

    // Janela de 1 hora antes, com a folga do intervalo do agendador.
    const inOneHour = new Date(now.getTime() + 60 * 60 * 1000);
    const windowEnd = new Date(inOneHour.getTime() + 30 * 60 * 1000);

    const soon = await db()
      .collection("appointments")
      .where("status", "in", ["confirmed", "requested"])
      .where("startsAt", ">=", admin.firestore.Timestamp.fromDate(inOneHour))
      .where("startsAt", "<", admin.firestore.Timestamp.fromDate(windowEnd))
      .get();

    for (const doc of soon.docs) {
      const a = doc.data();
      if (a.reminderSentOneHour === true) continue;

      const time = (a.startsAt as admin.firestore.Timestamp)
        .toDate()
        .toLocaleTimeString("pt-BR", {
          hour: "2-digit",
          minute: "2-digit",
          timeZone: "America/Sao_Paulo",
        });

      await push({
        uid: a.patientId,
        type: "appointmentReminder",
        title: "Consulta em 1 hora",
        body: `Com ${a.professionalName ?? "o profissional"}, às ${time}.`,
        route: "/telemedicina",
        urgent: true,
      });

      // O profissional também é avisado: agenda cheia faz esquecer.
      await push({
        uid: a.professionalId,
        type: "appointmentReminder",
        title: "Consulta em 1 hora",
        body: `${a.childName ?? a.patientName ?? "Paciente"}, às ${time}.`,
        route: "/telemedicina",
        urgent: true,
      });

      await doc.ref.update({ reminderSentOneHour: true });
    }

    logger.info("Lembretes de consulta processados", { count: soon.size });
  }
);

/**
 * Alerta o profissional sobre atendimentos deixados em rascunho.
 *
 * Um atendimento não assinado é um registro que não existe juridicamente. Se
 * ficou aberto de um dia para o outro, houve interrupção — e quanto mais tempo
 * passa, menos o médico lembra do que examinou.
 */
export const checkOpenDrafts = onSchedule(
  { region: REGION, schedule: "every day 19:00", timeZone: "America/Sao_Paulo" },
  async () => {
    const cutoff = new Date();
    cutoff.setHours(cutoff.getHours() - 6);

    const drafts = await db()
      .collection("encounters")
      .where("status", "==", "draft")
      .where("startedAt", "<", admin.firestore.Timestamp.fromDate(cutoff))
      .limit(300)
      .get();

    const byProfessional = new Map<string, number>();
    drafts.docs.forEach((d) => {
      const uid = d.data().professionalId as string;
      byProfessional.set(uid, (byProfessional.get(uid) ?? 0) + 1);
    });

    for (const [uid, count] of byProfessional) {
      await push({
        uid,
        type: "openDraft",
        title:
          count === 1
            ? "1 atendimento sem assinatura"
            : `${count} atendimentos sem assinatura`,
        body:
          "Atendimento em rascunho não vale como registro. Revise e assine.",
        route: "/pacientes",
      });
    }

    logger.info("Alertas de rascunho enviados", {
      professionals: byProfessional.size,
    });
  }
);

/**
 * Avisa quando um resultado de exame é registrado.
 *
 * A notificação diz que **chegou**, não o que diz. Um pai que recebe
 * "hemoglobina 9,8 — abaixo do esperado" no celular passa a noite no Google.
 * O valor está no app, junto do contexto e da faixa de referência.
 */
export const onLabResultCreated = onDocumentCreated(
  { region: REGION, document: "lab_results/{resultId}" },
  async (event) => {
    const result = event.data?.data();
    if (!result) return;

    const patientId = result.patientId as string;
    if (!patientId || patientId.startsWith("pending_")) return;

    await push({
      uid: patientId,
      type: "labResult",
      title: "Novo resultado de exame",
      body: "Um resultado foi registrado no prontuário.",
      route: "/avisos",
    });
  }
);

/** Lê as preferências e os tipos disponíveis. */
export const getNotificationSettings = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const doc = await db().collection("users").doc(uid).get();
    const user = doc.data() ?? {};
    const prefs = (user.notificationPrefs ?? {}) as Record<string, boolean>;
    const role = (user.role as string) ?? "parent";

    const types = Object.entries(NOTIFICATION_TYPES)
      .filter(([, config]) => {
        if (config.audience === "both") return true;
        if (config.audience === "professional") {
          return role === "professional" || role === "admin";
        }
        return role === "parent" || role === "admin";
      })
      .map(([key, config]) => ({
        key,
        label: config.label,
        description: config.description,
        enabled: prefs[key] ?? config.default,
      }));

    return {
      types,
      quietHours: { start: QUIET_START, end: QUIET_END },
      deviceCount: ((user.fcmTokens ?? []) as string[]).length,
    };
  }
);

/** Grava as preferências. */
export const updateNotificationSettings = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const { prefs } = request.data as { prefs: Record<string, boolean> };

    const clean: Record<string, boolean> = {};
    for (const [key, value] of Object.entries(prefs ?? {})) {
      if (key in NOTIFICATION_TYPES) clean[key] = value === true;
    }

    await db().collection("users").doc(uid).update({
      notificationPrefs: clean,
      notificationPrefsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true };
  }
);

/** Registra o token do aparelho. */
export const registerDevice = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { token } = request.data as { token: string };
  if (!token || token.length < 20) {
    throw new HttpsError("invalid-argument", "Token inválido.");
  }

  await db().collection("users").doc(uid).update({
    fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
  });

  return { ok: true };
});

/** Remove o token — chamado no logout, para o aparelho parar de receber. */
export const unregisterDevice = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { token } = request.data as { token: string };

  await db().collection("users").doc(uid).update({
    fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
  });

  return { ok: true };
});
