import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/scheduling/agenda_conflicts.dart';
import 'package:pediatria360/shared/scheduling/assistant_text.dart';
import 'package:pediatria360/shared/scheduling/booking_assistant.dart';
import 'package:pediatria360/shared/scheduling/slots.dart';

/// Terça-feira, 29/09/2026, 10h.
final DateTime kNow = DateTime(2026, 9, 29, 10);

const WorkingHours kHours = WorkingHours(<int, List<WorkingRange>>{
  1: <WorkingRange>[
    WorkingRange(8 * 60, 12 * 60),
    WorkingRange(14 * 60, 18 * 60),
  ],
  2: <WorkingRange>[
    WorkingRange(8 * 60, 12 * 60),
    WorkingRange(14 * 60, 18 * 60),
  ],
  3: <WorkingRange>[
    WorkingRange(8 * 60, 12 * 60),
    WorkingRange(14 * 60, 18 * 60),
  ],
  4: <WorkingRange>[
    WorkingRange(8 * 60, 12 * 60),
    WorkingRange(14 * 60, 18 * 60),
  ],
  5: <WorkingRange>[WorkingRange(8 * 60, 12 * 60)],
});

class FakeBackend implements SchedulingBackend {
  final List<BookedInterval> booked = <BookedInterval>[
    BookedInterval(
      id: 'a1',
      startsAt: DateTime(2026, 9, 29, 14),
      durationMinutes: 40,
      professionalId: 'pa',
      patientId: 'c9',
    ),
  ];
  final List<ScheduleBlock> blocks = <ScheduleBlock>[
    ScheduleBlock(
      id: 'b1',
      startsAt: DateTime(2026, 9, 30, 8),
      endsAt: DateTime(2026, 9, 30, 12),
      professionalId: 'pa',
      reason: 'Congresso',
    ),
  ];
  final List<String> handoffs = <String>[];
  final Map<String, BookingDraft> drafts = <String, BookingDraft>{};

  /// Simula outra pessoa reservando entre a oferta e a confirmação.
  DateTime? stealBeforeBooking;

  @override
  DateTime get now => kNow;

  @override
  SchedulingPolicy get policy => const SchedulingPolicy();

  @override
  List<AssistantChild> children() => const <AssistantChild>[
    AssistantChild(id: 'c1', name: 'Luna Exemplo', ageMonths: 14),
    AssistantChild(id: 'c2', name: 'Alice Exemplo', ageMonths: 31),
  ];

  @override
  List<AssistantProfessional> professionals() => const <AssistantProfessional>[
    AssistantProfessional(
      id: 'pa',
      name: 'Dra. Exemplo A',
      clinic: 'Clínica A',
    ),
    AssistantProfessional(id: 'pb', name: 'Dr. Exemplo B', clinic: 'Clínica B'),
  ];

  @override
  List<AssistantAppointment> upcoming() => <AssistantAppointment>[
    for (final BookedInterval b in booked)
      if (b.isBlocking && b.patientId.startsWith('c') && b.patientId != 'c9')
        AssistantAppointment(
          id: b.id,
          childId: b.patientId,
          childName: b.patientId == 'c1' ? 'Luna Exemplo' : 'Alice Exemplo',
          professionalId: b.professionalId,
          professionalName: 'Dra. Exemplo A',
          start: b.startsAt,
          durationMinutes: b.durationMinutes,
          teleconsulta: false,
        ),
  ];

  @override
  List<DateTime> findSlots(SlotQuery query, {int limit = 4}) => availableSlots(
    query: query,
    hours: kHours,
    existing: booked,
    blocks: blocks,
    policy: policy,
    now: now,
    limit: limit,
  );

  @override
  String book(BookingDraft d) {
    if (stealBeforeBooking != null) {
      booked.add(
        BookedInterval(
          id: 'x',
          startsAt: stealBeforeBooking!,
          durationMinutes: 40,
          professionalId: d.professionalId,
          patientId: 'c9',
        ),
      );
      stealBeforeBooking = null;
    }
    final String? problem = slotProblem(
      start: d.start,
      durationMinutes: d.durationMinutes,
      professionalId: d.professionalId,
      hours: kHours,
      existing: booked,
      blocks: blocks,
      policy: policy,
      now: now,
      patientId: d.childId,
    );
    if (problem != null) throw BookingException(problem, slotTaken: true);
    final String id = 'n${booked.length}';
    booked.add(
      BookedInterval(
        id: id,
        startsAt: d.start,
        durationMinutes: d.durationMinutes,
        professionalId: d.professionalId,
        patientId: d.childId,
      ),
    );
    drafts[id] = d;
    return id;
  }

