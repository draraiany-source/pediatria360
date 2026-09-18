import 'package:equatable/equatable.dart';

/// Dominio do marco do desenvolvimento.
enum MilestoneCategory {
  grossMotor,
  fineMotor,
  language,
  social,
  cognitive;

  String get label => switch (this) {
        MilestoneCategory.grossMotor => 'Motor grosso',
        MilestoneCategory.fineMotor => 'Motor fino',
        MilestoneCategory.language => 'Linguagem',
        MilestoneCategory.social => 'Social / afetivo',
        MilestoneCategory.cognitive => 'Cognitivo',
      };

  static MilestoneCategory fromName(String? value) =>
      MilestoneCategory.values.firstWhere(
        (MilestoneCategory c) => c.name == value,
        orElse: () => MilestoneCategory.grossMotor,
      );
}

/// Situacao observada do marco.
enum MilestoneStatus {
  acquired,
  acquiring,
  notObserved,
  needsFollowUp;

  String get label => switch (this) {
        MilestoneStatus.acquired => 'Adquirido',
        MilestoneStatus.acquiring => 'Em aquisicao',
        MilestoneStatus.notObserved => 'Nao observado',
        MilestoneStatus.needsFollowUp => 'Requer seguimento',
      };

  static MilestoneStatus fromName(String? value) =>
      MilestoneStatus.values.firstWhere(
        (MilestoneStatus s) => s.name == value,
        orElse: () => MilestoneStatus.notObserved,
      );
}

/// Registro de um marco do desenvolvimento em um atendimento / consulta.
class DevelopmentMilestoneRecord extends Equatable {
  const DevelopmentMilestoneRecord({
    required this.id,
    required this.childId,
    required this.professionalId,
    required this.category,
    required this.code,
    required this.title,
    required this.status,
    required this.observedAt,
    this.appointmentId,
    this.encounterId,
    this.expectedAgeMonths,
    this.observedAgeMonths,
    this.notes = '',
  });

  factory DevelopmentMilestoneRecord.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return DevelopmentMilestoneRecord(
      id: id ?? (map['id'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      category: MilestoneCategory.fromName(map['category'] as String?),
      code: (map['code'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      status: MilestoneStatus.fromName(map['status'] as String?),
      observedAt: DateTime.tryParse((map['observedAt'] as String?) ?? '') ??
          DateTime.now(),
      appointmentId: map['appointmentId'] as String?,
      encounterId: map['encounterId'] as String?,
      expectedAgeMonths: (map['expectedAgeMonths'] as num?)?.toInt(),
      observedAgeMonths: (map['observedAgeMonths'] as num?)?.toInt(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  final String id;
  final String childId;
  final String professionalId;
  final MilestoneCategory category;

  /// Codigo estavel do marco (ex.: `gm_sits_unsupported`).
  final String code;
  final String title;
  final MilestoneStatus status;
  final DateTime observedAt;

  final String? appointmentId;
  final String? encounterId;
  final int? expectedAgeMonths;
  final int? observedAgeMonths;
  final String notes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'childId': childId,
        'professionalId': professionalId,
        'category': category.name,
        'code': code,
        'title': title,
        'status': status.name,
        'observedAt': observedAt.toIso8601String(),
        'appointmentId': appointmentId,
        'encounterId': encounterId,
        'expectedAgeMonths': expectedAgeMonths,
        'observedAgeMonths': observedAgeMonths,
        'notes': notes,
      };

  @override
  List<Object?> get props => <Object?>[
        id,
        childId,
        professionalId,
        category,
        code,
        title,
        status,
        observedAt,
        appointmentId,
        encounterId,
        expectedAgeMonths,
        observedAgeMonths,
        notes,
      ];
}
