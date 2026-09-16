import 'package:equatable/equatable.dart';

/// Uma medição antropométrica registrada em uma data.
///
/// Os três campos são opcionais de propósito: numa consulta de rotina pesa-se
/// e mede-se tudo, mas em casa o responsável muitas vezes só tem a balança.
/// Exigir os três faria o registro simplesmente não acontecer.
class GrowthRecord extends Equatable {
  const GrowthRecord({
    required this.id,
    required this.childId,
    required this.measuredAt,
    required this.updatedAt,
    this.weightKg,
    this.heightCm,
    this.headCircumferenceCm,
    this.note,
    this.pendingSync = false,
  });

  final String id;
  final String childId;

  /// Data da medição — não é a data do registro. Um responsável pode lançar
  /// hoje o peso anotado na consulta da semana passada.
  final DateTime measuredAt;

  final DateTime updatedAt;

  final double? weightKg;
  final double? heightCm;

  /// Perímetro cefálico. Relevante clinicamente até os 3 anos; depois disso a
  /// medida deixa de compor o acompanhamento de rotina.
  final double? headCircumferenceCm;

  final String? note;
  final bool pendingSync;

  bool get isEmpty =>
      weightKg == null && heightCm == null && headCircumferenceCm == null;

  /// IMC. Só faz sentido com peso e altura juntos.
  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm == 0) return null;
    final double heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  GrowthRecord copyWith({
    DateTime? measuredAt,
    DateTime? updatedAt,
    double? weightKg,
    double? heightCm,
    double? headCircumferenceCm,
    String? note,
    bool? pendingSync,
  }) =>
      GrowthRecord(
        id: id,
        childId: childId,
        measuredAt: measuredAt ?? this.measuredAt,
        updatedAt: updatedAt ?? this.updatedAt,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        headCircumferenceCm: headCircumferenceCm ?? this.headCircumferenceCm,
        note: note ?? this.note,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        childId,
        measuredAt,
        weightKg,
        heightCm,
        headCircumferenceCm,
        note,
        updatedAt,
        pendingSync,
      ];
}

/// Indicador antropométrico avaliado contra a referência da OMS.
enum GrowthIndicator {
  weightForAge,
  heightForAge,
  bmiForAge,
  headForAge;

  String get label => switch (this) {
        GrowthIndicator.weightForAge => 'Peso para idade',
        GrowthIndicator.heightForAge => 'Estatura para idade',
        GrowthIndicator.bmiForAge => 'IMC para idade',
        GrowthIndicator.headForAge => 'Perímetro cefálico',
      };

  String get shortLabel => switch (this) {
        GrowthIndicator.weightForAge => 'Peso',
        GrowthIndicator.heightForAge => 'Estatura',
        GrowthIndicator.bmiForAge => 'IMC',
        GrowthIndicator.headForAge => 'P. cefálico',
      };

  String get unit => switch (this) {
        GrowthIndicator.weightForAge => 'kg',
        GrowthIndicator.heightForAge => 'cm',
        GrowthIndicator.bmiForAge => 'kg/m²',
        GrowthIndicator.headForAge => 'cm',
      };

  /// Idade máxima, em meses, em que o indicador é acompanhado.
  int get maxAgeMonths => switch (this) {
        GrowthIndicator.weightForAge => 120,
        GrowthIndicator.heightForAge => 228,
        GrowthIndicator.bmiForAge => 228,
        GrowthIndicator.headForAge => 36,
      };
}
