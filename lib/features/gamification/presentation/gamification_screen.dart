import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/gamification.dart';
import '../../auth/presentation/providers/auth_providers.dart';

final StreamProvider<List<Badge>> badgesProvider =
    StreamProvider<List<Badge>>((Ref ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.badges)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                Badge.fromMap(d.id, d.data()))
            .toList(growable: false),
      );
});

final StreamProvider<List<EarnedBadge>> earnedBadgesProvider =
    StreamProvider<List<EarnedBadge>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<EarnedBadge>>.value(const <EarnedBadge>[]);
  }

  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection('earned_badges')
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) => EarnedBadge(
                badgeId: d.id,
                earnedAt:
                    (d.data()['earnedAt'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
              ),
            )
            .toList(growable: false),
      );
});

final StreamProvider<List<LeaderboardEntry>> leaderboardProvider =
    StreamProvider<List<LeaderboardEntry>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;

  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.leaderboard)
      .orderBy('position')
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs.map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final Map<String, dynamic> data = d.data();
            return LeaderboardEntry(
              uid: d.id,
              displayName: (data['displayName'] as String?) ?? 'Usuário',
              xp: (data['xp'] as num?)?.toInt() ?? 0,
              position: (data['position'] as num?)?.toInt() ?? 0,
              photoUrl: data['photoUrl'] as String?,
              isCurrentUser: d.id == uid,
            );
          },
        ).toList(growable: false),
      );
});

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(currentUserProvider);
    final AsyncValue<List<Badge>> badges = ref.watch(badgesProvider);
    final AsyncValue<List<EarnedBadge>> earned =
        ref.watch(earnedBadgesProvider);

    if (user == null) return const Scaffold(body: LoadingState());

    final Set<String> earnedIds = (earned.valueOrNull ?? const <EarnedBadge>[])
        .map((EarnedBadge b) => b.badgeId)
        .toSet();

    return Scaffold(
      body: AmbientBackground(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              title: const Text('Conquistas'),
              leading: IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.homePath),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Voltar',
              ),
              actions: <Widget>[
                IconButton(
                  onPressed: () => context.push(Routes.leaderboardPath),
                  icon: const Icon(Icons.leaderboard_outlined),
                  tooltip: 'Ranking',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  ContentBounds(
                    maxWidth: 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _LevelCard(user: user),
                        const SectionHeader(
                          title: 'Como ganhar XP',
                          eyebrow: 'Pontuação',
                        ),
                        Card(
                          child: Column(
                            children: <Widget>[
                              for (final XpAction action in XpAction.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          action.label,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      DataValue(
                                        value: '+${action.displayXp}',
                                        unit: 'XP',
                                        size: 14,
                                        color: AppColors.honey,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SectionHeader(
                          title: 'Medalhas',
                          eyebrow: 'Coleção',
                        ),
                        badges.when(
                          loading: () =>
                              const SkeletonList(itemCount: 3, itemHeight: 64),
                          error: (Object e, StackTrace s) =>
                              const SizedBox.shrink(),
                          data: (List<Badge> list) {
                            if (list.isEmpty) {
                              return const EmptyState(
                                icon: Icons.military_tech_outlined,
                                title: 'Nenhuma medalha cadastrada',
                                message: 'As medalhas são configuradas pelo '
                                    'painel administrativo.',
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: list.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.82,
                              ),
                              itemBuilder: (BuildContext context, int index) =>
                                  _BadgeTile(
                                badge: list[index],
                                earned: earnedIds.contains(list[index].id),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppColors.warmGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${user.level}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Nível ${user.level}',
                        style: theme.textTheme.titleLarge),
                    Text(
                      '${user.xp} XP acumulado',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.raspberry,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${user.streakDays}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.raspberry,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user.streakDays == 1 ? 'dia seguido' : 'dias seguidos',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: user.levelProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Faltam ${((1 - user.levelProgress) * 100).round()}% para o '
            'nível ${user.level + 1}.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          // A tolerância da sequência é explicada, não escondida: o usuário
          // precisa saber que um dia perdido não apaga semanas de esforço.
          Row(
            children: <Widget>[
              Icon(
                Icons.favorite_outline_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sua sequência aguenta um dia perdido por semana. '
                  'A vida com criança não é linear.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final Badge badge;
  final bool earned;

  Color get _tierColor => switch (badge.tier) {
        BadgeTier.bronze => AppColors.badgeBronze,
        BadgeTier.silver => AppColors.badgeSilver,
        BadgeTier.gold => AppColors.honey,
        BadgeTier.platinum => AppColors.petrolSoft,
      };

  IconData get _icon => switch (badge.icon) {
        'vaccine' => Icons.vaccines_rounded,
        'growth' => Icons.show_chart_rounded,
        'book' => Icons.menu_book_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'school' => Icons.school_rounded,
        'heart' => Icons.favorite_rounded,
        _ => Icons.military_tech_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget tile = Card(
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(badge.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(badge.description),
                if (badge.requirement != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Como conquistar: ${badge.requirement}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: earned
                      ? _tierColor.withValues(alpha: 0.18)
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  earned ? _icon : Icons.lock_outline_rounded,
                  color: earned
                      ? _tierColor
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                badge.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: earned ? null : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    // Só a medalha conquistada anima. Animar tudo tiraria o sentido de
    // conquista de quem realmente ganhou.
    return earned
        ? tile.animate().fadeIn(duration: AppMotion.normal).scale(
              begin: const Offset(0.94, 0.94),
              end: const Offset(1, 1),
              curve: AppMotion.enter,
            )
        : tile;
  }
}

/// Ranking público.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<LeaderboardEntry>> entries =
        ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: entries.when(
        loading: () => const SkeletonList(itemCount: 8, itemHeight: 56),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.leaderboard_outlined,
          title: 'Ranking indisponível',
          message: 'Tente novamente em instantes.',
        ),
        data: (List<LeaderboardEntry> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'Ranking ainda vazio',
              message: 'Ele é recalculado uma vez por dia.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == list.length) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'O ranking mostra apenas primeiro nome e inicial do '
                    'sobrenome, e é recalculado todo dia às 3h.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final LeaderboardEntry entry = list[index];

              return ContentBounds(
                maxWidth: 560,
                child: Card(
                  color: entry.isCurrentUser
                      ? theme.colorScheme.primaryContainer
                      : null,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: SizedBox(
                      width: 36,
                      child: Center(
                        child: entry.position <= 3
                            ? Icon(
                                Icons.emoji_events_rounded,
                                color: switch (entry.position) {
                                  1 => AppColors.honey,
                                  2 => AppColors.badgeSilver,
                                  _ => AppColors.badgeBronze,
                                },
                              )
                            : Text(
                                '${entry.position}',
                                style: theme.textTheme.titleSmall,
                              ),
                      ),
                    ),
                    title: Text(
                      entry.displayName,
                      style: theme.textTheme.titleSmall,
                    ),
                    trailing: DataValue(
                      value: '${entry.xp}',
                      unit: 'XP',
                      size: 15,
                      color: AppColors.honey,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
