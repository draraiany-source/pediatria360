import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/features/shell/domain/account_role_label.dart';
import 'package:pediatria360/features/shell/domain/main_menu.dart';
import 'package:pediatria360/features/workspace/domain/workspace_profile.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

AppUser user(UserRole role, {String? specialty}) => AppUser(
      uid: 'u',
      email: 'u@exemplo.invalid',
      name: 'U',
      role: role,
      plan: UserPlan.free,
      createdAt: DateTime(2026),
      onboardingDone: true,
      specialty: specialty,
    );

ClinicMembership member(ClinicRole role) => ClinicMembership(
      id: 'm',
      clinicId: 'c1',
      userId: 'u',
      role: role,
      createdAt: DateTime(2026),
    );

/// Mesma decisão do router para o perfil dado.
bool Function(String) policy(
  AppUser u, {
  ClinicMembership? m,
  required WorkspaceProfile w,
}) =>
    (String location) =>
        resolveRouteRedirect(
          maintenanceMode: false,
          location: location,
          authLoading: false,
          onboardingLoading: false,
          user: u,
          seenOnboarding: true,
          clinicMembership: m,
          workspace: w,
        ) ==
        null;

List<MainMenuModule> modules(List<MainMenuEntry> entries) =>
    entries.map((MainMenuEntry e) => e.module).toList();

