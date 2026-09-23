import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../data/consent_history_repository.dart';
import '../../data/security_audit_repository.dart';
import '../../domain/audit_log_service.dart';
import '../../domain/consent_history.dart';
import '../../domain/security_audit_models.dart';

final Provider<SecurityAuditRepository> securityAuditRepositoryProvider =
    Provider<SecurityAuditRepository>(
  (Ref ref) => SecurityAuditRepository(firestore: ref.watch(firestoreProvider)),
);

final Provider<AuditLogService> auditLogServiceProvider = Provider<AuditLogService>(
  (Ref ref) => AuditLogService(
    repository: ref.watch(securityAuditRepositoryProvider),
  ),
);

final Provider<ConsentHistoryRepository> consentHistoryRepositoryProvider =
    Provider<ConsentHistoryRepository>(
  (Ref ref) => ConsentHistoryRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

final StreamProvider<List<ConsentHistoryEntry>> consentHistoryProvider =
    StreamProvider<List<ConsentHistoryEntry>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<ConsentHistoryEntry>>.value(
      const <ConsentHistoryEntry>[],
    );
  }
  return ref.watch(consentHistoryRepositoryProvider).watchForUser(uid);
});

class AuditLogFilterState {
  const AuditLogFilterState({
    this.module,
    this.action,
    this.severity,
    this.entityIdSearch = '',
    this.since,
    this.until,
  });

  final String? module;
  final String? action;
  final SecurityAuditSeverity? severity;
  final String entityIdSearch;
  final DateTime? since;
  final DateTime? until;

  AuditLogFilterState copyWith({
    String? module,
    String? action,
    SecurityAuditSeverity? severity,
    String? entityIdSearch,
    DateTime? since,
    DateTime? until,
    bool clearModule = false,
    bool clearAction = false,
    bool clearSeverity = false,
  }) =>
      AuditLogFilterState(
        module: clearModule ? null : (module ?? this.module),
        action: clearAction ? null : (action ?? this.action),
        severity: clearSeverity ? null : (severity ?? this.severity),
        entityIdSearch: entityIdSearch ?? this.entityIdSearch,
        since: since ?? this.since,
        until: until ?? this.until,
      );
}

final StateProvider<AuditLogFilterState> auditLogFilterProvider =
    StateProvider<AuditLogFilterState>(
  (Ref ref) => const AuditLogFilterState(),
);

final StreamProvider<List<SecurityAuditEvent>> securityAuditLogsProvider =
    StreamProvider<List<SecurityAuditEvent>>((Ref ref) {
  final AuditLogFilterState filter = ref.watch(auditLogFilterProvider);
  final String? clinicId = ref.watch(activeClinicMembershipProvider)?.clinicId;
  final query = SecurityAuditQuery(
    clinicId: clinicId,
    module: filter.module,
    action: filter.action,
    severity: filter.severity,
    entityIdSearch: filter.entityIdSearch,
    since: filter.since,
    until: filter.until,
    limit: 50,
  );
  return ref.watch(securityAuditRepositoryProvider).watchLogs(query);
});
