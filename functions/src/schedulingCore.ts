/**
 * Regras puras da agenda (sem Firestore, sem relógio global).
 *
 * As callables de `scheduling.ts` decidem tudo por aqui, dentro de
 * transações. O mesmo cálculo serve para a recepção, para a família e para o
 * assistente de IA: ninguém calcula horário livre no aparelho.
 *
 * Fuso: a agenda é local (America/Sao_Paulo, UTC-3 sem horário de verão
 * desde 2019). O deslocamento é parâmetro para os testes não dependerem do
 * fuso da máquina.
 */

export const DEFAULT_TZ_OFFSET_MIN = -180;
const MIN_MS = 60_000;
const DAY_MS = 86_400_000;

// ------------------------------------------------------------------ Status

export const APPOINTMENT_STATUSES = [
  "requested",
  "awaitingConfirmation",
  "confirmed",
  "inProgress",
  "completed",
  "cancelled",
  "noShow",
] as const;
export type AppointmentStatus = (typeof APPOINTMENT_STATUSES)[number];

/** Não ocupam o horário (liberam a vaga). */
export const NON_BLOCKING_STATUSES: ReadonlySet<string> = new Set(["cancelled", "noShow"]);
export const TERMINAL_STATUSES: ReadonlySet<string> = new Set(["completed", "cancelled", "noShow"]);

export type ScheduleActor = "family" | "reception" | "professional" | "manager" | "system";

const STAFF: ScheduleActor[] = ["reception", "professional", "manager"];

/**
 * Transições permitidas por perfil. Atendimento (em andamento/concluído) é
 * do profissional; falta é registrada pela equipe; a família confirma o que
 * a clínica deixou aguardando e cancela dentro das regras.
 */
const TRANSITIONS: Record<AppointmentStatus, Partial<Record<AppointmentStatus, ScheduleActor[]>>> = {
  requested: {
    awaitingConfirmation: STAFF,
    confirmed: STAFF,
    cancelled: ["family", ...STAFF, "system"],
  },
  awaitingConfirmation: {
    confirmed: ["family", ...STAFF],
    cancelled: ["family", ...STAFF, "system"],
  },
  confirmed: {
    inProgress: ["professional"],
    noShow: STAFF,
    cancelled: ["family", ...STAFF],
  },
  inProgress: {
    completed: ["professional"],
  },
  completed: {},
  cancelled: {},
  noShow: {},
};

export function isAppointmentStatus(v: unknown): v is AppointmentStatus {
  return typeof v === "string" && (APPOINTMENT_STATUSES as readonly string[]).includes(v);
}

export function canTransition(
  from: string,
  to: string,
  actor: ScheduleActor
): boolean {
  if (!isAppointmentStatus(from) || !isAppointmentStatus(to)) return false;
  return (TRANSITIONS[from][to] ?? []).includes(actor);
}

// ------------------------------------------------------------------ Regras

export interface SchedulingPolicy {
  /** Antecedência mínima para a família pedir/remarcar (minutos). */
  minLeadMinutes: number;
  maxDaysAhead: number;
  slotStepMinutes: number;
  /** Família cancela/remarca sozinha até N horas antes. */
  familyCancelUntilHours: number;
  familyRescheduleUntilHours: number;
  /** Status com que nasce o pedido da família. */
  familyBookingStatus: "requested" | "awaitingConfirmation" | "confirmed";
  /** Prazo para quem recebeu convite da lista de espera responder. */
  waitlistHoldMinutes: number;
  /** Lembretes (horas antes), no máximo 3. */
  reminderOffsetsHours: number[];
  /** Retorno sugerido (dias) depois de uma consulta concluída. */
  returnAfterDays: number;
  /** Família pode remarcar quantas vezes a mesma consulta. */
  maxFamilyReschedules: number;
}

export const DEFAULT_POLICY: SchedulingPolicy = {
  minLeadMinutes: 120,
  maxDaysAhead: 90,
  slotStepMinutes: 15,
  familyCancelUntilHours: 24,
  familyRescheduleUntilHours: 24,
  familyBookingStatus: "requested",
  waitlistHoldMinutes: 120,
  reminderOffsetsHours: [24, 2],
  returnAfterDays: 30,
  maxFamilyReschedules: 2,
};

const REMINDER_CHOICES = [168, 72, 48, 24, 12, 6, 3, 2, 1];

