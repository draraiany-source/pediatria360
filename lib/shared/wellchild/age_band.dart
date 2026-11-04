/// Faixas etárias usadas para separar modelos de orientação e sugestões de
/// marcos, e a idade da consulta (cronológica ou corrigida).
library;

import '../clinical/growth.dart';

enum ChildAgeBand {
  ate3m('0 a 3 meses', 0, 4),
  de4a11m('4 a 11 meses', 4, 12),
  de1a2a('1 a 2 anos', 12, 36),
  de3a5a('3 a 5 anos', 36, 72),
  de6a('6 anos ou mais', 72, null);

  const ChildAgeBand(this.label, this.fromMonths, this.untilMonths);

  final String label;
  final int fromMonths;

  /// Limite superior (exclusivo); `null` = sem limite.
  final int? untilMonths;

  static ChildAgeBand forMonths(int months) {
    for (final ChildAgeBand b in ChildAgeBand.values) {
      if (months >= b.fromMonths &&
          (b.untilMonths == null || months < b.untilMonths!)) {
        return b;
      }
    }
    return months < 0 ? ate3m : de6a;
  }

  static ChildAgeBand? fromName(String? name) {
    for (final ChildAgeBand b in ChildAgeBand.values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// Idade da criança numa data, com a correção para prematuros quando se
/// aplica (mesma regra das curvas de crescimento).
class VisitAge {
  VisitAge._(this.growthAge, this.gestationalAgeDays);

  factory VisitAge.of({
    required DateTime birthDate,
    required DateTime at,
    int? gestationalAgeDays,
  }) => VisitAge._(
    GrowthAge.of(
      birthDate: birthDate,
      at: at,
      gestationalAgeDays: gestationalAgeDays,
    ),
    gestationalAgeDays,
  );

  final GrowthAge growthAge;
  final int? gestationalAgeDays;

  bool get usesCorrected => growthAge.usesCorrected;

  String get chronologicalLabel => growthAge.chronologicalLabel;
  String? get correctedLabel => growthAge.correctedLabel;

  /// Meses usados para escolher a faixa (corrigidos, quando se aplica).
  int get referenceMonths {
    final int days = growthAge.referenceDays;
    return days < 0 ? 0 : (days / daysPerMonth).floor();
  }

  ChildAgeBand get band => ChildAgeBand.forMonths(referenceMonths);

  /// Identificação para o prontuário e o PDF.
  String get label => usesCorrected
      ? 'Idade cronológica: $chronologicalLabel. Idade corrigida: '
            '$correctedLabel (nascimento com '
            '${formatGestationalAge(gestationalAgeDays!)}; correção usada '
            'até 24 meses para curvas, marcos e faixa das orientações).'
      : 'Idade: $chronologicalLabel.';

  /// Versão curta para cabeçalhos.
  String get shortLabel => usesCorrected
      ? '$chronologicalLabel (corrigida: $correctedLabel)'
      : chronologicalLabel;
}
