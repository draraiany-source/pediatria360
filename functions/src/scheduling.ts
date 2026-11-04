/**
 * Agenda inteligente: toda reserva, remarcação e mudança de status passa por
 * aqui, em transação, com travas por recurso (profissional, sala,
 * equipamento). As regras puras ficam em `schedulingCore.ts`.
 *
 * Princípios:
 * - Consulta nunca concede acesso clínico. Marcar para criança exige a
 *   concessão do titular já existente (mesma regra da Etapa 2).
 * - A recepção organiza a agenda sem ler prontuário: nada aqui devolve
 *   conteúdo clínico.
 * - O assistente de IA usa as mesmas callables (slots reais), e a reserva só
 *   acontece quando o usuário confirma — revalidando o horário na transação.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp, Transaction, DocumentReference } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { childOwnerUid, grantAllows, grantRef } from "./childAccess";
import { clinicRoleOf } from "./clinicFlow";
import { CARE_ROLES } from "./intake";
import {
  allLockIds,
  canTransition,
  computeSlots,
  expandRecurrence,
  familyMayCancel,
  familyMayReschedule,
  Interval,
  isAppointmentStatus,
  NON_BLOCKING_STATUSES,
  normalizePolicy,
  parseWeeklyHours,
  pickWaitlistEntry,
  Recurrence,
  reminderPlan,
  resolveDuration,
  ScheduleActor,
  SchedulingPolicy,
  slotProblem,
  WeeklyHours,
  APPOINTMENT_TYPES,
  TERMINAL_STATUSES,
} from "./schedulingCore";
import { DEFAULT_RULES, MessageKind, normalizeRule } from "./automationCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const MIN = 60_000;
const DAY = 86_400_000;
const MAX_LOOKBACK_MIN = 240;

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

function str(v: unknown, max = 200): string | null {
  return typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null;
}

function id(v: unknown): string | null {
  const s = str(v, 128);
  return s && !s.includes("/") ? s : null;
}

function parseStart(v: unknown): number {
  const ms = typeof v === "string" ? Date.parse(v) : NaN;
  if (!Number.isFinite(ms)) throw new HttpsError("invalid-argument", "Horário inválido.");
  if (Math.floor(ms / MIN) * MIN !== ms) throw new HttpsError("invalid-argument", "Horário inválido.");
  return ms;
}

// ------------------------------------------------------------------ Leitura de configuração

export interface ClinicSchedulingConfig {
  policy: SchedulingPolicy;
  typeDurations: Record<string, unknown> | null;
}

export async function loadSchedulingConfig(clinicId: string | null): Promise<ClinicSchedulingConfig> {
  if (!clinicId) return { policy: normalizePolicy(null), typeDurations: null };
  const snap = await db().collection("clinics").doc(clinicId).collection("settings").doc("scheduling").get();
  const d = snap.data() ?? {};
  return {
    policy: normalizePolicy(d.policy),
    typeDurations: (d.typeDurations as Record<string, unknown>) ?? null,
  };
}

interface ProfessionalCalendar {
  hours: WeeklyHours;
  breaks: WeeklyHours;
  vacations: Interval[];
  name: string;
  specialty: string | null;
}

function isoInterval(raw: unknown): Interval | null {
  const r = (raw ?? {}) as Record<string, unknown>;
  const start = Date.parse(String(r.startsAt ?? ""));
  const end = Date.parse(String(r.endsAt ?? ""));
  return Number.isFinite(start) && Number.isFinite(end) && end > start ? { start, end } : null;
}

/**
 * Grade do profissional. Na clínica: `professional_schedules/{prof}`.
 * Fora dela (ou sem grade): disponibilidade declarada no perfil, cada início
 * vira um intervalo da duração padrão.
 */
async function loadCalendar(clinicId: string | null, professionalId: string): Promise<ProfessionalCalendar> {
  const user = (await db().collection("users").doc(professionalId).get()).data() ?? {};
  const base = {
    name: String(user.name ?? ""),
    specialty: (user.specialty as string) ?? null,
  };
  if (clinicId) {
    const s = (await db().collection("clinics").doc(clinicId)
      .collection("professional_schedules").doc(professionalId).get()).data();
    if (s && s.active !== false) {
      return {
        ...base,
        hours: parseWeeklyHours(s.hours),
        breaks: parseWeeklyHours(s.breaks),
        vacations: (Array.isArray(s.vacations) ? s.vacations : [])
          .map(isoInterval).filter((i): i is Interval => i !== null),
      };
    }
  }
  const legacy = (user.availability ?? {}) as Record<string, unknown>;
  const step = Number(user.consultationMinutes ?? 30);
  const hours: WeeklyHours = {};
  for (const [k, v] of Object.entries(legacy)) {
    const day = Number(k);
    if (!Number.isInteger(day) || day < 0 || day > 6 || !Array.isArray(v)) continue;
    hours[day] = v
      .map((t) => /^(\d{2}):(\d{2})$/.exec(String(t)))
      .filter((m): m is RegExpExecArray => m !== null)
      .map((m) => {
        const start = Number(m[1]) * 60 + Number(m[2]);
        return { start, end: Math.min(start + step, 24 * 60) };
      });
  }
  return { ...base, hours, breaks: {}, vacations: [] };
}

/** Bloqueios da clínica que atingem o profissional/sala (ou a clínica toda). */
async function loadBlocks(clinicId: string | null, professionalId: string, roomId: string | null): Promise<Interval[]> {
  if (!clinicId) return [];
  const snap = await db().collection("clinics").doc(clinicId).collection("schedule_blocks").limit(500).get();
  return snap.docs
    .map((d) => d.data())
    .filter((b) => {
      const prof = str(b.professionalId);
      const room = str(b.roomId);
      if (!prof && !room) return true;
      return prof === professionalId || (roomId !== null && room === roomId);
    })
    .map(isoInterval)
    .filter((i): i is Interval => i !== null);
}

interface ActiveAppointment extends Interval {
  id: string;
}

function blockingIntervals(docs: FirebaseFirestore.QueryDocumentSnapshot[], ignoreId: string | null): ActiveAppointment[] {
  return docs
    .filter((d) => d.id !== ignoreId && !NON_BLOCKING_STATUSES.has(String(d.get("status"))))
    .map((d) => {
      const start = (d.get("startsAt") as Timestamp).toMillis();
      const dur = Number(d.get("durationMinutes") ?? 30);
      return { id: d.id, start, end: start + dur * MIN };
    });
}

function professionalRangeQuery(professionalId: string, fromMs: number, toMs: number) {
  return db().collection("appointments")
    .where("professionalId", "==", professionalId)
    .where("startsAt", ">=", Timestamp.fromMillis(fromMs - MAX_LOOKBACK_MIN * MIN))
    .where("startsAt", "<", Timestamp.fromMillis(toMs));
}

