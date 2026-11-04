import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/routine/child_routine.dart';
import 'package:pediatria360/shared/routine/sleep_log.dart';

void main() {
  int n = 0;
  DiaryEntry sleep(
    DateTime at, {
    DateTime? end,
    String option = '',
    List<SleepWaking> wakings = const <SleepWaking>[],
    String note = '',
    bool voided = false,
  }) => DiaryEntry(
    id: 's${++n}',
    patientId: 'p1',
    kind: DiaryKind.sono,
    values: DiaryValues(
      at: at,
      endAt: end,
      option: option,
      wakings: wakings,
      note: note,
    ),
    author: 'Família',
    role: DiaryRole.familia,
    recordedAt: at,
    voided: voided,
  );

  final DateTime mon = DateTime(2026, 9, 21);
  DateTime at(int day, int h, [int m = 0]) =>
      DateTime(mon.year, mon.month, mon.day + day, h, m);

  group('tipo de sono', () {
    test('escolhido pela família prevalece', () {
      expect(
        sleepTypeOf(sleep(at(0, 21), end: at(0, 22), option: kSleepNight)),
        SleepType.night,
      );
      expect(
        sleepTypeOf(sleep(at(0, 20), end: at(1, 6), option: kSleepNap)),
        SleepType.nap,
      );
    });

    test('sem escolha: noite longa ou em andamento vira noturno', () {
      expect(inferSleepType(at(0, 20, 30), 570), SleepType.night);
      expect(inferSleepType(at(0, 20, 30), null), SleepType.night);
      expect(inferSleepType(at(0, 10), 75), SleepType.nap);
      expect(inferSleepType(at(0, 19), 40), SleepType.nap);
    });

    test('noite de madrugada conta para o dia anterior', () {
      expect(nightOf(at(1, 0, 30)), at(0, 0));
      expect(nightOf(at(0, 20, 30)), at(0, 0));
    });
  });

  group('resumo por dia e por semana', () {
    List<DiaryEntry> week() => <DiaryEntry>[
      sleep(
        at(0, 20, 30),
        end: at(1, 6),
        option: kSleepNight,
        wakings: <SleepWaking>[
          SleepWaking(at: at(1, 1, 10), minutesAwake: 20),
          SleepWaking(at: at(1, 4)),
        ],
      ),
      sleep(at(0, 10), end: at(0, 11, 15), option: kSleepNap),
      sleep(
        at(0, 15),
        end: at(0, 16),
        option: kSleepNap,
        note: 'Dormiu no colo',
      ),
      sleep(at(1, 21), end: at(2, 6, 30), option: kSleepNight),
      sleep(at(1, 13), end: at(1, 14, 30)),
      sleep(at(2, 9), end: at(2, 9, 30), voided: true),
    ];

    test('dia soma a noite que começou nele e os cochilos', () {
      final SleepWeek w = SleepWeek.build(
        entries: week(),
        from: mon,
        to: at(6, 0),
      );
      final SleepDay d0 = w.days[0];
      expect(d0.nightMinutes, 570);
      expect(d0.napCount, 2);
      expect(d0.napMinutes, 135);
      expect(d0.totalMinutes, 705);
      expect(d0.wakingCount, 2);
      expect(d0.longestNightStretch, 280);
      expect(
        d0.describe(),
        'noite 9h30 com 2 despertares - 2 cochilos (2h15) - total 11h45',
      );
      final SleepDay d1 = w.days[1];
      expect(d1.nightMinutes, 570);
      expect(d1.napCount, 1);
      expect(w.days[2].isEmpty, isTrue, reason: 'registro excluído não conta');
    });

    test('semana: médias só entre dias com registro', () {
      final SleepWeek w = SleepWeek.build(
        entries: week(),
        from: mon,
        to: at(6, 0),
      );
      expect(w.daysWithRecords, 2);
      expect(w.avgNightMinutes, 570);
      expect(w.totalWakings, 2);
      expect(w.avgWakings, 1);
      expect(w.avgNapCount, 1.5);
      expect(w.bedtimeRange!.$1, at(0, 20, 30));
      expect(w.bedtimeRange!.$2, at(1, 21));
      final List<String> lines = w.lines();
      expect(lines.first, '2 de 7 dias com registro de sono.');
      expect(
        lines,
        contains(
          'Sono noturno: média de 9h30 por noite (2 noites); '
          'início entre 20:30 e 21:00.',
        ),
      );
      expect(
        lines,
        contains('Despertares: 2 no período (média de 1 por noite).'),
      );
      final String text = w.toClinicalText();
      expect(
        text,
        startsWith(
          'Diário do sono informado pela família (21/09/2026 a 27/09/2026):',
        ),
      );
      expect(text, contains('Observação da família em 21/09: Dormiu no colo'));
      expect(text, endsWith('conferir na consulta.'));
    });

    test('semana vazia diz que não há registro', () {
      final SleepWeek w = SleepWeek.build(
        entries: const <DiaryEntry>[],
        from: mon,
        to: at(6, 0),
      );
      expect(w.isEmpty, isTrue);
      expect(w.lines(), <String>['Nenhum sono registrado no período.']);
    });
  });

  group('linha do tempo', () {
    test('sono que atravessa a meia-noite vira dois trechos', () {
      final List<DiaryEntry> e = <DiaryEntry>[
        sleep(
          at(0, 20, 30),
          end: at(1, 6),
          option: kSleepNight,
          wakings: <SleepWaking>[SleepWaking(at: at(1, 2))],
        ),
      ];
      final ({List<SleepSegment> segments, List<int> wakings}) d0 = sleepOnDay(
        e,
        at(0, 0),
        now: at(3, 0),
      );
      expect(d0.segments.single.fromMinute, 20 * 60 + 30);
      expect(d0.segments.single.toMinute, 1440);
      expect(d0.wakings, isEmpty);
      final ({List<SleepSegment> segments, List<int> wakings}) d1 = sleepOnDay(
        e,
        at(1, 0),
        now: at(3, 0),
      );
      expect(d1.segments.single.fromMinute, 0);
      expect(d1.segments.single.toMinute, 360);
      expect(d1.wakings, <int>[120]);
    });

    test('sono em andamento vai até agora', () {
      final ({List<SleepSegment> segments, List<int> wakings}) d = sleepOnDay(
        <DiaryEntry>[sleep(at(0, 13))],
        at(0, 0),
        now: at(0, 14, 10),
      );
      expect(d.segments.single.open, isTrue);
      expect(d.segments.single.toMinute, 14 * 60 + 10);
    });
  });

  group('despertares no diário', () {
    test('descrição, validação e histórico', () {
      final DiaryEntry s = sleep(at(0, 20), option: kSleepNight);
      final DiaryEntry w = s.withWaking(
        SleepWaking(at: at(1, 2, 15), minutesAwake: 15),
        author: 'Família',
        at: at(1, 2, 30),
      );
      expect(w.values.wakings.single.describe(), '02:15 (15 min)');
      expect(w.revisions.single.action, 'Despertar registrado');
      expect(w.revisions.single.before!.wakings, isEmpty);
      final DiaryEntry done = w.finishedSleep(
        end: at(1, 6),
        author: 'Família',
        at: at(1, 6),
      );
      expect(
        done.describe,
        'Sono noturno - 20:00 às 06:00 - 10h - 1 despertar (02:15 (15 min))',
      );
      final List<String> errors = DiaryValues(
        at: at(0, 20),
        endAt: at(1, 6),
        wakings: <SleepWaking>[
          SleepWaking(at: at(1, 7)),
          SleepWaking(at: at(1, 3), minutesAwake: 0),
        ],
      ).validate(DiaryKind.sono, now: at(2, 0));
      expect(
        errors,
        contains('O despertar das 07:00 fica fora do período de sono.'),
      );
      expect(
        errors,
        contains('Tempo sem dormir no despertar: use de 1 a 600 minutos.'),
      );
    });

    test('correção compara despertares', () {
      final DiaryValues a = DiaryValues(
        at: at(0, 20),
        wakings: <SleepWaking>[SleepWaking(at: at(1, 1))],
      );
      expect(a.sameAs(a.copyWith()), isTrue);
      expect(a.sameAs(a.copyWith(wakings: const <SleepWaking>[])), isFalse);
    });
  });
}
