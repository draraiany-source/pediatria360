import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/models/content_model.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/content.dart';

/// Acesso à biblioteca médica.
///
/// ## Filtragem por público
///
/// O filtro de audiência é aplicado **na consulta**, não só na tela. Se um pai
/// abrir o app, um protocolo com posologia nem chega ao dispositivo. Isso
/// depende das regras do Firestore para valer de verdade (Módulo 7) — o filtro
/// no cliente é conveniência, a regra é a garantia.
///
/// ## Cache
///
/// A primeira página de cada categoria é cacheada no Hive por 6 horas. Conteúdo
/// médico não muda de hora em hora, e o ganho é grande: a biblioteca abre
/// instantânea e continua legível no metrô sem sinal.
class LibraryRepository {
  const LibraryRepository({
    required FirebaseFirestore firestore,
    required CacheService cache,
  })  : _firestore = firestore,
        _cache = cache;

  final FirebaseFirestore _firestore;
  final CacheService _cache;

  static const String _cachePrefix = 'library:';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.articles);

  /// Públicos que um usuário pode ver, dado seu papel.
  ///
  /// Profissional **não verificado** não recebe conteúdo restrito: o registro
  /// declarado no cadastro não vale como credencial até a conferência.
  static List<String> audiencesFor(AppUser? user) {
    if (user == null) {
      return <String>[ContentAudience.everyone.name];
    }
    if (user.canPrescribe) {
      return ContentAudience.values
          .map((ContentAudience a) => a.name)
          .toList(growable: false);
    }
    return <String>[
      ContentAudience.everyone.name,
      ContentAudience.parents.name,
    ];
  }

  /// Lista paginada, opcionalmente filtrada por categoria e tipo.
  Future<Result<Paginated<Content>>> list({
    required AppUser? user,
    String? category,
    ContentType? type,
    String? cursor,
    int limit = AppConfig.defaultPageSize,
  }) =>
      guard(() async {
        final String cacheKey =
            '$_cachePrefix${category ?? 'all'}:${type?.name ?? 'all'}';

        Query<Map<String, dynamic>> query = _collection
            .where('published', isEqualTo: true)
            .where('audience', whereIn: audiencesFor(user));

        if (category != null) {
          query = query.where('category', isEqualTo: category);
        }
        if (type != null) {
          query = query.where('type', isEqualTo: type.name);
        }

        query = query.orderBy('updatedAt', descending: true).limit(limit);

        if (cursor != null) {
          final DocumentSnapshot<Map<String, dynamic>> anchor =
              await _collection.doc(cursor).get();
          if (anchor.exists) query = query.startAfterDocument(anchor);
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        final List<Content> items = snapshot.docs
            .map(ContentMapper.fromFirestore)
            .toList(growable: false);

        // Só a primeira página entra no cache: é a que abre a tela.
        if (cursor == null) {
          await _cache.write(
            cacheKey,
            items.map(ContentMapper.toCacheMap).toList(growable: false),
            ttl: AppConfig.cacheTtlMedium,
          );
        }

        return Paginated<Content>(
          items: items,
          hasMore: items.length == limit,
          nextCursor: items.isEmpty ? null : items.last.id,
        );
      });

  /// Primeira página vinda do cache, para pintar a tela antes da rede.
  List<Content> cachedList({String? category, ContentType? type}) {
    final String cacheKey =
        '$_cachePrefix${category ?? 'all'}:${type?.name ?? 'all'}';
    return _cache
        .readList(cacheKey)
        .map(ContentMapper.fromCacheMap)
        .toList(growable: false);
  }

  /// Busca por termos.
  ///
  /// `array-contains-any` aceita no máximo 10 valores e não combina com
  /// `whereIn` em outro campo na mesma consulta — por isso a audiência é
  /// filtrada depois, em memória. Para um catálogo desta ordem de grandeza o
  /// custo é irrelevante; se a biblioteca crescer muito, o caminho é um índice
  /// de busca dedicado.
  Future<Result<List<Content>>> search({
    required AppUser? user,
    required String query,
    int limit = 30,
  }) =>
      guard(() async {
        final List<String> tokens = searchTokens(query);
        if (tokens.isEmpty) return const <Content>[];

        final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
            .where('published', isEqualTo: true)
            .where('searchTerms', arrayContainsAny: tokens)
            .limit(limit)
            .get();

        final List<String> allowed = audiencesFor(user);

        final List<Content> results = snapshot.docs
            .map(ContentMapper.fromFirestore)
            .where((Content c) => allowed.contains(c.audience.name))
            .toList();

        // Ordena por quantos termos da busca o documento cobre — um resultado
        // que casa "febre" e "bebe" vem antes do que casa só "febre".
        results.sort((Content a, Content b) {
          final int scoreA = _score(a, tokens);
          final int scoreB = _score(b, tokens);
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return b.updatedAt.compareTo(a.updatedAt);
        });

        return results;
      });

  static int _score(Content content, List<String> tokens) {
    int score = 0;
    final String normalizedTitle = normalizeForSearch(content.title);
    for (final String token in tokens) {
      if (content.searchTerms.contains(token)) score++;
      // Casar no título vale mais que casar no corpo.
      if (normalizedTitle.contains(token)) score += 2;
    }
    return score;
  }

  Future<Result<Content>> byId(String id) => guard(() async {
        final String cacheKey = '$_cachePrefix doc:$id';

        final Map<String, dynamic>? cached = _cache.readMap(cacheKey);

        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _collection.doc(id).get();

        if (!doc.exists) {
          if (cached != null) return ContentMapper.fromCacheMap(cached);
          throw StateError('Conteúdo não encontrado.');
        }

        final Content content = ContentMapper.fromFirestore(doc);
        await _cache.write(
          cacheKey,
          ContentMapper.toCacheMap(content),
          ttl: AppConfig.cacheTtlLong,
        );
        return content;
      });

  /// Documento cacheado, disponível offline.
  Content? cachedById(String id) {
    final Map<String, dynamic>? cached = _cache.readMap('$_cachePrefix doc:$id');
    return cached == null ? null : ContentMapper.fromCacheMap(cached);
  }
}
