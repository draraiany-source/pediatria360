/**
 * Anamnese e pré-consulta: modelos, validação e reaproveitamento (puro).
 *
 * Tudo que a família responde é "relatado" — nunca achado confirmado. Uma
 * resposta enviada não é sobrescrita: alterar depois cria nova resposta, e o
 * reaproveitamento mostra origem e data e só vale depois da confirmação.
 */

export type FieldType = "text" | "longText" | "boolean" | "choice" | "multiChoice" | "date" | "number" | "attachments";

export interface TemplateField {
  id: string;
  label: string;
  type: FieldType;
  required?: boolean;
  options?: string[];
  /** Mostra só se outro campo tiver este valor. */
  showIf?: { field: string; equals: string | boolean };
  /** Pode ser sugerido a partir da última anamnese da criança. */
  reusable?: boolean;
  help?: string;
}

export interface TemplateSection {
  id: string;
  title: string;
  fields: TemplateField[];
}

export interface AnamnesisTemplate {
  id: string;
  name: string;
  specialty: string;
  ageMinMonths: number;
  ageMaxMonths: number;
  sections: TemplateSection[];
}

const t = (id: string, label: string, extra: Partial<TemplateField> = {}): TemplateField => ({ id, label, type: "text", ...extra });
const lt = (id: string, label: string, extra: Partial<TemplateField> = {}): TemplateField => ({ id, label, type: "longText", ...extra });
const yn = (id: string, label: string, extra: Partial<TemplateField> = {}): TemplateField => ({ id, label, type: "boolean", ...extra });

