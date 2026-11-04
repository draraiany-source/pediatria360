/**
 * Financeiro integrado à consulta, com operações idempotentes no servidor.
 *
 * Reaproveita as coleções existentes (finance_receivables, finance_receipts,
 * finance_audit_logs). Cada operação tem chave de idempotência e vira um
 * documento `finance_operations/{cobrança}_{chave}`: repetir a chamada (rede
 * instável, toque duplo, reenvio do provedor) devolve o mesmo resultado sem
 * lançar de novo. "Pago" só vem de registro da equipe ou de webhook assinado
 * do provedor, nunca do retorno da página de pagamento.
 */

import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { createHmac, timingSafeEqual } from "crypto";
import { clinicRoleOf } from "./clinicFlow";
import {
  applyFinanceOp,
  FinanceOp,
  FinanceRuleError,
  isCents,
  PAYMENT_METHODS,
  providerEventDecision,
  ProviderEvent,
  ProviderStatus,
  ReceivableState,
  summarizeFinance,
} from "./financeCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const PAYMENT_WEBHOOK_SECRET = defineSecret("PAYMENT_WEBHOOK_SECRET");

export const FINANCE_WRITE_ROLES = ["clinicAdmin", "finance"];
/** Recepção registra pagamento no balcão, mas não estorna nem cancela. */
const PAYMENT_DESK_ROLES = ["clinicAdmin", "finance", "receptionist"];
export const FINANCE_READ_ROLES = ["clinicAdmin", "finance"];

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

function key(v: unknown): string {
  if (typeof v !== "string" || !/^[A-Za-z0-9_-]{8,80}$/.test(v)) {
    throw new HttpsError("invalid-argument", "Chave de idempotência inválida.");
  }
  return v;
}

async function requireFinanceRole(clinicId: unknown, uid: string, roles: string[]): Promise<string> {
  if (typeof clinicId !== "string" || !clinicId || clinicId.includes("/")) {
    throw new HttpsError("invalid-argument", "Clínica inválida.");
  }
  const role = await clinicRoleOf(clinicId, uid);
  if (!role || !roles.includes(role)) throw new HttpsError("permission-denied", "Sem permissão financeira.");
  return role;
}

function stateOf(d: Record<string, unknown>): ReceivableState {
  return {
    totalCents: Number(d.totalCents ?? 0),
    discountCents: Number(d.discountCents ?? 0),
    paidCents: Number(d.paidCents ?? 0),
    refundedCents: Number(d.refundedCents ?? 0),
    status: (d.status as ReceivableState["status"]) ?? "pending",
    dueAtMs: d.dueAt instanceof Timestamp ? d.dueAt.toMillis() : null,
  };
}

const AUDIT_ACTION: Record<FinanceOp["type"], string> = {
  payment: "paymentRegistered",
  discount: "discountApplied",
  refund: "receivableRefunded",
  cancel: "receivableCancelled",
};

/**
 * Aplica a operação de forma idempotente. Devolve o estado final e se foi
 * repetição.
 */
