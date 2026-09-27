/**
 * Consulta por voz / Prontuario IA.
 *
 * A chave Anthropic vive so aqui (secret). O cliente nunca assina
 * atendimento: applyVoiceDraftToEncounter grava apenas campos de rascunho.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const REGION = "southamerica-east1";
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const db = () => admin.firestore();

const AI_DISCLAIMER =
  "Conteudo gerado por IA em modo RASCUNHO. Revise, edite e confirme antes de gravar no prontuario. A IA nao diagnostica nem assina.";

const NOT_INFORMED = "Nao informado";

async function requireVerifiedProfessional(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const doc = await db().collection("users").doc(uid).get();
  const user = doc.data() ?? {};
  const isPro = user.role === "professional" || user.role === "admin";
  if (!isPro || user.professionalVerified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Acao restrita a profissionais com registro verificado."
    );
  }
  return {
    uid,
    name: (user.name as string) ?? "",
  };
}

async function loadOwnedSession(sessionId: string, uid: string) {
  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId nao informado.");
  }
  const ref = db().collection("voice_sessions").doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Sessao nao encontrada.");
  }
  const data = snap.data() ?? {};
  if (data.professionalId !== uid) {
    throw new HttpsError("permission-denied", "Sessao de outro profissional.");
  }
  return { ref, data };
}

function emptyDraft(template: string) {
  return {
    chiefComplaint: NOT_INFORMED,
    historyOfPresentIllness: NOT_INFORMED,
    pastMedicalHistory: NOT_INFORMED,
    gestationalHistory: NOT_INFORMED,
    birthHistory: NOT_INFORMED,
    developmentHistory: NOT_INFORMED,
    feedingHistory: NOT_INFORMED,
    sleepHistory: NOT_INFORMED,
    eliminationHistory: NOT_INFORMED,
    immunizationStatus: NOT_INFORMED,
    allergies: [] as string[],
    currentMedications: [] as string[],
    familyHistory: NOT_INFORMED,
    socialHistory: NOT_INFORMED,
    reviewOfSystems: {} as Record<string, string>,
    examFindings: {} as Record<string, string>,
    examNotes: NOT_INFORMED,
    assessment: NOT_INFORMED,
    plan: NOT_INFORMED,
    missingFields: [
      "queixa principal",
      "historia da doenca atual",
      "exame fisico",
      "avaliacao",
      "plano",
    ],
    evolutionText: NOT_INFORMED,
    hypotheses: [] as string[],
    suggestedCids: [] as string[],
    disclaimer: AI_DISCLAIMER,
    evolutionTemplate: template,
    isDraft: true,
  };
}

function fillMissing(value: unknown): string {
  if (typeof value !== "string") return NOT_INFORMED;
  const t = value.trim();
  return t.length === 0 ? NOT_INFORMED : t;
}

/** Inicia sessao apos consentimento no cliente. */
export const startVoiceConsultation = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const {
      childId,
      childName,
      professionalName,
      appointmentId,
      encounterId,
      audioRetentionPolicy,
    } = request.data as {
      childId?: string;
      childName?: string;
      professionalName?: string;
      appointmentId?: string;
      encounterId?: string;
      audioRetentionPolicy?: string;
    };

    if (!childId) {
      throw new HttpsError("invalid-argument", "childId e obrigatorio.");
    }

    const ref = db().collection("voice_sessions").doc();
    const now = FieldValue.serverTimestamp();
    const payload = {
      id: ref.id,
      childId,
      childName: childName ?? "",
      professionalId: actor.uid,
      professionalName: professionalName || actor.name,
      appointmentId: appointmentId ?? null,
      encounterId: encounterId ?? null,
      status: "recording",
      consentAt: now,
      consentByUid: actor.uid,
      startedAt: now,
      endedAt: null,
      durationSeconds: 0,
      segments: [],
      draft: null,
      audioRetentionPolicy: audioRetentionPolicy ?? "deleteAfterValidation",
      audioStored: false,
      aiDisclaimer: AI_DISCLAIMER,
      createdAt: now,
      updatedAt: now,
    };

    await ref.set(payload);

    return {
      ...payload,
      consentAt: new Date().toISOString(),
      startedAt: new Date().toISOString(),
    };
  }
);

