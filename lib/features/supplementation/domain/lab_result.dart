/// Resultado laboratorial registrado pelo profissional (sem auto-diagnostico).
enum LabResultFlag {
  unset,
  normal,
  attention,
  altered;

  String get label => switch (this) {
        LabResultFlag.unset => 'Nao classificado',
        LabResultFlag.normal => 'Normal',
        LabResultFlag.attention => 'Atencao',
        LabResultFlag.altered => 'Alterado',
      };

  static LabResultFlag fromName(String? v) => LabResultFlag.values.firstWhere(
        (LabResultFlag f) => f.name == v,
        orElse: () => LabResultFlag.unset,
      );
}

class PatientLabResult {
  const PatientLabResult({
    required this.id,
    required this.childId,
    required this.examId,
    required this.examName,
    required this.recordedBy,
    required this.recordedAt,
    this.valueText = '',
    this.unit = '',
    this.labName = '',
    this.referenceText = '',
    this.notes = '',
    this.flag = LabResultFlag.unset,
    this.professionalFlagNote = '',
  });

  factory PatientLabResult.fromMap(Map<String, dynamic> map, {String? id}) {
    return PatientLabResult(
      id: id ?? (map['id'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      examId: (map['examId'] as String?) ?? '',
      examName: (map['examName'] as String?) ?? '',
      recordedBy: (map['recordedBy'] as String?) ?? '',
      recordedAt: DateTime.tryParse((map['recordedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      valueText: (map['valueText'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? '',
      labName: (map['labName'] as String?) ?? '',
      referenceText: (map['referenceText'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      flag: LabResultFlag.fromName(map['flag'] as String?),
      professionalFlagNote: (map['professionalFlagNote'] as String?) ?? '',
    );
  }

  final String id;
  final String childId;
  final String examId;
  final String examName;
  final String recordedBy;
  final DateTime recordedAt;
  final String valueText;
  final String unit;
  final String labName;
  final String referenceText;
  final String notes;
  final LabResultFlag flag;
  final String professionalFlagNote;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'childId': childId,
        'examId': examId,
        'examName': examName,
        'recordedBy': recordedBy,
        'recordedAt': recordedAt.toIso8601String(),
        'valueText': valueText,
        'unit': unit,
        'labName': labName,
        'referenceText': referenceText,
        'notes': notes,
        'flag': flag.name,
        'professionalFlagNote': professionalFlagNote,
      };
}
