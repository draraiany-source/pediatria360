import '../../shared/domain/entities/app_user.dart';
import 'routes.dart';

/// Política de autorização de rota — para onde redirecionar, dado o estado
/// atual da sessão e a rota que se está tentando acessar.
///
/// ## Por que isto existe separado do `GoRouter`
///
/// A função `redirect:` do `GoRouter` recebe `BuildContext` e
/// `GoRouterState`, e lê `ref.read(...)` diretamente — nada disso é
/// testável sem simular o framework inteiro. Esta função não recebe nada
/// do Flutter: só os valores que a decisão realmente depende. O
/// `GoRouter.redirect` vira uma casca fina que coleta esses valores e
/// chama esta função — a decisão em si mora aqui, testável com um
/// `AppUser` de mentira e uma string de rota, nada mais.
///
/// Retorna o caminho para onde redirecionar, ou `null` se a rota atual já
/// é permitida.
String? resolveRouteRedirect({
  required bool maintenanceMode,
  required String location,
  required bool authLoading,
  required bool onboardingLoading,
  required AppUser? user,
  required bool seenOnboarding,
  bool unlockAllRoles = false,
}) {
  // 1. Manutencao bloqueia tudo, inclusive telas publicas.
  if (maintenanceMode) {
    return location == Routes.maintenancePath ? null : Routes.maintenancePath;
  }
  if (location == Routes.maintenancePath) return Routes.splashPath;

  // 2. Enquanto sessao ou preferencia carregam, segura no splash.
  if (authLoading || onboardingLoading) {
    return location == Routes.splashPath ? null : Routes.splashPath;
  }

  final bool signedIn = user != null;

  const Set<String> publicRoutes = <String>{
    Routes.loginPath,
    Routes.registerPath,
    Routes.forgotPasswordPath,
    Routes.onboardingPath,
  };
  final bool isPublic = publicRoutes.contains(location);
  final bool isSplash = location == Routes.splashPath;

  // 3. Deslogado: apresentacao na primeira vez, senao login.
  if (!signedIn) {
    if (!seenOnboarding) {
      return location == Routes.onboardingPath ? null : Routes.onboardingPath;
    }
    return isPublic ? null : Routes.loginPath;
  }

  // 4. Logado, mas sem papel definido: perfil inicial e obrigatorio.
  if (!user.onboardingDone) {
    return location == Routes.roleSetupPath ? null : Routes.roleSetupPath;
  }

  // 5. Logado e completo: tira de qualquer tela de entrada.
  if (isPublic || isSplash || location == Routes.roleSetupPath) {
    return Routes.homePath;
  }

  // Em DEV_MODE o usuário local precisa abrir admin + prontuário/agenda
  // para testar UI. Em release, unlockAllRoles é sempre false.
  if (unlockAllRoles) {
    return null;
  }

  // 6. Area administrativa exige papel de admin.
  if (location.startsWith(Routes.adminPath) && !user.role.isAdmin) {
    return Routes.homePath;
  }

  // 7. Prontuario, agenda e consultorio exigem papel de profissional. Bloqueia
  // tambem o admin — administracao da plataforma nao e a mesma coisa que
  // autorizacao clinica, e nao deveria dar acesso automatico a prontuario
  // so por ser admin. Essa mesma regra ja existe, separadamente, nas
  // regras do Firestore (`encounters/{id}`) — aqui e a segunda camada,
  // nao a unica.
  final bool isProfessionalArea = location.startsWith(Routes.patientsPath) ||
      location.startsWith(Routes.agendaPath) ||
      location.startsWith(Routes.clinicPath) ||
      location.startsWith(Routes.financePath) ||
      location.startsWith(Routes.billingPath) ||
      location.startsWith(Routes.inventoryPath) ||
      location.startsWith(Routes.biPath) ||
      location.startsWith(Routes.auditPath) ||
      location.startsWith(Routes.permissionsPath) ||
      location.startsWith(Routes.supplementPath) ||
      location.startsWith(Routes.clinicOrgPath);
  if (isProfessionalArea && user.role != UserRole.professional) {
    return Routes.homePath;
  }

  return null;
}
