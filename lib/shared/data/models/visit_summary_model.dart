import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/visit_summary.dart';

class VisitSummaryMapper {
  const VisitSummaryMapper._();

  static VisitSummary fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return VisitSummary(
      encounterId: doc.id,
      patientId: (data['patientId'] as String?) ?? '',
      professionalId: (data['professionalId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: VisitSummaryStatus.fromName(data['status'] as String?),
      guidance: (data['guidance'] as String?) ?? '',
      careInstructions: (data['careInstructions'] as String?) ?? '',
      warningSigns: _stringList(data['warningSigns']),
      followUpNotes: (data['followUpNotes'] as String?) ?? '',
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
      releasedDocumentIds: _stringList(data['releasedDocumentIds']),
      releasedAt: (data['releasedAt'] as Timestamp?)?.toDate(),
      finalizedAt: (data['finalizedAt'] as Timestamp?)?.toDate(),
      amendsSummaryId: data['amendsSummaryId'] as String?,
      amendmentReason: data['amendmentReason'] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(VisitSummary s) => <String, dynamic>{
        'patientId': s.patientId,
        'professionalId': s.professionalId,
        'createdAt': Timestamp.fromDate(s.createdAt),
        'status': s.status.name,
        'guidance': s.guidance,
        'careInstructions': s.careInstructions,
        'warningSigns': s.warningSigns,
        'followUpNotes': s.followUpNotes,
        'followUpDate':
            s.followUpDate == null ? null : Timestamp.fromDate(s.followUpDate!),
        'releasedDocumentIds': s.releasedDocumentIds,
        'releasedAt':
            s.releasedAt == null ? null : Timestamp.fromDate(s.releasedAt!),
        'finalizedAt':
            s.finalizedAt == null ? null : Timestamp.fromDate(s.finalizedAt!),
        'amendsSummaryId': s.amendsSummaryId,
        'amendmentReason': s.amendmentReason,
      };

  static List<String> _stringList(Object? value) => value == null
      ? const <String>[]
      : List<String>.from(value as List<dynamic>);
}
