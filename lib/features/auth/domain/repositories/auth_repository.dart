import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';

/// Contrato de autenticacao. A camada de apresentacao depende disto, nunca do
/// FirebaseAuth — e o que permite trocar o provedor sem tocar nas telas.
abstract class AuthRepository {
  /// Emite o usuario a cada mudanca de sessao *e* a cada mudanca no documento
  /// `users/{uid}` (papel, plano, XP). `null` quando deslogado.
  Stream<AppUser?> watchCurrentUser();

  /// Usuario atual sem esperar o stream. `null` se deslogado.
  AppUser? get cachedUser;

  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });

  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);

  Future<Result<void>> sendEmailVerification();

  /// Recarrega o usuario do servidor — usado ao voltar da caixa de entrada
  /// para checar se o e-mail ja foi confirmado.
  Future<Result<AppUser>> reload();

  Future<Result<AppUser>> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    String? specialty,
  });

  /// Define papel e dados profissionais na tela de perfil inicial.
  Future<Result<AppUser>> completeOnboarding({
    required UserRole role,
    String? crm,
    String? specialty,
  });

  /// Registra o token de push do aparelho atual.
  Future<Result<void>> registerDeviceToken(String token);

  Future<Result<void>> removeDeviceToken(String token);

  /// Exclui a conta e todo o dado associado (LGPD, art. 18, VI). A remocao em
  /// cascata roda na Cloud Function `onUserDeleted`.
  Future<Result<void>> deleteAccount({required String password});
}
