import 'package:flutter/foundation.dart';

import '../../shared/domain/entities/app_user.dart';
import 'app_config.dart';

/// Acesso direto temporário para desenvolvimento / homologação de UI.
///
/// ## Segurança
///
/// - Em debug: ativo quando [_flag] é `true`.
/// - Em release/profile: só com `--dart-define=SKIP_AUTH=true` **e**
///   ambiente diferente de `prod`. Em `ENV=prod` nunca liga.
/// - Se existir sessão Firebase Auth real, ela prevalece sobre o usuário
///   local (homologação pode navegar como convidado e depois entrar de
///   verdade sem rebuild).
/// - O usuário local **não** autentica no Firebase; leituras/escritas
///   clínicas exigem conta profissional verificada.
class DevMode {
  const DevMode._();

  /// Liga o atalho de desenvolvimento. Troque para `false` se quiser
  /// testar o login real ainda em debug.
  static const bool _flag = true;

  /// Homologação web: `flutter build web --dart-define=SKIP_AUTH=true`.
  static const bool _skipAuthDefine =
      bool.fromEnvironment('SKIP_AUTH', defaultValue: false);

  /// Força Auth Firebase real (FASE 10 / staging Emulator).
  /// Ex.: `--dart-define=FORCE_REAL_AUTH=true`
  static const bool _forceRealAuthDefine =
      bool.fromEnvironment('FORCE_REAL_AUTH', defaultValue: false);

  /// Quando `true`, desliga o convidado nesta sessão e força login real.
  static bool requireRealAuth = false;

  static bool get isEnabled {
    if (_forceRealAuthDefine || requireRealAuth) return false;
    if (!_flag) return false;
    if (kDebugMode) return true;
    return _skipAuthDefine && !AppConfig.isProduction;
  }

  /// UID local — não é um uid do Firebase Auth.
  static const String userId = 'dev-local-user';

  /// Perfil profissional para testar UI clínica (sem Auth Firebase).
  static AppUser get user => AppUser(
        uid: userId,
        email: 'dev@pediatria360.local',
        name: 'Carolina Souza',
        role: UserRole.professional,
        plan: UserPlan.pro,
        createdAt: DateTime.utc(2018, 1, 1),
        emailVerified: true,
        onboardingDone: true,
        professionalVerified: true,
        specialty: 'Pediatra',
        crm: '12345-SP',
      );

  /// Sessão convidada (sem Firebase Auth) — dados clínicos reais não carregam.
  static bool get isGuestSession => isEnabled;
}
