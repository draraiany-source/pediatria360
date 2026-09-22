import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

enum InventoryAccessLevel {
  none,
  view,
  clinicalUse,
  stockOps,
  full,
}

/// RBAC estoque (clinica + plataforma).
class InventoryAccess {
  InventoryAccess._();

  static InventoryAccessLevel level({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    if (user == null) return InventoryAccessLevel.none;
    if (user.role.isAdmin) return InventoryAccessLevel.full;

    if (clinicMembership != null && clinicMembership.active) {
      final ClinicRole role = clinicMembership.role;
      if (role == ClinicRole.clinicAdmin) return InventoryAccessLevel.full;
      if (role == ClinicRole.nursing || role == ClinicRole.technician) {
        return InventoryAccessLevel.stockOps;
      }
      if (role == ClinicRole.physician ||
          role == ClinicRole.healthProfessional) {
        return InventoryAccessLevel.clinicalUse;
      }
      if (role.canAccessFinance) return InventoryAccessLevel.view;
      if (role == ClinicRole.receptionist) return InventoryAccessLevel.none;
    }

    if (user.role == UserRole.professional) {
      return InventoryAccessLevel.full;
    }

    return InventoryAccessLevel.none;
  }

  static bool canAccessModule({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      level(user: user, clinicMembership: clinicMembership) !=
      InventoryAccessLevel.none;

  static bool canView({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final InventoryAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    return l != InventoryAccessLevel.none;
  }

  static bool canStockOps({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final InventoryAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    return l == InventoryAccessLevel.full || l == InventoryAccessLevel.stockOps;
  }

  static bool canClinicalUse({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final InventoryAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    return l == InventoryAccessLevel.full ||
        l == InventoryAccessLevel.stockOps ||
        l == InventoryAccessLevel.clinicalUse;
  }

  static bool canManagePurchases({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    if (user?.role.isAdmin == true) return true;
    if (clinicMembership != null &&
        clinicMembership.active &&
        clinicMembership.role.canManageInventory) {
      return true;
    }
    return user?.role == UserRole.professional;
  }

  static bool canViewCosts({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      canManagePurchases(user: user, clinicMembership: clinicMembership) ||
      level(user: user, clinicMembership: clinicMembership) ==
          InventoryAccessLevel.full;
}
