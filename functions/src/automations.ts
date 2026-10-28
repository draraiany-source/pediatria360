/**
 * Central de automações: fila, despacho e WhatsApp.
 *
 * - Jobs em `message_queue/{chave}` (id determinístico = deduplicação).
 * - O despachante revalida tudo antes de enviar (automationCore).
 * - Canal "inApp" é real (aviso na central do app). WhatsApp só envia com
 *   credenciais, número, modelo aprovado e autorização do responsável;
 *   faltando qualquer um, o job fica "blocked" com o motivo exato. Nada é
 *   marcado como enviado sem confirmação do provedor.
 * - Mensagens nunca levam conteúdo clínico: só dados administrativos e
 *   convite para abrir o app (área autenticada).
 */

import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { clinicRoleOf } from "./clinicFlow";
import {
  dispatchDecision,
  DispatchContext,
  MAX_ATTEMPTS,
  MESSAGE_KINDS,
  MESSAGE_TEMPLATES,
  MessageKind,
  normalizeRule,
  QueueJob,
  rateKey,
  renderTemplate,
  retryDelayMs,
  whatsappBlocker,
  Channel,
} from "./automationCore";
import { automationRule } from "./scheduling";
import { canTransition } from "./schedulingCore";
import { normalizeBrazilPhone, parseWebhook, sendWhatsAppTemplate, verifySignature, verifyWebhookChallenge, GRAPH_API_VERSION } from "./whatsapp";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

const WHATSAPP_TOKEN = defineSecret("WHATSAPP_TOKEN");
const WHATSAPP_PHONE_NUMBER_ID = defineSecret("WHATSAPP_PHONE_NUMBER_ID");
const WHATSAPP_APP_SECRET = defineSecret("WHATSAPP_APP_SECRET");
const WHATSAPP_VERIFY_TOKEN = defineSecret("WHATSAPP_VERIFY_TOKEN");

function secretValue(s: { value(): string }): string {
  try {
    return s.value() ?? "";
  } catch {
    return "";
  }
}

const ROUTES: Record<MessageKind, string> = {
  appointmentReminder: "/telemedicina",
  preVisitForm: "/pre-consulta",
  appointmentChange: "/telemedicina",
  waitlistOffer: "/telemedicina",
  returnReminder: "/telemedicina",
  noShowFollowUp: "/telemedicina",
  paymentReminder: "/financeiro",
  satisfactionSurvey: "/notificacoes",
  campaign: "/notificacoes",
};

interface DispatchStats {
  sent: number;
  cancelled: number;
  deferred: number;
  blocked: number;
  failed: number;
  retried: number;
}

interface Env {
  token: string;
  phoneNumberId: string;
  appSecret: string;
  fetchImpl?: Parameters<typeof sendWhatsAppTemplate>[1]["fetchImpl"];
}

