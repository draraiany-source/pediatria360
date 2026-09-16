/**
 * Publicação de conteúdo com histórico de versões.
 *
 * ## Por que passa pelo servidor
 *
 * O instantâneo da versão e a atualização do documento precisam acontecer na
 * mesma transação. Se fossem duas escritas do cliente, uma falha entre elas
 * deixaria conteúdo no ar sem registro do que havia antes — exatamente a
 * situação em que o histórico seria necessário.
 *
 * Além disso, os termos de busca são regenerados aqui, garantindo que
 * conteúdo criado por qualquer caminho (painel, script, importação) fique
 * indexado do mesmo jeito.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

async function requireAdmin(uid: string | undefined): Promise<{
  uid: string;
  name: string;
}> {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const doc = await db().collection("users").doc(uid).get();
  if (doc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Ação restrita à equipe.");
  }
  return { uid, name: (doc.data()?.name as string) ?? "Equipe" };
}

function normalize(input: string): string {
  return input
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function buildSearchTerms(data: Record<string, unknown>): string[] {
  const sections = (data.sections ?? []) as { title?: string }[];
  const haystack = [
    (data.title as string) ?? "",
    (data.summary as string) ?? "",
    ((data.tags as string[]) ?? []).join(" "),
    (data.category as string) ?? "",
    sections.map((s) => s.title ?? "").join(" "),
  ].join(" ");

  return Array.from(
    new Set(normalize(haystack).split(" ").filter((t) => t.length >= 3))
  ).slice(0, 200);
}

/**
 * Valida o conteúdo antes de publicar.
 *
 * As checagens são deliberadamente rígidas para material clínico: um
 * protocolo sem sinais de alarme ou sem revisor identificado não deveria
 * chegar a uma família.
 */
function validate(data: Record<string, unknown>, publish: boolean): void {
  const title = (data.title as string) ?? "";
  const summary = (data.summary as string) ?? "";

  if (title.trim().length < 5) {
    throw new HttpsError("invalid-argument", "O título é obrigatório.");
  }
  if (title.length > 200) {
    throw new HttpsError("invalid-argument", "Título muito longo.");
  }

  if (!publish) return; // rascunho pode estar incompleto

  if (summary.trim().length < 20) {
    throw new HttpsError(
      "invalid-argument",
      "Escreva um resumo — é o que aparece na busca e na lista."
    );
  }

  const sections = (data.sections ?? []) as { title?: string; body?: string; kind?: string }[];

  if (sections.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Adicione pelo menos uma seção antes de publicar."
    );
  }

  for (const section of sections) {
    if (!section.body || section.body.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        `A seção "${section.title ?? "sem título"}" está vazia.`
      );
    }
  }

  // Protocolo é documento de conduta: sem "quando procurar atendimento", ele
  // informa sem orientar, que é o pior dos dois mundos numa urgência.
  if (data.type === "protocol") {
    const hasRedFlag = sections.some((s) => s.kind === "redFlag");
    if (!hasRedFlag) {
      throw new HttpsError(
        "failed-precondition",
        "Todo protocolo precisa de uma seção de sinais de alarme " +
          '(tipo "redFlag") indicando quando procurar atendimento.'
      );
    }
  }

  // Posologia só existe em conteúdo restrito a profissionais.
  const hasDosage = sections.some((s) => s.kind === "dosage");
  if (hasDosage && data.audience !== "professionals") {
    throw new HttpsError(
      "failed-precondition",
      "Conteúdo com posologia precisa ter público " +
        '"professionals". Dose lida por um responsável é risco de ' +
        "automedicação."
    );
  }

  if (!data.reviewedBy) {
    throw new HttpsError(
      "failed-precondition",
      "Informe quem revisou clinicamente antes de publicar."
    );
  }
}

