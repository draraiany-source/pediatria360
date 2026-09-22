import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/bi/domain/bi_access.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final AppUser professional = AppUser(
    uid: 'pro',
    email: 'p@x.com',
    name: 'Pro',
    role: UserRole.professional,
    plan: UserPlan.pro,
    createdAt: DateTime(2026),
    onboardingDone: true,
    professionalVerified: true,
  );

  final AppUser parent = AppUser(
    uid: 'par',
    email: 'a@x.com',
    name: 'Resp',
    role: UserRole.parent,
    plan: UserPlan.free,
    createdAt: DateTime(2026),
    onboardingDone: true,
  );

  test('clinic admin has full BI access', () {
    final ClinicMembership m = ClinicMembership(
      id: '1',
      clinicId: 'c',
      userId: 'pro',
      role: ClinicRole.clinicAdmin,
      createdAt: DateTime(2026),
    );
    expect(BiAccess.level(user: professional, clinicMembership: m),
        BiAccessLevel.full);
    expect(
      BiAccess.canSeeFinance(user: professional, clinicMembership: m),
      isTrue,
    );
    expect(
      BiAccess.canSeeClinical(user: professional, clinicMembership: m),
      isTrue,
    );
    expect(BiAccess.canExport(user: professional, clinicMembership: m), isTrue);
  });

  test('finance role sees finance not clinical deep', () {
    final ClinicMembership m = ClinicMembership(
      id: '2',
      clinicId: 'c',
      userId: 'pro',
      role: ClinicRole.finance,
      createdAt: DateTime(2026),
    );
    expect(BiAccess.level(user: professional, clinicMembership: m),
        BiAccessLevel.financial);
    expect(
      BiAccess.canSeeFinance(user: professional, clinicMembership: m),
      isTrue,
    );
    expect(
      BiAccess.canSeeClinical(user: professional, clinicMembership: m),
      isFalse,
    );
    expect(
      BiAccess.canSeeInventory(user: professional, clinicMembership: m),
      isTrue,
    );
  });

  test('physician has clinical ops', () {
    final ClinicMembership m = ClinicMembership(
      id: '3',
      clinicId: 'c',
      userId: 'pro',
      role: ClinicRole.physician,
      createdAt: DateTime(2026),
    );
    expect(BiAccess.level(user: professional, clinicMembership: m),
        BiAccessLevel.clinicalOps);
    expect(
      BiAccess.canSeeClinical(user: professional, clinicMembership: m),
      isTrue,
    );
    expect(
      BiAccess.canSeeFinance(user: professional, clinicMembership: m),
      isFalse,
    );
  });

  test('receptionist ops without finance', () {
    final ClinicMembership m = ClinicMembership(
      id: '4',
      clinicId: 'c',
      userId: 'pro',
      role: ClinicRole.receptionist,
      createdAt: DateTime(2026),
    );
    expect(
      BiAccess.canSeeOps(user: professional, clinicMembership: m),
      isTrue,
    );
    expect(
      BiAccess.canSeeFinance(user: professional, clinicMembership: m),
      isFalse,
    );
  });

  test('legacy professional without membership is full', () {
    expect(
      BiAccess.level(user: professional, clinicMembership: null),
      BiAccessLevel.full,
    );
  });

  test('parent has no BI access', () {
    expect(
      BiAccess.canAccessModule(user: parent, clinicMembership: null),
      isFalse,
    );
  });
}
