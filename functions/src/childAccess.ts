/**
 * Vínculo profissional–criança, conferido no servidor.
 *
 * As Functions rodam com Admin SDK e passam por cima das regras do
 * Firestore; por isso repetem aqui a mesma política de
 * `firestore.rules` (grantIsActive / canWriteChart):
 *
 * - a concessão fica em
 *   users/{dono}/children/{criança}/authorized_professionals/{profissional};
 * - só vale com escopo, validade e sem revogação. Concessão antiga (só
 *   `grantedAt`) não vale;
 * - `summary` lê o cadastro; `chartWrite` grava no prontuário. Um não
 *   implica o outro;
 * - o dono da criança é o do child_registry, nunca um campo enviado pelo
 *   cliente.
 *
 * Ser profissional verificado, ser dono de clínica, conhecer os ids ou ter
 * criado uma consulta não bastam.
 */

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export type GrantScope = "summary" | "chartWrite";

export const GRANT_SCOPES: readonly GrantScope[] = ["summary", "chartWrite"];
export const GRANT_SOURCES = ["guardian", "familyAppointment"] as const;

/** Validade da concessão criada a partir de consulta pedida pela família. */
export const FAMILY_GRANT_DAYS = 180;

/** Status em que uma consulta pedida pela família ainda autoriza o vínculo. */
export const ACTIVE_APPOINTMENT_STATUSES = ["requested", "confirmed", "inProgress"];

const DAY_MS = 24 * 60 * 60 * 1000;

interface TimestampLike {
  toMillis(): number;
}

function millisOf(value: unknown): number | null {
  if (value && typeof (value as TimestampLike).toMillis === "function") {
    return (value as TimestampLike).toMillis();
  }
  return null;
}

/**
 * A concessão permite `scope` agora, na clínica informada?
 *
 * `clinicId` só pesa quando a concessão é restrita a uma clínica: nesse
 * caso, o registro precisa ser dessa clínica.
 */
export function grantAllows(
  grant: Record<string, unknown> | undefined | null,
  scope: GrantScope,
  nowMs: number,
  clinicId: string | null = null
): boolean {
  if (!grant) return false;
  if (!GRANT_SOURCES.includes(grant.source as (typeof GRANT_SOURCES)[number])) {
    return false;
  }
  const scopes = grant.scopes;
  if (!Array.isArray(scopes) || !scopes.includes(scope)) return false;
  const expiresAt = millisOf(grant.expiresAt);
  if (expiresAt === null || expiresAt <= nowMs) return false;
  if (grant.revokedAt != null) return false;
  const grantClinic = grant.clinicId ?? null;
  if (grantClinic !== null && grantClinic !== clinicId) return false;
  return true;
}

/**
 * A consulta prova pedido da família para este profissional e esta criança?
 *
 * `requestedBy` só é gravado pelo próprio titular (regra de criação) ou por
 * `bookAppointment`, e não muda depois. Consulta marcada pela equipe não
 * conta: marcar consulta não cria vínculo.
 */
export function isFamilyRequestFor(
  appointment: Record<string, unknown> | undefined | null,
  params: { ownerUid: string; childId: string; professionalUid: string }
): boolean {
  if (!appointment) return false;
  return (
    appointment.patientId === params.ownerUid &&
    appointment.requestedBy === params.ownerUid &&
    appointment.childId === params.childId &&
    appointment.professionalId === params.professionalUid &&
    ACTIVE_APPOINTMENT_STATUSES.includes(appointment.status as string)
  );
}

/**
 * Concessão revogada pelo responsável só volta com pedido novo da família,
 * feito depois da revogação.
 */
export function revocationBlocksRequest(
  existing: Record<string, unknown> | undefined | null,
  appointmentCreatedMs: number | null
): boolean {
  if (!existing || existing.revokedAt == null) return false;
  const revokedMs = millisOf(existing.revokedAt);
  if (revokedMs === null || appointmentCreatedMs === null) return true;
  return appointmentCreatedMs <= revokedMs;
}

/** Concessão gravada pela Function a partir do pedido da família. */
export function familyAppointmentGrant(params: {
  ownerUid: string;
  appointmentId: string;
  nowMs: number;
}) {
  return {
    scopes: ["summary", "chartWrite"] as GrantScope[],
    source: "familyAppointment" as const,
    authorizedBy: params.ownerUid,
    appointmentId: params.appointmentId,
    expiresAtMs: params.nowMs + FAMILY_GRANT_DAYS * DAY_MS,
    revokedAt: null,
    clinicId: null,
  };
}

export function grantRef(ownerUid: string, childId: string, professionalUid: string) {
  return admin
    .firestore()
    .collection("users")
    .doc(ownerUid)
    .collection("children")
    .doc(childId)
    .collection("authorized_professionals")
    .doc(professionalUid);
}

/** Dono da criança pelo child_registry. */
export async function childOwnerUid(childId: string): Promise<string | null> {
  if (!childId || typeof childId !== "string") return null;
  const registry = await admin.firestore().collection("child_registry").doc(childId).get();
  const owner = registry.get("ownerUid");
  return typeof owner === "string" && owner ? owner : null;
}

/**
 * Exige concessão ativa com `scope` para o profissional nesta criança.
 * Devolve o dono da criança.
 */
export async function requireChildAccess(
  professionalUid: string,
  childId: unknown,
  scope: GrantScope,
  clinicId: string | null = null
): Promise<{ ownerUid: string }> {
  const denied = new HttpsError(
    "permission-denied",
    "Sem autorização do responsável para este acesso à criança."
  );
  if (typeof childId !== "string" || !childId) throw denied;
  const ownerUid = await childOwnerUid(childId);
  if (!ownerUid) throw denied;
  const grant = await grantRef(ownerUid, childId, professionalUid).get();
  if (!grantAllows(grant.data(), scope, Date.now(), clinicId)) throw denied;
  return { ownerUid };
}