/** Pausa ou retoma a gravacao. */
export const updateVoiceSession = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { sessionId, action } = request.data as {
      sessionId?: string;
      action?: string;
    };

    const { ref, data } = await loadOwnedSession(sessionId ?? "", actor.uid);

    if (action !== "pause" && action !== "resume") {
      throw new HttpsError("invalid-argument", "action deve ser pause|resume.");
    }

    const next =
      action === "pause"
        ? "paused"
        : data.status === "paused"
          ? "recording"
          : "recording";

    await ref.update({
      status: next,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, status: next };
  }
);

/**
 * Finaliza a gravacao: marca processing.
 * Se transcript vier no request, persiste; senao deixa pendente.
 */
export const finalizeVoiceRecording = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { sessionId, transcript, evolutionTemplate } = request.data as {
      sessionId?: string;
      transcript?: { id?: string; speaker?: string; text?: string; at?: string; markedImportant?: boolean }[];
      evolutionTemplate?: string;
    };

    const { ref } = await loadOwnedSession(sessionId ?? "", actor.uid);

    const patch: Record<string, unknown> = {
      status: "processing",
      endedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (Array.isArray(transcript) && transcript.length > 0) {
      patch.segments = transcript.map((s, i) => ({
        id: s.id ?? `seg_${i}`,
        speaker: s.speaker ?? "unknown",
        text: s.text ?? "",
        at: s.at ?? new Date().toISOString(),
        markedImportant: s.markedImportant ?? false,
      }));
      patch.transcriptPending = false;
    } else {
      patch.transcriptPending = true;
    }

    if (evolutionTemplate) {
      patch.evolutionTemplate = evolutionTemplate;
    }

    await ref.update(patch);
    return { ok: true, status: "processing" };
  }
);

/**
 * Estrutura o rascunho clinico via Anthropic.
 * NUNCA inventa fatos — usa "Nao informado" quando ausente. Sempre isDraft.
 */
