/// Calculadora pediátrica de doses.
///
/// Faz aritmética de conferência sobre uma referência de dose cadastrada e
/// validada. Não conhece nenhum medicamento, não sugere dose e não prescreve:
/// sem referência validada, sem peso datado ou sem data de nascimento, o
/// cálculo fica bloqueado.
library;

import 'dart:math' as math;

enum MassUnit {
  mcg('mcg', 0.001),
  mg('mg', 1),
  g('g', 1000);

  const MassUnit(this.label, this.toMg);

  final String label;
  final double toMg;
}

enum DoseBasis {
  perDose('mg/kg/dose'),
  perDay('mg/kg/dia');

  const DoseBasis(this.label);

  final String label;
}

enum PresentationForm { liquid, solid }

/// Apresentação comercial: concentração por mL (líquido) ou por unidade
/// (comprimido, cápsula).
class DrugPresentation {
  const DrugPresentation({
    required this.id,
    required this.label,
    required this.form,
    required this.amount,
    this.amountUnit = MassUnit.mg,
    this.perVolumeMl,
    this.unitName = 'comprimido',
    this.splittable = false,
    this.minAgeMonths,
    this.maxVolumePerDoseMl,
  });

  final String id;
  final String label;
  final PresentationForm form;

  /// Quantidade de princípio ativo em [perVolumeMl] mL (líquido) ou em uma
  /// unidade (sólido).
  final double amount;
  final MassUnit amountUnit;
  final double? perVolumeMl;
  final String unitName;

  /// Sólido que pode ser partido ao meio.
  final bool splittable;
  final int? minAgeMonths;
  final double? maxVolumePerDoseMl;

  bool get isLiquid => form == PresentationForm.liquid;

  double? get mgPerMl {
    if (!isLiquid || perVolumeMl == null || perVolumeMl! <= 0) return null;
    return amount * amountUnit.toMg / perVolumeMl!;
  }

  double? get mgPerUnit => isLiquid ? null : amount * amountUnit.toMg;

  String get concentrationLabel => isLiquid
      ? '${formatDoseNumber(amount)} ${amountUnit.label}/'
            '${formatDoseNumber(perVolumeMl ?? 0)} mL'
      : '${formatDoseNumber(amount)} ${amountUnit.label} por $unitName';

  /// Erro de cadastro que impede o uso da apresentação.
  String? get validationError {
    if (!amount.isFinite || amount <= 0) {
      return 'Concentração da apresentação inválida.';
    }
    if (isLiquid && (perVolumeMl == null || perVolumeMl! <= 0)) {
      return 'Volume da concentração ausente ou inválido.';
    }
    if (!isLiquid && perVolumeMl != null) {
      return 'Apresentação sólida não pode ter concentração em mL.';
    }
    return null;
  }
}

/// Referência de dose cadastrada por quem responde pelo protocolo.
class DoseReference {
  const DoseReference({
    required this.id,
    required this.drugName,
    required this.indication,
    required this.basis,
    required this.mgPerKg,
    required this.dosesPerDay,
    required this.presentations,
    required this.source,
    this.minMgPerKg,
    this.maxMgPerKg,
    this.maxSingleDoseMg,
    this.maxDailyDoseMg,
    this.minAgeMonths,
    this.maxAgeMonths,
    this.allergyKeywords = const <String>[],
    this.reviewedAt,
    this.reviewedBy,
    this.validated = false,
  });

  final String id;
  final String drugName;
  final String indication;
  final DoseBasis basis;

  /// Dose de referência na unidade de [basis].
  final double mgPerKg;

  /// Faixa configurada para o mg/kg escolhido pelo prescritor.
  final double? minMgPerKg;
  final double? maxMgPerKg;
  final int dosesPerDay;
  final double? maxSingleDoseMg;
  final double? maxDailyDoseMg;
  final int? minAgeMonths;
  final int? maxAgeMonths;
  final List<DrugPresentation> presentations;

