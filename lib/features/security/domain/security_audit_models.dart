import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SecurityAuditSeverity {
  info,
  warning,
  critical;

  static SecurityAuditSeverity fromName(String? value) =>
      SecurityAuditSeverity.values.firstWhere(
        (SecurityAuditSeverity s) => s.name == value,
        orElse: () => SecurityAuditSeverity.info,
      );
}

SecurityAuditSeverity classifyAuditSeverity(String action) {
  const Set<String> critical = <String>{
    'delete',
    'refund',
    'permissionChange',
    'blockedAccess',
    'massExport',
    'configChange',
    'finalizedChartEditAttempt',
  };
  if (critical.contains(action)) {
    return SecurityAuditSeverity.critical;
  }
  if (action == 'export' || action == 'cancel' || action == 'approve') {
    return SecurityAuditSeverity.warning;
  }
  return SecurityAuditSeverity.info;
}

const Set<String> _secretKeys = <String>{
  'password',
  'token',
  'accessToken',
  'refreshToken',
  'idToken',
  'apiKey',
  'secret',
  'credential',
};

Map<String, dynamic>? redactAuditJson(Map<String, dynamic>? source) {
  if (source == null) return null;
  final Map<String, dynamic> out = <String, dynamic>{};
  source.forEach((String key, dynamic value) {
    final String lower = key.toLowerCase();
    if (_secretKeys.any((String s) => lower.contains(s.toLowerCase()))) {
      out[key] = '[REDACTED]';
      return;
    }
    if (value is Map) {
      out[key] = redactAuditJson(Map<String, dynamic>.from(value));
      return;
    }
    out[key] = value;
  });
  return out;
}

class SecurityAuditEvent extends Equatable {
  const SecurityAuditEvent({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.module,
    required this.at,
    required this.severity,
    this.clinicId,
    this.unitId,
    this.entityType = '',
    this.entityId = '',
    this.beforeJson,
    this.afterJson,
    this.reason,
    this.status = 'recorded',
    this.ip,
    this.sessionId,
  });

  factory SecurityAuditEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    final String action = (map['action'] as String?) ?? '';
    return SecurityAuditEvent(
      id: id ?? (map['id'] as String?) ?? '',
      actorUid: (map['actorUid'] as String?) ?? '',
      actorName: (map['actorName'] as String?) ?? '',
      actorRole: (map['actorRole'] as String?) ?? '',
      clinicId: map['clinicId'] as String?,
      unitId: map['unitId'] as String?,
      action: action,
      module: (map['module'] as String?) ?? '',
      entityType: (map['entityType'] as String?) ?? '',
      entityId: (map['entityId'] as String?) ?? '',
      at: DateTime.tryParse((map['at'] as String?) ?? '') ??
          (map['at'] is Timestamp
              ? (map['at'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0)),
      severity: map['severity'] != null
          ? SecurityAuditSeverity.fromName(map['severity'] as String?)
          : classifyAuditSeverity(action),
      beforeJson: map['beforeJson'] != null
          ? redactAuditJson(
              Map<String, dynamic>.from(map['beforeJson'] as Map),
            )
          : null,
      afterJson: map['afterJson'] != null
          ? redactAuditJson(
              Map<String, dynamic>.from(map['afterJson'] as Map),
            )
          : null,
      reason: map['reason'] as String?,
      status: (map['status'] as String?) ?? 'recorded',
      ip: map['ip'] as String?,
      sessionId: map['sessionId'] as String?,
    );
  }

  final String id;
  final String actorUid;
  final String actorName;
  final String actorRole;
  final String? clinicId;
  final String? unitId;
  final String action;
  final String module;
  final String entityType;
  final String entityId;
  final DateTime at;
  final SecurityAuditSeverity severity;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;
  final String? reason;
  final String status;
  final String? ip;
  final String? sessionId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorRole': actorRole,
        if (clinicId != null) 'clinicId': clinicId,
        if (unitId != null) 'unitId': unitId,
        'action': action,
        'module': module,
        'entityType': entityType,
        'entityId': entityId,
        'at': at.toIso8601String(),
        'severity': severity.name,
        if (beforeJson != null) 'beforeJson': redactAuditJson(beforeJson),
        if (afterJson != null) 'afterJson': redactAuditJson(afterJson),
        if (reason != null) 'reason': reason,
        'status': status,
        if (ip != null) 'ip': ip,
        if (sessionId != null) 'sessionId': sessionId,
      };

  @override
  List<Object?> get props =>
      <Object?>[id, actorUid, action, module, entityId, at, severity];
}
