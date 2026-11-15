import '../services/remote_config_service.dart';
import 'app_config.dart';

/// Flags dos modulos M2/M3. Default desligado ate homologacao.
class ModuleFlags {
  const ModuleFlags._();

  static bool kidsSpaceEnabled([RemoteConfigService? remote]) {
    if (AppConfig.kidsSpaceRuntimeEnabled) {
      return true;
    }
    return remote?.kidsSpaceEnabled ?? false;
  }

  static bool kidsKioskEnabled([RemoteConfigService? remote]) {
    if (!kidsSpaceEnabled(remote)) {
      return false;
    }
    if (AppConfig.kidsKioskRuntimeEnabled) {
      return true;
    }
    return remote?.kidsKioskEnabled ?? false;
  }

  static bool tiaCrisRuntimeEnabled([RemoteConfigService? remote]) {
    if (AppConfig.tiaCrisRuntimeEnabled) {
      return true;
    }
    return remote?.tiaCrisEnabled ?? false;
  }

  static bool tiaCrisBookingEnabled([RemoteConfigService? remote]) {
    if (!tiaCrisRuntimeEnabled(remote)) {
      return false;
    }
    if (AppConfig.tiaCrisBookingRuntimeEnabled) {
      return true;
    }
    return remote?.tiaCrisBookingEnabled ?? false;
  }
}