/** Modelos do sistema (a clínica pode copiar e adaptar). */
export const SYSTEM_TEMPLATES: AnamnesisTemplate[] = [
  {
    id: "sys_pediatria_geral",
    name: "Pediatria — pré-consulta geral",
    specialty: "pediatria",
    ageMinMonths: 0,
    ageMaxMonths: 216,
    sections: [
      { id: "queixa", title: "Motivo da consulta", fields: [
        lt("chiefComplaint", "Qual o principal motivo da consulta?", { required: true }),
        t("symptomDuration", "Há quanto tempo?", { required: true }),
        lt("presentIllness", "Como começou e como evoluiu?"),
      ] },
      { id: "gestacao", title: "Gestação, parto e período neonatal", fields: [
        t("gestationalAgeWeeks", "Idade gestacional ao nascer (semanas)", { reusable: true }),
        { id: "birthType", label: "Tipo de parto", type: "choice", options: ["normal", "cesárea", "não sei"], reusable: true },
        t("birthWeight", "Peso ao nascer", { reusable: true }),
        yn("neonatalIcu", "Precisou de UTI neonatal?", { reusable: true }),
        lt("neonatalIcuDetails", "Conte o que aconteceu", { showIf: { field: "neonatalIcu", equals: true }, reusable: true }),
      ] },
      { id: "antecedentes", title: "Antecedentes pessoais e familiares", fields: [
        lt("personalHistory", "Doenças que a criança já teve", { reusable: true }),
        lt("familyHistory", "Doenças na família (pais, irmãos, avós)", { reusable: true }),
      ] },
      { id: "alergias", title: "Alergias e medicamentos", fields: [
        yn("hasAllergies", "Tem alguma alergia?", { required: true, reusable: true }),
        lt("allergies", "Quais alergias?", { showIf: { field: "hasAllergies", equals: true }, required: true, reusable: true }),
        lt("currentMedications", "Medicamentos em uso (nome e dose, se souber)", { reusable: true }),
      ] },
      { id: "alimentacao", title: "Alimentação e amamentação", fields: [
        { id: "breastfeeding", label: "Amamentação", type: "choice", options: ["exclusiva", "mista", "não amamenta", "já desmamou"] },
        lt("feeding", "Como é a alimentação no dia a dia?"),
      ] },
      { id: "rotina", title: "Sono, eliminações e rotina", fields: [
        lt("sleep", "Como é o sono?"),
        lt("elimination", "Xixi e cocô: algo diferente?"),
        lt("routine", "Rotina (creche, telas, atividades)"),
      ] },
      { id: "desenvolvimento", title: "Desenvolvimento, comportamento e escola", fields: [
        lt("development", "Algo no desenvolvimento preocupa vocês?"),
        lt("behavior", "Comportamento e convivência"),
        lt("school", "Escola/creche: adaptação e aprendizado"),
      ] },
      { id: "vacinas", title: "Vacinação", fields: [
        { id: "vaccinesUpToDate", label: "As vacinas estão em dia?", type: "choice", options: ["sim", "não", "não sei"], required: true },
        lt("vaccinesNotes", "Quais estão faltando ou atrasadas?", { showIf: { field: "vaccinesUpToDate", equals: "não" } }),
      ] },
      { id: "internacoes", title: "Internações, cirurgias e acompanhamentos", fields: [
        lt("hospitalizations", "Internações (quando e por quê)", { reusable: true }),
        lt("surgeries", "Cirurgias", { reusable: true }),
        lt("otherCare", "Acompanha com outros profissionais?", { reusable: true }),
      ] },
      { id: "duvidas", title: "Dúvidas e expectativas", fields: [
        lt("questions", "Quais dúvidas vocês querem tirar na consulta?"),
        lt("expectations", "O que esperam desta consulta?"),
      ] },
      { id: "anexos", title: "Anexos", fields: [
        { id: "attachments", label: "Exames, documentos ou fotos", type: "attachments" },
      ] },
    ],
  },
  {
    id: "sys_psicologia",
    name: "Psicologia infantil — pré-atendimento",
    specialty: "psicologia",
    ageMinMonths: 24,
    ageMaxMonths: 216,
    sections: [
      { id: "demanda", title: "Demanda", fields: [
        lt("chiefComplaint", "O que motivou a procura?", { required: true }),
        t("symptomDuration", "Desde quando?", { required: true }),
        lt("whoReferred", "Alguém indicou (escola, pediatra)?"),
      ] },
      { id: "contexto", title: "Contexto familiar e escolar", fields: [
        lt("familyContext", "Com quem a criança mora e como é a rotina da casa"),
        lt("school", "Escola: comportamento e aprendizado"),
        lt("recentChanges", "Mudanças recentes (mudança, separação, perdas, nascimento)"),
      ] },
      { id: "comportamento", title: "Comportamento, sono e alimentação", fields: [
        lt("behavior", "Comportamentos que preocupam"),
        lt("sleep", "Sono"),
        lt("feeding", "Alimentação"),
      ] },
      { id: "historico", title: "Acompanhamentos anteriores", fields: [
        lt("previousCare", "Já fez acompanhamento psicológico ou outro?", { reusable: true }),
        lt("currentMedications", "Medicamentos em uso", { reusable: true }),
      ] },
      { id: "expectativas", title: "Expectativas", fields: [lt("expectations", "O que esperam do atendimento?")] },
    ],
  },
  {
    id: "sys_fisioterapia",
    name: "Fisioterapia pediátrica — pré-atendimento",
    specialty: "fisioterapia",
    ageMinMonths: 0,
    ageMaxMonths: 216,
    sections: [
      { id: "queixa", title: "Motivo", fields: [
        lt("chiefComplaint", "Motivo do encaminhamento", { required: true }),
        t("symptomDuration", "Desde quando?", { required: true }),
        lt("referral", "Quem encaminhou e com qual orientação?"),
      ] },
      { id: "motor", title: "Desenvolvimento motor", fields: [
        lt("motorMilestones", "Sentou, engatinhou, andou com que idade?", { reusable: true }),
        lt("pain", "Dor ou limitação de movimento?"),
      ] },
      { id: "historico", title: "Histórico", fields: [
        lt("surgeries", "Cirurgias, fraturas ou internações", { reusable: true }),
        lt("otherCare", "Outros acompanhamentos", { reusable: true }),
      ] },
      { id: "anexos", title: "Anexos", fields: [{ id: "attachments", label: "Exames e laudos", type: "attachments" }] },
    ],
  },
];

const FIELD_ID = /^[A-Za-z][A-Za-z0-9_]{0,39}$/;
const TYPES: FieldType[] = ["text", "longText", "boolean", "choice", "multiChoice", "date", "number", "attachments"];

export class TemplateError extends Error {}

