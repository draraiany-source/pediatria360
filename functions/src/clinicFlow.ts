/**
 * Fluxo da clínica: solicitação de paciente novo, convite ao responsável e
 * equipe da clínica.
 *
 * 1. A recepção (ou o profissional, para si) registra a solicitação:
 *    createClinicIntake. Fica em clinic_intakes, sem id de criança e sem
 *    dado clínico; o horário pedido fica reservado.
 * 2. O responsável recebe o código (WhatsApp/e-mail fora do app) e, com a
 *    conta do e-mail informado à clínica e e-mail confirmado, vê a prévia
 *    (previewClinicIntake) e aceita para uma criança que já é dele
 *    (acceptClinicIntake). Só então nasce a consulta. Acesso clínico é
 *    escolha separada na mesma tela: nenhum, só resumo, ou resumo e
 *    prontuário, com validade.
 * 3. O profissional atende quando houver a concessão; a recepção organiza
 *    a agenda sem ver prontuário.
 *
 * Equipe: addClinicMember / setClinicMemberStatus, só pela gestão da
 * clínica. Recepção e financeiro não precisam de registro profissional.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { hasActiveBookingConflict } from "./booking";
import { childOwnerUid, grantRef } from "./childAccess";
import {
  ASSIGNABLE_ROLES,
  CARE_ROLES,
  CLINICAL_ROLES,
  INTAKE_DESK_ROLES,
  IntakeValidationError,
  attemptsBlocked,
  canRegisterIntake,
  formatInviteCode,
  generateInviteCode,
  hashInviteCode,
  intakeDedupeKey,
  inviteExpiresAtMs,
  normalizeEmail,
  normalizeInviteCode,
  parseGrantDays,
  parseGuardianScopes,
  parseIntakeInput,
  registerFailedAttempt,
} from "./intake";

const REGION = "southamerica-east1";
const db = () => admin.firestore();
const DAY_MS = 24 * 60 * 60 * 1000;

const INVALID_CODE = "Código inválido, já usado ou vencido.";

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");
  return uid;
}

function asHttps(e: unknown): never {
  if (e instanceof IntakeValidationError) {
    throw new HttpsError("invalid-argument", e.message);
  }
  throw e;
}

/**
 * Papel ativo do usuário na clínica, conferido nas duas pontas: a cópia do
 * usuário e o documento da clínica (que é o que vale). Mesma checagem de
 * isClinicMember nas regras.
 */
export async function clinicRoleOf(clinicId: string, uid: string): Promise<string | null> {
  const mirror = await db()
    .collection("users")
    .doc(uid)
    .collection("clinic_memberships")
    .doc(clinicId)
    .get();
  const m = mirror.data();
  if (!m || m.active !== true || m.userId !== uid || m.clinicId !== clinicId) return null;
  const membershipId = typeof m.id === "string" && m.id ? m.id : uid;
  const side = await db()
    .collection("clinics")
    .doc(clinicId)
    .collection("memberships")
    .doc(membershipId)
    .get();
  const s = side.data();
  if (!s || s.active !== true || s.userId !== uid) return null;
  return typeof s.role === "string" ? s.role : null;
}

async function clinicName(clinicId: string | null): Promise<string | null> {
  if (!clinicId) return null;
  const c = (await db().collection("clinics").doc(clinicId).get()).data();
  if (!c) return null;
  return (c.tradeName as string) || (c.name as string) || null;
}

async function audit(clinicId: string | null, entry: Record<string, unknown>) {
  const payload = { ...entry, at: FieldValue.serverTimestamp() };
  if (clinicId) {
    await db().collection("clinics").doc(clinicId).collection("audit_logs").add(payload);
  } else {
    await db().collection("audit_log").add(payload);
  }
}

function intakeCodeRef(hash: string) {
  return db().collection("clinic_intake_codes").doc(hash);
}

function intakePrivateRef(intakeId: string) {
  return db().collection("clinic_intakes").doc(intakeId).collection("private").doc("invite");
}

/** Quem pode cancelar ou renovar: balcão da clínica, quem criou ou o profissional. */
async function requireIntakeManager(uid: string, intake: Record<string, unknown>) {
  if (intake.createdBy === uid || intake.professionalId === uid) return;
  const clinicId = (intake.clinicId as string | null) ?? null;
  if (clinicId) {
    const role = await clinicRoleOf(clinicId, uid);
    if (role && INTAKE_DESK_ROLES.includes(role)) return;
  }
  throw new HttpsError("permission-denied", "Sem permissão para esta solicitação.");
}

