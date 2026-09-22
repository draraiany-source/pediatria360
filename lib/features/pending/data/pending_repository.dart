import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/result.dart';
import '../domain/pending_item.dart';
import 'pending_tracking_record.dart';

class PendingRepository {
  PendingRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tracking =>
      _firestore.collection('pending_tracking');

  Stream<Map<String, PendingTrackingRecord>> watchTrackingBySourceKey(
    String professionalId,
  ) =>
      _tracking
          .where('professionalId', isEqualTo: professionalId)
          .limit(500)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snap) {
              final Map<String, PendingTrackingRecord> map =
                  <String, PendingTrackingRecord>{};
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snap.docs) {
                final PendingTrackingRecord r =
                    PendingTrackingRecord.fromFirestore(doc);
                map[r.sourceKey] = r;
              }
              return map;
            },
          );

  Future<Result<void>> upsertStatus({
    required String professionalId,
    required PendingItem item,
    required PendingWorkflowStatus status,
    required String updatedBy,
    String? notes,
  }) =>
      guard(() async {
        final String docId =
            PendingTrackingRecord.docIdForSourceKey(item.sourceKey);
        final DateTime? resolvedAt =
            status == PendingWorkflowStatus.resolved ||
                    status == PendingWorkflowStatus.ignored
                ? DateTime.now()
                : null;
        final String? resolvedBy =
            resolvedAt != null ? updatedBy : null;

        await _tracking.doc(docId).set(
          <String, dynamic>{
            'professionalId': professionalId,
            'sourceKey': item.sourceKey,
            'kind': item.kind.name,
            if (item.patientId != null) 'patientId': item.patientId,
            'status': status.name,
            'updatedAt': FieldValue.serverTimestamp(),
            if (resolvedAt != null)
              'resolvedAt': Timestamp.fromDate(resolvedAt),
            if (resolvedBy != null) 'resolvedBy': resolvedBy,
            if (notes != null) 'notes': notes,
          },
          SetOptions(merge: true),
        );
      });
}