function roomRangeQuery(clinicId: string, roomId: string, fromMs: number, toMs: number) {
  return db().collection("appointments")
    .where("clinicId", "==", clinicId)
    .where("roomId", "==", roomId)
    .where("startsAt", ">=", Timestamp.fromMillis(fromMs - MAX_LOOKBACK_MIN * MIN))
    .where("startsAt", "<", Timestamp.fromMillis(toMs));
}

/** Reservas temporárias (convites da lista de espera) ainda dentro do prazo. */
async function activeHolds(professionalId: string, nowMs: number, ignoreHoldId: string | null): Promise<Interval[]> {
  const snap = await db().collection("schedule_holds")
    .where("professionalId", "==", professionalId)
    .where("holdUntil", ">", Timestamp.fromMillis(nowMs))
    .limit(100).get();
  return snap.docs
    .filter((d) => d.id !== ignoreHoldId && d.get("status") === "active")
    .map((d) => ({ start: Number(d.get("startMs")), end: Number(d.get("endMs")) }));
}

// ------------------------------------------------------------------ Papéis

async function professionalAvailable(clinicId: string | null, professionalId: string): Promise<boolean> {
  if (clinicId) {
    const role = await clinicRoleOf(clinicId, professionalId);
    return role !== null && CARE_ROLES.includes(role);
  }
  const p = (await db().collection("users").doc(professionalId).get()).data();
  return p?.professionalVerified === true;
}

/** Perfil de quem age sobre a consulta (null = sem relação). */
export async function scheduleActorFor(
  appt: Record<string, unknown>,
  uid: string
): Promise<ScheduleActor | null> {
  const clinicId = (appt.clinicId as string) ?? null;
  const role = clinicId ? await clinicRoleOf(clinicId, uid) : null;
  if (appt.professionalId === uid) {
    if (clinicId ? role !== null && CARE_ROLES.includes(role) : await professionalAvailable(null, uid)) {
      return "professional";
    }
  }
  if (role === "clinicAdmin") return "manager";
  if (role === "receptionist") return "reception";
  if (appt.patientId === uid) return "family";
  return null;
}

async function staffActorForClinic(clinicId: string, uid: string, professionalId: string): Promise<ScheduleActor> {
  const role = await clinicRoleOf(clinicId, uid);
  if (role === "clinicAdmin") return "manager";
  if (role === "receptionist") return "reception";
  if (role && CARE_ROLES.includes(role) && uid === professionalId) return "professional";
  throw new HttpsError("permission-denied", "Sem permissão para organizar esta agenda.");
}

// ------------------------------------------------------------------ Travas

interface LockOwner {
  appointmentId?: string;
  holdId?: string;
  version: number;
  holdUntilMs?: number;
}

const lockRef = (lockId: string) => db().collection("schedule_locks").doc(lockId);

/**
 * Lê as travas na transação. Trava de consulta cancelada, remarcada (versão
 * diferente) ou de convite vencido é considerada livre.
 */
async function readLockConflicts(
  tx: Transaction,
  lockIds: string[],
  ignore: { appointmentId?: string; holdId?: string },
  nowMs: number
): Promise<DocumentReference[]> {
  const refs = lockIds.map(lockRef);
  if (!refs.length) return refs;
  const snaps = await tx.getAll(...refs);
  const pendingAppointments: Array<{ apptId: string; version: number }> = [];
  for (const s of snaps) {
    if (!s.exists) continue;
    const d = s.data() ?? {};
    if (ignore.appointmentId && d.appointmentId === ignore.appointmentId) continue;
    if (ignore.holdId && d.holdId === ignore.holdId) continue;
    if (d.holdId) {
      if (Number(d.holdUntilMs ?? 0) > nowMs) throw slotTaken();
      continue;
    }
    if (d.appointmentId) pendingAppointments.push({ apptId: String(d.appointmentId), version: Number(d.version ?? 0) });
  }
  const unique = [...new Map(pendingAppointments.map((p) => [`${p.apptId}:${p.version}`, p])).values()];
  if (unique.length) {
    const apptSnaps = await tx.getAll(...unique.map((p) => db().collection("appointments").doc(p.apptId)));
    apptSnaps.forEach((a, i) => {
      if (!a.exists) return;
      const st = String(a.get("status"));
      const v = Number(a.get("scheduleVersion") ?? 0);
      if (!NON_BLOCKING_STATUSES.has(st) && v === unique[i].version) throw slotTaken();
    });
  }
  return refs;
}

