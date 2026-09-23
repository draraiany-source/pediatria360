import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final DateTime t = DateTime.utc(2026, 1, 1);

  group('ClinicRole RBAC', () {
    test('physician can access chart and agenda', () {
      expect(ClinicRole.physician.canAccessClinicalChart, isTrue);
      expect(ClinicRole.physician.canManageAgenda, isTrue);
      expect(ClinicRole.physician.canAccessFinance, isFalse);
    });

    test('receptionist manages agenda but not chart write flags', () {
      expect(ClinicRole.receptionist.canManageAgenda, isTrue);
      expect(ClinicRole.receptionist.canAccessClinicalChart, isFalse);
      expect(ClinicRole.receptionist.canAccessFinance, isFalse);
    });

    test('finance role is isolated', () {
      expect(ClinicRole.finance.canAccessFinance, isTrue);
      expect(ClinicRole.finance.canAccessBilling, isTrue);
      expect(ClinicRole.finance.canAccessClinicalChart, isFalse);
      expect(ClinicRole.finance.canManageStaff, isFalse);
    });

    test('clinicAdmin has staff and finance', () {
      expect(ClinicRole.clinicAdmin.canManageStaff, isTrue);
      expect(ClinicRole.clinicAdmin.canAccessFinance, isTrue);
      expect(ClinicRole.clinicAdmin.canAccessClinicalChart, isTrue);
    });

    test('inventory RBAC helpers', () {
      expect(ClinicRole.nursing.canConsumeInventory, isTrue);
      expect(ClinicRole.nursing.canManageInventory, isFalse);
      expect(ClinicRole.finance.canManageInventory, isTrue);
      expect(ClinicRole.clinicAdmin.canManageInventory, isTrue);
    });
  });

  group('ClinicMembership unit admin getters', () {
    test('global clinic admin', () {
      final ClinicMembership m = ClinicMembership(
        id: 'm-admin',
        clinicId: 'c1',
        userId: 'u1',
        role: ClinicRole.clinicAdmin,
        createdAt: t,
      );
      expect(m.isGlobalClinicAdmin, isTrue);
      expect(m.isLocalUnitAdmin, isFalse);
    });

    test('local unit admin', () {
      final ClinicMembership m = ClinicMembership(
        id: 'm-local',
        clinicId: 'c1',
        userId: 'u1',
        role: ClinicRole.clinicAdmin,
        createdAt: t,
        unitIds: <String>['unit-a'],
      );
      expect(m.isGlobalClinicAdmin, isFalse);
      expect(m.isLocalUnitAdmin, isTrue);
    });
  });

  group('serialization', () {
    test('ClinicOrganization roundtrip', () {
      final ClinicOrganization c = ClinicOrganization(
        id: 'c1',
        name: 'Clinica Teste',
        createdAt: DateTime.utc(2026, 1, 1),
        cnpj: '00.000.000/0001-00',
      );
      final ClinicOrganization again =
          ClinicOrganization.fromMap(c.toMap(), id: 'c1');
      expect(again.name, 'Clinica Teste');
      expect(again.cnpj, '00.000.000/0001-00');
    });

    test('ClinicMembership roundtrip', () {
      final ClinicMembership m = ClinicMembership(
        id: 'm1',
        clinicId: 'c1',
        userId: 'u1',
        role: ClinicRole.nursing,
        clinicName: 'Unidade Centro',
        createdAt: DateTime.utc(2026, 1, 2),
        unitIds: const <String>['u-centro'],
      );
      final ClinicMembership again =
          ClinicMembership.fromMap(m.toMap(), id: 'm1');
      expect(again.role, ClinicRole.nursing);
      expect(again.clinicName, 'Unidade Centro');
      expect(again.unitIds, <String>['u-centro']);
    });

    test('empty clinicName falls back to clinicId for display', () {
      final ClinicMembership m = ClinicMembership(
        id: 'm2',
        clinicId: 'clinic-xyz',
        userId: 'u2',
        role: ClinicRole.physician,
        createdAt: DateTime.utc(2026, 1, 3),
      );
      final String label =
          m.clinicName.isNotEmpty ? m.clinicName : m.clinicId;
      expect(label, 'clinic-xyz');
    });
  });
}