async function buildContext(job: QueueJob & { vars?: Record<string, string> }, nowMs: number, env: Env): Promise<{ ctx: DispatchContext; phone: string | null; templateName: string | null }> {
  const base = await automationRule(job.clinicId, job.kind);
  // Campanha vale pela aprovação da própria campanha (conferida abaixo), não por regra automática.
  const rule = job.kind === "campaign" ? { ...base, enabled: true, paused: false, channels: ["inApp", "whatsapp"] as Channel[] } : base;
  const clinicSettings = job.clinicId
    ? (await db().collection("clinics").doc(job.clinicId).collection("settings").doc("automations").get()).data() ?? {}
    : {};
  let appointment: DispatchContext["appointment"] = null;
  if (job.appointmentId) {
    const a = (await db().collection("appointments").doc(job.appointmentId).get()).data();
    appointment = a ? {
      status: String(a.status),
      patientId: String(a.patientId),
      scheduleVersion: Number(a.scheduleVersion ?? 0),
      startMs: (a.startsAt as Timestamp).toMillis(),
    } : null;
  }
  const user = (await db().collection("users").doc(job.recipientUid).get()).data();
  const prefs = (user?.communicationPrefs ?? {}) as Record<string, unknown>;
  const optOut = (prefs.optOut ?? {}) as Partial<Record<Channel, boolean>>;
  const kinds = (prefs.kinds ?? {}) as Record<string, boolean>;
  const notif = (user?.notificationPrefs ?? {}) as Record<string, boolean>;
  const kindEnabled = kinds[job.kind] !== false &&
    !(job.kind === "appointmentReminder" && notif.appointmentReminder === false);
  const suppressed = (await db().collection("marketing_suppression").doc(job.recipientUid).get()).exists;
  const rate = (await db().collection("message_rate").doc(rateKey(job.recipientUid, nowMs)).get()).data();
  let campaignApproved: boolean | undefined;
  if (job.kind === "campaign" && job.campaignId && job.clinicId) {
    const c = (await db().collection("clinics").doc(job.clinicId).collection("campaigns").doc(job.campaignId).get()).data();
    campaignApproved = c?.status === "scheduled" || c?.status === "running";
  }
  const phone = typeof prefs.phone === "string" ? normalizeBrazilPhone(prefs.phone) : null;
  const wa = ((clinicSettings.whatsapp ?? {}) as Record<string, unknown>);
  const templates = (wa.approvedTemplates ?? {}) as Partial<Record<MessageKind, string>>;
  const blocker = job.channel === "whatsapp" ? whatsappBlocker(job.kind, {
    hasToken: !!env.token,
    hasPhoneNumberId: !!env.phoneNumberId,
    hasAppSecret: !!env.appSecret,
    clinicEnabled: wa.enabled === true,
    approvedTemplates: templates,
    recipientPhone: phone,
    recipientWhatsAppOptIn: prefs.whatsappOptIn === true,
  }) : null;
  return {
    ctx: {
      nowMs,
      rule,
      clinicAutomationsPaused: clinicSettings.paused === true,
      appointment,
      recipient: {
        exists: !!user,
        optOut,
        kindEnabled,
        marketingConsent: prefs.marketingConsent === true,
        suppressed,
      },
      sentToRecipientLast24h: Number(rate?.count ?? 0),
      channelBlocker: blocker,
      campaignApproved,
    },
    phone,
    templateName: templates[job.kind] ?? null,
  };
}