// ------------------------------------------------------------- Solicitação

export const createClinicIntake = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  let input;
  try {
    input = parseIntakeInput(request.data, Date.now());
  } catch (e) {
    asHttps(e);
  }

  let callerRole: string | null = null;
  if (input.clinicId) {
    callerRole = await clinicRoleOf(input.clinicId, uid);
    if (!canRegisterIntake(callerRole, uid, input.professionalId)) {
      throw new HttpsError(
        "permission-denied",
        "Só a recepção, a gestão ou o próprio profissional registram solicitações."
      );
    }
    const professionalRole = await clinicRoleOf(input.clinicId, input.professionalId);
    if (!professionalRole || !CARE_ROLES.includes(professionalRole)) {
      throw new HttpsError(
        "failed-precondition",
        "O profissional escolhido não atende nesta clínica."
      );
    }
  } else if (input.professionalId !== uid) {
    // Sem clínica: só o profissional, para a própria agenda.
    throw new HttpsError("permission-denied", "Escolha uma clínica.");
  }

  const professional = (await db().collection("users").doc(input.professionalId).get()).data();
  if (!professional || professional.professionalVerified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "O profissional ainda não tem o registro conferido."
    );
  }

  const nowMs = Date.now();
  const startsAt = Timestamp.fromMillis(input.startsAtMs);
  const expiresAt = Timestamp.fromMillis(inviteExpiresAtMs(nowMs, input.startsAtMs));
  const dedupeKey = intakeDedupeKey(input);
  const code = generateInviteCode();
  const codeHash = hashInviteCode(code);
  const intakeRef = db().collection("clinic_intakes").doc();
  const cName = await clinicName(input.clinicId);

  await db().runTransaction(async (tx) => {
    const duplicate = await tx.get(
      db()
        .collection("clinic_intakes")
        .where("dedupeKey", "==", dedupeKey)
        .where("status", "==", "pendingGuardian")
        .limit(1)
    );
    if (!duplicate.empty) {
      throw new HttpsError(
        "already-exists",
        "Já existe solicitação pendente para esta criança e este responsável. Renove o código dela."
      );
    }

    const booked = await tx.get(
      db()
        .collection("appointments")
        .where("professionalId", "==", input.professionalId)
        .where("startsAt", "==", startsAt)
    );
    if (hasActiveBookingConflict(booked.docs.map((d) => d.data().status as string | undefined))) {
      throw new HttpsError("already-exists", "Horário já ocupado na agenda do profissional.");
    }

    const reserved = await tx.get(
      db()
        .collection("clinic_intakes")
        .where("professionalId", "==", input.professionalId)
        .where("requestedStartsAt", "==", startsAt)
        .where("status", "==", "pendingGuardian")
        .limit(1)
    );
    if (!reserved.empty) {
      throw new HttpsError(
        "already-exists",
        "Horário reservado para outra solicitação aguardando o responsável."
      );
    }

    const codeSnap = await tx.get(intakeCodeRef(codeHash));
    if (codeSnap.exists) {
      throw new HttpsError("aborted", "Tente novamente.");
    }

    tx.set(intakeRef, {
      clinicId: input.clinicId,
      clinicName: cName,
      professionalId: input.professionalId,
      professionalName: (professional.name as string) ?? "",
      specialty: (professional.specialty as string) ?? null,
      childName: input.childName,
      childBirthDate: input.childBirthDate,
      guardianName: input.guardianName,
      guardianEmail: input.guardianEmail,
      guardianPhone: input.guardianPhone,
      requestedStartsAt: startsAt,
      durationMinutes: input.durationMinutes,
      reason: input.reason,
      status: "pendingGuardian",
      dedupeKey,
      createdBy: uid,
      createdByRole: callerRole,
      createdAt: FieldValue.serverTimestamp(),
      inviteExpiresAt: expiresAt,
      linkedOwnerUid: null,
      linkedChildId: null,
      appointmentId: null,
    });
    tx.set(intakeCodeRef(codeHash), {
      intakeId: intakeRef.id,
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(intakePrivateRef(intakeRef.id), {
      codeHash,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  await audit(input.clinicId, {
    action: "intake_created",
    intakeId: intakeRef.id,
    actorUid: uid,
    professionalId: input.professionalId,
  });

  return {
    intakeId: intakeRef.id,
    inviteCode: formatInviteCode(code),
    expiresAt: expiresAt.toDate().toISOString(),
  };
});

export const cancelClinicIntake = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const { intakeId, reason } = (request.data ?? {}) as { intakeId?: string; reason?: string };
  if (!intakeId || typeof intakeId !== "string") {
    throw new HttpsError("invalid-argument", "Solicitação não informada.");
  }
  const ref = db().collection("clinic_intakes").doc(intakeId);
  const snap = await ref.get();
  const intake = snap.data();
  if (!intake) throw new HttpsError("not-found", "Solicitação não encontrada.");
  await requireIntakeManager(uid, intake);

  await db().runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    const priv = await tx.get(intakePrivateRef(intakeId));
    if (fresh.get("status") !== "pendingGuardian") {
      throw new HttpsError("failed-precondition", "A solicitação não está mais pendente.");
    }
    tx.update(ref, {
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: uid,
      cancelReason: typeof reason === "string" ? reason.slice(0, 300) : null,
    });
    const hash = priv.get("codeHash");
    if (typeof hash === "string") tx.delete(intakeCodeRef(hash));
  });

  await audit((intake.clinicId as string | null) ?? null, {
    action: "intake_cancelled",
    intakeId,
    actorUid: uid,
  });
  return { ok: true };
});

