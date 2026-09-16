/**
 * Assinatura de atendimento e emissão de documentos clínicos.
 *
 * ## Por que a assinatura acontece aqui e não no aplicativo
 *
 * O hash precisa ser calculado sobre o estado que está no servidor, não sobre
 * o que o cliente afirma ter gravado. Se o app calculasse, bastaria enviar um
 * hash de um conteúdo diferente do que foi salvo.
 *
 * ## Assinatura digital com validade legal
 *
 * O que este arquivo faz é **selar** o registro: congela o conteúdo, calcula o
 * hash e impede edição. Isso garante integridade e rastreabilidade.
 *
 * Não é a mesma coisa que assinatura digital ICP-Brasil, exigida pelo CFM para
 * receita e atestado com validade jurídica plena. Os campos
 * `signatureProvider` e `externalSignatureId` existem para receber o retorno
 * do provedor credenciado quando essa integração for feita. Enquanto estiverem
 * nulos, o documento vale como registro interno — e a tela precisa dizer isso
 * ao médico.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { createHash, randomBytes } from "crypto";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

/** Campos que compõem o hash. Metadados voláteis ficam de fora. */
const HASHED_FIELDS = [
  "patientId",
  "professionalId",
  "type",
  "anamnesis",
  "vitals",
  "exam",
  "diagnoses",
  "assessment",
  "plan",
  "procedures",
];

function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  // Chaves ordenadas: sem isso, o mesmo conteúdo geraria hashes diferentes
  // conforme a ordem em que o Firestore devolvesse os campos.
  const keys = Object.keys(value as Record<string, unknown>).sort();
  return `{${keys
    .map((k) => `${JSON.stringify(k)}:${stableStringify((value as Record<string, unknown>)[k])}`)
    .join(",")}}`;
}

function hashEncounter(data: Record<string, unknown>): string {
  const subset: Record<string, unknown> = {};
  for (const field of HASHED_FIELDS) {
    subset[field] = data[field] ?? null;
  }
  return createHash("sha256").update(stableStringify(subset)).digest("hex");
}

async function requireVerifiedProfessional(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const doc = await db().collection("users").doc(uid).get();
  const user = doc.data() ?? {};

  const isPro = user.role === "professional" || user.role === "admin";
  if (!isPro || user.professionalVerified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Ação restrita a profissionais com registro verificado."
    );
  }
  return {
    uid,
    name: (user.name as string) ?? "",
    crm: (user.crm as string) ?? null,
  };
}

/** Campos sem os quais o atendimento não pode ser assinado. */
function missingForSignature(e: Record<string, any>): string[] {
  const missing: string[] = [];

  if (!e.anamnesis?.chiefComplaint?.trim()) missing.push("Queixa principal");

  const hasExam = Object.keys(e.exam?.findings ?? {}).length > 0;
  const hasVitals = Object.values(e.vitals ?? {}).some((v) => v != null);
  if (!hasExam && !hasVitals) missing.push("Exame físico ou sinais vitais");

  if (!(e.diagnoses ?? []).length) missing.push("Ao menos um diagnóstico");
  if (!e.plan?.trim()) missing.push("Conduta");

  return missing;
}

/**
 * Assina o atendimento, tornando-o imutável.
 *
 * A partir daqui, `updateDraft` é recusado pelo repositório, pelas regras do
 * Firestore e por esta Function. Correção só por retificação.
 */