export const structureVoiceDraft = onCall(
  { region: REGION, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { sessionId, evolutionTemplate } = request.data as {
      sessionId?: string;
      evolutionTemplate?: string;
    };

    const template = evolutionTemplate || "SOAP";
    const { ref, data } = await loadOwnedSession(sessionId ?? "", actor.uid);

    const segments = (data.segments as { speaker?: string; text?: string }[]) ?? [];
    const transcriptText = segments
      .map((s) => `${s.speaker ?? "unknown"}: ${s.text ?? ""}`)
      .join("\n")
      .trim();

    let draft = emptyDraft(template);

    if (transcriptText.length > 0) {
      const system = `Voce extrai dados clinicos de uma transcricao pediatrica em pt-BR.
REGRAS RIGIDAS:
- NUNCA invente fatos, sintomas, doses, CIDs ou exames nao ditos.
- Se o dado nao estiver na transcricao, use exatamente "${NOT_INFORMED}".
- Listas vazias quando nao houver itens.
- missingFields: nomes dos campos clinicos relevantes ainda ausentes.
- Responda APENAS JSON valido, sem markdown.
- Marque isDraft: true e inclua disclaimer.
Campos esperados: chiefComplaint, historyOfPresentIllness, pastMedicalHistory,
gestationalHistory, birthHistory, developmentHistory, feedingHistory, sleepHistory,
eliminationHistory, immunizationStatus, allergies (array), currentMedications (array),
familyHistory, socialHistory, reviewOfSystems (objeto), examFindings (objeto),
examNotes, assessment, plan, missingFields (array), evolutionText, hypotheses (array),
suggestedCids (array), disclaimer, isDraft.
Modelo de evolucao pedido: ${template}.`;

      try {
        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY.value(),
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-5",
            max_tokens: 2500,
            system,
            messages: [
              {
                role: "user",
                content: `Transcricao:\n\n${transcriptText.slice(0, 20000)}`,
              },
            ],
          }),
        });

        if (!response.ok) {
          const body = await response.text();
          logger.error("structureVoiceDraft API falhou", {
            status: response.status,
            body,
          });
          throw new HttpsError(
            "unavailable",
            "IA indisponivel para estruturar o rascunho."
          );
        }

        const payload = (await response.json()) as {
          content: { type: string; text?: string }[];
        };
        const raw = payload.content
          .filter((c) => c.type === "text")
          .map((c) => c.text ?? "")
          .join("\n")
          .trim();

        const jsonStart = raw.indexOf("{");
        const jsonEnd = raw.lastIndexOf("}");
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          const parsed = JSON.parse(raw.slice(jsonStart, jsonEnd + 1)) as Record<
            string,
            unknown
          >;
          draft = {
            ...emptyDraft(template),
            ...parsed,
            chiefComplaint: fillMissing(parsed.chiefComplaint),
            historyOfPresentIllness: fillMissing(parsed.historyOfPresentIllness),
            pastMedicalHistory: fillMissing(parsed.pastMedicalHistory),
            gestationalHistory: fillMissing(parsed.gestationalHistory),
            birthHistory: fillMissing(parsed.birthHistory),
            developmentHistory: fillMissing(parsed.developmentHistory),
            feedingHistory: fillMissing(parsed.feedingHistory),
            sleepHistory: fillMissing(parsed.sleepHistory),
            eliminationHistory: fillMissing(parsed.eliminationHistory),
            immunizationStatus: fillMissing(parsed.immunizationStatus),
            familyHistory: fillMissing(parsed.familyHistory),
            socialHistory: fillMissing(parsed.socialHistory),
            examNotes: fillMissing(parsed.examNotes),
            assessment: fillMissing(parsed.assessment),
            plan: fillMissing(parsed.plan),
            evolutionText: fillMissing(parsed.evolutionText),
            allergies: Array.isArray(parsed.allergies)
              ? (parsed.allergies as string[])
              : [],
            currentMedications: Array.isArray(parsed.currentMedications)
              ? (parsed.currentMedications as string[])
              : [],
            missingFields: Array.isArray(parsed.missingFields)
              ? (parsed.missingFields as string[])
              : [],
            hypotheses: Array.isArray(parsed.hypotheses)
              ? (parsed.hypotheses as string[])
              : [],
            suggestedCids: Array.isArray(parsed.suggestedCids)
              ? (parsed.suggestedCids as string[])
              : [],
            disclaimer: AI_DISCLAIMER,
            isDraft: true,
            evolutionTemplate: template,
          };
        }
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("structureVoiceDraft erro", error);
        // Mantem rascunho vazio com Nao informado — nao inventa.
      }
    }

    await ref.update({
      draft,
      status: "draftReady",
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, draft };
  }
);

/**
 * Aplica o rascunho no encounter SOMENTE se status=draft e o profissional
 * for o dono. Nunca grava signedAt / signatureHash / signedBy.
 */
