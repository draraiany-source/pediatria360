/// Registro de triagem pediatrica pre-consulta.
class TriageRecord {
  const TriageRecord({
    required this.id,
    required this.appointmentId,
    required this.childId,
    required this.professionalId,
    required this.recordedBy,
    required this.recordedAt,
    this.weightKg,
    this.heightCm,
    this.headCircumferenceCm,
    this.temperatureC,
    this.heartRate,
    this.respiratoryRate,
    this.spo2,
    this.systolicBp,
    this.diastolicBp,
    this.glucoseMgDl,
    this.painScore,
    this.notes = '',
  });

  factory TriageRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    return TriageRecord(
      id: id ?? (map['id'] as String?) ?? '',
      appointmentId: (map['appointmentId'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      recordedBy: (map['recordedBy'] as String?) ?? '',
      recordedAt: DateTime.tryParse((map['recordedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      headCircumferenceCm: (map['headCircumferenceCm'] as num?)?.toDouble(),
      temperatureC: (map['temperatureC'] as num?)?.toDouble(),
      heartRate: (map['heartRate'] as num?)?.toInt(),
      respiratoryRate: (map['respiratoryRate'] as num?)?.toInt(),
      spo2: (map['spo2'] as num?)?.toInt(),
      systolicBp: (map['systolicBp'] as num?)?.toInt(),
      diastolicBp: (map['diastolicBp'] as num?)?.toInt(),
      glucoseMgDl: (map['glucoseMgDl'] as num?)?.toDouble(),
      painScore: (map['painScore'] as num?)?.toInt(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  final String id;
  final String appointmentId;
  final String childId;
  final String professionalId;
  final String recordedBy;
  final DateTime recordedAt;
  final double? weightKg;
  final double? heightCm;
  final double? headCircumferenceCm;
  final double? temperatureC;
  final int? heartRate;
  final int? respiratoryRate;
  final int? spo2;
  final int? systolicBp;
  final int? diastolicBp;
  final double? glucoseMgDl;
  final int? painScore;
  final String notes;

  /// IMC = peso(kg) / (altura(m))^2. Null se faltar dado.
  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final double meters = heightCm! / 100.0;
    return weightKg! / (meters * meters);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'appointmentId': appointmentId,
        'childId': childId,
        'professionalId': professionalId,
        'recordedBy': recordedBy,
        'recordedAt': recordedAt.toIso8601String(),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'headCircumferenceCm': headCircumferenceCm,
        'temperatureC': temperatureC,
        'heartRate': heartRate,
        'respiratoryRate': respiratoryRate,
        'spo2': spo2,
        'systolicBp': systolicBp,
        'diastolicBp': diastolicBp,
        'glucoseMgDl': glucoseMgDl,
        'painScore': painScore,
        'notes': notes,
        if (bmi != null) 'bmi': bmi,
      };
}