  /// Termos que, presentes nas alergias do paciente, disparam alerta.
  final List<String> allergyKeywords;
  final String source;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final bool validated;

  bool get isUsable =>
      validated && source.trim().isNotEmpty && reviewedAt != null;

  double get intervalHours => 24 / dosesPerDay;

  String get intervalLabel {
    final double h = intervalHours;
    final String hs = formatDoseNumber(h);
    return dosesPerDay == 1 ? '1 vez ao dia (24/24h)' : 'de $hs/${hs}h';
  }
}

class DosePatientData {
  const DosePatientData({
    this.name,
    this.weightKg,
    this.weighedAt,
    this.birthDate,
    this.allergies = const <String>[],
  });

  final String? name;
  final double? weightKg;
  final DateTime? weighedAt;
  final DateTime? birthDate;
  final List<String> allergies;
}

/// Quanto tempo uma pesagem continua valendo para cálculo, por idade.
class WeightFreshnessPolicy {
  const WeightFreshnessPolicy({
    this.underOneYear = const Duration(days: 30),
    this.underFiveYears = const Duration(days: 90),
    this.olderChildren = const Duration(days: 180),
  });

  final Duration underOneYear;
  final Duration underFiveYears;
  final Duration olderChildren;

  Duration maxAgeFor(int ageMonths) {
    if (ageMonths < 12) return underOneYear;
    if (ageMonths < 60) return underFiveYears;
    return olderChildren;
  }
}

enum DoseAlertKind {
  outdatedWeight,
  aboveMaxSingle,
  aboveMaxDaily,
  limitedToMax,
  allergy,
  ageRestriction,
  incompatiblePresentation,
  outOfConfiguredRange,
  volumeOutOfRange,
}

enum DoseAlertSeverity {
  /// Exige ciência explícita do prescritor antes de inserir.
  warning,

  /// Impede a inserção na receita.
  critical,
}

class DoseAlert {
  const DoseAlert(this.kind, this.severity, this.message);

  final DoseAlertKind kind;
  final DoseAlertSeverity severity;
  final String message;

  bool get isCritical => severity == DoseAlertSeverity.critical;
}

class DoseCalculation {
  const DoseCalculation._({
    required this.blockers,
    this.reference,
    this.presentation,
    this.weightKg,
    this.weighedAt,
    this.ageMonths,
    this.mgPerKgUsed,
    this.mgPerDose,
    this.mgPerDay,
    this.mlPerDose,
    this.unitsPerDose,
    this.limitedToMax = false,
    this.alerts = const <DoseAlert>[],
    this.steps = const <String>[],
  });

  /// Motivos que impedem o cálculo. Vazio quando o cálculo foi feito.
  final List<String> blockers;
  final DoseReference? reference;
  final DrugPresentation? presentation;
  final double? weightKg;
  final DateTime? weighedAt;
  final int? ageMonths;
  final double? mgPerKgUsed;
  final double? mgPerDose;
  final double? mgPerDay;
  final double? mlPerDose;
  final double? unitsPerDose;
  final bool limitedToMax;
  final List<DoseAlert> alerts;

  /// A conta, passo a passo, como deve ser exibida ao prescritor.
  final List<String> steps;

  bool get isBlocked => blockers.isNotEmpty;
  bool get hasCritical => alerts.any((DoseAlert a) => a.isCritical);
  bool get hasWarnings => alerts.any((DoseAlert a) => !a.isCritical);
  bool get canInsert => !isBlocked && !hasCritical;
  bool get exceedsMax => alerts.any(
    (DoseAlert a) =>
        a.kind == DoseAlertKind.aboveMaxSingle ||
        a.kind == DoseAlertKind.aboveMaxDaily,
  );

