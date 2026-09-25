import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/security/domain/permission_matrix.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final DateTime t = DateTime(2026);

  AppUser pro({required String uid, bool verified = true}) => AppUser(
        uid: uid,
        email: '$uid@test.com',
        name: 'Pro',
        role: UserRole.professional,
        plan: UserPlan.pro,
        createdAt: t,
        onboardingDone: true,
        professionalVerified: verified,
      );

  ClinicMembership membership(ClinicRole role, {String clinicId = 'clinicA'}) =>
      ClinicMembership(
        id: 'm-$role',
        clinicId: clinicId,
        userId: 'u1',
        role: role,
        createdAt: t,
      );

  group('PermissionMatrix negative cross-module', () {
    test('receptionist cannot finance full (manage ledger)', () {
      final AppUser user = pro(uid: 'rec');
      final ClinicMembership m = membership(ClinicRole.receptionist);
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.finance,
          action: PermissionAction.edit,
        ),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.finance,
          action: PermissionAction.view,
        ),
        isTrue,
      );
    });

    test('finance cannot clinical chart edit', () {
      final AppUser user = pro(uid: 'fin');
      final ClinicMembership m = membership(ClinicRole.finance);
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.chart,
          action: PermissionAction.edit,
        ),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.finance,
          action: PermissionAction.edit,
        ),
        isTrue,
      );
    });

    test('patient clinic role cannot BI', () {
      final AppUser user = pro(uid: 'pat');
      final ClinicMembership m = membership(ClinicRole.patient);
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.bi,
          action: PermissionAction.view,
        ),
        isFalse,
      );
    });

    test('membership clinic A does not imply clinic B (app-level context)', () {
      final AppUser user = pro(uid: 'phy');
      final ClinicMembership clinicA = membership(ClinicRole.physician, clinicId: 'A');
      final ClinicMembership clinicB = membership(ClinicRole.receptionist, clinicId: 'B');
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: clinicA,
          module: PermissionModule.chart,
          action: PermissionAction.edit,
        ),
        isTrue,
      );
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: clinicB,
          module: PermissionModule.chart,
          action: PermissionAction.edit,
        ),
        isFalse,
      );
    });

    test('FASE2 receptionist: agenda sim, chart nao', () {
      final AppUser user = pro(uid: 'rec');
      final ClinicMembership m = membership(ClinicRole.receptionist);
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.agenda,
          action: PermissionAction.create,
        ),
        isTrue,
      );
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.chart,
          action: PermissionAction.view,
        ),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: m,
          module: PermissionModule.patients,
          action: PermissionAction.create,
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatrix allows expected roles', () {
    test('admin platform bypasses', () {
      final AppUser admin = AppUser(
        uid: 'adm',
        email: 'a@b.com',
        name: 'Admin',
        role: UserRole.admin,
        plan: UserPlan.pro,
        createdAt: t,
        onboardingDone: true,
      );
      expect(
        PermissionMatrix.allows(
          user: admin,
          membership: null,
          module: PermissionModule.audit,
          action: PermissionAction.administer,
        ),
        isTrue,
      );
    });

    test('physician chart sign', () {
      final AppUser user = pro(uid: 'phy');
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: membership(ClinicRole.physician),
          module: PermissionModule.chart,
          action: PermissionAction.sign,
        ),
        isTrue,
      );
    });

    test('clinicAdmin audit view', () {
      final AppUser user = pro(uid: 'ca');
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: membership(ClinicRole.clinicAdmin),
          module: PermissionModule.audit,
          action: PermissionAction.view,
        ),
        isTrue,
      );
    });

    test('inventory finance view only for finance role', () {
      final AppUser user = pro(uid: 'inv');
      expect(
        PermissionMatrix.allows(
          user: user,
          membership: membership(ClinicRole.finance),
          module: PermissionModule.inventory,
          action: PermissionAction.view,
        ),
        isTrue,
      );
    });
  });
}
