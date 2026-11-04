/**
 * Campanhas administrativas e educativas.
 *
 * Fluxo: rascunho → prévia (contagem e texto, sem nomes) → aprovação por
 * outra pessoa da gestão → agendada (jobs na fila) → enviada. A fila revalida
 * consentimento, supressão e aprovação na hora do envio. Cancelar retira os
 * envios pendentes. Atendimento nunca depende de aceitar marketing.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { clinicRoleOf } from "./clinicFlow";
import { CampaignError, eligibility, matchesSegment, validateCampaign, Contact } from "./marketingCore";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

function uidOf(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

async function requireAdmin(clinicId: unknown, uid: string): Promise<string> {
  if (typeof clinicId !== "string" || !clinicId || clinicId.includes("/")) throw new HttpsError("invalid-argument", "Clínica inválida.");
  if ((await clinicRoleOf(clinicId, uid)) !== "clinicAdmin") throw new HttpsError("permission-denied", "Somente a gestão.");
  return clinicId;
}

async function contactsOf(clinicId: string): Promise<Contact[]> {
  const snap = await db().collection("clinics").doc(clinicId).collection("crm_contacts").limit(5000).get();
  const byOwner = new Map<string, FirebaseFirestore.DocumentData>();
  for (const d of snap.docs) {
    const c = d.data();
    if (c.mergedInto) continue;
    // Um envio por responsável, mesmo com várias crianças.
    const prev = byOwner.get(String(c.ownerUid));
    if (!prev || ((c.lastVisitAt as Timestamp | null)?.toMillis() ?? 0) > ((prev.lastVisitAt as Timestamp | null)?.toMillis() ?? 0)) byOwner.set(String(c.ownerUid), c);
  }
  const out: Contact[] = [];
  for (const [ownerUid, c] of byOwner) {
    const user = (await db().collection("users").doc(ownerUid).get()).data() ?? {};
    const prefs = (user.communicationPrefs ?? {}) as Record<string, unknown>;
    const suppressed = (await db().collection("marketing_suppression").doc(ownerUid).get()).exists;
    out.push({
      ownerUid,
      stage: String(c.stage ?? "novoContato"),
      lastVisitMs: (c.lastVisitAt as Timestamp | null)?.toMillis() ?? null,
      unitId: (c.unitId as string) ?? null,
      preferredChannel: String(prefs.preferredChannel ?? "inApp"),
      marketingConsent: prefs.marketingConsent === true,
      suppressed,
      lastMarketingMs: (user.lastMarketingAt as Timestamp | undefined)?.toMillis() ?? null,
    });
  }
  return out;
}

export const saveCampaignDraft = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireAdmin(d.clinicId, uid);
  let c;
  try {
    c = validateCampaign(d);
  } catch (e) {
    if (e instanceof CampaignError) throw new HttpsError("invalid-argument", e.message);
    throw e;
  }
  const col = db().collection("clinics").doc(clinicId).collection("campaigns");
  const ref = typeof d.campaignId === "string" && d.campaignId ? col.doc(d.campaignId) : col.doc();
  await db().runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.exists && !["draft", "pendingApproval"].includes(String(cur.get("status")))) throw new HttpsError("failed-precondition", "Campanha já aprovada; cancele e crie outra.");
    tx.set(ref, { ...c, status: "draft", createdBy: cur.exists ? cur.get("createdBy") : uid, updatedBy: uid, updatedAt: FieldValue.serverTimestamp(), aiDraft: d.aiDraft === true }, { merge: true });
  });
  return { campaignId: ref.id };
});

/** Prévia: quantos receberiam, motivos de exclusão e o texto final. Sem nomes. */
export const previewCampaign = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireAdmin(d.clinicId, uid);
  const ref = db().collection("clinics").doc(clinicId).collection("campaigns").doc(String(d.campaignId ?? "-"));
  const c = (await ref.get()).data();
  if (!c) throw new HttpsError("not-found", "Campanha não encontrada.");
  const now = Date.now();
  const excluded: Record<string, number> = {};
  let eligible = 0;
  let inSegment = 0;
  for (const ct of await contactsOf(clinicId)) {
    if (!matchesSegment(ct, c.segment ?? {})) continue;
    inSegment++;
    const e = eligibility(ct, Number(c.frequencyCapDays ?? 7), now);
    if (e.ok) eligible++;
    else excluded[e.reason] = (excluded[e.reason] ?? 0) + 1;
  }
  await ref.update({ status: "pendingApproval", previewedAt: FieldValue.serverTimestamp(), previewedBy: uid, previewEligible: eligible });
  return { inSegment, eligible, excluded, rendered: { title: c.title, body: c.body }, channel: "inApp" };
});