/** Novo código; o anterior deixa de valer. */
export const renewClinicIntakeCode = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const { intakeId } = (request.data ?? {}) as { intakeId?: string };
  if (!intakeId || typeof intakeId !== "string") {
    throw new HttpsError("invalid-argument", "Solicitação não informada.");
  }
  const ref = db().collection("clinic_intakes").doc(intakeId);
  const intake = (await ref.get()).data();
  if (!intake) throw new HttpsError("not-found", "Solicitação não encontrada.");
  await requireIntakeManager(uid, intake);

  const nowMs = Date.now();
  const startsMs = (intake.requestedStartsAt as Timestamp).toMillis();
  if (startsMs <= nowMs) {
    throw new HttpsError("failed-precondition", "O horário pedido já passou. Cancele e registre de novo.");
  }
  const code = generateInviteCode();
  const codeHash = hashInviteCode(code);
  const expiresAt = Timestamp.fromMillis(inviteExpiresAtMs(nowMs, startsMs));

  await db().runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    const priv = await tx.get(intakePrivateRef(intakeId));
    const clash = await tx.get(intakeCodeRef(codeHash));
    if (fresh.get("status") !== "pendingGuardian") {
      throw new HttpsError("failed-precondition", "A solicitação não está mais pendente.");
    }
    if (clash.exists) throw new HttpsError("aborted", "Tente novamente.");
    const old = priv.get("codeHash");
    if (typeof old === "string") tx.delete(intakeCodeRef(old));
    tx.set(intakeCodeRef(codeHash), {
      intakeId,
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(intakePrivateRef(intakeId), { codeHash, createdAt: FieldValue.serverTimestamp() });
    tx.update(ref, { inviteExpiresAt: expiresAt, inviteRenewedAt: FieldValue.serverTimestamp() });
  });

  await audit((intake.clinicId as string | null) ?? null, {
    action: "intake_code_renewed",
    intakeId,
    actorUid: uid,
  });
  return { inviteCode: formatInviteCode(code), expiresAt: expiresAt.toDate().toISOString() };
});

// ------------------------------------------------------------------ Convite

function attemptsRef(uid: string) {
  return db().collection("intake_attempts").doc(uid);
}

async function guardAttempts(uid: string) {
  const state = (await attemptsRef(uid).get()).data() as
    | { count?: number; windowStartMs?: number }
    | undefined;
  if (attemptsBlocked(state, Date.now())) {
    throw new HttpsError(
      "resource-exhausted",
      "Muitas tentativas com código inválido. Tente de novo mais tarde."
    );
  }
}

async function failAttempt(uid: string): Promise<never> {
  const ref = attemptsRef(uid);
  await db().runTransaction(async (tx) => {
    const prev = (await tx.get(ref)).data() as
      | { count?: number; windowStartMs?: number }
      | undefined;
    tx.set(ref, registerFailedAttempt(prev, Date.now()));
  });
  throw new HttpsError("not-found", INVALID_CODE);
}

/**
 * Conta de quem aceita: e-mail confirmado e igual ao que a clínica
 * registrou. O código sozinho, vazado ou repassado, não basta.
 */
