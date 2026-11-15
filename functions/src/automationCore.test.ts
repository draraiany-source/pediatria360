import {
  dispatchDecision,
  DispatchContext,
  nextAllowedTime,
  MESSAGE_KINDS,
  normalizeRule,
  notificationRoute,
  QueueJob,
  renderTemplate,
  retryDelayMs,
  whatsappBlocker,
  DEFAULT_RULES,
} from "./automationCore";

// 10:00 em Brasília (13:00 UTC), segunda 2/11/2026.
const TEN = Date.UTC(2026, 10, 2, 13, 0);
const H = 3_600_000;

function job(over: Partial<QueueJob> = {}): QueueJob {
  return {
    kind: "appointmentReminder", channel: "inApp", recipientUid: "ana", clinicId: "c1",
    appointmentId: "ap1", scheduleVersion: 2, attempts: 0, sendAtMs: TEN, ...over,
  };
}

function ctx(over: Partial<DispatchContext> = {}): DispatchContext {
  return {
    nowMs: TEN,
    rule: DEFAULT_RULES.appointmentReminder,
    clinicAutomationsPaused: false,
    appointment: { status: "confirmed", patientId: "ana", scheduleVersion: 2, startMs: TEN + 24 * H },
    recipient: { exists: true, optOut: {}, kindEnabled: true, marketingConsent: false, suppressed: false },
    sentToRecipientLast24h: 0,
    channelBlocker: null,
    ...over,
  };
}

describe("revalidação antes do envio", () => {
  it("envia quando tudo confere", () => {
    expect(dispatchDecision(job(), ctx())).toEqual({ action: "send" });
  });
  it("lembrete de versão antiga (remarcada) é cancelado", () => {
    expect(dispatchDecision(job({ scheduleVersion: 1 }), ctx())).toEqual({ action: "cancel", reason: "consulta remarcada" });
  });
  it("consulta cancelada, destinatário trocado ou recusa de canal cancelam", () => {
    expect(dispatchDecision(job(), ctx({ appointment: { status: "cancelled", patientId: "ana", scheduleVersion: 2, startMs: TEN + H } })).action).toBe("cancel");
    expect(dispatchDecision(job(), ctx({ appointment: { status: "confirmed", patientId: "bruno", scheduleVersion: 2, startMs: TEN + H } })).action).toBe("cancel");
    expect(dispatchDecision(job(), ctx({ recipient: { exists: true, optOut: { inApp: true }, kindEnabled: true, marketingConsent: false, suppressed: false } })).action).toBe("cancel");
  });
  it("pausa adia; fora do horário adia para a janela permitida", () => {
    expect(dispatchDecision(job(), ctx({ clinicAutomationsPaused: true })).action).toBe("defer");
    const night = Date.UTC(2026, 10, 3, 1, 0); // 22:00 local
    const d = dispatchDecision(job({ sendAtMs: night }), ctx({ nowMs: night, appointment: { status: "confirmed", patientId: "ana", scheduleVersion: 2, startMs: night + 48 * H } }));
    expect(d).toEqual({ action: "defer", untilMs: Date.UTC(2026, 10, 3, 11, 0), reason: "fora do horário permitido" });
  });
  it("lembrete que só sairia depois da consulta é cancelado", () => {
    const night = Date.UTC(2026, 10, 3, 1, 0);
    expect(dispatchDecision(job(), ctx({ nowMs: night, appointment: { status: "confirmed", patientId: "ana", scheduleVersion: 2, startMs: night + 2 * H } })).action).toBe("cancel");
  });
  it("limite diário adia", () => {
    expect(dispatchDecision(job(), ctx({ sentToRecipientLast24h: 4 })).action).toBe("defer");
  });
  it("WhatsApp sem configuração bloqueia com o motivo exato (não finge envio)", () => {
    const rule = normalizeRule("appointmentReminder", { channels: ["inApp", "whatsapp"] });
    const reason = whatsappBlocker("appointmentReminder", {
      hasToken: false, hasPhoneNumberId: false, hasAppSecret: false, clinicEnabled: false,
      approvedTemplates: {}, recipientPhone: null, recipientWhatsAppOptIn: false,
    });
    expect(reason).toBe("WHATSAPP_TOKEN não configurado no servidor");
    expect(dispatchDecision(job({ channel: "whatsapp" }), ctx({ rule, channelBlocker: reason }))).toEqual({ action: "block", reason });
  });
  it("campanha exige consentimento, ausência de supressão e aprovação", () => {
    const rule = normalizeRule("campaign", { enabled: true });
    const base = ctx({ rule, appointment: null });
    const camp = job({ kind: "campaign", appointmentId: null, scheduleVersion: null, campaignId: "k1" });
    expect(dispatchDecision(camp, base)).toEqual({ action: "cancel", reason: "sem consentimento de marketing" });
    const consent = { exists: true, optOut: {}, kindEnabled: true, marketingConsent: true, suppressed: true };
    expect(dispatchDecision(camp, { ...base, recipient: consent })).toEqual({ action: "cancel", reason: "na lista de supressão" });
    expect(dispatchDecision(camp, { ...base, recipient: { ...consent, suppressed: false } })).toEqual({ action: "cancel", reason: "campanha não aprovada" });
    expect(dispatchDecision(camp, { ...base, recipient: { ...consent, suppressed: false }, campaignApproved: true })).toEqual({ action: "send" });
  });
});

describe("regras e modelos", () => {
  it("só lembrete, mudança e lista de espera vêm ligados", () => {
    expect(DEFAULT_RULES.appointmentReminder.enabled).toBe(true);
    expect(DEFAULT_RULES.paymentReminder.enabled).toBe(false);
    expect(DEFAULT_RULES.campaign.enabled).toBe(false);
  });
  it("janela inválida volta ao padrão; canais desconhecidos são ignorados", () => {
    const r = normalizeRule("appointmentReminder", { allowedFromHour: 20, allowedToHour: 8, channels: ["sms", "whatsapp"] });
    expect([r.allowedFromHour, r.allowedToHour]).toEqual([8, 20]);
    expect(r.channels).toEqual(["whatsapp"]);
  });
  it("modelo só preenche variáveis permitidas", () => {
    expect(renderTemplate("{{crianca}} {{diagnostico}}", { crianca: "Bia", diagnostico: "x" })).toBe("Bia ");
  });
  it("janela permitida e espera entre tentativas", () => {
    expect(nextAllowedTime(TEN, { allowedFromHour: 8, allowedToHour: 20 })).toBe(TEN);
    expect(retryDelayMs(1)).toBe(5 * 60_000);
    expect(retryDelayMs(10)).toBe(6 * H);
  });
});

describe("notificationRoute", () => {
  const routes = ["/telemedicina", "/avisos"];

  it("leva a pré-consulta para a consulta certa", () => {
    expect(notificationRoute("preVisitForm", "appt-1")).toBe("/pre-consulta/appt-1");
    expect(notificationRoute("preVisitForm", null)).toBe("/telemedicina");
  });

  it("nunca aponta para área restrita da equipe", () => {
    for (const kind of MESSAGE_KINDS) {
      const r = notificationRoute(kind, null);
      expect(routes).toContain(r);
    }
    expect(notificationRoute("paymentReminder")).toBe("/avisos");
  });
});