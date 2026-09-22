import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/pending_item.dart';

/// Rastreamento de status/resolução de uma pendência derivada.
///
/// Collection: `pending_tracking`
/// - professionalId (string): autor do vínculo clínico
/// - sourceKey (string): chave estável gerada pelo agregador
/// - kind (string): PendingKind.name
/// - patientId (string, opcional)
/// - status (string): PendingWorkflowStatus.name
/// - resolvedAt (timestamp, opcional)
/// - resolvedBy (string, opcional): uid
/// - updatedAt (timestamp)
/// - notes (string, opcional)
class PendingTrackingRecord {
  const PendingTrackingRecord({
    required this.id,
    required this.professionalId,
    required this.sourceKey,
    required this.kind,
    required this.status,
    required this.updatedAt,
    this.patientId,
    this.resolvedAt,
    this.resolvedBy,
    this.notes,
  });

  factory PendingTrackingRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? const <String, dynamic>{};
    return PendingTrackingRecord(
      id: doc.id,
      professionalId: (d['professionalId'] as String?) ?? '',
      sourceKey: (d['sourceKey'] as String?) ?? doc.id,
      kind: (d['kind'] as String?) ?? '',
      status: PendingWorkflowStatus.fromName(d['status'] as String?),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientId: d['patientId'] as String?,
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: d['resolvedBy'] as String?,
      notes: d['notes'] as String?,
    );
  }

  final String id;
  final String professionalId;
  final String sourceKey;
  final String kind;
  final PendingWorkflowStatus status;
  final DateTime updatedAt;
  final String? patientId;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? notes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'professionalId': professionalId,
        'sourceKey': sourceKey,
        'kind': kind,
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (patientId != null) 'patientId': patientId,
        if (resolvedAt != null)
          'resolvedAt': Timestamp.fromDate(resolvedAt!),
        if (resolvedBy != null) 'resolvedBy': resolvedBy,
        if (notes != null) 'notes': notes,
      };

  static String docIdForSourceKey(String sourceKey) =>
      sourceKey.replaceAll('/', '_').replaceAll(':', '__');
}
