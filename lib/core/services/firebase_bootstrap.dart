import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../../firebase_options.dart';
import 'app_check_bootstrap.dart';
import 'app_logger.dart';
import 'notification_service.dart';

/// Inicializacao da infraestrutura, antes do primeiro frame.
///
/// Ordem importa: Firebase -> App Check (opcional) -> Crashlytics ->
/// persistencia local -> emuladores (se pedido).
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> run() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await AppCheckBootstrap.activateIfEnabled();
    await _setupCrashlytics();
    await _setupFirestore();
    await _setupHive();

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    if (AppConfig.useFirebaseEmulator) {
      await _useEmulators();
    }
  }

  static Future<void> _setupCrashlytics() async {
    if (kIsWeb) return; // Crashlytics nao suporta web.

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(AppConfig.isProduction);
    AppLogger.enableCrashReporting();

    // Erros do framework Flutter.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Erros assincronos fora da zona do Flutter.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static Future<void> _setupFirestore() async {
    // Persistencia offline nativa do Firestore: leituras continuam
    // funcionando sem rede e escritas ficam em fila no proprio SDK.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static Future<void> _setupHive() async {
    await Hive.initFlutter('pediatria360');
  }

  static Future<void> _useEmulators() async {
    const String host = AppConfig.emulatorHost;
    try {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .useFunctionsEmulator(host, 5001);
      AppLogger.info('Emuladores do Firebase ativos em $host', tag: 'boot');
    } catch (error, stack) {
      await AppLogger.error(error, stack, reason: 'emulator setup');
    }
  }
}
