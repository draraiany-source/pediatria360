import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:equatable/equatable.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/models/content_model.dart';
import '../../../shared/domain/entities/content.dart';

/// Uma versão salva de um conteúdo.
///
/// ## Por que versionar
///
/// Um protocolo clínico publicado com a informação errada não é um bug de
/// software — é orientação errada chegando a uma família às 3 da manhã. O
/// caminho de volta precisa ser imediato: um toque, sem depender de backup do
/// banco nem de quem lembra o texto anterior.
///
/// Cada publicação grava um instantâneo completo. Espaço é barato; reconstruir
/// um protocolo de memória, não.
class ContentVersion extends Equatable {
  const ContentVersion({
    required this.id,
    required this.contentId,
    required this.version,
    required this.title,
    required this.snapshot,
    required this.createdAt,
    required this.authorUid,
    this.authorName,
    this.note,
    this.published = false,
  });

  factory ContentVersion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String contentId,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return ContentVersion(
      id: doc.id,
      contentId: contentId,
      version: (data['version'] as num?)?.toInt() ?? 1,
      title: (data['title'] as String?) ?? '',
      snapshot: Map<String, dynamic>.from(
        (data['snapshot'] as Map<dynamic, dynamic>?) ??
            const <dynamic, dynamic>{},
      ),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: data['authorName'] as String?,
      note: data['note'] as String?,
      published: (data['published'] as bool?) ?? false,
    );
  }

  final String id;
  final String contentId;
  final int version;
  final String title;

  /// O documento inteiro como estava. Restaurar é copiar isto de volta.
  final Map<String, dynamic> snapshot;

  final DateTime createdAt;
  final String authorUid;
  final String? authorName;

  /// Motivo da alteração, escrito por quem publicou. Obrigatório na tela —
  /// "atualizei o texto" não ajuda ninguém seis meses depois.
  final String? note;

  /// `true` se esta é a versão que está no ar.
  final bool published;

  Content toContent() => ContentMapper.fromMap(contentId, snapshot);

  @override
  List<Object?> get props => <Object?>[id, version, published];
}

/// Diferença entre duas versões, para a tela de comparação.
class VersionDiff {
  const VersionDiff({
    required this.changedFields,
    required this.sectionsAdded,
    required this.sectionsRemoved,
    required this.sectionsChanged,
  });

  final List<String> changedFields;
  final List<String> sectionsAdded;
  final List<String> sectionsRemoved;
  final List<String> sectionsChanged;

  bool get isEmpty =>
      changedFields.isEmpty &&
      sectionsAdded.isEmpty &&
      sectionsRemoved.isEmpty &&
      sectionsChanged.isEmpty;

  int get totalChanges =>
      changedFields.length +
      sectionsAdded.length +
      sectionsRemoved.length +
      sectionsChanged.length;

  /// Compara dois instantâneos.
  ///
  /// Comparação por campo e por título de seção — não diff de texto caractere
  /// a caractere. Quem revisa um protocolo quer saber *o que* mudou ("a seção
  /// de sinais de alarme foi alterada"), não onde caiu uma vírgula.
  static VersionDiff between(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    const List<String> tracked = <String>[
      'title',
      'summary',
      'category',
      'audience',
      'type',
      'readMinutes',
      'reviewedBy',
      'published',
    ];

    final List<String> changed = <String>[];
    for (final String field in tracked) {
      if (before[field]?.toString() != after[field]?.toString()) {
        changed.add(_fieldLabel(field));
      }
    }

    Map<String, String> sectionsOf(Map<String, dynamic> map) {
      final List<dynamic> raw =
          (map['sections'] as List<dynamic>?) ?? const <dynamic>[];
      return <String, String>{
        for (final dynamic s in raw.whereType<Map<dynamic, dynamic>>())
          (s['title'] as String?) ?? '': (s['body'] as String?) ?? '',
      };
    }

    final Map<String, String> beforeSections = sectionsOf(before);
    final Map<String, String> afterSections = sectionsOf(after);

    final List<String> added = afterSections.keys
        .where((String k) => !beforeSections.containsKey(k))
        .toList(growable: false);

    final List<String> removed = beforeSections.keys
        .where((String k) => !afterSections.containsKey(k))
        .toList(growable: false);

    final List<String> modified = afterSections.keys
        .where(
          (String k) =>
              beforeSections.containsKey(k) &&
              beforeSections[k] != afterSections[k],
        )
        .toList(growable: false);

    return VersionDiff(
      changedFields: changed,
      sectionsAdded: added,
      sectionsRemoved: removed,
      sectionsChanged: modified,
    );
  }

  static String _fieldLabel(String field) => switch (field) {
        'title' => 'Título',
        'summary' => 'Resumo',
        'category' => 'Categoria',
        'audience' => 'Público',
        'type' => 'Tipo',
        'readMinutes' => 'Tempo de leitura',
        'reviewedBy' => 'Revisor',
        'published' => 'Publicação',
        _ => field,
      };
}

/// Operações de edição de conteúdo, restritas a admin.
///
/// A escrita passa por Cloud Function, não direto no Firestore. Duas razões:
/// o instantâneo de versão precisa ser gravado na mesma transação da
/// publicação (senão uma falha deixa conteúdo no ar sem histórico), e os
/// termos de busca são regenerados no servidor.
class AdminContentRepository {
  const AdminContentRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Todos os conteúdos, inclusive rascunhos.
  Stream<List<Content>> watchAll() => _firestore
      .collection(FirestorePaths.articles)
      .orderBy('updatedAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(ContentMapper.fromFirestore).toList(growable: false),
      );

  /// Histórico de um conteúdo, da versão mais nova para a mais antiga.
  Stream<List<ContentVersion>> watchVersions(String contentId) => _firestore
      .collection(FirestorePaths.articles)
      .doc(contentId)
      .collection('versions')
      .orderBy('version', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  ContentVersion.fromFirestore(d, contentId),
            )
            .toList(growable: false),
      );

  /// Salva e publica, gravando o instantâneo da versão.
  Future<Result<String>> save({
    String? contentId,
    required Map<String, dynamic> data,
    required String note,
    required bool publish,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response =
            await _functions.httpsCallable('saveContent').call(
          <String, dynamic>{
            if (contentId != null) 'contentId': contentId,
            'data': data,
            'note': note,
            'publish': publish,
          },
        );

        final Map<String, dynamic> result =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);
        return (result['contentId'] as String?) ?? '';
      });

  /// Volta para uma versão anterior.
  ///
  /// A restauração cria uma versão **nova** com o conteúdo antigo, em vez de
  /// apagar o histórico. O caminho de volta também precisa ser auditável.
  Future<Result<void>> restore({
    required String contentId,
    required String versionId,
    required String note,
  }) =>
      guard(() async {
        await _functions.httpsCallable('restoreContentVersion').call(
          <String, dynamic>{
            'contentId': contentId,
            'versionId': versionId,
            'note': note,
          },
        );
      });

  /// Tira do ar sem apagar. Despublicar é reversível; excluir não.
  Future<Result<void>> unpublish(String contentId) => guard(() async {
        await _functions.httpsCallable('saveContent').call(
          <String, dynamic>{
            'contentId': contentId,
            'data': <String, dynamic>{'published': false},
            'note': 'Retirado do ar',
            'publish': false,
            'partial': true,
          },
        );
      });
}
