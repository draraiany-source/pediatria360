/**
 * Lembretes de consulta pelo WhatsApp Business Platform (Cloud API oficial
 * da Meta) — PREPARADO, NÃO ATIVADO.
 *
 * Este arquivo NÃO é exportado em `index.ts`: nenhum gatilho é implantado
 * e nenhuma mensagem sai enquanto não houver credenciais e autorização da
 * clínica. Aqui ficam só as partes puras e testáveis:
 *
 * - montar a mensagem de modelo (template) aprovada, com botões de resposta
 *   rápida Confirmar / Reagendar / Cancelar;
 * - enviar pela Graph API (com `fetch` injetável para teste);
 * - validar o webhook (desafio de verificação e assinatura
 *   `X-Hub-Signature-256`);
 * - ler os eventos de status (sent, delivered, read, failed) e as respostas.
 *
 * ## Para ativar (depois da autorização)
 *
 * 1. Verificar a empresa no Meta Business Manager e criar a conta WhatsApp
 *    Business (WABA) com o número oficial da clínica.
 * 2. Aprovar o modelo `lembrete_consulta_v1` (categoria utilidade, pt_BR),
 *    corpo com 5 variáveis e 3 botões de resposta rápida.
 * 3. Guardar como segredos do Firebase: WHATSAPP_TOKEN (token permanente de
 *    usuário do sistema), WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET e
 *    WHATSAPP_VERIFY_TOKEN.
 * 4. Criar os gatilhos (função agendada de envio e `onRequest` do webhook)
 *    usando estas funções, exportar em `index.ts` e implantar.
 *
 * Privacidade: o texto do modelo não leva motivo, queixa, exame nem
 * especialidade. Só primeiro nome do responsável e da criança, clínica,
 * data/hora e modalidade.
 */
import { createHmac, timingSafeEqual } from "crypto";

export const GRAPH_API_VERSION = "v21.0";
export const REMINDER_TEMPLATE = "lembrete_consulta_v1";

export type ReminderReply = "confirmar" | "reagendar" | "cancelar";
export const REPLIES: ReminderReply[] = ["confirmar", "reagendar", "cancelar"];

export interface ReminderParams {
  /** Destino em E.164 sem "+" (ex.: 5511900000001). */
  to: string;
  reminderId: string;
  guardianFirstName: string;
  childFirstName: string;
  clinicName: string;
  /** Ex.: "qui, 01/10 às 09:30". */
  whenLabel: string;
  teleconsulta: boolean;
}

/** Só dígitos, com DDI 55; `null` se não for um celular brasileiro válido. */
export function normalizeBrazilPhone(raw: string): string | null {
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 12 || digits.length > 13) return null;
  if (!digits.startsWith("55")) return null;
  return digits;
}

export function maskPhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  return digits.length < 4 ? "••••" : `•••• ${digits.slice(-4)}`;
}

function firstName(s: string): string {
  return s.trim().split(/\s+/)[0] ?? "";
}

/** Corpo da requisição `POST /{phone-number-id}/messages`. */
export function buildReminderTemplate(p: ReminderParams) {
  const text = (value: string) => ({ type: "text", text: value });
  return {
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: p.to,
    type: "template",
    template: {
      name: REMINDER_TEMPLATE,
      language: { code: "pt_BR" },
      components: [
        {
          type: "body",
          parameters: [
            text(firstName(p.guardianFirstName)),
            text(firstName(p.childFirstName)),
            text(p.clinicName),
            text(p.whenLabel),
            text(p.teleconsulta ? "online" : "presencial"),
          ],
        },
        ...REPLIES.map((reply, index) => ({
          type: "button",
          sub_type: "quick_reply",
          index: String(index),
          parameters: [{ type: "payload", payload: `${p.reminderId}:${reply}` }],
        })),
      ],
    },
  };
}

export interface SendResult {
  ok: boolean;
  messageId?: string;
  errorCode?: number;
  errorMessage?: string;
}

type FetchLike = (
  url: string,
  init: { method: string; headers: Record<string, string>; body: string }
) => Promise<{ ok: boolean; status: number; json: () => Promise<unknown> }>;

