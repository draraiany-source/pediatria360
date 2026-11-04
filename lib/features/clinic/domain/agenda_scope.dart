import '../../../shared/domain/entities/clinic_organization.dart';
import '../../workspace/domain/workspace_profile.dart';

/// Quem opera a recepcao enxerga a agenda do dia da clinica inteira; os
/// demais, apenas os proprios atendimentos. As regras do Firestore limitam a
/// leitura por clinica a equipe de agenda (`isClinicAgendaStaff`).
bool usesClinicWideAgenda(
  ClinicMembership? membership,
  WorkspaceProfile workspace,
) {
  if (membership == null || !membership.active) return false;
  if (membership.clinicId.isEmpty) return false;
  return switch (membership.role) {
    ClinicRole.receptionist => true,
    ClinicRole.clinicAdmin => workspace == WorkspaceProfile.receptionist,
    _ => false,
  };
}
