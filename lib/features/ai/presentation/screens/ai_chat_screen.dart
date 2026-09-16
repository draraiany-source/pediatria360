import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../data/ai_repository.dart';
import '../providers/ai_providers.dart';

/// Perguntas de partida. Uma tela de chat em branco é intimidante; estas dão
/// o tom do que a IA faz bem — e do que ela não faz.
const List<String> _starters = <String>[
  'Meu bebê de 8 meses acorda várias vezes à noite. É esperado?',
  'Quando devo me preocupar com febre?',
  'Como sei se a pega da amamentação está certa?',
  'Meu filho de 2 anos fala pouco. Devo investigar?',
];

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({this.conversationId, super.key});

  final String? conversationId;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.conversationId != null) {
      Future<void>.microtask(
        () => ref
            .read(chatProvider.notifier)
            .loadConversation(widget.conversationId!),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.normal,
        curve: AppMotion.enter,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final String text = preset ?? _input.text;
    if (text.trim().isEmpty) return;

    _input.clear();
    FocusScope.of(context).unfocus();
    _scrollToEnd();

    await ref.read(chatProvider.notifier).send(text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChatState chat = ref.watch(chatProvider);
    final RemoteConfigService config = ref.watch(remoteConfigProvider);
    final AsyncValue<AiQuota> quota = ref.watch(aiQuotaProvider);
    final List<Child> children =
        ref.watch(childrenProvider).valueOrNull ?? const <Child>[];

    if (!config.aiEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('IA pediátrica')),
        body: const EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'IA indisponível',
          message: 'O recurso está desativado no momento. Tente mais tarde.',
        ),
      );
    }

    final AiQuota? q = quota.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IA pediátrica'),
        actions: <Widget>[
          if (q != null && !q.unlimited)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: AppTag(
                  label: '${q.remaining} hoje',
                  color: q.remaining <= 2
                      ? AppColors.warning
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          if (chat.messages.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(chatProvider.notifier).reset(),
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'Nova conversa',
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (children.isNotEmpty)
            _ChildSelector(children: children, selected: chat.childId),
          Expanded(
            child: chat.messages.isEmpty
                ? _Welcome(
                    disclaimer: config.aiDisclaimer,
                    onPick: _send,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount:
                        chat.messages.length + (chat.isSending ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= chat.messages.length) {
                        return const _Thinking();
                      }
                      return ContentBounds(
                        maxWidth: 720,
                        child: _Bubble(
                          message: chat.messages[index],
                          onRetry: () =>
                              ref.read(chatProvider.notifier).retryLast(),
                        ),
                      );
                    },
                  ),
          ),
          if (chat.failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                chat.failure!.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          _Composer(
            controller: _input,
            enabled: !chat.isSending && !(q?.exhausted ?? false),
            exhausted: q?.exhausted ?? false,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ChildSelector extends ConsumerWidget {
  const _ChildSelector({required this.children, required this.selected});

  final List<Child> children;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('Pergunta geral'),
              selected: selected == null,
              onSelected: (_) =>
                  ref.read(chatProvider.notifier).attachChild(null),
            ),
          ),
          for (final Child child in children)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text('Sobre ${child.firstName}'),
                selected: selected == child.id,
                onSelected: (_) =>
                    ref.read(chatProvider.notifier).attachChild(child.id),
                avatar: CircleAvatar(
                  backgroundColor: AppColors.avatarFor(child.id),
                  child: Text(
                    child.initials,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.disclaimer, required this.onPick});

  final String disclaimer;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        ContentBounds(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xl),
              Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'O que você quer entender?',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  disclaimer,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final String starter in _starters)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: InkWell(
                      onTap: () => onPick(starter),
                      borderRadius: AppRadius.lgAll,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                starter,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.north_east_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry});

  final AiMessage message;
  final VoidCallback onRetry;

  /// Detecta o bloco de emergência que a Cloud Function prefixa.
  bool get _isEmergency => message.text.startsWith('⚠️');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            if (message.failed) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Não enviou. Tentar de novo'),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: _isEmergency
                  ? AppColors.emergency.withValues(alpha: 0.07)
                  : theme.colorScheme.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: _isEmergency
                    ? AppColors.emergency.withValues(alpha: 0.4)
                    : theme.colorScheme.outlineVariant,
                width: _isEmergency ? 1.5 : 1,
              ),
            ),
            child: Text(
              message.text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
          if (message.sources.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('Baseado em', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final MessageSource source in message.sources)
                  ActionChip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 15),
                    label: Text(
                      source.title,
                      style: theme.textTheme.bodySmall,
                    ),
                    onPressed: source.contentId == null
                        ? null
                        : () => context.push(
                              Routes.article(source.contentId!),
                            ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Consultando os protocolos...',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.exhausted,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool exhausted;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ContentBounds(
            maxWidth: 720,
            child: exhausted
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.hourglass_empty_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Você usou suas perguntas de hoje. O limite '
                            'renova amanhã.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: enabled,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Escreva sua dúvida...',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: enabled ? onSend : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        tooltip: 'Enviar',
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
