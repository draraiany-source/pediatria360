import {
  ATTEMPT_WINDOW_MS,
  INVITE_DAYS,
  IntakeValidationError,
  MAX_FAILED_ATTEMPTS,
  attemptsBlocked,
  canRegisterIntake,
  formatInviteCode,
  generateInviteCode,
  hashInviteCode,
  intakeDedupeKey,
  inviteExpiresAtMs,
  normalizeEmail,
  normalizeInviteCode,
  parseGrantDays,
  parseGuardianScopes,
  parseIntakeInput,
  registerFailedAttempt,
} from "./intake";

const DIA = 24 * 60 * 60 * 1000;
const AGORA = Date.UTC(2026, 9, 25, 12, 0, 0);

function pedido(extra: Record<string, unknown> = {}) {
  return {
    clinicId: "clinica-a",
    professionalId: "uid_dra",
    childName: "Bia Teste",
    childBirthDate: "2024-03-10",
    guardianName: "Ana Teste",
    guardianEmail: " Ana@Exemplo.Invalid ",
    guardianPhone: "",
    startsAt: new Date(AGORA + 3 * DIA).toISOString(),
    durationMinutes: 30,
    reason: "Primeira consulta",
    ...extra,
  };
}

describe("código do convite", () => {
  it("gera 10 caracteres sem ambíguos e normaliza o que o responsável digita", () => {
    const code = generateInviteCode();
    expect(code).toMatch(/^[A-HJKMNP-Z2-9]{10}$/);
    expect(normalizeInviteCode(formatInviteCode(code).toLowerCase())).toBe(code);
    expect(normalizeInviteCode(` ${code.slice(0, 5)} ${code.slice(5)} `)).toBe(code);
  });

  it("rejeita tamanho errado e caracteres fora do alfabeto", () => {
    expect(normalizeInviteCode("ABC")).toBeNull();
    expect(normalizeInviteCode("ABCDE-FGHI0")).toBeNull();
    expect(normalizeInviteCode(123)).toBeNull();
  });

  it("guarda só o hash, estável e diferente do código", () => {
    expect(hashInviteCode("ABCDEFGHJK")).toBe(hashInviteCode("ABCDEFGHJK"));
    expect(hashInviteCode("ABCDEFGHJK")).not.toContain("ABCDEFGHJK");
    expect(hashInviteCode("ABCDEFGHJK")).not.toBe(hashInviteCode("ABCDEFGHJM"));
  });

  it("vence em INVITE_DAYS ou no horário da consulta, o que vier antes", () => {
    expect(inviteExpiresAtMs(AGORA, AGORA + 30 * DIA)).toBe(AGORA + INVITE_DAYS * DIA);
    expect(inviteExpiresAtMs(AGORA, AGORA + DIA)).toBe(AGORA + DIA);
  });
});

describe("parseIntakeInput", () => {
  it("limpa e normaliza o e-mail", () => {
    const p = parseIntakeInput(pedido(), AGORA);
    expect(p.guardianEmail).toBe("ana@exemplo.invalid");
    expect(p.guardianPhone).toBeNull();
    expect(p.clinicId).toBe("clinica-a");
  });

  it("recusa horário passado, nascimento futuro, e-mail inválido e duração fora da faixa", () => {
    const bad = [
      pedido({ startsAt: new Date(AGORA - 1).toISOString() }),
      pedido({ childBirthDate: "2030-01-01" }),
      pedido({ childBirthDate: "10/03/2024" }),
      pedido({ guardianEmail: "sem-arroba" }),
      pedido({ durationMinutes: 5 }),
      pedido({ childName: "" }),
      pedido({ professionalId: "" }),
    ];
    for (const b of bad) {
      expect(() => parseIntakeInput(b, AGORA)).toThrow(IntakeValidationError);
    }
  });
});

