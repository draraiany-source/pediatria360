import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/content.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/library_repository.dart';

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>(
  (Ref ref) => LibraryRepository(
    firestore: ref.watch(firestoreProvider),
    cache: ref.watch(cacheServiceProvider),
  ),
);

/// Filtro ativo da biblioteca.
class LibraryFilter {
  const LibraryFilter({this.category, this.type});

  final String? category;
  final ContentType? type;

  LibraryFilter copyWith({
    String? category,
    ContentType? type,
    bool clearCategory = false,
    bool clearType = false,
  }) =>
      LibraryFilter(
        category: clearCategory ? null : (category ?? this.category),
        type: clearType ? null : (type ?? this.type),
      );

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.category == category &&
      other.type == type;

  @override
  int get hashCode => Object.hash(category, type);
}

final NotifierProvider<LibraryFilterController, LibraryFilter>
    libraryFilterProvider =
    NotifierProvider<LibraryFilterController, LibraryFilter>(
  LibraryFilterController.new,
);

class LibraryFilterController extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setCategory(String? category) => state = category == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(category: category);

  void setType(ContentType? type) => state = type == null
      ? state.copyWith(clearType: true)
      : state.copyWith(type: type);

  void clear() => state = const LibraryFilter();
}

/// Estado da listagem paginada.
class LibraryState {
  const LibraryState({
    this.items = const <Content>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.cursor,
    this.failure,
    this.fromCache = false,
  });

  final List<Content> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? cursor;
  final Failure? failure;

  /// `true` quando o que está na tela veio do cache e a rede ainda não
  /// respondeu — a UI mostra isso discretamente.
  final bool fromCache;

  bool get isEmpty => items.isEmpty && !isLoading;

  LibraryState copyWith({
    List<Content>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? cursor,
    Failure? failure,
    bool? fromCache,
    bool clearFailure = false,
  }) =>
      LibraryState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        cursor: cursor ?? this.cursor,
        failure: clearFailure ? null : (failure ?? this.failure),
        fromCache: fromCache ?? this.fromCache,
      );
}

/// Lista da biblioteca, com scroll infinito.
class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    // Refaz a consulta quando o filtro ou o usuário muda (o papel altera o
    // que pode ser lido).
    ref.watch(libraryFilterProvider);
    ref.watch(currentUserProvider);

    Future<void>.microtask(load);
    return const LibraryState(isLoading: true);
  }

  Future<void> load() async {
    final LibraryFilter filter = ref.read(libraryFilterProvider);
    final LibraryRepository repository = ref.read(libraryRepositoryProvider);
    final AppUser? user = ref.read(currentUserProvider);

    // Pinta com o cache antes de esperar a rede.
    final List<Content> cached = repository.cachedList(
      category: filter.category,
      type: filter.type,
    );
    if (cached.isNotEmpty) {
      state = state.copyWith(
        items: cached,
        isLoading: false,
        fromCache: true,
        clearFailure: true,
      );
    } else {
      state = const LibraryState(isLoading: true);
    }

    final Result<Paginated<Content>> result = await repository.list(
      user: user,
      category: filter.category,
      type: filter.type,
    );

    state = result.fold(
      (Paginated<Content> page) => LibraryState(
        items: page.items,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
      ),
      (Failure failure) => state.copyWith(
        isLoading: false,
        // Com cache na tela, a falha de rede não apaga o que o usuário já lê.
        failure: state.items.isEmpty ? failure : null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoadingMore: true);

    final LibraryFilter filter = ref.read(libraryFilterProvider);
    final Result<Paginated<Content>> result =
        await ref.read(libraryRepositoryProvider).list(
              user: ref.read(currentUserProvider),
              category: filter.category,
              type: filter.type,
              cursor: state.cursor,
            );

    state = result.fold(
      (Paginated<Content> page) => state.copyWith(
        items: <Content>[...state.items, ...page.items],
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        isLoadingMore: false,
        fromCache: false,
      ),
      (Failure failure) =>
          state.copyWith(isLoadingMore: false, failure: failure),
    );
  }

  Future<void> refresh() => load();
}

final NotifierProvider<LibraryController, LibraryState> libraryProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

/// Busca textual. `family` sobre o termo para o Riverpod cachear por consulta.
final FutureProviderFamily<List<Content>, String> librarySearchProvider =
    FutureProvider.family<List<Content>, String>((Ref ref, String query) async {
  if (query.trim().length < 3) return const <Content>[];

  ref.read(analyticsProvider).logSearch(query, area: 'biblioteca');

  final Result<List<Content>> result =
      await ref.read(libraryRepositoryProvider).search(
            user: ref.read(currentUserProvider),
            query: query,
          );

  return result.fold(
    (List<Content> items) => items,
    (Failure failure) => throw failure,
  );
});

/// Documento único, com queda para o cache quando offline.
final FutureProviderFamily<Content, String> contentProvider =
    FutureProvider.family<Content, String>((Ref ref, String id) async {
  final LibraryRepository repository = ref.read(libraryRepositoryProvider);

  final Result<Content> result = await repository.byId(id);

  return result.fold(
    (Content content) {
      ref.read(analyticsProvider).logEvent(
        AnalyticsEvent.protocolOpened,
        <String, Object>{'content_id': id, 'type': content.type.name},
      );
      return content;
    },
    (Failure failure) {
      final Content? cached = repository.cachedById(id);
      if (cached != null) return cached;
      throw failure;
    },
  );
});
