import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/tools/domain/calculators.dart';

void main() {
  group('Holliday-Segar', () {
    test('primeiros 10 kg: 100 mL/kg/dia', () {
      expect(PediatricCalculators.maintenanceFluids(5).perDayMl, 500);
      expect(PediatricCalculators.maintenanceFluids(10).perDayMl, 1000);
    });

    test('de 10 a 20 kg: 1000 mL + 50 mL/kg', () {
      expect(PediatricCalculators.maintenanceFluids(15).perDayMl, 1250);
      expect(PediatricCalculators.maintenanceFluids(20).perDayMl, 1500);
    });

    test('acima de 20 kg: 1500 mL + 20 mL/kg', () {
      expect(PediatricCalculators.maintenanceFluids(30).perDayMl, 1700);
      expect(PediatricCalculators.maintenanceFluids(70).perDayMl, 2500);
    });

    test('a regra 4-2-1 é calculada direto, não derivada da diária', () {
      // 10 kg: 4-2-1 dá 40 mL/h; a diária dividida por 24 dá 41,7. As duas
      // formas são deliberadamente diferentes — este teste protege isso.
      final FluidRequirement f = PediatricCalculators.maintenanceFluids(10);
      expect(f.perHourMl421, 40);
      expect(f.perHourMl, closeTo(41.67, 0.01));
    });

    test('4-2-1 nas três faixas', () {
      expect(PediatricCalculators.maintenanceFluids(8).perHourMl421, 32);
      expect(PediatricCalculators.maintenanceFluids(15).perHourMl421, 50);
      expect(PediatricCalculators.maintenanceFluids(30).perHourMl421, 70);
    });

    test('peso inválido devolve zero', () {
      expect(PediatricCalculators.maintenanceFluids(0).perDayMl, 0);
      expect(PediatricCalculators.maintenanceFluids(-5).perDayMl, 0);
    });
  });

  group('Mosteller', () {
    test('superfície corporal de referência', () {
      expect(
        PediatricCalculators.bodySurfaceArea(weightKg: 70, heightCm: 170),
        closeTo(1.818, 0.001),
      );
      expect(
        PediatricCalculators.bodySurfaceArea(weightKg: 10, heightCm: 75),
        closeTo(0.456, 0.001),
      );
    });

    test('entrada inválida devolve zero', () {
      expect(
        PediatricCalculators.bodySurfaceArea(weightKg: 0, heightCm: 100),
        0,
      );
    });
  });

  group('IMC', () {
    test('calcula peso sobre altura ao quadrado', () {
      expect(
        PediatricCalculators.bmi(weightKg: 16, heightCm: 100),
        closeTo(16, 0.001),
      );
    });
  });

  group('déficit por desidratação', () {
    test('peso x percentual x 10', () {
      expect(
        PediatricCalculators.dehydrationDeficitMl(
          weightKg: 10,
          percentage: 5,
        ),
        500,
      );
    });
  });

  group('idade corrigida', () {
    test('a termo não corrige', () {
      expect(
        PediatricCalculators.correctedAgeMonths(
          chronologicalMonths: 12,
          gestationalWeeks: 39,
        ),
        12,
      );
    });

    test('32 semanas desconta cerca de 2 meses', () {
      expect(
        PediatricCalculators.correctedAgeMonths(
          chronologicalMonths: 12,
          gestationalWeeks: 32,
        ),
        10,
      );
    });

    test('não corrige depois dos 24 meses', () {
      expect(
        PediatricCalculators.correctedAgeMonths(
          chronologicalMonths: 30,
          gestationalWeeks: 30,
        ),
        30,
      );
    });

    test('nunca devolve idade negativa', () {
      expect(
        PediatricCalculators.correctedAgeMonths(
          chronologicalMonths: 0,
          gestationalWeeks: 26,
        ),
        0,
      );
    });
  });

  group('peso estimado APLS', () {
    test('(idade + 4) x 2', () {
      expect(PediatricCalculators.estimatedWeightKg(1), 10);
      expect(PediatricCalculators.estimatedWeightKg(4), 16);
      expect(PediatricCalculators.estimatedWeightKg(10), 28);
    });

    test('fora da faixa de validade devolve nulo', () {
      expect(PediatricCalculators.estimatedWeightKg(0), isNull);
      expect(PediatricCalculators.estimatedWeightKg(11), isNull);
    });
  });

  group('motor de dose', () {
    const DoseProtocol protocol = DoseProtocol(
      drugName: 'Exemplo',
      mgPerKg: 15,
      timesPerDay: 4,
      source: 'Protocolo de teste',
      maxSingleDoseMg: 750,
      maxDailyDoseMg: 3000,
      concentrationMgPerMl: 200,
    );

    test('dose simples é mg/kg x peso', () {
      final DoseResult r =
          DoseCalculator.calculate(protocol: protocol, weightKg: 10);
      expect(r.singleDoseMg, 150);
      expect(r.dailyDoseMg, 600);
      expect(r.hasWarning, isFalse);
    });

    test('converte para volume usando a concentração', () {
      final DoseResult r =
          DoseCalculator.calculate(protocol: protocol, weightKg: 10);
      expect(r.singleDoseMl, closeTo(0.75, 0.001));
    });

    test('respeita o teto por dose e sinaliza', () {
      final DoseResult r =
          DoseCalculator.calculate(protocol: protocol, weightKg: 60);
      expect(r.singleDoseMg, 750);
      expect(r.cappedBySingleMax, isTrue);
      expect(r.hasWarning, isTrue);
    });

    test('teto diário reduz a dose unitária, mantendo as tomadas', () {
      const DoseProtocol capped = DoseProtocol(
        drugName: 'Exemplo',
        mgPerKg: 15,
        timesPerDay: 4,
        source: 'teste',
        maxDailyDoseMg: 1000,
      );
      final DoseResult r =
          DoseCalculator.calculate(protocol: capped, weightKg: 30);

      expect(r.dailyDoseMg, 1000);
      expect(r.singleDoseMg, 250);
      expect(r.cappedByDailyMax, isTrue);
    });

    test('sem concentração não calcula volume', () {
      const DoseProtocol noConc = DoseProtocol(
        drugName: 'Exemplo',
        mgPerKg: 10,
        timesPerDay: 3,
        source: 'teste',
      );
      final DoseResult r =
          DoseCalculator.calculate(protocol: noConc, weightKg: 10);
      expect(r.singleDoseMl, isNull);
    });

    test('sinaliza criança abaixo da idade mínima', () {
      const DoseProtocol restricted = DoseProtocol(
        drugName: 'Exemplo',
        mgPerKg: 10,
        timesPerDay: 2,
        source: 'teste',
        minAgeMonths: 6,
      );
      final DoseResult r = DoseCalculator.calculate(
        protocol: restricted,
        weightKg: 5,
        ageMonths: 3,
      );
      expect(r.belowMinimumAge, isTrue);
      expect(r.hasWarning, isTrue);
    });

    test('peso inválido devolve zero, não lança', () {
      final DoseResult r =
          DoseCalculator.calculate(protocol: protocol, weightKg: 0);
      expect(r.singleDoseMg, 0);
      expect(r.dailyDoseMg, 0);
    });
  });
}
