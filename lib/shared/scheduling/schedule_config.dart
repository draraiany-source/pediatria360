/// Agenda configurada por profissional e reserva temporária de horário.
///
/// O profissional ou a recepção cadastram dias e faixas de atendimento,
/// duração por tipo, intervalo entre consultas, bloqueios, férias, valores,
/// prazo de retorno e limite de remarcações. O assistente de agendamento só
/// oferece o que estas regras permitem; qualquer alteração manual muda na
/// hora o que ele mostra, porque a disponibilidade é sempre recalculada a
/// partir daqui.
library;

import '../care/care_model.dart' show CareSpecialty;
import 'agenda_conflicts.dart';
import 'slots.dart';

/// Período de férias ou ausência (dias inteiros, fim inclusivo).
class AbsencePeriod {
  const AbsencePeriod({
    required this.id,
    required this.firstDay,
    required this.lastDay,
    this.reason = 'Férias',
  });

  final String id;
  final DateTime firstDay;
  final DateTime lastDay;
  final String reason;

  DateTime get _start => DateTime(firstDay.year, firstDay.month, firstDay.day);
  DateTime get _end => DateTime(lastDay.year, lastDay.month, lastDay.day + 1);

  bool covers(DateTime t) => !t.isBefore(_start) && t.isBefore(_end);

  ScheduleBlock asBlock(String professionalId) => ScheduleBlock(
    id: id,
    startsAt: _start,
    endsAt: _end,
    professionalId: professionalId,
    reason: reason,
  );
}

/// Valor cadastrado (centavos). `null` = não cadastrado: o assistente não
/// inventa preço e diz que a recepção informa.
class VisitPrice {
  const VisitPrice({this.presencialCents, this.teleCents});

  final int? presencialCents;
  final int? teleCents;

  int? forModality({required bool tele}) => tele ? teleCents : presencialCents;
}

String formatCents(int cents) {
  final String reais = (cents ~/ 100).toString();
  final String centavos = (cents % 100).toString().padLeft(2, '0');
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) b.write('.');
    b.write(reais[i]);
  }
  return 'R\$ $b,$centavos';
}

/// Agenda de um profissional, como cadastrada.
class ProfessionalSchedule {
  const ProfessionalSchedule({
    required this.professionalId,
    required this.specialty,
    required this.hours,
    this.durations = const <VisitType, int>{},
    this.bufferMinutes = 0,
    this.absences = const <AbsencePeriod>[],
    this.blocks = const <ScheduleBlock>[],
    this.prices = const <VisitType, VisitPrice>{},
    this.address = '',
    this.acceptsTele = true,
    this.returnWindowDays = 30,
    this.maxReschedules = 2,
    this.updatedBy = '',
    this.updatedAt,
  });

  final String professionalId;
  final CareSpecialty specialty;
  final WorkingHours hours;

  /// Duração própria por tipo; sem valor, vale a padrão do tipo.
  final Map<VisitType, int> durations;

  /// Intervalo livre obrigatório entre duas consultas.
  final int bufferMinutes;
  final List<AbsencePeriod> absences;
  final List<ScheduleBlock> blocks;
  final Map<VisitType, VisitPrice> prices;

  /// Endereço do atendimento presencial.
  final String address;
  final bool acceptsTele;

  /// Retorno vale até estes dias depois da última consulta concluída.
  final int returnWindowDays;

  /// Remarcações permitidas por consulta antes de passar pela recepção.
  final int maxReschedules;

  final String updatedBy;
  final DateTime? updatedAt;

  /// Tipos que este profissional atende.
  List<VisitType> get visitTypes => VisitType.values
      .where((VisitType t) => t.specialty == specialty)
      .toList();

  int durationFor(VisitType t, {required bool tele}) =>
      durations[t] ?? t.durationMinutes(teleconsulta: tele);

  int? priceFor(VisitType t, {required bool tele}) =>
      prices[t]?.forModality(tele: tele);

  List<ScheduleBlock> get allBlocks => <ScheduleBlock>[
    for (final ScheduleBlock b in blocks)
      if (b.professionalId.isEmpty || b.professionalId == professionalId) b,
    for (final AbsencePeriod a in absences) a.asBlock(professionalId),
  ];

  AbsencePeriod? absenceOn(DateTime t) {
    for (final AbsencePeriod a in absences) {
      if (a.covers(t)) return a;
    }
    return null;
  }

