import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/dose_calculator.dart';

final DateTime now = DateTime(2026, 9, 27, 10);

const DrugPresentation susp = DrugPresentation(
  id: 'susp',
  label: 'Suspensão 100 mg/5 mL',
  form: PresentationForm.liquid,
  amount: 100,
  perVolumeMl: 5,
  maxVolumePerDoseMl: 20,
);
const DrugPresentation tab = DrugPresentation(
  id: 'tab',
  label: 'Comprimido 500 mg',
  form: PresentationForm.solid,
  amount: 500,
  splittable: true,
  minAgeMonths: 72,
);

DoseReference perDoseRef({bool validated = true, String source = 'Fonte X'}) =>
    DoseReference(
      id: 'a',
      drugName: 'Medicamento Exemplo A',
      indication: 'Indicação exemplo',
      basis: DoseBasis.perDose,
      mgPerKg: 15,
      minMgPerKg: 10,
      maxMgPerKg: 15,
      dosesPerDay: 4,
      maxSingleDoseMg: 500,
      maxDailyDoseMg: 2000,
      presentations: const <DrugPresentation>[susp, tab],
      source: source,
      reviewedAt: DateTime(2026, 1, 10),
      validated: validated,
    );

const DrugPresentation susp50 = DrugPresentation(
  id: 'susp50',
  label: 'Suspensão 250 mg/5 mL',
  form: PresentationForm.liquid,
  amount: 250,
  perVolumeMl: 5,
);

final DoseReference perDayRef = DoseReference(
  id: 'b',
  drugName: 'Medicamento Exemplo B',
  indication: 'Indicação exemplo',
  basis: DoseBasis.perDay,
  mgPerKg: 40,
  dosesPerDay: 2,
  maxDailyDoseMg: 1500,
  minAgeMonths: 24,
  presentations: const <DrugPresentation>[susp50],
  allergyKeywords: const <String>['classe exemplo b'],
  source: 'Fonte Y',
  reviewedAt: DateTime(2026, 2, 1),
  validated: true,
);

DosePatientData patient({
  double? weight = 10,
  DateTime? weighedAt,
  DateTime? birth,
  List<String> allergies = const <String>[],
}) =>
    DosePatientData(
      weightKg: weight,
      weighedAt: weighedAt ?? now.subtract(const Duration(days: 5)),
      birthDate: birth ?? DateTime(2023, 3, 1),
      allergies: allergies,
    );

