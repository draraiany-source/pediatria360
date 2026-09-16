/**
 * Regras puras de validação de agendamento — sem Firestore, sem
 * `Date.now()` direto, sem nada que dependa do ambiente.
 *
 * ## Por que isto existe separado de commerce.ts
 *
 * `bookAppointment` (em commerce.ts) decide dentro de uma transação do
 * Firestore, com `admin.firestore.Timestamp` e `HttpsError` — nada disso é
 * testável sem subir o emulador inteiro. As DUAS decisões que mais importa
 * acertar — "este horário já está ocupado?" e "este horário já passou?" —
 * são lógica pura por trás disso, e moram aqui para poder ter teste real
 * de unidade, sem emulador.
 *
 * `functions/package.json` não tinha nenhum script de teste até esta
 * versão — nem framework instalado. `tool/validate_release.sh` já chamava
 * `npm test` para as Functions; teria falhado com "Missing script: test"
 * na primeira execução real.
 */

/** Status que NÃO ocupam o horário — um agendamento cancelado ou marcado
 * como falta libera o horário para outra pessoa reservar. */
const NON_BLOCKING_STATUSES = new Set(["cancelled", "noShow"]);

/**
 * Verdadeiro se algum dos agendamentos existentes ainda ocupa o horário.
 *
 * Espelha exatamente o filtro usado dentro da transação de
 * `bookAppointment`: `status !== "cancelled" && status !== "noShow"`.
 */
export function hasActiveBookingConflict(
  existingStatuses: Array<string | undefined>
): boolean {
  // undefined conta como bloqueio, não como livre — um documento com
  // status ausente (incompleto, corrompido) não deveria liberar um
  // horário que pode não estar livre de verdade. Errar para o lado de
  // bloquear é mais seguro que errar para o lado de permitir dupla
  // reserva.
  return existingStatuses.some(
    (status) => status === undefined || !NON_BLOCKING_STATUSES.has(status)
  );
}

/**
 * Verdadeiro se o horário pedido já passou.
 *
 * `now` é parâmetro, não `Date.now()` lido direto — assim o teste não
 * precisa mockar relógio global para verificar um caso determinístico.
 */
export function isPastAppointmentTime(startsAt: Date, now: Date): boolean {
  return startsAt.getTime() < now.getTime();
}
