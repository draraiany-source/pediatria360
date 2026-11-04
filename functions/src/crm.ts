/**
 * CRM administrativo da clínica.
 *
 * `clinics/{c}/crm_contacts/{titular}_{criança}` é derivado das consultas
 * (gatilho) e guarda só dados administrativos: nomes, canal preferido,
 * datas de visita, estágio, contadores. Notas são administrativas e ficam
 * separadas do prontuário. Fusão de duplicados exige revisão de um gestor e
 * mantém histórico; nada é apagado automaticamente.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { clinicRoleOf } from "./clinicFlow";
import { CRM_STAGES, deriveCrm, findDuplicates, normalizeCriteria } from "./crmCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
export const CRM_ROLES = ["clinicAdmin", "receptionist"];

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

async function requireCrm(clinicId: unknown, uid: string, roles = CRM_ROLES): Promise<string> {
  if (typeof clinicId !== "string" || !clinicId || clinicId.includes("/")) throw new HttpsError("invalid-argument", "Clínica inválida.");
  const role = await clinicRoleOf(clinicId, uid);
  if (!role || !roles.includes(role)) throw new HttpsError("permission-denied", "Sem permissão para o CRM.");
  return role;
}

const contactKey = (ownerUid: string, childId: string) => `${ownerUid}_${childId}`;

async function criteriaOf(clinicId: string) {
  const s = (await db().collection("clinics").doc(clinicId).collection("settings").doc("crm").get()).data();
  return normalizeCriteria(s?.criteria);
}

/** Recalcula o contato a partir das consultas da criança nesta clínica. */
export async function refreshCrmContact(clinicId: string, ownerUid: string, childId: string): Promise<void> {
  const appts = await db().collection("appointments")
    .where("clinicId", "==", clinicId).where("childId", "==", childId).limit(500).get();
  const mine = appts.docs.filter((a) => a.get("patientId") === ownerUid && a.get("startsAt") instanceof Timestamp);
  const nowMs = Date.now();
  const derived = deriveCrm(mine.map((a) => ({
    status: String(a.get("status")),
    startMs: (a.get("startsAt") as Timestamp).toMillis(),
    expectedReturnMs: (a.get("expectedReturnAt") as Timestamp | undefined)?.toMillis() ?? null,
  })), nowMs, await criteriaOf(clinicId));
  const latest = mine.sort((a, b) => (b.get("startsAt") as Timestamp).toMillis() - (a.get("startsAt") as Timestamp).toMillis())[0];
  const guardian = (await db().collection("users").doc(ownerUid).get()).data() ?? {};
  const prefs = (guardian.communicationPrefs ?? {}) as Record<string, unknown>;
  const ts = (ms: number | null) => (ms == null ? null : Timestamp.fromMillis(ms));
  await db().collection("clinics").doc(clinicId).collection("crm_contacts").doc(contactKey(ownerUid, childId)).set({
    ownerUid,
    childId,
    childName: latest?.get("childName") ?? null,
    guardianName: (guardian.name as string) ?? null,
    preferredChannel: prefs.preferredChannel ?? "inApp",
    whatsappOptIn: prefs.whatsappOptIn === true,
    marketingConsent: prefs.marketingConsent === true,
    unitId: latest?.get("unitId") ?? null,
    lastProfessionalId: latest?.get("professionalId") ?? null,
    stage: derived.stage,
    firstVisitAt: ts(derived.firstVisitMs),
    lastVisitAt: ts(derived.lastVisitMs),
    nextAppointmentAt: ts(derived.nextAppointmentMs),
    expectedReturnAt: ts(derived.expectedReturnMs),
    visitCount: derived.visitCount,
    noShowCount: derived.noShowCount,
    cancelCount: derived.cancelCount,
    flags: derived.flags,
    refreshedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

export const onAppointmentWrittenCrm = onDocumentWritten({ region: REGION, document: "appointments/{id}" }, async (event) => {
  const after = event.data?.after.data() ?? event.data?.before.data();
  if (!after?.clinicId || !after.childId || !after.patientId) return;
  await refreshCrmContact(String(after.clinicId), String(after.patientId), String(after.childId));
});

export const saveCrmCriteria = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid, ["clinicAdmin"]);
  const criteria = normalizeCriteria(d.criteria);
  await db().collection("clinics").doc(String(d.clinicId)).collection("settings").doc("crm").set({ criteria, updatedBy: uid, updatedAt: FieldValue.serverTimestamp() });
  return { criteria };
});