export const signEncounter = onCall({ region: REGION }, async (request) => {
  const actor = await requireVerifiedProfessional(request.auth?.uid);
  const { encounterId } = request.data as { encounterId: string };

  if (!encounterId) {
    throw new HttpsError("invalid-argument", "Atendimento não informado.");
  }

  const ref = db().collection("encounters").doc(encounterId);

  const signatureHash = await db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError("not-found", "Atendimento não encontrado.");
    }

    const e = doc.data() ?? {};

    if (e.professionalId !== actor.uid) {
      throw new HttpsError(
        "permission-denied",
        "Só quem conduziu o atendimento pode assiná-lo."
      );
    }

    if (e.status !== "draft") {
      throw new HttpsError(
        "failed-precondition",
        "Este atendimento já foi assinado."
      );
    }

    const missing = missingForSignature(e);
    if (missing.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        `Faltam campos obrigatórios: ${missing.join(", ")}.`
      );
    }

    const hash = hashEncounter(e);

    tx.update(ref, {
      status: e.amendsEncounterId ? "amended" : "signed",
      signedAt: admin.firestore.FieldValue.serverTimestamp(),
      signedBy: actor.uid,
      signerName: actor.name,
      signerCrm: actor.crm,
      signatureHash: hash,
      // Nulo até a integração com provedor ICP-Brasil.
      signatureProvider: null,
      externalSignatureId: null,
    });

    return hash;
  });

  await db().collection("audit_log").add({
    action: "encounter_signed",
    encounterId,
    actorUid: actor.uid,
    signatureHash,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("Atendimento assinado", { encounterId, actor: actor.uid });

  return { signatureHash };
});

/**
 * Cria a retificação de um atendimento assinado.
 *
 * O original **não é alterado**. Nasce um novo atendimento em rascunho, com o
 * conteúdo copiado e um vínculo com o original. Os dois ficam visíveis na
 * linha do tempo — quem lê o prontuário vê o que foi registrado primeiro e o
 * que foi corrigido, que é justamente o que se discute quando há
 * questionamento.
 */
