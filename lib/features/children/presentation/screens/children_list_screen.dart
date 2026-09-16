import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../providers/children_providers.dart';

class ChildrenListScreen extends ConsumerWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Child>> children = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crianças'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(Routes.childFormName),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      ),
      body: children.when(
        loading: () => const SkeletonList(itemCount: 3, itemHeight: 72),
        error: (Object error, StackTrace stack) => ErrorState(
          failure: ErrorMapper.map(error, stack),
          onRetry: () => ref.invalidate(childrenProvider),
        ),
        data: (List<Child> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.child_care_rounded,
              animation: AppAssets.lottieEmpty,
              title: 'Nenhuma criança ainda',
              message: 'Cadastre a primeira para acompanhar crescimento, '
                  'vacinas e marcos do desenvolvimento.',
              actionLabel: 'Cadastrar criança',
              onAction: () => context.pushNamed(Routes.childFormName),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                ContentBounds(child: _ChildCard(child: list[index])),
          );
        },
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final VaccineSummary vaccines =
        ref.watch(vaccineSummaryProvider(child.id));

    return SurfaceCard(
      onTap: () => context.push(Routes.childDetail(child.id)),
      child: Row(
            children: <Widget>[
              PersonAvatar(
                name: child.name,
                seed: child.id,
                radius: 28,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            child.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (child.pendingSync) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      Formatters.pediatricAge(child.birthDate),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        if (child.isPreterm)
                          const ClinicalAlertChip(
                            label: 'Prematuro',
                            tone: ClinicalAlertTone.warning,
                          ),
                        if (vaccines.overdue > 0)
                          ClinicalAlertChip(
                            label: '${vaccines.overdue} vacina'
                                '${vaccines.overdue == 1 ? '' : 's'} em atraso',
                            tone: ClinicalAlertTone.danger,
                            icon: Icons.priority_high_rounded,
                          )
                        else if (vaccines.upcoming > 0)
                          ClinicalAlertChip(
                            label: '${vaccines.upcoming} vacina'
                                '${vaccines.upcoming == 1 ? '' : 's'} em breve',
                            tone: ClinicalAlertTone.warning,
                            icon: Icons.schedule_rounded,
                          ),
                        if (child.daysUntilBirthday <= 7)
                          AppTag(
                            label: child.daysUntilBirthday == 0
                                ? 'Aniversário hoje'
                                : 'Aniversário em ${child.daysUntilBirthday} d',
                            color: AppColors.honey,
                            icon: Icons.cake_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
    );
  }
}
