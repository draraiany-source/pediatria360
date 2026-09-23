import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Entrada de historico de consentimento (LGPD).
///
/// **Pendencia FASE 8:** leitura em tempo real de `users/{uid}/consents`
/// (subcoleção ja usada pelas Cloud Functions de privacidade). UI dedicada
/// pode ser ligada quando o manifesto expuser historico completo; ate la,
/// revogacao/exportacao na [PrivacyScreen] deve usar [AuditLogService].
class ConsentHistoryEntry extends Equatable {
  const ConsentHistoryEntry({
    required this.id,
    required this.purposeKey,
    required this.granted,
    required this.recordedAt,
    this.version = '',
    this.source = '',
  });

  factory ConsentHistoryEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    return ConsentHistoryEntry(
      id: id ?? (map['id'] as String?) ?? '',
      purposeKey: (map['purposeKey'] as String?) ??
          (map['purpose'] as String?) ??
          (map['revoked'] as String?) ??
          '',
      granted: (map['granted'] as bool?) ?? (map['revoked'] == null),
      recordedAt: _readRecordedAt(map),
      version: (map['version'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
    );
  }

  factory ConsentHistoryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> map = doc.data() ?? const <String, dynamic>{};
    return ConsentHistoryEntry.fromMap(map, id: doc.id);
  }

  static DateTime _readRecordedAt(Map<String, dynamic> map) {
    final dynamic raw = map['recordedAt'] ?? map['grantedAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      return DateTime.tryParse(raw) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final String id;
  final String purposeKey;
  final bool granted;
  final DateTime recordedAt;
  final String version;
  final String source;

  @override
  List<Object?> get props => <Object?>[id, purposeKey, granted, recordedAt];
}
