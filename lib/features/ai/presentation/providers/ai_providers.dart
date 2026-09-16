import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/ai_repository.dart';

final Provider<AiRepository> aiRepositoryProvider = Provider<AiRepository>(
  (Ref ref) => AiRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

final FutureProvider<AiQuota> aiQuotaProvider =
    FutureProvider<AiQuota>((Ref ref) async {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return const AiQuota(used: 0, limit: 0, unlimited: false);
  }

  final Result<AiQuota> result =
      await ref.watch(aiRepositoryProvider).quota(uid);
  return result.valueOrNull ??
      const AiQuota(used: 0, limit: 10, unlimited: false);
});

/// Estado de uma conversa em andamento.
class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const <AiMessage>[],
    this.isSending = false,
    this.failure,
    this.childId,
  });

  final String? conversationId;
  final List<AiMessage> messages;
  final bool isSending;
  final Failure? failure;

  /// Criança vinculada: a IA recebe idade, alergias e prematuridade como
  /// contexto, o que muda materialmente a resposta.
  final String? childId;

  ChatState copyWith({
    String? conversationId,
    List<AiMessage>? messages,
    bool? isSending,
    Failure? failure,
    String? childId,
    bool clearFailure = false,
    bool clearChild = false,
  }) =>
      ChatState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
        failure: clearFailure ? null : (failure ?? this.failure),
        childId: clearChild ? null : (childId ?? this.childId),
      );
}

/// Controla uma conversa.
///
/// As mensagens do usuário aparecem na hora (otimista) — esperar o servidor
/// para ver a própria pergunta na tela parece travamento. A resposta da IA só
/// aparece quando chega de verdade, com um indicador enquanto isso.
class ChatController extends AutoDisposeNotifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  void attachChild(String? childId) => state = childId == null
      ? state.copyWith(clearChild: true)
      : state.copyWith(childId: childId);

  void loadConversation(String conversationId) {
    state = ChatState(conversationId: conversationId);

    ref.listen<AsyncValue<List<AiMessage>>>(
      _messagesProvider(conversationId),
      (AsyncValue<List<AiMessage>>? _, AsyncValue<List<AiMessage>> next) {
        final List<AiMessage>? messages = next.valueOrNull;
        if (messages != null && !state.isSending) {
          state = state.copyWith(messages: messages);
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> send(String question) async {
    final String trimmed = question.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final AiMessage optimistic = AiMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: <AiMessage>[...state.messages, optimistic],
      isSending: true,
      clearFailure: true,
    );

    ref.read(analyticsProvider).logEvent(
      AnalyticsEvent.aiMessageSent,
      <String, Object>{'has_child_context': state.childId != null},
    );

    final Result<AiAnswer> result = await ref.read(aiRepositoryProvider).ask(
          question: trimmed,
          conversationId: state.conversationId,
          childId: state.childId,
        );

    state = result.fold(
      (AiAnswer answer) {
        ref.invalidate(aiQuotaProvider);
        return state.copyWith(
          conversationId: answer.conversationId,
          isSending: false,
          messages: <AiMessage>[
            ...state.messages,
            AiMessage(
              id: answer.messageId,
              role: MessageRole.assistant,
              text: answer.text,
              createdAt: DateTime.now(),
              sources: answer.sources,
            ),
          ],
        );
      },
      (Failure failure) => state.copyWith(
        isSending: false,
        failure: failure,
        // A pergunta fica na tela marcada como falha: o usuário reenvia sem
        // ter que digitar de novo.
        messages: <AiMessage>[
          ...state.messages.take(state.messages.length - 1),
          optimistic.copyWith(failed: true),
        ],
      ),
    );
  }

  /// Reenvia a última pergunta que falhou.
  Future<void> retryLast() async {
    final AiMessage? last =
        state.messages.isEmpty ? null : state.messages.last;
    if (last == null || !last.failed) return;

    state = state.copyWith(
      messages: state.messages.take(state.messages.length - 1).toList(),
    );
    await send(last.text);
  }

  void reset() => state = ChatState(childId: state.childId);
}

final AutoDisposeStreamProviderFamily<List<AiMessage>, String>
    _messagesProvider = StreamProvider.autoDispose.family<List<AiMessage>, String>(
  (Ref ref, String conversationId) =>
      ref.watch(aiRepositoryProvider).watchMessages(conversationId),
);

final AutoDisposeNotifierProvider<ChatController, ChatState> chatProvider =
    NotifierProvider.autoDispose<ChatController, ChatState>(
  ChatController.new,
);
