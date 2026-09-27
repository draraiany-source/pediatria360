/**
 * Comércio e telemedicina.
 *
 * ## Onde o preço é decidido
 *
 * O cliente envia **apenas ids e quantidades**. Todo valor cobrado é calculado
 * aqui, lendo o preço do Firestore no momento do pedido. Aceitar o total
 * enviado pelo app é o erro clássico de e-commerce: basta interceptar a
 * requisição e comprar por um centavo.
 *
 * ## Onde o horário é reservado
 *
 * Em transação. Dois pais tocando "agendar" no mesmo segundo não podem ficar
 * com o mesmo horário — sem transação, ficam.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { hasActiveBookingConflict, isPastAppointmentTime } from "./booking";

const REGION = "southamerica-east1";
const db = () => admin.firestore();

/** Frete grátis a partir deste valor. */
const FREE_SHIPPING_THRESHOLD_CENTS = 19900;
const DEFAULT_SHIPPING_CENTS = 2490;

interface RequestedItem {
  productId: string;
  quantity: number;
}

interface ResolvedItem {
  productId: string;
  name: string;
  unitPriceCents: number;
  quantity: number;
  imageUrl: string | null;
}

interface PriceResult {
  items: ResolvedItem[];
  subtotalCents: number;
  shippingCents: number;
  discountCents: number;
  totalCents: number;
  couponValid: boolean;
  couponMessage: string | null;
  unavailable: string[];
}

/**
 * Resolve o carrinho contra o catálogo real.
 *
 * Devolve o que existe, está publicado e tem estoque. O que não passa entra em
 * `unavailable`, para o app avisar em vez de cobrar por algo que não será
 * enviado.
 */
async function priceCart(
  items: RequestedItem[],
  couponCode?: string
): Promise<PriceResult> {
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Carrinho vazio.");
  }
  if (items.length > 50) {
    throw new HttpsError("invalid-argument", "Carrinho grande demais.");
  }

  const resolved: ResolvedItem[] = [];
  const unavailable: string[] = [];

  for (const item of items) {
    const quantity = Math.max(1, Math.min(Number(item.quantity) || 1, 20));
    const doc = await db().collection("products").doc(item.productId).get();

    if (!doc.exists) {
      unavailable.push(item.productId);
      continue;
    }

    const product = doc.data() ?? {};

    if (product.published !== true) {
      unavailable.push(product.name ?? item.productId);
      continue;
    }
    if ((product.stock ?? 0) < quantity) {
      unavailable.push(product.name ?? item.productId);
      continue;
    }
    // Produto com receita não é vendido pelo app; a compra passa por
    // conferência humana.
    if (product.requiresPrescription === true) {
      unavailable.push(product.name ?? item.productId);
      continue;
    }

    resolved.push({
      productId: doc.id,
      name: product.name ?? "",
      unitPriceCents: Number(product.priceCents) || 0,
      quantity,
      imageUrl: product.imageUrl ?? null,
    });
  }

  const subtotalCents = resolved.reduce(
    (sum, i) => sum + i.unitPriceCents * i.quantity,
    0
  );

  // --------------------------------------------------------------- Cupom
  let discountCents = 0;
  let couponValid = false;
  let couponMessage: string | null = null;

  if (couponCode) {
    const code = couponCode.trim().toUpperCase();
    const couponDoc = await db().collection("coupons").doc(code).get();

    if (!couponDoc.exists) {
      couponMessage = "Cupom não encontrado.";
    } else {
      const coupon = couponDoc.data() ?? {};
      const now = Timestamp.now();

      if (coupon.active !== true) {
        couponMessage = "Este cupom não está mais ativo.";
      } else if (coupon.expiresAt && coupon.expiresAt < now) {
        couponMessage = "Este cupom expirou.";
      } else if (
        coupon.maxUses &&
        (coupon.usedCount ?? 0) >= coupon.maxUses
      ) {
        couponMessage = "Este cupom atingiu o limite de usos.";
      } else if (
        coupon.minSubtotalCents &&
        subtotalCents < coupon.minSubtotalCents
      ) {
        const min = (coupon.minSubtotalCents / 100).toFixed(2);
        couponMessage = `Válido em compras acima de R$ ${min}.`;
      } else {
        couponValid = true;
        discountCents =
          coupon.type === "percent"
            ? Math.round((subtotalCents * (coupon.value ?? 0)) / 100)
            : Math.min(Number(coupon.value) || 0, subtotalCents);
        couponMessage = "Cupom aplicado.";
      }
    }
  }

  // O desconto nunca ultrapassa o subtotal: sem isso, um cupom generoso
  // geraria total negativo.
  discountCents = Math.min(discountCents, subtotalCents);

  const shippingCents =
    subtotalCents - discountCents >= FREE_SHIPPING_THRESHOLD_CENTS
      ? 0
      : DEFAULT_SHIPPING_CENTS;

  return {
    items: resolved,
    subtotalCents,
    shippingCents,
    discountCents,
    totalCents: subtotalCents - discountCents + shippingCents,
    couponValid,
    couponMessage,
    unavailable,
  };
}

