import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/scheduling/follow_up.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 29, 10);
  const FollowUpCriteria criteria = FollowUpCriteria();

  FollowUpStatus classify(
    List<DateTime> visits, {
    DateTime? next,
    DateTime? ret,
    FollowUpCriteria c = criteria,
    int? period,
  }) => classifyFollowUp(
    FollowUpInput(
      patientId: 'x',
      visits: visits,
      nextAppointment: next,
      recommendedReturn: ret,
    ),
    c,
    now: now,
    periodMonths: period,
  );

  group('inativo', () {
    test('sem consulta há mais de N meses e sem consulta futura', () {
      final FollowUpStatus s = classify(<DateTime>[DateTime(2026, 2, 10)]);
      expect(s.isIn(FollowUpCategory.inativo), isTrue);
      expect(s.inactiveButScheduled, isFalse);
    });

    test('NÃO é inativo quem já tem consulta futura marcada', () {
      final FollowUpStatus s = classify(
        <DateTime>[DateTime(2026, 2, 10)],
        next: DateTime(2026, 10, 3, 9),
      );
      expect(s.isIn(FollowUpCategory.inativo), isFalse);
      expect(s.inactiveButScheduled, isTrue);
    });

    test('consulta futura já passada não protege', () {
      final FollowUpStatus s = classify(
        <DateTime>[DateTime(2026, 2, 10)],
        next: DateTime(2026, 9, 1),
      );
      expect(s.isIn(FollowUpCategory.inativo), isTrue);
      expect(s.nextAppointment, isNull);
    });

    test('critério configurável muda a classificação', () {
      final List<DateTime> v = <DateTime>[DateTime(2026, 5, 20)];
      expect(classify(v).isIn(FollowUpCategory.inativo), isFalse);
      expect(
        classify(
          v,
          c: criteria.copyWith(inactiveAfterMonths: 3),
        ).isIn(FollowUpCategory.inativo),
        isTrue,
      );
    });

    test('sem nenhuma consulta não vira inativo', () {
      expect(classify(<DateTime>[]).categories, isEmpty);
    });

    test('usa a consulta mais recente, fora de ordem', () {
      final FollowUpStatus s = classify(<DateTime>[
        DateTime(2025, 1, 1),
        DateTime(2026, 9, 1),
        DateTime(2025, 6, 1),
      ]);
      expect(s.lastVisit, DateTime(2026, 9, 1));
      expect(s.isIn(FollowUpCategory.inativo), isFalse);
    });
  });

  group('frequente', () {
    final List<DateTime> visits = <DateTime>[
      DateTime(2026, 8, 1),
      DateTime(2026, 5, 1),
      DateTime(2026, 1, 1),
      DateTime(2025, 6, 1),
    ];

    test('conta consultas no período padrão (12 meses)', () {
      final FollowUpStatus s = classify(visits);
      expect(s.visitsInPeriod, 3);
      expect(s.isIn(FollowUpCategory.frequente), isTrue);
    });

    test('filtro de período do painel', () {
      final FollowUpStatus s = classify(visits, period: 6);
      expect(s.visitsInPeriod, 2);
      expect(s.isIn(FollowUpCategory.frequente), isFalse);
    });
  });

  group('retorno próximo', () {
    test('faltam até N dias', () {
      final FollowUpStatus s = classify(
        <DateTime>[DateTime(2026, 9, 1)],
        ret: DateTime(2026, 10, 10),
      );
      expect(s.daysToReturn, 11);
      expect(s.isIn(FollowUpCategory.retornoProximo), isTrue);
      expect(returnLabel(s), 'Retorno em 11 dias');
    });

    test('longe demais não entra; critério maior entra', () {
      final DateTime ret = DateTime(2026, 10, 25);
      expect(
        classify(<DateTime>[], ret: ret).isIn(FollowUpCategory.retornoProximo),
        isFalse,
      );
      expect(
        classify(
          <DateTime>[],
          ret: ret,
          c: criteria.copyWith(returnSoonDays: 30),
        ).isIn(FollowUpCategory.retornoProximo),
        isTrue,
      );
    });

    test('vencido sem agendamento entra; vencido já agendado não', () {
      final DateTime ret = DateTime(2026, 9, 20);
      final FollowUpStatus open = classify(<DateTime>[], ret: ret);
      expect(open.isIn(FollowUpCategory.retornoProximo), isTrue);
      expect(returnLabel(open), 'Retorno vencido há 9 dias');
      expect(
        classify(
          <DateTime>[],
          ret: ret,
          next: DateTime(2026, 10, 2),
        ).isIn(FollowUpCategory.retornoProximo),
        isFalse,
      );
    });
  });

  test('contagem por indicador', () {
    final List<FollowUpStatus> all = <FollowUpStatus>[
      classify(<DateTime>[DateTime(2025, 1, 1)]),
      classify(<DateTime>[], ret: DateTime(2026, 10, 1)),
      classify(<DateTime>[DateTime(2025, 1, 1)], next: DateTime(2026, 10, 1)),
    ];
    final Map<FollowUpCategory, int> c = countFollowUp(all);
    expect(c[FollowUpCategory.inativo], 1);
    expect(c[FollowUpCategory.retornoProximo], 1);
    expect(c[FollowUpCategory.frequente], 0);
  });

  test('validação dos critérios', () {
    expect(criteria.validate(), isNull);
    expect(criteria.copyWith(inactiveAfterMonths: 0).validate(), isNotNull);
    expect(criteria.copyWith(returnSoonDays: 200).validate(), isNotNull);
    expect(criteria.copyWith(frequentMinVisits: 1).validate(), isNotNull);
    expect(criteria.copyWith(frequentWindowMonths: 30).validate(), isNotNull);
  });

  test('subtractMonths ajusta fim de mês', () {
    expect(subtractMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 28));
    expect(subtractMonths(DateTime(2026, 1, 15), 2), DateTime(2025, 11, 15));
  });
}
