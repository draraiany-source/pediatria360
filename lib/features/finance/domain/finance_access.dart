import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import 'finance_models.dart';

enum FinanceAccessLevel {
  none,
  registerPayment,
  viewOwnProduction,
  viewDashboard,
  full,
}

/// RBAC financeiro (clinica + plataforma).
class FinanceAccess {
  FinanceAccess._();

  static FinanceAccessLevel level({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    if (user == null) return FinanceAccessLevel.none;
    if (user.role.isAdmin) return FinanceAccessLevel.full;

    if (clinicMembership != null && clinicMembership.active) {
      final ClinicRole role = clinicMembership.role;
      if (role.canAccessFinance || role == ClinicRole.clinicAdmin) {
        return FinanceAccessLevel.full;
      }
      if (role == ClinicRole.physician ||
          role == ClinicRole.healthProfessional) {
        return FinanceAccessLevel.viewOwnProduction;
      }
      if (role == ClinicRole.receptionist || role == ClinicRole.technician) {
        return FinanceAccessLevel.registerPayment;
      }
    }

    if (user.role == UserRole.professional) {
      return FinanceAccessLevel.full;
    }

    return FinanceAccessLevel.none;
  }

  static bool canAccessModule({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      level(user: user, clinicMembership: clinicMembership) !=
      FinanceAccessLevel.none;

  static bool canViewDashboard({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final FinanceAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    return l == FinanceAccessLevel.full ||
        l == FinanceAccessLevel.viewOwnProduction ||
        l == FinanceAccessLevel.registerPayment;
  }

  static bool canManageLedger({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      level(user: user, clinicMembership: clinicMembership) ==
          FinanceAccessLevel.full ||
      user?.role.isAdmin == true;

  static bool canRegisterPayment({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final FinanceAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    return l == FinanceAccessLevel.full || l == FinanceAccessLevel.registerPayment;
  }

  static bool canViewReceivable({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
    required FinanceReceivable receivable,
  }) {
    final FinanceAccessLevel l =
        level(user: user, clinicMembership: clinicMembership);
    if (l == FinanceAccessLevel.full ||
        l == FinanceAccessLevel.registerPayment) {
      return true;
    }
    if (l == FinanceAccessLevel.viewOwnProduction) {
      return receivable.professionalId == user?.uid ||
          receivable.ownerId == user?.uid;
    }
    return false;
  }

  static bool canViewPatientFinance({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      canViewDashboard(user: user, clinicMembership: clinicMembership);

  /// Responsavel: recibos apenas do proprio filho (patientId = childId).
  static bool parentCanViewReceipt({
    required AppUser? user,
    required String childId,
    required FinanceReceipt receipt,
  }) {
    if (user == null || user.role != UserRole.parent) return false;
    return receipt.patientId == childId;
  }
}
