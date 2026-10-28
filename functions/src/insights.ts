/**
 * Central de IA da gestão e operações do assistente.
 *
 * - Indicadores determinísticos (agenda, CRM, financeiro) com período,
 *   filtros e fonte em toda resposta; dados agregados por padrão.
 * - Pergunta livre só aciona intenções da lista (insightsCore); texto do
 *   usuário nunca vira consulta ao banco nem instrução de permissão.
 * - Ser gestor não abre prontuário: nada aqui lê conteúdo clínico.
 * - Assistente de agenda: propõe (proposta com validade) e só executa quando
 *   o usuário confirma, revalidando o horário na transação.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { clinicRoleOf } from "./clinicFlow";
import { CARE_ROLES } from "./intake";
import { financeSummary } from "./finance";
import { brl, classifyIntent, FINANCIAL_INTENTS, Intent, parsePeriod, Period, SUPPORTED_QUESTIONS } from "./insightsCore";
import { computeSlots, parseWeeklyHours, NON_BLOCKING_STATUSES } from "./schedulingCore";
import { loadSchedulingConfig, performReschedule, performStatusChange, reserveAppointment, scheduleActorFor } from "./scheduling";
import { consumeOrThrow } from "./usage";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const DAY = 86_400_000;

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

interface Filters {
  professionalId: string | null;
  unitId: string | null;
}

async function agendaStats(clinicId: string, period: Period, f: Filters) {
  const snap = await db().collection("appointments").where("clinicId", "==", clinicId)
    .where("startsAt", ">=", Timestamp.fromMillis(period.fromMs)).where("startsAt", "<", Timestamp.fromMillis(period.toMs)).limit(5000).get();
  const rows = snap.docs.map((d) => d.data()).filter((a) => (!f.professionalId || a.professionalId === f.professionalId) && (!f.unitId || a.unitId === f.unitId));
  const byStatus: Record<string, number> = {};
  for (const a of rows) byStatus[String(a.status)] = (byStatus[String(a.status)] ?? 0) + 1;
  const past = rows.filter((a) => (a.startsAt as Timestamp).toMillis() < Date.now());
  const noShow = byStatus.noShow ?? 0;
  const attendedOrMissed = noShow + (byStatus.completed ?? 0);
  return {
    total: rows.length,
    byStatus,
    noShow,
    cancelled: byStatus.cancelled ?? 0,
    completed: byStatus.completed ?? 0,
    noShowRate: attendedOrMissed ? Math.round((noShow / attendedOrMissed) * 1000) / 10 : null,
    pastWithoutOutcome: past.filter((a) => ["requested", "awaitingConfirmation", "confirmed"].includes(String(a.status))).length,
    truncated: snap.size >= 5000,
  };
}

async function pendingReturns(clinicId: string, f: Filters, detail: boolean) {
  const now = Date.now();
  const snap = await db().collection("clinics").doc(clinicId).collection("crm_contacts").limit(5000).get();
  const rows = snap.docs.map((d) => d.data()).filter((c) => !c.mergedInto && c.flags?.returnPending && (!f.unitId || c.unitId === f.unitId) && (!f.professionalId || c.lastProfessionalId === f.professionalId));
  const overdue = rows.filter((c) => (c.expectedReturnAt as Timestamp | null)?.toMillis() ?? 0 < now);
  return {
    count: rows.length,
    overdue: overdue.length,
    items: detail ? rows.slice(0, 20).map((c) => ({
      child: String(c.childName ?? "").split(" ")[0] || "(sem nome)",
      expectedReturnAt: (c.expectedReturnAt as Timestamp | null)?.toDate().toISOString() ?? null,
    })) : undefined,
  };
}

async function availableSlotsNext7(clinicId: string, f: Filters) {
  const members = await db().collection("clinics").doc(clinicId).collection("memberships").where("active", "==", true).limit(200).get();
  const profs = members.docs.map((m) => m.data()).filter((m) => CARE_ROLES.includes(String(m.role)) && (!f.professionalId || m.userId === f.professionalId));
  const { policy, typeDurations } = await loadSchedulingConfig(clinicId);
  const now = Date.now();
  const out: Array<{ professionalId: string; name: string | null; freeSlots: number; firstSlot: string | null }> = [];
  for (const p of profs.slice(0, 30)) {
    const sched = (await db().collection("clinics").doc(clinicId).collection("professional_schedules").doc(String(p.userId)).get()).data();
    if (!sched || sched.active === false) continue;
    const appts = await db().collection("appointments").where("professionalId", "==", p.userId)
      .where("startsAt", ">=", Timestamp.fromMillis(now - 4 * 3_600_000)).where("startsAt", "<", Timestamp.fromMillis(now + 8 * DAY)).get();
    const busy = appts.docs.filter((a) => !NON_BLOCKING_STATUSES.has(String(a.get("status")))).map((a) => {
      const s = (a.get("startsAt") as Timestamp).toMillis();
      return { start: s, end: s + Number(a.get("durationMinutes") ?? 30) * 60_000 };
    });
    const slots = computeSlots({
      hours: parseWeeklyHours(sched.hours), breaks: parseWeeklyHours(sched.breaks), unavailable: busy,
      durationMinutes: Number((typeDurations ?? {}).presencial ?? 30) || 30, stepMinutes: policy.slotStepMinutes,
      fromMs: now, days: 7, nowMs: now, minLeadMinutes: 0, maxDaysAhead: policy.maxDaysAhead,
    });
    out.push({ professionalId: String(p.userId), name: (p.displayName as string) ?? null, freeSlots: slots.length, firstSlot: slots[0] ? new Date(slots[0]).toISOString() : null });
  }
  return { professionals: out, withoutSchedule: profs.length - out.length };
}

async function crmCounts(clinicId: string, f: Filters) {
  const snap = await db().collection("clinics").doc(clinicId).collection("crm_contacts").limit(5000).get();
  const rows = snap.docs.map((d) => d.data()).filter((c) => !c.mergedInto && (!f.unitId || c.unitId === f.unitId));
  return { frequent: rows.filter((c) => c.flags?.frequent).length, inactive: rows.filter((c) => c.flags?.inactive).length, total: rows.length };
}

async function requireInsightRole(clinicId: unknown, uid: string): Promise<{ clinicId: string; role: string; financial: boolean }> {
  if (typeof clinicId !== "string" || !clinicId) throw new HttpsError("invalid-argument", "Clínica inválida.");
  const role = await clinicRoleOf(clinicId, uid);
  if (role !== "clinicAdmin" && role !== "finance") throw new HttpsError("permission-denied", "A Central de IA é restrita à gestão autorizada.");
  return { clinicId, role, financial: true };
}

function filtersOf(d: Record<string, unknown>): Filters {
  return {
    professionalId: typeof d.professionalId === "string" && d.professionalId ? d.professionalId : null,
    unitId: typeof d.unitId === "string" && d.unitId ? d.unitId : null,
  };
}

function suggestions(agenda: Awaited<ReturnType<typeof agendaStats>>, returns: { count: number }): string[] {
  const s: string[] = [];
  if (agenda.noShowRate != null && agenda.noShowRate >= 10) s.push(`Taxa de faltas em ${agenda.noShowRate}%: avalie ativar a confirmação 24 h antes e o acompanhamento de faltas.`);
  if (agenda.pastWithoutOutcome > 0) s.push(`${agenda.pastWithoutOutcome} consulta(s) passada(s) sem desfecho registrado (concluída/falta).`);
  if (returns.count > 0) s.push(`${returns.count} retorno(s) pendente(s): considere ativar o lembrete de retorno.`);
  if (!s.length) s.push("Sem alertas automáticos para o período.");
  return s;
}

/** Painel da Central de IA: tudo determinístico, com fonte e período. */
export const getManagementInsights = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const { clinicId, role } = await requireInsightRole(d.clinicId, uid);
  const now = Date.now();
  const period = typeof d.from === "string" && typeof d.to === "string"
    ? { fromMs: Date.parse(d.from), toMs: Date.parse(d.to), label: "período informado" }
    : parsePeriod("este mês", now);
  if (!Number.isFinite(period.fromMs) || !Number.isFinite(period.toMs) || period.toMs <= period.fromMs) throw new HttpsError("invalid-argument", "Período inválido.");
  const f = filtersOf(d);
  const agenda = role === "clinicAdmin" ? await agendaStats(clinicId, period, f) : null;
  const returns = role === "clinicAdmin" ? await pendingReturns(clinicId, f, false) : null;
  const crm = role === "clinicAdmin" ? await crmCounts(clinicId, f) : null;
  const finance = await financeSummary(clinicId, period.fromMs, period.toMs, f);
  return {
    period: { from: new Date(period.fromMs).toISOString(), to: new Date(period.toMs).toISOString(), label: period.label },
    filters: f,
    agenda: agenda ? { ...agenda, source: "appointments" } : { unavailable: "sem permissão de agenda" },
    returns: returns ? { ...returns, source: "crm_contacts" } : { unavailable: "sem permissão" },
    crm: crm ? { ...crm, source: "crm_contacts" } : { unavailable: "sem permissão" },
    finance: { ...finance, source: "finance_receipts, finance_receivables, finance_payables" },
    suggestions: agenda && returns ? suggestions(agenda, returns) : [],
    note: "Dados agregados. Nenhum conteúdo clínico é usado.",
  };
});

