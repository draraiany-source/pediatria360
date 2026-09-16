import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/data/models/app_user_model.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/commerce.dart';
import 'content_editor_screen.dart';

/// Números agregados do painel.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.newUsers,
    required this.pendingVerifications,
    required this.orders,
    required this.paidOrders,
    required this.revenueCents,
    required this.publishedArticles,
    required this.publishedCourses,
  });

  factory AdminStats.fromMap(Map<String, dynamic> map) => AdminStats(
        totalUsers: (map['totalUsers'] as num?)?.toInt() ?? 0,
        newUsers: (map['newUsersLast30Days'] as num?)?.toInt() ?? 0,
        pendingVerifications:
            (map['pendingVerifications'] as num?)?.toInt() ?? 0,
        orders: (map['ordersLast30Days'] as num?)?.toInt() ?? 0,
        paidOrders: (map['paidOrdersLast30Days'] as num?)?.toInt() ?? 0,
        revenueCents: (map['revenueLast30DaysCents'] as num?)?.toInt() ?? 0,
        publishedArticles: (map['publishedArticles'] as num?)?.toInt() ?? 0,
        publishedCourses: (map['publishedCourses'] as num?)?.toInt() ?? 0,
      );

  final int totalUsers;
  final int newUsers;
  final int pendingVerifications;
  final int orders;
  final int paidOrders;
  final int revenueCents;
  final int publishedArticles;
  final int publishedCourses;

  /// Taxa de conversão de pedidos criados para pagos.
  double get paymentRate => orders == 0 ? 0 : paidOrders / orders;
}

final FutureProvider<AdminStats> adminStatsProvider =
    FutureProvider<AdminStats>((Ref ref) async {
  final HttpsCallableResult<dynamic> response = await ref
      .watch(firebaseFunctionsProvider)
      .httpsCallable('adminDashboard')
      .call();

  return AdminStats.fromMap(
    Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
  );
});

/// Profissionais aguardando conferência do registro.
final StreamProvider<List<AppUser>> pendingProfessionalsProvider =
    StreamProvider<List<AppUser>>((Ref ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.users)
      .where('role', isEqualTo: 'professional')
      .where('professionalVerified', isEqualTo: false)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(AppUserMapper.fromFirestore).toList(growable: false),
      );
});

