import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';

/// Regiao das Cloud Functions. Sao Paulo reduz a latencia para o publico
/// brasileiro em ~120ms comparado a us-central1.
const String kFunctionsRegion = 'southamerica-east1';

// ---------------------------------------------------------------- Firebase

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (Ref ref) => FirebaseAuth.instance,
);

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) => FirebaseStorage.instance);

final Provider<FirebaseFunctions> firebaseFunctionsProvider =
    Provider<FirebaseFunctions>(
  (Ref ref) => FirebaseFunctions.instanceFor(region: kFunctionsRegion),
);

final Provider<AnalyticsService> analyticsProvider = Provider<AnalyticsService>(
  (Ref ref) => AnalyticsService(FirebaseAnalytics.instance),
);

// ------------------------------------------------------------------ Rede

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5), // uploads de video
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }
  ref.onDispose(dio.close);
  return dio;
});

final Provider<ConnectivityService> connectivityServiceProvider =
    Provider<ConnectivityService>((Ref ref) {
  final ConnectivityService service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// `true` quando ha rede. A UI observa isto para exibir o `OfflineBanner` e o
/// `SyncService` para drenar a outbox.
final StreamProvider<bool> connectivityProvider = StreamProvider<bool>(
  (Ref ref) async* {
    final ConnectivityService service =
        ref.watch(connectivityServiceProvider);
    yield service.isOnline;
    yield* service.onStatusChange;
  },
);

final Provider<bool> isOnlineProvider = Provider<bool>(
  (Ref ref) => ref.watch(connectivityProvider).value ?? true,
);

// ------------------------------------------------------- Servicos assincronos
//
// Estes provedores sao sobrescritos no `main.dart` com a instancia ja
// inicializada, para que nenhuma tela precise esperar pelo `AsyncValue`.

final Provider<CacheService> cacheServiceProvider = Provider<CacheService>(
  (Ref ref) => throw UnimplementedError(
    'cacheServiceProvider precisa ser sobrescrito no bootstrap.',
  ),
);

final Provider<LocalDatabase?> localDatabaseProvider = Provider<LocalDatabase?>(
  (Ref ref) => throw UnimplementedError(
    'localDatabaseProvider precisa ser sobrescrito no bootstrap.',
  ),
);

final Provider<RemoteConfigService> remoteConfigProvider =
    Provider<RemoteConfigService>(
  (Ref ref) => throw UnimplementedError(
    'remoteConfigProvider precisa ser sobrescrito no bootstrap.',
  ),
);

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>(
  (Ref ref) => throw UnimplementedError(
    'notificationServiceProvider precisa ser sobrescrito no bootstrap.',
  ),
);