export async function applyOperation(args: {
  receivableId: string;
  clinicId: string | null;
  op: FinanceOp;
  idempotencyKey: string;
  actorUid: string;
  method?: string | null;
  reason?: string | null;
  source: "staff" | "provider";
  providerStatus?: ProviderStatus | null;
  providerAtMs?: number | null;
}): Promise<{ state: ReceivableState; replay: boolean }> {
  const recRef = db().collection("finance_receivables").doc(args.receivableId);
  const opRef = db().collection("finance_operations").doc(`${args.receivableId}_${args.idempotencyKey}`);
  return db().runTransaction(async (tx) => {
    const [rec, prev] = await tx.getAll(recRef, opRef);
    if (!rec.exists) throw new HttpsError("not-found", "Cobrança não encontrada.");
    const r = rec.data() ?? {};
    if (args.clinicId !== null && r.clinicId !== args.clinicId) throw new HttpsError("not-found", "Cobrança não encontrada.");
    if (prev.exists) {
      const p = prev.data() ?? {};
      if (p.type !== args.op.type || (p.amountCents ?? null) !== ("amountCents" in args.op ? args.op.amountCents : null)) {
        throw new HttpsError("already-exists", "Esta chave já foi usada para outra operação.");
      }
      return { state: stateOf(r), replay: true };
    }
    let next: ReceivableState;
    try {
      next = applyFinanceOp(stateOf(r), args.op, Date.now());
    } catch (e) {
      if (e instanceof FinanceRuleError) throw new HttpsError("failed-precondition", e.message);
      throw e;
    }
    const amount = "amountCents" in args.op ? args.op.amountCents : null;
    tx.set(opRef, {
      receivableId: args.receivableId,
      clinicId: r.clinicId ?? null,
      unitId: r.unitId ?? null,
      professionalId: r.professionalId ?? null,
      type: args.op.type,
      amountCents: amount,
      method: args.method ?? null,
      reason: args.reason ?? null,
      source: args.source,
      byUserId: args.actorUid,
      at: FieldValue.serverTimestamp(),
      atMs: Date.now(),
    });
    tx.update(recRef, {
      paidCents: next.paidCents,
      discountCents: next.discountCents,
      refundedCents: next.refundedCents,
      status: next.status,
      updatedAt: FieldValue.serverTimestamp(),
      ...(next.status === "cancelled" ? { cancelledAt: FieldValue.serverTimestamp(), cancelReason: args.reason ?? null } : {}),
      ...(args.providerStatus ? { providerStatus: args.providerStatus, providerUpdatedAtMs: args.providerAtMs ?? null } : {}),
    });
    if (args.op.type === "payment") {
      tx.set(db().collection("finance_receipts").doc(`rcp_${args.receivableId}_${args.idempotencyKey}`), {
        ownerId: r.ownerId ?? args.actorUid,
        receivableId: args.receivableId,
        amountCents: amount,
        method: args.method ?? "other",
        issuedAt: FieldValue.serverTimestamp(),
        patientId: r.childId ?? r.patientId ?? null,
        clinicId: r.clinicId ?? null,
        unitId: r.unitId ?? null,
        professionalId: r.professionalId ?? null,
        source: args.source,
      });
    }
    tx.set(db().collection("finance_audit_logs").doc(), {
      ownerId: r.ownerId ?? args.actorUid,
      action: AUDIT_ACTION[args.op.type],
      entityType: "receivable",
      entityId: args.receivableId,
      byUserId: args.actorUid,
      clinicId: r.clinicId ?? null,
      unitId: r.unitId ?? null,
      metadata: { amountCents: amount, method: args.method ?? null, source: args.source, key: args.idempotencyKey },
      createdAt: FieldValue.serverTimestamp(),
    });
    if (r.appointmentId) {
      const paid = next.status === "paid";
      tx.set(db().collection("appointments").doc(String(r.appointmentId)), { paid }, { merge: true });
    }
    return { state: next, replay: false };
  });
}

/** Cobrança da consulta: uma por consulta (id determinístico). */
export const createCharge = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireFinanceRole(d.clinicId, uid, PAYMENT_DESK_ROLES);
  const clinicId = String(d.clinicId);
  const apptId = typeof d.appointmentId === "string" && !d.appointmentId.includes("/") ? d.appointmentId : null;
  let base: Record<string, unknown> = {};
  let receivableId: string;
  if (apptId) {
    const a = (await db().collection("appointments").doc(apptId).get()).data();
    if (!a || a.clinicId !== clinicId) throw new HttpsError("not-found", "Consulta não encontrada.");
    if (a.status === "cancelled") throw new HttpsError("failed-precondition", "Consulta cancelada.");
    base = {
      appointmentId: apptId,
      patientId: a.patientId ?? null,
      childId: a.childId ?? null,
      professionalId: a.professionalId ?? null,
      professionalName: a.professionalName ?? null,
      unitId: a.unitId ?? null,
      serviceId: a.serviceId ?? null,
      origin: a.type === "teleconsulta" ? "teleconsult" : "private",
      totalCents: isCents(d.amountCents) ? d.amountCents : Number(a.priceCents ?? 0),
    };
    receivableId = `apt_${apptId}`;
  } else {
    base = { origin: "other", totalCents: d.amountCents, unitId: typeof d.unitId === "string" ? d.unitId : null };
    receivableId = `chg_${clinicId}_${key(d.idempotencyKey)}`;
  }
  if (!isCents(base.totalCents)) throw new HttpsError("invalid-argument", "Informe o valor da cobrança.");
  const dueAtMs = Date.parse(String(d.dueAt ?? ""));
  const ref = db().collection("finance_receivables").doc(receivableId);
  const created = await db().runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, {
      ...base,
      ownerId: uid,
      clinicId,
      description: typeof d.description === "string" ? d.description.slice(0, 120) : "Atendimento",
      discountCents: 0,
      paidCents: 0,
      refundedCents: 0,
      status: "pending",
      dueAt: Timestamp.fromMillis(Number.isFinite(dueAtMs) ? dueAtMs : Date.now()),
      createdAt: FieldValue.serverTimestamp(),
      createdBy: uid,
    });
    tx.set(db().collection("finance_audit_logs").doc(), {
      ownerId: uid, action: "receivableCreated", entityType: "receivable", entityId: receivableId,
      byUserId: uid, clinicId, metadata: { amountCents: base.totalCents }, createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  return { receivableId, created };
});