/// Painel administrativo.
///
/// O acesso é barrado em três lugares: o guarda do roteador, as regras do
/// Firestore e a checagem de papel dentro de cada Cloud Function. Nenhuma das
/// três sozinha basta — o roteador é contornável, e as regras não cobrem o que
/// as Functions fazem com privilégio de admin.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<AdminStats> stats = ref.watch(adminStatsProvider);
    final AsyncValue<List<AppUser>> pending =
        ref.watch(pendingProfessionalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administração'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(adminStatsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          ContentBounds(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                stats.when(
                  loading: () =>
                      const SkeletonList(itemCount: 2, itemHeight: 88),
                  error: (Object e, StackTrace s) => EmptyState(
                    icon: Icons.query_stats_rounded,
                    title: 'Métricas indisponíveis',
                    message: 'A função adminDashboard pode não estar '
                        'publicada ainda.',
                    actionLabel: 'Tentar de novo',
                    onAction: () => ref.invalidate(adminStatsProvider),
                  ),
                  data: (AdminStats s) => _StatsGrid(stats: s),
                ),
                const SectionHeader(
                  title: 'Verificação de registro',
                  eyebrow: 'Fila',
                ),
                // Este é o gate que libera protocolos de prescrição e
                // telemedicina. A conferência é manual de propósito: um falso
                // positivo dá acesso a conteúdo de prescrição a quem não deve.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.gpp_maybe_outlined,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Aprovar libera acesso a posologias e telemedicina. '
                          'Confira o registro no portal do conselho antes.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                pending.when(
                  loading: () =>
                      const SkeletonList(itemCount: 2, itemHeight: 72),
                  error: (Object e, StackTrace s) => const SizedBox.shrink(),
                  data: (List<AppUser> list) {
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.verified_outlined,
                        title: 'Fila vazia',
                        message: 'Nenhum registro aguardando conferência.',
                      );
                    }
                    return Column(
                      children: <Widget>[
                        for (final AppUser u in list)
                          _VerificationTile(user: u),
                      ],
                    );
                  },
                ),
                const SectionHeader(title: 'Conteúdo', eyebrow: 'Gestão'),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: const Text('Artigos e protocolos'),
                        subtitle: Text(
                          stats.valueOrNull == null
                              ? 'Carregando...'
                              : '${stats.value!.publishedArticles} publicados',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AdminContentListScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _AdminAction(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Cursos e aulas',
                        subtitle: stats.valueOrNull == null
                            ? 'Carregando...'
                            : '${stats.value!.publishedCourses} publicados',
                      ),
                      const Divider(height: 1),
                      _AdminAction(
                        icon: Icons.inventory_2_outlined,
                        title: 'Produtos e estoque',
                        subtitle: 'Catálogo do marketplace',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Cursos e produtos ainda são cadastrados pelo console do '
                  'Firebase. Artigos e protocolos já têm editor com histórico '
                  'de versões e restauração.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final List<({String label, String value, IconData icon, Color color})>
        cards = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'Usuários',
        value: '${stats.totalUsers}',
        icon: Icons.people_outline_rounded,
        color: AppColors.petrol,
      ),
      (
        label: 'Novos em 30 dias',
        value: '+${stats.newUsers}',
        icon: Icons.person_add_outlined,
        color: AppColors.success,
      ),
      (
        label: 'Verificações pendentes',
        value: '${stats.pendingVerifications}',
        icon: Icons.gpp_maybe_outlined,
        color: stats.pendingVerifications > 0
            ? AppColors.warning
            : AppColors.inkMuted,
      ),
      (
        label: 'Receita em 30 dias',
        value: formatCents(stats.revenueCents),
        icon: Icons.payments_outlined,
        color: AppColors.raspberry,
      ),
      (
        label: 'Pedidos em 30 dias',
        value: '${stats.orders}',
        icon: Icons.receipt_long_outlined,
        color: AppColors.moduleShop,
      ),
      (
        label: 'Taxa de pagamento',
        value: '${(stats.paymentRate * 100).round()}%',
        icon: Icons.trending_up_rounded,
        color: AppColors.vital,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsive<int>(
          compact: 2,
          medium: 3,
          expanded: 3,
        ),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (BuildContext context, int index) {
        final ({String label, String value, IconData icon, Color color}) card =
            cards[index];
        final ThemeData theme = Theme.of(context);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Icon(card.icon, color: card.color, size: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      card.value,
                      style: theme.textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      card.label,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VerificationTile extends ConsumerStatefulWidget {
  const _VerificationTile({required this.user});

  final AppUser user;

  @override
  ConsumerState<_VerificationTile> createState() => _VerificationTileState();
}

class _VerificationTileState extends ConsumerState<_VerificationTile> {
  bool _busy = false;

  Future<void> _decide({required bool approved}) async {
    setState(() => _busy = true);

    final Result<void> result = await guard(() async {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('verifyProfessional')
          .call(<String, dynamic>{
        'targetUid': widget.user.uid,
        'approved': approved,
      });
    });

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '${widget.user.firstName} aprovado.'
                : 'Registro recusado.',
          ),
        ),
      ),
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: AppColors.avatarFor(widget.user.uid),
                    child: Text(
                      widget.user.initials,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.user.name,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          widget.user.email,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (widget.user.crm != null)
                    AppTag(
                      label: widget.user.crm!,
                      icon: Icons.badge_outlined,
                    ),
                  if (widget.user.specialty != null)
                    AppTag(label: widget.user.specialty!),
                  AppTag(
                    label: 'Cadastro em '
                        '${Formatters.date(widget.user.createdAt)}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: 'Recusar',
                      variant: AppButtonVariant.outline,
                      isLoading: _busy,
                      onPressed: () => _decide(approved: false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Aprovar',
                      isLoading: _busy,
                      onPressed: () => _decide(approved: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Edite pelo console do Firebase por enquanto.'),
            ),
          );
      },
    );
  }
}
