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
      purposeKey: (map['purposeKey'] as String?) ?? (map['purpose'] as String?) ?? '',
      granted: (map['granted'] as bool?) ?? false,
      recordedAt: DateTime.tryParse((map['recordedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      version: (map['version'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
    );
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
