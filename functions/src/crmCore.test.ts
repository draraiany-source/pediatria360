import { deriveCrm, DEFAULT_CRM_CRITERIA, findDuplicates, normalizeCriteria } from "./crmCore";

const NOW = Date.UTC(2026, 9, 26);
const D = 86_400_000;

describe("estágio e classificação", () => {
  it("novo contato, solicitado, agendado, atendido, acompanhamento", () => {
    expect(deriveCrm([], NOW, DEFAULT_CRM_CRITERIA).stage).toBe("novoContato");
    expect(deriveCrm([{ status: "requested", startMs: NOW + D }], NOW, DEFAULT_CRM_CRITERIA).stage).toBe("agendamentoSolicitado");
    expect(deriveCrm([{ status: "confirmed", startMs: NOW + D }], NOW, DEFAULT_CRM_CRITERIA).stage).toBe("agendado");
    expect(deriveCrm([{ status: "completed", startMs: NOW - D }], NOW, DEFAULT_CRM_CRITERIA).stage).toBe("atendido");
    expect(deriveCrm([{ status: "completed", startMs: NOW - 9 * D }, { status: "completed", startMs: NOW - D }], NOW, DEFAULT_CRM_CRITERIA).stage).toBe("acompanhamento");
  });
  it("frequente, inativo, faltoso e retorno pendente por critério configurável", () => {
    const visits = [1, 2, 3, 4].map((i) => ({ status: "completed", startMs: NOW - i * 30 * D }));
    expect(deriveCrm(visits, NOW, DEFAULT_CRM_CRITERIA).flags.frequent).toBe(true);
    expect(deriveCrm(visits, NOW, normalizeCriteria({ frequentMinVisits: 5 })).flags.frequent).toBe(false);
    expect(deriveCrm([{ status: "completed", startMs: NOW - 200 * D }], NOW, DEFAULT_CRM_CRITERIA).flags.inactive).toBe(true);
    expect(deriveCrm([{ status: "noShow", startMs: NOW - D }, { status: "noShow", startMs: NOW - 2 * D }], NOW, DEFAULT_CRM_CRITERIA).flags.noShow).toBe(true);
    expect(deriveCrm([{ status: "completed", startMs: NOW - 20 * D, expectedReturnMs: NOW + 5 * D }], NOW, DEFAULT_CRM_CRITERIA).flags.returnPending).toBe(true);
  });
});

describe("duplicidade", () => {
  it("sugere por nome+nascimento ou telefone+primeiro nome", () => {
    const r = findDuplicates([
      { key: "a", childName: "Beatriz Souza", birthDate: "2022-01-01", guardianPhone: null, ownerUid: "u1" },
      { key: "b", childName: "beatriz  souza", birthDate: "2022-01-01", guardianPhone: null, ownerUid: "u2" },
      { key: "c", childName: "Bia Lima", birthDate: null, guardianPhone: "5511900000001", ownerUid: "u3" },
      { key: "d", childName: "Bia Costa", birthDate: null, guardianPhone: "5511900000001", ownerUid: "u4" },
      { key: "e", childName: "Pedro", birthDate: "2022-01-01", guardianPhone: null, ownerUid: "u5" },
    ]);
    expect(r).toEqual([
      { a: "a", b: "b", reason: "mesmo nome e data de nascimento" },
      { a: "c", b: "d", reason: "mesmo telefone do responsável e primeiro nome" },
    ]);
  });
});
