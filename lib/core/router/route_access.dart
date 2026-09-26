import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../features/workspace/domain/workspace_profile.dart';
import '../../features/workspace/presentation/providers/workspace_providers.dart';
import '../../shared/domain/entities/app_user.dart';
import '../../shared/domain/entities/clinic_organization.dart';
import '../config/dev_mode.dart';
import 'route_authorization.dart';

/// Mesma decisao do `redirect` do router, para a UI esconder atalhos que
/// seriam bloqueados (o toque "voltaria sozinho" ao inicio).
///
/// Use dentro de `build`; em callbacks use [canOpenRouteNow].
bool canOpenRoute(WidgetRef ref, String location) => _allowed(
      location,
      ref.watch(currentUserProvider),
      ref.watch(activeClinicMembershipProvider),
      ref.watch(currentWorkspaceProvider),
    );

bool canOpenRouteNow(WidgetRef ref, String location) => _allowed(
      location,
      ref.read(currentUserProvider),
      ref.read(activeClinicMembershipProvider),
      ref.read(currentWorkspaceProvider),
    );

bool _allowed(
  String location,
  AppUser? user,
  ClinicMembership? membership,
  WorkspaceProfile workspace,
) {
  return resolveRouteRedirect(
        maintenanceMode: false,
        location: Uri.parse(location).path,
        authLoading: false,
        onboardingLoading: false,
        user: user,
        seenOnboarding: true,
        unlockAllRoles: DevMode.isEnabled,
        clinicMembership: membership,
        workspace: workspace,
      ) ==
      null;
}
