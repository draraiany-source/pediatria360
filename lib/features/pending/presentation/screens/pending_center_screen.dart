import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/pending_access.dart';
import '../../domain/pending_aggregator.dart';
import '../../domain/pending_item.dart';
import '../pending_actions.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../providers/pending_providers.dart';
import '../widgets/pending_item_tile.dart';

/// Central de Pendências — visão operacional unificada.
class PendingCenterScreen extends ConsumerStatefulWidget {
  const PendingCenterScreen({this.initialFilter, super.key});

  final PendingCenterFilter? initialFilter;

  @override
  ConsumerState<PendingCenterScreen> createState() =>
      _PendingCenterScreenState();
}

class _PendingCenterScreenState extends ConsumerState<PendingCenterScreen> {
  late PendingCenterFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? PendingCenterFilter.clinical;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PendingItem>> async =
        ref.watch(professionalPendingItemsProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Central de Pendências'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'CRM clínico',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push(Routes.clinicCrmPath),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando pendências…'),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(professionalPendingItemsProvider),
        ),
        data: (List<PendingItem> all) {
          final DateTime now = DateTime.now();
          final List<PendingItem> filtered =
              PendingAggregator.filterByCenterFilter(all, _filter, now);
          filtered.sort(
            (PendingItem a, PendingItem b) =>
                (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt),
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(professionalPendingItemsProvider);
              await ref.read(professionalPendingItemsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PendingCenterFilter.values
                        .map(
                          (PendingCenterFilter f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f.label),
                              selected: _filter == f,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  AppCard(
                    child: Text(
                      'Nenhuma pendência neste filtro.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...filtered.map(
                    (PendingItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PendingItemTile(
                        item: item,
                        now: now,
                        onPrimary: () => runPendingAction(
                          context,
                          ref,
                          item,
                          item.primaryAction,
                        ),
                        onSecondary: item.secondaryAction ==
                                PendingActionKind.none
                            ? null
                            : () => runPendingAction(
                                  context,
                                  ref,
                                  item,
                                  item.secondaryAction,
                                ),
                        onStatus: (PendingWorkflowStatus status) =>
                            updatePendingStatus(ref, item, status),
                        canUpdateStatus: PendingAccess.canUpdateStatus(
                          user: ref.read(currentUserProvider),
                          clinicMembership:
                              ref.read(activeClinicMembershipProvider),
                          item: item,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
