import 'package:equatable/equatable.dart';

import '../utils/result.dart';

/// Caso de uso assincrono que recebe [Params] e devolve [T].
abstract class UseCase<T, Params> {
  const UseCase();

  Future<Result<T>> call(Params params);
}

/// Caso de uso que expoe um fluxo continuo (ex.: `watchChildren`).
abstract class StreamUseCase<T, Params> {
  const StreamUseCase();

  Stream<Result<T>> call(Params params);
}

/// Marcador para casos de uso sem parametros.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => <Object?>[];
}

/// Parametros de paginacao reutilizaveis.
class PageParams extends Equatable {
  const PageParams({
    this.limit = 20,
    this.cursor,
    this.query,
  });

  final int limit;

  /// Identificador do ultimo documento carregado (cursor do Firestore).
  final String? cursor;

  /// Termo de busca opcional.
  final String? query;

  PageParams copyWith({int? limit, String? cursor, String? query}) => PageParams(
        limit: limit ?? this.limit,
        cursor: cursor ?? this.cursor,
        query: query ?? this.query,
      );

  @override
  List<Object?> get props => <Object?>[limit, cursor, query];
}

/// Pagina generica devolvida pelos repositorios paginados.
class Paginated<T> extends Equatable {
  const Paginated({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  const Paginated.empty()
      : items = const <Never>[],
        hasMore = false,
        nextCursor = null;

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;

  Paginated<T> merge(Paginated<T> next) => Paginated<T>(
        items: <T>[...items, ...next.items],
        hasMore: next.hasMore,
        nextCursor: next.nextCursor,
      );

  @override
  List<Object?> get props => <Object?>[items, hasMore, nextCursor];
}
