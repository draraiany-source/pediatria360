import 'dart:async';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Implementacao de [AuthRepository].
///
/// Alem de traduzir excecoes em `Failure` (via `guard`), o repositorio e o
/// unico ponto que sabe que login/logout tambem significam: identificar o
/// usuario no Analytics e no Crashlytics, e limpar o dado local ao sair.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AnalyticsService analytics,
    required Future<void> Function() onSignOut,
  })  : _remote = remote,
        _analytics = analytics,
        _onSignOut = onSignOut;

  final AuthRemoteDataSource _remote;
  final AnalyticsService _analytics;

  /// Callback de limpeza: apaga cache e banco local. Injetado para nao acoplar
  /// a autenticacao ao Hive/SQLite.
  final Future<void> Function() _onSignOut;

  AppUser? _cached;

  @override
  AppUser? get cachedUser => _cached;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _remote.watchCurrentUser().map((AppUser? user) {
      _cached = user;
      unawaited(_identify(user));
      return user;
    });
  }

  Future<void> _identify(AppUser? user) async {
    await AppLogger.setUser(user?.uid);
    await _analytics.setUser(
      uid: user?.uid,
      role: user?.role.name,
      plan: user?.plan.name,
    );
  }

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final AppUser user = await _remote.signInWithEmail(
          email: email,
          password: password,
        );
        _cached = user;
        await _analytics.logEvent(
          AnalyticsEvent.login,
          <String, Object>{'method': 'email'},
        );
        return user;
      });

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) =>
      guard(() async {
        final AppUser user = await _remote.signUpWithEmail(
          email: email,
          password: password,
          name: name,
        );
        _cached = user;
        await _analytics.logEvent(
          AnalyticsEvent.signUp,
          <String, Object>{'method': 'email'},
        );
        return user;
      });

  @override
  Future<Result<AppUser>> signInWithGoogle() => guard(() async {
        final AppUser user = await _remote.signInWithGoogle();
        _cached = user;
        await _analytics.logEvent(
          AnalyticsEvent.login,
          <String, Object>{'method': 'google'},
        );
        return user;
      });

  @override
  Future<Result<void>> signOut() => guard(() async {
        await _analytics.logEvent(AnalyticsEvent.logout);
        await _remote.signOut();
        _cached = null;
        // Dado clinico de uma familia nao pode sobrar no aparelho depois que a
        // sessao acaba — especialmente em celular compartilhado.
        await _onSignOut();
      });

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      guard(() => _remote.sendPasswordReset(email));

  @override
  Future<Result<void>> sendEmailVerification() =>
      guard(_remote.sendEmailVerification);

  @override
  Future<Result<AppUser>> reload() => guard(() async {
        final AppUser user = await _remote.reload();
        _cached = user;
        return user;
      });

  @override
  Future<Result<AppUser>> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    String? specialty,
  }) =>
      guard(() async {
        final AppUser user = await _remote.updateProfile(
          name: name,
          phone: phone,
          photoUrl: photoUrl,
          specialty: specialty,
        );
        _cached = user;
        return user;
      });

  @override
  Future<Result<AppUser>> completeOnboarding({
    required UserRole role,
    String? crm,
    String? specialty,
  }) =>
      guard(() async {
        final AppUser user = await _remote.completeOnboarding(
          role: role,
          crm: crm,
          specialty: specialty,
        );
        _cached = user;
        await _analytics.setUser(uid: user.uid, role: role.name);
        return user;
      });

  @override
  Future<Result<void>> registerDeviceToken(String token) =>
      guard(() => _remote.registerDeviceToken(token));

  @override
  Future<Result<void>> removeDeviceToken(String token) =>
      guard(() => _remote.removeDeviceToken(token));

  @override
  Future<Result<void>> deleteAccount({required String password}) =>
      guard(() async {
        await _remote.deleteAccount(password: password);
        _cached = null;
        await _onSignOut();
      });
}