function writeLocks(tx: Transaction, refs: DocumentReference[], owner: LockOwner, clinicId: string | null) {
  for (const r of refs) {
    tx.set(r, {
      appointmentId: owner.appointmentId ?? null,
      holdId: owner.holdId ?? null,
      version: owner.version,
      holdUntilMs: owner.holdUntilMs ?? null,
      clinicId,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

function slotTaken(): HttpsError {
  return new HttpsError("already-exists", "Este horário acabou de ser ocupado. Escolha outro.");
}

// ------------------------------------------------------------------ Lembretes e avisos

export async function automationRule(clinicId: string | null, kind: MessageKind) {
  if (!clinicId) return DEFAULT_RULES[kind];
  const snap = await db().collection("clinics").doc(clinicId).collection("automations").doc(kind).get();
  return normalizeRule(kind, snap.data());
}

export interface QueueSeed {
  key: string;
  kind: MessageKind;
  recipientUid: string;
  clinicId: string | null;
  sendAtMs: number;
  appointmentId?: string | null;
  scheduleVersion?: number | null;
  vars: Record<string, string>;
  ruleId?: string;
}

/** Cria os jobs (um por canal) se ainda não existirem: idempotente. */
export async function enqueueMessages(seeds: QueueSeed[], tx?: Transaction): Promise<number> {
  if (!seeds.length) return 0;
  const rules = new Map<string, Awaited<ReturnType<typeof automationRule>>>();
  const docs: Array<{ ref: DocumentReference; data: Record<string, unknown> }> = [];
  for (const s of seeds) {
    const ruleKey = `${s.clinicId}:${s.kind}`;
    if (!rules.has(ruleKey)) rules.set(ruleKey, await automationRule(s.clinicId, s.kind));
    const rule = rules.get(ruleKey)!;
    if (!rule.enabled) continue;
    for (const channel of rule.channels) {
      docs.push({
        ref: db().collection("message_queue").doc(`${s.key}_${channel}`),
        data: {
          kind: s.kind,
          channel,
          recipientUid: s.recipientUid,
          clinicId: s.clinicId,
          appointmentId: s.appointmentId ?? null,
          scheduleVersion: s.scheduleVersion ?? null,
          sendAt: Timestamp.fromMillis(s.sendAtMs),
          status: "pending",
          attempts: 0,
          vars: s.vars,
          ruleId: s.ruleId ?? s.kind,
          createdAt: FieldValue.serverTimestamp(),
        },
      });
    }
  }
  if (!docs.length) return 0;
  let created = 0;
  if (tx) {
    const snaps = await tx.getAll(...docs.map((d) => d.ref));
    snaps.forEach((s, i) => {
      if (!s.exists) {
        tx.set(docs[i].ref, docs[i].data);
        created++;
      }
    });
    return created;
  }
  for (const d of docs) {
    try {
      await d.ref.create(d.data);
      created++;
    } catch (e) {
      if ((e as { code?: number }).code !== 6) throw e; // ALREADY_EXISTS
    }
  }
  return created;
}

/** Cancela o que ainda não saiu (lembretes antigos depois de remarcar/cancelar). */
export async function cancelPendingMessages(appointmentId: string, reason: string, keepVersion?: number): Promise<number> {
  const snap = await db().collection("message_queue")
    .where("appointmentId", "==", appointmentId)
    .where("status", "==", "pending")
    .limit(100).get();
  const batch = db().batch();
  let n = 0;
  for (const d of snap.docs) {
    if (keepVersion != null && d.get("scheduleVersion") === keepVersion) continue;
    batch.update(d.ref, { status: "cancelled", cancelReason: reason, updatedAt: FieldValue.serverTimestamp() });
    n++;
  }
  if (n) await batch.commit();
  return n;
}

function fmtDate(ms: number): { data: string; hora: string } {
  const f = new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false,
  }).formatToParts(new Date(ms));
  const g = (t: string) => f.find((p) => p.type === t)?.value ?? "";
  return { data: `${g("day")}/${g("month")}`, hora: `${g("hour")}:${g("minute")}` };
}

function appointmentVars(a: Record<string, unknown>, startMs: number): Record<string, string> {
  const { data, hora } = fmtDate(startMs);
  return {
    crianca: String(a.childName ?? "a criança").split(" ")[0],
    profissional: String(a.professionalName ?? "o profissional"),
    data,
    hora,
  };
}

function reminderSeeds(apptId: string, a: Record<string, unknown>, startMs: number, version: number, policy: SchedulingPolicy, nowMs: number): QueueSeed[] {
  const vars = appointmentVars(a, startMs);
  const seeds: QueueSeed[] = reminderPlan(apptId, startMs, version, policy.reminderOffsetsHours, nowMs).map((r) => ({
    key: r.key,
    kind: "appointmentReminder" as MessageKind,
    recipientUid: String(a.patientId),
    clinicId: (a.clinicId as string) ?? null,
    sendAtMs: r.sendAtMs,
    appointmentId: apptId,
    scheduleVersion: version,
    vars,
  }));
  seeds.push({
    key: `pre_${apptId}_v${version}`,
    kind: "preVisitForm",
    recipientUid: String(a.patientId),
    clinicId: (a.clinicId as string) ?? null,
    sendAtMs: Math.max(nowMs, startMs - 48 * 3_600_000),
    appointmentId: apptId,
    scheduleVersion: version,
    vars,
  });
  return seeds;
}

async function logChange(apptId: string, entry: Record<string, unknown>) {
  const ref = db().collection("appointments").doc(apptId).collection("change_log").doc();
  await ref.set({ id: ref.id, ...entry, at: new Date().toISOString(), atServer: FieldValue.serverTimestamp() });
}

// ------------------------------------------------------------------ Horários livres

interface SlotRequest {
  clinicId: string | null;
  professionalId: string;
  type: string;
  serviceId: string | null;
  roomId: string | null;
}

async function loadService(clinicId: string | null, serviceId: string | null) {
  if (!clinicId || !serviceId) return null;
  const s = (await db().collection("clinics").doc(clinicId).collection("services").doc(serviceId).get()).data();
  if (!s || s.active === false) throw new HttpsError("not-found", "Serviço indisponível.");
  return s;
}

async function unavailableFor(req: SlotRequest, fromMs: number, toMs: number, nowMs: number, ignore: { appointmentId?: string | null; holdId?: string | null }) {
  const cal = await loadCalendar(req.clinicId, req.professionalId);
  const blocks = await loadBlocks(req.clinicId, req.professionalId, req.roomId);
  const prof = await professionalRangeQuery(req.professionalId, fromMs, toMs).get();
  const busy: Interval[] = blockingIntervals(prof.docs, ignore.appointmentId ?? null);
  if (req.clinicId && req.roomId) {
    const room = await roomRangeQuery(req.clinicId, req.roomId, fromMs, toMs).get();
    busy.push(...blockingIntervals(room.docs, ignore.appointmentId ?? null));
  }
  busy.push(...await activeHolds(req.professionalId, nowMs, ignore.holdId ?? null));
  return { cal, unavailable: [...busy, ...blocks, ...cal.vacations] };
}

/** Horários livres reais (família, recepção e assistente). */
export const getScheduleSlots = onCall({ region: REGION }, async (request) => {
  requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const professionalId = id(d.professionalId);
  if (!professionalId) throw new HttpsError("invalid-argument", "Profissional inválido.");
  const clinicId = id(d.clinicId);
  const type = (APPOINTMENT_TYPES as readonly string[]).includes(String(d.appointmentType)) ? String(d.appointmentType) : "presencial";
  const fromMs = Date.parse(String(d.from ?? ""));
  if (!Number.isFinite(fromMs)) throw new HttpsError("invalid-argument", "Data inválida.");
  const days = Math.max(1, Math.min(Number(d.days ?? 1) || 1, 31));
  if (!(await professionalAvailable(clinicId, professionalId))) {
    throw new HttpsError("not-found", "Profissional não disponível.");
  }
  const req: SlotRequest = { clinicId, professionalId, type, serviceId: id(d.serviceId), roomId: id(d.roomId) };
  const { policy, typeDurations } = await loadSchedulingConfig(clinicId);
  const duration = resolveDuration(type, await loadService(clinicId, req.serviceId), typeDurations);
  const nowMs = Date.now();
  const toMs = fromMs + days * DAY;
  const { cal, unavailable } = await unavailableFor(req, fromMs, toMs, nowMs, {});
  const isStaff = clinicId ? (await clinicRoleOf(clinicId, request.auth!.uid)) !== null : false;
  const slots = computeSlots({
    hours: cal.hours,
    breaks: cal.breaks,
    unavailable,
    durationMinutes: duration,
    stepMinutes: policy.slotStepMinutes,
    fromMs,
    days,
    nowMs,
    minLeadMinutes: isStaff ? 0 : policy.minLeadMinutes,
    maxDaysAhead: policy.maxDaysAhead,
    limit: 300,
  });
  return {
    durationMinutes: duration,
    appointmentType: type,
    slots: slots.map((s) => new Date(s).toISOString()),
    source: clinicId ? "agenda da clínica" : "disponibilidade do profissional",
  };
});

// ------------------------------------------------------------------ Reserva

interface ReserveInput {
  clinicId: string | null;
  professionalId: string;
  startMs: number;
  type: string;
  serviceId: string | null;
  roomId: string | null;
  roomLabel: string | null;
  equipmentIds: string[];
  patientId: string;
  childId: string | null;
  childName: string | null;
  reason: string | null;
  status: string;
  origin: "familyBooking" | "clinicStaff" | "waitlist";
  createdBy: string;
  enforceLead: boolean;
  seriesId?: string | null;
  holdId?: string | null;
  unitId?: string | null;
  fallbackPriceCents?: number;
}

/** Valida, trava e cria a consulta numa transação. Devolve o id. */
export async function reserveAppointment(input: ReserveInput): Promise<string> {
  const { policy, typeDurations } = await loadSchedulingConfig(input.clinicId);
  const service = await loadService(input.clinicId, input.serviceId);
  const duration = resolveDuration(input.type, service, typeDurations);
  const nowMs = Date.now();
  const req: SlotRequest = { ...input };
  const end = input.startMs + duration * MIN;
  const { cal, unavailable } = await unavailableFor(req, input.startMs, end, nowMs, { holdId: input.holdId });
  const problem = slotProblem(input.startMs, duration, {
    hours: cal.hours, breaks: cal.breaks, unavailable, nowMs,
    minLeadMinutes: policy.minLeadMinutes, maxDaysAhead: policy.maxDaysAhead,
  }, { enforceLead: input.enforceLead });
  if (problem) throw new HttpsError(problem === "Horário indisponível." ? "already-exists" : "failed-precondition", problem);

  const apptRef = db().collection("appointments").doc();
  const lockIds = allLockIds({
    clinicScope: input.clinicId ?? "sem-clinica",
    professionalId: input.professionalId,
    roomId: input.roomId,
    equipmentIds: input.equipmentIds,
    startMs: input.startMs,
    durationMinutes: duration,
  });
  const payload: Record<string, unknown> = {
    patientId: input.patientId,
    professionalId: input.professionalId,
    professionalName: cal.name,
    specialty: cal.specialty,
    startsAt: Timestamp.fromMillis(input.startMs),
    durationMinutes: duration,
    type: input.type,
    status: input.status,
    origin: input.origin,
    childId: input.childId,
    childName: input.childName,
    reason: input.reason,
    clinicId: input.clinicId,
    unitId: input.unitId ?? null,
    roomId: input.roomId,
    roomLabel: input.roomLabel,
    equipmentIds: input.equipmentIds,
    serviceId: input.serviceId,
    priceCents: Number.isInteger(service?.priceCents) ? service!.priceCents : (input.fallbackPriceCents ?? 0),
    paid: false,
    scheduleVersion: 1,
    rescheduleCount: 0,
    lockIds,
    remindersManaged: true,
    seriesId: input.seriesId ?? null,
    workflowStatus: input.clinicId ? "scheduled" : null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (input.origin === "familyBooking") payload.requestedBy = input.createdBy;
  else payload.createdBy = input.createdBy;

  await db().runTransaction(async (tx) => {
    const refs = await readLockConflicts(tx, lockIds, { holdId: input.holdId ?? undefined }, nowMs);
    // Consultas antigas (sem trava) ou criadas por outro caminho.
    const prof = await tx.get(professionalRangeQuery(input.professionalId, input.startMs, end));
    const busy = blockingIntervals(prof.docs, null);
    if (input.clinicId && input.roomId) {
      busy.push(...blockingIntervals((await tx.get(roomRangeQuery(input.clinicId, input.roomId, input.startMs, end))).docs, null));
    }
    if (busy.some((b) => b.start < end && input.startMs < b.end)) throw slotTaken();
    const intakes = await tx.get(db().collection("clinic_intakes")
      .where("professionalId", "==", input.professionalId)
      .where("requestedStartsAt", "==", Timestamp.fromMillis(input.startMs))
      .where("status", "==", "pendingGuardian").limit(1));
    if (!intakes.empty) throw slotTaken();
    const seeds = ["confirmed", "awaitingConfirmation", "requested"].includes(input.status)
      ? reminderSeeds(apptRef.id, payload, input.startMs, 1, policy, nowMs) : [];
    await enqueueMessages(seeds, tx);
    tx.set(apptRef, payload);
    writeLocks(tx, refs, { appointmentId: apptRef.id, version: 1 }, input.clinicId);
  });
  await logChange(apptRef.id, { action: "created", actorUid: input.createdBy, origin: input.origin, status: input.status, startsAt: new Date(input.startMs).toISOString() });
  return apptRef.id;
}

/** Concessão do titular exigida para a equipe marcar (Etapa 2). */
async function requireStaffBookingGrant(clinicId: string, childId: string, patientId: string, professionalId: string) {
  const owner = await childOwnerUid(childId);
  if (!owner || owner !== patientId) throw new HttpsError("permission-denied", "Responsável não confere com o cadastro da criança.");
  const g = await grantRef(owner, childId, professionalId).get();
  if (!grantAllows(g.data(), "summary", Date.now(), clinicId)) {
    throw new HttpsError("permission-denied", "O responsável ainda não autorizou este profissional. Use a solicitação de novo paciente.");
  }
  const child = (await db().collection("users").doc(owner).collection("children").doc(childId).get()).data();
  return String(child?.name ?? "") || null;
}

/** Recepção/gestão (ou o profissional para si) marca na agenda da clínica. */
export const scheduleAppointment = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = id(d.clinicId);
  const professionalId = id(d.professionalId);
  const childId = id(d.childId);
  const patientId = id(d.patientId);
  if (!clinicId || !professionalId || !childId || !patientId) {
    throw new HttpsError("invalid-argument", "Informe clínica, profissional, criança e responsável.");
  }
  await staffActorForClinic(clinicId, uid, professionalId);
  if (!(await professionalAvailable(clinicId, professionalId))) {
    throw new HttpsError("failed-precondition", "Profissional não vinculado a esta clínica.");
  }
  const childName = await requireStaffBookingGrant(clinicId, childId, patientId, professionalId);
  const type = (APPOINTMENT_TYPES as readonly string[]).includes(String(d.appointmentType)) ? String(d.appointmentType) : "presencial";
  const status = ["requested", "awaitingConfirmation", "confirmed"].includes(String(d.status)) ? String(d.status) : "awaitingConfirmation";
  const equipmentIds = Array.isArray(d.equipmentIds) ? d.equipmentIds.map(id).filter((x): x is string => !!x).slice(0, 5) : [];
  const roomId = id(d.roomId);
  const startMs = parseStart(d.startsAt);
  const base = {
    clinicId, professionalId, type, serviceId: id(d.serviceId), roomId, roomLabel: str(d.roomLabel, 80),
    equipmentIds, patientId, childId, childName, reason: str(d.reason, 500), status,
    origin: "clinicStaff" as const, createdBy: uid, enforceLead: false, unitId: id(d.unitId),
  };

  const rec = (d.recurrence ?? null) as Record<string, unknown> | null;
  if (!rec) {
    return { appointmentIds: [await reserveAppointment({ ...base, startMs })], conflicts: [] };
  }
  const freq = ["weekly", "biweekly", "monthly"].includes(String(rec.frequency)) ? (rec.frequency as Recurrence) : null;
  if (!freq) throw new HttpsError("invalid-argument", "Recorrência inválida.");
  const dates = expandRecurrence(startMs, freq, Number(rec.count ?? 1));
  const skip = rec.onConflict === "skip";
  const seriesId = db().collection("appointment_series").doc().id;

  // Pré-checagem: mostra todos os conflitos antes de criar qualquer coisa.
  const { policy, typeDurations } = await loadSchedulingConfig(clinicId);
  const duration = resolveDuration(type, await loadService(clinicId, base.serviceId), typeDurations);
  const nowMs = Date.now();
  const conflicts: Array<{ startsAt: string; reason: string }> = [];
  for (const s of dates) {
    const { cal, unavailable } = await unavailableFor(base, s, s + duration * MIN, nowMs, {});
    const p = slotProblem(s, duration, { hours: cal.hours, breaks: cal.breaks, unavailable, nowMs, minLeadMinutes: 0, maxDaysAhead: Math.max(policy.maxDaysAhead, 366) }, { enforceLead: false });
    if (p) conflicts.push({ startsAt: new Date(s).toISOString(), reason: p });
  }
  if (conflicts.length && !skip) return { appointmentIds: [], conflicts, created: false };
  const blocked = new Set(conflicts.map((c) => c.startsAt));
  const ids: string[] = [];
  for (const s of dates) {
    if (blocked.has(new Date(s).toISOString())) continue;
    try {
      ids.push(await reserveAppointment({ ...base, startMs: s, seriesId }));
    } catch (e) {
      conflicts.push({ startsAt: new Date(s).toISOString(), reason: e instanceof HttpsError ? e.message : "falha" });
    }
  }
  await db().collection("appointment_series").doc(seriesId).set({
    clinicId, professionalId, patientId, childId, frequency: freq, appointmentIds: ids,
    skipped: conflicts, createdBy: uid, createdAt: FieldValue.serverTimestamp(),
  });
  return { appointmentIds: ids, conflicts, seriesId, created: ids.length > 0 };
});

// ------------------------------------------------------------------ Remarcação

export async function performReschedule(uid: string, d: Record<string, unknown>) {
  const apptId = id(d.appointmentId);
  if (!apptId) throw new HttpsError("invalid-argument", "Consulta inválida.");
  const newStart = parseStart(d.startsAt);
  const ref = db().collection("appointments").doc(apptId);
  const snap = await ref.get();
  const a = snap.data();
  if (!a) throw new HttpsError("not-found", "Consulta não encontrada.");
  const actor = await scheduleActorFor(a, uid);
  if (!actor) throw new HttpsError("permission-denied", "Sem permissão para esta consulta.");
  if (TERMINAL_STATUSES.has(String(a.status)) || a.status === "inProgress") {
    throw new HttpsError("failed-precondition", "Esta consulta não pode mais ser remarcada.");
  }
  const clinicId = (a.clinicId as string) ?? null;
  const { policy } = await loadSchedulingConfig(clinicId);
  const nowMs = Date.now();
  const oldStart = a.startsAt instanceof Timestamp ? a.startsAt.toMillis() : null;
  if (actor === "family" && (oldStart == null || !familyMayReschedule(oldStart, nowMs, Number(a.rescheduleCount ?? 0), policy))) {
    throw new HttpsError("failed-precondition", "Pelo prazo da clínica, a remarcação precisa ser feita com a recepção.");
  }
  const roomId = d.roomId === undefined ? ((a.roomId as string) ?? null) : id(d.roomId);
  const duration = Number(a.durationMinutes ?? 30);
  const req: SlotRequest = { clinicId, professionalId: String(a.professionalId), type: String(a.type ?? "presencial"), serviceId: null, roomId };
  const end = newStart + duration * MIN;
  const { cal, unavailable } = await unavailableFor(req, newStart, end, nowMs, { appointmentId: apptId });
  const problem = slotProblem(newStart, duration, { hours: cal.hours, breaks: cal.breaks, unavailable, nowMs, minLeadMinutes: policy.minLeadMinutes, maxDaysAhead: policy.maxDaysAhead }, { enforceLead: actor === "family" });
  if (problem) throw new HttpsError(problem === "Horário indisponível." ? "already-exists" : "failed-precondition", problem);

  const version = Number(a.scheduleVersion ?? 0) + 1;
  const lockIds = allLockIds({ clinicScope: clinicId ?? "sem-clinica", professionalId: String(a.professionalId), roomId, equipmentIds: (a.equipmentIds as string[]) ?? [], startMs: newStart, durationMinutes: duration });
  const reason = str(d.reason, 300);
  await db().runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (Number(cur.get("scheduleVersion") ?? 0) !== version - 1) {
      throw new HttpsError("aborted", "A consulta mudou enquanto você remarcava. Atualize e tente de novo.");
    }
    const refs = await readLockConflicts(tx, lockIds, { appointmentId: apptId }, nowMs);
    const prof = await tx.get(professionalRangeQuery(String(a.professionalId), newStart, end));
    const busy = blockingIntervals(prof.docs, apptId);
    if (clinicId && roomId) busy.push(...blockingIntervals((await tx.get(roomRangeQuery(clinicId, roomId, newStart, end))).docs, apptId));
    if (busy.some((b) => b.start < end && newStart < b.end)) throw slotTaken();
    const seeds = reminderSeeds(apptId, a, newStart, version, policy, nowMs);
    seeds.push({ key: `chg_${apptId}_v${version}`, kind: "appointmentChange", recipientUid: String(a.patientId), clinicId, sendAtMs: nowMs, appointmentId: apptId, scheduleVersion: version, vars: { ...appointmentVars(a, newStart), mudanca: "remarcada" } });
    // Quem remarca não é avisado de novo: o aviso vai só se foi a clínica.
    await enqueueMessages(actor === "family" ? seeds.filter((s) => s.kind !== "appointmentChange") : seeds, tx);
    for (const old of ((a.lockIds as string[]) ?? []).filter((l) => !lockIds.includes(l))) tx.delete(lockRef(old));
    tx.update(ref, {
      startsAt: Timestamp.fromMillis(newStart),
      previousStartsAt: a.startsAt,
      roomId,
      scheduleVersion: version,
      rescheduleCount: FieldValue.increment(1),
      lockIds,
      remindersManaged: true,
      rescheduledAt: FieldValue.serverTimestamp(),
      rescheduledBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
      ...(actor === "family" && policy.familyBookingStatus !== "confirmed" ? { status: "requested" } : {}),
    });
    writeLocks(tx, refs, { appointmentId: apptId, version }, clinicId);
  });
  const cancelled = await cancelPendingMessages(apptId, "consulta remarcada", version);
  await logChange(apptId, { action: "rescheduled", actorUid: uid, actorRole: actor, from: oldStart != null ? new Date(oldStart).toISOString() : null, to: new Date(newStart).toISOString(), reason });
  if (oldStart != null) await offerFreedSlot({ ...a, id: apptId }, oldStart).catch((e) => logger.warn("lista de espera", { code: (e as Error).name }));
  return { ok: true, scheduleVersion: version, cancelledMessages: cancelled };
}

