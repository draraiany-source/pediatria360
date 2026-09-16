import 'package:equatable/equatable.dart';

/// Falha de dominio: o que a camada de apresentacao consegue exibir.
///
/// Excecoes tecnicas nunca cruzam a fronteira do repositorio; sao traduzidas
/// para [Failure] pelo `ErrorMapper`.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code, this.cause});

  /// Mensagem pronta para o usuario, em pt-BR, sem jargao tecnico.
  final String message;

  /// Codigo tecnico de origem (ex.: `permission-denied`).
  final String? code;

  /// Erro original, util para o Crashlytics.
  final Object? cause;

  @override
  List<Object?> get props => <Object?>[message, code];

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// Sem conexao, timeout ou DNS.
class NetworkFailure extends Failure {
  const NetworkFailure([
    String message =
        'Sem conexao. Os dados mostrados podem estar desatualizados.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Falha do servidor, do Firestore ou das Cloud Functions.
class ServerFailure extends Failure {
  const ServerFailure([
    String message = 'Nao foi possivel concluir. Tente novamente em instantes.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Falha de autenticacao.
class AuthFailure extends Failure {
  const AuthFailure([
    String message = 'Nao foi possivel autenticar.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Usuario autenticado, mas sem permissao para a operacao.
class PermissionFailure extends Failure {
  const PermissionFailure([
    String message = 'Voce nao tem acesso a este conteudo.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Recurso inexistente.
class NotFoundFailure extends Failure {
  const NotFoundFailure([
    String message = 'Conteudo nao encontrado.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Dados invalidos enviados pelo usuario.
///
/// Carrega [fieldErrors] para que o formulario destaque o campo exato em vez
/// de mostrar um alerta generico no topo.
class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const <String, String>{},
    super.code,
    super.cause,
  });

  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => <Object?>[message, code, fieldErrors];
}

/// Falha no cache local (Hive/SQLite).
class CacheFailure extends Failure {
  const CacheFailure([
    String message = 'Nao foi possivel ler os dados salvos no aparelho.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Falha em upload ou download de midia.
class StorageFailure extends Failure {
  const StorageFailure([
    String message = 'Falha ao transferir o arquivo.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Limite de uso atingido (ex.: mensagens gratuitas da IA no dia).
class QuotaFailure extends Failure {
  const QuotaFailure([
    String message = 'Voce atingiu o limite do plano gratuito.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}

/// Falha desconhecida.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    String message = 'Algo saiu do esperado. Tente novamente.',
    String? code,
    Object? cause,
  ]) : super(message, code: code, cause: cause);
}