function requireGuardianEmail(request: CallableRequest, intake: Record<string, unknown>) {
  const token = (request.auth?.token ?? {}) as { email?: string; email_verified?: boolean };
  const email = normalizeEmail(token.email);
  if (!email || token.email_verified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Confirme o e-mail da sua conta antes de aceitar o convite."
    );
  }
  if (email !== intake.guardianEmail) {
    throw new HttpsError(
      "permission-denied",
      "Este convite foi enviado para outro e-mail. Entre com a conta do e-mail informado à clínica."
    );
  }
}

async function loadIntakeByCode(uid: string, rawCode: unknown) {
  await guardAttempts(uid);
  const code = normalizeInviteCode(rawCode);
  if (!code) return failAttempt(uid);
  const codeSnap = await intakeCodeRef(hashInviteCode(code)).get();
  const intakeId = codeSnap.get("intakeId");
  if (!codeSnap.exists || typeof intakeId !== "string") return failAttempt(uid);
  const intakeSnap = await db().collection("clinic_intakes").doc(intakeId).get();
  const intake = intakeSnap.data();
  const expires = intake?.inviteExpiresAt as Timestamp | undefined;
  if (
    !intake ||
    intake.status !== "pendingGuardian" ||
    !expires ||
    expires.toMillis() <= Date.now()
  ) {
    return failAttempt(uid);
  }
  return { code, intakeId, intake };
}

export const previewClinicIntake = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const { intake } = await loadIntakeByCode(uid, (request.data ?? {}).code);
  requireGuardianEmail(request, intake);
  return {
    clinicName: intake.clinicName ?? null,
    professionalName: intake.professionalName ?? "",
    specialty: intake.specialty ?? null,
    startsAt: (intake.requestedStartsAt as Timestamp).toDate().toISOString(),
    durationMinutes: intake.durationMinutes ?? 30,
    childName: intake.childName ?? "",
    childBirthDate: intake.childBirthDate ?? null,
    guardianName: intake.guardianName ?? "",
    expiresAt: (intake.inviteExpiresAt as Timestamp).toDate().toISOString(),
  };
});