export const amendEncounter = onCall({ region: REGION }, async (request) => {
  const actor = await requireVerifiedProfessional(request.auth?.uid);
  const { encounterId, reason } = request.data as {
    encounterId: string;
    reason: string;
  };

  if (!reason || reason.trim().length < 10) {
    throw new HttpsError(
      "invalid-argument",
      "Descreva o motivo da retificação — ele fica registrado no prontuário."
    );
  }

  const originalRef = db().collection("encounters").doc(encounterId);
  const original = await originalRef.get();

  if (!original.exists) {
    throw new HttpsError("not-found", "Atendimento não encontrado.");
  }

  const e = original.data() ?? {};

  if (e.professionalId !== actor.uid) {
    throw new HttpsError(
      "permission-denied",
      "Só quem conduziu o atendimento pode retificá-lo."
    );
  }
  if (e.status === "draft") {
    throw new HttpsError(
      "failed-precondition",
      "Rascunho ainda é editável — não precisa de retificação."
    );
  }

  const newRef = db().collection("encounters").doc();

  await newRef.set({
    ...e,
    status: "draft",
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    signedAt: null,
    signedBy: null,
    signatureHash: null,
    signatureProvider: null,
    externalSignatureId: null,
    amendsEncounterId: encounterId,
    amendmentReason: reason.trim().slice(0, 1000),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Marca o original, para a linha do tempo sinalizar que houve correção.
  await originalRef.update({
    amendedByEncounterId: newRef.id,
    amendedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db().collection("audit_log").add({
    action: "encounter_amended",
    encounterId,
    newEncounterId: newRef.id,
    actorUid: actor.uid,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.warn("Atendimento retificado", { encounterId, newId: newRef.id });

  return { encounterId: newRef.id };
});

/** Código de conferência de autenticidade, legível ao telefone. */
function verificationCode(): string {
  // Sem caracteres ambíguos (0/O, 1/I): o código é ditado por telefone para
  // farmácia e escola conferirem.
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes(10);
  let code = "";
  for (let i = 0; i < 10; i++) {
    code += alphabet[bytes[i] % alphabet.length];
    if (i === 4) code += "-";
  }
  return code;
}

/** Validade padrão por tipo de documento, em dias. */
const DEFAULT_VALIDITY_DAYS: Record<string, number | null> = {
  prescription: 30,
  certificate: null,
  referral: 90,
  report: null,
  dischargeSummary: null,
  examRequest: 90,
};

/**
 * Emite um documento clínico vinculado a um atendimento.
 *
 * Exige atendimento **assinado**: documento emitido a partir de rascunho
 * poderia divergir do registro final, e é o registro que sustenta o documento.
 */
export const issueClinicalDocument = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);

    const { encounterId, type, content, items, validUntil } =
      request.data as {
        encounterId: string;
        type: string;
        content: string;
        items?: Record<string, unknown>[];
        validUntil?: string;
      };

    if (!DEFAULT_VALIDITY_DAYS.hasOwnProperty(type)) {
      throw new HttpsError("invalid-argument", "Tipo de documento inválido.");
    }
    if (!content || content.trim().length < 5) {
      throw new HttpsError("invalid-argument", "Documento sem conteúdo.");
    }

    const encounterDoc = await db()
      .collection("encounters")
      .doc(encounterId)
      .get();

    if (!encounterDoc.exists) {
      throw new HttpsError("not-found", "Atendimento não encontrado.");
    }

    const e = encounterDoc.data() ?? {};

    if (e.professionalId !== actor.uid) {
      throw new HttpsError("permission-denied", "Atendimento de outro profissional.");
    }
    if (e.status === "draft") {
      throw new HttpsError(
        "failed-precondition",
        "Assine o atendimento antes de emitir documentos."
      );
    }

    // Receita exige ao menos um item — receita vazia é erro de fluxo.
    if (type === "prescription" && !(items ?? []).length) {
      throw new HttpsError(
        "invalid-argument",
        "Adicione ao menos um medicamento à receita."
      );
    }

    const now = new Date();
    let expiry: Date | null = null;

    if (validUntil) {
      expiry = new Date(validUntil);
    } else {
      const days = DEFAULT_VALIDITY_DAYS[type];
      if (days != null) {
        expiry = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
      }
    }

    const code = verificationCode();
    const hash = createHash("sha256")
      .update(stableStringify({ encounterId, type, content, items: items ?? [] }))
      .digest("hex");

    const ref = db().collection("clinical_documents").doc();

    await ref.set({
      encounterId,
      patientId: e.patientId,
      professionalId: actor.uid,
      professionalName: actor.name,
      professionalCrm: actor.crm,
      patientName: e.patientName ?? null,
      type,
      content: content.trim(),
      items: items ?? [],
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      validUntil: expiry ? admin.firestore.Timestamp.fromDate(expiry) : null,
      contentHash: hash,
      verificationCode: code,
      // Preenchidos quando houver integração ICP-Brasil.
      signatureProvider: null,
      signedAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelled: false,
      pdfUrl: null,
    });

    await db().collection("audit_log").add({
      action: "document_issued",
      documentId: ref.id,
      documentType: type,
      encounterId,
      actorUid: actor.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Documento emitido", { documentId: ref.id, type });

    return { documentId: ref.id, verificationCode: code, contentHash: hash };
  }
);

/**
 * Cancela um documento.
 *
 * Cancelar não apaga: o documento continua legível, marcado como cancelado.
 * Uma receita que circulou não deixa de ter circulado — a farmácia precisa
 * poder conferir que ela existiu e foi anulada.
 */
export const cancelClinicalDocument = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);

    const { documentId, reason } = request.data as {
      documentId: string;
      reason: string;
    };

    if (!reason || reason.trim().length < 5) {
      throw new HttpsError("invalid-argument", "Informe o motivo.");
    }

    const ref = db().collection("clinical_documents").doc(documentId);
    const doc = await ref.get();

    if (!doc.exists) {
      throw new HttpsError("not-found", "Documento não encontrado.");
    }
    if (doc.data()?.professionalId !== actor.uid) {
      throw new HttpsError("permission-denied", "Documento de outro profissional.");
    }
    if (doc.data()?.cancelled === true) {
      throw new HttpsError("failed-precondition", "Já está cancelado.");
    }

    await ref.update({
      cancelled: true,
      cancellationReason: reason.trim().slice(0, 500),
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: actor.uid,
    });

    await db().collection("audit_log").add({
      action: "document_cancelled",
      documentId,
      actorUid: actor.uid,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true };
  }
);

/**
 * Confere a autenticidade de um documento pelo código.
 *
 * Aberta a qualquer pessoa: é a farmácia, a escola ou o empregador conferindo.
 * Devolve **apenas** o suficiente para validar — nunca o conteúdo clínico.
 */
export const verifyDocument = onCall({ region: REGION }, async (request) => {
  const { code } = request.data as { code: string };

  if (!code || code.length < 8) {
    throw new HttpsError("invalid-argument", "Código inválido.");
  }

  const snapshot = await db()
    .collection("clinical_documents")
    .where("verificationCode", "==", code.toUpperCase().trim())
    .limit(1)
    .get();

  if (snapshot.empty) {
    return { found: false };
  }

  const d = snapshot.docs[0].data();
  const expiry = (d.validUntil as admin.firestore.Timestamp | null)?.toDate();

  // Nada de conteúdo clínico, nome do paciente ou diagnóstico. Quem confere
  // precisa saber que o documento é autêntico, não o que ele diz.
  return {
    found: true,
    type: d.type,
    issuedAt: (d.issuedAt as admin.firestore.Timestamp)?.toDate().toISOString(),
    professionalName: d.professionalName,
    professionalCrm: d.professionalCrm,
    cancelled: d.cancelled === true,
    expired: expiry ? expiry < new Date() : false,
    valid: d.cancelled !== true && (!expiry || expiry >= new Date()),
  };
});

/**
 * Concede a um profissional verificado a leitura do resumo de segurança de
 * uma criança (nome, idade, alergia) — não do prontuário clínico completo.
 *
 * ## Por que isto precisa ser Function, não escrita direta do cliente
 *
 * `EncounterRepository.create` grava direto no Firestore, sem passar por
 * Function — e só recebe `childId`, nunca o uid do responsável. Um
 * profissional não tem como escrever
 * `users/{ownerId}/children/{childId}/authorized_professionals/{seuUid}`
 * porque não sabe `ownerId`, e não tem como descobrir sem já ter a
 * permissão que está tentando conceder a si mesmo — circular.
 *
 * Rodando com Admin SDK, esta Function ignora as regras do cliente e
 * localiza a criança por busca de collection group, direto pelo id do
 * documento — não precisa de índice composto, é igualdade simples.
 *
 * ## O que isto NÃO concede
 *
 * Só a leitura do documento da criança em si (nome, idade, sexo, alergia,
 * condição, foto). Não dá acesso a `growth_records`, `vaccine_doses`, nem a
 * mais nada da família — essas subcoleções continuam exclusivas do dono. E
 * não precisa de nenhum atendimento existir antes: um profissional
 * verificado pode chamar isso para qualquer `childId` real — o mesmo
 * princípio já aceito para `bookAppointment`/`getAvailability`, onde ser
 * profissional verificado já é a barreira, não um vínculo prévio
 * comprovado documento a documento.
 */
export const grantChildSummaryAccess = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);
    const { childId } = request.data as { childId?: string };

    if (!childId) {
      throw new HttpsError("invalid-argument", "childId não informado.");
    }

    const found = await db()
      .collectionGroup("children")
      .where(admin.firestore.FieldPath.documentId(), "==", childId)
      .limit(1)
      .get();

    if (found.empty) {
      throw new HttpsError("not-found", "Criança não encontrada.");
    }

    // O caminho do documento encontrado é .../users/{ownerId}/children/{childId}
    // — o penúltimo segmento é o uid do responsável.
    const childRef = found.docs[0].ref;
    const ownerId = childRef.parent.parent?.id;
    if (!ownerId) {
      throw new HttpsError("internal", "Estrutura de documento inesperada.");
    }

    await childRef
      .collection("authorized_professionals")
      .doc(actor.uid)
      .set({ grantedAt: admin.firestore.FieldValue.serverTimestamp() });

    logger.info("Acesso ao resumo de criança concedido", {
      professional: actor.uid,
      childId,
    });

    return { ok: true };
  }
);