/** Chat da gestão: intenção da lista → operação específica → resposta com fonte. */
export const askManagementAssistant = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const { clinicId, role } = await requireInsightRole(d.clinicId, uid);
  const question = typeof d.question === "string" ? d.question.slice(0, 500) : "";
  if (!question.trim()) throw new HttpsError("invalid-argument", "Escreva a pergunta.");
  await consumeOrThrow(clinicId, uid, "aiRequests", 1, `ask_${uid}_${typeof d.requestId === "string" ? d.requestId.slice(0, 60) : Date.now()}`);
  const intent: Intent | null = classifyIntent(question);
  const period = parsePeriod(question, Date.now());
  const f = filtersOf(d);
  const meta = { period: { from: new Date(period.fromMs).toISOString(), to: new Date(period.toMs).toISOString(), label: period.label }, filters: f };
  if (!intent) {
    return { ...meta, intent: null, answer: "Não consigo responder essa pergunta com os dados disponíveis. Perguntas suportadas:", supported: SUPPORTED_QUESTIONS, source: null, sufficient: false };
  }
  if (!FINANCIAL_INTENTS.has(intent) && role !== "clinicAdmin") {
    return { ...meta, intent, answer: "Seu perfil tem acesso apenas a indicadores financeiros.", source: null, sufficient: false };
  }
  let answer = "";
  let source = "";
  let sufficient = true;
  let data: unknown = null;
  switch (intent) {
    case "noShowCount":
    case "cancellationCount":
    case "appointmentSummary": {
      const a = await agendaStats(clinicId, period, f);
      data = a;
      source = "appointments (status por consulta)";
      if (a.total === 0) {
        sufficient = false;
        answer = `Não há consultas registradas em ${period.label} com esses filtros.`;
      } else if (intent === "noShowCount") {
        answer = `${a.noShow} falta(s) em ${period.label}, de ${a.total} consulta(s) na agenda${a.noShowRate != null ? ` (taxa ${a.noShowRate}% entre concluídas e faltas)` : ""}.` +
          (a.pastWithoutOutcome ? ` Atenção: ${a.pastWithoutOutcome} consulta(s) passada(s) ainda sem desfecho registrado — o número de faltas pode estar subestimado.` : "");
      } else if (intent === "cancellationCount") {
        answer = `${a.cancelled} cancelamento(s) em ${period.label}, de ${a.total} consulta(s).`;
      } else {
        answer = `${a.total} consulta(s) em ${period.label}: ${Object.entries(a.byStatus).map(([k, v]) => `${k} ${v}`).join(", ")}.`;
      }
      if (a.truncated) answer += " (Resultado parcial: limite de 5.000 registros.)";
      break;
    }
    case "pendingReturns": {
      const r = await pendingReturns(clinicId, f, true);
      data = r;
      source = "crm_contacts (retorno previsto x próximas consultas)";
      answer = r.count ? `${r.count} retorno(s) pendente(s), ${r.overdue} já vencido(s).` : "Nenhum retorno pendente encontrado (depende de consultas concluídas com retorno previsto).";
      sufficient = r.count > 0;
      break;
    }
    case "availableSlots": {
      const s = await availableSlotsNext7(clinicId, f);
      data = s;
      source = "professional_schedules + appointments (próximos 7 dias)";
      answer = s.professionals.length
        ? s.professionals.map((p) => `${p.name ?? p.professionalId}: ${p.freeSlots} horário(s) livre(s)`).join("; ") + "."
        : "Nenhum profissional com grade de horários configurada.";
      if (s.withoutSchedule) answer += ` ${s.withoutSchedule} profissional(is) sem grade configurada não entraram na conta.`;
      sufficient = s.professionals.length > 0;
      break;
    }
    case "frequentPatients":
    case "inactivePatients": {
      const c = await crmCounts(clinicId, f);
      data = c;
      source = "crm_contacts (critérios configuráveis do CRM)";
      answer = intent === "frequentPatients" ? `${c.frequent} paciente(s) frequente(s) de ${c.total} no CRM.` : `${c.inactive} paciente(s) inativo(s) de ${c.total} no CRM.`;
      sufficient = c.total > 0;
      break;
    }
    case "receivedAmount":
    case "pendingAmount":
    case "revenueVsExpenses": {
      const s = await financeSummary(clinicId, period.fromMs, period.toMs, f);
      data = s;
      source = "finance_receipts, finance_receivables, finance_payables, finance_operations";
      if (intent === "receivedAmount") {
        answer = `Recebido em ${period.label}: ${brl(s.receivedCents)} (${s.counts.receipts} lançamento(s))` +
          (Object.keys(s.byMethod).length ? `; por forma: ${Object.entries(s.byMethod).map(([k, v]) => `${k} ${brl(v)}`).join(", ")}` : "") +
          (s.refundedCents ? `; estornos ${brl(s.refundedCents)}` : "") + ".";
        sufficient = s.counts.receipts > 0;
      } else if (intent === "pendingAmount") {
        answer = `Pendente de recebimento (vencimentos em ${period.label}): ${brl(s.pendingCents)}, sendo ${brl(s.overdueCents)} vencido(s). Previsto: ${brl(s.forecastCents)}.`;
        sufficient = s.counts.receivables > 0;
      } else {
        answer = `Em ${period.label}: recebido ${brl(s.receivedCents)}, estornos ${brl(s.refundedCents)}, despesas pagas ${brl(s.expensesPaidCents)}; saldo de caixa ${brl(s.netCashCents)}.`;
        sufficient = s.counts.receipts + s.counts.payables > 0;
      }
      if (!sufficient) answer += " Não há lançamentos suficientes no período para uma conclusão.";
      break;
    }
  }
  await db().collection("clinics").doc(clinicId).collection("ai_hub_log").add({ uid, intent, period: meta.period, filters: f, at: FieldValue.serverTimestamp() });
  return { ...meta, intent, answer, source, sufficient, data };
});