/** Processa um job já reivindicado. Nunca lança. */
async function processJob(ref: FirebaseFirestore.DocumentReference, nowMs: number, env: Env, stats: DispatchStats) {
  const snap = await ref.get();
  const raw = snap.data() ?? {};
  const job: QueueJob & { vars?: Record<string, string> } = {
    kind: raw.kind,
    channel: raw.channel,
    recipientUid: raw.recipientUid,
    clinicId: raw.clinicId ?? null,
    appointmentId: raw.appointmentId ?? null,
    scheduleVersion: raw.scheduleVersion ?? null,
    attempts: Number(raw.attempts ?? 0),
    sendAtMs: (raw.sendAt as Timestamp).toMillis(),
    campaignId: raw.campaignId ?? null,
    vars: raw.vars ?? {},
  };
  try {
    const { ctx, phone, templateName } = await buildContext(job, nowMs, env);
    const decision = dispatchDecision(job, ctx);
    if (decision.action === "cancel") {
      stats.cancelled++;
      await ref.update({ status: "cancelled", cancelReason: decision.reason, processedAt: FieldValue.serverTimestamp(), leaseUntil: null });
      return;
    }
    if (decision.action === "defer") {
      stats.deferred++;
      await ref.update({ status: "pending", sendAt: Timestamp.fromMillis(decision.untilMs), deferReason: decision.reason, leaseUntil: null });
      return;
    }
    if (decision.action === "block") {
      stats.blocked++;
      await ref.update({ status: "blocked", blockedReason: decision.reason, processedAt: FieldValue.serverTimestamp(), leaseUntil: null });
      return;
    }
    const tpl = MESSAGE_TEMPLATES[job.kind];
    const title = renderTemplate(tpl.title, job.vars ?? {});
    const body = renderTemplate(tpl.body, job.vars ?? {});
    let providerMessageId: string | null = null;
    if (job.channel === "inApp") {
      // Id = id do job: repetir o despacho não duplica o aviso.
      await db().collection("users").doc(job.recipientUid).collection("notifications").doc(ref.id).set({
        type: job.kind, title, body, route: ROUTES[job.kind], read: false,
        source: "automation", createdAt: FieldValue.serverTimestamp(),
      });
    } else {
      const vars = job.vars ?? {};
      const params = ["crianca", "data", "hora", "profissional", "prazo", "mudanca"]
        .filter((k) => typeof vars[k] === "string" && vars[k])
        .map((k) => ({ type: "text", text: String(vars[k]).slice(0, 60) }));
      const payload = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: phone!,
        type: "template",
        template: { name: templateName!, language: { code: "pt_BR" }, components: params.length ? [{ type: "body", parameters: params }] : [] },
      };
      const res = await sendWhatsAppTemplate(payload as never, {
        phoneNumberId: env.phoneNumberId, accessToken: env.token, fetchImpl: env.fetchImpl, apiVersion: GRAPH_API_VERSION,
      });
      if (!res.ok || !res.messageId) throw Object.assign(new Error("provider"), { providerCode: res.errorCode ?? null });
      providerMessageId = res.messageId;
    }
    await db().runTransaction(async (tx) => {
      const rateRef = db().collection("message_rate").doc(rateKey(job.recipientUid, nowMs));
      tx.set(rateRef, { count: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      tx.update(ref, {
        status: "sent",
        providerStatus: job.channel === "whatsapp" ? "accepted" : "delivered",
        providerMessageId,
        sentAt: FieldValue.serverTimestamp(),
        leaseUntil: null,
      });
    });
    stats.sent++;
  } catch (e) {
    const attempts = job.attempts + 1;
    const code = (e as { providerCode?: number | null }).providerCode ?? null;
    if (attempts >= MAX_ATTEMPTS) {
      stats.failed++;
      await ref.update({ status: "failed", attempts, lastErrorCode: code, failedAt: FieldValue.serverTimestamp(), leaseUntil: null });
    } else {
      stats.retried++;
      await ref.update({ status: "pending", attempts, lastErrorCode: code, sendAt: Timestamp.fromMillis(nowMs + retryDelayMs(attempts)), leaseUntil: null });
    }
    logger.warn("falha no envio", { job: ref.id, kind: job.kind, channel: job.channel, attempts, code });
  }
}

/** Reivindica (transação) e processa os jobs vencidos. */
export async function runDispatch(nowMs: number, opts: { clinicId?: string | null; limit?: number; env: Env }): Promise<DispatchStats> {
  const stats: DispatchStats = { sent: 0, cancelled: 0, deferred: 0, blocked: 0, failed: 0, retried: 0 };
  let q = db().collection("message_queue").where("status", "==", "pending");
  if (opts.clinicId) q = q.where("clinicId", "==", opts.clinicId);
  const due = await q.where("sendAt", "<=", Timestamp.fromMillis(nowMs)).limit(opts.limit ?? 100).get();
  let stale = db().collection("message_queue").where("status", "==", "processing");
  if (opts.clinicId) stale = stale.where("clinicId", "==", opts.clinicId);
  const stuck = await stale.where("leaseUntil", "<=", Timestamp.fromMillis(nowMs)).limit(50).get();
  for (const d of [...due.docs, ...stuck.docs]) {
    const claimed = await db().runTransaction(async (tx) => {
      const cur = await tx.get(d.ref);
      const st = cur.get("status");
      const lease = cur.get("leaseUntil") as Timestamp | null;
      const free = st === "pending" || (st === "processing" && lease && lease.toMillis() <= nowMs);
      if (!free) return false;
      tx.update(d.ref, { status: "processing", leaseUntil: Timestamp.fromMillis(nowMs + 5 * 60_000) });
      return true;
    });
    if (claimed) await processJob(d.ref, nowMs, opts.env, stats);
  }
  return stats;
}

function envFromSecrets(): Env {
  return {
    token: secretValue(WHATSAPP_TOKEN),
    phoneNumberId: secretValue(WHATSAPP_PHONE_NUMBER_ID),
    appSecret: secretValue(WHATSAPP_APP_SECRET),
  };
}

export const dispatchMessageQueue = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "America/Sao_Paulo",
    secrets: [WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET],
  },
  async () => {
    const stats = await runDispatch(Date.now(), { env: envFromSecrets() });
    await db().collection("automation_runs").add({ ...stats, clinicId: null, trigger: "schedule", at: FieldValue.serverTimestamp() });
    logger.info("fila de mensagens", stats);
  }
);

// ------------------------------------------------------------------ Gestão

