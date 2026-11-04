import {
  allLockIds,
  canTransition,
  computeSlots,
  expandRecurrence,
  familyMayCancel,
  familyMayReschedule,
  localParts,
  lockIds,
  normalizePolicy,
  parseWeeklyHours,
  pickWaitlistEntry,
  reminderPlan,
  resolveDuration,
  slotProblem,
  DEFAULT_POLICY,
} from "./schedulingCore";

// Segunda-feira, 2 de novembro de 2026, 00:00 em Brasília (03:00 UTC).
const MON = Date.UTC(2026, 10, 2, 3, 0);
const H = 3_600_000;
const M = 60_000;

describe("status", () => {
  it("família confirma o que aguarda confirmação, mas não inicia atendimento", () => {
    expect(canTransition("awaitingConfirmation", "confirmed", "family")).toBe(true);
    expect(canTransition("confirmed", "inProgress", "family")).toBe(false);
    expect(canTransition("confirmed", "inProgress", "reception")).toBe(false);
    expect(canTransition("confirmed", "inProgress", "professional")).toBe(true);
  });
  it("estados finais não mudam", () => {
    for (const to of ["confirmed", "requested", "inProgress"]) {
      expect(canTransition("cancelled", to, "manager")).toBe(false);
      expect(canTransition("completed", to, "professional")).toBe(false);
    }
  });
  it("status desconhecido é recusado", () => {
    expect(canTransition("x", "confirmed", "manager")).toBe(false);
  });
});

describe("regras da clínica", () => {
  it("valores inválidos voltam ao padrão e lembretes ficam no máximo 3", () => {
    const p = normalizePolicy({ minLeadMinutes: -5, slotStepMinutes: 7, reminderOffsetsHours: [1, 24, 24, 2, 168, 999] });
    expect(p.minLeadMinutes).toBe(DEFAULT_POLICY.minLeadMinutes);
    expect(p.slotStepMinutes).toBe(DEFAULT_POLICY.slotStepMinutes);
    expect(p.reminderOffsetsHours).toEqual([168, 24, 2]);
  });
  it("janela de cancelamento/remarcação da família", () => {
    const p = normalizePolicy({ familyCancelUntilHours: 24, maxFamilyReschedules: 1 });
    expect(familyMayCancel(MON + 48 * H, MON, p)).toBe(true);
    expect(familyMayCancel(MON + 10 * H, MON, p)).toBe(false);
    expect(familyMayReschedule(MON + 48 * H, MON, 1, p)).toBe(false);
  });
});

describe("duração", () => {
  it("serviço > configuração da clínica > padrão do tipo", () => {
    expect(resolveDuration("retorno", { durationMinutes: 40 }, { retorno: 25 })).toBe(40);
    expect(resolveDuration("retorno", null, { retorno: 25 })).toBe(25);
    expect(resolveDuration("primeiraConsulta", null, null)).toBe(45);
    expect(resolveDuration("retorno", { durationMinutes: 7 }, null)).toBe(20);
  });
});

describe("horários livres", () => {
  const hours = parseWeeklyHours({ 1: ["08:00-12:00", "13:00-15:00"], 9: ["x"], 2: ["10:00-09:00"] });
  it("lê a grade semanal e descarta entradas inválidas", () => {
    expect(hours[1]).toHaveLength(2);
    expect(hours[2]).toBeUndefined();
    expect(localParts(MON).weekday).toBe(1);
  });
  it("respeita bloqueios, pausas, consultas e antecedência", () => {
    const slots = computeSlots({
      hours,
      breaks: { 1: [{ start: 10 * 60, end: 10 * 60 + 30 }] },
      unavailable: [{ start: MON + 9 * H, end: MON + 9 * H + 45 * M }],
      durationMinutes: 30,
      stepMinutes: 30,
      fromMs: MON,
      days: 1,
      nowMs: MON - 48 * H,
      minLeadMinutes: 60,
      maxDaysAhead: 30,
    });
    const labels = slots.map((s) => localParts(s).minuteOfDay / 60);
    expect(labels).toEqual([8, 8.5, 10.5, 11, 11.5, 13, 13.5, 14, 14.5]);
  });
  it("sobreposição parcial com duração diferente também bloqueia", () => {
    const problem = slotProblem(MON + 9 * H + 30 * M, 30, {
      hours,
      unavailable: [{ start: MON + 9 * H, end: MON + 9 * H + 45 * M }],
      nowMs: MON - 48 * H,
      minLeadMinutes: 0,
      maxDaysAhead: 30,
    }, { enforceLead: true });
    expect(problem).toBe("Horário indisponível.");
  });
  it("recusa fora da grade, no passado e sem antecedência", () => {
    const base = { hours, unavailable: [], nowMs: MON + 8 * H, minLeadMinutes: 120, maxDaysAhead: 30 };
    expect(slotProblem(MON + 7 * H, 30, base, { enforceLead: false })).toBe("Este horário já passou.");
    expect(slotProblem(MON + 9 * H, 30, base, { enforceLead: true })).toBe("Fora da antecedência mínima da clínica.");
    expect(slotProblem(MON + 9 * H, 30, base, { enforceLead: false })).toBeNull();
    expect(slotProblem(MON + 11 * H + 45 * M, 30, base, { enforceLead: false })).toBe("Fora do horário de atendimento.");
  });
});

