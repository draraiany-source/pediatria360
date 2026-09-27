import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/growth.dart';

void main() {
  final WhoGrowthTables tables = WhoGrowthTables.fromJson(
    jsonDecode(File('assets/data/who_growth_lms.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final GrowthCalculator calc = GrowthCalculator(tables);
  final DateTime birth = DateTime(2025, 1, 10);

  GrowthMeasurement m(
    DateTime date, {
    double? w,
    double? l,
    double? hc,
    MeasurePosition pos = MeasurePosition.lying,
  }) => GrowthMeasurement(
    id: 'g${date.millisecondsSinceEpoch}',
    patientId: 'p',
    values: GrowthValues(
      date: date,
      weightKg: w,
      lengthCm: l,
      headCm: hc,
      position: pos,
    ),
    author: 'teste',
    recordedAt: date,
  );

  group('tabelas oficiais da OMS', () {
    test('valores publicados ao nascer (Padrões 2006)', () {
      final WhoLookup boy = tables.lookup(
        GrowthIndicator.weightForAge,
        GrowthSex.male,
        0,
      )!;
      expect(boy.lms.l, 0.3487);
      expect(boy.lms.m, 3.3464);
      expect(boy.lms.s, 0.14602);
      expect(boy.referenceId, 'who2006');
      final WhoLookup girl = tables.lookup(
        GrowthIndicator.lengthHeightForAge,
        GrowthSex.female,
        0,
      )!;
      expect(girl.lms.m, 49.1477);
      expect(girl.measure, 'length');
    });

    test('comprimento até 730 dias e altura depois', () {
      expect(
        tables
            .lookup(GrowthIndicator.lengthHeightForAge, GrowthSex.male, 730)!
            .measure,
        'length',
      );
      expect(
        tables
            .lookup(GrowthIndicator.lengthHeightForAge, GrowthSex.male, 731)!
            .measure,
        'height',
      );
    });

    test('peso de menino aos 12 meses: -2 e +2 escores Z da tabela mensal', () {
      final LmsValues lms = tables
          .lookup(GrowthIndicator.weightForAge, GrowthSex.male, 365)!
          .lms;
      expect(lms.valueAt(-2), closeTo(7.7, 0.05));
      expect(lms.valueAt(2), closeTo(12.0, 0.05));
    });

    test('Referência 2007 após 5 anos e limites de cada indicador', () {
      final WhoLookup ref = tables.lookup(
        GrowthIndicator.lengthHeightForAge,
        GrowthSex.female,
        (120 * daysPerMonth).round(),
      )!;
      expect(ref.referenceId, 'who2007');
      expect(ref.lms.m, closeTo(138.6, 0.2));
      expect(
        tables
            .lookup(GrowthIndicator.weightForAge, GrowthSex.male, 1826)!
            .referenceId,
        'who2006',
      );
      expect(
        tables.lookup(GrowthIndicator.weightForAge, GrowthSex.male, 4000),
        isNull,
      );
      expect(
        tables.lookup(GrowthIndicator.headForAge, GrowthSex.male, 1900),
        isNull,
      );
      expect(
        tables.lookup(GrowthIndicator.bmiForAge, GrowthSex.female, 6900),
        isNotNull,
      );
    });
  });

  group('escore Z e percentil', () {
    test('mediana dá Z zero e percentil 50', () {
      final LmsValues lms = tables
          .lookup(GrowthIndicator.weightForAge, GrowthSex.male, 0)!
          .lms;
      expect(whoZScore(lms, 3.3464, restricted: true), closeTo(0, 1e-9));
      expect(formatPercentile(0), 'P50');
    });

    test('método restrito da OMS além de +3 e -3 para peso', () {
      final LmsValues lms = tables
          .lookup(GrowthIndicator.weightForAge, GrowthSex.male, 365)!
          .lms;
      final double sd3 = lms.valueAt(3);
      final double sd2 = lms.valueAt(2);
      expect(
        whoZScore(lms, sd3 + (sd3 - sd2), restricted: true),
        closeTo(4, 1e-9),
      );
      final double sd3n = lms.valueAt(-3);
      final double sd2n = lms.valueAt(-2);
      expect(
        whoZScore(lms, sd3n - (sd2n - sd3n), restricted: true),
        closeTo(-4, 1e-9),
      );
    });

    test('percentil limitado nas extremidades', () {
      expect(formatPercentile(-3.5), '< P0,1');
      expect(formatPercentile(3.5), '> P99,9');
      expect(formatPercentile(2.5), 'P99,4');
      expect(formatZ(-1.234), '-1,23');
      expect(formatZ(0.5), '+0,50');
    });
  });

  group('idade e posição', () {
    test('altura medida em pé antes de 24 meses soma 0,7 cm', () {
      final GrowthPoint p = calc.assess(
        measurement: m(
          DateTime(2026, 1, 10),
          l: 75,
          pos: MeasurePosition.standing,
        ),
        indicator: GrowthIndicator.lengthHeightForAge,
        sex: GrowthSex.male,
        birthDate: birth,
      )!;
      expect(p.value, closeTo(75.7, 1e-9));
      expect(p.adjustment, contains('+0,7'));
      expect(p.lookup!.measure, 'length');
    });

    test('prematuro: idade corrigida até 24 meses cronológicos', () {
      final GrowthAge a = GrowthAge.of(
        birthDate: birth,
        at: birth.add(const Duration(days: 84)),
        gestationalAgeDays: 32 * 7,
      );
      expect(a.usesCorrected, isTrue);
      expect(a.chronologicalDays, 84);
      expect(a.correctedDays, 28);

      final GrowthAge later = GrowthAge.of(
        birthDate: birth,
        at: birth.add(const Duration(days: 800)),
        gestationalAgeDays: 32 * 7,
      );
      expect(later.usesCorrected, isFalse);

      final GrowthAge term = GrowthAge.of(
        birthDate: birth,
        at: birth.add(const Duration(days: 84)),
        gestationalAgeDays: 39 * 7,
      );
      expect(term.usesCorrected, isFalse);
    });

    test('antes do termo corrigido não há escore (referência neonatal)', () {
      final GrowthPoint p = calc.assess(
        measurement: m(birth.add(const Duration(days: 20)), w: 1.9),
        indicator: GrowthIndicator.weightForAge,
        sex: GrowthSex.female,
        birthDate: birth,
        gestationalAgeDays: 32 * 7,
      )!;
      expect(p.z, isNull);
      expect(p.unavailable, contains('neonatal'));
      expect(p.age.correctedDays, lessThan(0));
    });

    test('peso após 10 anos não tem referência: orienta usar IMC', () {
      final GrowthPoint p = calc.assess(
        measurement: m(birth.add(const Duration(days: 4000)), w: 35),
        indicator: GrowthIndicator.weightForAge,
        sex: GrowthSex.male,
        birthDate: birth,
      )!;
      expect(p.z, isNull);
      expect(p.unavailable, contains('IMC'));
    });

    test('IMC usa o comprimento ajustado', () {
      final GrowthPoint p = calc.assess(
        measurement: m(birth.add(const Duration(days: 1000)), w: 13, l: 90),
        indicator: GrowthIndicator.bmiForAge,
        sex: GrowthSex.male,
        birthDate: birth,
      )!;
      expect(p.value, closeTo(13 / (0.893 * 0.893), 1e-6));
      expect(p.z, isNotNull);
    });
  });

  group('histórico de correções', () {
    final GrowthMeasurement first = m(DateTime(2026, 1, 10), w: 91);

    test('corrigir guarda o valor anterior, o motivo e o autor', () {
      final GrowthMeasurement fixed = first.correct(
        values: GrowthValues(date: DateTime(2026, 1, 10), weightKg: 9.1),
        reason: 'Vírgula esquecida',
        author: 'Dra. Teste',
        at: DateTime(2026, 1, 11),
      );
      expect(fixed.values.weightKg, 9.1);
      expect(fixed.revisions.single.before.weightKg, 91);
      expect(fixed.revisions.single.reason, 'Vírgula esquecida');
      expect(fixed.wasCorrected, isTrue);
    });

    test('correção exige motivo e alguma mudança', () {
      expect(
        () => first.correct(
          values: GrowthValues(date: DateTime(2026, 1, 10), weightKg: 9.1),
          reason: ' ',
          author: 'x',
          at: DateTime(2026),
        ),
        throwsStateError,
      );
      expect(
        () => first.correct(
          values: first.values,
          reason: 'nada',
          author: 'x',
          at: DateTime(2026),
        ),
        throwsStateError,
      );
    });

    test('lançamento anulado sai da curva e fica no histórico', () {
      final GrowthMeasurement voided = first.voidEntry(
        reason: 'Paciente errado',
        author: 'x',
        at: DateTime(2026, 1, 12),
      );
      expect(voided.revisions.single.voided, isTrue);
      final List<GrowthPoint> s = calc.series(
        measurements: <GrowthMeasurement>[
          voided,
          m(DateTime(2026, 2, 10), w: 9.4),
        ],
        indicator: GrowthIndicator.weightForAge,
        sex: GrowthSex.male,
        birthDate: birth,
      );
      expect(s.length, 1);
    });

    test(
      'validação barra data futura, antes do nascimento e erro grosseiro',
      () {
        final List<String> e = GrowthValues.validate(
          GrowthValues(date: DateTime(2024), weightKg: 900),
          birthDate: birth,
          now: DateTime(2026),
        );
        expect(e, hasLength(2));
        expect(
          GrowthValues.validate(
            GrowthValues(date: DateTime(2027)),
            birthDate: birth,
            now: DateTime(2026),
          ),
          hasLength(2),
        );
      },
    );
  });

  test('curva de referência é contínua dentro da janela', () {
    final List<(double, double)> c = calc.curve(
      indicator: GrowthIndicator.weightForAge,
      sex: GrowthSex.female,
      z: 0,
      fromDays: 0,
      toDays: 730,
    );
    expect(c.first.$1, 0);
    expect(c.last.$1, closeTo(24, 0.3));
    for (int i = 1; i < c.length; i++) {
      expect(c[i].$2, greaterThan(c[i - 1].$2));
    }
  });

  test('idade formatada', () {
    expect(formatAgeDays(10), '10 dias');
    expect(formatAgeDays(400), '13 meses e 4 dias');
    expect(formatAgeDays(1000), '2 anos e 8 meses');
    expect(formatAgeDays(-20), '3 semanas antes do termo');
    expect(formatGestationalAge(34 * 7 + 2), '34 semanas e 2 dias');
    expect(GrowthSex.fromLabel('Menina'), GrowthSex.female);
    expect(GrowthSex.fromLabel('Menino'), GrowthSex.male);
  });

  test('idade exibida em calendario', () {
    expect(
      formatAgeBetween(DateTime(2025, 7, 3), DateTime(2026, 7, 3)),
      '12 meses',
    );
    expect(
      formatAgeBetween(DateTime(2025, 7, 3), DateTime(2025, 8, 2)),
      '30 dias',
    );
    expect(
      formatAgeBetween(DateTime(2025, 7, 3), DateTime(2025, 8, 3)),
      '1 mês',
    );
    expect(
      formatAgeBetween(DateTime(2025, 1, 31), DateTime(2025, 3, 1)),
      '1 mês e 1 dia',
    );
    expect(
      formatAgeBetween(DateTime(2023, 1, 10), DateTime(2025, 10, 20)),
      '2 anos e 9 meses',
    );
    expect(
      formatAgeBetween(DateTime(2025, 7, 3), DateTime(2025, 6, 19)),
      '2 semanas antes do termo',
    );

    final GrowthAge a = GrowthAge.of(
      birthDate: DateTime(2025, 7, 3),
      at: DateTime(2026, 9, 17),
      gestationalAgeDays: 34 * 7 + 2,
    );
    expect(a.chronologicalLabel, '14 meses e 14 dias');
    // Termo provavel: 40 dias depois do nascimento (12/08/2025).
    expect(a.correctedLabel, '13 meses e 5 dias');
    expect(
      GrowthAge.of(
        birthDate: DateTime(2020, 1, 1),
        at: DateTime(2026, 1, 1),
      ).correctedLabel,
      isNull,
    );
  });
}
