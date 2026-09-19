import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../config/app_assets.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';
import '../theme/app_shadows.dart';
import '../theme/app_tokens.dart';

/// Cabeçalho de marca: menu · logo · notificações (referências Pediatria360).
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onMenu,
    this.notificationCount = 0,
    this.onNotifications,
    this.showMenu = true,
  });

  final VoidCallback? onMenu;
  final int notificationCount;
  final VoidCallback? onNotifications;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          if (showMenu)
            IconButton(
              onPressed: onMenu ?? () => Scaffold.maybeOf(context)?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
              color: AppColors.brand,
              tooltip: 'Menu',
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SvgPicture.asset(
                  AppAssets.iconLogo,
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text.rich(
                        TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                              text: 'Pediatria',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: '360',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Cuidado integral, cada fase importa',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Badge(
            isLabelVisible: notificationCount > 0,
            label: Text(
              notificationCount > 9 ? '9+' : '$notificationCount',
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: AppColors.brand,
            child: IconButton(
              onPressed: onNotifications ??
                  () => context.go(Routes.notificationsPath),
              icon: const Icon(Icons.notifications_none_rounded),
              color: AppColors.navy,
              tooltip: 'Notificações',
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de tela + subtítulo + ação opcional (ex.: Filtros).
class ScreenTitleBlock extends StatelessWidget {
  const ScreenTitleBlock({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.brand,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Card branco arredondado com sombra suave (padrão das referências).
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.color,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadius.xlAll;
    final Widget body = Padding(
      padding: padding ?? AppSpacing.card,
      child: child,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: radius,
            boxShadow: AppShadows.card,
          ),
          child: body,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label)),
            ],
          );

    final Widget button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        elevation: 0,
        shadowColor: AppColors.brand.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      ),
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand, width: 1.5),
        minimumSize: const Size(64, 54),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      ),
      child: Text(label),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum StatusChipTone { confirmed, pending, next, followUp, done, info, danger }

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    super.key,
    this.tone = StatusChipTone.info,
  });

  final String label;
  final StatusChipTone tone;

  factory StatusChip.fromStatusLabel(String label) {
    final String l = label.toLowerCase();
    if (l.contains('confirm') || l.contains('conclu') || l.contains('aplic')) {
      return StatusChip(
        label: label,
        tone: l.contains('conclu') || l.contains('aplic')
            ? StatusChipTone.done
            : StatusChipTone.confirmed,
      );
    }
    if (l.contains('pend')) {
      return StatusChip(label: label, tone: StatusChipTone.pending);
    }
    if (l.contains('próx') || l.contains('prox')) {
      return StatusChip(label: label, tone: StatusChipTone.next);
    }
    if (l.contains('acompanh')) {
      return StatusChip(label: label, tone: StatusChipTone.followUp);
    }
    return StatusChip(label: label, tone: StatusChipTone.info);
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      StatusChipTone.confirmed || StatusChipTone.done => (
          AppColors.softTeal,
          AppColors.tealDeep,
        ),
      StatusChipTone.pending => (AppColors.softPink, const Color(0xFFD94A7A)),
      StatusChipTone.next => (AppColors.softBlue, AppColors.brand),
      StatusChipTone.followUp => (AppColors.softLilac, const Color(0xFF7C6CF0)),
      StatusChipTone.info => (AppColors.softBlue, AppColors.brand),
      StatusChipTone.danger => (
          const Color(0xFFFFE8EA),
          AppColors.danger,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class BrandSectionHeader extends StatelessWidget {
  const BrandSectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: iconColor ?? AppColors.brand),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class QuickAccessCard extends StatelessWidget {
  const QuickAccessCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.asset,
    this.subtitle,
    this.wide = false,
    super.key,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final String? asset;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (wide || subtitle != null) {
      return AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdAll,
              ),
              child: asset != null ? AppIcon(asset: asset!, size: 28, fallback: icon, color: color) : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.inkMuted.withValues(alpha: 0.7),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: asset != null
                ? AppIcon(
                    asset: asset!,
                    size: 28,
                    fallback: icon,
                    color: color,
                  )
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
        ],
      ),
    );
  }
}

class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
    this.selectedColor,
    this.unselectedBg,
    this.unselectedFg,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedBg;
  final Color? unselectedFg;

  @override
  Widget build(BuildContext context) {
    final Color sel = selectedColor ?? AppColors.brand;
    final Color bg = selected
        ? sel
        : (unselectedBg ?? AppColors.softBlue);
    final Color fg = selected
        ? Colors.white
        : (unselectedFg ?? AppColors.brand);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TipBanner extends StatelessWidget {
  const TipBanner({
    required this.title,
    required this.body,
    super.key,
    this.icon = Icons.verified_user_outlined,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: backgroundColor ?? AppColors.softBlue,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
