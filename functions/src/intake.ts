/**
 * Regras puras da solicitação de paciente novo e do convite ao responsável.
 * Sem Firestore nem relógio global, para ter teste de unidade.
 *
 * A solicitação (clinic_intakes) é provisória: guarda o que a clínica
 * informou (nome, nascimento, contato) e o horário pedido. Ela não aponta
 * para criança nenhuma. O vínculo só nasce quando o responsável aceita o
 * convite, autenticado, com o código e para uma criança que já é dele.
 * Conhecer nome, nascimento ou ids de uma criança não basta para nada.
 */

import { createHash, randomInt } from "crypto";

/** Validade do convite. Também nunca passa do horário da consulta. */
export const INVITE_DAYS = 7;

/** Tentativas erradas de código por usuário dentro da janela. */
export const MAX_FAILED_ATTEMPTS = 10;
export const ATTEMPT_WINDOW_MS = 60 * 60 * 1000;

/** Sem 0/O, 1/I/L: o código é ditado e copiado à mão. */
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 10;

export const INTAKE_STATUSES = ["pendingGuardian", "linked", "cancelled"] as const;
export type IntakeStatus = (typeof INTAKE_STATUSES)[number];

/** Papéis que registram solicitação para qualquer profissional da clínica. */
export const INTAKE_DESK_ROLES = ["clinicAdmin", "receptionist"];

/** Papéis que atendem (podem ser o profissional da solicitação). */
export const CARE_ROLES = [
  "clinicAdmin",
  "physician",
  "healthProfessional",
  "nursing",
  "technician",
];

/** Papéis que o gestor pode atribuir pela tela de equipe. */
export const ASSIGNABLE_ROLES = [
  "clinicAdmin",
  "physician",
  "healthProfessional",
  "receptionist",
  "finance",
  "nursing",
  "technician",
];

/** Papéis clínicos: exigem conta de profissional (registro conferido à parte). */
export const CLINICAL_ROLES = ["physician", "healthProfessional", "nursing"];

const DAY_MS = 24 * 60 * 60 * 1000;

export function generateInviteCode(rand: (max: number) => number = randomInt): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CODE_ALPHABET[rand(CODE_ALPHABET.length)];
  }
  return out;
}

/** Aceita "abcde-fghij", espaços e minúsculas. */
export function normalizeInviteCode(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const clean = input.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (clean.length !== CODE_LENGTH) return null;
  for (const ch of clean) {
    if (!CODE_ALPHABET.includes(ch)) return null;
  }
  return clean;
}

export function formatInviteCode(code: string): string {
  return `${code.slice(0, 5)}-${code.slice(5)}`;
}

/** O código não é guardado: só o hash, que serve de id do documento. */
export function hashInviteCode(code: string): string {
  return createHash("sha256").update(`p360-intake:${code}`).digest("hex");
}

export function normalizeEmail(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const e = input.trim().toLowerCase();
  if (e.length > 200) return null;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) ? e : null;
}