/** Envia pela Graph API. Não lança: falha volta como `ok: false`. */
export async function sendWhatsAppTemplate(
  payload: ReturnType<typeof buildReminderTemplate>,
  opts: {
    phoneNumberId: string;
    accessToken: string;
    fetchImpl?: FetchLike;
    apiVersion?: string;
  }
): Promise<SendResult> {
  if (!opts.phoneNumberId || !opts.accessToken) {
    return { ok: false, errorMessage: "WhatsApp não configurado." };
  }
  const doFetch = opts.fetchImpl ?? (fetch as unknown as FetchLike);
  const url =
    `https://graph.facebook.com/${opts.apiVersion ?? GRAPH_API_VERSION}` +
    `/${opts.phoneNumberId}/messages`;
  try {
    const res = await doFetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${opts.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const body = (await res.json()) as {
      messages?: Array<{ id?: string }>;
      error?: { code?: number; message?: string };
    };
    if (!res.ok || body.error) {
      return {
        ok: false,
        errorCode: body.error?.code ?? res.status,
        errorMessage: body.error?.message ?? `HTTP ${res.status}`,
      };
    }
    return { ok: true, messageId: body.messages?.[0]?.id };
  } catch (e) {
    return { ok: false, errorMessage: (e as Error).message };
  }
}

/** Desafio GET da Meta ao cadastrar o webhook. Devolve o texto a ecoar. */
export function verifyWebhookChallenge(
  query: Record<string, unknown>,
  verifyToken: string
): string | null {
  if (!verifyToken) return null;
  if (query["hub.mode"] !== "subscribe") return null;
  if (query["hub.verify_token"] !== verifyToken) return null;
  const challenge = query["hub.challenge"];
  return typeof challenge === "string" ? challenge : null;
}

/** Confere `X-Hub-Signature-256` (HMAC-SHA256 do corpo cru). */
export function verifySignature(
  rawBody: Buffer | string,
  header: string | undefined,
  appSecret: string
): boolean {
  if (!header || !appSecret || !header.startsWith("sha256=")) return false;
  const expected = createHmac("sha256", appSecret).update(rawBody).digest();
  const given = Buffer.from(header.slice("sha256=".length), "hex");
  return given.length === expected.length && timingSafeEqual(given, expected);
}

export type DeliveryStatus = "sent" | "delivered" | "read" | "failed";

export interface StatusEvent {
  messageId: string;
  status: DeliveryStatus;
  at: Date;
  recipient: string;
  errorCode?: number;
  errorTitle?: string;
}

export interface ReplyEvent {
  from: string;
  /** Id da mensagem de lembrete respondida. */
  contextMessageId?: string;
  reminderId: string;
  reply: ReminderReply;
  at: Date;
}

/** Status que exigem contato manual da recepção. */
export function needsManualContact(status: DeliveryStatus): boolean {
  return status === "failed";
}

/** Lê o corpo do webhook (`entry[].changes[].value`). Ignora o resto. */
export function parseWebhook(body: unknown): {
  statuses: StatusEvent[];
  replies: ReplyEvent[];
} {
  const statuses: StatusEvent[] = [];
  const replies: ReplyEvent[] = [];
  const entries = (body as { entry?: unknown[] })?.entry ?? [];
  for (const entry of entries as Array<{ changes?: unknown[] }>) {
    for (const change of (entry.changes ?? []) as Array<{
      value?: {
        statuses?: Array<Record<string, unknown>>;
        messages?: Array<Record<string, unknown>>;
      };
    }>) {
      const value = change.value ?? {};
      for (const s of value.statuses ?? []) {
        const status = s.status as DeliveryStatus;
        if (!["sent", "delivered", "read", "failed"].includes(status)) continue;
        const err = (s.errors as Array<{ code?: number; title?: string }>)?.[0];
        statuses.push({
          messageId: String(s.id),
          status,
          at: new Date(Number(s.timestamp) * 1000),
          recipient: maskPhone(String(s.recipient_id ?? "")),
          errorCode: err?.code,
          errorTitle: err?.title,
        });
      }
      for (const m of value.messages ?? []) {
        const button = m.button as { payload?: string } | undefined;
        const payload = button?.payload ?? "";
        const [reminderId, reply] = payload.split(":");
        if (!reminderId || !REPLIES.includes(reply as ReminderReply)) continue;
        replies.push({
          from: maskPhone(String(m.from ?? "")),
          contextMessageId: (m.context as { id?: string } | undefined)?.id,
          reminderId,
          reply: reply as ReminderReply,
          at: new Date(Number(m.timestamp) * 1000),
        });
      }
    }
  }
  return { statuses, replies };
}

/**
 * Qual lembrete enviar agora (horas antes da consulta). Se vários venceram
 * — função parada, por exemplo — envia só o mais próximo da consulta.
 * Espelha `dueReminderOffset` do app (lib/shared/scheduling/reminders.dart).
 */
export function dueReminderOffset(
  startsAt: Date,
  offsetsHours: number[],
  alreadyHandled: number[],
  now: Date
): number | null {
  if (startsAt.getTime() <= now.getTime()) return null;
  let due: number | null = null;
  for (const h of offsetsHours) {
    if (alreadyHandled.includes(h)) continue;
    const at = startsAt.getTime() - h * 3600_000;
    if (at > now.getTime()) continue;
    if (due === null || h < due) due = h;
  }
  return due;
}
