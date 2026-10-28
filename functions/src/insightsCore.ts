/**
 * Central de IA da gestão (puro): intenção da pergunta, período e resposta.
 *
 * A pergunta nunca vira consulta livre ao banco: só intenções desta lista,
 * cada uma ligada a uma operação específica e com permissão própria.
 */

import { localParts, DEFAULT_TZ_OFFSET_MIN } from "./schedulingCore";

export const INTENTS = [
  "noShowCount",
  "cancellationCount",
  "appointmentSummary",
  "pendingReturns",
  "availableSlots",
  "frequentPatients",
  "inactivePatients",
  "receivedAmount",
  "pendingAmount",
  "revenueVsExpenses",
] as const;
export type Intent = (typeof INTENTS)[number];

export const FINANCIAL_INTENTS: ReadonlySet<Intent> = new Set(["receivedAmount", "pendingAmount", "revenueVsExpenses"]);

const PATTERNS: Array<[Intent, RegExp]> = [
  ["noShowCount", /\b(falt(a|aram|ou|as)|no.?show|nao compareceu|não compareceu)\b/],
  ["cancellationCount", /\bcancel/],
  ["pendingReturns", /\bretorn/],
  ["availableSlots", /\b(horario|horário|vaga|agenda livre|disponi)/],
  ["frequentPatients", /\bfrequent/],
  ["inactivePatients", /\binativ/],
  ["receivedAmount", /\b(recebe|recebemos|recebido|entrou|faturamos|receita)\b/],
  ["pendingAmount", /\b(pendente|a receber|em aberto|inadimpl)/],
  ["revenueVsExpenses", /\b(despesa|gasto|lucro|saldo|resultado)/],
  ["appointmentSummary", /\b(consulta|atendimento|agendamento)s?\b/],
];

/** Intenção suportada, ou null (a resposta lista o que é suportado). */
export function classifyIntent(question: string): Intent | null {
  const q = question.toLowerCase().normalize("NFC");
  for (const [intent, re] of PATTERNS) if (re.test(q)) return intent;
  return null;
}

export interface Period {
  fromMs: number;
  toMs: number;
  label: string;
}

/** "hoje", "esta semana", "este mês", "mês passado", "últimos N dias". */
export function parsePeriod(question: string, nowMs: number, tz = DEFAULT_TZ_OFFSET_MIN): Period {
  const q = question.toLowerCase();
  const p = localParts(nowMs, tz);
  const day = 86_400_000;
  const local = new Date(nowMs + tz * 60_000);
  const monthStart = (y: number, m: number) => Date.UTC(y, m, 1) - tz * 60_000;
  if (/\bhoje\b/.test(q)) return { fromMs: p.dayStartMs, toMs: p.dayStartMs + day, label: "hoje" };
  const last = /últimos?\s+(\d{1,3})\s+dias|ultimos?\s+(\d{1,3})\s+dias/.exec(q);
  if (last) {
    const n = Math.min(365, Number(last[1] ?? last[2]));
    return { fromMs: p.dayStartMs - (n - 1) * day, toMs: p.dayStartMs + day, label: `últimos ${n} dias` };
  }
  if (/(nesta|esta|essa|nessa)\s+semana|semana atual/.test(q)) {
    const mondayOffset = (p.weekday + 6) % 7;
    const from = p.dayStartMs - mondayOffset * day;
    return { fromMs: from, toMs: from + 7 * day, label: "esta semana (segunda a domingo)" };
  }
  if (/m[eê]s passado|último m[eê]s|ultimo m[eê]s/.test(q)) {
    return { fromMs: monthStart(local.getUTCFullYear(), local.getUTCMonth() - 1), toMs: monthStart(local.getUTCFullYear(), local.getUTCMonth()), label: "mês passado" };
  }
  if (/pr[oó]xim[oa]s?\s+(7\s+dias|semana)/.test(q)) {
    return { fromMs: nowMs, toMs: p.dayStartMs + 8 * day, label: "próximos 7 dias" };
  }
  return { fromMs: monthStart(local.getUTCFullYear(), local.getUTCMonth()), toMs: monthStart(local.getUTCFullYear(), local.getUTCMonth() + 1), label: "este mês" };
}

export function brl(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const reais = Math.floor(abs / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return `${sign}R$ ${reais},${String(abs % 100).padStart(2, "0")}`;
}

export const SUPPORTED_QUESTIONS = [
  "Quantos pacientes faltaram este mês?",
  "Quantas consultas foram canceladas esta semana?",
  "Quais retornos estão pendentes?",
  "Quais horários estão livres nos próximos 7 dias?",
  "Quantos pacientes frequentes/inativos temos?",
  "Quanto recebemos nesta semana?",
  "Quanto está pendente de recebimento este mês?",
  "Qual o resultado (receitas x despesas) do mês passado?",
];
