/**
 * Anamnese e pré-consulta (Firestore). Regras puras em anamnesisCore.ts.
 *
 * - Modelos versionados: salvar cria nova versão; respostas guardam a versão
 *   usada. Versões antigas não mudam.
 * - Resposta enviada é imutável. Atualizar depois cria nova resposta que
 *   aponta para a anterior (`supersedes`).
 * - Só a família (titular) responde; só o profissional da consulta lê o que
 *   foi enviado para aquela consulta. Recepção e gestão não leem.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { clinicRoleOf } from "./clinicFlow";
import { CARE_ROLES } from "./intake";
import {
  AnamnesisTemplate,
  missingRequired,
  parseTemplate,
  pickTemplate,
  preliminarySummary,
  reuseSuggestions,
  sanitizeAnswers,
  SYSTEM_TEMPLATES,
  TemplateError,
} from "./anamnesisCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const OPEN_STATUSES = ["requested", "awaitingConfirmation", "confirmed"];

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

function safeId(v: unknown): string | null {
  return typeof v === "string" && v && v.length <= 128 && !v.includes("/") ? v : null;
}

interface TemplateRef {
  scope: "system" | "clinic";
  clinicId: string | null;
  templateId: string;
  version: number;
}

type LoadedTemplate = AnamnesisTemplate & { ref: TemplateRef; ownerProfessionalId?: string | null };

async function loadTemplate(ref: TemplateRef): Promise<LoadedTemplate | null> {
  if (ref.scope === "system") {
    const s = SYSTEM_TEMPLATES.find((x) => x.id === ref.templateId);
    return s ? { ...s, ref: { ...ref, version: 1 } } : null;
  }
  if (!ref.clinicId) return null;
  const base = db().collection("clinics").doc(ref.clinicId).collection("anamnesis_templates").doc(ref.templateId);
  const head = (await base.get()).data();
  if (!head) return null;
  const v = (await base.collection("versions").doc(String(ref.version)).get()).data();
  if (!v) return null;
  return {
    id: ref.templateId, name: v.name, specialty: v.specialty, ageMinMonths: v.ageMinMonths, ageMaxMonths: v.ageMaxMonths,
    sections: v.sections, ref, ownerProfessionalId: head.ownerProfessionalId ?? null,
  };
}

async function clinicTemplates(clinicId: string): Promise<Array<{ id: string; currentVersion: number; specialty: string; ageMinMonths: number; ageMaxMonths: number; name: string; scope: string; ownerProfessionalId: string | null }>> {
  const snap = await db().collection("clinics").doc(clinicId).collection("anamnesis_templates").where("active", "==", true).limit(100).get();
  return snap.docs.map((d) => ({
    id: d.id, currentVersion: Number(d.get("currentVersion") ?? 1), specialty: String(d.get("specialty")),
    ageMinMonths: Number(d.get("ageMinMonths") ?? 0), ageMaxMonths: Number(d.get("ageMaxMonths") ?? 216),
    name: String(d.get("name")), scope: String(d.get("scope") ?? "clinic"), ownerProfessionalId: (d.get("ownerProfessionalId") as string) ?? null,
  }));
}

export const listAnamnesisTemplates = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = safeId(d.clinicId);
  const out: Array<Record<string, unknown>> = SYSTEM_TEMPLATES.map((s) => ({
    scope: "system", templateId: s.id, version: 1, name: s.name, specialty: s.specialty, ageMinMonths: s.ageMinMonths, ageMaxMonths: s.ageMaxMonths,
  }));
  if (clinicId && (await clinicRoleOf(clinicId, uid))) {
    for (const t of await clinicTemplates(clinicId)) {
      out.push({ scope: "clinic", clinicId, templateId: t.id, version: t.currentVersion, name: t.name, specialty: t.specialty, ageMinMonths: t.ageMinMonths, ageMaxMonths: t.ageMaxMonths, owner: t.scope === "professional" ? t.ownerProfessionalId : "clinic" });
    }
  }
  return { templates: out };
});

/** Cria/atualiza modelo da clínica (gestão) ou do próprio profissional. */
export const saveAnamnesisTemplate = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = safeId(d.clinicId);
  if (!clinicId) throw new HttpsError("invalid-argument", "Clínica inválida.");
  const role = await clinicRoleOf(clinicId, uid);
  const scope = d.scope === "professional" ? "professional" : "clinic";
  if (scope === "clinic" && role !== "clinicAdmin") throw new HttpsError("permission-denied", "Somente a gestão cria modelos da clínica.");
  if (scope === "professional" && (!role || !CARE_ROLES.includes(role))) throw new HttpsError("permission-denied", "Somente profissionais da clínica.");
  let parsed;
  try {
    parsed = parseTemplate(d);
  } catch (e) {
    if (e instanceof TemplateError) throw new HttpsError("invalid-argument", e.message);
    throw e;
  }
  const col = db().collection("clinics").doc(clinicId).collection("anamnesis_templates");
  const existingId = safeId(d.templateId);
  const ref = existingId ? col.doc(existingId) : col.doc();
  const version = await db().runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.exists) {
      const c = cur.data() ?? {};
      if (c.scope === "professional" && c.ownerProfessionalId !== uid) throw new HttpsError("permission-denied", "Modelo de outro profissional.");
      if (c.scope === "clinic" && role !== "clinicAdmin") throw new HttpsError("permission-denied", "Somente a gestão.");
    } else if (existingId) {
      throw new HttpsError("not-found", "Modelo não encontrado.");
    }
    const next = Number(cur.get("currentVersion") ?? 0) + 1;
    tx.set(ref.collection("versions").doc(String(next)), { ...parsed, createdBy: uid, createdAt: FieldValue.serverTimestamp() });
    tx.set(ref, {
      name: parsed.name, specialty: parsed.specialty, ageMinMonths: parsed.ageMinMonths, ageMaxMonths: parsed.ageMaxMonths,
      scope, ownerProfessionalId: scope === "professional" ? uid : null, currentVersion: next,
      active: d.active !== false, updatedBy: uid, updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return next;
  });
  return { templateId: ref.id, version };
});