/** Prévia do pedido, sem criar nada. */
export const quoteOrder = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Entre para continuar.");
  }

  const { items, couponCode } = request.data as {
    items: RequestedItem[];
    couponCode?: string;
  };

  const result = await priceCart(items, couponCode);

  // Compara com o preço que o app tinha no carrinho, para avisar mudanças.
  const priceChanges = (items as (RequestedItem & { unitPriceCents?: number })[])
    .map((requested) => {
      const found = result.items.find(
        (i) => i.productId === requested.productId
      );
      if (!found || requested.unitPriceCents === undefined) return null;
      if (requested.unitPriceCents === found.unitPriceCents) return null;
      return {
        productId: found.productId,
        name: found.name,
        oldPriceCents: requested.unitPriceCents,
        newPriceCents: found.unitPriceCents,
      };
    })
    .filter(Boolean);

  return { ...result, priceChanges };
});

/** Cria o pedido e reserva o estoque. */
export const createOrder = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { items, address, paymentMethod, couponCode } = request.data as {
    items: RequestedItem[];
    address: Record<string, string>;
    paymentMethod: string;
    couponCode?: string;
  };

  if (!address?.zipCode || !address?.street || !address?.number) {
    throw new HttpsError("invalid-argument", "Endereço incompleto.");
  }

  const priced = await priceCart(items, couponCode);

  if (priced.unavailable.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      `Itens indisponíveis: ${priced.unavailable.join(", ")}`
    );
  }
  if (priced.items.length === 0) {
    throw new HttpsError("invalid-argument", "Nenhum item disponível.");
  }

  const orderRef = db().collection("orders").doc();

  // Transação: baixa de estoque e criação do pedido acontecem juntas ou não
  // acontecem. Sem isso, dois pedidos simultâneos podem vender o mesmo último
  // item duas vezes.
  await db().runTransaction(async (tx) => {
    const productRefs = priced.items.map((i) =>
      db().collection("products").doc(i.productId)
    );
    const snapshots = await Promise.all(productRefs.map((r) => tx.get(r)));

    snapshots.forEach((snap, index) => {
      const stock = Number(snap.data()?.stock ?? 0);
      const needed = priced.items[index].quantity;
      if (stock < needed) {
        throw new HttpsError(
          "failed-precondition",
          `${priced.items[index].name} ficou sem estoque.`
        );
      }
      tx.update(productRefs[index], {
        stock: FieldValue.increment(-needed),
      });
    });

    tx.set(orderRef, {
      ownerId: uid,
      items: priced.items,
      subtotalCents: priced.subtotalCents,
      shippingCents: priced.shippingCents,
      discountCents: priced.discountCents,
      totalCents: priced.totalCents,
      couponCode: priced.couponValid ? couponCode?.toUpperCase() : null,
      status: "pending",
      paymentMethod,
      address,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (priced.couponValid && couponCode) {
      tx.update(db().collection("coupons").doc(couponCode.toUpperCase()), {
        usedCount: FieldValue.increment(1),
      });
    }
  });

  logger.info("Pedido criado", {
    orderId: orderRef.id,
    uid,
    totalCents: priced.totalCents,
  });

  // A URL de pagamento vem do gateway (Stripe, Mercado Pago, Pagar.me). A
  // integração é um passo à parte: o webhook do gateway é que muda o status
  // para "paid" — nunca o cliente.
  return {
    orderId: orderRef.id,
    totalCents: priced.totalCents,
    paymentUrl: null,
  };
});

