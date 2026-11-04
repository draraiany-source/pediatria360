import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/routine/child_routine.dart';

void main() {
  final DateTime base = DateTime(2026, 3, 2, 16); // segunda-feira

  RoutineEvent event({
    RoutineRepeat repeat = RoutineRepeat.none,
    DateTime? until,
    List<int> reminders = const <int>[],
    bool allDay = false,
  }) => RoutineEvent(
    id: 'e1',
    patientId: 'p1',
    kind: RoutineKind.atividade,
    title: 'Natação (exemplo)',
    start: base,
    allDay: allDay,
    repeat: repeat,
    until: until,
    reminders: reminders,
    author: 'Família Exemplo',
    createdAt: base.subtract(const Duration(days: 1)),
  );

  group('leitura da receita', () {
    test('intervalo em horas', () {
      expect(parseIntervalHours('de 8/8h'), 8);
      expect(parseIntervalHours('1 vez ao dia (24/24h)'), 24);
      expect(parseIntervalHours('a cada 6 horas'), 6);
      expect(parseIntervalHours('2 vezes ao dia'), 12);
      expect(parseIntervalHours('três vezes ao dia'), 8);
      expect(parseIntervalHours('se dor'), isNull);
    });

    test('duração em dias', () {
      expect(parseDurationDays('5 dias'), 5);
      expect(parseDurationDays('2 semanas'), 14);
      expect(parseDurationDays('uso contínuo'), isNull);
    });

    test('datas e números digitados', () {
      expect(parseHm('07:05'), (hour: 7, minute: 5));
      expect(parseHm('24:00'), isNull);
      expect(parseDmy('31/02/2026'), isNull);
      expect(parseDmy('05/03/2026'), DateTime(2026, 3, 5));
      expect(parseDecimal('37,8'), 37.8);
      expect(formatDecimal(10.40, digits: 2), '10,4');
      expect(formatMinutes(75), '1h15');
      expect(routineDateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(parseRoutineDateKey('2026-02-30'), isNull);
    });
  });

  group('compromissos', () {
    test('semanal gera uma ocorrência por semana e respeita o fim', () {
      final RoutineEvent e = event(
        repeat: RoutineRepeat.weekly,
        until: DateTime(2026, 3, 23),
      );
      final List<DateTime> all = e.occurrencesBetween(
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(all.map((DateTime d) => d.day), <int>[2, 9, 16, 23]);
      expect(all.every((DateTime d) => d.hour == 16), isTrue);
      expect(e.occursOn(DateTime(2026, 3, 30)), isFalse);
    });

    test('diário dentro de uma janela no meio da série', () {
      final RoutineEvent e = event(repeat: RoutineRepeat.daily);
      final List<DateTime> w = e.occurrencesBetween(
        DateTime(2026, 5, 10),
        DateTime(2026, 5, 13),
      );
      expect(w.map((DateTime d) => d.day), <int>[10, 11, 12]);
    });

    test('concluir e cancelar valem só para a ocorrência escolhida', () {
      final RoutineEvent e = event(repeat: RoutineRepeat.weekly);
      final RoutineEvent done = e.withStatus(
        '2026-03-09',
        RoutineStatus.done,
        author: 'Família Exemplo',
        at: DateTime(2026, 3, 9, 17),
      );
      expect(done.statusOf('2026-03-09'), RoutineStatus.done);
      expect(done.statusOf('2026-03-16'), RoutineStatus.planned);
      final RoutineEvent cancelled = done.withStatus(
        '2026-03-16',
        RoutineStatus.cancelled,
        author: 'Família Exemplo',
        at: DateTime(2026, 3, 15),
        note: 'Chuva',
      );
      expect(cancelled.occurrences['2026-03-16']!.note, 'Chuva');
      expect(cancelled.history.map((RoutineChange c) => c.action), <String>[
        'Concluído',
        'Cancelado',
      ]);
      final RoutineEvent reopened = cancelled.withStatus(
        '2026-03-16',
        RoutineStatus.planned,
        author: 'Família Exemplo',
        at: DateTime(2026, 3, 15, 1),
      );
      expect(reopened.statusOf('2026-03-16'), RoutineStatus.planned);
      expect(reopened.history.last.action, 'Reaberto');
    });

    test('edição registra o que mudou; sem mudança nada é gravado', () {
      final RoutineEvent e = event();
      final RoutineEvent same = e.edited(
        e.copyWith(),
        author: 'Família Exemplo',
        at: base,
      );
      expect(identical(same, e), isTrue);
      final RoutineEvent next = e.edited(
        e.copyWith(title: 'Natação infantil', reminders: <int>[60]),
        author: 'Família Exemplo',
        at: base,
      );
      expect(next.title, 'Natação infantil');
      expect(next.history.single.action, 'Editado');
      expect(next.history.single.detail, contains('título'));
      expect(next.history.single.detail, contains('1 hora antes'));
    });

    test('validação', () {
      expect(event().copyWith(title: ' ').validate(), isNotEmpty);
      expect(
        event(
          repeat: RoutineRepeat.daily,
          until: DateTime(2026, 3, 1),
        ).validate(),
        contains('A data final da repetição deve ser depois do início.'),
      );
      expect(event().validate(), isEmpty);
    });
  });

  group('horários da receita', () {
    final MedicationPlan plan = MedicationPlan(
      id: 'm1',
      patientId: 'p1',
      docId: 'd3',
      itemIndex: 0,
      drug: 'Medicamento Exemplo A',
      posology: '5 mL, via oral, de 8/8h, por 5 dias',
      firstDose: DateTime(2026, 3, 2, 8),
      intervalHours: 8,
      days: 5,
      author: 'Família Exemplo',
      createdAt: DateTime(2026, 3, 2),
    );

    test('doses de 8 em 8 horas por 5 dias', () {
      expect(plan.doseCount, 15);
      expect(plan.lastDose, DateTime(2026, 3, 6, 24));
      expect(
        plan.dosesBetween(DateTime(2026, 3, 3), DateTime(2026, 3, 4)).length,
        3,
      );
    });

    test('dose administrada e dose não administrada', () {
      final MedicationPlan p = plan
          .withDose(
            '2026-03-02T08:00',
            RoutineStatus.done,
            author: 'Família Exemplo',
            at: DateTime(2026, 3, 2, 8, 5),
            diaryEntryId: 'r1',
          )
          .withDose(
            '2026-03-02T16:00',
            RoutineStatus.cancelled,
            author: 'Família Exemplo',
            at: DateTime(2026, 3, 2, 20),
            note: 'Vomitou',
          );
      expect(p.givenCount, 1);
      expect(p.doses['2026-03-02T08:00']!.diaryEntryId, 'r1');
      expect(p.statusOf('2026-03-02T16:00'), RoutineStatus.cancelled);
      expect(p.history.last.detail, contains('Vomitou'));
    });
  });

  group('lembretes', () {
    CalendarItem item({
      RoutineStatus status = RoutineStatus.planned,
      List<int> reminders = const <int>[30],
      bool allDay = false,
    }) => CalendarItem(
      id: 'ev:e1:2026-03-02',
      patientId: 'p1',
      kind: RoutineKind.atividade,
      title: 'Natação (exemplo)',
      start: allDay ? DateTime(2026, 3, 2) : base,
      allDay: allDay,
      status: status,
      source: RoutineSource.familia,
      reminders: reminders,
    );

    test('dispara no horário escolhido e só para itens planejados', () {
      final DateTime before = base.subtract(const Duration(minutes: 31));
      final DateTime after = base.subtract(const Duration(minutes: 29));
      expect(
        dueReminders(
          <CalendarItem>[item()],
          from: base.subtract(const Duration(hours: 12)),
          to: before,
        ),
        isEmpty,
      );
      final List<DueReminder> due = dueReminders(
        <CalendarItem>[item()],
        from: base.subtract(const Duration(hours: 12)),
        to: after,
      );
      expect(due.single.minutesBefore, 30);
      expect(
        dueReminders(
          <CalendarItem>[item(status: RoutineStatus.done)],
          from: base.subtract(const Duration(hours: 12)),
          to: after,
        ),
        isEmpty,
      );
      expect(
        dueReminders(
          <CalendarItem>[item()],
          from: base.subtract(const Duration(hours: 12)),
          to: after,
          dismissed: <String>{due.single.key},
        ),
        isEmpty,
      );
    });

    test('dia inteiro: "1 dia antes" avisa às 8h da véspera', () {
      final CalendarItem i = item(allDay: true, reminders: <int>[1440]);
      expect(reminderTime(i, 1440), DateTime(2026, 3, 1, 8));
      expect(
        nextReminder(<CalendarItem>[i], DateTime(2026, 2, 28))!.at,
        DateTime(2026, 3, 1, 8),
      );
    });

    test('rótulos', () {
      expect(kReminderOptions.map(reminderLabel), <String>[
        'No horário',
        '10 min antes',
        '30 min antes',
        '1 hora antes',
        '1 dia antes',
      ]);
    });
  });

  group('diário', () {
    final DateTime now = DateTime(2026, 3, 2, 20);

    test('validação por tipo', () {
      List<String> v(DiaryKind k, DiaryValues x) => x.validate(k, now: now);
      final DateTime at = DateTime(2026, 3, 2, 10);
      expect(
        v(DiaryKind.mamada, DiaryValues(at: at)),
        contains('Escolha peito ou mamadeira.'),
      );
      expect(
        v(DiaryKind.mamada, DiaryValues(at: at, option: 'Mamadeira')),
        contains('Informe quantos mL na mamadeira.'),
      );
      expect(
        v(
          DiaryKind.mamada,
          DiaryValues(at: at, option: 'Mamadeira', quantity: 120, unit: 'mL'),
        ),
        isEmpty,
      );
      expect(
        v(
          DiaryKind.temperatura,
          DiaryValues(at: at, quantity: 378, unit: '°C'),
        ).single,
        contains('34 e 43'),
      );
      expect(
        v(DiaryKind.peso, DiaryValues(at: at)),
        contains('Informe o peso.'),
      );
      expect(
        v(
          DiaryKind.fralda,
          DiaryValues(at: now.add(const Duration(hours: 1)), option: 'Xixi'),
        ),
        contains('O horário não pode estar no futuro.'),
      );
      expect(
        v(
          DiaryKind.sono,
          DiaryValues(at: at, endAt: at.subtract(const Duration(minutes: 5))),
        ),
        contains('O fim deve ser depois do início.'),
      );
      expect(
        v(DiaryKind.observacao, DiaryValues(at: at)),
        contains('Escreva a observação.'),
      );
    });

    test('descrição legível e sem interpretação', () {
      final DateTime at = DateTime(2026, 3, 2, 10, 15);
      expect(
        DiaryValues(
          at: at,
          endAt: DateTime(2026, 3, 2, 11, 30),
        ).describe(DiaryKind.sono),
        '10:15 às 11:30 - 1h15',
      );
      expect(
        DiaryValues(
          at: at,
          quantity: 37.8,
          unit: '°C',
          option: 'Axilar',
        ).describe(DiaryKind.temperatura),
        '37,8 °C - axilar',
      );
      expect(
        DiaryValues(at: at).describe(DiaryKind.sono),
        'dormindo desde 10:15',
      );
    });

    DiaryEntry entry(DiaryKind k, DiaryValues v, {String id = 'r1'}) =>
        DiaryEntry(
          id: id,
          patientId: 'p1',
          kind: k,
          values: v,
          author: 'Família Exemplo',
          role: DiaryRole.familia,
          recordedAt: v.at,
        );

    test('correção guarda a versão anterior; excluir mantém no histórico', () {
      final DiaryEntry e = entry(
        DiaryKind.peso,
        DiaryValues(at: DateTime(2026, 3, 2, 11), quantity: 14, unit: 'kg'),
      );
      final DiaryEntry same = e.corrected(
        values: e.values,
        author: 'Família Exemplo',
        at: now,
      );
      expect(identical(same, e), isTrue);
      final DiaryEntry fixed = e.corrected(
        values: e.values.copyWith(quantity: () => 10.4),
        author: 'Família Exemplo',
        at: now,
        reason: 'Digitei errado',
      );
      expect(fixed.wasCorrected, isTrue);
      expect(fixed.values.quantity, 10.4);
      expect(fixed.revisions.single.before!.quantity, 14);
      expect(fixed.revisions.single.reason, 'Digitei errado');
      final DiaryEntry gone = fixed.voidedBy(
        author: 'Família Exemplo',
        at: now,
        reason: 'Duplicado',
      );
      expect(gone.voided, isTrue);
      expect(gone.revisions, hasLength(2));
    });

    test('sono aberto e fim do sono', () {
      final DiaryEntry s = entry(
        DiaryKind.sono,
        DiaryValues(at: DateTime(2026, 3, 2, 13)),
      );
      expect(s.isOpenSleep, isTrue);
      final DiaryEntry woke = s.finishedSleep(
        end: DateTime(2026, 3, 2, 14, 30),
        author: 'Família Exemplo',
        at: now,
      );
      expect(woke.isOpenSleep, isFalse);
      expect(woke.values.minutes, 90);
      expect(woke.wasCorrected, isFalse);
    });

    test('resumo por período e tipo, sem registros excluídos', () {
      final List<DiaryEntry> list = <DiaryEntry>[
        entry(
          DiaryKind.mamada,
          DiaryValues(
            at: DateTime(2026, 3, 1, 6),
            option: 'Mamadeira',
            quantity: 120,
            unit: 'mL',
          ),
          id: 'a',
        ),
        entry(
          DiaryKind.mamada,
          DiaryValues(
            at: DateTime(2026, 3, 2, 6),
            option: 'Os dois peitos',
            durationMinutes: 15,
          ),
          id: 'b',
        ),
        entry(
          DiaryKind.fralda,
          DiaryValues(at: DateTime(2026, 3, 2, 7), option: 'Xixi e cocô'),
          id: 'c',
        ),
        entry(
          DiaryKind.sono,
          DiaryValues(
            at: DateTime(2026, 3, 2, 10),
            endAt: DateTime(2026, 3, 2, 11, 30),
          ),
          id: 'd',
        ),
        entry(
          DiaryKind.temperatura,
          DiaryValues(
            at: DateTime(2026, 3, 2, 21),
            quantity: 37.8,
            unit: '°C',
            option: 'Axilar',
          ),
          id: 'e',
        ).corrected(
          values: DiaryValues(
            at: DateTime(2026, 3, 2, 21),
            quantity: 37.9,
            unit: '°C',
            option: 'Axilar',
          ),
          author: 'Família Exemplo',
          at: now,
        ),
        entry(
          DiaryKind.observacao,
          DiaryValues(at: DateTime(2026, 3, 2, 9), text: 'Lançado por engano'),
          id: 'f',
        ).voidedBy(author: 'Família Exemplo', at: now, reason: 'Engano'),
        entry(
          DiaryKind.fralda,
          DiaryValues(at: DateTime(2026, 2, 20, 7), option: 'Xixi'),
          id: 'g',
        ),
      ];
      final RoutineSummary s = RoutineSummary.build(
        entries: list,
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 2),
        upcoming: <CalendarItem>[
          CalendarItem(
            id: 'appt:a6',
            patientId: 'p1',
            kind: RoutineKind.retorno,
            title: 'Retorno (exemplo)',
            start: DateTime(2026, 3, 10, 9, 30),
            status: RoutineStatus.planned,
            source: RoutineSource.clinica,
          ),
        ],
      );
      expect(s.days, 2);
      expect(s.entries, hasLength(5));
      final List<String> totals = s.totals();
      expect(
        totals.first,
        'Mamadas: 2 (média de 1 por dia); mamadeira 1 vez(es), total 120 mL',
      );
      expect(
        totals,
        contains('Fraldas: 1 (média de 0,5 por dia); com xixi 1, com cocô 1'),
      );
      expect(
        totals.any((String t) => t.startsWith('Sono registrado: 1h30')),
        isTrue,
      );
      final String text = s.toText(
        patientName: 'Criança Exemplo',
        guardianName: 'Família Exemplo',
        generatedAt: now,
      );
      expect(text, contains('Informado pela família (Família Exemplo)'));
      expect(text, contains('37,9 °C - axilar [corrigido pela família]'));
      expect(text, isNot(contains('Lançado por engano')));
      expect(text, contains('10/03 09:30 Retorno: Retorno (exemplo)'));
      expect(text, contains('não substituem a avaliação do pediatra'));

      final RoutineSummary onlyDiapers = RoutineSummary.build(
        entries: list,
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 2),
        kinds: <DiaryKind>{DiaryKind.fralda},
      );
      expect(onlyDiapers.entries.single.id, 'c');
      final RoutineSummary empty = RoutineSummary.build(
        entries: list,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 2),
      );
      expect(
        empty.toText(patientName: 'X', guardianName: 'Y', generatedAt: now),
        contains('Nenhum registro no período'),
      );
    });
  });
}
