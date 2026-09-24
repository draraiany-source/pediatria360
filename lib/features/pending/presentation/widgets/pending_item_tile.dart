import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../domain/pending_item.dart';

class PendingItemTile extends StatelessWidget {
  const PendingItemTile({
    required this.item,
    required this.now,
    required this.onPrimary,
    required this.onStatus,
    required this.canUpdateStatus,
    this.onSecondary,
    super.key,
  });

  final PendingItem item;
  final DateTime now;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final void Function(PendingWorkflowStatus status) onStatus;
  final bool canUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PendingDisplayStatus display = item.displayStatus(now);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(display: display, workflow: item.workflowStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(onPressed: onPrimary, child: const Text('Ação')),
              if (onSecondary != null)
                OutlinedButton(
                  onPressed: onSecondary,
                  child: const Text('Alternativa'),
                ),
              if (canUpdateStatus && item.isActive)
                PopupMenuButton<PendingWorkflowStatus>(
                  tooltip: 'Status',
                  onSelected: onStatus,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<PendingWorkflowStatus>>[
                    const PopupMenuItem<PendingWorkflowStatus>(
                      value: PendingWorkflowStatus.inProgress,
                      child: Text('Em andamento'),
                    ),
                    const PopupMenuItem<PendingWorkflowStatus>(
                      value: PendingWorkflowStatus.resolved,
                      child: Text('Resolvida'),
                    ),
                    const PopupMenuItem<PendingWorkflowStatus>(
                      value: PendingWorkflowStatus.ignored,
                      child: Text('Ignorada'),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.more_horiz),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.display,
    required this.workflow,
  });

  final PendingDisplayStatus display;
  final PendingWorkflowStatus workflow;

  @override
  Widget build(BuildContext context) {
    final String label = switch (display) {
      PendingDisplayStatus.overdue => 'Vencida',
      PendingDisplayStatus.open => workflow.label,
      PendingDisplayStatus.inProgress => workflow.label,
      PendingDisplayStatus.resolved => workflow.label,
      PendingDisplayStatus.ignored => workflow.label,
    };
    final Color color = switch (display) {
      PendingDisplayStatus.overdue => AppColors.danger,
      PendingDisplayStatus.resolved => AppColors.tealDeep,
      PendingDisplayStatus.ignored => AppColors.inkMuted,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