// ------------------------------------------------------------------ Assistente: propostas com confirmação

const PROPOSAL_TTL_MS = 10 * 60_000;

/**
 * Prepara (não executa) uma ação de agenda: reserva, remarcação ou
 * cancelamento. A tela mostra o resumo e chama `confirmAssistantProposal`.
 */
export const prepareAssistantProposal = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const action = String(d.action ?? "");
  if (!["book", "reschedule", "cancel"].includes(action)) throw new HttpsError("invalid-argument", "Ação não suportada.");
  const payload: Record<string, unknown> = {};
  let summary = "";
  if (action === "book") {
    for (const k of ["professionalId", "startsAt", "childId", "clinicId", "appointmentType"]) {
      if (typeof d[k] === "string") payload[k] = d[k];
    }
    if (!payload.professionalId || !payload.startsAt || !payload.childId) throw new HttpsError("invalid-argument", "Dados incompletos.");
    const owner = (await db().collection("child_registry").doc(String(payload.childId)).get()).get("ownerUid");
    if (owner !== uid) throw new HttpsError("permission-denied", "Criança não encontrada.");
    summary = `Solicitar consulta em ${new Date(String(payload.startsAt)).toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}.`;
  } else {
    const apptId = typeof d.appointmentId === "string" ? d.appointmentId : "";
    const a = (await db().collection("appointments").doc(apptId).get()).data();
    if (!a || !(await scheduleActorFor(a, uid))) throw new HttpsError("not-found", "Consulta não encontrada.");
    payload.appointmentId = apptId;
    payload.scheduleVersion = Number(a.scheduleVersion ?? 0);
    if (action === "reschedule") {
      if (typeof d.startsAt !== "string") throw new HttpsError("invalid-argument", "Informe o novo horário.");
      payload.startsAt = d.startsAt;
      summary = `Remarcar para ${new Date(d.startsAt).toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}.`;
    } else {
      payload.reason = typeof d.reason === "string" ? d.reason.slice(0, 300) : null;
      summary = "Cancelar a consulta.";
    }
  }
  const ref = await db().collection("assistant_proposals").add({
    uid, action, payload, summary, status: "pending", expiresAt: Timestamp.fromMillis(Date.now() + PROPOSAL_TTL_MS), createdAt: FieldValue.serverTimestamp(),
  });
  return { proposalId: ref.id, summary, expiresInSeconds: PROPOSAL_TTL_MS / 1000, requiresConfirmation: true };
});