export const acceptClinicIntake = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as {
    code?: string;
    childId?: string;
    scopes?: unknown;
    days?: unknown;
  };
  let scopes: string[];
  let days = 0;
  try {
    scopes = parseGuardianScopes(data.scopes);
    if (scopes.length > 0) days = parseGrantDays(data.days);
  } catch (e) {
    asHttps(e);
  }

  const { code, intakeId, intake } = await loadIntakeByCode(uid, data.code);
  requireGuardianEmail(request, intake);

  // A criança precisa ser do titular autenticado, pelo child_registry. Não
  // se cria nem se assume criança por aqui.
  const childId = data.childId;
  if (typeof childId !== "string" || !childId || (await childOwnerUid(childId)) !== uid) {
    throw new HttpsError(
      "permission-denied",
      "Escolha uma criança cadastrada na sua conta."
    );
  }
  const childSnap = await db()
    .collection("users")
    .doc(uid)
    .collection("children")
    .doc(childId)
    .get();
  if (!childSnap.exists) {
    throw new HttpsError("permission-denied", "Escolha uma criança cadastrada na sua conta.");
  }

  const codeRef = intakeCodeRef(hashInviteCode(code));
  const intakeRef = db().collection("clinic_intakes").doc(intakeId);
  const professionalId = intake.professionalId as string;
  const clinicId = (intake.clinicId as string | null) ?? null;
  const startsAt = intake.requestedStartsAt as Timestamp;
  const appointmentRef = db().collection("appointments").doc();
  const gRef = grantRef(uid, childId, professionalId);
  const nowMs = Date.now();

  await db().runTransaction(async (tx) => {
    const codeSnap = await tx.get(codeRef);
    const fresh = await tx.get(intakeRef);
    const booked = await tx.get(
      db()
        .collection("appointments")
        .where("professionalId", "==", professionalId)
        .where("startsAt", "==", startsAt)
    );
    if (!codeSnap.exists || codeSnap.get("intakeId") !== intakeId ||
        fresh.get("status") !== "pendingGuardian") {
      throw new HttpsError("not-found", INVALID_CODE);
    }
    if (hasActiveBookingConflict(booked.docs.map((d) => d.data().status as string | undefined))) {
      throw new HttpsError(
        "failed-precondition",
        "O horário reservado não está mais livre. Fale com a clínica para remarcar."
      );
    }

    tx.set(appointmentRef, {
      patientId: uid,
      childId,
      childName: (childSnap.get("name") as string) ?? intake.childName ?? null,
      professionalId,
      professionalName: intake.professionalName ?? "",
      specialty: intake.specialty ?? null,
      clinicId,
      startsAt,
      durationMinutes: intake.durationMinutes ?? 30,
      type: "primeiraConsulta",
      status: "confirmed",
      workflowStatus: "scheduled",
      paid: false,
      reason: intake.reason ?? null,
      origin: "clinicIntake",
      intakeId,
      createdBy: intake.createdBy ?? null,
      confirmedBy: uid,
      confirmedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(intakeRef, {
      status: "linked",
      linkedOwnerUid: uid,
      linkedChildId: childId,
      appointmentId: appointmentRef.id,
      acceptedAt: FieldValue.serverTimestamp(),
      grantScopes: scopes,
    });
    tx.delete(codeRef);

    if (scopes.length > 0) {
      tx.set(gRef, {
        scopes,
        source: "guardianInvite",
        authorizedBy: uid,
        grantedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(nowMs + days * DAY_MS),
        revokedAt: null,
        clinicId,
        professionalName: intake.professionalName ?? "",
        clinicName: intake.clinicName ?? null,
        intakeId,
      });
    }
  });

  await audit(clinicId, {
    action: "intake_accepted",
    intakeId,
    appointmentId: appointmentRef.id,
    actorUid: uid,
    scopes,
  });
  if (scopes.length > 0) {
    await db().collection("audit_log").add({
      action: "child_access_granted",
      childId,
      professionalUid: professionalId,
      scopes,
      source: "guardianInvite",
      intakeId,
      actorUid: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  logger.info("Convite da clínica aceito", { intakeId, appointmentId: appointmentRef.id });

  return {
    appointmentId: appointmentRef.id,
    startsAt: startsAt.toDate().toISOString(),
    professionalName: intake.professionalName ?? "",
    clinicName: intake.clinicName ?? null,
    scopes,
  };
});

// ----------------------------------------------------- Profissional (busca)

/**
 * Para o responsável escolher a quem autorizar: devolve só nome e
 * especialidade de profissional com registro conferido. Não lista contas.
 */
export const lookupProfessional = onCall({ region: REGION }, async (request) => {
  requireUid(request);
  const email = normalizeEmail((request.data ?? {}).email);
  if (!email) throw new HttpsError("invalid-argument", "Informe o e-mail do profissional.");
  let uid: string;
  try {
    uid = (await admin.auth().getUserByEmail(email)).uid;
  } catch {
    throw new HttpsError("not-found", "Nenhum profissional verificado com este e-mail.");
  }
  const user = (await db().collection("users").doc(uid).get()).data();
  if (!user || user.role !== "professional" || user.professionalVerified !== true) {
    throw new HttpsError("not-found", "Nenhum profissional verificado com este e-mail.");
  }
  return {
    uid,
    name: (user.name as string) ?? "",
    specialty: (user.specialty as string) ?? null,
  };
});

// ----------------------------------------------------------------- Equipe

async function requireClinicAdmin(clinicId: unknown, uid: string): Promise<string> {
  if (typeof clinicId !== "string" || !clinicId) {
    throw new HttpsError("invalid-argument", "Clínica não informada.");
  }
  if ((await clinicRoleOf(clinicId, uid)) !== "clinicAdmin") {
    throw new HttpsError("permission-denied", "Só a gestão da clínica altera a equipe.");
  }
  return clinicId;
}

/**
 * Inclui na clínica uma conta existente, pelo e-mail. Se a pessoa já tem
 * vínculo com esta clínica, atualiza papel e reativa (sem duplicar).
 */
export const addClinicMember = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const { clinicId: rawClinic, email: rawEmail, role } = (request.data ?? {}) as {
    clinicId?: string;
    email?: string;
    role?: string;
  };
  const clinicId = await requireClinicAdmin(rawClinic, uid);
  const email = normalizeEmail(rawEmail);
  if (!email) throw new HttpsError("invalid-argument", "E-mail inválido.");
  if (typeof role !== "string" || !ASSIGNABLE_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "Papel inválido.");
  }

  let memberUid: string;
  try {
    memberUid = (await admin.auth().getUserByEmail(email)).uid;
  } catch {
    throw new HttpsError(
      "not-found",
      "Não há conta com este e-mail. Peça para a pessoa criar a conta no app primeiro."
    );
  }
  const memberUser = (await db().collection("users").doc(memberUid).get()).data() ?? {};
  if (CLINICAL_ROLES.includes(role) && memberUser.role !== "professional") {
    throw new HttpsError(
      "failed-precondition",
      "Papel clínico exige conta de profissional de saúde."
    );
  }

  const cName = (await clinicName(clinicId)) ?? "";
  const mirrorRef = db()
    .collection("users")
    .doc(memberUid)
    .collection("clinic_memberships")
    .doc(clinicId);

  const result = await db().runTransaction(async (tx) => {
    const mirror = await tx.get(mirrorRef);
    const existingId = mirror.get("id");
    const sideRef =
      typeof existingId === "string" && existingId
        ? db().collection("clinics").doc(clinicId).collection("memberships").doc(existingId)
        : db().collection("clinics").doc(clinicId).collection("memberships").doc();
    const side = await tx.get(sideRef);
    const createdAt =
      (side.get("createdAt") as string | undefined) ?? new Date().toISOString();
    const membership = {
      id: sideRef.id,
      clinicId,
      userId: memberUid,
      role,
      clinicName: cName,
      unitIds: (side.get("unitIds") as string[] | undefined) ?? [],
      active: true,
      name: (memberUser.name as string) ?? "",
      crm: (memberUser.crm as string) ?? "",
      specialty: (memberUser.specialty as string) ?? "",
      createdAt,
    };
    tx.set(sideRef, { ...membership, updatedBy: uid });
    tx.set(mirrorRef, membership);
    return { membershipId: sideRef.id, existed: side.exists };
  });

  await audit(clinicId, {
    action: result.existed ? "member_updated" : "member_added",
    membershipId: result.membershipId,
    memberUid,
    role,
    actorUid: uid,
  });
  return { ...result, name: (memberUser.name as string) ?? "" };
});

