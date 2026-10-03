/// Diário de atendimentos: classifica cada horário da agenda como
/// realizado, pendente, falta, agendado ou cancelado.
library;

enum VisitOutcome {
  realizada('Realizada'),
  pendente('Pendente'),
  falta('Falta'),
  agendada('Agendada'),
  cancelada('Cancelada');

  const VisitOutcome(this.label);

  final String label;
}

class VisitClassification {
  const VisitClassification(this.outcome, [this.pendingReason]);

  final VisitOutcome outcome;

  /// Por que está pendente (só quando [outcome] é pendente).
  final String? pendingReason;
}

/// Regras:
/// - cancelado e falta valem como registrados na agenda;
/// - realizada exige a consulta finalizada no prontuário;
/// - consulta em rascunho, ou horário que já passou sem registro, fica
///   pendente;
/// - o que ainda não começou é agendado.
VisitClassification classifyVisit({
  required DateTime start,
  required bool cancelled,
  required bool noShow,
  required bool concluded,
  required bool recordFinished,
  required bool recordDraft,
  required DateTime now,
}) {
  if (cancelled) return const VisitClassification(VisitOutcome.cancelada);
  if (noShow) return const VisitClassification(VisitOutcome.falta);
  if (recordFinished) return const VisitClassification(VisitOutcome.realizada);
  if (recordDraft) {
    return const VisitClassification(
      VisitOutcome.pendente,
      'Consulta em rascunho: falta finalizar.',
    );
  }
  if (concluded) {
    return const VisitClassification(
      VisitOutcome.pendente,
      'Marcada como concluída, sem registro no prontuário.',
    );
  }
  if (!start.isAfter(now)) {
    return const VisitClassification(
      VisitOutcome.pendente,
      'Horário passou sem registro nem falta.',
    );
  }
  return const VisitClassification(VisitOutcome.agendada);
}

enum DiaryPeriod {
  hoje('Hoje', 0),
  semana('7 dias', 6),
  mes('30 dias', 29),
  tudo('Tudo', null);

  const DiaryPeriod(this.label, this.daysBack);

  final String label;

  /// Dias antes de hoje incluídos; `null` = sem limite.
  final int? daysBack;

  /// O diário olha para trás: vai até o fim de hoje.
  bool accepts(DateTime at, DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime end = DateTime(today.year, today.month, today.day + 1);
    if (!at.isBefore(end)) return false;
    if (daysBack == null) return true;
    final DateTime from = DateTime(
      today.year,
      today.month,
      today.day - daysBack!,
    );
    return !at.isBefore(from);
  }
}
