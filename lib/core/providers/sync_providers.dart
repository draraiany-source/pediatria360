import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync_service.dart';
import 'core_providers.dart';

final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (Ref ref) {
    final SyncService service = SyncService(
      database: ref.watch(localDatabaseProvider),
      firestore: ref.watch(firestoreProvider),
      connectivity: ref.watch(connectivityServiceProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Estado da sincronização, como fluxo.
///
/// Alimenta a faixa que diz ao usuário se o que ele registrou já subiu. Para
/// dado de saúde, "achei que tinha salvado" é um resultado ruim.
final StreamProvider<SyncStatus> syncStatusProvider =
    StreamProvider<SyncStatus>(
  (Ref ref) => ref.watch(syncServiceProvider).onStatusChange,
);

/// Quantas alterações aguardam envio.
///
/// Atalho síncrono sobre [syncStatusProvider], para o shell não precisar
/// tratar `AsyncValue` só para mostrar um número.
final Provider<int> pendingSyncCountProvider = Provider<int>(
  (Ref ref) => ref.watch(syncStatusProvider).valueOrNull?.pending ?? 0,
);
