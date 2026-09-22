import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/automation_catalog.dart';
import '../../domain/pending_aggregator.dart';
import '../../domain/pending_item.dart';
import '../pending_actions.dart';
import '../providers/pending_providers.dart';
import '../widgets/pending_item_tile.dart';

/// CRM clínico — segmentos derivados de pendências reais.
class ClinicCrmScreen extends ConsumerStatefulWidget {
  const ClinicCrmScreen({super.key});

  @override
  ConsumerState<ClinicCrmScreen> createState() => _ClinicCrmScreenState();
}

class _ClinicCrmScreenState extends ConsumerState<ClinicCrmScreen> {
  CrmSegment _segment = CrmSegment.noReturnScheduled;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PendingItem>> async =
        ref.watch(professionalPendingItemsProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('CRM clínico'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Central de pendências',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(Routes.clinicPendingPath),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando segmentos…'),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(professionalPendingItemsProvider),
        ),
        data: (List<PendingItem> all) {
          final DateTime now = DateTime.now();
          final List<PendingItem> segmentItems =
              PendingAggregator.forCrmSegment(all, _segment);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(professionalPendingItemsProvider);
              await ref.read(professionalPendingItemsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                Text(
                  'Segmentos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CrmSegment.values
                      .map(
                        (CrmSegment s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _segment == s,
                          onSelected: (_) => setState(() => _segment = s),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.lg),
                BrandSectionHeader(
                  title: '${_segment.label} (${segmentItems.length})',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (segmentItems.isEmpty)
                  AppCard(
                    child: Text(
                      'Nenhum paciente ou item neste segmento.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...segmentItems.map(
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
                        canUpdateStatus: true,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                const BrandSectionHeader(title: 'Automações (regras)'),
                const SizedBox(height: AppSpacing.sm),
                ...automationRuleCatalog.map(
                  (AutomationRuleDefinition rule) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: ListTile(
                        title: Text(rule.title),
                        subtitle: Text(
                          '${rule.description}\n${rule.integrationPendingLabel}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.link_off_outlined),
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
