import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../features/shell/domain/account_role_label.dart';
import '../../features/workspace/presentation/providers/workspace_providers.dart';
import '../../shared/domain/entities/app_user.dart';
import '../theme/app_icons.dart';
import 'app_icon.dart';
import 'brand_ui.dart';

/// Barra superior premium (desktop/tablet) ? busca + notificacoes + perfil.
class PremiumTopBar extends ConsumerWidget {
  const PremiumTopBar({
    super.key,
    this.notificationCount = 0,
    this.onSearchSubmitted,
    this.showSearch = true,
    this.leading,
    this.contextChip,
  });

  final int notificationCount;
  final bool showSearch;
  final ValueChanged<String>? onSearchSubmitted;

  /// Botão à esquerda (ex.: abrir o menu em telas médias).
  final Widget? leading;

  /// Contexto ativo exibido antes dos ícones (ex.: paciente em foco).
  final Widget? contextChip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final ThemeData theme = Theme.of(context);
    final String name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'Conta';
    final String roleLabel = accountRoleLabel(
      user: user,
      membership: ref.watch(activeClinicMembershipProvider),
      workspace: ref.watch(currentWorkspaceProvider),
    );
    final String? clinicName = ref.watch(activeClinicProvider).valueOrNull?.name;

    return Material(
      color: Colors.white,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!showSearch) const Spacer() else Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: TextField(
                  onSubmitted: (String q) {
                    if (onSearchSubmitted != null) {
                      onSearchSubmitted!(q);
                      return;
                    }
                    if (q.trim().isEmpty) return;
                    context.go(
                      '${Routes.patientsPath}?q=${Uri.encodeQueryComponent(q.trim())}',
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar paciente pelo nome',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.lightBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(color: AppColors.brand),
                    ),
                  ),
                ),
              ),
            ),
            if (contextChip != null) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Flexible(child: contextChip!),
            ],
            const SizedBox(width: AppSpacing.md),
            IconButton(
              tooltip: 'Notificações',
              onPressed: () => context.go(Routes.notificationsPath),
              icon: Badge(
                isLabelVisible: notificationCount > 0,
                label: Text(
                  notificationCount > 9 ? '9+' : '$notificationCount',
                ),
                child: const AppIcon(
                  asset: AppIcons.notification,
                  size: 22,
                  fallback: Icons.notifications_none_rounded,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PopupMenuButton<String>(
              key: const Key('topbar-account-menu'),
              tooltip: 'Conta',
              position: PopupMenuPosition.under,
              onSelected: (String action) async {
                switch (action) {
                  case 'profile':
                    context.go(Routes.profilePath);
                  case 'settings':
                    await context.push(Routes.settingsPath);
                  case 'logout':
                    final bool ok = await ref
                        .read(authControllerProvider.notifier)
                        .signOut();
                    if (ok && context.mounted) context.go(Routes.loginPath);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    clinicName == null || clinicName.isEmpty
                        ? 'Sem clínica ativa'
                        : 'Unidade: $clinicName',
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Meu perfil'),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Ajustes'),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Sair'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.softLilac,
                      child: Text(
                        user?.initials ?? '?',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// KPI premium com tendencia opcional (como nas referencias).
class PremiumKpiCard extends StatelessWidget {
  const PremiumKpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.asset,
    this.trendLabel,
    this.trendPositive = true,
    this.helper,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? asset;
  final Color color;
  final String? trendLabel;
  final bool trendPositive;
  final String? helper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: asset != null
                    ? AppIcon(asset: asset!, size: 28, fallback: icon, color: color)
                    : Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (trendLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (trendPositive ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    trendLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: trendPositive
                          ? AppColors.tealDeep
                          : AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMuted.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card compacto de acesso rapido (linha de 5 nas refs).
class PremiumQuickTile extends StatelessWidget {
  const PremiumQuickTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.asset,
    super.key,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String? asset;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadius.mdAll,
            ),
            child: asset != null
                ? AppIcon(asset: asset!, size: AppIcon.card, fallback: icon, color: color)
                : Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de atencao necessaria com contagem.
class PremiumAttentionRow extends StatelessWidget {
  const PremiumAttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.count,
    this.actionLabel,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? count;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: color, size: 20),
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
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (actionLabel != null)
                Text(
                  actionLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