  /// Dose por administração como será lida pelo responsável.
  String get perAdministrationLabel {
    if (isBlocked) return '';
    final String mg = '${formatDoseNumber(mgPerDose!)} mg';
    if (mlPerDose != null) {
      return '${formatDoseNumber(mlPerDose!, decimals: 1)} mL ($mg) por dose';
    }
    if (unitsPerDose != null) {
      final String u = formatDoseNumber(unitsPerDose!);
      return '$u ${presentation!.unitName}${unitsPerDose! > 1 ? 's' : ''} '
          '($mg) por dose';
    }
    return '$mg por dose';
  }
}

int ageInMonths(DateTime birthDate, DateTime now) {
  int months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  if (now.day < birthDate.day) months--;
  return math.max(0, months);
}

String formatAgeMonths(int months) {
  if (months < 24) return '$months ${months == 1 ? 'mês' : 'meses'}';
  final int years = months ~/ 12;
  final int rest = months % 12;
  return rest == 0
      ? '$years anos'
      : '$years anos e $rest ${rest == 1 ? 'mês' : 'meses'}';
}

/// Número em pt-BR, sem zeros à direita.
String formatDoseNumber(double value, {int decimals = 2}) {
  String s = value.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

class PediatricDoseCalculator {
  const PediatricDoseCalculator._();

  static const double _eps = 1e-9;

  static DoseCalculation calculate({
    required DoseReference? reference,
    required DrugPresentation? presentation,
    required DosePatientData patient,
    required DateTime now,
    double? mgPerKgOverride,
    bool limitToMax = false,
    WeightFreshnessPolicy policy = const WeightFreshnessPolicy(),
  }) {
    final List<String> blockers = <String>[];
    final double? w = patient.weightKg;

    if (reference == null) {
      blockers.add('Selecione um medicamento com referência cadastrada.');
    } else {
      if (!reference.validated) {
        blockers.add(
          'A referência de dose de ${reference.drugName} ainda '
          'não foi validada. Cálculo bloqueado.',
        );
      }
      if (reference.source.trim().isEmpty) {
        blockers.add('A referência de dose não informa a fonte.');
      }
      if (reference.reviewedAt == null) {
        blockers.add('A referência de dose não tem data de revisão.');
      }
      if (reference.dosesPerDay <= 0 || reference.dosesPerDay > 24) {
        blockers.add('Número de doses por dia inválido na referência.');
      }
    }
    if (w == null) {
      blockers.add('Peso não registrado.');
    } else if (!w.isFinite || w < 0.3 || w > 150) {
      blockers.add('Peso fora do plausível. Confira se está em kg.');
    }
    if (patient.weighedAt == null) {
      blockers.add('Data da pesagem não registrada.');
    } else if (patient.weighedAt!.isAfter(now)) {
      blockers.add('Data da pesagem no futuro.');
    }
    if (patient.birthDate == null) {
      blockers.add('Data de nascimento não registrada.');
    }
    if (presentation == null) {
      blockers.add('Selecione a apresentação.');
    } else {
      final String? err = presentation.validationError;
      if (err != null) blockers.add(err);
      if (reference != null &&
          !reference.presentations.any(
            (DrugPresentation p) => p.id == presentation.id,
          )) {
        blockers.add('A apresentação não pertence a ${reference.drugName}.');
      }
    }
    final double mgPerKg = mgPerKgOverride ?? reference?.mgPerKg ?? 0;
    if (!mgPerKg.isFinite || mgPerKg <= 0) {
      blockers.add('Dose de referência (mg/kg) ausente ou inválida.');
    }

    if (blockers.isNotEmpty) {
      return DoseCalculation._(blockers: blockers);
    }

    final DoseReference ref = reference!;
    final DrugPresentation pres = presentation!;
    final int n = ref.dosesPerDay;
    final int age = ageInMonths(patient.birthDate!, now);
    final List<DoseAlert> alerts = <DoseAlert>[];
    final List<String> steps = <String>[];
    final String wLabel = '${formatDoseNumber(w!)} kg';

    double perDose;
    double perDay;
    if (ref.basis == DoseBasis.perDose) {
      perDose = mgPerKg * w;
      perDay = perDose * n;
      steps
        ..add(
          '${formatDoseNumber(mgPerKg)} mg/kg/dose × $wLabel = '
          '${formatDoseNumber(perDose)} mg por dose',
        )
        ..add(
          '${formatDoseNumber(perDose)} mg × $n doses/dia '
          '(${ref.intervalLabel}) = ${formatDoseNumber(perDay)} mg/dia',
        );
    } else {
      perDay = mgPerKg * w;
      perDose = perDay / n;
      steps
        ..add(
          '${formatDoseNumber(mgPerKg)} mg/kg/dia × $wLabel = '
          '${formatDoseNumber(perDay)} mg/dia',
        )
        ..add(
          '${formatDoseNumber(perDay)} mg/dia ÷ $n doses '
          '(${ref.intervalLabel}) = ${formatDoseNumber(perDose)} mg por dose',
        );
    }

    final bool aboveSingle =
        ref.maxSingleDoseMg != null && perDose > ref.maxSingleDoseMg! + _eps;
    final bool aboveDaily =
        ref.maxDailyDoseMg != null && perDay > ref.maxDailyDoseMg! + _eps;
    bool limited = false;

    if ((aboveSingle || aboveDaily) && limitToMax) {
      if (aboveSingle) perDose = ref.maxSingleDoseMg!;
      perDay = perDose * n;
      if (ref.maxDailyDoseMg != null && perDay > ref.maxDailyDoseMg!) {
        perDay = ref.maxDailyDoseMg!;
        perDose = perDay / n;
      }
      limited = true;
      steps.add(
        'Limitado à dose máxima: ${formatDoseNumber(perDose)} mg por '
        'dose e ${formatDoseNumber(perDay)} mg/dia',
      );
      alerts.add(
        DoseAlert(
          DoseAlertKind.limitedToMax,
          DoseAlertSeverity.warning,
          'A dose calculada ultrapassava o máximo e foi limitada a '
          '${formatDoseNumber(perDose)} mg por dose.',
        ),
      );
    } else {
      if (aboveSingle) {
        alerts.add(
          DoseAlert(
            DoseAlertKind.aboveMaxSingle,
            DoseAlertSeverity.critical,
            'Dose por administração (${formatDoseNumber(perDose)} mg) acima do '
            'máximo de ${formatDoseNumber(ref.maxSingleDoseMg!)} mg.',
          ),
        );
      }
      if (aboveDaily) {
        alerts.add(
          DoseAlert(
            DoseAlertKind.aboveMaxDaily,
            DoseAlertSeverity.critical,
            'Dose diária (${formatDoseNumber(perDay)} mg) acima do máximo de '
            '${formatDoseNumber(ref.maxDailyDoseMg!)} mg/dia.',
          ),
        );
      }
    }

    double? ml;
    double? units;
    if (pres.isLiquid) {
      ml = perDose / pres.mgPerMl!;
      steps.add(
        '${formatDoseNumber(perDose)} mg ÷ '
        '${formatDoseNumber(pres.mgPerMl!)} mg/mL (${pres.label}) = '
        '${formatDoseNumber(ml)} mL por dose',
      );
      if (pres.maxVolumePerDoseMl != null && ml > pres.maxVolumePerDoseMl!) {
        alerts.add(
          DoseAlert(
            DoseAlertKind.volumeOutOfRange,
            DoseAlertSeverity.warning,
            'Volume por dose (${formatDoseNumber(ml)} mL) acima da faixa '
            'configurada para esta apresentação '
            '(${formatDoseNumber(pres.maxVolumePerDoseMl!)} mL).',
          ),
        );
      }
    } else {
      units = perDose / pres.mgPerUnit!;
      steps.add(
        '${formatDoseNumber(perDose)} mg ÷ '
        '${formatDoseNumber(pres.mgPerUnit!)} mg por ${pres.unitName} = '
        '${formatDoseNumber(units)} ${pres.unitName}(s) por dose',
      );
      final double step = pres.splittable ? 0.5 : 1;
      final double nearest = (units / step).round() * step;
      if (nearest == 0 || (units - nearest).abs() / units > 0.1) {
        alerts.add(
          DoseAlert(
            DoseAlertKind.incompatiblePresentation,
            DoseAlertSeverity.critical,
            'A dose não corresponde a uma fração utilizável do ${pres.unitName} '
            '(${formatDoseNumber(units)} por dose). Escolha outra apresentação.',
          ),
        );
      }
    }

    if (pres.minAgeMonths != null && age < pres.minAgeMonths!) {
      alerts.add(
        DoseAlert(
          DoseAlertKind.incompatiblePresentation,
          DoseAlertSeverity.critical,
          '${pres.label} não é adequada para ${formatAgeMonths(age)} '
          '(mínimo configurado: ${formatAgeMonths(pres.minAgeMonths!)}).',
        ),
      );
    }
    if (ref.minAgeMonths != null && age < ref.minAgeMonths!) {
      alerts.add(
        DoseAlert(
          DoseAlertKind.ageRestriction,
          DoseAlertSeverity.critical,
          '${ref.drugName} tem restrição de idade: mínimo de '
          '${formatAgeMonths(ref.minAgeMonths!)} na referência cadastrada.',
        ),
      );
    }
    if (ref.maxAgeMonths != null && age > ref.maxAgeMonths!) {
      alerts.add(
        DoseAlert(
          DoseAlertKind.ageRestriction,
          DoseAlertSeverity.critical,
          'A referência cadastrada vale até ${formatAgeMonths(ref.maxAgeMonths!)}.',
        ),
      );
    }

    final List<String> terms = <String>[ref.drugName, ...ref.allergyKeywords]
        .map((String t) => t.toLowerCase().trim())
        .where((String t) => t.isNotEmpty)
        .toList();
    for (final String allergy in patient.allergies) {
      final String a = allergy.toLowerCase().trim();
      if (a.isEmpty) continue;
      if (terms.any((String t) => a.contains(t) || t.contains(a))) {
        alerts.add(
          DoseAlert(
            DoseAlertKind.allergy,
            DoseAlertSeverity.critical,
            'Alergia registrada: "$allergy".',
          ),
        );
      }
    }

    if ((ref.minMgPerKg != null && mgPerKg < ref.minMgPerKg! - _eps) ||
        (ref.maxMgPerKg != null && mgPerKg > ref.maxMgPerKg! + _eps)) {
      alerts.add(
        DoseAlert(
          DoseAlertKind.outOfConfiguredRange,
          DoseAlertSeverity.warning,
          '${formatDoseNumber(mgPerKg)} ${ref.basis.label} fora da faixa '
          'configurada (${formatDoseNumber(ref.minMgPerKg ?? 0)} a '
          '${formatDoseNumber(ref.maxMgPerKg ?? mgPerKg)} ${ref.basis.label}).',
        ),
      );
    }

    final Duration weightAge = now.difference(patient.weighedAt!);
    final Duration maxWeightAge = policy.maxAgeFor(age);
    if (weightAge > maxWeightAge) {
      alerts.add(
        DoseAlert(
          DoseAlertKind.outdatedWeight,
          DoseAlertSeverity.warning,
          'Peso registrado há ${weightAge.inDays} dias (limite para a idade: '
          '${maxWeightAge.inDays} dias). Considere pesar novamente.',
        ),
      );
    }

    return DoseCalculation._(
      blockers: const <String>[],
      reference: ref,
      presentation: pres,
      weightKg: w,
      weighedAt: patient.weighedAt,
      ageMonths: age,
      mgPerKgUsed: mgPerKg,
      mgPerDose: perDose,
      mgPerDay: perDay,
      mlPerDose: ml,
      unitsPerDose: units,
      limitedToMax: limited,
      alerts: alerts,
      steps: steps,
    );
  }
}