/** Aprovação por outra pessoa da gestão; agenda os envios (dedupe por responsável). */
export const approveCampaign = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireAdmin(d.clinicId, uid);
  const ref = db().collection("clinics").doc(clinicId).collection("campaigns").doc(String(d.campaignId ?? "-"));
  const c = (await ref.get()).data();
  if (!c) throw new HttpsError("not-found", "Campanha não encontrada.");
  if (c.status !== "pendingApproval") throw new HttpsError("failed-precondition", "Gere a prévia antes de aprovar.");
  if (c.createdBy === uid || c.updatedBy === uid) throw new HttpsError("permission-denied", "A aprovação precisa ser de outra pessoa da gestão.");
  const sendAt = Date.parse(String(d.sendAt ?? ""));
  const sendAtMs = Number.isFinite(sendAt) && sendAt > Date.now() ? sendAt : Date.now();
  const now = Date.now();
  const targets = (await contactsOf(clinicId)).filter((ct) => matchesSegment(ct, c.segment ?? {}) && eligibility(ct, Number(c.frequencyCapDays ?? 7), now).ok);
  let batch = db().batch();
  let n = 0;
  for (const t of targets) {
    batch.set(db().collection("message_queue").doc(`cmp_${ref.id}_${t.ownerUid}_inApp`), {
      kind: "campaign", channel: "inApp", recipientUid: t.ownerUid, clinicId, campaignId: ref.id,
      appointmentId: null, scheduleVersion: null, sendAt: Timestamp.fromMillis(sendAtMs), status: "pending", attempts: 0,
      vars: { titulo: c.title, texto: c.body }, ruleId: "campaign", createdAt: FieldValue.serverTimestamp(),
    }, { merge: false });
    batch.set(db().collection("users").doc(t.ownerUid), { lastMarketingAt: Timestamp.fromMillis(sendAtMs) }, { merge: true });
    if (++n % 200 === 0) {
      await batch.commit();
      batch = db().batch();
    }
  }
  batch.update(ref, { status: "scheduled", approvedBy: uid, approvedAt: FieldValue.serverTimestamp(), sendAt: Timestamp.fromMillis(sendAtMs), targetCount: targets.length });
  await batch.commit();
  return { scheduled: targets.length };
});

export const cancelCampaign = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireAdmin(d.clinicId, uid);
  const ref = db().collection("clinics").doc(clinicId).collection("campaigns").doc(String(d.campaignId ?? "-"));
  if (!(await ref.get()).exists) throw new HttpsError("not-found", "Campanha não encontrada.");
  const pending = await db().collection("message_queue").where("campaignId", "==", ref.id).where("status", "==", "pending").limit(500).get();
  const batch = db().batch();
  pending.docs.forEach((m) => batch.update(m.ref, { status: "cancelled", cancelReason: "campanha cancelada" }));
  batch.update(ref, { status: "cancelled", cancelledBy: uid, cancelledAt: FieldValue.serverTimestamp() });
  await batch.commit();
  return { cancelledMessages: pending.size };
});

export const getCampaignMetrics = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const clinicId = await requireAdmin(d.clinicId, uid);
  const msgs = await db().collection("message_queue").where("clinicId", "==", clinicId).where("campaignId", "==", String(d.campaignId ?? "-")).limit(5000).get();
  const byStatus: Record<string, number> = {};
  msgs.docs.forEach((m) => { byStatus[String(m.get("status"))] = (byStatus[String(m.get("status"))] ?? 0) + 1; });
  return { byStatus, total: msgs.size, note: "Entrega/leitura de WhatsApp só aparece com provedor configurado; aviso no app conta como entregue ao gravar." };
});

/** Descadastro pelo próprio responsável (vale para todas as clínicas). */
export const unsubscribeMarketing = onCall({ region: REGION }, async (request) => {
  const uid = uidOf(request);
  const userRef = db().collection("users").doc(uid);
  const batch = db().batch();
  batch.set(userRef, { communicationPrefs: { marketingConsent: false } }, { merge: true });
  batch.set(db().collection("marketing_suppression").doc(uid), { reason: "unsubscribe", at: FieldValue.serverTimestamp() });
  batch.set(userRef.collection("communication_consents").doc(), { type: "marketingConsent", granted: false, at: FieldValue.serverTimestamp(), source: "unsubscribe" });
  await batch.commit();
  const pending = await db().collection("message_queue").where("recipientUid", "==", uid).where("kind", "==", "campaign").where("status", "==", "pending").limit(200).get();
  const b2 = db().batch();
  pending.docs.forEach((m) => b2.update(m.ref, { status: "cancelled", cancelReason: "descadastro" }));
  if (!pending.empty) await b2.commit();
  return { ok: true, cancelledMessages: pending.size };
});
