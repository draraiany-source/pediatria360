import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/config/module_flags.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/kids_progress_repository.dart';
import '../../domain/kids_progress.dart';

final Provider<KidsProgressRepository> kidsProgressRepositoryProvider =
    Provider<KidsProgressRepository>(
  (Ref ref) => KidsProgressRepository(ref.watch(firestoreProvider)),
);

final Provider<bool> kidsSpaceEnabledProvider = Provider<bool>((Ref ref) {
  final RemoteConfigService remote = ref.watch(remoteConfigProvider);
  return ModuleFlags.kidsSpaceEnabled(remote);
});

final FutureProvider<KidsProgressProfile?> kidsProgressProvider =
    FutureProvider<KidsProgressProfile?>((Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }
  return ref.watch(kidsProgressRepositoryProvider).load(user.uid);
});


/// Preferencias de acessibilidade da sessao Kids (sem dados clinicos).
class KidsAccessibilityPrefs {
  const KidsAccessibilityPrefs({
    this.noTimer = true,
    this.reducedMotion = false,
    this.voiceHelp = false,
    this.pauseAnytime = true,
  });

  final bool noTimer;
  final bool reducedMotion;
  final bool voiceHelp;
  final bool pauseAnytime;

  KidsAccessibilityPrefs copyWith({
    bool? noTimer,
    bool? reducedMotion,
    bool? voiceHelp,
    bool? pauseAnytime,
  }) =>
      KidsAccessibilityPrefs(
        noTimer: noTimer ?? this.noTimer,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        voiceHelp: voiceHelp ?? this.voiceHelp,
        pauseAnytime: pauseAnytime ?? this.pauseAnytime,
      );
}

final StateProvider<KidsAccessibilityPrefs> kidsAccessibilityProvider =
    StateProvider<KidsAccessibilityPrefs>(
  (Ref ref) => const KidsAccessibilityPrefs(),
);
