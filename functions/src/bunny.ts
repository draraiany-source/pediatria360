/**
 * Integração com o Bunny.net.
 *
 * A chave de API do Bunny permite criar, listar e APAGAR toda a biblioteca de
 * vídeos. Embutida num aplicativo publicado, seria extraída em minutos e o
 * acervo poderia ser destruído por qualquer pessoa. Por isso ela vive apenas
 * aqui, no Secret Manager.
 *
 * O que o app faz sozinho: montar URLs públicas de reprodução (concatenação de
 * hostname e GUID). O que passa por aqui: criar vídeo, assinar upload, assinar
 * reprodução de conteúdo pago e apagar.
 */

import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { createHash } from "crypto";

const REGION = "southamerica-east1";

const BUNNY_STREAM_API_KEY = defineSecret("BUNNY_STREAM_API_KEY");
const BUNNY_TOKEN_KEY = defineSecret("BUNNY_TOKEN_KEY");
const BUNNY_LIBRARY_ID = defineString("BUNNY_LIBRARY_ID");
const BUNNY_CDN_HOSTNAME = defineString("BUNNY_CDN_HOSTNAME");

const STREAM_API = "https://video.bunnycdn.com/library";

const db = () => admin.firestore();

/** Só admin publica vídeo. */
async function requireAdmin(uid: string | undefined): Promise<void> {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const doc = await db().collection("users").doc(uid).get();
  if (doc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Ação restrita à equipe.");
  }
}

/** Verifica se o usuário pode assistir a uma aula paga. */
async function canWatch(uid: string, videoGuid: string): Promise<boolean> {
  const userDoc = await db().collection("users").doc(uid).get();
  const user = userDoc.data() ?? {};

  // Plano ativo libera tudo que não seja exclusivo de profissional.
  const planActive =
    user.plan && user.plan !== "free" &&
    (!user.planExpiresAt || user.planExpiresAt.toDate() > new Date());

  // Localiza a aula pelo GUID para checar se é amostra gratuita.
  const lessons = await db()
    .collectionGroup("lessons")
    .where("videoGuid", "==", videoGuid)
    .limit(1)
    .get();

  if (lessons.empty) return planActive === true;

  const lesson = lessons.docs[0];
  if (lesson.data().isFree === true) return true;

  const courseRef = lesson.ref.parent.parent;
  if (!courseRef) return planActive === true;

  const course = (await courseRef.get()).data() ?? {};

  if (course.professionalOnly === true) {
    const verified =
      (user.role === "professional" || user.role === "admin") &&
      user.professionalVerified === true;
    if (!verified) return false;
  }

  if (course.requiresPlan === true) return planActive === true;

  return true;
}

/**
 * Cria a entrada do vídeo e devolve a URL de upload.
 *
 * O app faz o PUT dos bytes direto no Bunny. Passar 500 MB de vídeo por uma
 * Cloud Function custaria caro e estouraria o limite de tempo.
 */
export const createBunnyVideo = onCall(
  { region: REGION, secrets: [BUNNY_STREAM_API_KEY] },
  async (request) => {
    await requireAdmin(request.auth?.uid);

    const { title, collectionId } = request.data as {
      title: string;
      collectionId?: string;
    };

    if (!title || title.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Informe o título do vídeo.");
    }

    const libraryId = BUNNY_LIBRARY_ID.value();

    const response = await fetch(`${STREAM_API}/${libraryId}/videos`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        AccessKey: BUNNY_STREAM_API_KEY.value(),
      },
      body: JSON.stringify({
        title: title.slice(0, 200),
        ...(collectionId ? { collectionId } : {}),
      }),
    });

    if (!response.ok) {
      logger.error("Falha ao criar vídeo no Bunny", {
        status: response.status,
        body: await response.text(),
      });
      throw new HttpsError("internal", "Não foi possível preparar o envio.");
    }

    const video = (await response.json()) as { guid: string };

    // Assinatura de upload: SHA256(libraryId + apiKey + expiração + guid).
    // Vale 2 horas — tempo de sobra para um vídeo grande numa conexão ruim.
    const expires = Math.floor(Date.now() / 1000) + 2 * 60 * 60;
    const signature = createHash("sha256")
      .update(libraryId + BUNNY_STREAM_API_KEY.value() + expires + video.guid)
      .digest("hex");

    return {
      guid: video.guid,
      uploadUrl: `${STREAM_API}/${libraryId}/videos/${video.guid}`,
      signature,
      expires,
    };
  }
);