/** Ativa/desativa ou troca o papel. Não deixa a clínica sem gestor. */
export const setClinicMemberStatus = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const { clinicId: rawClinic, membershipId, active, role } = (request.data ?? {}) as {
    clinicId?: string;
    membershipId?: string;
    active?: boolean;
    role?: string;
  };
  const clinicId = await requireClinicAdmin(rawClinic, uid);
  if (typeof membershipId !== "string" || !membershipId) {
    throw new HttpsError("invalid-argument", "Vínculo não informado.");
  }
  if (typeof active !== "boolean") {
    throw new HttpsError("invalid-argument", "Informe se o vínculo fica ativo.");
  }
  if (role !== undefined && (typeof role !== "string" || !ASSIGNABLE_ROLES.includes(role))) {
    throw new HttpsError("invalid-argument", "Papel inválido.");
  }

  const sideRef = db().collection("clinics").doc(clinicId).collection("memberships").doc(membershipId);
  await db().runTransaction(async (tx) => {
    const side = await tx.get(sideRef);
    if (!side.exists) throw new HttpsError("not-found", "Vínculo não encontrado.");
    const memberUid = side.get("userId") as string;
    const newRole = role ?? (side.get("role") as string);
    const losingAdmin =
      side.get("role") === "clinicAdmin" && (newRole !== "clinicAdmin" || !active);
    if (losingAdmin) {
      const admins = await tx.get(
        db()
          .collection("clinics")
          .doc(clinicId)
          .collection("memberships")
          .where("role", "==", "clinicAdmin")
          .where("active", "==", true)
      );
      if (admins.size <= 1) {
        throw new HttpsError("failed-precondition", "A clínica precisa de pelo menos um gestor ativo.");
      }
    }
    if (CLINICAL_ROLES.includes(newRole)) {
      const u = await tx.get(db().collection("users").doc(memberUid));
      if (u.get("role") !== "professional") {
        throw new HttpsError("failed-precondition", "Papel clínico exige conta de profissional de saúde.");
      }
    }
    const mirrorRef = db()
      .collection("users")
      .doc(memberUid)
      .collection("clinic_memberships")
      .doc(clinicId);
    tx.update(sideRef, { active, role: newRole, updatedBy: uid });
    tx.set(mirrorRef, { ...side.data(), active, role: newRole, updatedBy: FieldValue.delete() }, { merge: true });
  });

  await audit(clinicId, {
    action: "member_status_changed",
    membershipId,
    active,
    role: role ?? null,
    actorUid: uid,
  });
  return { ok: true };
});
