import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:equatable/equatable.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/result.dart';

/// Quem escreveu a mensagem.
enum MessageRole { user, assistant }

/// Uma fonte citada pela IA.
///
/// Toda resposta clínica precisa apontar de onde veio. Sem isso, a IA vira
/// oráculo — e o responsável não tem como levar a informação ao pediatra para
/// conferir.
class MessageSource extends Equatable {
  const MessageSource({
    required this.title,
    this.contentId,
    this.excerpt,
  });

  factory MessageSource.fromMap(Map<String, dynamic> map) => MessageSource(
        title: (map['title'] as String?) ?? '',
        contentId: map['contentId'] as String?,
        excerpt: map['excerpt'] as String?,
      );

  final String title;

  /// Id do documento na biblioteca, quando a fonte é interna — permite abrir
  /// o protocolo completo com um toque.
  final String? contentId;

  final String? excerpt;

  @override
  List<Object?> get props => <Object?>[title, contentId];
}

/// Mensagem de uma conversa com a IA.
class AiMessage extends Equatable {
  const AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.sources = const <MessageSource>[],
    this.isStreaming = false,
    this.failed = false,
  });

  factory AiMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return AiMessage(
      id: doc.id,
      role: (data['role'] as String?) == 'assistant'
          ? MessageRole.assistant
          : MessageRole.user,
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sources: ((data['sources'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                MessageSource.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final List<MessageSource> sources;

  /// `true` enquanto a resposta ainda está sendo gerada.
  final bool isStreaming;

  final bool failed;

  bool get isUser => role == MessageRole.user;

  AiMessage copyWith({
    String? text,
    List<MessageSource>? sources,
    bool? isStreaming,
    bool? failed,
  }) =>
      AiMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        sources: sources ?? this.sources,
        isStreaming: isStreaming ?? this.isStreaming,
        failed: failed ?? this.failed,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, role, text, createdAt, isStreaming, failed];
}

/// Uma conversa.
class AiConversation extends Equatable {
  const AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.childId,
    this.messageCount = 0,
  });

  factory AiConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return AiConversation(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Nova conversa',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      childId: data['childId'] as String?,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final DateTime updatedAt;

  /// Conversa vinculada a uma criança: a IA recebe idade e alergias como
  /// contexto, o que muda materialmente a resposta.
  final String? childId;

  final int messageCount;

  @override
  List<Object?> get props => <Object?>[id, title, updatedAt, messageCount];
}

/// Cota diária de uso da IA.
class AiQuota extends Equatable {
  const AiQuota({
    required this.used,
    required this.limit,
    required this.unlimited,
  });

  final int used;
  final int limit;
  final bool unlimited;

  int get remaining => unlimited ? 9999 : (limit - used).clamp(0, limit);
  bool get exhausted => !unlimited && remaining <= 0;

  @override
  List<Object?> get props => <Object?>[used, limit, unlimited];
}

/// Acesso à IA pediátrica.
///
/// ## Por que tudo passa por Cloud Function
///
/// A chave do provedor de IA **nunca** chega ao aplicativo. Um app publicado é
/// código aberto na prática: qualquer pessoa extrai uma chave embutida em
/// minutos e a usa até estourar a fatura. Além disso, o servidor é o único
/// lugar onde dá para aplicar cota, montar o prompt de sistema com os
/// protocolos revisados e registrar o que foi perguntado — nada disso é
/// confiável se rodar no cliente.
class AiRepository {
  const AiRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
  })  : _functions = functions,
        _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection(FirestorePaths.aiConversations);

  /// Conversas do usuário, mais recentes primeiro.
  Stream<List<AiConversation>> watchConversations(String uid) => _conversations
      .where('ownerId', isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(AiConversation.fromFirestore)
            .toList(growable: false),
      );

  /// Mensagens de uma conversa, em tempo real.
  ///
  /// `limitToLast` em vez de `limit`: a ordenação é crescente por data, então
  /// "as últimas 500" são as mais recentes — exatamente o que uma tela de
  /// chat precisa mostrar, mesmo que a conversa tenha crescido além disso.
  /// Sem limite, uma conversa longa faria o listener resssincronizar o
  /// histórico inteiro a cada mensagem nova, para sempre.
  Stream<List<AiMessage>> watchMessages(String conversationId) => _firestore
      .collection(FirestorePaths.conversationMessages(conversationId))
      .orderBy('createdAt')
      .limitToLast(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(AiMessage.fromFirestore).toList(growable: false),
      );

  /// Envia uma pergunta.
  ///
  /// A função `aiChat` grava a pergunta e a resposta no Firestore; o app não
  /// escreve nada nessa collection — o que evita que alguém forje uma resposta
  /// "da IA" editando o documento direto.
  Future<Result<AiAnswer>> ask({
    required String question,
    String? conversationId,
    String? childId,
  }) =>
      guard(() async {
        final HttpsCallable callable = _functions.httpsCallable(
          'aiChat',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 90),
          ),
        );

        final HttpsCallableResult<dynamic> response = await callable.call(
          <String, dynamic>{
            'question': question,
            if (conversationId != null) 'conversationId': conversationId,
            if (childId != null) 'childId': childId,
          },
        );

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        if (data['error'] != null) {
          throw ServerException(data['error'] as String);
        }

        return AiAnswer(
          conversationId: (data['conversationId'] as String?) ?? '',
          messageId: (data['messageId'] as String?) ?? '',
          text: (data['answer'] as String?) ?? '',
          sources: ((data['sources'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (Map<dynamic, dynamic> m) =>
                    MessageSource.fromMap(Map<String, dynamic>.from(m)),
              )
              .toList(growable: false),
          quota: AiQuota(
            used: (data['quotaUsed'] as num?)?.toInt() ?? 0,
            limit: (data['quotaLimit'] as num?)?.toInt() ?? 0,
            unlimited: (data['quotaUnlimited'] as bool?) ?? false,
          ),
          escalate: (data['escalate'] as bool?) ?? false,
        );
      });

  /// Cota do dia. Lida do documento que a função mantém.
  Future<Result<AiQuota>> quota(String uid) => guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
            .collection(FirestorePaths.users)
            .doc(uid)
            .collection('ai_usage')
            .doc(_todayKey())
            .get();

        final Map<String, dynamic> data =
            doc.data() ?? const <String, dynamic>{};

        return AiQuota(
          used: (data['count'] as num?)?.toInt() ?? 0,
          limit: (data['limit'] as num?)?.toInt() ?? 10,
          unlimited: (data['unlimited'] as bool?) ?? false,
        );
      });

  static String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<Result<void>> deleteConversation(String conversationId) =>
      guard(() async {
        // Apagar subcollection exige privilégio de admin; a função cuida disso.
        await _functions
            .httpsCallable('deleteConversation')
            .call(<String, dynamic>{'conversationId': conversationId});
      });
}

/// Resposta completa de uma pergunta.
class AiAnswer {
  const AiAnswer({
    required this.conversationId,
    required this.messageId,
    required this.text,
    required this.sources,
    required this.quota,
    this.escalate = false,
  });

  final String conversationId;
  final String messageId;
  final String text;
  final List<MessageSource> sources;
  final AiQuota quota;

  /// `true` quando o servidor detectou sinal de alarme na pergunta e a resposta
  /// orienta procurar atendimento. A tela destaca isso em vermelho.
  final bool escalate;
}
