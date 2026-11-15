/**
 * CRM administrativo (puro): estágio, classificação e duplicidade.
 * Nada aqui usa conteúdo clínico — só datas e status de consultas.
 */

export const CRM_STAGES = ["novoContato", "agendamentoSolicitado", "agendado", "atendido", "acompanhamento"] as const;
export type CrmStage = (typeof CRM_STAGES)[number];

export interface CrmCriteria {
  frequentMinVisits: number;
  frequentWindowDays: number;
  inactiveAfterDays: number;
  noShowMin: number;
}

export const DEFAULT_CRM_CRITERIA: CrmCriteria = {
  frequentMinVisits: 4,
  frequentWindowDays: 365,
  inactiveAfterDays: 180,
  noShowMin: 2,
};

export function normalizeCriteria(raw: unknown): CrmCriteria {
  const r = (raw ?? {}) as Record<string, unknown>;
  const n = (k: keyof CrmCriteria, min: number, max: number) => {
    const v = Number(r[k]);
    return Number.isInteger(v) && v >= min && v <= max ? v : DEFAULT_CRM_CRITERIA[k];
  };
  return {
    frequentMinVisits: n("frequentMinVisits", 2, 50),
    frequentWindowDays: n("frequentWindowDays", 30, 730),
    inactiveAfterDays: n("inactiveAfterDays", 30, 1095),
    noShowMin: n("noShowMin", 1, 20),
  };
}

export interface ApptLite {
  status: string;
  startMs: number;
  expectedReturnMs?: number | null;
}

export interface CrmDerived {
  stage: CrmStage;
  firstVisitMs: number | null;
  lastVisitMs: number | null;
  nextAppointmentMs: number | null;
  expectedReturnMs: number | null;
  visitCount: number;
  noShowCount: number;
  cancelCount: number;
  flags: { frequent: boolean; inactive: boolean; noShow: boolean; returnPending: boolean };
}

const DAY = 86_400_000;

export function deriveCrm(appts: ApptLite[], nowMs: number, c: CrmCriteria): CrmDerived {
  const done = appts.filter((a) => a.status === "completed").sort((a, b) => a.startMs - b.startMs);
  const future = appts.filter((a) => a.startMs > nowMs && ["requested", "awaitingConfirmation", "confirmed"].includes(a.status))
    .sort((a, b) => a.startMs - b.startMs);
  const requested = future.some((a) => a.status === "requested");
  const scheduled = future.some((a) => a.status !== "requested");
  const last = done[done.length - 1] ?? null;
  const expectedReturnMs = last?.expectedReturnMs ?? null;
  const returnPending = expectedReturnMs != null && expectedReturnMs <= nowMs + 30 * DAY && !future.length;
  const recent = done.filter((a) => a.startMs >= nowMs - c.frequentWindowDays * DAY).length;
  const noShowCount = appts.filter((a) => a.status === "noShow").length;
  let stage: CrmStage = "novoContato";
  if (scheduled) stage = "agendado";
  else if (requested) stage = "agendamentoSolicitado";
  else if (done.length > 1 || (done.length === 1 && expectedReturnMs != null)) stage = "acompanhamento";
  else if (done.length === 1) stage = "atendido";
  return {
    stage,
    firstVisitMs: done[0]?.startMs ?? null,
    lastVisitMs: last?.startMs ?? null,
    nextAppointmentMs: future[0]?.startMs ?? null,
    expectedReturnMs,
    visitCount: done.length,
    noShowCount,
    cancelCount: appts.filter((a) => a.status === "cancelled").length,
    flags: {
      frequent: recent >= c.frequentMinVisits,
      inactive: last != null && last.startMs < nowMs - c.inactiveAfterDays * DAY && !future.length,
      noShow: noShowCount >= c.noShowMin,
      returnPending,
    },
  };
}

/** Nome comparável: sem acento, minúsculo, espaços simples. */
export function normalizeName(s: string): string {
  return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z ]/g, " ").replace(/\s+/g, " ").trim();
}

export interface DupCandidate {
  key: string;
  childName: string;
  birthDate: string | null;
  guardianPhone: string | null;
  ownerUid: string;
}

/**
 * Possíveis duplicidades: mesmo nome normalizado e mesma data de
 * nascimento, ou mesmo telefone do responsável com nome parecido. Só
 * sugere: a fusão exige revisão humana.
 */
export function findDuplicates(list: DupCandidate[]): Array<{ a: string; b: string; reason: string }> {
  const out: Array<{ a: string; b: string; reason: string }> = [];
  for (let i = 0; i < list.length; i++) {
    for (let j = i + 1; j < list.length; j++) {
      const x = list[i];
      const y = list[j];
      const nx = normalizeName(x.childName);
      const ny = normalizeName(y.childName);
      if (!nx || !ny) continue;
      if (nx === ny && x.birthDate && x.birthDate === y.birthDate) {
        out.push({ a: x.key, b: y.key, reason: "mesmo nome e data de nascimento" });
      } else if (x.guardianPhone && x.guardianPhone === y.guardianPhone && nx.split(" ")[0] === ny.split(" ")[0]) {
        out.push({ a: x.key, b: y.key, reason: "mesmo telefone do responsável e primeiro nome" });
      }
    }
  }
  return out;
}
