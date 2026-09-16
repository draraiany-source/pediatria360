import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dev_mode.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

// ------------------------------------------------------------ Injecao

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
  (Ref ref) => AuthRemoteDataSource(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    analytics: ref.watch(analyticsProvider),
    onSignOut: () async {
      // Apaga tudo que ficou no aparelho: cache de leitura e banco local.
      await ref.read(cacheServiceProvider).clear();
      await ref.read(localDatabaseProvider)?.wipe();
    },
  ),
);

// ------------------------------------------------------------- Estado

// ---------------------------------------------------------- Casos de uso

final Provider<SignInWithEmail> signInWithEmailProvider =
    Provider<SignInWithEmail>(
  (Ref ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);

final Provider<SignUpWithEmail> signUpWithEmailProvider =
    Provider<SignUpWithEmail>(
  (Ref ref) => SignUpWithEmail(ref.watch(authRepositoryProvider)),
);

final Provider<SignInWithGoogle> signInWithGoogleProvider =
    Provider<SignInWithGoogle>(
  (Ref ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final Provider<SignOut> signOutProvider = Provider<SignOut>(
  (Ref ref) => SignOut(ref.watch(authRepositoryProvider)),
);

final Provider<SendPasswordReset> sendPasswordResetProvider =
    Provider<SendPasswordReset>(
  (Ref ref) => SendPasswordReset(ref.watch(authRepositoryProvider)),
);

final Provider<CompleteOnboarding> completeOnboardingProvider =
    Provider<CompleteOnboarding>(
  (Ref ref) => CompleteOnboarding(ref.watch(authRepositoryProvider)),
);

final Provider<UpdateProfile> updateProfileProvider = Provider<UpdateProfile>(
  (Ref ref) => UpdateProfile(ref.watch(authRepositoryProvider)),
);

final Provider<DeleteAccount> deleteAccountProvider = Provider<DeleteAccount>(
  (Ref ref) => DeleteAccount(ref.watch(authRepositoryProvider)),
);

// -------------------------------------------------------------- Controlador

/// Estado de autenticação vindo do Firebase, como fluxo.
///
/// É a fonte da verdade sobre "há sessão?" — o roteador redireciona a partir
/// dela, e não de um booleano guardado em memória que pode ficar defasado.
///
/// Em [DevMode] (somente debug), emite o usuário local sem tocar no Auth.
final StreamProvider<AppUser?> authStateProvider =
    StreamProvider<AppUser?>(
  (Ref ref) {
    if (DevMode.isEnabled) {
      return Stream<AppUser?>.value(DevMode.user);
    }
    return ref.watch(authRepositoryProvider).watchCurrentUser();
  },
);

/// Usuário da sessão atual, ou `null`.
///
/// Atalho síncrono sobre [authStateProvider], para as telas não precisarem
/// tratar `AsyncValue` só para ler o nome de quem está logado.
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>(
  (Ref ref) => ref.watch(authStateProvider).valueOrNull,
);

/// Estado das acoes de autenticacao (login, cadastro, recuperacao).
@immutable
class AuthActionState {
  const AuthActionState({
    this.isLoading = false,
    this.failure,
    this.message,
  });

  final bool isLoading;
  final Failure? failure;

  /// Mensagem de sucesso (ex.: "E-mail de recuperacao enviado").
  final String? message;

  AuthActionState copyWith({
    bool? isLoading,
    Failure? failure,
    String? message,
    bool clear = false,
  }) =>
      AuthActionState(
        isLoading: isLoading ?? this.isLoading,
        failure: clear ? null : (failure ?? this.failure),
        message: clear ? null : (message ?? this.message),
      );
}

/// Executa as acoes de autenticacao e expoe carregamento/erro para a tela.
class AuthController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  Future<bool> signIn({
    required String email,
    required String password,
  }) =>
      _run(
        () => ref.read(signInWithEmailProvider)(
          SignInParams(email: email, password: password),
        ),
      );

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(
        () => ref.read(signUpWithEmailProvider)(
          SignUpParams(name: name, email: email, password: password),
        ),
      );

  Future<bool> signInWithGoogle() => _run(
        () => ref.read(signInWithGoogleProvider)(const NoParams()),
      );

  Future<bool> completeOnboarding({
    required UserRole role,
    String? crm,
    String? specialty,
  }) =>
      _run(
        () => ref.read(completeOnboardingProvider)(
          OnboardingParams(role: role, crm: crm, specialty: specialty),
        ),
      );

  Future<bool> sendPasswordReset(String email) async {
    final bool ok = await _run(
      () => ref.read(sendPasswordResetProvider)(email),
    );
    if (ok) {
      state = state.copyWith(
        message: 'Enviamos um link de redefinicao para $email.',
      );
    }
    return ok;
  }

  Future<bool> signOut() => _run(
        () => ref.read(signOutProvider)(const NoParams()),
      );

  Future<bool> deleteAccount(String password) => _run(
        () => ref.read(deleteAccountProvider)(password),
      );

  /// Limpa erro e mensagem — chamado ao sair da tela ou ao editar o formulario.
  void clear() => state = const AuthActionState();

  Future<bool> _run<T>(Future<Result<T>> Function() action) async {
    state = const AuthActionState(isLoading: true);
    final Result<T> result = await action();

    return result.fold(
      (T _) {
        state = const AuthActionState();
        return true;
      },
      (Failure failure) {
        // "Login cancelado" e escolha do usuario, nao erro: nao vira alerta.
        if (failure.code == 'cancelled') {
          state = const AuthActionState();
          return false;
        }
        unawaited(
          AppLogger.error(
            failure.cause ?? failure,
            StackTrace.current,
            reason: 'auth: ${failure.code}',
          ),
        );
        state = AuthActionState(failure: failure);
        return false;
      },
    );
  }
}

final NotifierProvider<AuthController, AuthActionState> authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(AuthController.new);