/** Mescla e valida a configuração da clínica; valor inválido volta ao padrão. */
export function normalizePolicy(raw: unknown): SchedulingPolicy {
  const r = (raw ?? {}) as Record<string, unknown>;
  const int = (k: keyof SchedulingPolicy, min: number, max: number): number => {
    const v = Number(r[k]);
    return Number.isInteger(v) && v >= min && v <= max ? v : (DEFAULT_POLICY[k] as number);
  };
  const offsets = Array.isArray(r.reminderOffsetsHours)
    ? [...new Set(r.reminderOffsetsHours.map(Number))]
        .filter((h) => REMINDER_CHOICES.includes(h))
        .sort((a, b) => b - a)
        .slice(0, 3)
    : DEFAULT_POLICY.reminderOffsetsHours;
  const status = ["requested", "awaitingConfirmation", "confirmed"].includes(String(r.familyBookingStatus))
    ? (r.familyBookingStatus as SchedulingPolicy["familyBookingStatus"])
    : DEFAULT_POLICY.familyBookingStatus;
  const step = int("slotStepMinutes", 5, 60);
  return {
    minLeadMinutes: int("minLeadMinutes", 0, 7 * 24 * 60),
    maxDaysAhead: int("maxDaysAhead", 1, 366),
    slotStepMinutes: step % 5 === 0 ? step : DEFAULT_POLICY.slotStepMinutes,
    familyCancelUntilHours: int("familyCancelUntilHours", 0, 168),
    familyRescheduleUntilHours: int("familyRescheduleUntilHours", 0, 168),
    familyBookingStatus: status,
    waitlistHoldMinutes: int("waitlistHoldMinutes", 15, 72 * 60),
    reminderOffsetsHours: offsets,
    returnAfterDays: int("returnAfterDays", 1, 365),
    maxFamilyReschedules: int("maxFamilyReschedules", 0, 10),
  };
}

export function familyMayCancel(startMs: number, nowMs: number, p: SchedulingPolicy): boolean {
  return startMs - nowMs >= p.familyCancelUntilHours * 3_600_000;
}

export function familyMayReschedule(
  startMs: number,
  nowMs: number,
  reschedules: number,
  p: SchedulingPolicy
): boolean {
  return startMs - nowMs >= p.familyRescheduleUntilHours * 3_600_000 &&
    reschedules < p.maxFamilyReschedules;
}

// ------------------------------------------------------------------ Duração

export const APPOINTMENT_TYPES = ["presencial", "teleconsulta", "primeiraConsulta", "retorno", "procedimento"] as const;
export type AppointmentType = (typeof APPOINTMENT_TYPES)[number];

const DEFAULT_DURATION: Record<AppointmentType, number> = {
  presencial: 30,
  teleconsulta: 30,
  primeiraConsulta: 45,
  retorno: 20,
  procedimento: 30,
};

export function isValidDuration(min: unknown): min is number {
  return Number.isInteger(min) && (min as number) >= 10 && (min as number) <= 240 &&
    (min as number) % 5 === 0;
}

/** Duração: a do serviço, senão a do tipo configurada pela clínica, senão o padrão. */
export function resolveDuration(
  type: string,
  service: { durationMinutes?: unknown } | null,
  clinicDurations: Record<string, unknown> | null
): number {
  if (service && isValidDuration(service.durationMinutes)) return service.durationMinutes;
  const t = (APPOINTMENT_TYPES as readonly string[]).includes(type) ? (type as AppointmentType) : "presencial";
  const configured = clinicDurations?.[t];
  return isValidDuration(configured) ? configured : DEFAULT_DURATION[t];
}

// ------------------------------------------------------------------ Horários

export interface TimeRange {
  /** Minutos desde a meia-noite local. */
  start: number;
  end: number;
}
/** 0 = domingo ... 6 = sábado. */
export type WeeklyHours = Partial<Record<number, TimeRange[]>>;

export interface Interval {
  start: number;
  end: number;
}

export function overlaps(a: Interval, b: Interval): boolean {
  return a.start < b.end && b.start < a.end;
}

/** "08:00-12:00" → {start: 480, end: 720}. */
export function parseRange(s: unknown): TimeRange | null {
  if (typeof s !== "string") return null;
  const m = /^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/.exec(s.trim());
  if (!m) return null;
  const start = Number(m[1]) * 60 + Number(m[2]);
  const end = Number(m[3]) * 60 + Number(m[4]);
  if (start >= end || end > 24 * 60 || Number(m[2]) > 59 || Number(m[4]) > 59) return null;
  return { start, end };
}

/** `{ "1": ["08:00-12:00", "13:00-17:00"] }` → WeeklyHours; ignora o inválido. */
export function parseWeeklyHours(raw: unknown): WeeklyHours {
  const out: WeeklyHours = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
    const day = Number(k);
    if (!Number.isInteger(day) || day < 0 || day > 6 || !Array.isArray(v)) continue;
    const ranges = v.map(parseRange).filter((r): r is TimeRange => r !== null)
      .sort((a, b) => a.start - b.start);
    if (ranges.length) out[day] = ranges;
  }
  return out;
}

