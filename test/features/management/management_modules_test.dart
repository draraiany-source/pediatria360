import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/features/management/domain/management_modules.dart';
import 'package:pediatria360/features/management/presentation/anamnesis_screens.dart'
    show anamnesisFieldVisible;
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  group('módulos por perfil', () {
    test('sem vínculo ou paciente não vê nada', () {
      expect(visibleManagementModules(null), isEmpty);
      expect(visibleManagementModules(ClinicRole.patient), isEmpty);
    });

    test('recepção: agenda, CRM, comunicação e automações; nada clínico', () {
      final List<ManagementModule> m =
          visibleManagementModules(ClinicRole.receptionist);
      expect(
        m,
        containsAll(<ManagementModule>[
          ManagementModule.agenda,
          ManagementModule.crm,
          ManagementModule.communication,
          ManagementModule.automations,
        ]),
      );
      expect(m, isNot(contains(ManagementModule.anamnesis)));
      expect(m, isNot(contains(ManagementModule.care)));
      expect(m, isNot(contains(ManagementModule.finance)));
      expect(m, isNot(contains(ManagementModule.aiHub)));
      expect(m, isNot(contains(ManagementModule.marketing)));
    });

    test('financeiro: financeiro e Central de IA, sem agenda nem clínico', () {
      final List<ManagementModule> m =
          visibleManagementModules(ClinicRole.finance);
      expect(
        m,
        unorderedEquals(<ManagementModule>[
          ManagementModule.finance,
          ManagementModule.aiHub,
        ]),
      );
    });

    test('profissional: agenda, anamnese e atendimento; sem gestão', () {
      final List<ManagementModule> m =
          visibleManagementModules(ClinicRole.physician);
      expect(
        m,
        unorderedEquals(<ManagementModule>[
          ManagementModule.agenda,
          ManagementModule.anamnesis,
          ManagementModule.care,
        ]),
      );
      expect(canTranscribeConsultation(ClinicRole.physician), isTrue);
      expect(canTranscribeConsultation(ClinicRole.receptionist), isFalse);
      expect(canTranscribeConsultation(ClinicRole.finance), isFalse);
    });

    test('gestão vê os dez módulos, na ordem do menu', () {
      expect(
        visibleManagementModules(ClinicRole.clinicAdmin),
        ManagementModule.values,
      );
    });
  });

  group('rotas /gestao', () {
    test('cada rota segue o módulo', () {
      expect(
        managementRouteAllowed(Routes.managementAiPath, ClinicRole.finance),
        isTrue,
      );
      expect(
        managementRouteAllowed(
            Routes.managementAiPath, ClinicRole.receptionist),
        isFalse,
      );
      expect(
        managementRouteAllowed(
            Routes.managementMarketingPath, ClinicRole.finance),
        isFalse,
      );
      expect(
        managementRouteAllowed(
            Routes.managementAnamnesisPath, ClinicRole.receptionist),
        isFalse,
      );
      expect(
        managementRouteAllowed(
            Routes.managementCommunicationPath, ClinicRole.receptionist),
        isTrue,
      );
      expect(managementRouteAllowed(Routes.managementPath, null), isFalse);
      expect(managementRouteAllowed('/gestao/inexistente', ClinicRole.clinicAdmin),
          isFalse);
    });

    AppUser user(UserRole role) => AppUser(
          uid: 'u1',
          email: 'ficticio@example.invalid',
          name: 'Conta fictícia',
          role: role,
          plan: UserPlan.free,
          onboardingDone: true,
          createdAt: DateTime(2026),
        );

    ClinicMembership membership(ClinicRole role, {bool active = true}) =>
        ClinicMembership(
          id: 'u1',
          clinicId: 'clinica-ficticia',
          userId: 'u1',
          role: role,
          createdAt: DateTime(2026),
          active: active,
        );

    String? redirect(String loc, AppUser u, ClinicMembership? m) =>
        resolveRouteRedirect(
          maintenanceMode: false,
          location: loc,
          authLoading: false,
          onboardingLoading: false,
          user: u,
          seenOnboarding: true,
          clinicMembership: m,
        );

    test('redirect usa o papel ativo; vínculo revogado perde o acesso', () {
      final AppUser parent = user(UserRole.parent);
      expect(
        redirect(Routes.managementAiPath, parent,
            membership(ClinicRole.clinicAdmin)),
        isNull,
      );
      expect(
        redirect(Routes.managementAiPath, parent,
            membership(ClinicRole.clinicAdmin, active: false)),
        Routes.homePath,
      );
      expect(
        redirect(Routes.managementAiPath, parent,
            membership(ClinicRole.receptionist)),
        Routes.homePath,
      );
      expect(redirect(Routes.managementPath, parent, null), Routes.homePath);
    });
  });

  group('anamnese condicional', () {
    test('campo com showIf só aparece com a resposta correspondente', () {
      final Map<String, dynamic> field = <String, dynamic>{
        'id': 'alergiaQual',
        'showIf': <String, dynamic>{'field': 'temAlergia', 'equals': true},
      };
      expect(anamnesisFieldVisible(field, <String, dynamic>{}), isFalse);
      expect(
        anamnesisFieldVisible(field, <String, dynamic>{'temAlergia': true}),
        isTrue,
      );
      expect(
        anamnesisFieldVisible(<String, dynamic>{'id': 'x'}, <String, dynamic>{}),
        isTrue,
      );
    });
  });
}