function opCallable(type: FinanceOp["type"], roles: string[]) {
  return onCall({ region: REGION }, async (request) => {
    const uid = uidOf(request);
    const d = (request.data ?? {}) as Record<string, unknown>;
    await requireFinanceRole(d.clinicId, uid, roles);
    const receivableId = typeof d.receivableId === "string" && !d.receivableId.includes("/") ? d.receivableId : "";
    if (!receivableId) throw new HttpsError("invalid-argument", "Cobrança inválida.");
    const reason = typeof d.reason === "string" ? d.reason.slice(0, 200) : null;
    if ((type === "refund" || type === "cancel" || type === "discount") && !reason) {
      throw new HttpsError("invalid-argument", "Informe o motivo.");
    }
    const method = type === "payment" ? String(d.method ?? "") : null;
    if (type === "payment" && !(PAYMENT_METHODS as readonly string[]).includes(method!)) {
      throw new HttpsError("invalid-argument", "Forma de pagamento inválida.");
    }
    const op: FinanceOp = type === "cancel" ? { type } : { type, amountCents: Number(d.amountCents) };
    const { state, replay } = await applyOperation({
      receivableId, clinicId: String(d.clinicId), op, idempotencyKey: key(d.idempotencyKey),
      actorUid: uid, method, reason, source: "staff",
    });
    return { ...state, replay };
  });
}

export const recordPayment = opCallable("payment", PAYMENT_DESK_ROLES);
export const applyDiscount = opCallable("discount", FINANCE_WRITE_ROLES);
export const refundPayment = opCallable("refund", FINANCE_WRITE_ROLES);
export const cancelCharge = opCallable("cancel", FINANCE_WRITE_ROLES);

// ------------------------------------------------------------------ Provedor

/** Aplica um evento do provedor já autenticado. Idempotente por evento e por pagamento. */
export async function applyProviderEvent(provider: string, e: ProviderEvent): Promise<{ outcome: string }> {
  const evRef = db().collection("payment_events").doc(`${provider}_${e.eventId}`);
  try {
    await evRef.create({ provider, paymentId: e.paymentId, receivableId: e.receivableId, status: e.status, receivedAt: FieldValue.serverTimestamp() });
  } catch {
    return { outcome: "duplicate" };
  }
  const rec = (await db().collection("finance_receivables").doc(e.receivableId).get()).data();
  if (!rec) {
    await evRef.update({ outcome: "unknown receivable" });
    return { outcome: "unknown receivable" };
  }
  const decision = providerEventDecision(e, {
    providerStatus: (rec.providerStatus as ProviderStatus) ?? null,
    providerUpdatedAtMs: (rec.providerUpdatedAtMs as number) ?? null,
    receivable: stateOf(rec),
  });
  if (decision.action === "ignore") {
    await evRef.update({ outcome: decision.reason });
    return { outcome: decision.reason };
  }
  if (decision.op) {
    try {
      await applyOperation({
        receivableId: e.receivableId, clinicId: null, op: decision.op,
        // Chave por pagamento do provedor: eventos diferentes do mesmo
        // pagamento não lançam duas vezes.
        idempotencyKey: `prov_${provider}_${e.paymentId}_${decision.op.type}`.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 80),
        actorUid: `provider:${provider}`, method: "other", reason: null, source: "provider",
        providerStatus: decision.providerStatus, providerAtMs: e.occurredAtMs,
      });
    } catch (err) {
      const msg = err instanceof HttpsError ? err.message : "erro";
      await evRef.update({ outcome: `rejeitado: ${msg}` });
      return { outcome: `rejeitado: ${msg}` };
    }
  } else {
    await db().collection("finance_receivables").doc(e.receivableId).update({ providerStatus: decision.providerStatus, providerUpdatedAtMs: e.occurredAtMs });
  }
  await evRef.update({ outcome: "applied" });
  return { outcome: "applied" };
}

/**
 * Webhook genérico de provedor de pagamento. Exige HMAC-SHA256 do corpo com
 * PAYMENT_WEBHOOK_SECRET em `x-signature`. Sem segredo configurado, recusa
 * tudo (503): nenhum provedor está integrado nesta etapa.
 */
