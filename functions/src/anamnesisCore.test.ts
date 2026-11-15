import {
  missingRequired,
  parseTemplate,
  pickTemplate,
  preliminarySummary,
  reuseSuggestions,
  sanitizeAnswers,
  SYSTEM_TEMPLATES,
  TemplateError,
} from "./anamnesisCore";

const ped = SYSTEM_TEMPLATES[0];

describe("modelos", () => {
  it("modelo pediátrico cobre as seções pedidas", () => {
    expect(ped.sections.map((s) => s.id)).toEqual([
      "queixa", "gestacao", "antecedentes", "alergias", "alimentacao", "rotina",
      "desenvolvimento", "vacinas", "internacoes", "duvidas", "anexos",
    ]);
  });
  it("escolhe o modelo por especialidade e idade", () => {
    expect(pickTemplate(SYSTEM_TEMPLATES, "psicologia", 12)).toBeNull();
    expect(pickTemplate(SYSTEM_TEMPLATES, "psicologia", 60)?.id).toBe("sys_psicologia");
  });
  it("recusa modelo com id repetido ou condição para campo inexistente", () => {
    expect(() => parseTemplate({ name: "x", specialty: "p", sections: [{ fields: [{ id: "a", type: "text" }, { id: "a", type: "text" }] }] })).toThrow(TemplateError);
    expect(() => parseTemplate({ name: "x", specialty: "p", sections: [{ fields: [{ id: "a", type: "text", showIf: { field: "zz", equals: true } }] }] })).toThrow("inexistente");
  });
});

describe("respostas", () => {
  it("campo condicional obrigatório só conta quando visível", () => {
    const a = sanitizeAnswers(ped, { chiefComplaint: "Tosse", symptomDuration: "3 dias", hasAllergies: false, vaccinesUpToDate: "sim", allergies: "resto antigo" });
    expect(a.allergies).toBeUndefined();
    expect(missingRequired(ped, a)).toEqual([]);
    const b = sanitizeAnswers(ped, { ...a, hasAllergies: true });
    expect(missingRequired(ped, b)).toEqual(["allergies"]);
  });
  it("descarta campos desconhecidos, opção inválida e anexo fora do caminho", () => {
    const a = sanitizeAnswers(ped, { hack: "x", birthType: "outro", attachments: ["anamnesis/u1/r1/exame.pdf", "../../segredo"] });
    expect(a).toEqual({ attachments: ["anamnesis/u1/r1/exame.pdf"] });
  });
  it("reaproveitamento traz origem e data, só de campos marcados", () => {
    const s = reuseSuggestions(ped, { id: "r0", submittedAt: "2026-01-10T12:00:00.000Z", answers: { allergies: "dipirona", chiefComplaint: "febre" } });
    expect(s).toEqual([{ field: "allergies", value: "dipirona", sourceResponseId: "r0", sourceSubmittedAt: "2026-01-10T12:00:00.000Z" }]);
  });
  it("resumo preliminar marca relato, lacunas e reaproveitamento", () => {
    const sum = preliminarySummary(ped, { chiefComplaint: "Tosse", hasAllergies: true, allergies: "dipirona" }, ["allergies"]);
    expect(sum.header).toMatch(/Relatado pela família/);
    expect(sum.missing).toEqual(["symptomDuration", "vaccinesUpToDate"]);
    expect(sum.sections.find((s) => s.title.startsWith("Alergias"))?.lines[1]).toMatch(/reaproveitado/);
    expect(sum.notAnswered.length).toBeGreaterThan(5);
  });
});
