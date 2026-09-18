/// Rascunho/prescricao de suplemento ? so finaliza com confirmacao medica.
enum SupplementRxStatus {
  draft,
  confirmed,
  cancelled;

  String get label => switch (this) {
        SupplementRxStatus.draft => 'Rascunho',
        SupplementRxStatus.confirmed => 'Confirmada',
        SupplementRxStatus.cancelled => 'Cancelada',
      };

  static SupplementRxStatus fromName(String? v) =>
      SupplementRxStatus.values.firstWhere(
        (SupplementRxStatus s) => s.name == v,
        orElse: () => SupplementRxStatus.draft,
      );
}

class SupplementPrescription {
  const SupplementPrescription({
    required this.id,
    required this.childId,
    required this.professionalId,
    required this.createdAt,
    this.updatedAt,
    this.micronutrientId = '',
    this.productName = '',
    this.activeIngredient = '',
    this.presentation = '',
    this.concentration = '',
    this.doseText = '',
    this.unit = '',
    this.frequency = '',
    this.route = 'oral',
    this.duration = '',
    this.quantity = '',
    this.instructions = '',
    this.status = SupplementRxStatus.draft,
    this.confirmedAt,
    this.confirmedBy,
    this.calculatorSuggestion = '',
    this.clinicalNote = '',
  });

  factory SupplementPrescription.fromMap(Map<String, dynamic> map, {String? id}) {
    return SupplementPrescription(
      id: id ?? (map['id'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.tryParse(map['updatedAt'] as String),
      micronutrientId: (map['micronutrientId'] as String?) ?? '',
      productName: (map['productName'] as String?) ?? '',
      activeIngredient: (map['activeIngredient'] as String?) ?? '',
      presentation: (map['presentation'] as String?) ?? '',
      concentration: (map['concentration'] as String?) ?? '',
      doseText: (map['doseText'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? '',
      frequency: (map['frequency'] as String?) ?? '',
      route: (map['route'] as String?) ?? 'oral',
      duration: (map['duration'] as String?) ?? '',
      quantity: (map['quantity'] as String?) ?? '',
      instructions: (map['instructions'] as String?) ?? '',
      status: SupplementRxStatus.fromName(map['status'] as String?),
      confirmedAt: map['confirmedAt'] == null
          ? null
          : DateTime.tryParse(map['confirmedAt'] as String),
      confirmedBy: map['confirmedBy'] as String?,
      calculatorSuggestion: (map['calculatorSuggestion'] as String?) ?? '',
      clinicalNote: (map['clinicalNote'] as String?) ?? '',
    );
  }

  final String id;
  final String childId;
  final String professionalId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String micronutrientId;
  final String productName;
  final String activeIngredient;
  final String presentation;
  final String concentration;
  final String doseText;
  final String unit;
  final String frequency;
  final String route;
  final String duration;
  final String quantity;
  final String instructions;
  final SupplementRxStatus status;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final String calculatorSuggestion;
  final String clinicalNote;

  bool get isEditable => status == SupplementRxStatus.draft;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'childId': childId,
        'professionalId': professionalId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'micronutrientId': micronutrientId,
        'productName': productName,
        'activeIngredient': activeIngredient,
        'presentation': presentation,
        'concentration': concentration,
        'doseText': doseText,
        'unit': unit,
        'frequency': frequency,
        'route': route,
        'duration': duration,
        'quantity': quantity,
        'instructions': instructions,
        'status': status.name,
        'confirmedAt': confirmedAt?.toIso8601String(),
        'confirmedBy': confirmedBy,
        'calculatorSuggestion': calculatorSuggestion,
        'clinicalNote': clinicalNote,
      };
}