function ageMonths(birth: unknown, nowMs: number): number | null {
  const ms = birth instanceof Timestamp ? birth.toMillis() : typeof birth === "string" ? Date.parse(birth) : NaN;
  if (!Number.isFinite(ms)) return null;
  return Math.max(0, Math.floor((nowMs - ms) / (30.44 * 86_400_000)));
}

async function chooseTemplate(appt: Record<string, unknown>, requested: Record<string, unknown> | null, ageM: number | null): Promise<LoadedTemplate> {
  const clinicId = (appt.clinicId as string) ?? null;
  if (requested) {
    const scope = requested.scope === "clinic" ? "clinic" : "system";
    const templateId = safeId(requested.templateId);
    if (!templateId) throw new HttpsError("invalid-argument", "Modelo inválido.");
    if (scope === "clinic") {
      if (!clinicId) throw new HttpsError("invalid-argument", "Modelo inválido.");
      const head = (await db().collection("clinics").doc(clinicId).collection("anamnesis_templates").doc(templateId).get()).data();
      if (!head || head.active === false) throw new HttpsError("not-found", "Modelo indisponível.");
      if (head.scope === "professional" && head.ownerProfessionalId !== appt.professionalId) throw new HttpsError("permission-denied", "Modelo de outro profissional.");
      const t = await loadTemplate({ scope, clinicId, templateId, version: Number(head.currentVersion) });
      if (t) return t;
    } else {
      const t = await loadTemplate({ scope, clinicId: null, templateId, version: 1 });
      if (t) return t;
    }
    throw new HttpsError("not-found", "Modelo indisponível.");
  }
  const specialty = String(appt.specialty ?? "pediatria").toLowerCase();
  if (clinicId) {
    const list = await clinicTemplates(clinicId);
    const own = pickTemplate(list.filter((t) => t.scope === "professional" && t.ownerProfessionalId === appt.professionalId), specialty, ageM);
    const clinic = own ?? pickTemplate(list.filter((t) => t.scope !== "professional"), specialty, ageM);
    if (clinic) {
      const t = await loadTemplate({ scope: "clinic", clinicId, templateId: clinic.id, version: clinic.currentVersion });
      if (t) return t;
    }
  }
  const sys = pickTemplate(SYSTEM_TEMPLATES, specialty, ageM) ?? SYSTEM_TEMPLATES[0];
  return { ...sys, ref: { scope: "system", clinicId: null, templateId: sys.id, version: 1 } };
}

