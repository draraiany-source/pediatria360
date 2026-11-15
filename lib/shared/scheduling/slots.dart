/// Horários realmente disponíveis e regras da clínica para agendar,
/// reagendar e cancelar.
///
/// Reaproveita `findAgendaConflict` (agenda do app real): conflito de
/// profissional pela duração inteira da consulta e bloqueios de agenda.
library;

import 'agenda_conflicts.dart';

/// Tipos que a família pode escolher. A duração segue
/// `defaultDurationForAppointmentType` do app real.
enum VisitType {
  queixa('Consulta por queixa', 'presencial', allowsTele: true),
  puericultura('Puericultura (rotina)', 'primeiraConsulta', allowsTele: false),
  retorno('Retorno', 'retorno', allowsTele: true),
  primeiraConsulta('Primeira consulta', 'primeiraConsulta', allowsTele: false);

  const VisitType(this.label, this._durationKey, {required this.allowsTele});

  final String label;
  final String _durationKey;

  /// Puericultura e primeira consulta pedem exame físico: só presencial.
  final bool allowsTele;

  int durationMinutes({required bool teleconsulta}) => teleconsulta
      ? defaultDurationForAppointmentType('teleconsulta')
      : defaultDurationForAppointmentType(_durationKey);

  static VisitType? fromLabel(String label) {
    for (final VisitType t in values) {
      if (t.label == label) return t;
    }
    return null;
  }
}

enum DayPart {
  manha('Manhã'),
  tarde('Tarde'),
  qualquer('Qualquer horário');

  const DayPart(this.label);

  final String label;

  bool accepts(DateTime t) => switch (this) {
    DayPart.manha => t.hour < 12,
    DayPart.tarde => t.hour >= 12,
    DayPart.qualquer => true,
  };
}

/// Faixa de atendimento num dia da semana (minutos desde 0h).
class WorkingRange {
  const WorkingRange(this.startMinute, this.endMinute);

  final int startMinute;
  final int endMinute;
}

/// Horário de atendimento de um profissional: `weekday` (1 = segunda) →
/// faixas.
class WorkingHours {
  const WorkingHours(this.byWeekday);

  final Map<int, List<WorkingRange>> byWeekday;

  List<WorkingRange> on(DateTime day) =>
      byWeekday[day.weekday] ?? const <WorkingRange>[];
}

/// Regras da clínica para o autoatendimento.
class SchedulingPolicy {
  const SchedulingPolicy({
    this.minLeadHours = 2,
    this.maxDaysAhead = 60,
    this.selfRescheduleUntilHours = 24,
    this.selfCancelUntilHours = 12,
    this.slotStepMinutes = 20,
  });

  /// Antecedência mínima para marcar.
  final int minLeadHours;

  /// Até quantos dias à frente a família pode marcar.
  final int maxDaysAhead;

  /// Reagendar pelo app só até estas horas antes; depois, só pela recepção.
  final int selfRescheduleUntilHours;

  /// Cancelar pelo app só até estas horas antes; depois, só pela recepção.
  final int selfCancelUntilHours;

  final int slotStepMinutes;

  bool canSelfReschedule(DateTime start, DateTime now) =>
      !start.subtract(Duration(hours: selfRescheduleUntilHours)).isBefore(now);

  bool canSelfCancel(DateTime start, DateTime now) =>
      !start.subtract(Duration(hours: selfCancelUntilHours)).isBefore(now);
}

class SlotQuery {
  const SlotQuery({
    required this.professionalId,
    required this.durationMinutes,
    required this.from,
    this.days = 14,
    this.dayPart = DayPart.qualquer,
    this.weekdays = const <int>{},
    this.patientId,
    this.ignoreAppointmentId,
  });

  final String professionalId;
  final int durationMinutes;
  final DateTime from;
  final int days;
  final DayPart dayPart;

  /// Vazio = qualquer dia útil de atendimento.
  final Set<int> weekdays;

  /// A mesma criança não pode ter duas consultas sobrepostas.
  final String? patientId;

  /// No reagendamento, o horário atual não conta como ocupado.
  final String? ignoreAppointmentId;