  @override
  void reschedule(String id, DateTime start) {
    final int i = booked.indexWhere((BookedInterval b) => b.id == id);
    final BookedInterval old = booked[i];
    booked[i] = BookedInterval(
      id: id,
      startsAt: start,
      durationMinutes: old.durationMinutes,
      professionalId: old.professionalId,
      patientId: old.patientId,
    );
  }

  @override
  void cancel(String id) {
    final int i = booked.indexWhere((BookedInterval b) => b.id == id);
    final BookedInterval old = booked[i];
    booked[i] = BookedInterval(
      id: id,
      startsAt: old.startsAt,
      durationMinutes: old.durationMinutes,
      professionalId: old.professionalId,
      patientId: old.patientId,
      status: 'cancelled',
    );
  }

  @override
  void handoff(String summary) => handoffs.add(summary);
}

void main() {
  group('horários disponíveis', () {
    final FakeBackend b = FakeBackend();

    List<DateTime> slots({
      DayPart part = DayPart.qualquer,
      int duration = 40,
      Set<int> weekdays = const <int>{},
      String? patientId,
      String? ignore,
    }) => b.findSlots(
      SlotQuery(
        professionalId: 'pa',
        durationMinutes: duration,
        from: kNow,
        dayPart: part,
        weekdays: weekdays,
        patientId: patientId,
        ignoreAppointmentId: ignore,
      ),
      limit: 20,
    );

    test('respeita antecedência mínima e o agendamento existente', () {
      final List<DateTime> s = slots();
      // 10h + 2 h de antecedência: primeiro às 14h? não — 14h está ocupado
      // por 40 min; o próximo livre sem sobrepor é 14:40.
      expect(s.first, DateTime(2026, 9, 29, 14, 40));
      expect(s.contains(DateTime(2026, 9, 29, 14, 20)), isFalse);
    });

    test('bloqueio de agenda (congresso na quarta de manhã)', () {
      final List<DateTime> s = slots(part: DayPart.manha, weekdays: <int>{3});
      expect(s.where((DateTime t) => t.day == 30), isEmpty);
      expect(s.first, DateTime(2026, 10, 7, 8));
    });

    test('duração cabe na faixa de atendimento', () {
      final List<DateTime> s = slots(duration: 40, weekdays: <int>{5});
      expect(s.last.hour * 60 + s.last.minute + 40, lessThanOrEqualTo(12 * 60));
    });

    test('mesma criança não fica com duas consultas sobrepostas', () {
      final String? p = slotProblem(
        start: DateTime(2026, 9, 29, 14, 20),
        durationMinutes: 20,
        professionalId: 'pb',
        hours: kHours,
        existing: b.booked,
        blocks: const <ScheduleBlock>[],
        policy: const SchedulingPolicy(),
        now: kNow,
        patientId: 'c9',
      );
      expect(p, 'A criança já tem consulta neste horário.');
    });

    test('reagendamento ignora o próprio horário', () {
      final List<DateTime> s = slots(ignore: 'a1', part: DayPart.tarde);
      expect(s.first, DateTime(2026, 9, 29, 14));
    });

    test('regras de reagendar e cancelar', () {
      const SchedulingPolicy p = SchedulingPolicy();
      expect(p.canSelfReschedule(DateTime(2026, 9, 30, 11), kNow), isTrue);
      expect(p.canSelfReschedule(DateTime(2026, 9, 30, 9), kNow), isFalse);
      expect(p.canSelfCancel(DateTime(2026, 9, 29, 23), kNow), isTrue);
      expect(p.canSelfCancel(DateTime(2026, 9, 29, 21), kNow), isFalse);
    });

    test('duração por tipo reaproveita a regra da agenda real', () {
      expect(VisitType.retorno.durationMinutes(teleconsulta: false), 20);
      expect(VisitType.puericultura.durationMinutes(teleconsulta: false), 40);
      expect(VisitType.queixa.durationMinutes(teleconsulta: true), 30);
    });
  });

  group('urgência e texto livre', () {
    test('sinais de alerta', () {
      expect(
        checkUrgency('Ela está com dificuldade para respirar').urgent,
        isTrue,
      );
      expect(checkUrgency('teve uma CONVULSÃO agora').urgent, isTrue);
      expect(checkUrgency('lábios roxos').urgent, isTrue);
      expect(checkUrgency('tosse há 3 dias').urgent, isFalse);
      expect(checkUrgency('febre', ageInMonths: 2).urgent, isTrue);
      expect(checkUrgency('febre', ageInMonths: 14).urgent, isFalse);
    });

    test('orientação não traz diagnóstico', () {
      expect(urgencyGuidance, contains('192'));
      expect(urgencyGuidance, contains('não faz avaliação médica'));
    });

    test('intenção, período e dias', () {
      expect(detectIntent('quero remarcar'), AssistantIntent.remarcar);
      expect(detectIntent('preciso desmarcar'), AssistantIntent.cancelar);
      expect(detectIntent('marcar consulta'), AssistantIntent.agendar);
      expect(detectIntent('falar com a recepção'), AssistantIntent.recepcao);
      expect(detectDayPart('de manhã cedo'), DayPart.manha);
      expect(detectDayPart('à tarde'), DayPart.tarde);
      expect(detectWeekdays('terça ou quinta'), <int>{2, 4});
      expect(detectTele('pode ser online'), isTrue);
      expect(
        matchOption('é para a luna', <String>['Luna Exemplo', 'Alice Exemplo']),
        'Luna Exemplo',
      );
    });
  });

  group('conversa', () {
    test('agenda só após confirmação explícita', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      expect(a.options, contains(BookingAssistant.optBook));
      a.send(BookingAssistant.optBook);
      expect(a.options, <String>['Luna Exemplo', 'Alice Exemplo']);
      a.send('Luna Exemplo');
      a.send('Tosse há três dias');
      expect(a.options, contains(VisitType.queixa.label));
      a.send(VisitType.queixa.label);
      a.send(BookingAssistant.optPresencial);
      a.send('Dra. Exemplo A');
      a.send(DayPart.tarde.label);
      final List<String> offered = a.options;
      expect(offered.first, 'ter, 29/09 às 14:40');
      a.send(offered.first);
      expect(a.messages.last.card?.kind, AssistantCardKind.summary);
      expect(b.drafts, isEmpty, reason: 'nada gravado antes de confirmar');
      a.send(BookingAssistant.optConfirmBooking);
      expect(b.drafts, hasLength(1));
      final BookingDraft d = b.drafts.values.single;
      expect(d.childId, 'c1');
      expect(d.reason, 'Tosse há três dias');
      expect(d.durationMinutes, 40);
      expect(a.messages.last.card?.kind, AssistantCardKind.booked);
      expect(a.bookedAppointmentId, isNotNull);
    });

    test('próxima semana busca a partir da segunda seguinte', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send(BookingAssistant.optBook);
      a.send('Luna Exemplo');
      a.send('Consulta');
      a.send(VisitType.queixa.label);
      a.send(BookingAssistant.optPresencial);
      a.send('Dra. Exemplo A');
      final List<String> thisWeek = <String>[
        for (final int d in <int>[29, 30]) '/09',
        for (final int d in <int>[1, 2, 3, 4]) '0/10',
      ];
      bool offersThisWeek() => a.options.any(
        (String o) => thisWeek.any((String d) => o.contains(d)),
      );
      a.send(BookingAssistant.optNextWeek);
      expect(a.options, contains(BookingAssistant.optMoreSlots));
      expect(offersThisWeek(), isFalse, reason: a.options.join(' | '));
      a.send(BookingAssistant.optChangePeriod);
      a.send(DayPart.qualquer.label);
      expect(offersThisWeek(), isTrue);
      a.send('prefiro na próxima semana');
      expect(a.options, contains(BookingAssistant.optMoreSlots));
      expect(offersThisWeek(), isFalse, reason: a.options.join(' | '));
    });

    test('frase completa preenche vários dados de uma vez', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send(
        'Quero marcar um retorno online para a Alice com o Dr. Exemplo B de manhã',
      );
      // Falta só o motivo.
      expect(a.messages.last.text, contains('motivo'));
      a.send('Rever resultado');
      expect(a.options.first, contains('às'));
      a.send(a.options.first);
      final AssistantCard card = a.messages.last.card!;
      expect(card.lines, contains('Tipo: Retorno (30 min)'));
      expect(card.lines, contains('Modalidade: Teleconsulta'));
    });

    test('puericultura é só presencial', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send('Agendar consulta de puericultura online para a Luna');
      a.send('Rotina');
      expect(
        a.messages.any(
          (AssistantMessage m) => m.text.contains('só presencial'),
        ),
        isTrue,
      );
    });

    test('horário ocupado na confirmação: oferece outros', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send(BookingAssistant.optBook);
      a.send('Luna Exemplo');
      a.send('Consulta');
      a.send(VisitType.queixa.label);
      a.send(BookingAssistant.optPresencial);
      a.send('Dra. Exemplo A');
      a.send(DayPart.tarde.label);
      final String first = a.options.first;
      a.send(first);
      b.stealBeforeBooking = DateTime(2026, 9, 29, 14, 40);
      a.send(BookingAssistant.optConfirmBooking);
      expect(b.drafts, isEmpty);
      expect(a.options, isNot(contains(first)));
    });

    test('urgência interrompe e orienta, sem gravar', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send(BookingAssistant.optBook);
      a.send('Luna Exemplo');
      a.send('Está com falta de ar e os lábios roxos');
      expect(a.messages.last.card?.kind, AssistantCardKind.urgency);
      expect(a.messages.last.text, contains('192'));
      expect(b.drafts, isEmpty);
    });

    test('remarcar e cancelar dentro das regras', () {
      final FakeBackend b = FakeBackend()
        ..booked.add(
          BookedInterval(
            id: 'm1',
            startsAt: DateTime(2026, 10, 5, 9),
            durationMinutes: 20,
            professionalId: 'pa',
            patientId: 'c1',
          ),
        );
      final BookingAssistant r = BookingAssistant(
        b,
        startWith: AssistantIntent.remarcar,
        appointmentId: 'm1',
      );
      r.send('quinta à tarde');
      expect(r.options.first, 'qui, 01/10 às 14:00');
      r.send(r.options.first);
      expect(
        b.booked.firstWhere((BookedInterval x) => x.id == 'm1').startsAt,
        DateTime(2026, 10, 5, 9),
        reason: 'só grava após confirmar',
      );
      r.send(BookingAssistant.optConfirmReschedule);
      expect(r.messages.last.card?.kind, AssistantCardKind.rescheduled);
      final BookedInterval moved = b.booked.firstWhere(
        (BookedInterval x) => x.id == 'm1',
      );
      expect(moved.startsAt, DateTime(2026, 10, 1, 14));
      expect(moved.durationMinutes, 20);

      final BookingAssistant c = BookingAssistant(b);
      c.send(BookingAssistant.optCancel);
      c.send(BookingAssistant.optKeep);
      expect(
        b.booked.firstWhere((BookedInterval x) => x.id == 'm1').isBlocking,
        isTrue,
      );
      c.send(BookingAssistant.optCancel);
      c.send(BookingAssistant.optConfirmCancel);
      expect(
        b.booked.firstWhere((BookedInterval x) => x.id == 'm1').isBlocking,
        isFalse,
      );
    });

    test('fora do prazo vai para a recepção', () {
      final FakeBackend b = FakeBackend()
        ..booked.add(
          BookedInterval(
            id: 'm2',
            startsAt: DateTime(2026, 9, 29, 16),
            durationMinutes: 20,
            professionalId: 'pa',
            patientId: 'c2',
          ),
        );
      final BookingAssistant a = BookingAssistant(
        b,
        startWith: AssistantIntent.cancelar,
        appointmentId: 'm2',
      );
      expect(a.messages.last.card?.kind, AssistantCardKind.handoff);
      expect(b.handoffs.single, contains('Cancelamento'));
      expect(
        b.booked.firstWhere((BookedInterval x) => x.id == 'm2').isBlocking,
        isTrue,
      );
    });

    test('não entendeu duas vezes: oferece a recepção', () {
      final FakeBackend b = FakeBackend();
      final BookingAssistant a = BookingAssistant(b);
      a.send('xyz');
      a.send('abc');
      expect(a.options, contains(BookingAssistant.optReception));
      a.send(BookingAssistant.optReception);
      expect(b.handoffs, hasLength(1));
    });
  });
}
