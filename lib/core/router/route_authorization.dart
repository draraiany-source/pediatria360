import '../../features/security/domain/permission_matrix.dart';
import '../../features/workspace/domain/workspace_profile.dart';
import '../../shared/domain/entities/app_user.dart';
import '../../shared/domain/entities/clinic_organization.dart';
import 'routes.dart';

/// Politica de autorizacao de rota — para onde redirecionar, dado o estado
/// atual da sessao e a rota que se esta tentando acessar.
///
/// Retorna o caminho para onde redirecionar, ou `null` se a rota atual ja
/// e permitida.
String? resolveRouteRedirect({
  required bool maintenanceMode,
  required String location,
  required bool authLoading,
  required bool onboardingLoading,
  required AppUser? user,
  required bool seenOnboarding,
  bool unlockAllRoles = false,
  ClinicMembership? clinicMembership,
  WorkspaceProfile? workspace,
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

  // Em DEV_MODE o usuario local precisa abrir admin + prontuario/agenda
  // para testar UI. Em release, unlockAllRoles e sempre false.
  if (unlockAllRoles) {
    return null;
  }

  // 6. Area administrativa CMS exige papel de admin de plataforma.
  if (_under(location, Routes.adminPath) && !user.role.isAdmin) {
    return Routes.homePath;
  }

  // 7. Areas de equipe (clinica / financeiro / BI).
  final bool isStaffArea =
      _under(location, Routes.patientsPath) ||
      _under(location, Routes.agendaPath) ||
      _under(location, Routes.clinicPath) ||
      _under(location, Routes.financePath) ||
      _under(location, Routes.billingPath) ||
      _under(location, Routes.inventoryPath) ||
      _under(location, Routes.biPath) ||
      _under(location, Routes.auditPath) ||
      _under(location, Routes.permissionsPath) ||
      _under(location, Routes.supplementPath) ||
      _under(location, Routes.clinicOrgPath);

  if (isStaffArea) {
    if (user.role == UserRole.professional) {
      // ok
    } else if (user.role.isAdmin) {
      final bool adminAllowed =
          _under(location, Routes.adminPath) ||
          _under(location, Routes.permissionsPath) ||
          _under(location, Routes.auditPath) ||
          _under(location, Routes.biPath) ||
          _under(location, Routes.clinicOrgPath);
      if (!adminAllowed) return Routes.homePath;
    } else {
      return Routes.homePath;
    }
  }

  // 8. FASE 2 — RBAC clinico: recepcao nao abre evolucao/prontuario por URL.
  if (user.role == UserRole.professional && clinicMembership != null) {
    final bool isChartArea =
        _under(location, Routes.patientsPath) ||
        _under(location, Routes.clinicVoicePath);
    if (isChartArea &&
        !PermissionMatrix.allows(
          user: user,
          membership: clinicMembership,
          module: PermissionModule.chart,
          action: PermissionAction.view,
        )) {
      return Routes.homePath;
    }
  }

  // 9. Area de trabalho ativa (perfil concedido) — reforco de UI/rota.
  if (workspace != null && user.role == UserRole.professional) {
    final bool isChart =
        _under(location, Routes.patientsPath) ||
        _under(location, Routes.clinicVoicePath) ||
        _under(location, Routes.supplementPath);
    final bool isFinance =
        _under(location, Routes.financePath) ||
        _under(location, Routes.billingPath) ||
        _under(location, Routes.inventoryPath);

    switch (workspace) {
      case WorkspaceProfile.receptionist:
        if (isChart || isFinance) return Routes.homePath;
      case WorkspaceProfile.finance:
        if (isChart) return Routes.homePath;
        if (_under(location, Routes.clinicReceptionPath) ||
            _under(location, Routes.clinicPendingPath)) {
          return Routes.homePath;
        }
      case WorkspaceProfile.professional:
      case WorkspaceProfile.admin:
      case WorkspaceProfile.patient:
        break;
    }
  }

  return null;
}

/// `/bi` cobre `/bi` e `/bi/...`, mas nao `/biblioteca`.
bool _under(String location, String base) =>
    location == base || location.startsWith('$base/');