  /// Consultas existentes alargadas pelo intervalo obrigatório: uma consulta
  /// nova não pode começar nem terminar dentro dele.
  List<BookedInterval> withBuffer(List<BookedInterval> booked) {
    if (bufferMinutes <= 0) return booked;
    return <BookedInterval>[
      for (final BookedInterval b in booked)
        b.professionalId == professionalId
            ? BookedInterval(
                id: b.id,
                startsAt: b.startsAt.subtract(Duration(minutes: bufferMinutes)),
                durationMinutes: b.durationMinutes + 2 * bufferMinutes,
                professionalId: b.professionalId,
                patientId: b.patientId,
                status: b.status,
              )
            : b,
    ];
  }

  /// Erro de cadastro em português, ou `null` se a agenda é válida.
  String? validate() {
    bool any = false;
    for (final MapEntry<int, List<WorkingRange>> e in hours.byWeekday.entries) {
      if (e.key < 1 || e.key > 7) return 'Dia da semana inválido.';
      final List<WorkingRange> sorted = <WorkingRange>[...e.value]
        ..sort((WorkingRange a, WorkingRange b) => a.startMinute - b.startMinute);
      for (int i = 0; i < sorted.length; i++) {
        final WorkingRange r = sorted[i];
        if (r.startMinute < 0 || r.endMinute > 24 * 60) {
          return 'Horário fora do dia.';
        }
        if (r.endMinute <= r.startMinute) {
          return 'O fim de cada faixa precisa ser depois do início.';
        }
        if (i > 0 && r.startMinute < sorted[i - 1].endMinute) {
          return 'Faixas de atendimento sobrepostas no mesmo dia.';
        }
        any = true;
      }
    }
    if (!any) return 'Cadastre ao menos uma faixa de atendimento.';
    for (final int d in durations.values) {
      if (d < 10 || d > 240) {
        return 'A duração de cada tipo deve ficar entre 10 e 240 minutos.';
      }
    }
    if (bufferMinutes < 0 || bufferMinutes > 60) {
      return 'O intervalo entre consultas deve ficar entre 0 e 60 minutos.';
    }
    for (final AbsencePeriod a in absences) {
      if (a.lastDay.isBefore(a.firstDay)) {
        return 'Férias: o último dia precisa ser depois do primeiro.';
      }
    }
    for (final ScheduleBlock b in blocks) {
      if (!b.endsAt.isAfter(b.startsAt)) {
        return 'Bloqueio: o fim precisa ser depois do início.';
      }
    }
    for (final VisitPrice p in prices.values) {
      if ((p.presencialCents ?? 0) < 0 || (p.teleCents ?? 0) < 0) {
        return 'Valor não pode ser negativo.';
      }
    }
    if (returnWindowDays < 0 || returnWindowDays > 120) {
      return 'O prazo de retorno deve ficar entre 0 e 120 dias.';
    }
    if (maxReschedules < 0 || maxReschedules > 10) {
      return 'O limite de remarcações deve ficar entre 0 e 10.';
    }
    return null;
  }

