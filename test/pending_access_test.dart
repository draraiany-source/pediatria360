import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/pending/domain/pending_access.dart';
import 'package:pediatria360/features/pending/domain/pending_item.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final AppUser physician = AppUser(
    uid: 'u1',
    email: 'a@b.com',
    name: 'Med',
    role: UserRole.professional,
    plan: UserPlan.free,
    createdAt: DateTime(2026),
    onboardingDone: true,
    professionalVerified: true,
  );

  final ClinicMembership reception = ClinicMembership(
    id: 'm1',
    clinicId: 'c1',
    userId: 'u2',
    role: ClinicRole.receptionist,
    createdAt: DateTime(2026),
  );

  test('reception sees admin not finance', () {
    expect(
      PendingAccess.canViewCategory(
        user: physician,
        clinicMembership: reception,
        category: PendingCategory.administrative,
      ),
      isTrue,
    );
    expect(
      PendingAccess.canViewCategory(
        user: physician,
        clinicMembership: reception,
        category: PendingCategory.financial,
      ),
      isFalse,
    );
  });

  test('filterVisible hides finance for reception', () {
    final List<PendingItem> items = <PendingItem>[
      PendingItem(
        sourceKey: 'f1',
        kind: PendingKind.paymentPending,
        category: PendingCategory.financial,
        title: 'Pag',
        subtitle: '',
        createdAt: DateTime.now(),
      ),
    ];
    final List<PendingItem> visible = PendingAccess.filterVisible(
      items: items,
      user: physician,
      clinicMembership: reception,
    );
    expect(visible, isEmpty);
  });
}
