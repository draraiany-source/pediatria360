import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/features/children/domain/child_access_grant.dart';
import 'package:pediatria360/features/clinic_intake/domain/clinic_intake.dart';
import 'package:pediatria360/features/workspace/domain/workspace_profile.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

/// Etapa 2: autorização explícita do responsável, solicitação provisória e
/// perfis de recepção/financeiro/gestão em conta comum. Dados fictícios.
void main() {
  final DateTime now = DateTime.utc(2026, 10, 21, 12);

  AppUser user(UserRole role) => AppUser(
        uid: 'u1',
        email: 'conta@exemplo.invalid',
        name: 'Conta Exemplo',
        role: role,
        plan: UserPlan.free,
        createdAt: DateTime.utc(2026),
        onboardingDone: true,
      );

  ClinicMembership membership(ClinicRole role, {bool active = true}) =>
      ClinicMembership(
        id: 'm1',
        clinicId: 'c1',
        userId: 'u1',
        role: role,
        active: active,
        createdAt: DateTime.utc(2026),
      );

  group('ChildAccessGrant — classificação', () {
    Map<String, dynamic> grant({
      String? source = 'guardian',
      List<String> scopes = const <String>['summary'],
      DateTime? expiresAt,
      DateTime? revokedAt,
    }) =>
        <String, dynamic>{
          'source': source,
          'scopes': scopes,
          'expiresAt': expiresAt ?? now.add(const Duration(days: 30)),
          'revokedAt': revokedAt,
          'professionalName': 'Dra. Exemplo',
        };

    ChildAccessGrant parse(Map<String, dynamic> m) =>
        ChildAccessGrant.fromMap('prof-1', m, now: now);

    test('ativa: origem válida, escopo e validade futura', () {
      final ChildAccessGrant g = parse(grant());
      expect(g.status, ChildAccessStatus.active);
      expect(g.level, ChildAccessLevel.summaryOnly);
    });

    test('convite aceito (guardianInvite) também vale', () {
      expect(parse(grant(source: 'guardianInvite')).status,
          ChildAccessStatus.active);
    });

    test('concessão automática antiga (familyAppointment) não vale', () {
      expect(parse(grant(source: 'familyAppointment')).status,
          ChildAccessStatus.invalid);
    });

    test('sem escopo, sem validade ou sem origem: antiga, sem efeito', () {
      expect(parse(grant(scopes: const <String>[])).status,
          ChildAccessStatus.invalid);
      expect(parse(grant(source: null)).status, ChildAccessStatus.invalid);
      expect(
        parse(<String, dynamic>{'grantedAt': now}).status,
        ChildAccessStatus.invalid,
      );
    });

    test('vencida e revogada', () {
      expect(parse(grant(expiresAt: now.subtract(const Duration(days: 1)))).status,
          ChildAccessStatus.expired);
      expect(parse(grant(revokedAt: now)).status, ChildAccessStatus.revoked);
    });

    test('prontuário implica resumo; resumo sozinho não libera prontuário', () {
      expect(
        parse(grant(scopes: const <String>['summary', 'chartWrite'])).level,
        ChildAccessLevel.chart,
      );
      expect(ChildAccessLevel.summaryOnly.scopes, <String>['summary']);
      expect(ChildAccessLevel.chart.scopes, <String>['summary', 'chartWrite']);
    });

    test('validades oferecidas ficam dentro do limite do servidor', () {
      expect(kChildAccessDurations.every((int d) => d >= 1 && d <= 365), isTrue);
    });
  });

  group('candidatos a autorização', () {
    test('um por profissional e clínica, a partir das consultas da família', () {
      final List<AccessCandidate> c = candidatesFromAppointments(
        <Map<String, dynamic>>[
          <String, dynamic>{'professionalId': 'p1', 'clinicId': 'c1', 'professionalName': 'Dra. A'},
          <String, dynamic>{'professionalId': 'p1', 'clinicId': 'c1', 'professionalName': 'Dra. A'},
          <String, dynamic>{'professionalId': 'p1', 'clinicId': 'c2', 'professionalName': 'Dra. A'},
          <String, dynamic>{'professionalId': '', 'clinicId': 'c1'},
          <String, dynamic>{'clinicId': 'c1'},
        ],
      );
      expect(c.length, 2);
      expect(c.map((AccessCandidate a) => a.clinicId).toSet(), <String?>{'c1', 'c2'});
    });
  });

  group('convite da clínica', () {
    test('mensagem traz o código e a validade, sem dados clínicos', () {
      final IntakeInvite invite = IntakeInvite(
        intakeId: 'i1',
        code: 'ABCDE-FGHJK',
        expiresAt: DateTime(2026, 10, 28),
      );
      final String msg = invite.messageFor(
        guardianName: 'Responsavel Exemplo',
        childName: 'Bebe Exemplo',
        clinicName: 'Clinica Exemplo',
      );
      expect(msg, contains('ABCDE-FGHJK'));
      expect(msg, contains('28/10'));
    });
  });

  group('perfis em conta comum (sem verificação profissional)', () {
    test('recepção recebe só a área de recepção, além da família', () {
      final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
        user: user(UserRole.parent),
        memberships: <ClinicMembership>[membership(ClinicRole.receptionist)],
      );
      expect(g, <WorkspaceProfile>{WorkspaceProfile.patient, WorkspaceProfile.receptionist});
    });

    test('financeiro recebe só a área financeira', () {
      final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
        user: user(UserRole.parent),
        memberships: <ClinicMembership>[membership(ClinicRole.finance)],
      );
      expect(g, <WorkspaceProfile>{WorkspaceProfile.patient, WorkspaceProfile.finance});
    });

    test('gestão recebe recepção e financeiro, nunca o profissional', () {
      final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
        user: user(UserRole.parent),
        memberships: <ClinicMembership>[membership(ClinicRole.clinicAdmin)],
      );
      expect(g.contains(WorkspaceProfile.professional), isFalse);
      expect(g, containsAll(<WorkspaceProfile>[WorkspaceProfile.receptionist, WorkspaceProfile.finance]));
    });

    test('papel clínico em conta comum não abre nada', () {
      final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
        user: user(UserRole.parent),
        memberships: <ClinicMembership>[membership(ClinicRole.physician)],
      );
      expect(g, <WorkspaceProfile>{WorkspaceProfile.patient});
    });

    test('vínculo inativo não conta', () {
      final Set<WorkspaceProfile> g = WorkspaceAccess.grantedProfiles(
        user: user(UserRole.parent),
        memberships: <ClinicMembership>[membership(ClinicRole.receptionist, active: false)],
      );
      expect(g, <WorkspaceProfile>{WorkspaceProfile.patient});
    });
  });

  group('rotas para recepção, financeiro e gestão em conta comum', () {
    String? go(String location, {WorkspaceProfile? workspace, ClinicMembership? m}) =>
        resolveRouteRedirect(
          maintenanceMode: false,
          location: location,
          authLoading: false,
          onboardingLoading: false,
          user: user(UserRole.parent),
          seenOnboarding: true,
          clinicMembership: m,
          workspace: workspace,
        );

    test('recepção: agenda, recepção e solicitações; nada clínico', () {
      const WorkspaceProfile w = WorkspaceProfile.receptionist;
      final ClinicMembership m = membership(ClinicRole.receptionist);
      expect(go(Routes.agendaPath, workspace: w, m: m), isNull);
      expect(go(Routes.clinicReceptionPath, workspace: w, m: m), isNull);
      expect(go(Routes.clinicIntakesPath, workspace: w, m: m), isNull);
      expect(go(Routes.patientsPath, workspace: w, m: m), Routes.homePath);
      expect(go(Routes.clinicVoicePath, workspace: w, m: m), Routes.homePath);
      expect(go(Routes.supplementPath, workspace: w, m: m), Routes.homePath);
      expect(go(Routes.financePath, workspace: w, m: m), Routes.homePath);
      expect(go(Routes.clinicTeamPath, workspace: w, m: m), Routes.homePath);
    });

    test('financeiro: financeiro e faturamento; nem agenda nem pacientes', () {
      const WorkspaceProfile w = WorkspaceProfile.finance;
      final ClinicMembership m = membership(ClinicRole.finance);
      expect(go(Routes.financePath, workspace: w, m: m), isNull);
      expect(go(Routes.billingPath, workspace: w, m: m), isNull);
      expect(go(Routes.agendaPath, workspace: w, m: m), Routes.homePath);
      expect(go(Routes.patientsPath, workspace: w, m: m), Routes.homePath);
    });

    test('gestão: administração da clínica, sem prontuário', () {
      final ClinicMembership m = membership(ClinicRole.clinicAdmin);
      expect(go(Routes.clinicTeamPath, workspace: WorkspaceProfile.receptionist, m: m), isNull);
      expect(go(Routes.patientsPath, workspace: WorkspaceProfile.receptionist, m: m), Routes.homePath);
      expect(go(Routes.clinicVoicePath, workspace: WorkspaceProfile.finance, m: m), Routes.homePath);
    });

    test('família sem papel na clínica continua fora da área da equipe', () {
      expect(go(Routes.agendaPath, workspace: WorkspaceProfile.patient), Routes.homePath);
      expect(go(Routes.clinicIntakesPath), Routes.homePath);
      expect(go(Routes.clinicTeamPath), Routes.homePath);
      expect(go(Routes.clinicInvitePath, workspace: WorkspaceProfile.patient), isNull);
    });
  });
}