/** Valida um modelo vindo da clínica/profissional. */
export function parseTemplate(raw: unknown): Omit<AnamnesisTemplate, "id"> {
  const r = (raw ?? {}) as Record<string, unknown>;
  const name = typeof r.name === "string" ? r.name.trim().slice(0, 120) : "";
  if (!name) throw new TemplateError("Informe o nome do modelo.");
  const specialty = typeof r.specialty === "string" ? r.specialty.trim().toLowerCase().slice(0, 40) : "";
  if (!specialty) throw new TemplateError("Informe a especialidade.");
  const min = Number(r.ageMinMonths ?? 0);
  const max = Number(r.ageMaxMonths ?? 216);
  if (!Number.isInteger(min) || !Number.isInteger(max) || min < 0 || max > 300 || min > max) throw new TemplateError("Faixa etária inválida.");
  const sections = Array.isArray(r.sections) ? r.sections : [];
  if (!sections.length || sections.length > 30) throw new TemplateError("O modelo precisa de 1 a 30 seções.");
  const ids = new Set<string>();
  const parsed: TemplateSection[] = sections.map((s, si) => {
    const sec = (s ?? {}) as Record<string, unknown>;
    const fields = Array.isArray(sec.fields) ? sec.fields : [];
    if (!fields.length || fields.length > 40) throw new TemplateError(`Seção ${si + 1} sem campos.`);
    return {
      id: typeof sec.id === "string" && FIELD_ID.test(sec.id) ? sec.id : `s${si + 1}`,
      title: String(sec.title ?? `Seção ${si + 1}`).slice(0, 120),
      fields: fields.map((f) => {
        const fd = (f ?? {}) as Record<string, unknown>;
        const id = String(fd.id ?? "");
        if (!FIELD_ID.test(id) || ids.has(id)) throw new TemplateError(`Campo com id inválido ou repetido: ${id}`);
        ids.add(id);
        const type = TYPES.includes(fd.type as FieldType) ? (fd.type as FieldType) : null;
        if (!type) throw new TemplateError(`Tipo inválido no campo ${id}.`);
        const options = Array.isArray(fd.options) ? fd.options.map((o) => String(o).slice(0, 60)).slice(0, 20) : undefined;
        if ((type === "choice" || type === "multiChoice") && !options?.length) throw new TemplateError(`Campo ${id} precisa de opções.`);
        const showIf = fd.showIf && typeof fd.showIf === "object" ? fd.showIf as { field: unknown; equals: unknown } : null;
        return {
          id, type, label: String(fd.label ?? id).slice(0, 200),
          required: fd.required === true,
          reusable: fd.reusable === true,
          ...(options ? { options } : {}),
          ...(showIf && typeof showIf.field === "string" && (typeof showIf.equals === "string" || typeof showIf.equals === "boolean")
            ? { showIf: { field: showIf.field, equals: showIf.equals } } : {}),
        };
      }),
    };
  });
  for (const s of parsed) for (const f of s.fields) {
    if (f.showIf && !ids.has(f.showIf.field)) throw new TemplateError(`Condição do campo ${f.id} aponta para campo inexistente.`);
  }
  return { name, specialty, ageMinMonths: min, ageMaxMonths: max, sections: parsed };
}

export function allFields(tpl: Pick<AnamnesisTemplate, "sections">): TemplateField[] {
  return tpl.sections.flatMap((s) => s.fields);
}

export function isVisible(f: TemplateField, answers: Record<string, unknown>): boolean {
  if (!f.showIf) return true;
  return answers[f.showIf.field] === f.showIf.equals;
}

function isEmpty(v: unknown): boolean {
  return v === undefined || v === null || (typeof v === "string" && !v.trim()) || (Array.isArray(v) && v.length === 0);
}