export function normalizeName(input: unknown): string {
  if (typeof input !== "string") return "";
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Mesma criança, mesmo responsável, mesmo profissional, mesma clínica. */
export function intakeDedupeKey(p: {
  clinicId: string | null;
  professionalId: string;
  childName: string;
  childBirthDate: string;
  guardianEmail: string;
}): string {
  const raw = [
    p.clinicId ?? "-",
    p.professionalId,
    normalizeName(p.childName),
    p.childBirthDate,
    p.guardianEmail,
  ].join("|");
  return createHash("sha256").update(raw).digest("hex").slice(0, 40);
}

export interface IntakeInput {
  clinicId: string | null;
  professionalId: string;
  childName: string;
  childBirthDate: string;
  guardianName: string;
  guardianEmail: string;
  guardianPhone: string | null;
  startsAtMs: number;
  durationMinutes: number;
  reason: string | null;
}

export class IntakeValidationError extends Error {}

function str(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

/** Valida e limpa o que a recepção enviou. Lança IntakeValidationError. */
export function parseIntakeInput(data: unknown, nowMs: number): IntakeInput {
  const d = (data ?? {}) as Record<string, unknown>;
  const clinicId = typeof d.clinicId === "string" && d.clinicId ? d.clinicId : null;
  const professionalId = str(d.professionalId, 128);
  if (!professionalId) throw new IntakeValidationError("Escolha o profissional.");

  const childName = str(d.childName, 120);
  if (childName.length < 2) throw new IntakeValidationError("Informe o nome da criança.");

  const childBirthDate = str(d.childBirthDate, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(childBirthDate)) {
    throw new IntakeValidationError("Data de nascimento inválida (use AAAA-MM-DD).");
  }
  const birthMs = Date.parse(`${childBirthDate}T00:00:00Z`);
  if (Number.isNaN(birthMs) || birthMs > nowMs) {
    throw new IntakeValidationError("Data de nascimento inválida.");
  }

  const guardianName = str(d.guardianName, 120);
  if (guardianName.length < 2) throw new IntakeValidationError("Informe o nome do responsável.");

  const guardianEmail = normalizeEmail(d.guardianEmail);
  if (!guardianEmail) {
    throw new IntakeValidationError("Informe um e-mail válido do responsável.");
  }

  const phone = str(d.guardianPhone, 30);

  const startsAtMs = Date.parse(str(d.startsAt, 40));
  if (Number.isNaN(startsAtMs)) throw new IntakeValidationError("Horário inválido.");
  if (startsAtMs <= nowMs) throw new IntakeValidationError("Este horário já passou.");
  if (startsAtMs > nowMs + 366 * DAY_MS) {
    throw new IntakeValidationError("Horário muito distante.");
  }

  const duration = Number(d.durationMinutes ?? 30);
  if (!Number.isInteger(duration) || duration < 10 || duration > 240) {
    throw new IntakeValidationError("Duração inválida.");
  }

  const reason = str(d.reason, 300);

  return {
    clinicId,
    professionalId,
    childName,
    childBirthDate,
    guardianName,
    guardianEmail,
    guardianPhone: phone || null,
    startsAtMs,
    durationMinutes: duration,
    reason: reason || null,
  };
}

/** O convite vence em INVITE_DAYS ou no início da consulta, o que vier antes. */
export function inviteExpiresAtMs(nowMs: number, startsAtMs: number): number {
  return Math.min(nowMs + INVITE_DAYS * DAY_MS, startsAtMs);
}

/**
 * Escopos escolhidos pelo responsável ao aceitar. Lista vazia = só confirma
 * a consulta, sem acesso clínico. `chartWrite` sem `summary` não existe na
 * tela; aqui também não.
 */
export function parseGuardianScopes(input: unknown): string[] {
  if (input == null) return [];
  if (!Array.isArray(input)) throw new IntakeValidationError("Escopos inválidos.");
  const set = new Set<string>();
  for (const s of input) {
    if (s !== "summary" && s !== "chartWrite") {
      throw new IntakeValidationError("Escopo desconhecido.");
    }
    set.add(s);
  }
  if (set.has("chartWrite") && !set.has("summary")) {
    throw new IntakeValidationError("Acesso ao prontuário inclui o resumo.");
  }
  return GRANT_ORDER.filter((s) => set.has(s));
}

const GRANT_ORDER = ["summary", "chartWrite"];

export function parseGrantDays(input: unknown): number {
  const n = Number(input);
  if (!Number.isInteger(n) || n < 1 || n > 365) {
    throw new IntakeValidationError("Validade deve ficar entre 1 e 365 dias.");
  }
  return n;
}

/** Janela de tentativas erradas: devolve o novo estado e se bloqueia. */
export function registerFailedAttempt(
  previous: { count?: number; windowStartMs?: number } | undefined,
  nowMs: number
): { count: number; windowStartMs: number } {
  if (!previous?.windowStartMs || nowMs - previous.windowStartMs > ATTEMPT_WINDOW_MS) {
    return { count: 1, windowStartMs: nowMs };
  }
  return { count: (previous.count ?? 0) + 1, windowStartMs: previous.windowStartMs };
}

export function attemptsBlocked(
  state: { count?: number; windowStartMs?: number } | undefined,
  nowMs: number
): boolean {
  if (!state?.windowStartMs) return false;
  if (nowMs - state.windowStartMs > ATTEMPT_WINDOW_MS) return false;
  return (state.count ?? 0) >= MAX_FAILED_ATTEMPTS;
}

/** Quem pode registrar solicitação para `professionalId` nesta clínica. */
export function canRegisterIntake(
  callerRole: string | null,
  callerUid: string,
  professionalId: string
): boolean {
  if (callerRole && INTAKE_DESK_ROLES.includes(callerRole)) return true;
  return (
    callerRole !== null && CARE_ROLES.includes(callerRole) && callerUid === professionalId
  );
}
