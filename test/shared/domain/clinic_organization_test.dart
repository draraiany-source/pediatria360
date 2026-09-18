import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
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
      expect(ClinicRole.finance.canAccessClinicalChart, isFalse);
      expect(ClinicRole.finance.canManageStaff, isFalse);
    });

    test('clinicAdmin has staff and finance', () {
      expect(ClinicRole.clinicAdmin.canManageStaff, isTrue);
      expect(ClinicRole.clinicAdmin.canAccessFinance, isTrue);
      expect(ClinicRole.clinicAdmin.canAccessClinicalChart, isTrue);
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
        createdAt: DateTime.utc(2026, 1, 2),
        unitIds: const <String>['u-centro'],
      );
      final ClinicMembership again =
          ClinicMembership.fromMap(m.toMap(), id: 'm1');
      expect(again.role, ClinicRole.nursing);
      expect(again.unitIds, <String>['u-centro']);
    });
  });
}
