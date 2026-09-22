import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

enum BiAccessLevel {
  none,
  clinicalOps,
  financial,
  full,
}

class BiAccess {
  BiAccess._();

  static BiAccessLevel level({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    if (user == null) return BiAccessLevel.none;
    if (user.role.isAdmin) return BiAccessLevel.full;

    if (clinicMembership != null && clinicMembership.active) {
      switch (clinicMembership.role) {
        case ClinicRole.clinicAdmin:
          return BiAccessLevel.full;
        case ClinicRole.finance:
          return BiAccessLevel.financial;
        case ClinicRole.physician:
        case ClinicRole.nursing:
        case ClinicRole.healthProfessional:
          return BiAccessLevel.clinicalOps;
        case ClinicRole.receptionist:
          return BiAccessLevel.clinicalOps;
        case ClinicRole.technician:
        case ClinicRole.patient:
          return BiAccessLevel.none;
      }
    }

    if (user.role == UserRole.professional) {
      return BiAccessLevel.full;
    }

    return BiAccessLevel.none;
  }

  static bool canAccessModule({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      level(user: user, clinicMembership: clinicMembership) !=
      BiAccessLevel.none;

  static bool canSeeFinance({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final BiAccessLevel l = level(user: user, clinicMembership: clinicMembership);
    return l == BiAccessLevel.full || l == BiAccessLevel.financial;
  }

  static bool canSeeClinical({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final BiAccessLevel l = level(user: user, clinicMembership: clinicMembership);
    return l == BiAccessLevel.full || l == BiAccessLevel.clinicalOps;
  }

  static bool canSeeOps({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final BiAccessLevel l = level(user: user, clinicMembership: clinicMembership);
    return l == BiAccessLevel.full || l == BiAccessLevel.clinicalOps;
  }

  static bool canSeeInventory({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final BiAccessLevel l = level(user: user, clinicMembership: clinicMembership);
    return l == BiAccessLevel.full || l == BiAccessLevel.financial;
  }

  static bool canExport({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    final BiAccessLevel l = level(user: user, clinicMembership: clinicMembership);
    return l == BiAccessLevel.full || l == BiAccessLevel.financial;
  }
}
