import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

/// Areas de trabalho do Pedi360 — distintas de [UserRole] de plataforma.
///
/// - [admin]: equipe Pedi360 (UserRole.admin)
/// - [professional]: atendimento clinico
/// - [receptionist]: agenda/check-in sem prontuario
/// - [finance]: financeiro/faturamento
/// - [patient]: familia/responsavel
enum WorkspaceProfile {
  admin,
  professional,
  receptionist,
  finance,
  patient;

  String get label => switch (this) {
        WorkspaceProfile.admin => 'Administrador',
        WorkspaceProfile.professional => 'Profissional',
        WorkspaceProfile.receptionist => 'Recepcionista',
        WorkspaceProfile.finance => 'Financeiro',
        WorkspaceProfile.patient => 'Paciente',
      };

  String get homeSubtitle => switch (this) {
        WorkspaceProfile.admin =>
          'Gerencie equipe, unidades, conteudos e indicadores.',
        WorkspaceProfile.professional =>
          'Agenda, pacientes e prontuario sob seus cuidados.',
        WorkspaceProfile.receptionist =>
          'Organize atendimentos, check-in e cadastros.',
        WorkspaceProfile.finance =>
          'Recebimentos, pendencias e relatorios financeiros.',
        WorkspaceProfile.patient =>
          'Acompanhe a saude de quem voce cuida.',
      };
}

/// Resolve quais areas a conta pode abrir — nunca por escolha livre na UI.
class WorkspaceAccess {
  const WorkspaceAccess._();

  static Set<WorkspaceProfile> grantedProfiles({
    required AppUser? user,
    required List<ClinicMembership> memberships,
  }) {
    if (user == null) return <WorkspaceProfile>{};

    if (user.role.isAdmin) {
      return <WorkspaceProfile>{WorkspaceProfile.admin};
    }
    if (user.role == UserRole.parent) {
      return <WorkspaceProfile>{WorkspaceProfile.patient};
    }
    if (user.role != UserRole.professional) {
      return <WorkspaceProfile>{};
    }

    final Set<WorkspaceProfile> granted = <WorkspaceProfile>{};
    final List<ClinicMembership> active = memberships
        .where((ClinicMembership m) => m.active)
        .toList(growable: false);

    if (active.isEmpty) {
      // Profissional legado / sem clinica: area clinica.
      granted.add(WorkspaceProfile.professional);
      return granted;
    }

    for (final ClinicMembership m in active) {
      switch (m.role) {
        case ClinicRole.clinicAdmin:
          granted.add(WorkspaceProfile.professional);
          granted.add(WorkspaceProfile.receptionist);
          granted.add(WorkspaceProfile.finance);
        case ClinicRole.physician:
        case ClinicRole.healthProfessional:
        case ClinicRole.nursing:
          granted.add(WorkspaceProfile.professional);
        case ClinicRole.receptionist:
        case ClinicRole.technician:
          granted.add(WorkspaceProfile.receptionist);
        case ClinicRole.finance:
          granted.add(WorkspaceProfile.finance);
        case ClinicRole.patient:
          break;
      }
    }

    if (granted.isEmpty) {
      granted.add(WorkspaceProfile.professional);
    }
    return granted;
  }

  static WorkspaceProfile defaultProfile(Set<WorkspaceProfile> granted) {
    const List<WorkspaceProfile> order = <WorkspaceProfile>[
      WorkspaceProfile.admin,
      WorkspaceProfile.professional,
      WorkspaceProfile.receptionist,
      WorkspaceProfile.finance,
      WorkspaceProfile.patient,
    ];
    for (final WorkspaceProfile p in order) {
      if (granted.contains(p)) return p;
    }
    return WorkspaceProfile.patient;
  }

  /// Home path preferencial apos login (hoje todas usam /inicio com UI distinta).
  static String homePathFor(WorkspaceProfile profile) => '/inicio';
}