describe("travas de concorrência", () => {
  it("consultas sobrepostas compartilham pelo menos uma trava", () => {
    const a = lockIds("prof", "p1", MON + 9 * H, 45);
    const b = lockIds("prof", "p1", MON + 9 * H + 30 * M, 30);
    expect(a.some((id) => b.includes(id))).toBe(true);
    const c = lockIds("prof", "p1", MON + 9 * H + 45 * M, 30);
    expect(a.some((id) => c.includes(id))).toBe(false);
  });
  it("sala e equipamento entram nas travas, separados por clínica", () => {
    const ids = allLockIds({ clinicScope: "c1", professionalId: "p1", roomId: "s1", equipmentIds: ["e1"], startMs: MON, durationMinutes: 10 });
    expect(ids).toEqual(expect.arrayContaining(["room_c1~s1_" + MON / (5 * M), "equip_c1~e1_" + MON / (5 * M)]));
    expect(() => lockIds("prof", "a/b", MON, 10)).toThrow();
  });
});

describe("recorrência", () => {
  it("semanal, quinzenal e mensal (fim de mês ajustado)", () => {
    expect(expandRecurrence(MON, "weekly", 3)).toEqual([MON, MON + 7 * 24 * H, MON + 14 * 24 * H]);
    expect(expandRecurrence(MON, "biweekly", 2)[1]).toBe(MON + 14 * 24 * H);
    const jan31 = Date.UTC(2027, 0, 31, 13, 0); // 10:00 local
    const feb = expandRecurrence(jan31, "monthly", 2)[1];
    expect(new Date(feb).toISOString()).toBe("2027-02-28T13:00:00.000Z");
    expect(expandRecurrence(MON, "weekly", 100)).toHaveLength(26);
  });
});

describe("lista de espera", () => {
  it("prioridade e depois ordem de chegada, respeitando período", () => {
    const entries = [
      { id: "a", professionalId: "p1", status: "waiting", createdAtMs: 1, dayPart: "tarde" as const },
      { id: "b", professionalId: "p1", status: "waiting", createdAtMs: 2 },
      { id: "c", professionalId: "p1", status: "waiting", createdAtMs: 3, priority: 1 },
      { id: "d", professionalId: "p1", status: "offered", createdAtMs: 0, priority: 9 },
    ];
    expect(pickWaitlistEntry(entries, { professionalId: "p1", startMs: MON + 9 * H })?.id).toBe("c");
    expect(pickWaitlistEntry(entries.slice(0, 2), { professionalId: "p1", startMs: MON + 9 * H })?.id).toBe("b");
    expect(pickWaitlistEntry(entries, { professionalId: "p2", startMs: MON })).toBeNull();
  });
});

describe("lembretes", () => {
  it("chave muda com a versão da agenda e só agenda o futuro", () => {
    const v1 = reminderPlan("ap", MON + 30 * H, 1, [24, 2], MON + 10 * H);
    expect(v1.map((r) => r.key)).toEqual(["rem_ap_v1_2h"]);
    const v2 = reminderPlan("ap", MON + 60 * H, 2, [24, 2], MON + 10 * H);
    expect(v2.map((r) => r.key)).toEqual(["rem_ap_v2_24h", "rem_ap_v2_2h"]);
  });
});