// ------------------------------------------------------------ Telemedicina

/** Horários livres de um profissional numa data. */
export const getAvailability = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Entre para continuar.");
  }

  const { professionalId, date } = request.data as {
    professionalId: string;
    date: string;
  };

  const day = new Date(date);
  if (Number.isNaN(day.getTime())) {
    throw new HttpsError("invalid-argument", "Data inválida.");
  }

  const professional = await db().collection("users").doc(professionalId).get();
  const profile = professional.data() ?? {};

  if (profile.professionalVerified !== true) {
    throw new HttpsError("not-found", "Profissional não disponível.");
  }

  // Disponibilidade declarada: { "1": ["09:00","09:30", ...] } por dia da
  // semana (0 = domingo).
  const weekday = day.getUTCDay().toString();
  const declared: string[] = profile.availability?.[weekday] ?? [];
  const duration = Number(profile.consultationMinutes ?? 30);

  const dayStart = new Date(day);
  dayStart.setUTCHours(0, 0, 0, 0);
  const dayEnd = new Date(dayStart);
  dayEnd.setUTCDate(dayEnd.getUTCDate() + 1);

  const booked = await db()
    .collection("appointments")
    .where("professionalId", "==", professionalId)
    .where("startsAt", ">=", Timestamp.fromDate(dayStart))
    .where("startsAt", "<", Timestamp.fromDate(dayEnd))
    .get();

  const takenTimes = new Set(
    booked.docs
      .filter((d) => {
        const status = d.data().status;
        return status !== "cancelled" && status !== "noShow";
      })
      .map((d) => (d.data().startsAt as Timestamp).toMillis())
  );

  const now = Date.now();

  const slots = declared
    .map((time: string) => {
      const [hour, minute] = time.split(":").map(Number);
      const slot = new Date(dayStart);
      slot.setUTCHours(hour, minute, 0, 0);
      return slot;
    })
    // Horário que já passou não é oferecido.
    .filter((slot) => slot.getTime() > now)
    .map((slot) => ({
      startsAt: slot.toISOString(),
      durationMinutes: duration,
      available: !takenTimes.has(slot.getTime()),
    }));

  return { slots };
});

