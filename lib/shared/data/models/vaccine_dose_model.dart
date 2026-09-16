import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/vaccine.dart';

/// Conversor de [VaccineDose] entre Firestore, SQLite e domínio.
class VaccineDoseMapper {
  const VaccineDoseMapper._();

  static VaccineDose fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String childId,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return VaccineDose(
      id: doc.id,
      childId: childId,
      vaccineId: (data['vaccineId'] as String?) ?? '',
      doseIndex: (data['doseIndex'] as num?)?.toInt() ?? 1,
      dueAt: _date(data['dueAt']),
      appliedAt: _date(data['appliedAt']),
      lot: data['lot'] as String?,
      clinic: data['clinic'] as String?,
      proofUrl: data['proofUrl'] as String?,
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toOutboxPayload(
    VaccineDose dose,
    String ownerId,
  ) =>
      <String, dynamic>{
        'ownerId': ownerId,
        'childId': dose.childId,
        'vaccineId': dose.vaccineId,
        'doseIndex': dose.doseIndex,
        'dueAt': dose.dueAt?.toUtc().toIso8601String(),
        'appliedAt': dose.appliedAt?.toUtc().toIso8601String(),
        'lot': dose.lot,
        'clinic': dose.clinic,
        'proofUrl': dose.proofUrl,
      };

  static VaccineDose fromRow(Map<String, Object?> row) => VaccineDose(
        id: row['id']! as String,
        childId: row['child_id']! as String,
        vaccineId: row['vaccine_id']! as String,
        doseIndex: row['dose_index']! as int,
        dueAt: _fromMillis(row['due_at'] as int?),
        appliedAt: _fromMillis(row['applied_at'] as int?),
        lot: row['lot'] as String?,
        clinic: row['clinic'] as String?,
        proofUrl: row['proof_url'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
          isUtc: true,
        ).toLocal(),
        pendingSync: (row['dirty'] as int? ?? 0) == 1,
      );

  static Map<String, Object?> toRow(VaccineDose dose, {bool dirty = false}) =>
      <String, Object?>{
        'id': dose.id,
        'child_id': dose.childId,
        'vaccine_id': dose.vaccineId,
        'dose_index': dose.doseIndex,
        'due_at': dose.dueAt?.toUtc().millisecondsSinceEpoch,
        'applied_at': dose.appliedAt?.toUtc().millisecondsSinceEpoch,
        'lot': dose.lot,
        'clinic': dose.clinic,
        'proof_url': dose.proofUrl,
        'updated_at': dose.updatedAt.toUtc().millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
        'deleted': 0,
      };

  static DateTime? _fromMillis(int? ms) => ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
