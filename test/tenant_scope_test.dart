import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/security/domain/tenant_scope.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final DateTime t = DateTime(2026);

  ClinicMembership adminGlobal({String clinicId = 'clinic-a'}) =>
      ClinicMembership(
        id: 'm-admin',
        clinicId: clinicId,
        userId: 'u1',
        role: ClinicRole.clinicAdmin,
        createdAt: t,
        unitIds: const <String>[],
      );

  ClinicMembership financeUnit(String unitId) => ClinicMembership(
        id: 'm-fin',
        clinicId: 'clinic-a',
        userId: 'u2',
        role: ClinicRole.finance,
        createdAt: t,
        unitIds: <String>[unitId],
      );

  group('requireClinicAccess', () {
    test('same clinic ok', () {
      expect(
        () => TenantScope.requireClinicAccess(adminGlobal(), 'clinic-a'),
        returnsNormally,
      );
    });

    test('cross clinic deny', () {
      expect(
        () => TenantScope.requireClinicAccess(adminGlobal(), 'clinic-b'),
        throwsA(isA<TenantScopeException>()),
      );
    });
  });

  group('assertSameClinic', () {
    test('legacy doc without clinicId ok', () {
      expect(
        () => TenantScope.assertSameClinic(null, 'clinic-a'),
        returnsNormally,
      );
    });

    test('matching clinic ok', () {
      expect(
        () => TenantScope.assertSameClinic('clinic-a', 'clinic-a'),
        returnsNormally,
      );
    });

    test('cross clinic deny', () {
      expect(
        () => TenantScope.assertSameClinic('clinic-b', 'clinic-a'),
        throwsA(isA<TenantScopeException>()),
      );
    });
  });

  group('canAccessUnit', () {
    test('clinicAdmin empty unitIds allows any unit', () {
      expect(
        TenantScope.canAccessUnit(adminGlobal(), 'unit-centro'),
        isTrue,
      );
    });

    test('scoped finance allows assigned unit only', () {
      final ClinicMembership m = financeUnit('unit-centro');
      expect(TenantScope.canAccessUnit(m, 'unit-centro'), isTrue);
      expect(TenantScope.canAccessUnit(m, 'unit-zona'), isFalse);
    });

    test('doc without unitId allowed when member', () {
      expect(TenantScope.canAccessUnit(financeUnit('u1'), null), isTrue);
    });
  });

  group('requireTransferUnits', () {
    test('allows transfer between accessible units', () {
      final ClinicMembership m = financeUnit('unit-a');
      expect(
        () => TenantScope.requireTransferUnits(
          m,
          fromUnitId: 'unit-a',
          toUnitId: 'unit-a',
        ),
        returnsNormally,
      );
    });

    test('denies destination outside scope', () {
      final ClinicMembership m = financeUnit('unit-a');
      expect(
        () => TenantScope.requireTransferUnits(
          m,
          fromUnitId: 'unit-a',
          toUnitId: 'unit-b',
        ),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('global admin can reach any unit', () {
      expect(
        () => TenantScope.requireTransferUnits(
          adminGlobal(),
          fromUnitId: 'unit-x',
          toUnitId: 'unit-y',
        ),
        returnsNormally,
      );
    });
  });

  group('stampLedgerMap', () {
    test('adds clinicId without overriding', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'ownerId': 'phy',
        'clinicId': 'existing',
      };
      TenantScope.stampLedgerMap(
        data,
        membership: adminGlobal(clinicId: 'clinic-a'),
      );
      expect(data['clinicId'], 'existing');
    });

    test('stamps clinicId when missing', () {
      final Map<String, dynamic> data = <String, dynamic>{'ownerId': 'phy'};
      TenantScope.stampLedgerMap(
        data,
        membership: adminGlobal(clinicId: 'clinic-a'),
      );
      expect(data['clinicId'], 'clinic-a');
    });
  });
}