async function lastSubmittedForChild(ownerUid: string, childId: string, excludeId?: string) {
  const snap = await db().collection("anamnesis_responses")
    .where("ownerUid", "==", ownerUid).where("childId", "==", childId)
    .where("status", "in", ["submitted", "reviewed"]).orderBy("submittedAt", "desc").limit(3).get();
  const d = snap.docs.find((x) => x.id !== excludeId);
  if (!d) return null;
  return { id: d.id, submittedAt: (d.get("submittedAt") as Timestamp).toDate().toISOString(), answers: (d.get("answers") ?? {}) as Record<string, unknown> };
}

/** Família abre (ou retoma) a pré-consulta de uma consulta. */
export const startAnamnesis = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const apptId = safeId(d.appointmentId);
  if (!apptId) throw new HttpsError("invalid-argument", "Consulta inválida.");
  const appt = (await db().collection("appointments").doc(apptId).get()).data();
  if (!appt || appt.patientId !== uid || !appt.childId) throw new HttpsError("not-found", "Consulta não encontrada.");
  if (!OPEN_STATUSES.includes(String(appt.status))) throw new HttpsError("failed-precondition", "A pré-consulta fica disponível só antes do atendimento.");
  const existing = await db().collection("anamnesis_responses")
    .where("ownerUid", "==", uid).where("appointmentId", "==", apptId).where("status", "==", "draft").limit(1).get();
  const child = (await db().collection("users").doc(uid).collection("children").doc(String(appt.childId)).get()).data() ?? {};
  let responseId: string;
  let tpl: LoadedTemplate;
  let answers: Record<string, unknown> = {};
  if (!existing.empty) {
    const r = existing.docs[0];
    responseId = r.id;
    tpl = (await loadTemplate(r.get("template") as TemplateRef))!;
    answers = (r.get("answers") ?? {}) as Record<string, unknown>;
  } else {
    tpl = await chooseTemplate(appt, (d.template ?? null) as Record<string, unknown> | null, ageMonths(child.birthDate, Date.now()));
    const ref = db().collection("anamnesis_responses").doc();
    responseId = ref.id;
    await ref.set({
      ownerUid: uid, childId: appt.childId, appointmentId: apptId, professionalId: appt.professionalId,
      clinicId: appt.clinicId ?? null, template: tpl.ref, status: "draft", answers: {}, reusedFields: [],
      nature: "reported", startedBy: uid, startedAt: FieldValue.serverTimestamp(), revision: 0,
    });
  }
  const reuse = reuseSuggestions(tpl, await lastSubmittedForChild(uid, String(appt.childId), responseId));
  return { responseId, template: { name: tpl.name, sections: tpl.sections, ref: tpl.ref }, answers, reuseSuggestions: reuse };
});