/** Estágio de processamento de um vídeo. */
export const getBunnyVideo = onCall(
  { region: REGION, secrets: [BUNNY_STREAM_API_KEY] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Entre para continuar.");
    }

    const { videoGuid } = request.data as { videoGuid: string };
    const libraryId = BUNNY_LIBRARY_ID.value();

    const response = await fetch(
      `${STREAM_API}/${libraryId}/videos/${videoGuid}`,
      { headers: { AccessKey: BUNNY_STREAM_API_KEY.value() } }
    );

    if (!response.ok) {
      throw new HttpsError("not-found", "Vídeo não encontrado.");
    }

    const video = (await response.json()) as Record<string, unknown>;

    return {
      guid: video.guid,
      title: video.title,
      length: video.length,
      status: video.status,
      thumbnailUrl: `https://${BUNNY_CDN_HOSTNAME.value()}/${videoGuid}/thumbnail.jpg`,
    };
  }
);

/**
 * URL de reprodução com token, para conteúdo pago.
 *
 * O token expira, então um link copiado do inspetor do navegador deixa de
 * funcionar em poucas horas. Não impede gravação de tela — nada impede — mas
 * elimina o compartilhamento casual de link, que é o vazamento real.
 */
export const signBunnyPlayback = onCall(
  { region: REGION, secrets: [BUNNY_TOKEN_KEY] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

    const { videoGuid, expiresInSeconds } = request.data as {
      videoGuid: string;
      expiresInSeconds?: number;
    };

    if (!videoGuid) {
      throw new HttpsError("invalid-argument", "Vídeo não informado.");
    }

    if (!(await canWatch(uid, videoGuid))) {
      throw new HttpsError(
        "permission-denied",
        "Esta aula não está incluída no seu plano."
      );
    }

    const hostname = BUNNY_CDN_HOSTNAME.value();
    const path = `/${videoGuid}/playlist.m3u8`;

    // Máximo de 12 horas: um token muito longo perde o propósito.
    const ttl = Math.min(expiresInSeconds ?? 4 * 60 * 60, 12 * 60 * 60);
    const expires = Math.floor(Date.now() / 1000) + ttl;

    // Token Authentication do Bunny: SHA256(chave + caminho + expiração),
    // em base64 url-safe.
    const token = createHash("sha256")
      .update(BUNNY_TOKEN_KEY.value() + path + expires)
      .digest("base64")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");

    return {
      url: `https://${hostname}${path}?token=${token}&expires=${expires}`,
      expires,
    };
  }
);

export const deleteBunnyVideo = onCall(
  { region: REGION, secrets: [BUNNY_STREAM_API_KEY] },
  async (request) => {
    await requireAdmin(request.auth?.uid);

    const { videoGuid } = request.data as { videoGuid: string };
    const libraryId = BUNNY_LIBRARY_ID.value();

    const response = await fetch(
      `${STREAM_API}/${libraryId}/videos/${videoGuid}`,
      {
        method: "DELETE",
        headers: { AccessKey: BUNNY_STREAM_API_KEY.value() },
      }
    );

    if (!response.ok) {
      throw new HttpsError("internal", "Não foi possível remover o vídeo.");
    }

    return { ok: true };
  }
);

/**
 * Webhook do Bunny: avisa quando o processamento termina.
 *
 * Melhor que polling — o painel recebe o aviso na hora e o app não fica
 * consultando status a cada seis segundos.
 *
 * Configure em: Stream > Library > Webhook URL.
 */
export const bunnyWebhook = onRequest({ region: REGION }, async (req, res) => {
  const { VideoGuid, Status } = req.body as {
    VideoGuid?: string;
    Status?: number;
  };

  if (!VideoGuid) {
    res.status(400).send("VideoGuid ausente");
    return;
  }

  logger.info("Webhook do Bunny", { VideoGuid, Status });

  // Atualiza toda aula que aponte para este vídeo.
  const lessons = await db()
    .collectionGroup("lessons")
    .where("videoGuid", "==", VideoGuid)
    .get();

  const batch = db().batch();
  lessons.docs.forEach((doc) =>
    batch.update(doc.ref, {
      videoStatus: Status,
      videoReady: Status === 4,
      updatedAt: FieldValue.serverTimestamp(),
    })
  );
  await batch.commit();

  res.status(200).send("ok");
});
