/**
 * Marketing (puro): validação de campanha, segmentação permitida e
 * elegibilidade. Segmentação só por preferências e critérios
 * administrativos — nunca diagnóstico, transcrição ou conteúdo clínico.
 */

export const ALLOWED_SEGMENT_KEYS = ["stage", "lastVisitBefore", "lastVisitAfter", "unitId", "preferredChannel"] as const;
const STAGES = ["novoContato", "agendamentoSolicitado", "agendado", "atendido", "acompanhamento"];

export interface Segment {
  stage?: string[];
  lastVisitBefore?: string;
  lastVisitAfter?: string;
  unitId?: string;
  preferredChannel?: "inApp" | "whatsapp";
}

export class CampaignError extends Error {}

/** Promessas e alegações que a clínica não pode publicar sem comprovação. */
const FORBIDDEN_CLAIMS = [
  /depoimento/i, /garantid[oa]/i, /\bcura\b/i, /100\s?%/, /resultado(s)? comprovado/i, /o melhor (pediatra|médico|da cidade)/i,
  /sem risco/i, /milagr/i, /antes e depois/i, /diagn[oó]stico/i,
];

export function validateCampaign(raw: unknown): { title: string; body: string; segment: Segment; frequencyCapDays: number; kind: "administrative" | "educational" } {
  const r = (raw ?? {}) as Record<string, unknown>;
  const title = typeof r.title === "string" ? r.title.trim().slice(0, 80) : "";
  const body = typeof r.body === "string" ? r.body.trim().slice(0, 500) : "";
  if (!title || !body) throw new CampaignError("Informe título e texto.");
  for (const re of FORBIDDEN_CLAIMS) {
    if (re.test(title) || re.test(body)) throw new CampaignError("O texto contém alegação não permitida (depoimento, promessa de resultado, diagnóstico ou credencial não comprovada).");
  }
  const seg = (r.segment ?? {}) as Record<string, unknown>;
  for (const k of Object.keys(seg)) {
    if (!(ALLOWED_SEGMENT_KEYS as readonly string[]).includes(k)) throw new CampaignError(`Critério de segmentação não permitido: ${k}`);
  }
  const segment: Segment = {};
  if (Array.isArray(seg.stage)) segment.stage = seg.stage.filter((s): s is string => typeof s === "string" && STAGES.includes(s));
  for (const k of ["lastVisitBefore", "lastVisitAfter"] as const) {
    if (typeof seg[k] === "string" && !Number.isNaN(Date.parse(seg[k] as string))) segment[k] = seg[k] as string;
  }
  if (typeof seg.unitId === "string") segment.unitId = seg.unitId.slice(0, 64);
  if (seg.preferredChannel === "inApp" || seg.preferredChannel === "whatsapp") segment.preferredChannel = seg.preferredChannel;
  const cap = Number(r.frequencyCapDays ?? 7);
  return {
    title, body, segment,
    frequencyCapDays: Number.isInteger(cap) && cap >= 1 && cap <= 90 ? cap : 7,
    kind: r.kind === "administrative" ? "administrative" : "educational",
  };
}

export interface Contact {
  ownerUid: string;
  stage: string;
  lastVisitMs: number | null;
  unitId: string | null;
  preferredChannel: string;
  marketingConsent: boolean;
  suppressed: boolean;
  lastMarketingMs: number | null;
}

export function matchesSegment(c: Contact, s: Segment): boolean {
  if (s.stage?.length && !s.stage.includes(c.stage)) return false;
  if (s.lastVisitBefore && !(c.lastVisitMs != null && c.lastVisitMs < Date.parse(s.lastVisitBefore))) return false;
  if (s.lastVisitAfter && !(c.lastVisitMs != null && c.lastVisitMs >= Date.parse(s.lastVisitAfter))) return false;
  if (s.unitId && c.unitId !== s.unitId) return false;
  if (s.preferredChannel && c.preferredChannel !== s.preferredChannel) return false;
  return true;
}

/** Elegível: consentimento específico, fora da supressão e do limite de frequência. */
export function eligibility(c: Contact, capDays: number, nowMs: number): { ok: true } | { ok: false; reason: string } {
  if (!c.marketingConsent) return { ok: false, reason: "sem consentimento de marketing" };
  if (c.suppressed) return { ok: false, reason: "lista de supressão" };
  if (c.lastMarketingMs != null && nowMs - c.lastMarketingMs < capDays * 86_400_000) return { ok: false, reason: "limite de frequência" };
  return { ok: true };
}