async function ownDraft(uid: string, responseId: unknown) {
  const id = safeId(responseId);
  if (!id) throw new HttpsError("invalid-argument", "Resposta inválida.");
  const ref = db().collection("anamnesis_responses").doc(id);
  const r = (await ref.get()).data();
  if (!r || r.ownerUid !== uid) throw new HttpsError("not-found", "Resposta não encontrada.");
  if (r.status !== "draft") throw new HttpsError("failed-precondition", "Resposta já enviada. Use 'atualizar' para criar uma nova versão.");
  const appt = (await db().collection("appointments").doc(String(r.appointmentId)).get()).data();
  if (!appt || appt.patientId !== uid || !OPEN_STATUSES.includes(String(appt.status))) {
    throw new HttpsError("failed-precondition", "A consulta não aceita mais pré-consulta.");
  }
  const tpl = await loadTemplate(r.template as TemplateRef);
  if (!tpl) throw new HttpsError("failed-precondition", "Modelo indisponível.");
  return { ref, r, tpl };
}

/** Salvamento parcial (pode retomar depois). */
export const saveAnamnesisDraft = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const { ref, r, tpl } = await ownDraft(uid, d.responseId);
  const answers = sanitizeAnswers(tpl, d.answers);
  // Reaproveitamento só conta para campos que a família confirmou e cujo
  // valor ainda é o da anamnese de origem.
  const prev = await lastSubmittedForChild(uid, String(r.childId), ref.id);
  const confirmed = Array.isArray(d.confirmedReuse) ? d.confirmedReuse.filter((x): x is string => typeof x === "string") : [];
  const reused = reuseSuggestions(tpl, prev)
    .filter((s) => confirmed.includes(s.field) && JSON.stringify(answers[s.field]) === JSON.stringify(s.value))
    .map((s) => ({ field: s.field, sourceResponseId: s.sourceResponseId, sourceSubmittedAt: s.sourceSubmittedAt }));
  await ref.update({ answers, reusedFields: reused, lastSavedAt: FieldValue.serverTimestamp(), lastSavedBy: uid });
  return { ok: true, missingRequired: missingRequired(tpl, answers) };
});

export const submitAnamnesis = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const { ref, r, tpl } = await ownDraft(uid, d.responseId);
  const answers = (r.answers ?? {}) as Record<string, unknown>;
  const missing = missingRequired(tpl, answers);
  if (missing.length) throw new HttpsError("failed-precondition", `Faltam campos obrigatórios: ${missing.join(", ")}`);
  await db().runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.get("status") !== "draft") throw new HttpsError("failed-precondition", "Resposta já enviada.");
    tx.update(ref, { status: "submitted", submittedAt: FieldValue.serverTimestamp(), submittedBy: uid, revision: 1 });
    tx.set(ref.collection("revisions").doc("1"), {
      answers, reusedFields: r.reusedFields ?? [], template: r.template, answeredBy: uid, at: FieldValue.serverTimestamp(),
    });
    if (r.supersedes) {
      tx.update(db().collection("anamnesis_responses").doc(String(r.supersedes)), { supersededBy: ref.id });
    }
  });
  return { ok: true };
});

/** Atualizar depois de enviar: nova resposta, a anterior fica intacta. */
export const amendAnamnesis = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const id = safeId((request.data ?? {}).responseId);
  if (!id) throw new HttpsError("invalid-argument", "Resposta inválida.");
  const old = (await db().collection("anamnesis_responses").doc(id).get()).data();
  if (!old || old.ownerUid !== uid) throw new HttpsError("not-found", "Resposta não encontrada.");
  if (old.status === "draft") return { responseId: id };
  const appt = (await db().collection("appointments").doc(String(old.appointmentId)).get()).data();
  if (!appt || !OPEN_STATUSES.includes(String(appt.status))) throw new HttpsError("failed-precondition", "A consulta não aceita mais alterações.");
  const draft = await db().collection("anamnesis_responses")
    .where("ownerUid", "==", uid).where("appointmentId", "==", old.appointmentId).where("status", "==", "draft").limit(1).get();
  if (!draft.empty) return { responseId: draft.docs[0].id };
  const ref = db().collection("anamnesis_responses").doc();
  await ref.set({
    ownerUid: uid, childId: old.childId, appointmentId: old.appointmentId, professionalId: old.professionalId,
    clinicId: old.clinicId ?? null, template: old.template, status: "draft", answers: old.answers ?? {},
    reusedFields: old.reusedFields ?? [], supersedes: id, nature: "reported", startedBy: uid,
    startedAt: FieldValue.serverTimestamp(), revision: 0,
  });
  return { responseId: ref.id };
});

