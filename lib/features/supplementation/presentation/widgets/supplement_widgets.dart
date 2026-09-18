import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../domain/lab_result.dart';
import '../../domain/supplement_catalog.dart';

class SupplementDisclaimerBanner extends StatelessWidget {
  const SupplementDisclaimerBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.honeySoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.honey.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined, color: AppColors.navy, size: compact ? 18 : 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              kSupplementClinicalDisclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class SupplementModuleCard extends StatelessWidget {
  const SupplementModuleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QuickAccessCard(
      label: label,
      subtitle: subtitle,
      icon: icon,
      color: color,
      wide: false,
      onTap: onTap,
    );
  }
}

class LabFlagChip extends StatelessWidget {
  const LabFlagChip({required this.flag, super.key});

  final LabResultFlag flag;

  Color get _color => switch (flag) {
        LabResultFlag.normal => AppColors.success,
        LabResultFlag.attention => AppColors.warning,
        LabResultFlag.altered => AppColors.danger,
        LabResultFlag.unset => AppColors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: _color.withValues(alpha: 0.15),
      side: BorderSide(color: _color.withValues(alpha: 0.4)),
      label: Text(
        flag.label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class PendingContentBox extends StatelessWidget {
  const PendingContentBox({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            kSupplementContentPending,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class SupplementEmptyState extends StatelessWidget {
  const SupplementEmptyState({
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupplementSkeletonList extends StatelessWidget {
  const SupplementSkeletonList({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.softBlue.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
