import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import 'pending_item.dart';

/// RBAC para pendencias (papel da plataforma + clinica).
class PendingAccess {
  PendingAccess._();

  static bool canViewCategory({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
    required PendingCategory category,
  }) {
    if (user == null) return false;
    if (user.role.isAdmin) return true;

    if (clinicMembership != null && clinicMembership.active) {
      return switch (category) {
        PendingCategory.clinical =>
          clinicMembership.role.canAccessClinicalChart,
        PendingCategory.administrative =>
          clinicMembership.role.canManageAgenda ||
              clinicMembership.role.canAccessClinicalChart ||
              clinicMembership.role.canManageInventory ||
              clinicMembership.role.canConsumeInventory,
        PendingCategory.financial =>
          clinicMembership.role.canAccessFinance ||
              clinicMembership.role.canAccessBilling ||
              clinicMembership.role.canAccessClinicalChart,
      };
    }

    return user.role.isProfessional;
  }

  static bool canUpdateStatus({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
    required PendingItem item,
  }) {
    if (!canViewCategory(
      user: user,
      clinicMembership: clinicMembership,
      category: item.category,
    )) {
      return false;
    }
    if (item.kind == PendingKind.automationIntegration) {
      return user?.role.isAdmin == true;
    }
    return true;
  }

  static List<PendingItem> filterVisible({
    required List<PendingItem> items,
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      items
          .where(
            (PendingItem i) => canViewCategory(
              user: user,
              clinicMembership: clinicMembership,
              category: i.category,
            ),
          )
          .toList(growable: false);
}