export const applyVoiceDraftToEncounter = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { sessionId } = request.data as { sessionId?: string };
    const { ref: sessionRef, data: session } = await loadOwnedSession(
      sessionId ?? "",
      actor.uid
    );

    const draft = session.draft as Record<string, unknown> | null;
    if (!draft) {
      throw new HttpsError(
        "failed-precondition",
        "Nao ha rascunho para aplicar."
      );
    }

    let encounterId = (session.encounterId as string) || null;
    const childId = session.childId as string;

    if (!encounterId) {
      const encRef = db().collection("encounters").doc();
      encounterId = encRef.id;
      await encRef.set({
        patientId: childId,
        professionalId: actor.uid,
        status: "draft",
        type: "consultation",
        anamnesis: {
          chiefComplaint: draft.chiefComplaint ?? NOT_INFORMED,
          historyOfPresentIllness:
            draft.historyOfPresentIllness ?? NOT_INFORMED,
          pastMedicalHistory: draft.pastMedicalHistory ?? NOT_INFORMED,
          gestationalHistory: draft.gestationalHistory ?? NOT_INFORMED,
          birthHistory: draft.birthHistory ?? NOT_INFORMED,
          developmentHistory: draft.developmentHistory ?? NOT_INFORMED,
          feedingHistory: draft.feedingHistory ?? NOT_INFORMED,
          sleepHistory: draft.sleepHistory ?? NOT_INFORMED,
          eliminationHistory: draft.eliminationHistory ?? NOT_INFORMED,
          immunizationStatus: draft.immunizationStatus ?? NOT_INFORMED,
          allergies: draft.allergies ?? [],
          currentMedications: draft.currentMedications ?? [],
          familyHistory: draft.familyHistory ?? NOT_INFORMED,
          socialHistory: draft.socialHistory ?? NOT_INFORMED,
          reviewOfSystems: draft.reviewOfSystems ?? {},
        },
        exam: {
          findings: draft.examFindings ?? {},
          systemsExamined: Object.keys(
            (draft.examFindings as Record<string, string>) ?? {}
          ),
          notes: draft.examNotes ?? NOT_INFORMED,
        },
        assessment: draft.assessment ?? NOT_INFORMED,
        plan: draft.plan ?? NOT_INFORMED,
        diagnoses: [],
        vitals: {},
        procedures: [],
        signedAt: null,
        signatureHash: null,
        signedBy: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        sourceVoiceSessionId: sessionRef.id,
        aiDraft: true,
      });
    } else {
      const encRef = db().collection("encounters").doc(encounterId);
      const encSnap = await encRef.get();
      if (!encSnap.exists) {
        throw new HttpsError("not-found", "Atendimento nao encontrado.");
      }
      const enc = encSnap.data() ?? {};
      if (enc.professionalId !== actor.uid) {
        throw new HttpsError(
          "permission-denied",
          "Atendimento de outro profissional."
        );
      }
      if (enc.status !== "draft") {
        throw new HttpsError(
          "failed-precondition",
          "So e permitido aplicar rascunho em atendimento draft."
        );
      }

      // Nunca tocar em assinatura.
      await encRef.update({
        anamnesis: {
          chiefComplaint: draft.chiefComplaint ?? NOT_INFORMED,
          historyOfPresentIllness:
            draft.historyOfPresentIllness ?? NOT_INFORMED,
          pastMedicalHistory: draft.pastMedicalHistory ?? NOT_INFORMED,
          gestationalHistory: draft.gestationalHistory ?? NOT_INFORMED,
          birthHistory: draft.birthHistory ?? NOT_INFORMED,
          developmentHistory: draft.developmentHistory ?? NOT_INFORMED,
          feedingHistory: draft.feedingHistory ?? NOT_INFORMED,
          sleepHistory: draft.sleepHistory ?? NOT_INFORMED,
          eliminationHistory: draft.eliminationHistory ?? NOT_INFORMED,
          immunizationStatus: draft.immunizationStatus ?? NOT_INFORMED,
          allergies: draft.allergies ?? [],
          currentMedications: draft.currentMedications ?? [],
          familyHistory: draft.familyHistory ?? NOT_INFORMED,
          socialHistory: draft.socialHistory ?? NOT_INFORMED,
          reviewOfSystems: draft.reviewOfSystems ?? {},
        },
        exam: {
          findings: draft.examFindings ?? {},
          systemsExamined: Object.keys(
            (draft.examFindings as Record<string, string>) ?? {}
          ),
          notes: draft.examNotes ?? NOT_INFORMED,
        },
        assessment: draft.assessment ?? NOT_INFORMED,
        plan: draft.plan ?? NOT_INFORMED,
        updatedAt: FieldValue.serverTimestamp(),
        sourceVoiceSessionId: sessionRef.id,
        aiDraft: true,
        // signedAt / signatureHash / signedBy intencionalmente omitidos
      });
    }

    await sessionRef.update({
      status: "applied",
      encounterId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, encounterId };
  }
);

export const discardVoiceSession = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { sessionId } = request.data as { sessionId?: string };
    const { ref } = await loadOwnedSession(sessionId ?? "", actor.uid);

    await ref.update({
      status: "discarded",
      draft: null,
      audioStored: false,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true };
  }
);
