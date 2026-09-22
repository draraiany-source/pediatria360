import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

/// Gate de auditoria e matriz de permissoes (admin clinica / plataforma).
class SecurityAccess {
  SecurityAccess._();

  /// Logs completos da clinica + export CSV — nao inclui financeiro sozinho.
  static bool canAdministerAudit({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) {
    if (user == null) return false;
    if (user.role.isAdmin) return true;
    if (clinicMembership != null &&
        clinicMembership.active &&
        clinicMembership.role == ClinicRole.clinicAdmin) {
      return true;
    }
    return false;
  }

  static bool canExportAuditLogs({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      canAdministerAudit(user: user, clinicMembership: clinicMembership);

  static bool canViewPermissionMatrix({
    required AppUser? user,
    required ClinicMembership? clinicMembership,
  }) =>
      canAdministerAudit(user: user, clinicMembership: clinicMembership);

  /// Profissional verificado pode registrar eventos proprios (create rules).
  static bool canAppendOwnAuditEvent({required AppUser? user}) {
    if (user == null) return false;
    if (user.role.isAdmin) return true;
    return user.role == UserRole.professional && user.professionalVerified;
  }
}