/** Ficha administrativa: contato, notas, tarefas e histórico de mensagens (sem conteúdo). */
export const getCrmContact = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const clinicId = String(d.clinicId);
  const key = String(d.contactKey ?? "");
  if (!key || key.includes("/")) throw new HttpsError("invalid-argument", "Contato inválido.");
  const ref = db().collection("clinics").doc(clinicId).collection("crm_contacts").doc(key);
  const c = (await ref.get()).data();
  if (!c) throw new HttpsError("not-found", "Contato não encontrado.");
  const [notes, tasks, msgs, appts] = await Promise.all([
    ref.collection("notes").orderBy("createdAt", "desc").limit(50).get(),
    db().collection("clinics").doc(clinicId).collection("crm_tasks").where("contactKey", "==", key).limit(50).get(),
    db().collection("message_queue").where("clinicId", "==", clinicId).where("recipientUid", "==", c.ownerUid).limit(50).get(),
    db().collection("appointments").where("clinicId", "==", clinicId).where("childId", "==", c.childId).limit(50).get(),
  ]);
  return {
    contact: { ...c, firstVisitAt: c.firstVisitAt?.toDate().toISOString() ?? null, lastVisitAt: c.lastVisitAt?.toDate().toISOString() ?? null, nextAppointmentAt: c.nextAppointmentAt?.toDate().toISOString() ?? null, expectedReturnAt: c.expectedReturnAt?.toDate().toISOString() ?? null, refreshedAt: null },
    notes: notes.docs.map((n) => ({ id: n.id, text: n.get("text"), by: n.get("createdBy"), at: (n.get("createdAt") as Timestamp | null)?.toDate().toISOString() ?? null })),
    tasks: tasks.docs.map((t) => ({ id: t.id, title: t.get("title"), status: t.get("status"), assigneeUid: t.get("assigneeUid"), dueAt: (t.get("dueAt") as Timestamp | null)?.toDate().toISOString() ?? null })),
    messages: msgs.docs.map((m) => ({ kind: m.get("kind"), channel: m.get("channel"), status: m.get("status"), sendAt: (m.get("sendAt") as Timestamp).toDate().toISOString() })),
    appointments: appts.docs.filter((a) => a.get("patientId") === c.ownerUid).map((a) => ({
      id: a.id, status: a.get("status"), startsAt: (a.get("startsAt") as Timestamp).toDate().toISOString(), professionalName: a.get("professionalName") ?? null, type: a.get("type") ?? null,
    })),
  };
});

export const addCrmNote = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const text = typeof d.text === "string" ? d.text.trim().slice(0, 1000) : "";
  if (!text) throw new HttpsError("invalid-argument", "Escreva a nota.");
  const ref = db().collection("clinics").doc(String(d.clinicId)).collection("crm_contacts").doc(String(d.contactKey ?? "-"));
  if (!(await ref.get()).exists) throw new HttpsError("not-found", "Contato não encontrado.");
  const n = await ref.collection("notes").add({ text, kind: "administrative", createdBy: uid, createdAt: FieldValue.serverTimestamp() });
  return { noteId: n.id };
});

export const saveCrmTask = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const clinicId = String(d.clinicId);
  const col = db().collection("clinics").doc(clinicId).collection("crm_tasks");
  if (typeof d.taskId === "string" && d.taskId) {
    const ref = col.doc(d.taskId);
    if (!(await ref.get()).exists) throw new HttpsError("not-found", "Tarefa não encontrada.");
    const status = ["open", "done", "cancelled"].includes(String(d.status)) ? d.status : "open";
    await ref.update({ status, updatedBy: uid, updatedAt: FieldValue.serverTimestamp() });
    return { taskId: ref.id };
  }
  const title = typeof d.title === "string" ? d.title.trim().slice(0, 200) : "";
  if (!title) throw new HttpsError("invalid-argument", "Informe o título.");
  const assignee = typeof d.assigneeUid === "string" ? d.assigneeUid : uid;
  if (!(await clinicRoleOf(clinicId, assignee))) throw new HttpsError("invalid-argument", "Responsável fora da equipe.");
  const due = Date.parse(String(d.dueAt ?? ""));
  const ref = await col.add({
    title, contactKey: typeof d.contactKey === "string" ? d.contactKey : null, assigneeUid: assignee,
    dueAt: Number.isFinite(due) ? Timestamp.fromMillis(due) : null, status: "open", createdBy: uid, createdAt: FieldValue.serverTimestamp(),
  });
  return { taskId: ref.id };
});