/** Agenda uma consulta, reservando o horário em transação. */
export const bookAppointment = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { professionalId, startsAt, childId, reason } = request.data as {
    professionalId: string;
    startsAt: string;
    childId?: string;
    reason?: string;
  };

  const start = new Date(startsAt);
  if (Number.isNaN(start.getTime())) {
    throw new HttpsError("invalid-argument", "Horário inválido.");
  }
  if (isPastAppointmentTime(start, new Date())) {
    throw new HttpsError("invalid-argument", "Este horário já passou.");
  }

  const professionalDoc = await db()
    .collection("users")
    .doc(professionalId)
    .get();
  const professional = professionalDoc.data() ?? {};

  if (professional.professionalVerified !== true) {
    throw new HttpsError("not-found", "Profissional não disponível.");
  }

  let childName: string | null = null;
  if (childId) {
    const childDoc = await db()
      .collection("users")
      .doc(uid)
      .collection("children")
      .doc(childId)
      .get();
    childName = (childDoc.data()?.name as string) ?? null;
  }

  const appointmentRef = db().collection("appointments").doc();
  const timestamp = Timestamp.fromDate(start);

  await db().runTransaction(async (tx) => {
    // Relê o horário dentro da transação: entre a consulta da agenda e o
    // toque em "agendar", outra pessoa pode ter reservado.
    const conflicting = await tx.get(
      db()
        .collection("appointments")
        .where("professionalId", "==", professionalId)
        .where("startsAt", "==", timestamp)
    );

    const active = conflicting.docs.filter((d) =>
      hasActiveBookingConflict([d.data().status])
    );

    if (active.length > 0) {
      throw new HttpsError(
        "already-exists",
        "Este horário acabou de ser ocupado. Escolha outro."
      );
    }

    tx.set(appointmentRef, {
      patientId: uid,
      professionalId,
      professionalName: professional.name ?? "",
      specialty: professional.specialty ?? null,
      startsAt: timestamp,
      durationMinutes: Number(professional.consultationMinutes ?? 30),
      priceCents: Number(professional.consultationPriceCents ?? 0),
      status: "requested",
      paid: false,
      childId: childId ?? null,
      childName,
      reason: reason?.slice(0, 500) ?? null,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return { appointmentId: appointmentRef.id };
});

/**
 * Entra na sala de vídeo.
 *
 * A URL é gerada na hora e vale pouco tempo. Guardar um link permanente no
 * documento significaria que qualquer pessoa com acesso ao histórico poderia
 * entrar numa consulta pediátrica alheia.
 */
export const joinConsultation = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const { appointmentId } = request.data as { appointmentId: string };

  const doc = await db().collection("appointments").doc(appointmentId).get();
  if (!doc.exists) {
    throw new HttpsError("not-found", "Consulta não encontrada.");
  }

  const appointment = doc.data() ?? {};

  if (appointment.patientId !== uid && appointment.professionalId !== uid) {
    throw new HttpsError("permission-denied", "Você não participa desta consulta.");
  }

  const start = (appointment.startsAt as Timestamp).toDate();
  const end = new Date(
    start.getTime() + (appointment.durationMinutes ?? 30) * 60000
  );
  const now = new Date();

  // Janela: 10 min antes até 15 min depois do fim previsto.
  if (now < new Date(start.getTime() - 10 * 60000)) {
    throw new HttpsError(
      "failed-precondition",
      "A sala abre 10 minutos antes do horário."
    );
  }
  if (now > new Date(end.getTime() + 15 * 60000)) {
    throw new HttpsError("failed-precondition", "Esta consulta já encerrou.");
  }

  // ------------------------------------------------------------------
  // INTEGRAÇÃO PENDENTE: sala de vídeo
  //
  // Aqui entra a chamada ao provedor escolhido (Daily.co, Whereby, Twilio
  // Video) para criar uma sala efêmera e devolver um token por participante.
  //
  // Videoconferência médica não é só WebRTC: envolve consentimento de
  // gravação, retenção, e conformidade com LGPD e com as resoluções do CFM
  // sobre telemedicina. É um produto à parte, não uma tela — por isso o
  // provedor é externo e a decisão de qual usar fica com quem conhece os
  // requisitos regulatórios do negócio.
  //
  // Exemplo com Daily.co:
  //   const room = await fetch("https://api.daily.co/v1/rooms", {
  //     method: "POST",
  //     headers: { Authorization: `Bearer ${DAILY_API_KEY.value()}` },
  //     body: JSON.stringify({
  //       properties: { exp: Math.floor(end.getTime()/1000) + 900 },
  //     }),
  //   });
  // ------------------------------------------------------------------

  // A mensagem devolvida ao cliente é só o que o usuário precisa ler —
  // sem nome de arquivo nem de função. O contexto para quem for implementar
  // fica no comentário acima, não no texto que aparece na tela.
  throw new HttpsError(
    "unimplemented",
    "A videochamada ainda não está disponível nesta versão. Em caso de " +
      "urgência, procure atendimento presencial ou ligue para o SAMU (192)."
  );
});
