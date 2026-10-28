import { applyFinanceOp, deriveStatus, FinanceRuleError, outstanding, providerEventDecision, ReceivableState, summarizeFinance } from "./financeCore";

const base: ReceivableState = { totalCents: 30000, discountCents: 0, paidCents: 0, refundedCents: 0, status: "pending" };

describe("operações", () => {
  it("pagamento parcial, desconto e quitação", () => {
    let s = applyFinanceOp(base, { type: "payment", amountCents: 10000 });
    expect(s.status).toBe("partial");
    s = applyFinanceOp(s, { type: "discount", amountCents: 5000 });
    expect(outstanding(s)).toBe(15000);
    s = applyFinanceOp(s, { type: "payment", amountCents: 15000 });
    expect(s.status).toBe("paid");
  });
  it("não aceita pagar além do saldo, valor quebrado ou negativo", () => {
    expect(() => applyFinanceOp(base, { type: "payment", amountCents: 30001 })).toThrow(FinanceRuleError);
    expect(() => applyFinanceOp(base, { type: "payment", amountCents: 10.5 })).toThrow(FinanceRuleError);
    expect(() => applyFinanceOp(base, { type: "payment", amountCents: -1 })).toThrow(FinanceRuleError);
  });
  it("estorno até o pago; cancelamento só sem valor pago", () => {
    const paid = applyFinanceOp(base, { type: "payment", amountCents: 30000 });
    expect(() => applyFinanceOp(paid, { type: "cancel" })).toThrow("estorne");
    expect(() => applyFinanceOp(paid, { type: "refund", amountCents: 30001 })).toThrow(FinanceRuleError);
    const refunded = applyFinanceOp(paid, { type: "refund", amountCents: 30000 });
    expect(refunded.status).toBe("refunded");
    expect(applyFinanceOp(refunded, { type: "cancel" }).status).toBe("cancelled");
    expect(() => applyFinanceOp({ ...base, status: "cancelled" }, { type: "payment", amountCents: 1 })).toThrow("cancelada");
  });
  it("vencido sem pagamento vira overdue", () => {
    expect(deriveStatus({ ...base, dueAtMs: 1000 }, 2000)).toBe("overdue");
  });
});

describe("eventos do provedor", () => {
  const ev = { eventId: "e1", paymentId: "p1", receivableId: "r1", amountCents: 30000, occurredAtMs: 1 };
  it("pago com valor certo registra pagamento", () => {
    expect(providerEventDecision({ ...ev, status: "paid" }, { providerStatus: "pending", providerUpdatedAtMs: 0, receivable: base }))
      .toEqual({ action: "record", op: { type: "payment", amountCents: 30000 }, providerStatus: "paid" });
  });
  it("evento atrasado não rebaixa; repetido é ignorado; valor divergente é recusado", () => {
    expect(providerEventDecision({ ...ev, status: "pending" }, { providerStatus: "paid", providerUpdatedAtMs: 0, receivable: base }).action).toBe("ignore");
    expect(providerEventDecision({ ...ev, status: "paid" }, { providerStatus: "paid", providerUpdatedAtMs: 0, receivable: base }).action).toBe("ignore");
    expect(providerEventDecision({ ...ev, status: "paid", amountCents: 100 }, { providerStatus: null, providerUpdatedAtMs: null, receivable: base }))
      .toEqual({ action: "ignore", reason: "valor diferente do saldo em aberto" });
  });
});

describe("resumo do período", () => {
  it("previsto x realizado, por forma de pagamento e despesas", () => {
    const s = summarizeFinance(
      { fromMs: 0, toMs: 100 },
      [
        { amountCents: 10000, method: "pix", issuedAtMs: 10, professionalId: "dra" },
        { amountCents: 5000, method: "card", issuedAtMs: 20 },
        { amountCents: 2000, method: "pix", issuedAtMs: 30, refund: true },
        { amountCents: 9999, method: "pix", issuedAtMs: 500 },
      ],
      [
        { ...base, dueAtMs: 50 },
        { ...base, paidCents: 30000, status: "paid", dueAtMs: 60 },
        { ...base, status: "cancelled", dueAtMs: 60 },
      ],
      [{ amountCents: 4000, paidCents: 4000, dueAtMs: 40, paidAtMs: 41, status: "paid" }],
      70
    );
    expect(s.receivedCents).toBe(15000);
    expect(s.byMethod).toEqual({ pix: 10000, card: 5000 });
    expect(s.refundedCents).toBe(2000);
    expect(s.forecastCents).toBe(60000);
    expect(s.pendingCents).toBe(30000);
    expect(s.overdueCents).toBe(30000);
    expect(s.expensesPaidCents).toBe(4000);
    expect(s.netCashCents).toBe(9000);
  });
});
