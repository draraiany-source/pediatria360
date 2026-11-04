import { buildClinicalPatch } from "./voice";

const draft = {
  chiefComplaint: "Febre ha dois dias",
  historyOfPresentIllness: "Nao informado",
  allergies: ["Dipirona"],
  currentMedications: ["Paracetamol"],
  examFindings: { orofaringe: "hiperemiada" },
  examNotes: "Bom estado geral",
  assessment: "Hipotese sugerida pela IA",
  plan: "Plano sugerido pela IA",
};

describe("buildClinicalPatch", () => {
  test("atendimento novo recebe o rascunho, exceto campos ignorados", () => {
    const p = buildClinicalPatch(draft, {}, new Set(["assessment"]));
    expect(p.anamnesis.chiefComplaint).toBe("Febre ha dois dias");
    expect(p.anamnesis.historyOfPresentIllness).toBe("Nao informado");
    expect(p.assessment).toBe("Nao informado");
    expect(p.plan).toBe("Plano sugerido pela IA");
    expect(p.exam.systemsExamined).toEqual(["orofaringe"]);
  });

  test("texto escrito pelo profissional nunca e sobrescrito", () => {
    const existing = {
      anamnesis: { chiefComplaint: "Tosse (digitado pelo medico)" },
      plan: "Plano do medico",
    };
    const p = buildClinicalPatch(draft, existing, new Set());
    expect(p.anamnesis.chiefComplaint).toBe("Tosse (digitado pelo medico)");
    expect(p.plan).toBe("Plano do medico");
    expect(p.kept).toEqual(expect.arrayContaining(["chiefComplaint", "plan"]));
    expect(p.assessment).toBe("Hipotese sugerida pela IA");
  });

  test("alergias e medicamentos sao somados sem duplicar", () => {
    const existing = { anamnesis: { allergies: ["dipirona", "Amoxicilina"] } };
    const p = buildClinicalPatch(draft, existing, new Set());
    expect(p.anamnesis.allergies).toEqual(["dipirona", "Amoxicilina"]);
    expect(p.anamnesis.currentMedications).toEqual(["Paracetamol"]);
  });

  test("alergia ignorada nao entra, mas a existente permanece", () => {
    const existing = { anamnesis: { allergies: ["Amoxicilina"] } };
    const p = buildClinicalPatch(draft, existing, new Set(["allergies"]));
    expect(p.anamnesis.allergies).toEqual(["Amoxicilina"]);
  });

  test("achados de exame do profissional prevalecem sobre os da IA", () => {
    const existing = { exam: { findings: { orofaringe: "normal" } } };
    const p = buildClinicalPatch(draft, existing, new Set());
    expect(p.exam.findings).toEqual({ orofaringe: "normal" });
  });
});
