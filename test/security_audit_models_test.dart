import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/security/domain/security_audit_models.dart';

void main() {
  group('classifyAuditSeverity', () {
    test('critical actions', () {
      expect(classifyAuditSeverity('delete'), SecurityAuditSeverity.critical);
      expect(classifyAuditSeverity('refund'), SecurityAuditSeverity.critical);
      expect(classifyAuditSeverity('blockedAccess'), SecurityAuditSeverity.critical);
      expect(classifyAuditSeverity('permissionChange'), SecurityAuditSeverity.critical);
      expect(classifyAuditSeverity('massExport'), SecurityAuditSeverity.critical);
    });

    test('warning for export', () {
      expect(classifyAuditSeverity('export'), SecurityAuditSeverity.warning);
    });

    test('info default', () {
      expect(classifyAuditSeverity('view'), SecurityAuditSeverity.info);
    });
  });

  group('redactAuditJson', () {
    test('redacts password and token keys', () {
      final Map<String, dynamic>? out = redactAuditJson(<String, dynamic>{
        'email': 'a@b.com',
        'password': 'secret',
        'nested': <String, dynamic>{'accessToken': 'xyz'},
      });
      expect(out!['password'], '[REDACTED]');
      expect((out['nested'] as Map)['accessToken'], '[REDACTED]');
      expect(out['email'], 'a@b.com');
    });

    test('SecurityAuditEvent.fromMap applies redaction', () {
      final SecurityAuditEvent e = SecurityAuditEvent.fromMap(<String, dynamic>{
        'actorUid': 'u1',
        'action': 'configChange',
        'module': 'settings',
        'at': '2026-01-01T00:00:00.000Z',
        'afterJson': <String, dynamic>{'apiKey': 'abc'},
      });
      expect(e.severity, SecurityAuditSeverity.critical);
      expect(e.afterJson!['apiKey'], '[REDACTED]');
    });
  });
}
