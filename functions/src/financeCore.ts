/**
 * Cálculos financeiros determinísticos (centavos inteiros, sem ponto
 * flutuante). O servidor decide valores e status; a IA só lê o resultado.
 */

export type ReceivableStatus = "pending" | "partial" | "paid" | "overdue" | "cancelled" | "refunded";
export const PAYMENT_METHODS = ["pix", "card", "cash", "transfer", "insurance", "other"] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export interface ReceivableState {
  totalCents: number;
  discountCents: number;
  paidCents: number;
  refundedCents: number;
  status: ReceivableStatus;
  dueAtMs?: number | null;
}

export type FinanceOp =
  | { type: "payment"; amountCents: number }
  | { type: "discount"; amountCents: number }
  | { type: "refund"; amountCents: number }
  | { type: "cancel" };

export class FinanceRuleError extends Error {}

export function isCents(v: unknown): v is number {
  return Number.isInteger(v) && (v as number) > 0 && (v as number) <= 100_000_000;
}

/** Quanto ainda falta receber. */
export function outstanding(s: ReceivableState): number {
  return Math.max(0, s.totalCents - s.discountCents - (s.paidCents - s.refundedCents));
}

export function deriveStatus(s: Omit<ReceivableState, "status"> & { status?: ReceivableStatus }, nowMs?: number): ReceivableStatus {
  if (s.status === "cancelled") return "cancelled";
  const net = s.paidCents - s.refundedCents;
  const due = s.totalCents - s.discountCents;
  if (s.refundedCents > 0 && net <= 0) return "refunded";
  if (net >= due) return "paid";
  if (nowMs != null && s.dueAtMs != null && s.dueAtMs < nowMs) return "overdue";
  if (net > 0) return "partial";
  return "pending";
}

/** Aplica uma operação; lança FinanceRuleError se violar as regras. */
export function applyFinanceOp(s: ReceivableState, op: FinanceOp, nowMs?: number): ReceivableState {
  if (s.status === "cancelled") throw new FinanceRuleError("Cobrança cancelada.");
  const next = { ...s };
  switch (op.type) {
    case "payment":
      if (!isCents(op.amountCents)) throw new FinanceRuleError("Valor inválido.");
      if (op.amountCents > outstanding(s)) throw new FinanceRuleError("Valor maior que o saldo em aberto.");
      next.paidCents += op.amountCents;
      break;
    case "discount":
      if (!isCents(op.amountCents)) throw new FinanceRuleError("Valor inválido.");
      if (op.amountCents > outstanding(s)) throw new FinanceRuleError("Desconto maior que o saldo em aberto.");
      next.discountCents += op.amountCents;
      break;
    case "refund":
      if (!isCents(op.amountCents)) throw new FinanceRuleError("Valor inválido.");
      if (op.amountCents > s.paidCents - s.refundedCents) throw new FinanceRuleError("Estorno maior que o valor pago.");
      next.refundedCents += op.amountCents;
      break;
    case "cancel":
      if (s.paidCents - s.refundedCents > 0) {
        throw new FinanceRuleError("Há valor pago: estorne antes de cancelar.");
      }
      return { ...next, status: "cancelled" };
  }
  next.status = deriveStatus(next, nowMs);
  return next;
}

// ------------------------------------------------------------------ Provedor de pagamento

export type ProviderStatus = "pending" | "authorized" | "paid" | "failed" | "expired" | "refunded";
const PROVIDER_RANK: Record<ProviderStatus, number> = {
  pending: 0, failed: 1, expired: 1, authorized: 2, paid: 3, refunded: 4,
};

export interface ProviderEvent {
  eventId: string;
  paymentId: string;
  receivableId: string;
  status: ProviderStatus;
  amountCents: number;
  occurredAtMs: number;
}

export type ProviderDecision =
  | { action: "ignore"; reason: string }
  | { action: "record"; op: FinanceOp | null; providerStatus: ProviderStatus };

/**
 * O que fazer com um evento do provedor. Retorno da página de pagamento
 * nunca chega aqui: só o webhook assinado. Evento antigo/fora de ordem não
 * rebaixa o estado; valor divergente não é aceito.
 */
