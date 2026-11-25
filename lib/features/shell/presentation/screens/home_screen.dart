import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../crismed/presentation/crismed_dashboard.dart';
import '../../../notifications/presentation/notification_center_screen.dart';

/// Home. Profissional vê o dashboard Crismed; família mantém os atalhos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final bool isPro = user?.role.isProfessional ?? false;

    if (isPro) return const CrismedDashboard();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: _FamilyHome(user: user, greeting: _greeting()),
      ),
    );
  }
}

class _FamilyHome extends ConsumerWidget {
  const _FamilyHome({required this.user, required this.greeting});

  final AppUser? user;
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfigService config = ref.watch(remoteConfigProvider);
    final int unread = ref.watch(unreadCountProvider);
    final ThemeData theme = Theme.of(context);

    final List<_FamilyShortcut> shortcuts = <_FamilyShortcut>[
      _FamilyShortcut(
        'Minhas crianças',
        Icons.child_care_rounded,
        AppColors.teal,
        () => context.push(Routes.childrenPath),
      ),
      _FamilyShortcut(
        'Área da família',
        Icons.family_restroom_rounded,
        AppColors.brand,
        () => context.go(Routes.patientAreaPath),
      ),
      _FamilyShortcut(
        'Espaço Kids',
        Icons.toys_rounded,
        AppColors.raspberry,
        () => context.go(Routes.kidsPath),
      ),
      _FamilyShortcut(
        'Diário',
        Icons.menu_book_rounded,
        AppColors.moduleLibrary,
        () => context.go(Routes.diaryPath),
      ),
      _FamilyShortcut(
        'Conteúdos',
        Icons.local_library_outlined,
        AppColors.moduleLibrary,
        () => context.go(Routes.libraryPath),
      ),
      _FamilyShortcut(
        'Cuidados',
        Icons.medical_services_outlined,
        AppColors.moduleFirstAid,
        () => context.go(Routes.toolsPath),
      ),
      if (config.telemedicineEnabled)
        _FamilyShortcut(
          'Teleconsulta',
          Icons.videocam_outlined,
          AppColors.moduleTelemedicine,
          () => context.push(Routes.telemedicinePath),
        ),
      _FamilyShortcut(
        'IA pediátrica',
        Icons.auto_awesome_rounded,
        AppColors.brand,
        () => context.go(Routes.aiPath),
      ),
      if (config.marketplaceEnabled)
        _FamilyShortcut(
          'Loja',
          Icons.shopping_bag_outlined,
          AppColors.moduleShop,
          () => context.push(Routes.shopPath),
        ),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            child: ContentBounds(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppHeader(notificationCount: unread),
                  Text(
                    '$greeting, ${user?.firstName ?? 'Família'}!',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Acompanhe o cuidado do seu pequeno com tranquilidade.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const BrandSectionHeader(title: 'Ações Rápidas'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: shortcuts
                        .map(
                          (_FamilyShortcut s) => SizedBox(
                            width: 110,
                            child: QuickAccessCard(
                              label: s.title,
                              icon: s.icon,
                              color: s.color,
                              onTap: s.onTap,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const TipBanner(
                    title: 'Dica do dia',
                    body:
                        'Mantenha a caderneta de vacinação em dia e registre '
                        'dúvidas antes da consulta.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FamilyShortcut {
  const _FamilyShortcut(this.title, this.icon, this.color, this.onTap);

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
