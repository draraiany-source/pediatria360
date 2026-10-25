import {
  familyAppointmentGrant,
  FAMILY_GRANT_DAYS,
  grantAllows,
  isFamilyRequestFor,
  revocationBlocksRequest,
} from "./childAccess";

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

  it("restrita a uma clínica só vale nela", () => {
    const restrita = concessao({ clinicId: "clinica-a" });
    expect(grantAllows(restrita, "chartWrite", AGORA, "clinica-a")).toBe(true);
    expect(grantAllows(restrita, "chartWrite", AGORA, "clinica-b")).toBe(false);
    expect(grantAllows(restrita, "chartWrite", AGORA, null)).toBe(false);
  });
});

describe("isFamilyRequestFor", () => {
  const pedido = {
    patientId: "uid_ana",
    requestedBy: "uid_ana",
    childId: "filha",
    professionalId: "uid_dra",
    status: "requested",
  };
  const alvo = { ownerUid: "uid_ana", childId: "filha", professionalUid: "uid_dra" };

  it("pedido da família para este profissional e esta criança", () => {
    expect(isFamilyRequestFor(pedido, alvo)).toBe(true);
  });

  it("consulta marcada pela equipe (sem requestedBy) não cria vínculo", () => {
    const semPedido: Record<string, unknown> = { ...pedido };
    delete semPedido.requestedBy;
    expect(isFamilyRequestFor(semPedido, alvo)).toBe(false);
  });

  it("consulta de outra família, outra criança ou outro profissional não serve", () => {
    expect(isFamilyRequestFor({ ...pedido, patientId: "uid_invasor", requestedBy: "uid_invasor" }, alvo)).toBe(false);
    expect(isFamilyRequestFor({ ...pedido, childId: "outra" }, alvo)).toBe(false);
    expect(isFamilyRequestFor({ ...pedido, professionalId: "uid_invasor" }, alvo)).toBe(false);
  });

  it("consulta cancelada ou concluída não serve", () => {
    expect(isFamilyRequestFor({ ...pedido, status: "cancelled" }, alvo)).toBe(false);
    expect(isFamilyRequestFor({ ...pedido, status: "completed" }, alvo)).toBe(false);
  });
});

describe("revocationBlocksRequest", () => {
  it("sem revogação, não bloqueia", () => {
    expect(revocationBlocksRequest(concessao(), AGORA)).toBe(false);
    expect(revocationBlocksRequest(undefined, AGORA)).toBe(false);
  });

  it("revogada: só pedido feito depois da revogação reabre", () => {
    const revogada = concessao({ revokedAt: ts(AGORA - DIA) });
    expect(revocationBlocksRequest(revogada, AGORA - 2 * DIA)).toBe(true);
    expect(revocationBlocksRequest(revogada, AGORA)).toBe(false);
    expect(revocationBlocksRequest(revogada, null)).toBe(true);
  });
});

describe("familyAppointmentGrant", () => {
  it("escopo de atendimento, validade limitada e sem restrição de clínica", () => {
    const g = familyAppointmentGrant({ ownerUid: "uid_ana", appointmentId: "c1", nowMs: AGORA });
    expect(g.scopes).toEqual(["summary", "chartWrite"]);
    expect(g.source).toBe("familyAppointment");
    expect(g.authorizedBy).toBe("uid_ana");
    expect(g.expiresAtMs).toBe(AGORA + FAMILY_GRANT_DAYS * DIA);
    expect(g.revokedAt).toBeNull();
  });
});
