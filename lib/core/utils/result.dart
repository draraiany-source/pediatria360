import '../error/error_mapper.dart';
import '../error/failures.dart';

/// Resultado de uma operacao: sucesso com valor ou falha de dominio.
///
/// Substitui `dartz`/`fpdart` por um sealed class nativo — menos dependencia,
/// exhaustividade garantida pelo compilador no `switch`.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  /// Valor, ou `null` se falhou.
  T? get valueOrNull => switch (this) {
        Success<T>(:final T value) => value,
        FailureResult<T>() => null,
      };

  /// Falha, ou `null` se deu certo.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(:final Failure failure) => failure,
      };

  R fold<R>(
    R Function(T value) onSuccess,
    R Function(Failure failure) onFailure,
  ) =>
      switch (this) {
        Success<T>(:final T value) => onSuccess(value),
        FailureResult<T>(:final Failure failure) => onFailure(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final T value) => Result<R>.success(transform(value)),
        FailureResult<T>(:final Failure failure) => Result<R>.failure(failure),
      };

  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) transform,
  ) async =>
      switch (this) {
        Success<T>(:final T value) => await transform(value),
        FailureResult<T>(:final Failure failure) => Result<R>.failure(failure),
      };

  /// Executa [action] apenas em caso de sucesso.
  Result<T> onSuccess(void Function(T value) action) {
    if (this case Success<T>(:final T value)) action(value);
    return this;
  }

  /// Executa [action] apenas em caso de falha.
  Result<T> onFailure(void Function(Failure failure) action) {
    if (this case FailureResult<T>(:final Failure failure)) action(failure);
    return this;
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

/// Envolve um bloco assincrono convertendo qualquer excecao em [Failure].
///
/// Uso tipico dentro de um repositorio:
/// ```dart
/// return guard(() async => UserMapper.toEntity(await remote.fetch(uid)));
/// ```
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Result<T>.success(await body());
  } catch (error, stackTrace) {
    return Result<T>.failure(ErrorMapper.map(error, stackTrace));
  }
}

/// Versao sincrona de [guard].
Result<T> guardSync<T>(T Function() body) {
  try {
    return Result<T>.success(body());
  } catch (error, stackTrace) {
    return Result<T>.failure(ErrorMapper.map(error, stackTrace));
  }
}
