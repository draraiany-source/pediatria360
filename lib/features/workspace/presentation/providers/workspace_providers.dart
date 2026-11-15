import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/workspace_profile.dart';

const String _kActiveWorkspaceKey = 'p360_active_workspace';

final Provider<Set<WorkspaceProfile>> grantedWorkspacesProvider =
    Provider<Set<WorkspaceProfile>>((Ref ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  final List<ClinicMembership> memberships =
      ref.watch(myClinicMembershipsProvider).valueOrNull ??
          const <ClinicMembership>[];
  return WorkspaceAccess.grantedProfiles(
    user: user,
    memberships: memberships,
  );
});

class ActiveWorkspaceController extends AsyncNotifier<WorkspaceProfile> {
  @override
  Future<WorkspaceProfile> build() async {
    final Set<WorkspaceProfile> granted = ref.watch(grantedWorkspacesProvider);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_kActiveWorkspaceKey);
    if (saved != null) {
      for (final WorkspaceProfile p in WorkspaceProfile.values) {
        if (p.name == saved && granted.contains(p)) return p;
      }
    }
    return WorkspaceAccess.defaultProfile(granted);
  }

  Future<void> select(WorkspaceProfile profile) async {
    final Set<WorkspaceProfile> granted = ref.read(grantedWorkspacesProvider);
    if (!granted.contains(profile)) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveWorkspaceKey, profile.name);
    state = AsyncData<WorkspaceProfile>(profile);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveWorkspaceKey);
    final Set<WorkspaceProfile> granted = ref.read(grantedWorkspacesProvider);
    state = AsyncData<WorkspaceProfile>(
      WorkspaceAccess.defaultProfile(granted),
    );
  }
}

final AsyncNotifierProvider<ActiveWorkspaceController, WorkspaceProfile>
    activeWorkspaceProvider =
    AsyncNotifierProvider<ActiveWorkspaceController, WorkspaceProfile>(
  ActiveWorkspaceController.new,
);

/// Valor sincrono seguro para UI (evita flicker Async).
final Provider<WorkspaceProfile> currentWorkspaceProvider =
    Provider<WorkspaceProfile>((Ref ref) {
  final Set<WorkspaceProfile> granted = ref.watch(grantedWorkspacesProvider);
  final WorkspaceProfile? async =
      ref.watch(activeWorkspaceProvider).valueOrNull;
  if (async != null && granted.contains(async)) return async;
  return WorkspaceAccess.defaultProfile(granted);
});