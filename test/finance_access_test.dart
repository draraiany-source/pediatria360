import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/finance/domain/finance_access.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final AppUser admin = AppUser(
    uid: 'adm',
    email: 'a@b.com',
    name: 'Admin',
    role: UserRole.admin,
    plan: UserPlan.pro,
    createdAt: DateTime(2026),
    onboardingDone: true,
  );

  final AppUser physician = AppUser(
    uid: 'phy',
    email: 'p@b.com',
    name: 'Med',
    role: UserRole.professional,
    plan: UserPlan.pro,
    createdAt: DateTime(2026),
    onboardingDone: true,
    professionalVerified: true,
  );

  test('finance role has full access', () {
    final ClinicMembership finance = ClinicMembership(
      id: 'm1',
      clinicId: 'c1',
      userId: 'f1',
      role: ClinicRole.finance,
      createdAt: DateTime(2026),
    );
    expect(
      FinanceAccess.level(user: physician, clinicMembership: finance),
      FinanceAccessLevel.full,
    );
    expect(
      FinanceAccess.canManageLedger(
        user: physician,
        clinicMembership: finance,
      ),
      isTrue,
    );
  });

  test('receptionist can register payment only', () {
    final ClinicMembership reception = ClinicMembership(
      id: 'm2',
      clinicId: 'c1',
      userId: 'r1',
      role: ClinicRole.receptionist,
      createdAt: DateTime(2026),
    );
    expect(
      FinanceAccess.level(user: physician, clinicMembership: reception),
      FinanceAccessLevel.registerPayment,
    );
    expect(
      FinanceAccess.canManageLedger(
        user: physician,
        clinicMembership: reception,
      ),
      isFalse,
    );
  });

  test('physician sees own receivables', () {
    final ClinicMembership phys = ClinicMembership(
      id: 'm3',
      clinicId: 'c1',
      userId: 'phy',
      role: ClinicRole.physician,
      createdAt: DateTime(2026),
    );
    final FinanceReceivable mine = FinanceReceivable(
      id: 'r1',
      ownerId: 'phy',
      totalCents: 1000,
      paidCents: 0,
      status: ReceivableStatus.pending,
      dueAt: DateTime(2026, 7),
      createdAt: DateTime(2026, 6),
      professionalId: 'phy',
    );
    final FinanceReceivable other = FinanceReceivable(
      id: 'r2',
      ownerId: 'other',
      totalCents: 1000,
      paidCents: 0,
      status: ReceivableStatus.pending,
      dueAt: DateTime(2026, 7),
      createdAt: DateTime(2026, 6),
      professionalId: 'other',
    );
    expect(
      FinanceAccess.canViewReceivable(
        user: physician,
        clinicMembership: phys,
        receivable: mine,
      ),
      isTrue,
    );
    expect(
      FinanceAccess.canViewReceivable(
        user: physician,
        clinicMembership: phys,
        receivable: other,
      ),
      isFalse,
    );
  });

  test('platform admin full', () {
    expect(
      FinanceAccess.level(user: admin, clinicMembership: null),
      FinanceAccessLevel.full,
    );
  });
}
