import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/billing/domain/billing_access.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final AppUser pro = AppUser(
    uid: 'u1',
    email: 'a@b.com',
    name: 'Med',
    role: UserRole.professional,
    plan: UserPlan.pro,
    createdAt: DateTime(2026),
    onboardingDone: true,
    professionalVerified: true,
  );

  test('finance role has full billing', () {
    expect(
      BillingAccess.level(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.finance,
          createdAt: DateTime(2026),
        ),
      ),
      BillingAccessLevel.full,
    );
  });

  test('reception has receptionBasic', () {
    expect(
      BillingAccess.level(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.receptionist,
          createdAt: DateTime(2026),
        ),
      ),
      BillingAccessLevel.receptionBasic,
    );
  });

  test('physician has physicianView', () {
    expect(
      BillingAccess.level(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.physician,
          createdAt: DateTime(2026),
        ),
      ),
      BillingAccessLevel.physicianView,
    );
  });
}
