import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../config/app_config.dart';
import 'app_logger.dart';

/// Chaves de Remote Config. Cada flag tem um default seguro: se o fetch
/// falhar (offline no primeiro uso), o app continua funcional.
class RemoteFlag {
  const RemoteFlag._();

  static const String aiEnabled = 'ai_enabled';
  static const String aiFreeMessagesPerDay = 'ai_free_messages_per_day';
  static const String aiDisclaimer = 'ai_disclaimer';
  static const String marketplaceEnabled = 'marketplace_enabled';
  static const String telemedicineEnabled = 'telemedicine_enabled';
  static const String gamificationEnabled = 'gamification_enabled';
  static const String liveEnabled = 'live_enabled';
  static const String minSupportedBuild = 'min_supported_build';
  static const String maintenanceMode = 'maintenance_mode';
  static const String maintenanceMessage = 'maintenance_message';
  static const String featuredCourseId = 'featured_course_id';
  static const String vaccineCalendarVersion = 'vaccine_calendar_version';

  static final Map<String, Object> defaults = <String, Object>{
    aiEnabled: true,
    aiFreeMessagesPerDay: AppConfig.aiFreeMessagesPerDay,
    aiDisclaimer:
        'As respostas da IA sao orientacao educativa e nao substituem a '
            'avaliacao de um pediatra. Em emergencia, procure atendimento.',
    marketplaceEnabled: true,
    telemedicineEnabled: true,
    gamificationEnabled: true,
    liveEnabled: true,
    minSupportedBuild: 1,
    maintenanceMode: false,
    maintenanceMessage:
        'Estamos em manutencao. Voltamos em alguns minutos.',
    featuredCourseId: '',
    vaccineCalendarVersion: 1,
  };
}

/// Acesso tipado ao Remote Config.
class RemoteConfigService {
  RemoteConfigService(this._config);

  final FirebaseRemoteConfig _config;

  static Future<RemoteConfigService> init() async {
    final FirebaseRemoteConfig config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Em dev, busca sempre; em producao, respeita a janela de cache.
        minimumFetchInterval: AppConfig.isProduction
            ? const Duration(hours: 6)
            : Duration.zero,
      ),
    );
    await config.setDefaults(RemoteFlag.defaults);

    try {
      await config.fetchAndActivate();
    } catch (error, stack) {
      // Falha de fetch nao pode impedir o app de abrir: os defaults valem.
      await AppLogger.error(
        error,
        stack,
        reason: 'remote_config.fetchAndActivate',
      );
    }

    return RemoteConfigService(config);
  }

  bool getBool(String key) => _config.getBool(key);
  int getInt(String key) => _config.getInt(key);
  String getString(String key) => _config.getString(key);
  double getDouble(String key) => _config.getDouble(key);

  /// Emite quando novos valores chegam do servidor (push do Remote Config).
  Stream<RemoteConfigUpdate> get onUpdate => _config.onConfigUpdated;

  Future<void> activateUpdate() async {
    await _config.activate();
  }

  Future<bool> refresh() => _config.fetchAndActivate();

  // ------------------------------------------------------------ Atalhos
  bool get aiEnabled => getBool(RemoteFlag.aiEnabled);
  int get aiFreeMessagesPerDay => getInt(RemoteFlag.aiFreeMessagesPerDay);
  String get aiDisclaimer => getString(RemoteFlag.aiDisclaimer);
  bool get marketplaceEnabled => getBool(RemoteFlag.marketplaceEnabled);
  bool get telemedicineEnabled => getBool(RemoteFlag.telemedicineEnabled);
  bool get gamificationEnabled => getBool(RemoteFlag.gamificationEnabled);
  bool get liveEnabled => getBool(RemoteFlag.liveEnabled);
  bool get maintenanceMode => getBool(RemoteFlag.maintenanceMode);
  String get maintenanceMessage => getString(RemoteFlag.maintenanceMessage);
  int get minSupportedBuild => getInt(RemoteFlag.minSupportedBuild);
  String get featuredCourseId => getString(RemoteFlag.featuredCourseId);
}