export const paymentWebhook = onRequest({ region: REGION, secrets: [PAYMENT_WEBHOOK_SECRET] }, async (req, res) => {
  let secret = "";
  try {
    secret = PAYMENT_WEBHOOK_SECRET.value() ?? "";
  } catch {
    secret = "";
  }
  if (!secret) {
    res.status(503).send("provedor de pagamento não configurado");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).send("method");
    return;
  }
  const raw = (req as unknown as { rawBody?: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body ?? {}));
  const header = String(req.get("x-signature") ?? "");
  const expected = createHmac("sha256", secret).update(raw).digest();
  const given = Buffer.from(header.replace(/^sha256=/, ""), "hex");
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    res.status(401).send("signature");
    return;
  }
  const b = (req.body ?? {}) as Record<string, unknown>;
  const statuses: ProviderStatus[] = ["pending", "authorized", "paid", "failed", "expired", "refunded"];
  const e: ProviderEvent = {
    eventId: String(b.eventId ?? ""),
    paymentId: String(b.paymentId ?? ""),
    receivableId: String(b.receivableId ?? ""),
    status: b.status as ProviderStatus,
    amountCents: Number(b.amountCents),
    occurredAtMs: Number(b.occurredAtMs ?? Date.now()),
  };
  if (!e.eventId || !e.paymentId || !e.receivableId || e.receivableId.includes("/") || !statuses.includes(e.status) || !Number.isInteger(e.amountCents)) {
    res.status(400).send("payload");
    return;
  }
  const provider = typeof b.provider === "string" && /^[a-z0-9_-]{2,30}$/.test(b.provider) ? b.provider : "generic";
  res.status(200).json(await applyProviderEvent(provider, e));
});

// ------------------------------------------------------------------ Indicadores

function ms(v: unknown): number | null {
  return v instanceof Timestamp ? v.toMillis() : null;
}

/** Resumo financeiro determinístico (também usado pela Central de IA). */
export async function financeSummary(clinicId: string, fromMs: number, toMs: number, filters: { professionalId?: string | null; unitId?: string | null }) {
  const [receipts, receivables, payables, refunds] = await Promise.all([
    db().collection("finance_receipts").where("clinicId", "==", clinicId)
      .where("issuedAt", ">=", Timestamp.fromMillis(fromMs)).where("issuedAt", "<", Timestamp.fromMillis(toMs)).limit(5000).get(),
    db().collection("finance_receivables").where("clinicId", "==", clinicId)
      .where("dueAt", ">=", Timestamp.fromMillis(fromMs)).where("dueAt", "<", Timestamp.fromMillis(toMs)).limit(5000).get(),
    db().collection("finance_payables").where("clinicId", "==", clinicId).limit(5000).get(),
    db().collection("finance_operations").where("clinicId", "==", clinicId).where("type", "==", "refund")
      .where("atMs", ">=", fromMs).where("atMs", "<", toMs).limit(5000).get(),
  ]);
  const match = (d: FirebaseFirestore.DocumentData) =>
    (!filters.professionalId || d.professionalId === filters.professionalId) && (!filters.unitId || d.unitId === filters.unitId);
  const summary = summarizeFinance(
    { fromMs, toMs },
    [
      ...receipts.docs.map((r) => r.data()).filter(match).map((r) => ({
        amountCents: Number(r.amountCents ?? 0), method: String(r.method ?? "other"), issuedAtMs: ms(r.issuedAt) ?? 0,
        professionalId: r.professionalId ?? null, unitId: r.unitId ?? null,
      })),
      ...refunds.docs.map((r) => r.data()).filter(match).map((r) => ({
        amountCents: Number(r.amountCents ?? 0), method: "estorno", issuedAtMs: Number(r.atMs), refund: true,
      })),
    ],
    receivables.docs.map((r) => r.data()).filter(match).map((r) => ({ ...stateOf(r), dueAtMs: ms(r.dueAt) ?? 0 })),
    filters.professionalId ? [] : payables.docs.map((p) => p.data()).filter((p) => !filters.unitId || p.unitId === filters.unitId).map((p) => ({
      amountCents: Number(p.amountCents ?? p.totalCents ?? 0), paidCents: Number(p.paidCents ?? 0),
      dueAtMs: ms(p.dueAt) ?? 0, paidAtMs: ms(p.paidAt), status: String(p.status ?? "pending"), unitId: p.unitId ?? null,
    })),
    Date.now()
  );
  return summary;
}

export const getFinanceSummary = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireFinanceRole(d.clinicId, uid, FINANCE_READ_ROLES);
  const fromMs = Date.parse(String(d.from ?? ""));
  const toMs = Date.parse(String(d.to ?? ""));
  if (!Number.isFinite(fromMs) || !Number.isFinite(toMs) || toMs <= fromMs || toMs - fromMs > 400 * 86_400_000) {
    throw new HttpsError("invalid-argument", "Período inválido.");
  }
  const filters = { professionalId: typeof d.professionalId === "string" ? d.professionalId : null, unitId: typeof d.unitId === "string" ? d.unitId : null };
  const summary = await financeSummary(String(d.clinicId), fromMs, toMs, filters);
  return { summary, period: { from: new Date(fromMs).toISOString(), to: new Date(toMs).toISOString() }, filters, source: "finance_receipts, finance_receivables, finance_payables, finance_operations" };
});
