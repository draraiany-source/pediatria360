import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../data/security_audit_repository.dart';
import 'blocked_access_tracker.dart';
import 'permission_matrix.dart';
import 'security_audit_models.dart';

/// Fachada para registrar eventos cross-cutting sem reescrever repositorios
/// de dominio (finance/billing/inventory mantem trilhas proprias).
class AuditLogService {
  AuditLogService({required SecurityAuditRepository repository})
      : _repository = repository;

  final SecurityAuditRepository _repository;

  static final Map<String, DateTime> _blockedAccessThrottle =
      <String, DateTime>{};
  static const Duration _blockedThrottleWindow = Duration(seconds: 30);
  static final BlockedAccessTracker _repeatedBlockedTracker =
      BlockedAccessTracker();

  Future<void> log({
    required AppUser? user,
    required ClinicMembership? membership,
    required String action,
    required PermissionModule module,
    String entityType = '',
    String entityId = '',
    Map<String, dynamic>? beforeJson,
    Map<String, dynamic>? afterJson,
    String? reason,
    SecurityAuditSeverity? severity,
    String? ip,
    String? sessionId,
  }) async {
    if (user == null) return;
    final SecurityAuditEvent event = SecurityAuditEvent(
      id: '',
      actorUid: user.uid,
      actorName: user.name,
      actorRole: membership?.role.name ?? user.role.name,
      clinicId: membership?.clinicId,
      action: action,
      module: module.name,
      entityType: entityType,
      entityId: entityId,
      at: DateTime.now().toUtc(),
      severity: severity ?? classifyAuditSeverity(action),
      beforeJson: beforeJson,
      afterJson: afterJson,
      reason: reason,
      ip: ip != null && ip.isNotEmpty ? ip : null,
      sessionId: sessionId != null && sessionId.isNotEmpty ? sessionId : null,
    );
    await _repository.append(event: event, actor: user);
  }

  Future<void> logBlockedAccess({
    required AppUser? user,
    required ClinicMembership? membership,
    required PermissionModule module,
    String? reason,
    String? ip,
    String? sessionId,
  }) async {
    if (user == null) return;
    final String key = '${user.uid}:${module.name}';
    final DateTime now = DateTime.now();
    final DateTime? last = _blockedAccessThrottle[key];
    if (last != null && now.difference(last) < _blockedThrottleWindow) {
      return;
    }
    _blockedAccessThrottle[key] = now;

    final bool repeated =
        _repeatedBlockedTracker.record(user.uid, now);

    await log(
      user: user,
      membership: membership,
      action: 'blockedAccess',
      module: module,
      reason: reason ?? 'Acesso negado na UI',
      severity: SecurityAuditSeverity.critical,
      ip: ip,
      sessionId: sessionId,
    );

    if (repeated) {
      await log(
        user: user,
        membership: membership,
        action: 'repeatedBlockedAccess',
        module: module,
        reason: 'Tres ou mais acessos bloqueados em cinco minutos',
        severity: SecurityAuditSeverity.critical,
        ip: ip,
        sessionId: sessionId,
      );
    }
  }

  Future<void> logExport({
    required AppUser? user,
    required ClinicMembership? membership,
    required PermissionModule module,
    String entityType = 'report',
    String entityId = '',
    String exportKind = 'csv',
    String? ip,
    String? sessionId,
  }) async {
    await log(
      user: user,
      membership: membership,
      action: exportKind == 'mass' ? 'massExport' : 'export',
      module: module,
      entityType: entityType,
      entityId: entityId,
      afterJson: <String, dynamic>{'format': exportKind},
      ip: ip,
      sessionId: sessionId,
    );
  }

  Future<void> logPermissionChange({
    required AppUser? user,
    required ClinicMembership? membership,
    required String targetUserId,
    required String previousRole,
    required String newRole,
    String? ip,
    String? sessionId,
  }) async {
    await log(
      user: user,
      membership: membership,
      action: 'permissionChange',
      module: PermissionModule.users,
      entityType: 'clinicMembership',
      entityId: targetUserId,
      beforeJson: <String, dynamic>{'role': previousRole},
      afterJson: <String, dynamic>{'role': newRole},
      severity: SecurityAuditSeverity.critical,
      ip: ip,
      sessionId: sessionId,
    );
  }
}