async function requireVisitProfessional(uid: string, appt: Record<string, unknown>) {
  if (appt.professionalId !== uid) throw new HttpsError("permission-denied", "Somente o profissional da consulta.");
  const clinicId = (appt.clinicId as string) ?? null;
  if (clinicId) {
    const role = await clinicRoleOf(clinicId, uid);
    if (!role || !CARE_ROLES.includes(role)) throw new HttpsError("permission-denied", "Somente o profissional da consulta.");
  } else {
    const u = (await db().collection("users").doc(uid).get()).data();
    if (u?.professionalVerified !== true) throw new HttpsError("permission-denied", "Somente profissional verificado.");
  }
}

/** Profissional da consulta lê a pré-consulta enviada (relato da família). */
export const getAnamnesisForVisit = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const apptId = safeId((request.data ?? {}).appointmentId);
  if (!apptId) throw new HttpsError("invalid-argument", "Consulta inválida.");
  const appt = (await db().collection("appointments").doc(apptId).get()).data();
  if (!appt) throw new HttpsError("not-found", "Consulta não encontrada.");
  await requireVisitProfessional(uid, appt);
  const snap = await db().collection("anamnesis_responses")
    .where("appointmentId", "==", apptId).where("professionalId", "==", uid)
    .where("status", "in", ["submitted", "reviewed"]).orderBy("submittedAt", "desc").limit(5).get();
  const current = snap.docs.find((x) => !x.get("supersededBy")) ?? snap.docs[0];
  if (!current) return { available: false, reason: "A família ainda não enviou a pré-consulta." };
  const r = current.data();
  const tpl = await loadTemplate(r.template as TemplateRef);
  const reused = ((r.reusedFields ?? []) as Array<{ field: string }>).map((x) => x.field);
  return {
    available: true,
    responseId: current.id,
    status: r.status,
    nature: "reported",
    submittedAt: (r.submittedAt as Timestamp).toDate().toISOString(),
    answeredBy: r.submittedBy === r.ownerUid ? "responsável titular" : "outro",
    template: tpl ? { name: tpl.name, sections: tpl.sections, ref: tpl.ref } : null,
    answers: r.answers ?? {},
    reusedFields: r.reusedFields ?? [],
    review: r.reviewedAt ? { reviewedAt: (r.reviewedAt as Timestamp).toDate().toISOString(), notes: r.reviewNotes ?? null } : null,
    summary: tpl ? preliminarySummary(tpl, r.answers ?? {}, reused) : null,
    previousVersions: snap.docs.filter((x) => x.id !== current.id).map((x) => ({ responseId: x.id, submittedAt: (x.get("submittedAt") as Timestamp).toDate().toISOString() })),
  };
});

/** Revisão do profissional na consulta: anota, não altera o relato. */
export const reviewAnamnesis = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = safeId(d.responseId);
  if (!id) throw new HttpsError("invalid-argument", "Resposta inválida.");
  const ref = db().collection("anamnesis_responses").doc(id);
  const r = (await ref.get()).data();
  if (!r || r.status === "draft") throw new HttpsError("not-found", "Resposta não encontrada.");
  const appt = (await db().collection("appointments").doc(String(r.appointmentId)).get()).data();
  if (!appt) throw new HttpsError("not-found", "Consulta não encontrada.");
  await requireVisitProfessional(uid, appt);
  await ref.update({
    status: "reviewed",
    reviewedBy: uid,
    reviewedAt: FieldValue.serverTimestamp(),
    reviewNotes: typeof d.notes === "string" ? d.notes.slice(0, 4000) : null,
  });
  return { ok: true };
});