void main() {
  test('o menu tem os 15 módulos na ordem das referências', () {
    expect(MainMenuModule.values, hasLength(15));
    expect(
      MainMenuModule.values.map((MainMenuModule m) => m.label),
      <String>[
        'Dashboard',
        'Agenda',
        'Pacientes',
        'Consultas',
        'Prontuário',
        'Prescrições e documentos',
        'Exames',
        'Vacinação',
        'Crescimento',
        'Puericultura',
        'Multidisciplinar',
        'Financeiro',
        'Relatórios',
        'Tia Cris — Recepcionista IA',
        'Configurações',
      ],
    );
  });

  test('sem rota liberada o item some; com várias, abre a primeira', () {
    final List<MainMenuEntry> menu = buildMainMenu(
      (String r) =>
          r == Routes.homePath ||
          r == Routes.clinicReceptionPath ||
          r == Routes.settingsPath,
    );
    expect(modules(menu), <MainMenuModule>[
      MainMenuModule.dashboard,
      MainMenuModule.consultations,
      MainMenuModule.settings,
    ]);
    expect(menu[1].route, Routes.clinicReceptionPath);
    expect(menu[2].route, Routes.settingsPath);
  });

  test('exames exige também a área de exames liberada', () {
    final List<MainMenuEntry> menu = buildMainMenu(
      (String r) => r != Routes.supplementLabsPath,
    );
    expect(modules(menu), isNot(contains(MainMenuModule.exams)));
    expect(modules(menu), contains(MainMenuModule.vaccines));
  });

  test('médico vê os módulos clínicos e não vê a recepcionista IA', () {
    final List<MainMenuModule> menu = modules(
      buildMainMenu(
        policy(
          user(UserRole.professional),
          m: member(ClinicRole.physician),
          w: WorkspaceProfile.professional,
        ),
      ),
    );
    expect(
      menu,
      containsAll(<MainMenuModule>[
        MainMenuModule.dashboard,
        MainMenuModule.agenda,
        MainMenuModule.patients,
        MainMenuModule.consultations,
        MainMenuModule.chart,
        MainMenuModule.prescriptions,
        MainMenuModule.exams,
        MainMenuModule.vaccines,
        MainMenuModule.growth,
        MainMenuModule.wellChild,
        MainMenuModule.multidisciplinary,
        MainMenuModule.settings,
      ]),
    );
    expect(menu, isNot(contains(MainMenuModule.receptionistAi)));
  });

  test('recepção não vê prontuário nem módulos clínicos', () {
    final List<MainMenuEntry> entries = buildMainMenu(
      policy(
        user(UserRole.professional),
        m: member(ClinicRole.receptionist),
        w: WorkspaceProfile.receptionist,
      ),
    );
    final List<MainMenuModule> menu = modules(entries);
    for (final MainMenuModule m in MainMenuModule.values) {
      if (m.patientScoped) expect(menu, isNot(contains(m)), reason: m.label);
    }
    expect(menu, isNot(contains(MainMenuModule.patients)));
    expect(menu, isNot(contains(MainMenuModule.finance)));
    expect(menu, contains(MainMenuModule.agenda));
    expect(menu, contains(MainMenuModule.receptionistAi));
  });

  test('conta comum com papel de recepção: Consultas abre a recepção', () {
    final List<MainMenuEntry> entries = buildMainMenu(
      policy(
        user(UserRole.parent),
        m: member(ClinicRole.receptionist),
        w: WorkspaceProfile.receptionist,
      ),
    );
    expect(
      entries
          .firstWhere(
            (MainMenuEntry e) => e.module == MainMenuModule.consultations,
          )
          .route,
      Routes.clinicReceptionPath,
    );
    expect(
      modules(entries).where((MainMenuModule m) => m.patientScoped),
      isEmpty,
    );
  });

  test('financeiro vê financeiro e relatórios, sem dados clínicos', () {
    final List<MainMenuModule> menu = modules(
      buildMainMenu(
        policy(
          user(UserRole.professional),
          m: member(ClinicRole.finance),
          w: WorkspaceProfile.finance,
        ),
      ),
    );
    expect(menu, contains(MainMenuModule.finance));
    expect(menu, contains(MainMenuModule.reports));
    expect(menu, isNot(contains(MainMenuModule.chart)));
    expect(menu, isNot(contains(MainMenuModule.patients)));
    expect(menu, isNot(contains(MainMenuModule.receptionistAi)));
  });

  test('rota da recepcionista IA: gestão e recepção, nunca médico', () {
    bool opens(ClinicRole role, WorkspaceProfile w) => policy(
          user(UserRole.professional),
          m: member(role),
          w: w,
        )(Routes.receptionistAiPath);
    expect(opens(ClinicRole.clinicAdmin, WorkspaceProfile.professional), isTrue);
    expect(opens(ClinicRole.receptionist, WorkspaceProfile.receptionist), isTrue);
    expect(opens(ClinicRole.physician, WorkspaceProfile.professional), isFalse);
    expect(opens(ClinicRole.finance, WorkspaceProfile.finance), isFalse);
  });

  test('módulo do paciente é rota de prontuário (recepção bloqueada)', () {
    final bool Function(String) reception = policy(
      user(UserRole.professional),
      m: member(ClinicRole.receptionist),
      w: WorkspaceProfile.professional,
    );
    expect(reception(Routes.patientModule('vacinacao')), isFalse);
  });

  test('item ativo segue a rota, prefixo mais longo vence', () {
    final List<MainMenuEntry> menu = buildMainMenu((_) => true);
    int active(String location) {
      final int i = activeMainMenuIndex(menu, location);
      return i;
    }

    expect(menu[active(Routes.agendaPath)].module, MainMenuModule.agenda);
    expect(
      menu[active(Routes.clinicReceptionPath)].module,
      MainMenuModule.consultations,
    );
    expect(
      menu[active(Routes.patientModule('crescimento'))].module,
      MainMenuModule.growth,
    );
    expect(
      menu[active(Routes.financeReportsPath)].module,
      MainMenuModule.reports,
    );
    expect(
      menu[active('${Routes.financePath}/receber')].module,
      MainMenuModule.finance,
    );
    expect(active('/biblioteca'), -1);
  });

  test('destino do módulo para o paciente selecionado', () {
    expect(
      MainMenuModule.exams.patientRoute('c9'),
      Routes.supplementWithChild(Routes.supplementLabsPath, 'c9'),
    );
    for (final MainMenuModule m in <MainMenuModule>[
      MainMenuModule.vaccines,
      MainMenuModule.growth,
      MainMenuModule.prescriptions,
    ]) {
      expect(m.patientRoute('c9'), Routes.clinicPatient360('c9'));
      expect(m.provisionalNotice, isNotNull, reason: m.label);
    }
    expect(MainMenuModule.exams.provisionalNotice, isNull);
    expect(
      MainMenuModule.chart.patientRoute('c9'),
      Routes.clinicPatient360('c9'),
    );
    expect(MainMenuModule.fromSlug('puericultura'), MainMenuModule.wellChild);
    expect(MainMenuModule.fromSlug('inexistente'), isNull);
  });

  group('papel exibido', () {
    test('recepcionista não aparece como área da família nem pediatra', () {
      expect(
        accountRoleLabel(
          user: user(UserRole.professional),
          membership: member(ClinicRole.receptionist),
          workspace: WorkspaceProfile.receptionist,
        ),
        'Recepcionista',
      );
    });

    test('profissional sem especialidade usa o papel na clínica', () {
      expect(
        accountRoleLabel(
          user: user(UserRole.professional),
          membership: member(ClinicRole.nursing),
          workspace: WorkspaceProfile.professional,
        ),
        'Enfermagem',
      );
      expect(
        accountRoleLabel(
          user: user(UserRole.professional, specialty: 'Neuropediatria'),
          membership: member(ClinicRole.physician),
          workspace: WorkspaceProfile.professional,
        ),
        'Neuropediatria',
      );
    });

    test('família', () {
      expect(
        accountRoleLabel(
          user: user(UserRole.parent),
          membership: null,
          workspace: WorkspaceProfile.patient,
        ),
        'Área da família',
      );
    });
  });
}
