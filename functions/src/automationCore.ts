/**
 * Regras puras da central de automações e da fila de mensagens.
 *
 * Cada envio é um documento da fila com id determinístico (a "chave de
 * deduplicação"): reprocessar um evento, repetir uma chamada ou rodar o
 * agendador duas vezes cai no mesmo documento e não gera segunda mensagem.
 * Antes de enviar, o despachante relê a consulta, o destinatário, as
 * preferências e a regra; qualquer mudança cancela ou adia o envio.
 */

import { localParts, DEFAULT_TZ_OFFSET_MIN } from "./schedulingCore";

export const MESSAGE_KINDS = [
  "appointmentReminder",
  "preVisitForm",
  "appointmentChange",
  "waitlistOffer",
  "returnReminder",
  "noShowFollowUp",
  "paymentReminder",
  "satisfactionSurvey",
  "campaign",
] as const;
export type MessageKind = (typeof MESSAGE_KINDS)[number];

export const CHANNELS = ["inApp", "whatsapp"] as const;
export type Channel = (typeof CHANNELS)[number];

/** Status da consulta em que cada tipo ainda faz sentido. */
const VALID_APPOINTMENT_STATUS: Partial<Record<MessageKind, string[]>> = {
  appointmentReminder: ["requested", "awaitingConfirmation", "confirmed"],
  preVisitForm: ["requested", "awaitingConfirmation", "confirmed"],
  waitlistOffer: [],
  noShowFollowUp: ["noShow"],
  satisfactionSurvey: ["completed"],
};

/** Textos administrativos: nunca conteúdo clínico. */
export const MESSAGE_TEMPLATES: Record<MessageKind, { title: string; body: string }> = {
  appointmentReminder: {
    title: "Lembrete de consulta",
    body: "{{crianca}} tem consulta em {{data}} às {{hora}} com {{profissional}}. Confirme, remarque ou cancele pelo app.",
  },
  preVisitForm: {
    title: "Pré-consulta disponível",
    body: "Responda a pré-consulta de {{crianca}} antes do atendimento de {{data}}. Abra o app para preencher.",
  },
  appointmentChange: {
    title: "Consulta atualizada",
    body: "A consulta de {{crianca}} foi {{mudanca}}. Veja os detalhes no app.",
  },
  waitlistOffer: {
    title: "Vaga disponível",
    body: "Abriu um horário em {{data}} às {{hora}} com {{profissional}}. Responda até {{prazo}} pelo app.",
  },
  returnReminder: {
    title: "Retorno sugerido",
    body: "Está chegando a data sugerida para o retorno de {{crianca}}. Agende pelo app.",
  },
  noShowFollowUp: {
    title: "Sentimos sua falta",
    body: "A consulta de {{crianca}} em {{data}} não aconteceu. Se quiser, remarque pelo app.",
  },
  paymentReminder: {
    title: "Pagamento pendente",
    body: "Há um valor em aberto referente ao atendimento de {{data}}. Veja no app.",
  },
  satisfactionSurvey: {
    title: "Como foi o atendimento?",
    body: "Conte como foi a consulta de {{data}}. Leva menos de um minuto.",
  },
  campaign: {
    title: "{{titulo}}",
    body: "{{texto}}",
  },
};

const VAR_RE = /\{\{([a-z_]+)\}\}/g;
const ALLOWED_VARS = new Set([
  "crianca", "data", "hora", "profissional", "prazo", "mudanca", "clinica", "titulo", "texto",
]);

/** Preenche o modelo; variável desconhecida vira vazio (não vaza campo). */
export function renderTemplate(text: string, vars: Record<string, unknown>): string {
  return text.replace(VAR_RE, (_m, k: string) =>
    ALLOWED_VARS.has(k) && typeof vars[k] === "string" ? String(vars[k]).slice(0, 120) : "");
}

// ------------------------------------------------------------------ Regra

export interface AutomationRule {
  kind: MessageKind;
  enabled: boolean;
  paused: boolean;
  channels: Channel[];
  /** Janela permitida (hora local), ex.: 8 a 20. */
  allowedFromHour: number;
  allowedToHour: number;
  /** Atraso (h) para tipos disparados depois do evento. */
  delayHours: number;
  /** Máximo de mensagens por destinatário por dia (todas as automações). */
  maxPerRecipientPerDay: number;
}

