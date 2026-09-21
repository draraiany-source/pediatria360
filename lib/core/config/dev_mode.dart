import 'package:flutter/foundation.dart';

import '../../shared/domain/entities/app_user.dart';
import 'app_config.dart';

/// Acesso direto temporário para desenvolvimento / homologação de UI.
///
/// ## Segurança
///
/// - Em debug: ativo quando [_flag] é `true`.
/// - Em release/profile: só com `--dart-define=SKIP_AUTH=true` **e**
///   ambiente diferente de `prod` (homologação web). Em `ENV=prod` nunca
///   liga, mesmo com SKIP_AUTH.
/// - Não grava senha, token nem credencial real. O usuário é um objeto
///   local em memória; não autentica no Firebase Auth.
/// - O fluxo de login e o Firebase Authentication permanecem intactos.
class DevMode {
  const DevMode._();

  /// Liga o atalho de desenvolvimento. Troque para `false` se quiser
  /// testar o login real ainda em debug.
  static const bool _flag = true;

  /// Homologação web: `flutter build web --dart-define=SKIP_AUTH=true`.
  static const bool _skipAuthDefine =
      bool.fromEnvironment('SKIP_AUTH', defaultValue: false);

  static bool get isEnabled {
    if (!_flag) return false;
    if (kDebugMode) return true;
    // Release/homolog: só com define explícito e fora de produção.
    return _skipAuthDefine && !AppConfig.isProduction;
  }

  /// UID local — não é um uid do Firebase Auth.
  static const String userId = 'dev-local-user';

  /// Perfil amplo para navegar telas clínicas e admin em testes de UI.
  static AppUser get user => AppUser(
        uid: userId,
        email: 'dev@pediatria360.local',
        name: 'Carolina Souza',
        role: UserRole.admin,
        plan: UserPlan.pro,
        createdAt: DateTime.utc(2018, 1, 1),
        emailVerified: true,
        onboardingDone: true,
        professionalVerified: true,
        specialty: 'Pediatra',
        crm: '12345-SP',
      );
}