export function providerEventDecision(
  e: ProviderEvent,
  current: { providerStatus: ProviderStatus | null; providerUpdatedAtMs: number | null; receivable: ReceivableState }
): ProviderDecision {
  const curRank = current.providerStatus ? PROVIDER_RANK[current.providerStatus] : -1;
  if (PROVIDER_RANK[e.status] < curRank) return { action: "ignore", reason: "evento fora de ordem" };
  if (PROVIDER_RANK[e.status] === curRank && e.status === current.providerStatus) {
    return { action: "ignore", reason: "status já aplicado" };
  }
  if (e.status === "paid") {
    if (e.amountCents !== outstanding(current.receivable)) {
      return { action: "ignore", reason: "valor diferente do saldo em aberto" };
    }
    return { action: "record", op: { type: "payment", amountCents: e.amountCents }, providerStatus: "paid" };
  }
  if (e.status === "refunded") {
    const net = current.receivable.paidCents - current.receivable.refundedCents;
    if (e.amountCents > net) return { action: "ignore", reason: "estorno maior que o pago" };
    return { action: "record", op: { type: "refund", amountCents: e.amountCents }, providerStatus: "refunded" };
  }
  return { action: "record", op: null, providerStatus: e.status };
}

// ------------------------------------------------------------------ Indicadores

export interface ReceiptRow { amountCents: number; method: string; issuedAtMs: number; professionalId?: string | null; unitId?: string | null; refund?: boolean }
export interface ReceivableRow extends ReceivableState { dueAtMs: number; professionalId?: string | null; unitId?: string | null }
export interface PayableRow { amountCents: number; paidCents: number; dueAtMs: number; paidAtMs?: number | null; status: string; unitId?: string | null }

export interface FinanceSummary {
  receivedCents: number;
  refundedCents: number;
  byMethod: Record<string, number>;
  forecastCents: number;
  pendingCents: number;
  overdueCents: number;
  expensesPaidCents: number;
  expensesDueCents: number;
  netCashCents: number;
  byProfessional: Record<string, number>;
  byUnit: Record<string, number>;
  counts: { receipts: number; receivables: number; payables: number };
}

/** Fluxo de caixa do período: previsto (vencimentos) x realizado (recibos). */
export function summarizeFinance(
  period: { fromMs: number; toMs: number },
  receipts: ReceiptRow[],
  receivables: ReceivableRow[],
  payables: PayableRow[],
  nowMs: number
): FinanceSummary {
  const inP = (ms: number | null | undefined) => ms != null && ms >= period.fromMs && ms < period.toMs;
  const s: FinanceSummary = {
    receivedCents: 0, refundedCents: 0, byMethod: {}, forecastCents: 0, pendingCents: 0, overdueCents: 0,
    expensesPaidCents: 0, expensesDueCents: 0, netCashCents: 0, byProfessional: {}, byUnit: {},
    counts: { receipts: 0, receivables: 0, payables: 0 },
  };
  for (const r of receipts) {
    if (!inP(r.issuedAtMs)) continue;
    s.counts.receipts++;
    if (r.refund) {
      s.refundedCents += r.amountCents;
      continue;
    }
    s.receivedCents += r.amountCents;
    s.byMethod[r.method] = (s.byMethod[r.method] ?? 0) + r.amountCents;
    const p = r.professionalId ?? "sem profissional";
    s.byProfessional[p] = (s.byProfessional[p] ?? 0) + r.amountCents;
    const u = r.unitId ?? "sem unidade";
    s.byUnit[u] = (s.byUnit[u] ?? 0) + r.amountCents;
  }
  for (const r of receivables) {
    if (r.status === "cancelled" || !inP(r.dueAtMs)) continue;
    s.counts.receivables++;
    s.forecastCents += r.totalCents - r.discountCents;
    const open = outstanding(r);
    s.pendingCents += open;
    if (open > 0 && r.dueAtMs < nowMs) s.overdueCents += open;
  }
  for (const p of payables) {
    if (p.status === "cancelled") continue;
    if (inP(p.paidAtMs)) s.expensesPaidCents += p.paidCents;
    if (inP(p.dueAtMs)) {
      s.counts.payables++;
      s.expensesDueCents += Math.max(0, p.amountCents - p.paidCents);
    }
  }
  s.netCashCents = s.receivedCents - s.refundedCents - s.expensesPaidCents;
  return s;
}
