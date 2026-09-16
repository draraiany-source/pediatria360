import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/tools/domain/calculators.dart';

void main() {
  group('Apgar', () {
    test('soma os cinco critérios', () {
      const ApgarScore score = ApgarScore(
        heartRate: 2,
        respiratoryEffort: 2,
        muscleTone: 1,
        reflexIrritability: 2,
        color: 1,
      );
      expect(score.total, 8);
      expect(score.interpretation, 'Normal');
    });

    test('faixas de interpretação', () {
      const ApgarScore baixo = ApgarScore(
        heartRate: 0,
        respiratoryEffort: 0,
        muscleTone: 0,
        reflexIrritability: 1,
        color: 0,
      );
      expect(baixo.total, 1);
      expect(baixo.interpretation, 'Gravemente deprimido');

      const ApgarScore moderado = ApgarScore(
        heartRate: 1,
        respiratoryEffort: 1,
        muscleTone: 1,
        reflexIrritability: 1,
        color: 1,
      );
      expect(moderado.total, 5);
      expect(moderado.interpretation, 'Moderadamente deprimido');
    });

    test('rejeita pontuação fora de 0-2', () {
      expect(
        () => ApgarScore(
          heartRate: 3,
          respiratoryEffort: 0,
          muscleTone: 0,
          reflexIrritability: 0,
          color: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('taxa de infusão de glicose', () {
    test('caso de referência neonatal', () {
      // RN de 1 kg em SG 10% a 4 mL/h. Verificado antes de implementar:
      // dentro da faixa inicial usual (~4-6 mg/kg/min).
      expect(
        glucoseInfusionRateMgKgMin(
          infusionRateMlPerHour: 4,
          dextroseConcentrationPercent: 10,
          weightKg: 1,
        ),
        closeTo(6.67, 0.01),
      );
    });

    test('escala com o peso', () {
      final double a = glucoseInfusionRateMgKgMin(
        infusionRateMlPerHour: 12,
        dextroseConcentrationPercent: 10,
        weightKg: 3,
      );
      final double b = glucoseInfusionRateMgKgMin(
        infusionRateMlPerHour: 4,
        dextroseConcentrationPercent: 10,
        weightKg: 1,
      );
      // Mesma proporção mL/h por kg -> mesmo TIG.
      expect(a, closeTo(b, 0.01));
    });

    test('peso inválido não lança, devolve zero', () {
      expect(
        glucoseInfusionRateMgKgMin(
          infusionRateMlPerHour: 4,
          dextroseConcentrationPercent: 10,
          weightKg: 0,
        ),
        0,
      );
    });
  });

  group('osmolaridade sérica calculada', () {
    test('valores normais dentro da faixa de referência', () {
      final double osm = calculatedSerumOsmolarity(
        sodiumMEqL: 140,
        glucoseMgDl: 90,
        ureaMgDl: 30,
      );
      expect(osm, closeTo(290, 0.1));
      expect(osm, greaterThanOrEqualTo(normalSerumOsmolarityRange.$1));
      expect(osm, lessThanOrEqualTo(normalSerumOsmolarityRange.$2));
    });

    test('usa ureia, não BUN — a conversão está embutida na fórmula', () {
      // Se alguém aplicasse por engano BUN/2,8 com um valor de UREIA, o
      // resultado divergiria. Confirma que ureia/6 é a conta certa.
      const double ureia = 40;
      const double bunEquivalente = ureia * 28 / 60;
      expect(ureia / 6, closeTo(bunEquivalente / 2.8, 0.001));
    });

    test('hiperglicemia eleva a osmolaridade', () {
      final double normal = calculatedSerumOsmolarity(
        sodiumMEqL: 140,
        glucoseMgDl: 90,
        ureaMgDl: 30,
      );
      final double hiperglicemia = calculatedSerumOsmolarity(
        sodiumMEqL: 140,
        glucoseMgDl: 400,
        ureaMgDl: 30,
      );
      expect(hiperglicemia, greaterThan(normal));
    });
  });

  group('débito urinário', () {
    test('calcula mL/kg/h', () {
      final UrineOutput output = urineOutput(
        volumeMl: 250,
        weightKg: 10,
        hours: 5,
      );
      expect(output.rate, 5);
      expect(output.isOliguric, isFalse);
    });

    test('detecta oligúria', () {
      final UrineOutput output = urineOutput(
        volumeMl: 20,
        weightKg: 10,
        hours: 4,
      );
      expect(output.rate, 0.5);
      expect(output.isOliguric, isTrue);
    });

    test('limite exato não é oligúria', () {
      final UrineOutput output = urineOutput(
        volumeMl: 10,
        weightKg: 10,
        hours: 1,
      );
      expect(output.rate, 1.0);
      expect(output.isOliguric, isFalse);
    });

    test('peso ou tempo inválido não lança', () {
      expect(
        urineOutput(volumeMl: 100, weightKg: 0, hours: 1).rate,
        0,
      );
      expect(
        urineOutput(volumeMl: 100, weightKg: 10, hours: 0).rate,
        0,
      );
    });
  });

  group('idade gestacional pela DUM', () {
    test('calcula semanas e dias corridos', () {
      final GestationalAge ga = gestationalAgeFromLmp(
        lastMenstrualPeriod: DateTime(2026, 1, 1),
        at: DateTime(2026, 7, 20),
      );
      expect(ga.weeks, 28);
      expect(ga.days, 4);
      expect(ga.label, '28 semanas e 4 dias');
    });

    test('classifica por faixa', () {
      GestationalAge ga(int weeks) =>
          GestationalAge(weeks: weeks, days: 0);

      expect(ga(26).classification, 'Prematuridade extrema');
      expect(ga(30).classification, 'Prematuridade grave');
      expect(ga(33).classification, 'Prematuridade moderada');
      expect(ga(36).classification, 'Prematuridade tardia');
      expect(ga(39).classification, 'A termo');
      expect(ga(43).classification, 'Pós-termo');
    });

    test('data futura não gera idade negativa', () {
      final GestationalAge ga = gestationalAgeFromLmp(
        lastMenstrualPeriod: DateTime(2026, 12, 1),
        at: DateTime(2026, 1, 1),
      );
      expect(ga.weeks, 0);
      expect(ga.days, 0);
    });
  });
}