/** Executa a proposta confirmada, uma única vez, revalidando tudo. */
export const confirmAssistantProposal = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const ref = db().collection("assistant_proposals").doc(String((request.data ?? {}).proposalId ?? "-"));
  const claimed = await db().runTransaction(async (tx) => {
    const p = await tx.get(ref);
    if (!p.exists || p.get("uid") !== uid) throw new HttpsError("not-found", "Proposta não encontrada.");
    if (p.get("status") !== "pending") throw new HttpsError("failed-precondition", "Proposta já usada.");
    if ((p.get("expiresAt") as Timestamp).toMillis() < Date.now()) throw new HttpsError("deadline-exceeded", "Proposta expirada. Peça de novo.");
    tx.update(ref, { status: "executing", confirmedAt: FieldValue.serverTimestamp() });
    return p.data()!;
  });
  try {
    const payload = claimed.payload as Record<string, string>;
    let result: Record<string, unknown> = {};
    if (claimed.action === "book") {
      const clinicId = payload.clinicId ?? null;
      const { policy } = await loadSchedulingConfig(clinicId);
      const child = (await db().collection("users").doc(uid).collection("children").doc(payload.childId).get()).data();
      const prof = (await db().collection("users").doc(payload.professionalId).get()).data();
      if (!clinicId && prof?.professionalVerified !== true) throw new HttpsError("not-found", "Profissional não disponível.");
      if (clinicId) {
        const role = await clinicRoleOf(clinicId, payload.professionalId);
        if (!role || !CARE_ROLES.includes(role)) throw new HttpsError("not-found", "Profissional não disponível.");
      }
      result.appointmentId = await reserveAppointment({
        clinicId, professionalId: payload.professionalId, startMs: Date.parse(payload.startsAt), type: payload.appointmentType ?? "presencial",
        serviceId: null, roomId: null, roomLabel: null, equipmentIds: [], patientId: uid, childId: payload.childId,
        childName: (child?.name as string) ?? null, reason: null, status: policy.familyBookingStatus, origin: "familyBooking",
        createdBy: uid, enforceLead: true, fallbackPriceCents: Number(prof?.consultationPriceCents ?? 0),
      });
    } else {
      const a = (await db().collection("appointments").doc(payload.appointmentId).get()).data();
      if (!a || Number(a.scheduleVersion ?? 0) !== Number(claimed.payload.scheduleVersion)) {
        throw new HttpsError("aborted", "A consulta mudou desde a proposta. Peça de novo.");
      }
      result = claimed.action === "reschedule"
        ? await performReschedule(uid, { appointmentId: payload.appointmentId, startsAt: payload.startsAt, reason: "via assistente" })
        : await performStatusChange(uid, { appointmentId: payload.appointmentId, status: "cancelled", reason: payload.reason ?? "cancelado via assistente" });
    }
    await ref.update({ status: "done", result });
    return { ok: true, ...result };
  } catch (e) {
    await ref.update({ status: "failed", error: e instanceof HttpsError ? e.message : "erro" });
    throw e;
  }
});