export const DEFAULT_RULES: Record<MessageKind, AutomationRule> = Object.fromEntries(
  MESSAGE_KINDS.map((k) => [k, {
    kind: k,
    // Só lembrete, mudança e lista de espera vêm ligados: os demais exigem
    // ativação explícita da gestão.
    enabled: ["appointmentReminder", "appointmentChange", "waitlistOffer"].includes(k),
    paused: false,
    channels: ["inApp"],
    allowedFromHour: 8,
    allowedToHour: 20,
    delayHours: k === "satisfactionSurvey" ? 2 : k === "noShowFollowUp" ? 24 : 0,
    maxPerRecipientPerDay: 4,
  } as AutomationRule])
) as Record<MessageKind, AutomationRule>;

export function normalizeRule(kind: MessageKind, raw: unknown): AutomationRule {
  const r = (raw ?? {}) as Record<string, unknown>;
  const d = DEFAULT_RULES[kind];
  const hour = (v: unknown, def: number) =>
    Number.isInteger(v) && (v as number) >= 0 && (v as number) <= 24 ? (v as number) : def;
  let from = hour(r.allowedFromHour, d.allowedFromHour);
  let to = hour(r.allowedToHour, d.allowedToHour);
  if (from >= to) {
    from = d.allowedFromHour;
    to = d.allowedToHour;
  }
  const channels = Array.isArray(r.channels)
    ? [...new Set(r.channels.filter((c): c is Channel => (CHANNELS as readonly string[]).includes(c as string)))]
    : d.channels;
  const delay = Number(r.delayHours);
  const max = Number(r.maxPerRecipientPerDay);
  return {
    kind,
    enabled: typeof r.enabled === "boolean" ? r.enabled : d.enabled,
    paused: r.paused === true,
    channels: channels.length ? channels : d.channels,
    allowedFromHour: from,
    allowedToHour: to,
    delayHours: Number.isInteger(delay) && delay >= 0 && delay <= 24 * 30 ? delay : d.delayHours,
    maxPerRecipientPerDay: Number.isInteger(max) && max >= 1 && max <= 20 ? max : d.maxPerRecipientPerDay,
  };
}

/** Próximo instante dentro da janela permitida (ou o próprio, se já estiver). */
export function nextAllowedTime(ms: number, rule: Pick<AutomationRule, "allowedFromHour" | "allowedToHour">, tz = DEFAULT_TZ_OFFSET_MIN): number {
  const p = localParts(ms, tz);
  const from = rule.allowedFromHour * 60;
  const to = rule.allowedToHour * 60;
  if (p.minuteOfDay >= from && p.minuteOfDay < to) return ms;
  if (p.minuteOfDay < from) return p.dayStartMs + from * 60_000;
  return p.dayStartMs + 86_400_000 + from * 60_000;
}

// ------------------------------------------------------------------ Despacho

export interface QueueJob {
  kind: MessageKind;
  channel: Channel;
  recipientUid: string;
  clinicId: string | null;
  appointmentId?: string | null;
  scheduleVersion?: number | null;
  attempts: number;
  sendAtMs: number;
  /** Para lembrete: o início da consulta quando o job foi criado. */
  appointmentStartMs?: number | null;
  /** Para campanha: id da campanha aprovada. */
  campaignId?: string | null;
}

export interface DispatchContext {
  nowMs: number;
  rule: AutomationRule;
  clinicAutomationsPaused: boolean;
  appointment?: {
    status: string;
    patientId: string;
    scheduleVersion: number;
    startMs: number;
  } | null;
  recipient: {
    exists: boolean;
    /** Opt-out por canal (true = recusou). */
    optOut: Partial<Record<Channel, boolean>>;
    /** Preferência por tipo (false = desligado). */
    kindEnabled: boolean;
    /** Consentimento específico de marketing. */
    marketingConsent: boolean;
    suppressed: boolean;
  };
  sentToRecipientLast24h: number;
  /** Motivo exato se o canal não pode enviar (credencial, número, modelo). */
  channelBlocker: string | null;
  campaignApproved?: boolean;
}

export type Decision =
  | { action: "send" }
  | { action: "cancel"; reason: string }
  | { action: "defer"; untilMs: number; reason: string }
  | { action: "block"; reason: string };

export const MAX_ATTEMPTS = 3;

export function retryDelayMs(attempts: number): number {
  return Math.min(6 * 3_600_000, 5 * 60_000 * 2 ** Math.max(0, attempts - 1));
}

/**
 * Decide o destino do job no momento do envio. Ordem: o que invalida
 * (cancelar), o que é temporário (adiar), o que depende de configuração
 * externa (bloquear com motivo exato).
 */
