import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/growth_record.dart';

/// Conversor de [GrowthRecord] entre Firestore, SQLite e domínio.
class GrowthRecordMapper {
  const GrowthRecordMapper._();

  static GrowthRecord fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String childId,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return GrowthRecord(
      id: doc.id,
      childId: childId,
      measuredAt: _date(data['measuredAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      headCircumferenceCm: (data['headCircumferenceCm'] as num?)?.toDouble(),
      note: data['note'] as String?,
    );
  }

  static Map<String, dynamic> toOutboxPayload(
    GrowthRecord record,
    String ownerId,
  ) =>
      <String, dynamic>{
        'ownerId': ownerId,
        'childId': record.childId,
        'measuredAt': record.measuredAt.toUtc().toIso8601String(),
        'weightKg': record.weightKg,
        'heightCm': record.heightCm,
        'headCircumferenceCm': record.headCircumferenceCm,
        'note': record.note,
      };

  static GrowthRecord fromRow(Map<String, Object?> row) => GrowthRecord(
        id: row['id']! as String,
        childId: row['child_id']! as String,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(
          row['measured_at']! as int,
          isUtc: true,
        ).toLocal(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
          isUtc: true,
        ).toLocal(),
        weightKg: row['weight_kg'] as double?,
        heightCm: row['height_cm'] as double?,
        headCircumferenceCm: row['head_cm'] as double?,
        note: row['note'] as String?,
        pendingSync: (row['dirty'] as int? ?? 0) == 1,
      );

  static Map<String, Object?> toRow(
    GrowthRecord record, {
    bool dirty = false,
  }) =>
      <String, Object?>{
        'id': record.id,
        'child_id': record.childId,
        'measured_at': record.measuredAt.toUtc().millisecondsSinceEpoch,
        'weight_kg': record.weightKg,
        'height_cm': record.heightCm,
        'head_cm': record.headCircumferenceCm,
        'note': record.note,
        'updated_at': record.updatedAt.toUtc().millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
        'deleted': 0,
      };

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