export const rescheduleAppointment = onCall({ region: REGION }, async (request) =>
  performReschedule(requireUid(request), (request.data ?? {}) as Record<string, unknown>));

// ------------------------------------------------------------------ Status

export async function performStatusChange(uid: string, d: Record<string, unknown>) {
  const apptId = id(d.appointmentId);
  const to = String(d.status ?? "");
  if (!apptId || !isAppointmentStatus(to)) throw new HttpsError("invalid-argument", "Status inválido.");
  const ref = db().collection("appointments").doc(apptId);
  const a = (await ref.get()).data();
  if (!a) throw new HttpsError("not-found", "Consulta não encontrada.");
  const actor = await scheduleActorFor(a, uid);
  if (!actor) throw new HttpsError("permission-denied", "Sem permissão para esta consulta.");
  const from = String(a.status);
  if (!canTransition(from, to, actor)) {
    throw new HttpsError("failed-precondition", `Mudança de "${from}" para "${to}" não permitida para este perfil.`);
  }
  const reason = str(d.reason, 300);
  const nowMs = Date.now();
  // Pedido avulso da família pode não ter horário ainda.
  const startMs = a.startsAt instanceof Timestamp ? a.startsAt.toMillis() : null;
  const clinicId = (a.clinicId as string) ?? null;
  const { policy } = await loadSchedulingConfig(clinicId);
  if (to === "cancelled") {
    if (actor !== "family" && !reason) throw new HttpsError("invalid-argument", "Informe o motivo do cancelamento.");
    if (actor === "family" && startMs != null && !familyMayCancel(startMs, nowMs, policy)) {
      throw new HttpsError("failed-precondition", "Pelo prazo da clínica, o cancelamento precisa ser feito com a recepção.");
    }
  }
  if (startMs == null && to !== "cancelled") {
    throw new HttpsError("failed-precondition", "Defina o horário (remarcar) antes de mudar o status.");
  }
  if (to === "noShow" && startMs != null && startMs > nowMs) throw new HttpsError("failed-precondition", "Falta só pode ser registrada depois do horário.");
  const version = Number(a.scheduleVersion ?? 0);
  const at = startMs ?? nowMs;

  await db().runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.get("status") !== from || Number(cur.get("scheduleVersion") ?? 0) !== version) {
      throw new HttpsError("aborted", "A consulta mudou. Atualize e tente de novo.");
    }
    const seeds: QueueSeed[] = [];
    const vars = appointmentVars(a, at);
    if (to === "cancelled" && actor !== "family" && startMs != null) {
      seeds.push({ key: `chg_${apptId}_cancel`, kind: "appointmentChange", recipientUid: String(a.patientId), clinicId, sendAtMs: nowMs, appointmentId: apptId, vars: { ...vars, mudanca: "cancelada" } });
    }
    if (to === "confirmed") seeds.push(...reminderSeeds(apptId, a, at, version, policy, nowMs));
    if (to === "noShow") seeds.push({ key: `nos_${apptId}`, kind: "noShowFollowUp", recipientUid: String(a.patientId), clinicId, sendAtMs: nowMs + (await automationRule(clinicId, "noShowFollowUp")).delayHours * 3_600_000, appointmentId: apptId, vars });
    if (to === "completed") {
      seeds.push({ key: `sat_${apptId}`, kind: "satisfactionSurvey", recipientUid: String(a.patientId), clinicId, sendAtMs: nowMs + (await automationRule(clinicId, "satisfactionSurvey")).delayHours * 3_600_000, appointmentId: apptId, vars });
      seeds.push({ key: `ret_${apptId}`, kind: "returnReminder", recipientUid: String(a.patientId), clinicId, sendAtMs: at + Math.max(1, policy.returnAfterDays - 7) * DAY, vars });
    }
    await enqueueMessages(seeds, tx);
    const patch: Record<string, unknown> = { status: to, updatedAt: FieldValue.serverTimestamp() };
    if (to === "cancelled") Object.assign(patch, { cancelledAt: FieldValue.serverTimestamp(), cancelledBy: uid, cancelReason: reason ?? "cancelado pela família" });
    if (to === "confirmed") Object.assign(patch, { confirmedAt: FieldValue.serverTimestamp(), confirmedBy: uid });
    if (to === "completed") Object.assign(patch, { completedAt: FieldValue.serverTimestamp(), expectedReturnAt: Timestamp.fromMillis(at + policy.returnAfterDays * DAY) });
    if (to === "noShow") patch.noShowAt = FieldValue.serverTimestamp();
    if (NON_BLOCKING_STATUSES.has(to)) {
      for (const l of (a.lockIds as string[]) ?? []) tx.delete(lockRef(l));
    }
    tx.update(ref, patch);
  });
  if (NON_BLOCKING_STATUSES.has(to)) {
    await cancelPendingMessages(apptId, `consulta ${to}`);
  }
  await logChange(apptId, { action: "status", actorUid: uid, actorRole: actor, from, to, reason });
  if (to === "cancelled" && startMs != null && startMs > nowMs) {
    await offerFreedSlot({ ...a, id: apptId }, startMs).catch((e) => logger.warn("lista de espera", { code: (e as Error).name }));
  }
  return { ok: true, status: to };
}