export interface LocalParts {
  weekday: number;
  minuteOfDay: number;
  /** Início do dia local, em ms UTC. */
  dayStartMs: number;
}

export function localParts(ms: number, tzOffsetMin = DEFAULT_TZ_OFFSET_MIN): LocalParts {
  const shifted = ms + tzOffsetMin * MIN_MS;
  const dayIndex = Math.floor(shifted / DAY_MS);
  return {
    weekday: ((dayIndex % 7) + 7 + 4) % 7, // 1970-01-01 foi quinta-feira
    minuteOfDay: Math.floor((shifted - dayIndex * DAY_MS) / MIN_MS),
    dayStartMs: dayIndex * DAY_MS - tzOffsetMin * MIN_MS,
  };
}

export interface SlotQuery {
  hours: WeeklyHours;
  /** Intervalos fixos de pausa por dia da semana (almoço etc.). */
  breaks?: WeeklyHours;
  /** Bloqueios, férias, consultas ativas, reservas temporárias. */
  unavailable: Interval[];
  durationMinutes: number;
  stepMinutes: number;
  fromMs: number;
  days: number;
  nowMs: number;
  minLeadMinutes: number;
  maxDaysAhead: number;
  tzOffsetMin?: number;
  limit?: number;
}

/** Inícios livres (ms), em ordem. Determinístico para a mesma entrada. */
export function computeSlots(q: SlotQuery): number[] {
  const tz = q.tzOffsetMin ?? DEFAULT_TZ_OFFSET_MIN;
  const durMs = q.durationMinutes * MIN_MS;
  const earliest = q.nowMs + q.minLeadMinutes * MIN_MS;
  const latest = q.nowMs + q.maxDaysAhead * DAY_MS;
  const days = Math.max(0, Math.min(q.days, 62));
  const limit = q.limit ?? 500;
  const out: number[] = [];
  const firstDay = localParts(q.fromMs, tz).dayStartMs;

  for (let d = 0; d < days && out.length < limit; d++) {
    const dayStart = firstDay + d * DAY_MS;
    const weekday = localParts(dayStart, tz).weekday;
    const breaks = (q.breaks?.[weekday] ?? []).map((b) => ({
      start: dayStart + b.start * MIN_MS,
      end: dayStart + b.end * MIN_MS,
    }));
    for (const range of q.hours[weekday] ?? []) {
      for (let m = range.start; m + q.durationMinutes <= range.end; m += q.stepMinutes) {
        const slot = { start: dayStart + m * MIN_MS, end: dayStart + m * MIN_MS + durMs };
        if (slot.start < earliest || slot.start < q.fromMs || slot.start > latest) continue;
        if (breaks.some((b) => overlaps(slot, b))) continue;
        if (q.unavailable.some((u) => overlaps(slot, u))) continue;
        out.push(slot.start);
        if (out.length >= limit) break;
      }
    }
  }
  return out;
}

/** Problema do horário pedido, ou null se cabe na grade e não colide. */
export function slotProblem(
  startMs: number,
  durationMinutes: number,
  q: Omit<SlotQuery, "fromMs" | "days" | "durationMinutes" | "stepMinutes" | "limit">,
  opts: { enforceLead: boolean }
): string | null {
  const tz = q.tzOffsetMin ?? DEFAULT_TZ_OFFSET_MIN;
  if (!isValidDuration(durationMinutes)) return "Duração inválida.";
  if (startMs <= q.nowMs) return "Este horário já passou.";
  if (opts.enforceLead && startMs < q.nowMs + q.minLeadMinutes * MIN_MS) {
    return "Fora da antecedência mínima da clínica.";
  }
  if (startMs > q.nowMs + q.maxDaysAhead * DAY_MS) return "Data além do limite da agenda.";
  const p = localParts(startMs, tz);
  const endMin = p.minuteOfDay + durationMinutes;
  const inside = (q.hours[p.weekday] ?? []).some((r) => p.minuteOfDay >= r.start && endMin <= r.end);
  if (!inside) return "Fora do horário de atendimento.";
  const slot = { start: startMs, end: startMs + durationMinutes * MIN_MS };
  const inBreak = (q.breaks?.[p.weekday] ?? []).some((b) =>
    overlaps(slot, { start: p.dayStartMs + b.start * MIN_MS, end: p.dayStartMs + b.end * MIN_MS }));
  if (inBreak) return "Horário de intervalo.";
  if (q.unavailable.some((u) => overlaps(slot, u))) return "Horário indisponível.";
  return null;
}

// ------------------------------------------------------------------ Travas

