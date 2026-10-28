import { CampaignError, eligibility, matchesSegment, validateCampaign } from "./marketingCore";

const contact = { ownerUid: "u", stage: "atendido", lastVisitMs: Date.UTC(2026, 0, 1), unitId: null, preferredChannel: "inApp", marketingConsent: true, suppressed: false, lastMarketingMs: null };

describe("campanha", () => {
  it("recusa segmentação clínica e alegações não comprovadas", () => {
    expect(() => validateCampaign({ title: "Vacinas", body: "Campanha", segment: { diagnosis: "asma" } })).toThrow("não permitido: diagnosis");
    expect(() => validateCampaign({ title: "Resultado garantido", body: "x" })).toThrow(CampaignError);
    expect(() => validateCampaign({ title: "Veja o depoimento", body: "x" })).toThrow(CampaignError);
  });
  it("aceita campanha educativa com critérios administrativos", () => {
    const c = validateCampaign({ title: "Semana da vacinação", body: "Confira o calendário no app.", segment: { stage: ["atendido", "xx"] } });
    expect(c.segment.stage).toEqual(["atendido"]);
    expect(c.kind).toBe("educational");
  });
});

describe("elegibilidade", () => {
  it("consentimento, supressão e frequência", () => {
    const now = Date.UTC(2026, 5, 1);
    expect(eligibility(contact, 7, now)).toEqual({ ok: true });
    expect(eligibility({ ...contact, marketingConsent: false }, 7, now)).toEqual({ ok: false, reason: "sem consentimento de marketing" });
    expect(eligibility({ ...contact, suppressed: true }, 7, now)).toEqual({ ok: false, reason: "lista de supressão" });
    expect(eligibility({ ...contact, lastMarketingMs: now - 86_400_000 }, 7, now)).toEqual({ ok: false, reason: "limite de frequência" });
  });
  it("segmento por estágio e última visita", () => {
    expect(matchesSegment(contact, { stage: ["atendido"], lastVisitBefore: "2026-03-01" })).toBe(true);
    expect(matchesSegment(contact, { lastVisitAfter: "2026-03-01" })).toBe(false);
  });
});