export const setAppointmentStatus = onCall({ region: REGION }, async (request) =>
  performStatusChange(requireUid(request), (request.data ?? {}) as Record<string, unknown>));

// ------------------------------------------------------------------ Lista de espera

export const joinWaitlist = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = id(d.clinicId);
  const professionalId = id(d.professionalId);
  const childId = id(d.childId);
  if (!clinicId || !professionalId || !childId) throw new HttpsError("invalid-argument", "Dados incompletos.");
  const owner = await childOwnerUid(childId);
  let patientId = uid;
  let createdBy: "family" | "staff" = "family";
  if (owner !== uid) {
    const role = await clinicRoleOf(clinicId, uid);
    if (role !== "clinicAdmin" && role !== "receptionist") throw new HttpsError("permission-denied", "Criança não encontrada.");
    if (!owner || id(d.patientId) !== owner) throw new HttpsError("permission-denied", "Responsável não confere.");
    patientId = owner;
    createdBy = "staff";
  }
  if (!(await professionalAvailable(clinicId, professionalId))) throw new HttpsError("not-found", "Profissional não disponível.");
  const dup = await db().collection("clinics").doc(clinicId).collection("waitlist")
    .where("childId", "==", childId).where("professionalId", "==", professionalId)
    .where("status", "in", ["waiting", "offered"]).limit(1).get();
  if (!dup.empty) return { entryId: dup.docs[0].id, alreadyWaiting: true };
  const child = (await db().collection("users").doc(patientId).collection("children").doc(childId).get()).data();
  const ref = db().collection("clinics").doc(clinicId).collection("waitlist").doc();
  const earliest = Date.parse(String(d.earliest ?? ""));
  const latest = Date.parse(String(d.latest ?? ""));
  await ref.set({
    clinicId, professionalId, childId, patientId,
    childName: String(child?.name ?? "") || null,
    appointmentType: (APPOINTMENT_TYPES as readonly string[]).includes(String(d.appointmentType)) ? d.appointmentType : "presencial",
    dayPart: ["manha", "tarde", "qualquer"].includes(String(d.dayPart)) ? d.dayPart : "qualquer",
    earliestMs: Number.isFinite(earliest) ? earliest : null,
    latestMs: Number.isFinite(latest) ? latest : null,
    priority: createdBy === "staff" && Number.isInteger(d.priority) ? Math.max(0, Math.min(Number(d.priority), 5)) : 0,
    status: "waiting",
    createdBy, createdByUid: uid,
    createdAt: FieldValue.serverTimestamp(),
    createdAtMs: Date.now(),
  });
  return { entryId: ref.id, alreadyWaiting: false };
});