/**
 * Concorrência: cada consulta ocupa "travas" de 5 minutos por recurso
 * (profissional, sala, equipamento). A transação cria todas; se alguma já
 * existir para uma consulta ativa, ninguém mais reserva aquele trecho —
 * vale também para horários que se sobrepõem sem começar juntos.
 */
export const LOCK_BUCKET_MIN = 5;

export type LockResource = "prof" | "room" | "equip";

export function lockIds(kind: LockResource, resourceId: string, startMs: number, durationMinutes: number): string[] {
  if (!resourceId || /[/]/.test(resourceId)) throw new Error("Recurso inválido.");
  const first = Math.floor(startMs / (LOCK_BUCKET_MIN * MIN_MS));
  const last = Math.ceil((startMs + durationMinutes * MIN_MS) / (LOCK_BUCKET_MIN * MIN_MS));
  const ids: string[] = [];
  for (let b = first; b < last; b++) ids.push(`${kind}_${resourceId}_${b}`);
  return ids;
}

export function allLockIds(r: {
  clinicScope: string;
  professionalId: string;
  roomId?: string | null;
  equipmentIds?: string[];
  startMs: number;
  durationMinutes: number;
}): string[] {
  const ids = lockIds("prof", r.professionalId, r.startMs, r.durationMinutes);
  if (r.roomId) ids.push(...lockIds("room", `${r.clinicScope}~${r.roomId}`, r.startMs, r.durationMinutes));
  for (const e of r.equipmentIds ?? []) {
    ids.push(...lockIds("equip", `${r.clinicScope}~${e}`, r.startMs, r.durationMinutes));
  }
  return ids;
}

// ------------------------------------------------------------------ Recorrência

export type Recurrence = "weekly" | "biweekly" | "monthly";

/** Datas da série (inclui a primeira). No máximo 26 ocorrências. */
export function expandRecurrence(startMs: number, freq: Recurrence, count: number, tzOffsetMin = DEFAULT_TZ_OFFSET_MIN): number[] {
  const n = Math.max(1, Math.min(Math.floor(count), 26));
  const out: number[] = [];
  if (freq === "monthly") {
    const local = new Date(startMs + tzOffsetMin * MIN_MS);
    const day = local.getUTCDate();
    for (let i = 0; i < n; i++) {
      const y = local.getUTCFullYear();
      const mo = local.getUTCMonth() + i;
      const lastDay = new Date(Date.UTC(y, mo + 1, 0)).getUTCDate();
      const t = Date.UTC(y, mo, Math.min(day, lastDay), local.getUTCHours(), local.getUTCMinutes());
      out.push(t - tzOffsetMin * MIN_MS);
    }
    return out;
  }
  const step = (freq === "weekly" ? 7 : 14) * DAY_MS;
  for (let i = 0; i < n; i++) out.push(startMs + i * step);
  return out;
}

// ------------------------------------------------------------------ Lista de espera

export interface WaitlistEntry {
  id: string;
  professionalId: string;
  status: string;
  createdAtMs: number;
  priority?: number;
  /** Janela aceita pelo paciente (ms). */
  earliestMs?: number | null;
  latestMs?: number | null;
  dayPart?: "manha" | "tarde" | "qualquer";
}

/** Próximo da fila que aceita esta vaga (prioridade, depois ordem de chegada). */
export function pickWaitlistEntry(
  entries: WaitlistEntry[],
  slot: { professionalId: string; startMs: number },
  tzOffsetMin = DEFAULT_TZ_OFFSET_MIN
): WaitlistEntry | null {
  const minute = localParts(slot.startMs, tzOffsetMin).minuteOfDay;
  const fits = entries.filter((e) =>
    e.status === "waiting" &&
    e.professionalId === slot.professionalId &&
    (e.earliestMs == null || slot.startMs >= e.earliestMs) &&
    (e.latestMs == null || slot.startMs <= e.latestMs) &&
    (e.dayPart == null || e.dayPart === "qualquer" ||
      (e.dayPart === "manha" ? minute < 12 * 60 : minute >= 12 * 60)));
  fits.sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0) || a.createdAtMs - b.createdAtMs);
  return fits[0] ?? null;
}

// ------------------------------------------------------------------ Lembretes

/** Momentos de envio ainda no futuro, com chave estável por versão da agenda. */
export function reminderPlan(
  appointmentId: string,
  startMs: number,
  scheduleVersion: number,
  offsetsHours: number[],
  nowMs: number
): Array<{ key: string; sendAtMs: number; offsetHours: number }> {
  return offsetsHours
    .map((h) => ({
      key: `rem_${appointmentId}_v${scheduleVersion}_${h}h`,
      sendAtMs: startMs - h * 3_600_000,
      offsetHours: h,
    }))
    .filter((r) => r.sendAtMs > nowMs);
}
