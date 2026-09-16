import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// Um aviso recebido.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.route,
  });

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: (d['type'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: (d['read'] as bool?) ?? false,
      route: d['route'] as String?,
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? route;

  /// Ícone por tipo, para a lista ser escaneável sem ler.
  IconData get icon => switch (type) {
        'vaccineDue' => Icons.vaccines_outlined,
        'appointmentReminder' => Icons.event_outlined,
        'growthReminder' => Icons.show_chart_rounded,
        'labResult' => Icons.science_outlined,
        'openDraft' => Icons.edit_note_rounded,
        'content' => Icons.menu_book_outlined,
        _ => Icons.notifications_outlined,
      };

  Color get color => switch (type) {
        'vaccineDue' => AppColors.moduleVaccines,
        'appointmentReminder' => AppColors.vital,
        'labResult' => AppColors.raspberry,
        'openDraft' => AppColors.warning,
        _ => AppColors.petrol,
      };
}

final StreamProvider<List<AppNotification>> notificationsProvider =
    StreamProvider<List<AppNotification>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<AppNotification>>.value(const <AppNotification>[]);
  }

  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(AppNotification.fromFirestore)
            .toList(growable: false),
      );
});

/// Quantos avisos não lidos — alimenta o marcador na barra.
final Provider<int> unreadCountProvider = Provider<int>(
  (Ref ref) =>
      (ref.watch(notificationsProvider).valueOrNull ??
              const <AppNotification>[])
          .where((AppNotification n) => !n.read)
          .length,
);

/// Tipos disponíveis e o estado de cada um.
final FutureProvider<Map<String, dynamic>> notificationSettingsProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  final HttpsCallableResult<dynamic> response = await ref
      .watch(firebaseFunctionsProvider)
      .httpsCallable('getNotificationSettings')
      .call();

  return Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);
});

/// Central de avisos.
///
/// ## Por que guardar cópia no aplicativo
///
/// Notificação do sistema é efêmera: quem viu de relance na tela de bloqueio e
/// desbloqueou o telefone perdeu o aviso. Para lembrete de vacina, isso
/// significa a dose atrasar.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> async =
        ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Mensagens',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.brand),
                tooltip: 'Voltar',
              )
            : null,
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, color: AppColors.brand),
            tooltip: 'Preferências',
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 72),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Não conseguimos carregar essas informações',
          message: 'Tente novamente em alguns instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(notificationsProvider),
        ),
        data: (List<AppNotification> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'Nenhuma mensagem por enquanto',
              message:
                  'Avisos de vacina, consultas, resultados e contatos com '
                  'responsáveis aparecem aqui.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => ContentBounds(
              maxWidth: 680,
              child: _NotificationTile(notification: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final String? uid = ref.read(currentUserProvider)?.uid;

    if (uid != null && !notification.read) {
      await ref
          .read(firestoreProvider)
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection('notifications')
          .doc(notification.id)
          .update(<String, dynamic>{
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted && notification.route != null) {
      // Navegação fire-and-forget após marcar como lida.
      // ignore: unawaited_futures
      context.push(notification.route!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: notification.read ? Colors.white : AppColors.softBlue,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: notification.read
                  ? AppColors.line
                  : AppColors.brand.withValues(alpha: 0.2),
            ),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: notification.color.withValues(alpha: 0.14),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Icon(
                        notification.icon,
                        size: 20,
                        color: notification.color,
                      ),
                    ),
                    if (!notification.read)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.navy,
                                fontWeight: notification.read
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            Formatters.relative(notification.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notification.route != null)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preferências de notificação.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, bool> _pending = <String, bool>{};
  bool _saving = false;

  Future<void> _save() async {
    if (_pending.isEmpty) return;

    setState(() => _saving = true);

    final Result<void> result = await guard(() async {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('updateNotificationSettings')
          .call(<String, dynamic>{'prefs': _pending});
    });

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) {
        ref.invalidate(notificationSettingsProvider);
        _pending.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências salvas.')),
        );
      },
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> async =
        ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferências de aviso'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      bottomNavigationBar: _pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppButton(
                  label: 'Salvar',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
      body: async.when(
        loading: () => const SkeletonList(itemCount: 4, itemHeight: 72),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.tune_rounded,
          title: 'Não foi possível carregar',
          message: 'Tente novamente em instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (Map<String, dynamic> settings) {
          final List<dynamic> types =
              (settings['types'] as List<dynamic>?) ?? const <dynamic>[];
          final Map<dynamic, dynamic> quiet =
              (settings['quietHours'] as Map<dynamic, dynamic>?) ??
                  const <dynamic, dynamic>{};
          final int devices = (settings['deviceCount'] as num?)?.toInt() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              ContentBounds(
                maxWidth: 680,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      child: Column(
                        children: <Widget>[
                          for (final dynamic item in types)
                            Builder(
                              builder: (BuildContext context) {
                                final Map<dynamic, dynamic> t =
                                    item as Map<dynamic, dynamic>;
                                final String key = t['key'].toString();
                                final bool value =
                                    _pending[key] ?? t['enabled'] == true;

                                return SwitchListTile(
                                  value: value,
                                  onChanged: (bool v) =>
                                      setState(() => _pending[key] = v),
                                  title: Text(t['label']?.toString() ?? ''),
                                  subtitle: Text(
                                    t['description']?.toString() ?? '',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Explicar a janela de silêncio evita a reclamação de que
                    // "o aviso não chegou" quando ele foi adiado de propósito.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.bedtime_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Silêncio das ${quiet['start'] ?? 21}h '
                                  'às ${quiet['end'] ?? 8}h',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Lembretes não chegam nesse período. '
                                  'Consulta começando em 1 hora é exceção — '
                                  'o horário do aviso é o horário do fato.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      devices == 0
                          ? 'Nenhum aparelho registrado. Autorize as '
                              'notificações para receber os avisos.'
                          : devices == 1
                              ? '1 aparelho recebendo avisos.'
                              : '$devices aparelhos recebendo avisos.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
