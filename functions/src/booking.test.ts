import { hasActiveBookingConflict, isPastAppointmentTime } from "./booking";

/**
 * Primeiros testes reais de Cloud Function do projeto. `functions/` não
 * tinha framework de teste nenhum até esta versão — `npm test` não
 * existia como script. `tool/validate_release.sh` já chamava esse comando;
 * teria falhado com "Missing script: test" na primeira execução real.
 *
 * Cobre as duas decisões que mais importa acertar em `bookAppointment`:
 * dupla reserva e horário passado. A lógica em si é simples — o valor
 * aqui é ter prova executável de que continua simples e certa depois da
 * próxima pessoa mexer no arquivo, não é a complexidade do teste.
 */
describe("hasActiveBookingConflict", () => {
  test("nenhum agendamento existente: sem conflito", () => {
    expect(hasActiveBookingConflict([])).toBe(false);
  });

  test("agendamento existente com status ativo: conflito", () => {
    expect(hasActiveBookingConflict(["requested"])).toBe(true);
    expect(hasActiveBookingConflict(["confirmed"])).toBe(true);
    expect(hasActiveBookingConflict(["inProgress"])).toBe(true);
    expect(hasActiveBookingConflict(["completed"])).toBe(true);
  });

  test("agendamento cancelado: NÃO conflita — horário está livre", () => {
    expect(hasActiveBookingConflict(["cancelled"])).toBe(false);
  });

  test("agendamento com falta (noShow): NÃO conflita", () => {
    expect(hasActiveBookingConflict(["noShow"])).toBe(false);
  });

  test("um cancelado e um ativo no mesmo horário: conflita (o ativo pesa)", () => {
    // Cenário real: alguém cancelou e outra pessoa já reservou o mesmo
    // horário antes desta chamada. O cancelado não deveria "limpar" o
    // conflito do que está ativo.
    expect(hasActiveBookingConflict(["cancelled", "confirmed"])).toBe(true);
  });

  test("dois cancelados: sem conflito", () => {
    expect(hasActiveBookingConflict(["cancelled", "noShow"])).toBe(false);
  });

  test("status indefinido (documento corrompido/incompleto): não derruba a checagem", () => {
    // undefined não é nenhum dos dois status que liberam o horário — por
    // segurança, um documento com status ausente conta como ocupado, não
    // como livre. Errar para o lado de bloquear é mais seguro que liberar
    // um horário que pode não estar livre de verdade.
    expect(hasActiveBookingConflict([undefined])).toBe(true);
  });
});

describe("isPastAppointmentTime", () => {
  const now = new Date("2026-08-09T12:00:00Z");

  test("horário no futuro: não é passado", () => {
    const future = new Date("2026-08-09T13:00:00Z");
    expect(isPastAppointmentTime(future, now)).toBe(false);
  });

  test("horário no passado: é passado", () => {
    const past = new Date("2026-08-09T11:00:00Z");
    expect(isPastAppointmentTime(past, now)).toBe(true);
  });

  test("horário exatamente igual a agora: não conta como passado", () => {
    // Fronteira: `<`, não `<=` — o instante exato de "agora" ainda é
    // válido para agendar, só o que já ficou pra trás não é.
    expect(isPastAppointmentTime(now, now)).toBe(false);
  });

  test("um segundo no passado: é passado", () => {
    const past = new Date(now.getTime() - 1000);
    expect(isPastAppointmentTime(past, now)).toBe(true);
  });
});