async function requireRole(clinicId: unknown, uid: string, roles: string[]): Promise<string> {
  if (typeof clinicId !== "string" || !clinicId) throw new HttpsError("invalid-argument", "Clínica inválida.");
  const role = await clinicRoleOf(clinicId, uid);
  if (!role || !roles.includes(role)) throw new HttpsError("permission-denied", "Sem permissão.");
  return clinicId;
}

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

/** Gestão executa a fila da própria clínica agora (homologação e suporte). */
export const processMessageQueueNow = onCall(
  { region: REGION, secrets: [WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET] },
  async (request) => {
    const uid = uidOf(request);
    const clinicId = await requireRole((request.data ?? {}).clinicId, uid, ["clinicAdmin"]);
    const stats = await runDispatch(Date.now(), { clinicId, limit: 100, env: envFromSecrets() });
    await db().collection("clinics").doc(clinicId).collection("automation_runs").add({ ...stats, trigger: "manual", by: uid, at: FieldValue.serverTimestamp() });
    return stats;
  }
);

export const saveAutomationRule = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireRole(d.clinicId, uid, ["clinicAdmin"]);
  const kind = String(d.kind) as MessageKind;
  if (!(MESSAGE_KINDS as readonly string[]).includes(kind) || kind === "campaign") {
    throw new HttpsError("invalid-argument", "Automação inválida.");
  }
  const rule = normalizeRule(kind, d);
  await db().collection("clinics").doc(clinicId).collection("automations").doc(kind).set({
    ...rule, updatedBy: uid, updatedAt: FieldValue.serverTimestamp(),
  });
  await db().collection("clinics").doc(clinicId).collection("audit_logs").add({
    action: "automationRuleSaved", kind, enabled: rule.enabled, paused: rule.paused, actorUid: uid, at: FieldValue.serverTimestamp(),
  });
  return rule;
});

export const setClinicAutomationsPaused = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireRole(d.clinicId, uid, ["clinicAdmin"]);
  await db().collection("clinics").doc(clinicId).collection("settings").doc("automations").set({
    paused: d.paused === true, updatedBy: uid, updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { paused: d.paused === true };
});

/** Configuração do WhatsApp da clínica (sem credenciais: elas ficam no servidor). */
export const saveWhatsAppSettings = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireRole(d.clinicId, uid, ["clinicAdmin"]);
  const templates: Record<string, string> = {};
  for (const k of MESSAGE_KINDS) {
    const v = (d.approvedTemplates as Record<string, unknown> | undefined)?.[k];
    if (typeof v === "string" && /^[a-z0-9_]{1,60}$/.test(v)) templates[k] = v;
  }
  await db().collection("clinics").doc(clinicId).collection("settings").doc("automations").set({
    whatsapp: { enabled: d.enabled === true, approvedTemplates: templates, displayPhoneLast4: typeof d.displayPhoneLast4 === "string" ? d.displayPhoneLast4.slice(-4) : null },
    updatedBy: uid, updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { enabled: d.enabled === true, approvedTemplates: templates };
});

/** Situação real do canal WhatsApp: o que falta, sem expor segredo. */
export const getWhatsAppStatus = onCall(
  { region: REGION, secrets: [WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET, WHATSAPP_VERIFY_TOKEN] },
  async (request) => {
    const uid = uidOf(request);
    const clinicId = await requireRole((request.data ?? {}).clinicId, uid, ["clinicAdmin", "receptionist"]);
    const s = (await db().collection("clinics").doc(clinicId).collection("settings").doc("automations").get()).data() ?? {};
    const wa = (s.whatsapp ?? {}) as Record<string, unknown>;
    const missing: string[] = [];
    if (!secretValue(WHATSAPP_TOKEN)) missing.push("WHATSAPP_TOKEN");
    if (!secretValue(WHATSAPP_PHONE_NUMBER_ID)) missing.push("WHATSAPP_PHONE_NUMBER_ID");
    if (!secretValue(WHATSAPP_APP_SECRET)) missing.push("WHATSAPP_APP_SECRET");
    if (!secretValue(WHATSAPP_VERIFY_TOKEN)) missing.push("WHATSAPP_VERIFY_TOKEN");
    if (wa.enabled !== true) missing.push("habilitar WhatsApp na clínica");
    const templates = (wa.approvedTemplates ?? {}) as Record<string, string>;
    const noTemplate = MESSAGE_KINDS.filter((k) => k !== "campaign" && !templates[k]);
    return { ready: missing.length === 0, missing, kindsWithoutApprovedTemplate: noTemplate };
  }
);

