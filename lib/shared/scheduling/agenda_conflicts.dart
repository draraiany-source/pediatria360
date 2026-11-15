/// Regras puras de conflito de agenda (FASE 2) — testaveis sem Firebase.
class AgendaConflict {
  const AgendaConflict({
    required this.reason,
    this.conflictingAppointmentId,
  });

  final String reason;
  final String? conflictingAppointmentId;
}

class AgendaInterval {
  const AgendaInterval({
    required this.id,
    required this.startsAt,
    required this.durationMinutes,
    this.professionalId = '',
    this.roomId = '',
    this.status = 'confirmed',
  });

  final String id;
  final DateTime startsAt;
  final int durationMinutes;
  final String professionalId;
  final String roomId;
  final String status;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  bool get isBlocking =>
      status != 'cancelled' && status != 'noShow';
}

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    this.professionalId = '',
    this.roomId = '',
    this.reason = '',
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String professionalId;
  final String roomId;
  final String reason;
}

bool intervalsOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

/// Detecta conflito de profissional e/ou sala no mesmo intervalo.
AgendaConflict? findAgendaConflict({
  required DateTime startsAt,
  required int durationMinutes,
  required String professionalId,
  String roomId = '',
  required List<AgendaInterval> existing,
  List<ScheduleBlock> blocks = const <ScheduleBlock>[],
  String? ignoreAppointmentId,
}) {
  final DateTime endsAt = startsAt.add(Duration(minutes: durationMinutes));

  for (final ScheduleBlock block in blocks) {
    final bool sameProfessional =
        block.professionalId.isEmpty || block.professionalId == professionalId;
    final bool sameRoom =
        roomId.isEmpty || block.roomId.isEmpty || block.roomId == roomId;
    if (sameProfessional &&
        sameRoom &&
        intervalsOverlap(startsAt, endsAt, block.startsAt, block.endsAt)) {
      return AgendaConflict(
        reason: block.reason.isEmpty
            ? 'Horario bloqueado na agenda'
            : 'Horario bloqueado: ${block.reason}',
      );
    }
  }

  for (final AgendaInterval other in existing) {
    if (!other.isBlocking) continue;
    if (ignoreAppointmentId != null && other.id == ignoreAppointmentId) {
      continue;
    }
    if (!intervalsOverlap(startsAt, endsAt, other.startsAt, other.endsAt)) {
      continue;
    }
    if (other.professionalId == professionalId) {
      return AgendaConflict(
        reason: 'Conflito de horario do profissional',
        conflictingAppointmentId: other.id,
      );
    }
    if (roomId.isNotEmpty &&
        other.roomId.isNotEmpty &&
        other.roomId == roomId) {
      return AgendaConflict(
        reason: 'Conflito de sala no mesmo horario',
        conflictingAppointmentId: other.id,
      );
    }
  }
  return null;
}

/// Duracoes padrao por tipo de atendimento (minutos).
int defaultDurationForAppointmentType(String typeName) => switch (typeName) {
      'retorno' => 20,
      'procedimento' => 45,
      'teleconsulta' => 30,
      'presencial' || 'primeiraConsulta' => 40,
      _ => 30,
    };