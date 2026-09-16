import 'package:flutter/foundation.dart';

import '../../shared/domain/entities/app_user.dart';

/// Acesso direto temporário para desenvolvimento local.
///
/// ## Segurança
///
/// - Ativo **somente** quando [kDebugMode] é `true` (builds debug).
/// - Em profile/release ([kReleaseMode] / sem debug), [isEnabled] é sempre
///   `false` — o login Firebase volta a ser obrigatório sem mudar código.
/// - Não grava senha, token nem credencial real. O usuário é um objeto
///   local em memória; não autentica no Firebase Auth.
/// - O fluxo de login e o Firebase Authentication permanecem intactos.
class DevMode {
  const DevMode._();

  /// Liga o atalho de desenvolvimento. Troque para `false` se quiser
  /// testar o login real ainda em debug.
  static const bool _flag = true;

  static bool get isEnabled => kDebugMode && _flag;

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