export function dispatchDecision(job: QueueJob, ctx: DispatchContext): Decision {
  if (!ctx.rule.enabled) return { action: "cancel", reason: "automação desligada" };
  if (ctx.clinicAutomationsPaused) return { action: "defer", untilMs: ctx.nowMs + 3_600_000, reason: "automações da clínica pausadas" };
  if (ctx.rule.paused) return { action: "defer", untilMs: ctx.nowMs + 3_600_000, reason: "automação pausada" };
  if (!ctx.rule.channels.includes(job.channel)) return { action: "cancel", reason: "canal não autorizado na regra" };
  if (!ctx.recipient.exists) return { action: "cancel", reason: "destinatário inexistente" };
  if (ctx.recipient.optOut[job.channel]) return { action: "cancel", reason: "destinatário recusou o canal" };
  if (!ctx.recipient.kindEnabled) return { action: "cancel", reason: "destinatário desligou este tipo" };

  if (job.kind === "campaign") {
    if (!ctx.recipient.marketingConsent) return { action: "cancel", reason: "sem consentimento de marketing" };
    if (ctx.recipient.suppressed) return { action: "cancel", reason: "na lista de supressão" };
    if (ctx.campaignApproved !== true) return { action: "cancel", reason: "campanha não aprovada" };
  }

  const valid = VALID_APPOINTMENT_STATUS[job.kind];
  if (job.appointmentId) {
    const a = ctx.appointment;
    if (!a) return { action: "cancel", reason: "consulta inexistente" };
    if (a.patientId !== job.recipientUid) return { action: "cancel", reason: "destinatário mudou" };
    if (job.scheduleVersion != null && a.scheduleVersion !== job.scheduleVersion) {
      return { action: "cancel", reason: "consulta remarcada" };
    }
    if (valid && valid.length && !valid.includes(a.status)) {
      return { action: "cancel", reason: `consulta ${a.status}` };
    }
    if (job.kind === "appointmentReminder" && a.startMs <= ctx.nowMs) {
      return { action: "cancel", reason: "consulta já começou" };
    }
  }

  if (ctx.sentToRecipientLast24h >= ctx.rule.maxPerRecipientPerDay) {
    return { action: "defer", untilMs: ctx.nowMs + 6 * 3_600_000, reason: "limite diário do destinatário" };
  }
  const allowed = nextAllowedTime(ctx.nowMs, ctx.rule);
  if (allowed > ctx.nowMs) {
    // Lembrete que ficaria para depois da consulta não serve mais.
    if (job.kind === "appointmentReminder" && ctx.appointment && allowed >= ctx.appointment.startMs) {
      return { action: "cancel", reason: "fora da janela permitida antes da consulta" };
    }
    return { action: "defer", untilMs: allowed, reason: "fora do horário permitido" };
  }
  if (ctx.channelBlocker) return { action: "block", reason: ctx.channelBlocker };
  return { action: "send" };
}

// ------------------------------------------------------------------ WhatsApp

export interface WhatsAppConfigState {
  hasToken: boolean;
  hasPhoneNumberId: boolean;
  hasAppSecret: boolean;
  clinicEnabled: boolean;
  /** Modelos aprovados na Meta, por tipo. */
  approvedTemplates: Partial<Record<MessageKind, string>>;
  recipientPhone: string | null;
  recipientWhatsAppOptIn: boolean;
}

/** Motivo exato do bloqueio, ou null se o envio pode ser tentado. */
export function whatsappBlocker(kind: MessageKind, c: WhatsAppConfigState): string | null {
  if (!c.hasToken) return "WHATSAPP_TOKEN não configurado no servidor";
  if (!c.hasPhoneNumberId) return "WHATSAPP_PHONE_NUMBER_ID não configurado no servidor";
  if (!c.hasAppSecret) return "WHATSAPP_APP_SECRET não configurado (webhook não pode ser validado)";
  if (!c.clinicEnabled) return "WhatsApp não habilitado nas configurações da clínica";
  if (!c.approvedTemplates[kind]) return `modelo aprovado ausente para ${kind}`;
  if (!c.recipientPhone) return "responsável sem telefone válido";
  if (!c.recipientWhatsAppOptIn) return "responsável sem autorização para WhatsApp";
  return null;
}

/** Dia (local) usado como chave do contador de envios por destinatário. */
export function rateKey(recipientUid: string, ms: number): string {
  const p = localParts(ms);
  return `${recipientUid}_${Math.floor(p.dayStartMs / 86_400_000)}`;
}
