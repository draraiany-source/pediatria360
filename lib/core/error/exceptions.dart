/// Excecoes tecnicas lancadas pelas data sources.
///
/// Ficam confinadas a camada de dados: o repositorio as converte em `Failure`.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.cause});
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Sem conexao com a internet.',
  ]);
}

class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.cause});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

class FileStorageException extends AppException {
  const FileStorageException(super.message, {super.code, super.cause});
}

class QuotaExceededException extends AppException {
  const QuotaExceededException(super.message, {super.code, super.cause});
}
