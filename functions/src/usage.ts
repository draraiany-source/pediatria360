/**
 * Limites de uso e custo estimado por clínica e usuário.
 *
 * Cada consumo tem chave de idempotência (`usage_events/{chave}`): repetir a
 * chamada não conta duas vezes. Limites ficam em `clinics/{c}/settings/usage`.
 * O custo é estimativa com preços unitários configuráveis — não é fatura.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { clinicRoleOf } from "./clinicFlow";
import { localParts } from "./schedulingCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

export const USAGE_KINDS = ["aiRequests", "audioMinutes", "attachmentsMb", "messages"] as const;
export type UsageKind = (typeof USAGE_KINDS)[number];

export interface UsageLimits {
  perClinicMonth: Record<UsageKind, number>;
  aiRequestsPerUserDay: number;
  /** Preço unitário estimado em centavos (premissa, ajustável). */
  unitCostCents: Record<UsageKind, number>;
}

export const DEFAULT_LIMITS: UsageLimits = {
  perClinicMonth: { aiRequests: 2000, audioMinutes: 1200, attachmentsMb: 5000, messages: 3000 },
  aiRequestsPerUserDay: 100,
  // Premissas: IA ~R$0,05/requisição; transcrição ~R$0,04/min; armazenamento
  // ~R$0,0015/MB-mês; WhatsApp utilidade ~R$0,08/mensagem (aviso no app = 0).
  unitCostCents: { aiRequests: 5, audioMinutes: 4, attachmentsMb: 0.15, messages: 8 },
};

export function normalizeLimits(raw: unknown): UsageLimits {
  const r = (raw ?? {}) as Record<string, Record<string, unknown> | number>;
  const pcm = (r.perClinicMonth ?? {}) as Record<string, unknown>;
  const unit = (r.unitCostCents ?? {}) as Record<string, unknown>;
  const perClinicMonth = { ...DEFAULT_LIMITS.perClinicMonth };
  const unitCostCents = { ...DEFAULT_LIMITS.unitCostCents };
  for (const k of USAGE_KINDS) {
    const v = Number(pcm[k]);
    if (Number.isInteger(v) && v >= 0 && v <= 10_000_000) perClinicMonth[k] = v;
    const u = Number(unit[k]);
    if (Number.isFinite(u) && u >= 0 && u <= 10_000) unitCostCents[k] = u;
  }
  const perUser = Number(r.aiRequestsPerUserDay);
  return {
    perClinicMonth,
    aiRequestsPerUserDay: Number.isInteger(perUser) && perUser >= 0 && perUser <= 10_000 ? perUser : DEFAULT_LIMITS.aiRequestsPerUserDay,
    unitCostCents,
  };
}

export function monthKey(ms: number): string {
  const d = new Date(localParts(ms).dayStartMs + 12 * 3_600_000);
  return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function dayKey(ms: number): string {
  return String(Math.floor(localParts(ms).dayStartMs / 86_400_000));
}

export class UsageLimitError extends Error {}

/**
 * Consome cota em transação. Lança UsageLimitError se exceder. Mesma chave
 * = mesmo consumo (não cobra de novo).
 */
export async function consumeUsage(clinicId: string, uid: string | null, kind: UsageKind, amount: number, idempotencyKey: string): Promise<{ replay: boolean }> {
  const nowMs = Date.now();
  const limits = normalizeLimits((await db().collection("clinics").doc(clinicId).collection("settings").doc("usage").get()).data()?.limits);
  const evRef = db().collection("usage_events").doc(`${clinicId}_${idempotencyKey}`.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 200));
  const monthRef = db().collection("usage_counters").doc(`${clinicId}_${monthKey(nowMs)}`);
  const userRef = uid ? db().collection("usage_counters").doc(`${clinicId}_${uid}_${dayKey(nowMs)}`) : null;
  return db().runTransaction(async (tx) => {
    const reads = await tx.getAll(evRef, monthRef, ...(userRef ? [userRef] : []));
    if (reads[0].exists) return { replay: true };
    const used = Number(reads[1].get(kind) ?? 0);
    if (used + amount > limits.perClinicMonth[kind]) throw new UsageLimitError(`Limite mensal da clínica atingido (${kind}).`);
    if (userRef && kind === "aiRequests") {
      const u = Number(reads[2].get(kind) ?? 0);
      if (u + amount > limits.aiRequestsPerUserDay) throw new UsageLimitError("Limite diário de uso da IA atingido.");
      tx.set(userRef, { [kind]: FieldValue.increment(amount), clinicId, uid, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    tx.set(evRef, { clinicId, uid, kind, amount, at: FieldValue.serverTimestamp() });
    tx.set(monthRef, { [kind]: FieldValue.increment(amount), clinicId, month: monthKey(nowMs), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { replay: false };
  });
}

/** Lança HttpsError amigável quando o limite estoura. */
export async function consumeOrThrow(clinicId: string, uid: string | null, kind: UsageKind, amount: number, key: string) {
  try {
    return await consumeUsage(clinicId, uid, kind, amount, key);
  } catch (e) {
    if (e instanceof UsageLimitError) throw new HttpsError("resource-exhausted", e.message);
    throw e;
  }
}

export const saveUsageLimits = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = typeof d.clinicId === "string" ? d.clinicId : "";
  if (!clinicId || (await clinicRoleOf(clinicId, uid)) !== "clinicAdmin") throw new HttpsError("permission-denied", "Somente a gestão.");
  const limits = normalizeLimits(d.limits);
  await db().collection("clinics").doc(clinicId).collection("settings").doc("usage").set({ limits, updatedBy: uid, updatedAt: FieldValue.serverTimestamp() });
  return { limits };
});

/** Painel de uso e custo estimado (gestão). */
export const getUsageDashboard = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = typeof d.clinicId === "string" ? d.clinicId : "";
  if (!clinicId || (await clinicRoleOf(clinicId, uid)) !== "clinicAdmin") throw new HttpsError("permission-denied", "Somente a gestão.");
  const limits = normalizeLimits((await db().collection("clinics").doc(clinicId).collection("settings").doc("usage").get()).data()?.limits);
  const month = typeof d.month === "string" && /^\d{6}$/.test(d.month) ? d.month : monthKey(Date.now());
  const c = (await db().collection("usage_counters").doc(`${clinicId}_${month}`).get()).data() ?? {};
  const rows = USAGE_KINDS.map((k) => {
    const used = Number(c[k] ?? 0);
    return { kind: k, used, limit: limits.perClinicMonth[k], estimatedCostCents: Math.round(used * limits.unitCostCents[k]) };
  });
  return {
    month,
    rows,
    totalEstimatedCostCents: rows.reduce((s, r) => s + r.estimatedCostCents, 0),
    assumptions: limits.unitCostCents,
    note: "Estimativa com preços unitários configurados; não substitui a fatura dos provedores.",
  };
});
