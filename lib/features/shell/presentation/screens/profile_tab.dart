import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_edit_screen.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../privacy/presentation/privacy_screen.dart';

/// Perfil do profissional — layout das referências Pediatria360.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Os dados salvos neste aparelho serão apagados. O que já foi '
          'sincronizado continua na sua conta.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(currentUserProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AuthActionState action = ref.watch(authControllerProvider);
    final int unread = ref.watch(unreadCountProvider);

    if (user == null) {
      return const Scaffold(body: LoadingState());
    }

    final String since = DateFormat('MMM/yyyy', 'pt_BR').format(user.createdAt);
    final String lastAccess =
        'Último acesso hoje às ${DateFormat('HH:mm').format(DateTime.now())}';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            ContentBounds(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppHeader(notificationCount: unread),
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        Stack(
                          children: <Widget>[
                            PersonAvatar(
                              name: user.name,
                              seed: user.uid,
                              radius: 40,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: AppColors.brand,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ProfileEditScreen(),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                user.role.isProfessional
                                    ? (user.name.startsWith('Dr')
                                        ? user.name
                                        : 'Dra. ${user.firstName}')
                                    : user.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                (user.specialty ?? '').isNotEmpty
                                    ? user.specialty!
                                    : user.role.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cuidado que acompanha cada fase da infância.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Resumo profissional',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _SummaryCell(
                            icon: Icons.badge_outlined,
                            iconColor: AppColors.teal,
                            label: 'CRM',
                            value: (user.crm ?? '').isEmpty
                                ? '—'
                                : user.crm!,
                          ),
                        ),
                        Container(width: 1, height: 48, color: AppColors.line),
                        Expanded(
                          child: _SummaryCell(
                            icon: Icons.apartment_rounded,
                            iconColor: AppColors.moduleLibrary,
                            label: 'Clínica',
                            value: (user.specialty ?? '').isNotEmpty
                                ? user.specialty!
                                : 'Consultório',
                          ),
                        ),
                        Container(width: 1, height: 48, color: AppColors.line),
                        Expanded(
                          child: _SummaryCell(
                            icon: Icons.calendar_month_outlined,
                            iconColor: AppColors.raspberry,
                            label: 'Desde',
                            value: since,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Configurações',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        _SettingsTile(
                          icon: Icons.person_outline_rounded,
                          iconBg: AppColors.softTeal,
                          iconColor: AppColors.teal,
                          title: 'Dados pessoais',
                          subtitle: 'Atualize suas informações pessoais',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileEditScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.notifications_none_rounded,
                          iconBg: AppColors.softLilac,
                          iconColor: AppColors.moduleLibrary,
                          title: 'Notificações',
                          subtitle: 'Gerencie seus avisos e lembretes',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const NotificationCenterScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.shield_outlined,
                          iconBg: AppColors.softBlue,
                          iconColor: AppColors.brand,
                          title: 'Segurança',
                          subtitle: 'Senha, biometria e privacidade',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.help_outline_rounded,
                          iconBg: AppColors.softOrange,
                          iconColor: AppColors.moduleAgenda,
                          title: 'Ajuda',
                          subtitle: 'Dúvidas frequentes e suporte',
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Central de ajuda em breve.',
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          iconBg: const Color(0xFFFFE8EA),
                          iconColor: AppColors.danger,
                          title: 'Sair',
                          subtitle: 'Encerrar sessão na sua conta',
                          onTap: action.isLoading
                              ? null
                              : () => _confirmSignOut(context, ref),
                        ),
                      ],
                    ),
                  ),
                  if (user.role.isAdmin) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      onTap: () => context.push(Routes.adminPath),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.admin_panel_settings_outlined),
                        title: Text('Painel administrativo'),
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: theme.copyWith(
                        radioTheme: RadioThemeData(
                          fillColor: WidgetStateProperty.resolveWith(
                            (Set<WidgetState> states) =>
                                states.contains(WidgetState.selected)
                                    ? AppColors.brand
                                    : AppColors.inkMuted,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                        title: const Text('Aparência'),
                        subtitle: const Text('Tema claro / escuro'),
                        children: <Widget>[
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.system,
                            groupValue: mode,
                            onChanged: (ThemeMode? v) => ref
                                .read(themeModeProvider.notifier)
                                .set(v ?? ThemeMode.system),
                            title: const Text('Seguir o sistema'),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            groupValue: mode,
                            onChanged: (ThemeMode? v) => ref
                                .read(themeModeProvider.notifier)
                                .set(v ?? ThemeMode.light),
                            title: const Text('Claro'),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            groupValue: mode,
                            onChanged: (ThemeMode? v) => ref
                                .read(themeModeProvider.notifier)
                                .set(v ?? ThemeMode.dark),
                            title: const Text('Escuro'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TipBanner(
                    title: 'Sua conta está protegida',
                    body: lastAccess,
                    icon: Icons.verified_user_outlined,
                    trailing: Icon(
                      Icons.toys_outlined,
                      size: 40,
                      color: AppColors.brand.withValues(alpha: 0.35),
                    ),
                  ),
                  if (!user.role.isProfessional) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      onTap: () => context.push(Routes.childrenPath),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.child_care_rounded),
                        title: Text('Crianças'),
                        subtitle: Text('Gerencie os perfis acompanhados'),
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.brand,
      ),
    );
  }
}