/** Recepção/gestão cancela um envio pendente. */
export const cancelQueuedMessage = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireRole(d.clinicId, uid, ["clinicAdmin", "receptionist"]);
  const ref = db().collection("message_queue").doc(String(d.messageId ?? "-"));
  await db().runTransaction(async (tx) => {
    const m = await tx.get(ref);
    if (!m.exists || m.get("clinicId") !== clinicId) throw new HttpsError("not-found", "Envio não encontrado.");
    if (!["pending", "blocked"].includes(String(m.get("status")))) throw new HttpsError("failed-precondition", "Este envio não pode mais ser cancelado.");
    tx.update(ref, { status: "cancelled", cancelReason: "cancelado pela equipe", cancelledBy: uid, updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/** Preferências de comunicação do próprio responsável (com histórico). */
export const saveCommunicationPreferences = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const kinds: Record<string, boolean> = {};
  for (const k of MESSAGE_KINDS) {
    const v = (d.kinds as Record<string, unknown> | undefined)?.[k];
    if (typeof v === "boolean") kinds[k] = v;
  }
  const optOut: Record<string, boolean> = {};
  for (const c of ["inApp", "whatsapp"]) {
    const v = (d.optOut as Record<string, unknown> | undefined)?.[c];
    if (typeof v === "boolean") optOut[c] = v;
  }
  const phoneRaw = typeof d.phone === "string" ? d.phone : null;
  const phone = phoneRaw ? normalizeBrazilPhone(phoneRaw) : null;
  if (phoneRaw && !phone) throw new HttpsError("invalid-argument", "Telefone inválido (use DDI 55 e DDD).");
  const prefs = {
    kinds,
    optOut,
    preferredChannel: ["inApp", "whatsapp"].includes(String(d.preferredChannel)) ? d.preferredChannel : "inApp",
    whatsappOptIn: d.whatsappOptIn === true,
    marketingConsent: d.marketingConsent === true,
    ...(phone ? { phone } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  };
  const userRef = db().collection("users").doc(uid);
  const before = ((await userRef.get()).data()?.communicationPrefs ?? {}) as Record<string, unknown>;
  const batch = db().batch();
  batch.set(userRef, { communicationPrefs: prefs }, { merge: true });
  for (const key of ["whatsappOptIn", "marketingConsent"] as const) {
    if ((before[key] === true) !== prefs[key]) {
      batch.set(userRef.collection("communication_consents").doc(), {
        type: key, granted: prefs[key], at: FieldValue.serverTimestamp(), source: "app",
      });
    }
  }
  if (prefs.marketingConsent) batch.delete(db().collection("marketing_suppression").doc(uid));
  else if (before.marketingConsent === true) {
    batch.set(db().collection("marketing_suppression").doc(uid), { reason: "optOut", at: FieldValue.serverTimestamp() });
  }
  await batch.commit();
  return { ok: true };
});

// ------------------------------------------------------------------ Webhook WhatsApp

/**
 * Webhook da Meta. Assinatura obrigatória; cada evento é processado uma vez
 * (`whatsapp_events/{id}`). Resposta "confirmar" só confirma a consulta do
 * lembrete respondido (ligada pelo id da mensagem enviada), e só se a
 * consulta ainda aguarda confirmação. Reagendar/cancelar viram atendimento
 * humano: o número de telefone não autentica ninguém.
 */
export const whatsappWebhook = onRequest(
  { region: REGION, secrets: [WHATSAPP_APP_SECRET, WHATSAPP_VERIFY_TOKEN] },
  async (req, res) => {
    if (req.method === "GET") {
      const echo = verifyWebhookChallenge(req.query as Record<string, unknown>, secretValue(WHATSAPP_VERIFY_TOKEN));
      if (echo === null) {
        res.status(403).send("forbidden");
        return;
      }
      res.status(200).send(echo);
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("method");
      return;
    }
    const raw = (req as unknown as { rawBody?: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body ?? {}));
    if (!verifySignature(raw, req.get("x-hub-signature-256") ?? undefined, secretValue(WHATSAPP_APP_SECRET))) {
      res.status(401).send("signature");
      return;
    }
    const result = await handleWebhookBody(req.body);
    res.status(200).json(result);
  }
);

const STATUS_RANK: Record<string, number> = { accepted: 0, sent: 1, delivered: 2, read: 3, failed: 4 };

export async function handleWebhookBody(body: unknown): Promise<{ statuses: number; replies: number; duplicates: number }> {
  const { statuses, replies } = parseWebhook(body);
  let duplicates = 0;
  for (const s of statuses) {
    const evRef = db().collection("whatsapp_events").doc(`st_${s.messageId}_${s.status}`);
    try {
      await evRef.create({ kind: "status", status: s.status, at: FieldValue.serverTimestamp() });
    } catch {
      duplicates++;
      continue;
    }
    const q = await db().collection("message_queue").where("providerMessageId", "==", s.messageId).limit(1).get();
    if (q.empty) continue;
    await db().runTransaction(async (tx) => {
      const cur = await tx.get(q.docs[0].ref);
      // Eventos fora de ordem: "delivered" atrasado não rebaixa "read".
      if ((STATUS_RANK[s.status] ?? 0) <= (STATUS_RANK[String(cur.get("providerStatus"))] ?? -1)) return;
      tx.update(cur.ref, {
        providerStatus: s.status,
        providerUpdatedAt: Timestamp.fromDate(s.at),
        ...(s.status === "failed" ? { needsManualContact: true, lastErrorCode: s.errorCode ?? null } : {}),
      });
    });
  }
  for (const r of replies) {
    const evRef = db().collection("whatsapp_events").doc(`rp_${r.contextMessageId ?? r.reminderId}_${r.reply}`);
    try {
      await evRef.create({ kind: "reply", reply: r.reply, at: FieldValue.serverTimestamp() });
    } catch {
      duplicates++;
      continue;
    }
    if (!r.contextMessageId) continue;
    const q = await db().collection("message_queue").where("providerMessageId", "==", r.contextMessageId).limit(1).get();
    if (q.empty) continue;
    const job = q.docs[0].data();
    const clinicId = (job.clinicId as string) ?? null;
    const apptId = (job.appointmentId as string) ?? null;
    let handled = false;
    if (r.reply === "confirmar" && apptId) {
      const ref = db().collection("appointments").doc(apptId);
      handled = await db().runTransaction(async (tx) => {
        const a = await tx.get(ref);
        if (!a.exists || a.get("patientId") !== job.recipientUid) return false;
        if (Number(a.get("scheduleVersion") ?? 0) !== Number(job.scheduleVersion ?? -1)) return false;
        if (!canTransition(String(a.get("status")), "confirmed", "family")) return false;
        tx.update(ref, { status: "confirmed", confirmedAt: FieldValue.serverTimestamp(), confirmedBy: job.recipientUid, confirmedVia: "whatsapp" });
        return true;
      });
    }
    if (clinicId && !handled) {
      await db().collection("clinics").doc(clinicId).collection("whatsapp_inbox").add({
        appointmentId: apptId,
        recipientUid: job.recipientUid,
        reply: r.reply,
        fromMasked: r.from,
        status: "open",
        reason: r.reply === "confirmar" ? "confirmação não aplicada (consulta mudou)" : "pedido de " + r.reply,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
  return { statuses: statuses.length, replies: replies.length, duplicates };
}

/** Recepção assume ou encerra uma conversa da caixa de entrada (handoff). */
export const updateInboxItem = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireRole(d.clinicId, uid, ["clinicAdmin", "receptionist"]);
  const status = ["assigned", "closed"].includes(String(d.status)) ? String(d.status) : null;
  if (!status) throw new HttpsError("invalid-argument", "Status inválido.");
  const ref = db().collection("clinics").doc(clinicId).collection("whatsapp_inbox").doc(String(d.itemId ?? "-"));
  if (!(await ref.get()).exists) throw new HttpsError("not-found", "Item não encontrado.");
  await ref.update({ status, assignedTo: uid, updatedAt: FieldValue.serverTimestamp() });
  return { ok: true };
});

