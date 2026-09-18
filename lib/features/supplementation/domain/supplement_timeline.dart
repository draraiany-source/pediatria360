/// Evento da timeline de suplementacao no prontuario.
enum SupplementTimelineKind {
  labResult,
  supplementationStarted,
  followUp,
  prescription,
  clinicalNote,
  parentGuidance,
  other;

  String get label => switch (this) {
        SupplementTimelineKind.labResult => 'Exame',
        SupplementTimelineKind.supplementationStarted => 'Suplementacao iniciada',
        SupplementTimelineKind.followUp => 'Retorno',
        SupplementTimelineKind.prescription => 'Prescricao',
        SupplementTimelineKind.clinicalNote => 'Nota clinica',
        SupplementTimelineKind.parentGuidance => 'Orientacao aos pais',
        SupplementTimelineKind.other => 'Evento',
      };

  static SupplementTimelineKind fromName(String? v) =>
      SupplementTimelineKind.values.firstWhere(
        (SupplementTimelineKind k) => k.name == v,
        orElse: () => SupplementTimelineKind.other,
      );
}

class SupplementTimelineEvent {
  const SupplementTimelineEvent({
    required this.id,
    required this.childId,
    required this.kind,
    required this.title,
    required this.occurredAt,
    required this.createdBy,
    this.detail = '',
    this.relatedExamId = '',
    this.relatedRxId = '',
    this.numericValue,
  });

  factory SupplementTimelineEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    return SupplementTimelineEvent(
      id: id ?? (map['id'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      kind: SupplementTimelineKind.fromName(map['kind'] as String?),
      title: (map['title'] as String?) ?? '',
      occurredAt: DateTime.tryParse((map['occurredAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: (map['createdBy'] as String?) ?? '',
      detail: (map['detail'] as String?) ?? '',
      relatedExamId: (map['relatedExamId'] as String?) ?? '',
      relatedRxId: (map['relatedRxId'] as String?) ?? '',
      numericValue: (map['numericValue'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String childId;
  final SupplementTimelineKind kind;
  final String title;
  final DateTime occurredAt;
  final String createdBy;
  final String detail;
  final String relatedExamId;
  final String relatedRxId;
  final double? numericValue;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'childId': childId,
        'kind': kind.name,
        'title': title,
        'occurredAt': occurredAt.toIso8601String(),
        'createdBy': createdBy,
        'detail': detail,
        'relatedExamId': relatedExamId,
        'relatedRxId': relatedRxId,
        'numericValue': numericValue,
      };
}