/**
 * Vaga liberada → convite ao próximo da fila, com reserva temporária
 * (trava de "hold") até o prazo. Ninguém mais reserva o horário enquanto o
 * convite vale; ao vencer, a trava expira sozinha.
 */
export async function offerFreedSlot(a: Record<string, unknown> & { id: string }, startMs: number): Promise<string | null> {
  const clinicId = (a.clinicId as string) ?? null;
  if (!clinicId) return null;
  const nowMs = Date.now();
  if (startMs <= nowMs + 30 * MIN) return null;
  const rule = await automationRule(clinicId, "waitlistOffer");
  if (!rule.enabled || rule.paused) return null;
  const professionalId = String(a.professionalId);
  const entries = await db().collection("clinics").doc(clinicId).collection("waitlist")
    .where("professionalId", "==", professionalId).where("status", "==", "waiting").limit(50).get();
  const pick = pickWaitlistEntry(entries.docs.map((e) => ({
    id: e.id, professionalId, status: "waiting", createdAtMs: Number(e.get("createdAtMs") ?? 0),
    priority: Number(e.get("priority") ?? 0), earliestMs: e.get("earliestMs") ?? null,
    latestMs: e.get("latestMs") ?? null, dayPart: e.get("dayPart") ?? "qualquer",
  })), { professionalId, startMs });
  if (!pick) return null;
  const { policy } = await loadSchedulingConfig(clinicId);
  const duration = Number(a.durationMinutes ?? 30);
  const holdUntilMs = Math.min(nowMs + policy.waitlistHoldMinutes * MIN, startMs - 15 * MIN);
  const entryRef = db().collection("clinics").doc(clinicId).collection("waitlist").doc(pick.id);
  const holdRef = db().collection("schedule_holds").doc(`wl_${pick.id}_${startMs}`);
  const lockIds = allLockIds({ clinicScope: clinicId, professionalId, roomId: (a.roomId as string) ?? null, startMs, durationMinutes: duration });
  try {
    await db().runTransaction(async (tx) => {
      const e = await tx.get(entryRef);
      if (e.get("status") !== "waiting") throw new HttpsError("aborted", "fila mudou");
      const refs = await readLockConflicts(tx, lockIds, {}, nowMs);
      const prof = await tx.get(professionalRangeQuery(professionalId, startMs, startMs + duration * MIN));
      if (blockingIntervals(prof.docs, null).some((b) => b.start < startMs + duration * MIN && startMs < b.end)) throw slotTaken();
      const { data, hora } = fmtDate(startMs);
      const prazo = fmtDate(holdUntilMs);
      await enqueueMessages([{
        key: `wlo_${pick.id}_${startMs}`, kind: "waitlistOffer", recipientUid: String(e.get("patientId")), clinicId,
        sendAtMs: nowMs, vars: { data, hora, profissional: String(a.professionalName ?? ""), prazo: `${prazo.data} ${prazo.hora}` },
      }], tx);
      tx.set(holdRef, {
        clinicId, professionalId, entryId: pick.id, status: "active",
        startMs, endMs: startMs + duration * MIN, durationMinutes: duration,
        roomId: (a.roomId as string) ?? null, appointmentType: e.get("appointmentType") ?? "presencial",
        holdUntil: Timestamp.fromMillis(holdUntilMs), lockIds, createdAt: FieldValue.serverTimestamp(),
      });
      writeLocks(tx, refs, { holdId: holdRef.id, version: 0, holdUntilMs }, clinicId);
      tx.update(entryRef, {
        status: "offered",
        offer: { holdId: holdRef.id, startsAt: Timestamp.fromMillis(startMs), durationMinutes: duration, holdUntil: Timestamp.fromMillis(holdUntilMs) },
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    if (e instanceof HttpsError) return null;
    throw e;
  }
  return holdRef.id;
}

/** Família aceita ou recusa o convite; aceitar cria a consulta usando a reserva. */
export const respondWaitlistOffer = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = id(d.clinicId);
  const entryId = id(d.entryId);
  if (!clinicId || !entryId) throw new HttpsError("invalid-argument", "Convite inválido.");
  const entryRef = db().collection("clinics").doc(clinicId).collection("waitlist").doc(entryId);
  const e = (await entryRef.get()).data();
  if (!e || e.patientId !== uid) throw new HttpsError("not-found", "Convite não encontrado.");
  if (e.status !== "offered" || !e.offer) throw new HttpsError("failed-precondition", "Este convite não está mais disponível.");
  const holdRef = db().collection("schedule_holds").doc(String(e.offer.holdId));
  const hold = (await holdRef.get()).data();
  const nowMs = Date.now();
  if (!hold || hold.status !== "active" || (hold.holdUntil as Timestamp).toMillis() <= nowMs) {
    await expireOffer(clinicId, entryId, holdRef.id);
    throw new HttpsError("deadline-exceeded", "O prazo para responder terminou.");
  }
  if (d.accept !== true) {
    await expireOffer(clinicId, entryId, holdRef.id, "declined");
    await offerFreedSlot({ id: holdRef.id, clinicId, professionalId: hold.professionalId, durationMinutes: hold.durationMinutes, roomId: hold.roomId }, Number(hold.startMs)).catch(() => null);
    return { ok: true, booked: false };
  }
  const { policy } = await loadSchedulingConfig(clinicId);
  const apptId = await reserveAppointment({
    clinicId, professionalId: String(e.professionalId), startMs: Number(hold.startMs),
    type: String(hold.appointmentType ?? "presencial"), serviceId: null,
    roomId: (hold.roomId as string) ?? null, roomLabel: null, equipmentIds: [],
    patientId: uid, childId: String(e.childId), childName: (e.childName as string) ?? null,
    reason: null, status: policy.familyBookingStatus === "requested" ? "awaitingConfirmation" : policy.familyBookingStatus,
    origin: "waitlist", createdBy: uid, enforceLead: false, holdId: holdRef.id,
  });
  const batch = db().batch();
  batch.update(entryRef, { status: "booked", appointmentId: apptId, updatedAt: FieldValue.serverTimestamp() });
  batch.update(holdRef, { status: "used", appointmentId: apptId });
  await batch.commit();
  return { ok: true, booked: true, appointmentId: apptId };
});

/** Encerra o convite (vencido ou recusado) e libera as travas da reserva. */
async function expireOffer(clinicId: string, entryId: string, holdId: string, status: "expired" | "declined" = "expired") {
  const holdRef = db().collection("schedule_holds").doc(holdId);
  const hold = (await holdRef.get()).data();
  const batch = db().batch();
  batch.update(db().collection("clinics").doc(clinicId).collection("waitlist").doc(entryId), {
    status,
    offer: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (hold && hold.status === "active") {
    batch.update(holdRef, { status });
    for (const l of (hold.lockIds as string[]) ?? []) {
      const lock = await lockRef(l).get();
      if (lock.get("holdId") === holdId) batch.delete(lockRef(l));
    }
  }
  await batch.commit();
}

/** Vence convites sem resposta e oferece a vaga ao próximo. */
export const expireWaitlistOffers = onSchedule(
  { region: REGION, schedule: "every 15 minutes", timeZone: "America/Sao_Paulo" },
  async () => {
    const nowMs = Date.now();
    const snap = await db().collection("schedule_holds")
      .where("status", "==", "active")
      .where("holdUntil", "<=", Timestamp.fromMillis(nowMs)).limit(100).get();
    for (const h of snap.docs) {
      const clinicId = String(h.get("clinicId"));
      await expireOffer(clinicId, String(h.get("entryId")), h.id);
      if (Number(h.get("startMs")) > nowMs + 30 * MIN) {
        await offerFreedSlot({
          id: h.id, clinicId, professionalId: h.get("professionalId"), durationMinutes: h.get("durationMinutes"),
          roomId: h.get("roomId"),
        }, Number(h.get("startMs"))).catch(() => null);
      }
    }
    logger.info("convites vencidos", { total: snap.size });
  }
);

// ------------------------------------------------------------------ Configuração (gestão)

async function requireClinicAdmin(clinicId: string | null, uid: string) {
  if (!clinicId || (await clinicRoleOf(clinicId, uid)) !== "clinicAdmin") {
    throw new HttpsError("permission-denied", "Somente a gestão da clínica.");
  }
}

export const saveSchedulingSettings = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = id(d.clinicId);
  await requireClinicAdmin(clinicId, uid);
  const policy = normalizePolicy(d.policy);
  const typeDurations: Record<string, number> = {};
  for (const t of APPOINTMENT_TYPES) {
    const v = (d.typeDurations as Record<string, unknown> | undefined)?.[t];
    if (Number.isInteger(v) && (v as number) >= 10 && (v as number) <= 240 && (v as number) % 5 === 0) typeDurations[t] = v as number;
  }
  await db().collection("clinics").doc(clinicId!).collection("settings").doc("scheduling").set({
    policy, typeDurations, updatedBy: uid, updatedAt: FieldValue.serverTimestamp(),
  });
  return { policy, typeDurations };
});

export const saveProfessionalSchedule = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = id(d.clinicId);
  const professionalId = id(d.professionalId);
  await requireClinicAdmin(clinicId, uid);
  if (!professionalId || !(await professionalAvailable(clinicId, professionalId))) {
    throw new HttpsError("failed-precondition", "Profissional não vinculado a esta clínica.");
  }
  const toStrings = (w: WeeklyHours) => Object.fromEntries(Object.entries(w).map(([k, rs]) => [k, (rs ?? []).map((r) =>
    `${String(Math.floor(r.start / 60)).padStart(2, "0")}:${String(r.start % 60).padStart(2, "0")}-${String(Math.floor(r.end / 60)).padStart(2, "0")}:${String(r.end % 60).padStart(2, "0")}`)]));
  const vacations = (Array.isArray(d.vacations) ? d.vacations : []).map(isoInterval)
    .filter((i): i is Interval => i !== null).slice(0, 50)
    .map((i) => ({ startsAt: new Date(i.start).toISOString(), endsAt: new Date(i.end).toISOString() }));
  const doc = {
    hours: toStrings(parseWeeklyHours(d.hours)),
    breaks: toStrings(parseWeeklyHours(d.breaks)),
    vacations,
    unitId: id(d.unitId),
    active: d.active !== false,
    updatedBy: uid,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await db().collection("clinics").doc(clinicId!).collection("professional_schedules").doc(professionalId).set(doc);
  return { ok: true, hours: doc.hours, breaks: doc.breaks, vacations };
});
