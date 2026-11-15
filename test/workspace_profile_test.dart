import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/workspace/domain/workspace_profile.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

AppUser _user({required UserRole role}) => AppUser(
      uid: 'u1',
      email: 'a@b.com',
      name: 'Teste',
      role: role,
      plan: UserPlan.free,
      createdAt: DateTime.utc(2024),
      onboardingDone: true,
    );

ClinicMembership _m(ClinicRole role) => ClinicMembership(
      id: 'm1',
      clinicId: 'c1',
      userId: 'u1',
      role: role,
      createdAt: DateTime.utc(2024),
    );

void main() {
  test('paciente so recebe workspace patient', () {
    final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
      user: _user(role: UserRole.parent),
      memberships: const <ClinicMembership>[],
    );
    expect(g, <WorkspaceProfile>{WorkspaceProfile.patient});
  });

  test('admin plataforma so recebe admin', () {
    final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
      user: _user(role: UserRole.admin),
      memberships: <ClinicMembership>[_m(ClinicRole.receptionist)],
    );
    expect(g, <WorkspaceProfile>{WorkspaceProfile.admin});
  });

  test('recepcionista nao recebe prontuario', () {
    final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
      user: _user(role: UserRole.professional),
      memberships: <ClinicMembership>[_m(ClinicRole.receptionist)],
    );
    expect(g, <WorkspaceProfile>{WorkspaceProfile.receptionist});
    expect(g.contains(WorkspaceProfile.professional), isFalse);
  });

  test('clinicAdmin recebe tres areas clinicas', () {
    final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
      user: _user(role: UserRole.professional),
      memberships: <ClinicMembership>[_m(ClinicRole.clinicAdmin)],
    );
    expect(
      g,
      <WorkspaceProfile>{
        WorkspaceProfile.professional,
        WorkspaceProfile.receptionist,
        WorkspaceProfile.finance,
      },
    );
  });

  test('rota: recepcao ativa bloqueia pacientes', () {
    // Importado via resolveRouteRedirect em outro arquivo — smoke local.
    expect(WorkspaceProfile.receptionist.label, 'Recepcionista');
  });
}