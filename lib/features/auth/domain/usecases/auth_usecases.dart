import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Entrar com e-mail e senha.
class SignInWithEmail implements UseCase<AppUser, SignInParams> {
  const SignInWithEmail(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(SignInParams params) =>
      _repository.signInWithEmail(
        email: params.email.trim(),
        password: params.password,
      );
}

class SignInParams {
  const SignInParams({required this.email, required this.password});

  final String email;
  final String password;
}

/// Criar conta com e-mail e senha.
class SignUpWithEmail implements UseCase<AppUser, SignUpParams> {
  const SignUpWithEmail(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(SignUpParams params) =>
      _repository.signUpWithEmail(
        email: params.email.trim(),
        password: params.password,
        name: params.name.trim(),
      );
}

class SignUpParams {
  const SignUpParams({
    required this.email,
    required this.password,
    required this.name,
  });

  final String email;
  final String password;
  final String name;
}

/// Entrar com o Google.
class SignInWithGoogle implements UseCase<AppUser, NoParams> {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(NoParams params) =>
      _repository.signInWithGoogle();
}

/// Sair. Remove o token de push antes de encerrar a sessao — se sair primeiro,
/// o app perde a permissao de escrever no proprio documento.
class SignOut implements UseCase<void, NoParams> {
  const SignOut(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.signOut();
}

/// Enviar e-mail de redefinicao de senha.
class SendPasswordReset implements UseCase<void, String> {
  const SendPasswordReset(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String email) =>
      _repository.sendPasswordReset(email.trim());
}

/// Concluir o perfil inicial (papel + dados profissionais).
class CompleteOnboarding implements UseCase<AppUser, OnboardingParams> {
  const CompleteOnboarding(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(OnboardingParams params) =>
      _repository.completeOnboarding(
        role: params.role,
        crm: params.crm?.trim(),
        specialty: params.specialty?.trim(),
      );
}

class OnboardingParams {
  const OnboardingParams({required this.role, this.crm, this.specialty});

  final UserRole role;
  final String? crm;
  final String? specialty;
}

/// Atualizar o perfil.
class UpdateProfile implements UseCase<AppUser, UpdateProfileParams> {
  const UpdateProfile(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(UpdateProfileParams params) =>
      _repository.updateProfile(
        name: params.name?.trim(),
        phone: params.phone?.trim(),
        photoUrl: params.photoUrl,
        specialty: params.specialty,
      );
}

class UpdateProfileParams {
  const UpdateProfileParams({
    this.name,
    this.phone,
    this.photoUrl,
    this.specialty,
  });

  final String? name;
  final String? phone;
  final String? photoUrl;

  /// Área de atuação — só faz sentido para conta profissional. CRM não
  /// entra aqui de propósito: é o dado que a equipe verificou manualmente
  /// para liberar prescrição, e o próprio usuário não pode reescrever o
  /// que foi conferido sobre ele.
  final String? specialty;
}

/// Excluir a conta.
class DeleteAccount implements UseCase<void, String> {
  const DeleteAccount(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String password) =>
      _repository.deleteAccount(password: password);
}
