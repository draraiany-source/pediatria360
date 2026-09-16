import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Card premium — sombra suave light / borda sutil no dark.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.glow = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color? border = borderColor ??
        (isDark ? AppColors.brand.withValues(alpha: 0.22) : null);

    final Widget content = Padding(
      padding: padding ?? AppSpacing.card,
      child: child,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xlAll,
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: AppRadius.xlAll,
            border: border == null ? null : Border.all(color: border),
            gradient: isDark ? AppColors.cardGlow : null,
            boxShadow: glow
                ? AppShadows.glow
                : (isDark ? AppShadows.soft : AppShadows.card),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Alias de compatibilidade — usa [PremiumCard].
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.borderColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: padding,
    onTap: onTap,
    borderColor: borderColor,
    glow: elevated && Theme.of(context).brightness == Brightness.dark,
    child: child,
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.color,
    this.onTap,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? AppColors.brand;

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, size: AppIconSize.sm, color: accent),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.data(theme.colorScheme.onSurface, size: 24),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Alias legado.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MetricCard(
    label: label,
    value: value,
    icon: icon,
    color: color,
    onTap: onTap,
  );
}

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    required this.title,
    super.key,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: AppTypography.eyebrow(
                      theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: AppColors.brand),
              ),
            ),
        ],
      ),
    );
  }
}

class ClinicalAlertChip extends StatelessWidget {
  const ClinicalAlertChip({
    required this.label,
    super.key,
    this.tone = ClinicalAlertTone.warning,
    this.icon,
  });

  final String label;
  final ClinicalAlertTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      ClinicalAlertTone.danger => AppColors.danger,
      ClinicalAlertTone.warning => AppColors.warning,
      ClinicalAlertTone.info => AppColors.info,
      ClinicalAlertTone.success => AppColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon ?? Icons.priority_high_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

enum ClinicalAlertTone { danger, warning, info, success }

class ClinicalBadge extends StatelessWidget {
  const ClinicalBadge({required this.label, super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    required this.seed,
    super.key,
    this.radius = 22,
    this.photoUrl,
  });

  final String name;
  final String seed;
  final double radius;
  final String? photoUrl;

  String get _initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.avatarFor(seed),
      backgroundImage:
          photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? null
          : Text(
              _initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? AppColors.brand;

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: accent, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