export const findCrmDuplicates = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const snap = await db().collection("clinics").doc(String(d.clinicId)).collection("crm_contacts").limit(1000).get();
  const list = await Promise.all(snap.docs.filter((c) => !c.get("mergedInto")).map(async (c) => {
    const child = (await db().collection("users").doc(String(c.get("ownerUid"))).collection("children").doc(String(c.get("childId"))).get()).data() ?? {};
    const prefs = ((await db().collection("users").doc(String(c.get("ownerUid"))).get()).data()?.communicationPrefs ?? {}) as Record<string, unknown>;
    const birth = child.birthDate instanceof Timestamp ? child.birthDate.toDate().toISOString().slice(0, 10) : typeof child.birthDate === "string" ? child.birthDate.slice(0, 10) : null;
    return { key: c.id, childName: String(c.get("childName") ?? child.name ?? ""), birthDate: birth, guardianPhone: (prefs.phone as string) ?? null, ownerUid: String(c.get("ownerUid")) };
  }));
  return { pairs: findDuplicates(list) };
});

export const requestCrmMerge = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const clinicId = String(d.clinicId);
  const primary = String(d.primaryKey ?? "");
  const duplicate = String(d.duplicateKey ?? "");
  if (!primary || !duplicate || primary === duplicate || primary.includes("/") || duplicate.includes("/")) throw new HttpsError("invalid-argument", "Contatos inválidos.");
  const col = db().collection("clinics").doc(clinicId).collection("crm_contacts");
  const [a, b] = await Promise.all([col.doc(primary).get(), col.doc(duplicate).get()]);
  if (!a.exists || !b.exists) throw new HttpsError("not-found", "Contato não encontrado.");
  const ref = await db().collection("clinics").doc(clinicId).collection("crm_merge_requests").add({
    primaryKey: primary, duplicateKey: duplicate, reason: typeof d.reason === "string" ? d.reason.slice(0, 300) : null,
    status: "pending", requestedBy: uid, requestedAt: FieldValue.serverTimestamp(),
  });
  return { requestId: ref.id };
});

/**
 * Gestor revisa. Aprovar marca o duplicado como fundido (`mergedInto`) e
 * registra no principal (`mergedFrom`); consultas, notas e cadastros da
 * família continuam onde estão. Contas e crianças de titulares diferentes
 * não são unidas: o CRM só deixa de listá-los separados.
 */
export const reviewCrmMerge = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid, ["clinicAdmin"]);
  const clinicId = String(d.clinicId);
  const ref = db().collection("clinics").doc(clinicId).collection("crm_merge_requests").doc(String(d.requestId ?? "-"));
  await db().runTransaction(async (tx) => {
    const r = await tx.get(ref);
    if (!r.exists || r.get("status") !== "pending") throw new HttpsError("failed-precondition", "Pedido não está pendente.");
    if (r.get("requestedBy") === uid) throw new HttpsError("permission-denied", "A revisão precisa ser feita por outra pessoa da gestão.");
    const approve = d.approve === true;
    tx.update(ref, { status: approve ? "approved" : "rejected", reviewedBy: uid, reviewedAt: FieldValue.serverTimestamp() });
    if (approve) {
      const col = db().collection("clinics").doc(clinicId).collection("crm_contacts");
      tx.update(col.doc(String(r.get("duplicateKey"))), { mergedInto: r.get("primaryKey"), mergedAt: FieldValue.serverTimestamp(), mergeRequestId: ref.id });
      tx.update(col.doc(String(r.get("primaryKey"))), { mergedFrom: FieldValue.arrayUnion(r.get("duplicateKey")) });
    }
  });
  return { ok: true };
});

/** Indicadores do CRM por período e unidade. */
export const getCrmIndicators = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  await requireCrm(d.clinicId, uid);
  const unitId = typeof d.unitId === "string" ? d.unitId : null;
  const snap = await db().collection("clinics").doc(String(d.clinicId)).collection("crm_contacts").limit(5000).get();
  const contacts = snap.docs.map((c) => c.data()).filter((c) => !c.mergedInto && (!unitId || c.unitId === unitId));
  const byStage = Object.fromEntries(CRM_STAGES.map((s) => [s, contacts.filter((c) => c.stage === s).length]));
  return {
    total: contacts.length,
    byStage,
    frequent: contacts.filter((c) => c.flags?.frequent).length,
    inactive: contacts.filter((c) => c.flags?.inactive).length,
    noShow: contacts.filter((c) => c.flags?.noShow).length,
    returnPending: contacts.filter((c) => c.flags?.returnPending).length,
    filters: { unitId },
    source: "crm_contacts (derivado das consultas)",
  };
});