describe("intakeDedupeKey", () => {
  const base = {
    clinicId: "clinica-a",
    professionalId: "uid_dra",
    childName: "Bia Teste",
    childBirthDate: "2024-03-10",
    guardianEmail: "ana@exemplo.invalid",
  };

  it("ignora acento, caixa e espaços no nome", () => {
    expect(intakeDedupeKey({ ...base, childName: "  BIA   teste " })).toBe(intakeDedupeKey(base));
    expect(intakeDedupeKey({ ...base, childName: "Biá Teste" })).toBe(intakeDedupeKey(base));
  });

  it("muda com outra clínica, profissional, nascimento ou responsável", () => {
    const k = intakeDedupeKey(base);
    expect(intakeDedupeKey({ ...base, clinicId: "clinica-b" })).not.toBe(k);
    expect(intakeDedupeKey({ ...base, professionalId: "uid_outro" })).not.toBe(k);
    expect(intakeDedupeKey({ ...base, childBirthDate: "2024-03-11" })).not.toBe(k);
    expect(intakeDedupeKey({ ...base, guardianEmail: "outra@exemplo.invalid" })).not.toBe(k);
  });
});

describe("escolha do responsável ao aceitar", () => {
  it("nenhum acesso, só resumo, ou resumo e prontuário", () => {
    expect(parseGuardianScopes(undefined)).toEqual([]);
    expect(parseGuardianScopes([])).toEqual([]);
    expect(parseGuardianScopes(["summary"])).toEqual(["summary"]);
    expect(parseGuardianScopes(["chartWrite", "summary"])).toEqual(["summary", "chartWrite"]);
  });

  it("prontuário sem resumo e escopo desconhecido são recusados", () => {
    expect(() => parseGuardianScopes(["chartWrite"])).toThrow(IntakeValidationError);
    expect(() => parseGuardianScopes(["admin"])).toThrow(IntakeValidationError);
    expect(() => parseGuardianScopes("summary")).toThrow(IntakeValidationError);
  });

  it("validade entre 1 e 365 dias", () => {
    expect(parseGrantDays(90)).toBe(90);
    for (const d of [0, 366, 1.5, "x", null]) {
      expect(() => parseGrantDays(d)).toThrow(IntakeValidationError);
    }
  });
});

describe("tentativas erradas de código", () => {
  it("bloqueia depois do limite dentro da janela e libera depois dela", () => {
    let s: { count: number; windowStartMs: number } | undefined;
    for (let i = 0; i < MAX_FAILED_ATTEMPTS; i++) s = registerFailedAttempt(s, AGORA + i);
    expect(attemptsBlocked(s, AGORA + MAX_FAILED_ATTEMPTS)).toBe(true);
    expect(attemptsBlocked(s, AGORA + ATTEMPT_WINDOW_MS + 1)).toBe(false);
    expect(registerFailedAttempt(s, AGORA + ATTEMPT_WINDOW_MS + 1).count).toBe(1);
  });
});

describe("canRegisterIntake", () => {
  it("recepção e gestão para qualquer profissional; profissional só para si", () => {
    expect(canRegisterIntake("receptionist", "u1", "uid_dra")).toBe(true);
    expect(canRegisterIntake("clinicAdmin", "u1", "uid_dra")).toBe(true);
    expect(canRegisterIntake("physician", "uid_dra", "uid_dra")).toBe(true);
    expect(canRegisterIntake("physician", "uid_outro", "uid_dra")).toBe(false);
  });

  it("financeiro, paciente e quem não é da clínica não registram", () => {
    expect(canRegisterIntake("finance", "u1", "uid_dra")).toBe(false);
    expect(canRegisterIntake("patient", "u1", "uid_dra")).toBe(false);
    expect(canRegisterIntake(null, "uid_dra", "uid_dra")).toBe(false);
  });
});

describe("normalizeEmail", () => {
  it("minúsculas e sem espaços; rejeita inválido", () => {
    expect(normalizeEmail(" X@Y.Invalid ")).toBe("x@y.invalid");
    expect(normalizeEmail("x@y")).toBeNull();
    expect(normalizeEmail(undefined)).toBeNull();
  });
});
