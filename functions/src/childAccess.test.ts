import { grantAllows, grantState, GRANT_SOURCES } from "./childAccess";

const DIA = 24 * 60 * 60 * 1000;
const AGORA = Date.UTC(2026, 9, 25, 12, 0, 0);

const ts = (ms: number) => ({ toMillis: () => ms });

function concessao(extra: Record<string, unknown> = {}) {
  return {
    scopes: ["summary", "chartWrite"],
    source: "guardian",
    authorizedBy: "uid_ana",
    expiresAt: ts(AGORA + 30 * DIA),
    revokedAt: null,
    clinicId: null,
    ...extra,
  };
}

describe("grantAllows", () => {
  it("concessão válida libera o escopo concedido", () => {
    expect(grantAllows(concessao(), "summary", AGORA)).toBe(true);
    expect(grantAllows(concessao(), "chartWrite", AGORA)).toBe(true);
  });

  it("summary não implica chartWrite", () => {
    expect(grantAllows(concessao({ scopes: ["summary"] }), "chartWrite", AGORA)).toBe(false);
  });

  it("concessão antiga, sem escopo nem validade, não vale", () => {
    expect(grantAllows({ grantedAt: ts(AGORA - DIA) }, "summary", AGORA)).toBe(false);
    expect(grantAllows(undefined, "summary", AGORA)).toBe(false);
  });

  it("vencida ou revogada não vale", () => {
    expect(grantAllows(concessao({ expiresAt: ts(AGORA - 1) }), "summary", AGORA)).toBe(false);
    expect(grantAllows(concessao({ revokedAt: ts(AGORA - DIA) }), "summary", AGORA)).toBe(false);
  });

  it("origem desconhecida não vale", () => {
    expect(grantAllows(concessao({ source: "clinic" }), "summary", AGORA)).toBe(false);
  });

  it("concessão automática por consulta (familyAppointment) não vale mais", () => {
    expect(GRANT_SOURCES).not.toContain("familyAppointment");
    expect(grantAllows(concessao({ source: "familyAppointment" }), "summary", AGORA)).toBe(false);
    expect(grantAllows(concessao({ source: "familyAppointment" }), "chartWrite", AGORA)).toBe(false);
  });

  it("aceite do convite pelo responsável (guardianInvite) vale como a da tela", () => {
    expect(grantAllows(concessao({ source: "guardianInvite" }), "chartWrite", AGORA)).toBe(true);
  });

  it("restrita a uma clínica só vale nela", () => {
    const restrita = concessao({ clinicId: "clinica-a" });
    expect(grantAllows(restrita, "chartWrite", AGORA, "clinica-a")).toBe(true);
    expect(grantAllows(restrita, "chartWrite", AGORA, "clinica-b")).toBe(false);
    expect(grantAllows(restrita, "chartWrite", AGORA, null)).toBe(false);
  });
});

describe("grantState", () => {
  it("classifica ativa, vencida, revogada, inválida e ausente", () => {
    expect(grantState(concessao(), AGORA)).toBe("active");
    expect(grantState(concessao({ expiresAt: ts(AGORA - 1) }), AGORA)).toBe("expired");
    expect(grantState(concessao({ revokedAt: ts(AGORA - DIA) }), AGORA)).toBe("revoked");
    expect(grantState({ grantedAt: ts(AGORA - DIA) }, AGORA)).toBe("invalid");
    expect(grantState(concessao({ source: "familyAppointment" }), AGORA)).toBe("invalid");
    expect(grantState(undefined, AGORA)).toBe("none");
  });

  it("revogada continua revogada mesmo depois de vencer", () => {
    const g = concessao({ revokedAt: ts(AGORA - 2 * DIA), expiresAt: ts(AGORA - DIA) });
    expect(grantState(g, AGORA)).toBe("revoked");
  });
});
