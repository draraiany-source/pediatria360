import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

/// Testa `resolveRouteRedirect` — a decisão de autorização por trás do
/// `GoRouter.redirect`, extraída para função pura precisamente para poder
/// ser testada sem simular `BuildContext`/`GoRouterState`.
///
/// A cobertura aqui é a decisão de autorização em si — não testa se o
/// `GoRouter` de fato chama esta função (isso exigiria um teste de
/// integração/widget, fora do escopo desta rodada), testa se a decisão,
/// dado um estado de sessão, é a correta.
void main() {
  AppUser user({
    required UserRole role,
    bool onboardingDone = true,
  }) =>
      AppUser(
        uid: 'uid-teste',
        email: 'teste@exemplo.com',
        name: 'Usuário Teste',
        role: role,
        plan: UserPlan.free,
        createdAt: DateTime(2026, 1, 1),
        onboardingDone: onboardingDone,
      );

  String? redirectFor({
    required String location,
    AppUser? asUser,
    bool maintenanceMode = false,
    bool authLoading = false,
    bool onboardingLoading = false,
    bool seenOnboarding = true,
    ClinicMembership? clinicMembership,
  }) =>
      resolveRouteRedirect(
        maintenanceMode: maintenanceMode,
        location: location,
        authLoading: authLoading,
        onboardingLoading: onboardingLoading,
        user: asUser,
        seenOnboarding: seenOnboarding,
        clinicMembership: clinicMembership,
      );

  group('RESPONSÁVEL (parent)', () {
    final AppUser parent = user(role: UserRole.parent);

    test('NÃO acessa /admin', () {
      expect(
        redirectFor(location: Routes.adminPath, asUser: parent),
        Routes.homePath,
      );
    });

    test('NÃO acessa /pacientes', () {
      expect(
        redirectFor(location: Routes.patientsPath, asUser: parent),
        Routes.homePath,
      );
    });

    test('NÃO acessa /agenda', () {
      expect(
        redirectFor(location: Routes.agendaPath, asUser: parent),
        Routes.homePath,
      );
    });

    test('NÃO acessa /consultorio', () {
      expect(
        redirectFor(location: Routes.clinicPath, asUser: parent),
        Routes.homePath,
      );
    });

    test('acessa /inicio normalmente', () {
      expect(redirectFor(location: Routes.homePath, asUser: parent), isNull);
    });
  });

  group('PROFISSIONAL', () {
    final AppUser professional = user(role: UserRole.professional);

    test('acessa /pacientes', () {
      expect(
        redirectFor(location: Routes.patientsPath, asUser: professional),
        isNull,
      );
    });

    test('acessa /agenda', () {
      expect(
        redirectFor(location: Routes.agendaPath, asUser: professional),
        isNull,
      );
    });

    test('acessa /consultorio', () {
      expect(
        redirectFor(location: Routes.clinicPath, asUser: professional),
        isNull,
      );
    });

    test('acessa sub-rota de voz do consultorio', () {
      expect(
        redirectFor(
          location: Routes.clinicVoicePath,
          asUser: professional,
        ),
        isNull,
      );
    });

    test('NÃO acessa /admin sem autorização', () {
      expect(
        redirectFor(location: Routes.adminPath, asUser: professional),
        Routes.homePath,
      );
    });

    test('acessa uma sub-rota de /pacientes (prefixo, não só a raiz)', () {
      expect(
        redirectFor(
          location: '${Routes.patientsPath}/paciente-123',
          asUser: professional,
        ),
        isNull,
      );
    });

    test('FASE2 recepcao com membership: agenda ok, pacientes bloqueado', () {
      final ClinicMembership rec = ClinicMembership(
        id: 'm1',
        clinicId: 'c1',
        userId: 'uid-teste',
        role: ClinicRole.receptionist,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(
        redirectFor(
          location: Routes.agendaPath,
          asUser: professional,
          clinicMembership: rec,
        ),
        isNull,
      );
      expect(
        redirectFor(
          location: Routes.patientsPath,
          asUser: professional,
          clinicMembership: rec,
        ),
        Routes.homePath,
      );
    });
  });

  group('ADMIN', () {
    final AppUser admin = user(role: UserRole.admin);

    test('acessa /admin', () {
      expect(redirectFor(location: Routes.adminPath, asUser: admin), isNull);
    });

    test('NÃO ganha acesso automático a /pacientes só por ser admin', () {
      // O ponto central desta seção: administração da plataforma não é
      // autorização clínica. Confirmado aqui e, separadamente, nas regras
      // do Firestore — duas camadas, não uma dependendo da outra.
      expect(
        redirectFor(location: Routes.patientsPath, asUser: admin),
        Routes.homePath,
      );
    });

    test('NÃO ganha acesso automático a /agenda só por ser admin', () {
      expect(
        redirectFor(location: Routes.agendaPath, asUser: admin),
        Routes.homePath,
      );
    });

    test('NÃO ganha acesso automático a /consultorio só por ser admin', () {
      expect(
        redirectFor(location: Routes.clinicPath, asUser: admin),
        Routes.homePath,
      );
    });
  });

  group('deslogado', () {
    test('sem onboarding visto: vai para onboarding, não para login', () {
      expect(
        redirectFor(
          location: Routes.homePath,
          asUser: null,
          seenOnboarding: false,
        ),
        Routes.onboardingPath,
      );
    });

    test('onboarding já visto: vai para login', () {
      expect(
        redirectFor(location: Routes.homePath, asUser: null),
        Routes.loginPath,
      );
    });

    test('rota pública permanece acessível', () {
      expect(redirectFor(location: Routes.loginPath, asUser: null), isNull);
    });
  });

  group('logado sem perfil definido', () {
    test('é obrigado a passar por /perfil-inicial', () {
      final AppUser semPerfil =
          user(role: UserRole.parent, onboardingDone: false);
      expect(
        redirectFor(location: Routes.homePath, asUser: semPerfil),
        Routes.roleSetupPath,
      );
    });

    test('já em /perfil-inicial, fica', () {
      final AppUser semPerfil =
          user(role: UserRole.parent, onboardingDone: false);
      expect(
        redirectFor(location: Routes.roleSetupPath, asUser: semPerfil),
        isNull,
      );
    });
  });

  group('logado e completo, em tela de entrada', () {
    test('sai do /login para /inicio', () {
      final AppUser parent = user(role: UserRole.parent);
      expect(
        redirectFor(location: Routes.loginPath, asUser: parent),
        Routes.homePath,
      );
    });

    test('sai da splash para /inicio', () {
      final AppUser parent = user(role: UserRole.parent);
      expect(
        redirectFor(location: Routes.splashPath, asUser: parent),
        Routes.homePath,
      );
    });
  });

  group('manutenção', () {
    test('bloqueia tudo, inclusive rota pública', () {
      expect(
        redirectFor(location: Routes.loginPath, maintenanceMode: true),
        Routes.maintenancePath,
      );
    });

    test('bloqueia até profissional em rota autorizada', () {
      final AppUser professional = user(role: UserRole.professional);
      expect(
        redirectFor(
          location: Routes.patientsPath,
          asUser: professional,
          maintenanceMode: true,
        ),
        Routes.maintenancePath,
      );
    });

    test('a própria tela de manutenção fica acessível', () {
      expect(
        redirectFor(location: Routes.maintenancePath, maintenanceMode: true),
        isNull,
      );
    });

    test('manutenção desligada: sai da tela de manutenção', () {
      expect(
        redirectFor(location: Routes.maintenancePath, maintenanceMode: false),
        Routes.splashPath,
      );
    });
  });

  group('carregando', () {
    test('sessão carregando: segura na splash', () {
      expect(
        redirectFor(location: Routes.homePath, authLoading: true),
        Routes.splashPath,
      );
    });

    test('preferência de onboarding carregando: segura na splash', () {
      expect(
        redirectFor(location: Routes.homePath, onboardingLoading: true),
        Routes.splashPath,
      );
    });

    test('já na splash enquanto carrega: fica', () {
      expect(
        redirectFor(location: Routes.splashPath, authLoading: true),
        isNull,
      );
    });
  });
}