  SlotQuery copyWith({DateTime? from, DayPart? dayPart, Set<int>? weekdays}) =>
      SlotQuery(
        professionalId: professionalId,
        durationMinutes: durationMinutes,
        from: from ?? this.from,
        days: days,
        dayPart: dayPart ?? this.dayPart,
        weekdays: weekdays ?? this.weekdays,
        patientId: patientId,
        ignoreAppointmentId: ignoreAppointmentId,
      );
}

/// Agendamento existente, visto pela regra de horários.
class BookedInterval extends AgendaInterval {
  const BookedInterval({
    required super.id,
    required super.startsAt,
    required super.durationMinutes,
    required super.professionalId,
    required this.patientId,
    super.status,
  });

  final String patientId;
}

/// Motivo pelo qual um horário não pode ser gravado; `null` = livre.
String? slotProblem({
  required DateTime start,
  required int durationMinutes,
  required String professionalId,
  required WorkingHours hours,
  required List<BookedInterval> existing,
  required List<ScheduleBlock> blocks,
  required SchedulingPolicy policy,
  required DateTime now,
  String? patientId,
  String? ignoreAppointmentId,
}) {
  if (start.isBefore(now.add(Duration(hours: policy.minLeadHours)))) {
    return 'Este horário não respeita a antecedência mínima de '
        '${policy.minLeadHours} h.';
  }
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (start.isAfter(today.add(Duration(days: policy.maxDaysAhead + 1)))) {
    return 'A agenda abre só ${policy.maxDaysAhead} dias à frente.';
  }
  final int startMin = start.hour * 60 + start.minute;
  final int endMin = startMin + durationMinutes;
  final bool inside = hours
      .on(start)
      .any((WorkingRange r) => startMin >= r.startMinute && endMin <= r.endMinute);
  if (!inside) return 'Fora do horário de atendimento do profissional.';

  final AgendaConflict? conflict = findAgendaConflict(
    startsAt: start,
    durationMinutes: durationMinutes,
    professionalId: professionalId,
    existing: existing,
    blocks: blocks,
    ignoreAppointmentId: ignoreAppointmentId,
  );
  if (conflict != null) {
    return conflict.conflictingAppointmentId != null
        ? 'Este horário acabou de ser ocupado.'
        : conflict.reason.replaceAll('Horario', 'Horário');
  }
  if (patientId != null) {
    final DateTime end = start.add(Duration(minutes: durationMinutes));
    for (final BookedInterval b in existing) {
      if (!b.isBlocking || b.id == ignoreAppointmentId) continue;
      if (b.patientId == patientId &&
          intervalsOverlap(start, end, b.startsAt, b.endsAt)) {
        return 'A criança já tem consulta neste horário.';
      }
    }
  }
  return null;
}

/// Horários livres, em ordem, respeitando duração, bloqueios, antecedência
/// mínima e o período pedido. [limit] corta a lista para a conversa.
List<DateTime> availableSlots({
  required SlotQuery query,
  required WorkingHours hours,
  required List<BookedInterval> existing,
  required List<ScheduleBlock> blocks,
  required SchedulingPolicy policy,
  required DateTime now,
  int limit = 4,
}) {
  final List<DateTime> out = <DateTime>[];
  final DateTime firstDay = DateTime(
    query.from.year,
    query.from.month,
    query.from.day,
  );
  for (int i = 0; i < query.days && out.length < limit; i++) {
    final DateTime day = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day + i,
    );
    if (query.weekdays.isNotEmpty && !query.weekdays.contains(day.weekday)) {
      continue;
    }
    for (final WorkingRange r in hours.on(day)) {
      for (
        int m = r.startMinute;
        m + query.durationMinutes <= r.endMinute && out.length < limit;
        m += policy.slotStepMinutes
      ) {
        final DateTime t = DateTime(day.year, day.month, day.day, 0, m);
        if (t.isBefore(query.from) || !query.dayPart.accepts(t)) continue;
        final String? problem = slotProblem(
          start: t,
          durationMinutes: query.durationMinutes,
          professionalId: query.professionalId,
          hours: hours,
          existing: existing,
          blocks: blocks,
          policy: policy,
          now: now,
          patientId: query.patientId,
          ignoreAppointmentId: query.ignoreAppointmentId,
        );
        if (problem == null) out.add(t);
      }
    }
  }
  return out;
}