/** Limpa e valida as respostas: descarta campos desconhecidos e ocultos. */
export function sanitizeAnswers(tpl: Pick<AnamnesisTemplate, "sections">, raw: unknown): Record<string, unknown> {
  const r = (raw ?? {}) as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const f of allFields(tpl)) {
    const v = r[f.id];
    if (v === undefined || v === null) continue;
    switch (f.type) {
      case "text": if (typeof v === "string") out[f.id] = v.slice(0, 500); break;
      case "longText": if (typeof v === "string") out[f.id] = v.slice(0, 4000); break;
      case "boolean": if (typeof v === "boolean") out[f.id] = v; break;
      case "number": if (typeof v === "number" && Number.isFinite(v)) out[f.id] = v; break;
      case "date": if (typeof v === "string" && !Number.isNaN(Date.parse(v))) out[f.id] = v.slice(0, 30); break;
      case "choice": if (typeof v === "string" && f.options?.includes(v)) out[f.id] = v; break;
      case "multiChoice": if (Array.isArray(v)) out[f.id] = v.filter((x) => typeof x === "string" && f.options?.includes(x)); break;
      case "attachments": if (Array.isArray(v)) out[f.id] = v.filter((x) => typeof x === "string" && /^anamnesis\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[A-Za-z0-9._-]+$/.test(x) && !x.includes("..")).slice(0, 10); break;
    }
  }
  // Campo oculto pela condição não guarda resposta antiga.
  for (const f of allFields(tpl)) if (!isVisible(f, out)) delete out[f.id];
  return out;
}

/** Campos obrigatórios (visíveis) sem resposta. */
export function missingRequired(tpl: Pick<AnamnesisTemplate, "sections">, answers: Record<string, unknown>): string[] {
  return allFields(tpl).filter((f) => f.required && isVisible(f, answers) && isEmpty(answers[f.id])).map((f) => f.id);
}

/** Modelo mais específico para especialidade e idade. */
export function pickTemplate<T extends Pick<AnamnesisTemplate, "specialty" | "ageMinMonths" | "ageMaxMonths">>(templates: T[], specialty: string, ageMonths: number | null): T | null {
  const fit = templates.filter((x) => x.specialty === specialty && (ageMonths == null || (ageMonths >= x.ageMinMonths && ageMonths <= x.ageMaxMonths)));
  fit.sort((a, b) => (a.ageMaxMonths - a.ageMinMonths) - (b.ageMaxMonths - b.ageMinMonths));
  return fit[0] ?? null;
}

export interface ReuseSuggestion {
  field: string;
  value: unknown;
  sourceResponseId: string;
  sourceSubmittedAt: string;
}

/** Sugestões de campos reaproveitáveis (precisam de confirmação na tela). */
export function reuseSuggestions(
  tpl: Pick<AnamnesisTemplate, "sections">,
  previous: { id: string; submittedAt: string; answers: Record<string, unknown> } | null
): ReuseSuggestion[] {
  if (!previous) return [];
  return allFields(tpl)
    .filter((f) => f.reusable && !isEmpty(previous.answers[f.id]))
    .map((f) => ({ field: f.id, value: previous.answers[f.id], sourceResponseId: previous.id, sourceSubmittedAt: previous.submittedAt }));
}

/**
 * Resumo preliminar determinístico para o profissional: só o que foi
 * relatado, com lacunas explícitas. Não interpreta nem sugere diagnóstico.
 */
export function preliminarySummary(tpl: Pick<AnamnesisTemplate, "sections">, answers: Record<string, unknown>, reused: string[]): {
  header: string;
  sections: Array<{ title: string; lines: string[] }>;
  missing: string[];
  notAnswered: string[];
} {
  const sections: Array<{ title: string; lines: string[] }> = [];
  const notAnswered: string[] = [];
  for (const s of tpl.sections) {
    const lines: string[] = [];
    for (const f of s.fields) {
      if (!isVisible(f, answers) || f.type === "attachments") continue;
      const v = answers[f.id];
      if (isEmpty(v)) {
        notAnswered.push(f.label);
        continue;
      }
      const shown = typeof v === "boolean" ? (v ? "sim" : "não") : Array.isArray(v) ? v.join(", ") : String(v);
      lines.push(`${f.label}: ${shown}${reused.includes(f.id) ? " (reaproveitado de anamnese anterior, confirmado pela família)" : ""}`);
    }
    if (lines.length) sections.push({ title: s.title, lines });
  }
  return {
    header: "Relatado pela família antes da consulta. Não são achados confirmados; revisar na consulta.",
    sections,
    missing: missingRequired(tpl, answers),
    notAnswered,
  };
}