/** Cria ou atualiza um conteúdo, gravando a versão. */
export const saveContent = onCall({ region: REGION }, async (request) => {
  const actor = await requireAdmin(request.auth?.uid);

  const { contentId, data, note, publish, partial } = request.data as {
    contentId?: string;
    data: Record<string, unknown>;
    note: string;
    publish: boolean;
    partial?: boolean;
  };

  if (!note || note.trim().length < 3) {
    // "atualizei o texto" não ajuda ninguém seis meses depois, mas exigir
    // algo já filtra o vazio.
    throw new HttpsError(
      "invalid-argument",
      "Descreva o que mudou nesta versão."
    );
  }

  const ref = contentId
    ? db().collection("articles").doc(contentId)
    : db().collection("articles").doc();

  const versionId = await db().runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    const previous = existing.data() ?? {};

    // Edição parcial (ex.: despublicar) mescla; edição completa substitui.
    const merged = partial ? { ...previous, ...data } : data;

    if (!partial) validate(merged, publish);

    const nextVersion = Number(previous.currentVersion ?? 0) + 1;

    const payload = {
      ...merged,
      published: publish,
      searchTerms: buildSearchTerms(merged),
      currentVersion: nextVersion,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
      ...(existing.exists
        ? {}
        : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
    };

    tx.set(ref, payload, { merge: partial === true });

    // Instantâneo. Grava o estado NOVO — restaurar significa voltar a um
    // ponto que já esteve no ar, não a um rascunho intermediário.
    const versionRef = ref.collection("versions").doc();
    tx.set(versionRef, {
      version: nextVersion,
      title: merged.title ?? "",
      snapshot: merged,
      note: note.trim().slice(0, 500),
      published: publish,
      authorUid: actor.uid,
      authorName: actor.name,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return versionRef.id;
  });

  await db().collection("audit_log").add({
    action: publish ? "content_published" : "content_saved",
    contentId: ref.id,
    versionId,
    actorUid: actor.uid,
    note,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("Conteúdo salvo", { contentId: ref.id, publish });

  return { contentId: ref.id, versionId };
});

/**
 * Restaura uma versão anterior.
 *
 * Não apaga o histórico: cria uma versão nova com o conteúdo antigo. O caminho
 * de volta também precisa ser auditável — saber que alguém reverteu, quando e
 * por quê importa tanto quanto saber quem publicou.
 */
export const restoreContentVersion = onCall(
  { region: REGION },
  async (request) => {
    const actor = await requireAdmin(request.auth?.uid);

    const { contentId, versionId, note } = request.data as {
      contentId: string;
      versionId: string;
      note: string;
    };

    if (!contentId || !versionId) {
      throw new HttpsError("invalid-argument", "Versão não informada.");
    }

    const ref = db().collection("articles").doc(contentId);

    const newVersion = await db().runTransaction(async (tx) => {
      const versionDoc = await tx.get(ref.collection("versions").doc(versionId));

      if (!versionDoc.exists) {
        throw new HttpsError("not-found", "Versão não encontrada.");
      }

      const snapshot = versionDoc.data()?.snapshot as Record<string, unknown>;
      const current = await tx.get(ref);
      const nextVersion = Number(current.data()?.currentVersion ?? 0) + 1;

      tx.set(ref, {
        ...snapshot,
        searchTerms: buildSearchTerms(snapshot),
        currentVersion: nextVersion,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: actor.uid,
      });

      const restoredRef = ref.collection("versions").doc();
      tx.set(restoredRef, {
        version: nextVersion,
        title: snapshot.title ?? "",
        snapshot,
        note:
          `Restaurado da versão ${versionDoc.data()?.version}. ` +
          (note ?? "").trim().slice(0, 400),
        published: snapshot.published === true,
        authorUid: actor.uid,
        authorName: actor.name,
        restoredFrom: versionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return nextVersion;
    });

    await db().collection("audit_log").add({
      action: "content_restored",
      contentId,
      restoredFrom: versionId,
      newVersion,
      actorUid: actor.uid,
      note,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.warn("Conteúdo restaurado", { contentId, versionId, actor: actor.uid });

    return { ok: true, version: newVersion };
  }
);