void main() {
  test('mg/kg/dose: dose por administração, diária e volume em mL', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weight: 10.2),
      now: now,
    );
    expect(c.isBlocked, isFalse);
    expect(c.mgPerDose, closeTo(153, 1e-9));
    expect(c.mgPerDay, closeTo(612, 1e-9));
    expect(c.mlPerDose, closeTo(7.65, 1e-9));
    expect(c.steps.first, '15 mg/kg/dose × 10,2 kg = 153 mg por dose');
    expect(c.steps[1], contains('× 4 doses/dia (de 6/6h) = 612 mg/dia'));
    expect(c.steps[2], '153 mg ÷ 20 mg/mL (Suspensão 100 mg/5 mL) = 7,65 mL por dose');
    expect(c.alerts, isEmpty);
    expect(c.canInsert, isTrue);
    expect(c.perAdministrationLabel, '7,7 mL (153 mg) por dose');
  });

  test('mg/kg/dia: divide a dose diária pelo número de tomadas', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDayRef,
      presentation: susp50,
      patient: patient(weight: 12.8, birth: DateTime(2024, 2, 10)),
      now: now,
    );
    expect(c.isBlocked, isFalse);
    expect(c.mgPerDay, closeTo(512, 1e-9));
    expect(c.mgPerDose, closeTo(256, 1e-9));
    expect(c.mlPerDose, closeTo(5.12, 1e-9));
    expect(c.steps.first, '40 mg/kg/dia × 12,8 kg = 512 mg/dia');
    expect(c.steps[1], '512 mg/dia ÷ 2 doses (de 12/12h) = 256 mg por dose');
  });

  test('conversão mcg e g para mg na concentração', () {
    const DrugPresentation gPerMl = DrugPresentation(
      id: 'g',
      label: '1 g/10 mL',
      form: PresentationForm.liquid,
      amount: 1,
      amountUnit: MassUnit.g,
      perVolumeMl: 10,
    );
    const DrugPresentation mcg = DrugPresentation(
      id: 'mcg',
      label: '500 mcg/mL',
      form: PresentationForm.liquid,
      amount: 500,
      amountUnit: MassUnit.mcg,
      perVolumeMl: 1,
    );
    expect(gPerMl.mgPerMl, 100);
    expect(mcg.mgPerMl, closeTo(0.5, 1e-12));
  });

  test('dose acima do máximo gera alerta crítico e pode ser limitada', () {
    final DoseCalculation over = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weight: 40, birth: DateTime(2015, 1, 1)),
      now: now,
    );
    expect(over.mgPerDose, 600);
    expect(over.exceedsMax, isTrue);
    expect(over.canInsert, isFalse);
    expect(over.alerts.map((DoseAlert a) => a.kind),
        containsAll(<DoseAlertKind>[DoseAlertKind.aboveMaxSingle, DoseAlertKind.aboveMaxDaily]));

    final DoseCalculation limited = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weight: 40, birth: DateTime(2015, 1, 1)),
      now: now,
      limitToMax: true,
    );
    expect(limited.mgPerDose, 500);
    expect(limited.mgPerDay, 2000);
    expect(limited.limitedToMax, isTrue);
    expect(limited.canInsert, isTrue);
    expect(limited.hasWarnings, isTrue);
  });

  test('dados ausentes bloqueiam o cálculo', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: const DosePatientData(),
      now: now,
    );
    expect(c.isBlocked, isTrue);
    expect(c.mgPerDose, isNull);
    expect(c.blockers, containsAll(<String>[
      'Peso não registrado.',
      'Data da pesagem não registrada.',
      'Data de nascimento não registrada.',
    ]));
    expect(c.canInsert, isFalse);

    final DoseCalculation noPres = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: null,
      patient: patient(),
      now: now,
    );
    expect(noPres.blockers, contains('Selecione a apresentação.'));
  });

  test('referência não validada ou sem fonte bloqueia o cálculo', () {
    final DoseCalculation draft = PediatricDoseCalculator.calculate(
      reference: perDoseRef(validated: false),
      presentation: susp,
      patient: patient(),
      now: now,
    );
    expect(draft.isBlocked, isTrue);
    expect(draft.blockers.first, contains('não foi validada'));

    final DoseCalculation noSource = PediatricDoseCalculator.calculate(
      reference: perDoseRef(source: ' '),
      presentation: susp,
      patient: patient(),
      now: now,
    );
    expect(noSource.blockers, contains('A referência de dose não informa a fonte.'));

    final DoseCalculation none = PediatricDoseCalculator.calculate(
      reference: null,
      presentation: null,
      patient: patient(),
      now: now,
    );
    expect(none.isBlocked, isTrue);
  });

  test('peso implausível e concentração inválida bloqueiam', () {
    const DrugPresentation bad = DrugPresentation(
      id: 'susp',
      label: 'Sem volume',
      form: PresentationForm.liquid,
      amount: 100,
    );
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: bad,
      patient: patient(weight: 1020),
      now: now,
    );
    expect(c.blockers, contains('Peso fora do plausível. Confira se está em kg.'));
    expect(c.blockers, contains('Volume da concentração ausente ou inválido.'));
  });

  test('apresentação de outro medicamento bloqueia', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp50,
      patient: patient(),
      now: now,
    );
    expect(c.blockers.single, contains('não pertence'));
  });

  test('peso desatualizado gera alerta que exige ciência', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weighedAt: now.subtract(const Duration(days: 150))),
      now: now,
    );
    final DoseAlert a = c.alerts.single;
    expect(a.kind, DoseAlertKind.outdatedWeight);
    expect(a.isCritical, isFalse);
    expect(c.canInsert, isTrue);
  });

  test('alergia registrada impede a inserção', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDayRef,
      presentation: susp50,
      patient: patient(
        weight: 30,
        birth: DateTime(2018, 1, 1),
        allergies: const <String>['Classe exemplo B (urticária)'],
      ),
      now: now,
    );
    expect(c.alerts.any((DoseAlert a) => a.kind == DoseAlertKind.allergy), isTrue);
    expect(c.canInsert, isFalse);
  });

  test('restrição de idade da referência impede a inserção', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDayRef,
      presentation: susp50,
      patient: patient(weight: 9, birth: DateTime(2025, 7, 1)),
      now: now,
    );
    expect(c.alerts.any((DoseAlert a) => a.kind == DoseAlertKind.ageRestriction), isTrue);
    expect(c.canInsert, isFalse);
  });

  test('comprimido incompatível com idade ou com a dose', () {
    final DoseCalculation young = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: tab,
      patient: patient(weight: 33.3),
      now: now,
    );
    expect(young.unitsPerDose, closeTo(0.999, 1e-9));
    expect(young.alerts.single.kind, DoseAlertKind.incompatiblePresentation);

    final DoseCalculation fraction = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: tab,
      patient: patient(weight: 20, birth: DateTime(2016, 1, 1)),
      now: now,
    );
    expect(fraction.unitsPerDose, closeTo(0.6, 1e-9));
    expect(fraction.alerts.single.kind, DoseAlertKind.incompatiblePresentation);
    expect(fraction.canInsert, isFalse);
  });

  test('mg/kg fora da faixa configurada gera alerta', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weight: 10),
      now: now,
      mgPerKgOverride: 20,
    );
    expect(c.mgPerDose, 200);
    expect(c.alerts.single.kind, DoseAlertKind.outOfConfiguredRange);
  });

  test('volume acima da faixa da apresentação gera alerta', () {
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: perDoseRef(),
      presentation: susp,
      patient: patient(weight: 30, birth: DateTime(2016, 1, 1)),
      now: now,
    );
    expect(c.mlPerDose, closeTo(22.5, 1e-9));
    expect(c.alerts.single.kind, DoseAlertKind.volumeOutOfRange);
  });

  test('formatação pt-BR', () {
    expect(formatDoseNumber(7.65), '7,65');
    expect(formatDoseNumber(612), '612');
    expect(formatDoseNumber(7.65, decimals: 1), '7,7');
    expect(formatAgeMonths(14), '14 meses');
    expect(formatAgeMonths(31), '2 anos e 7 meses');
  });
}
