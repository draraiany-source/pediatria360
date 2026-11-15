import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../workspace/domain/workspace_profile.dart';

/// Papel exibido no cabeçalho e no menu lateral.
///
/// Vem da área de trabalho ativa e do vínculo com a clínica; nunca supõe
/// "Pediatra" para quem não informou especialidade.
String accountRoleLabel({
  required AppUser? user,
  required ClinicMembership? membership,
  required WorkspaceProfile workspace,
}) {
  if (user == null) return 'Conta';
  switch (workspace) {
    case WorkspaceProfile.patient:
      return 'Área da família';
    case WorkspaceProfile.admin:
      return 'Administrador da plataforma';
    case WorkspaceProfile.receptionist:
      return 'Recepcionista';
    case WorkspaceProfile.finance:
      return 'Financeiro';
    case WorkspaceProfile.professional:
      final String specialty = (user.specialty ?? '').trim();
      if (specialty.isNotEmpty) return specialty;
      if (membership != null && membership.active) {
        return membership.role.label;
      }
      return 'Profissional de saúde';
  }
}