  ProfessionalSchedule copyWith({
    WorkingHours? hours,
    Map<VisitType, int>? durations,
    int? bufferMinutes,
    List<AbsencePeriod>? absences,
    List<ScheduleBlock>? blocks,
    Map<VisitType, VisitPrice>? prices,
    String? address,
    bool? acceptsTele,
    int? returnWindowDays,
    int? maxReschedules,
    String? updatedBy,
    DateTime? updatedAt,
  }) => ProfessionalSchedule(
    professionalId: professionalId,
    specialty: specialty,
    hours: hours ?? this.hours,
    durations: durations ?? this.durations,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    absences: absences ?? this.absences,
    blocks: blocks ?? this.blocks,
    prices: prices ?? this.prices,
    address: address ?? this.address,
    acceptsTele: acceptsTele ?? this.acceptsTele,
    returnWindowDays: returnWindowDays ?? this.returnWindowDays,
    maxReschedules: maxReschedules ?? this.maxReschedules,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Reserva temporária feita enquanto a família (ou a recepção) confere o
/// resumo. Enquanto vale, ninguém mais recebe o horário.
class SlotHold {
  const SlotHold({
    required this.id,
    required this.professionalId,
    required this.start,
    required this.durationMinutes,
    required this.holderId,
    required this.createdAt,
    required this.expiresAt,
    this.patientId,
  });

  final String id;
  final String professionalId;
  final DateTime start;
  final int durationMinutes;
  final String holderId;
  final String? patientId;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool activeAt(DateTime now) => now.isBefore(expiresAt);

  int secondsLeft(DateTime now) =>
      activeAt(now) ? expiresAt.difference(now).inSeconds : 0;

  BookedInterval asInterval() => BookedInterval(
    id: 'hold:$id',
    startsAt: start,
    durationMinutes: durationMinutes,
    professionalId: professionalId,
    patientId: patientId ?? '',
  );
}

/// Reservas temporárias em andamento. A conferência de conflito é de quem
/// chama ([placeHold] recebe o problema já calculado com estas reservas).
class SlotHoldBook {
  SlotHoldBook({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final List<SlotHold> _holds = <SlotHold>[];
  int _next = 1;

  List<SlotHold> active(DateTime now) =>
      _holds.where((SlotHold h) => h.activeAt(now)).toList();

  /// Reservas de outras pessoas, como horários ocupados.
  List<BookedInterval> blockingFor(String holderId, DateTime now) =>
      <BookedInterval>[
        for (final SlotHold h in active(now))
          if (h.holderId != holderId) h.asInterval(),
      ];

  SlotHold? byId(String id) {
    for (final SlotHold h in _holds) {
      if (h.id == id) return h;
    }
    return null;
  }

  SlotHold place({
    required String professionalId,
    required DateTime start,
    required int durationMinutes,
    required String holderId,
    required DateTime now,
    String? patientId,
  }) {
    _holds.removeWhere(
      (SlotHold h) => h.holderId == holderId || !h.activeAt(now),
    );
    final SlotHold h = SlotHold(
      id: 'r${_next++}',
      professionalId: professionalId,
      start: start,
      durationMinutes: durationMinutes,
      holderId: holderId,
      patientId: patientId,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
    _holds.add(h);
    return h;
  }

  /// Motivo para não aceitar a reserva na confirmação; `null` = vale.
  String? problemWith(String holdId, String holderId, DateTime now) {
    final SlotHold? h = byId(holdId);
    if (h == null || h.holderId != holderId) {
      return 'A reserva deste horário não foi encontrada.';
    }
    if (!h.activeAt(now)) {
      return 'A reserva temporária expirou e o horário pode ter sido ocupado.';
    }
    return null;
  }

  void release(String holdId) => _holds.removeWhere((SlotHold h) => h.id == holdId);

  void clear() => _holds.clear();
}

/// O que a família vê antes de confirmar. Pagamento e convênio nunca são
/// confirmados pelo assistente.
class BookingQuote {
  const BookingQuote({
    required this.priceLabel,
    required this.locationLabel,
    this.notes = const <String>[],
  });

  final String priceLabel;
  final String locationLabel;
  final List<String> notes;

  static const String paymentNote =
      'Pagamento, convênio e cobertura não são confirmados pelo assistente: '
      'a recepção confere com os dados do cadastro.';
}

BookingQuote quoteFor({
  required ProfessionalSchedule schedule,
  required VisitType type,
  required bool tele,
  DateTime? lastVisit,
  required DateTime start,
}) {
  final List<String> notes = <String>[];
  String price;
  final int? cents = schedule.priceFor(type, tele: tele);
  if (type == VisitType.retorno && lastVisit != null) {
    final int days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(lastVisit.year, lastVisit.month, lastVisit.day))
        .inDays;
    if (days > schedule.returnWindowDays) {
      notes.add(
        'O retorno vale até ${schedule.returnWindowDays} dias depois da '
        'última consulta; este horário passa do prazo e a recepção confirma '
        'como será cobrado.',
      );
    }
  }
  price = cents == null
      ? 'Valor não cadastrado: a recepção informa'
      : cents == 0
      ? 'Sem custo (valor cadastrado)'
      : '${formatCents(cents)} (valor cadastrado)';
  notes.add(BookingQuote.paymentNote);
  return BookingQuote(
    priceLabel: price,
    locationLabel: tele
        ? 'Teleconsulta (o link chega antes do horário)'
        : schedule.address.isEmpty
        ? 'Endereço a confirmar com a recepção'
        : schedule.address,
    notes: notes,
  );
}
