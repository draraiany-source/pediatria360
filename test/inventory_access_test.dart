import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/inventory/domain/inventory_access.dart';
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

  test('nursing has stockOps', () {
    expect(
      InventoryAccess.level(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.nursing,
          createdAt: DateTime(2026),
        ),
      ),
      InventoryAccessLevel.stockOps,
    );
  });

  test('finance has view only', () {
    expect(
      InventoryAccess.level(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.finance,
          createdAt: DateTime(2026),
        ),
      ),
      InventoryAccessLevel.view,
    );
  });

  test('reception has none', () {
    expect(
      InventoryAccess.canAccessModule(
        user: pro,
        clinicMembership: ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u1',
          role: ClinicRole.receptionist,
          createdAt: DateTime(2026),
        ),
      ),
      isFalse,
    );
  });
}
