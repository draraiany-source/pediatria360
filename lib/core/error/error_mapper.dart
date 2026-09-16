import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Traduz qualquer erro tecnico em uma [Failure] com mensagem em pt-BR.
///
/// Regra do projeto: nenhuma tela conhece `FirebaseException`.
class ErrorMapper {
  const ErrorMapper._();

  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseFunctionsException) return _functions(error);
    if (error is FirebaseException) return _firebase(error);
    if (error is DioException) return _dio(error);
    if (error is SocketException) {
      return NetworkFailure(
        'Sem conexao. Verifique sua internet.',
        'socket',
        error,
      );
    }
    if (error is TimeoutException) {
      return const NetworkFailure(
        'A operacao demorou demais. Tente novamente.',
        'timeout',
      );
    }
    if (error is QuotaExceededException) {
      return QuotaFailure(error.message, error.code, error);
    }
    if (error is CacheException) {
      return CacheFailure(error.message, error.code, error);
    }
    if (error is NetworkException) {
      return NetworkFailure(error.message, error.code, error);
    }
    if (error is AuthException) {
      return AuthFailure(error.message, error.code, error);
    }
    if (error is FileStorageException) {
      return StorageFailure(error.message, error.code, error);
    }
    if (error is AppException) {
      return ServerFailure(error.message, error.code, error);
    }

    return UnexpectedFailure(
      'Algo saiu do esperado. Tente novamente.',
      error.runtimeType.toString(),
      error,
    );
  }

  static Failure _auth(FirebaseAuthException e) {
    final String message = switch (e.code) {
      'invalid-email' => 'E-mail invalido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'E-mail ou senha incorretos.',
      'email-already-in-use' => 'Este e-mail ja esta cadastrado.',
      'weak-password' => 'A senha precisa de pelo menos 8 caracteres.',
      'operation-not-allowed' => 'Este metodo de login esta desativado.',
      'requires-recent-login' => 'Entre novamente para confirmar esta acao.',
      'too-many-requests' =>
        'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
      'network-request-failed' => 'Sem conexao. Verifique sua internet.',
      'account-exists-with-different-credential' =>
        'Este e-mail ja usa outro metodo de login.',
      _ => 'Nao foi possivel autenticar.',
    };
    if (e.code == 'network-request-failed') {
      return NetworkFailure(message, e.code, e);
    }
    return AuthFailure(message, e.code, e);
  }

  static Failure _functions(FirebaseFunctionsException e) {
    return switch (e.code) {
      'unauthenticated' => AuthFailure('Entre para continuar.', e.code, e),
      'permission-denied' => PermissionFailure(
          'Voce nao tem acesso a este recurso.',
          e.code,
          e,
        ),
      'not-found' => NotFoundFailure('Recurso nao encontrado.', e.code, e),
      'resource-exhausted' => QuotaFailure(
          e.message ?? 'Voce atingiu o limite do plano gratuito.',
          e.code,
          e,
        ),
      'invalid-argument' || 'failed-precondition' => ValidationFailure(
          e.message ?? 'Dados invalidos.',
          code: e.code,
          cause: e,
        ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
          'Servico indisponivel no momento. Tente novamente.',
          e.code,
          e,
        ),
      _ => ServerFailure(
          e.message ?? 'Nao foi possivel concluir a operacao.',
          e.code,
          e,
        ),
    };
  }

  static Failure _firebase(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
          'Voce nao tem acesso a este conteudo.',
          e.code,
          e,
        ),
      'not-found' || 'object-not-found' => NotFoundFailure(
          'Conteudo nao encontrado.',
          e.code,
          e,
        ),
      'unavailable' => NetworkFailure(
          'Sem conexao com o servidor. Mostrando dados salvos.',
          e.code,
          e,
        ),
      'canceled' => const ServerFailure('Operacao cancelada.', 'canceled'),
      'quota-exceeded' => QuotaFailure(
          'Limite de armazenamento atingido.',
          e.code,
          e,
        ),
      'unauthorized' => PermissionFailure(
          'Sem permissao para acessar este arquivo.',
          e.code,
          e,
        ),
      _ when e.plugin == 'firebase_storage' => StorageFailure(
          'Falha ao transferir o arquivo.',
          e.code,
          e,
        ),
      _ => ServerFailure(
          e.message ?? 'Nao foi possivel concluir a operacao.',
          e.code,
          e,
        ),
    };
  }

  static Failure _dio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkFailure(
          'A conexao demorou demais. Tente novamente.',
          'timeout',
        ),
      DioExceptionType.connectionError => const NetworkFailure(
          'Sem conexao. Verifique sua internet.',
          'connection-error',
        ),
      DioExceptionType.badResponse => _fromStatus(
          e.response?.statusCode ?? 0,
          e,
        ),
      DioExceptionType.cancel => const ServerFailure(
          'Operacao cancelada.',
          'cancel',
        ),
      _ => UnexpectedFailure('Falha na comunicacao.', 'dio', e),
    };
  }

  static Failure _fromStatus(int status, Object cause) {
    if (status == 401 || status == 403) {
      return PermissionFailure(
        'Acesso negado pelo servidor de midia.',
        '$status',
        cause,
      );
    }
    if (status == 404) {
      return NotFoundFailure('Midia nao encontrada.', '$status', cause);
    }
    if (status == 429) {
      return QuotaFailure(
        'Muitas requisicoes. Aguarde alguns instantes.',
        '$status',
        cause,
      );
    }
    if (status >= 500) {
      return ServerFailure(
        'O servidor esta instavel. Tente novamente.',
        '$status',
        cause,
      );
    }
    return ServerFailure('Requisicao invalida.', '$status', cause);
  }
}
