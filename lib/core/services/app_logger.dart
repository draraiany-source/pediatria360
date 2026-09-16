import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Log de desenvolvimento + reporte de erro em producao.
///
/// Regra: em debug, imprime; em producao, envia ao Crashlytics. Nenhuma parte
/// do app chama `print` diretamente (o lint `avoid_print` bloqueia).
class AppLogger {
  const AppLogger._();

  static bool _crashlyticsReady = false;

  /// Chamado no bootstrap depois que o Firebase inicializa.
  static void enableCrashReporting() => _crashlyticsReady = true;

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? 'app'}] $message');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? 'app'}] $message');
    } else if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log('[${tag ?? 'app'}] $message');
    }
  }

  /// Reporta um erro nao fatal. Nenhum dado de saude entra aqui: apenas ids,
  /// codigos e a stack — prontuario nunca sobe para o Crashlytics.
  static Future<void> error(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object>? context,
  }) async {
    if (kDebugMode) {
      debugPrint('[error] ${reason ?? ''} $error\n$stackTrace');
      return;
    }
    if (!_crashlyticsReady) return;

    final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
    if (context != null) {
      for (final MapEntry<String, Object> entry in context.entries) {
        await crashlytics.setCustomKey(entry.key, entry.value);
      }
    }
    await crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  static Future<void> setUser(String? uid) async {
    if (!_crashlyticsReady) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
  }

  /// Migalha de navegacao: ajuda a reconstruir o caminho ate o crash.
  static void breadcrumb(String route) {
    if (kDebugMode) {
      debugPrint('[route] $route');
    } else if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log('route:$route');
    }
  }
}
