import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../domain/security_access.dart';
import '../domain/security_audit_models.dart';

class SecurityAuditQuery {
  const SecurityAuditQuery({
    this.clinicId,
    this.actorUid,
    this.module,
    this.action,
    this.severity,
    this.entityIdSearch,
    this.since,
    this.until,
    this.limit = 50,
    this.startAfterDocument,
  });

  final String? clinicId;
  final String? actorUid;
  final String? module;
  final String? action;
  final SecurityAuditSeverity? severity;
  final String? entityIdSearch;
  final DateTime? since;
  final DateTime? until;
  final int limit;
  final DocumentSnapshot<Map<String, dynamic>>? startAfterDocument;
}

class SecurityAuditRepository {
  SecurityAuditRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('security_audit_logs');

  Future<Result<void>> append({
    required SecurityAuditEvent event,
    required AppUser? actor,
  }) async {
    return guard(() async {
      if (actor == null) {
        throw StateError('Actor required');
      }
      if (event.actorUid != actor.uid) {
        throw StateError('actorUid must match authenticated user');
      }
      if (!SecurityAccess.canAppendOwnAuditEvent(user: actor)) {
        throw StateError('Not allowed to append audit log');
      }
      final DocumentReference<Map<String, dynamic>> ref =
          event.id.isNotEmpty ? _collection.doc(event.id) : _collection.doc();
      final SecurityAuditEvent stored = SecurityAuditEvent(
        id: ref.id,
        actorUid: event.actorUid,
        actorName: event.actorName,
        actorRole: event.actorRole,
        clinicId: event.clinicId,
        unitId: event.unitId,
        action: event.action,
        module: event.module,
        entityType: event.entityType,
        entityId: event.entityId,
        at: event.at,
        severity: event.severity,
        beforeJson: event.beforeJson,
        afterJson: event.afterJson,
        reason: event.reason,
        status: event.status,
        ip: event.ip,
        sessionId: event.sessionId,
      );
      await ref.set(stored.toMap());
    });
  }

  Stream<List<SecurityAuditEvent>> watchLogs(SecurityAuditQuery query) {
    Query<Map<String, dynamic>> q = _collection.orderBy('at', descending: true);

    if (query.clinicId != null && query.clinicId!.isNotEmpty) {
      q = q.where('clinicId', isEqualTo: query.clinicId);
    }
    if (query.actorUid != null && query.actorUid!.isNotEmpty) {
      q = q.where('actorUid', isEqualTo: query.actorUid);
    }
    if (query.module != null && query.module!.isNotEmpty) {
      q = q.where('module', isEqualTo: query.module);
    }
    if (query.action != null && query.action!.isNotEmpty) {
      q = q.where('action', isEqualTo: query.action);
    }
    if (query.severity != null) {
      q = q.where('severity', isEqualTo: query.severity!.name);
    }

    q = q.limit(query.limit);
    if (query.startAfterDocument != null) {
      q = q.startAfterDocument(query.startAfterDocument!);
    }

    return q.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
      Iterable<SecurityAuditEvent> events = snap.docs.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            SecurityAuditEvent.fromMap(d.data(), id: d.id),
      );
      if (query.since != null) {
        events = events.where((SecurityAuditEvent e) => !e.at.isBefore(query.since!));
      }
      if (query.until != null) {
        events = events.where((SecurityAuditEvent e) => !e.at.isAfter(query.until!));
      }
      if (query.entityIdSearch != null && query.entityIdSearch!.trim().isNotEmpty) {
        final String needle = query.entityIdSearch!.trim().toLowerCase();
        events = events.where(
          (SecurityAuditEvent e) => e.entityId.toLowerCase().contains(needle),
        );
      }
      return events.toList(growable: false);
    });
  }

  /// Filtro client-side apos fetch (evita indices compostos extras).
  static List<SecurityAuditEvent> applyFilters(
    List<SecurityAuditEvent> source,
    SecurityAuditQuery query,
  ) {
    Iterable<SecurityAuditEvent> events = source;
    if (query.since != null) {
      events = events.where((SecurityAuditEvent e) => !e.at.isBefore(query.since!));
    }
    if (query.until != null) {
      events = events.where((SecurityAuditEvent e) => !e.at.isAfter(query.until!));
    }
    if (query.entityIdSearch != null && query.entityIdSearch!.trim().isNotEmpty) {
      final String needle = query.entityIdSearch!.trim().toLowerCase();
      events = events.where(
        (SecurityAuditEvent e) => e.entityId.toLowerCase().contains(needle),
      );
    }
    return events.toList(growable: false);
  }
}
