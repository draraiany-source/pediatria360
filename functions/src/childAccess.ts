/**
 * Vínculo profissional–criança, conferido no servidor.
 *
 * As Functions rodam com Admin SDK e passam por cima das regras do
 * Firestore; por isso repetem aqui a mesma política de
 * `firestore.rules` (grantIsActive / canWriteChart):
 *
 * - a concessão fica em
 *   users/{dono}/children/{criança}/authorized_professionals/{profissional};
 * - nasce só de escolha explícita do titular: pelo app (`guardian`) ou ao
 *   aceitar o convite da clínica (`guardianInvite`). Existir consulta não
 *   concede nada; concessão antiga (só `grantedAt`) e a automática por
 *   consulta (`familyAppointment`) não valem;
 * - só vale com escopo, validade e sem revogação;
 * - `summary` lê o cadastro; `chartWrite` grava no prontuário e libera as
 *   funções de IA e documentos. Um não implica o outro;
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
export const GRANT_SOURCES = ["guardian", "guardianInvite"] as const;

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

export type GrantState = "active" | "expired" | "revoked" | "invalid" | "none";

/** Situação da concessão, para a tela e o diagnóstico. */
export function grantState(
  grant: Record<string, unknown> | undefined | null,
  nowMs: number
): GrantState {
  if (!grant) return "none";
  if (
    !GRANT_SOURCES.includes(grant.source as (typeof GRANT_SOURCES)[number]) ||
    !Array.isArray(grant.scopes) ||
    millisOf(grant.expiresAt) === null
  ) {
    return "invalid";
  }
  if (grant.revokedAt != null) return "revoked";
  if ((millisOf(grant.expiresAt) as number) <= nowMs) return "expired";
  return "active";
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
