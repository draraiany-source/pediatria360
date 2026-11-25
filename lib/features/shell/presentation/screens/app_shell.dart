import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/crismed_ui.dart';
import '../../../../core/widgets/premium_chrome.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/widgets/sync_banner.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';

/// Destino da navegação principal.
class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    this.professionalOnly = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final bool professionalOnly;
}

const List<_Destination> _professionalSidebar = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Dashboard',
    icon: Icons.dashboard_rounded,
  ),
  _Destination(
    route: Routes.agendaPath,
    label: 'Agenda',
    icon: Icons.calendar_month_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.patientsPath,
    label: 'Pacientes',
    icon: Icons.groups_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.consultasPath,
    label: 'Consultas',
    icon: Icons.medical_services_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.chartHubPath,
    label: 'Prontuário',
    icon: Icons.folder_shared_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.prescriptionsPath,
    label: 'Prescrições',
    icon: Icons.description_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.examsHubPath,
    label: 'Exames',
    icon: Icons.biotech_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.vaccinationHubPath,
    label: 'Vacinação',
    icon: Icons.vaccines_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.growthHubPath,
    label: 'Crescimento',
    icon: Icons.show_chart_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.childcarePath,
    label: 'Puericultura',
    icon: Icons.child_care_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.multidisciplinaryPath,
    label: 'Multidisciplinar',
    icon: Icons.diversity_3_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.financeHubPath,
    label: 'Financeiro',
    icon: Icons.account_balance_wallet_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.reportsHubPath,
    label: 'Relatórios',
    icon: Icons.insights_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.clinicalAiPath,
    label: 'IA Clínica',
    icon: Icons.auto_awesome_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.aiHubPath,
    label: 'Central de IA',
    icon: Icons.psychology_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.unitsPath,
    label: 'Unidades',
    icon: Icons.apartment_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.insuranceHubPath,
    label: 'Convênios',
    icon: Icons.health_and_safety_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.patientAreaPath,
    label: 'Área do Paciente',
    icon: Icons.family_restroom_rounded,
  ),
  _Destination(
    route: Routes.adminHubPath,
    label: 'Permissões',
    icon: Icons.admin_panel_settings_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Configurações',
    icon: Icons.settings_rounded,
  ),
];

const List<_Destination> _professionalPrimary = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Início',
    icon: Icons.dashboard_rounded,
  ),
  _Destination(
    route: Routes.agendaPath,
    label: 'Agenda',
    icon: Icons.calendar_month_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.patientsPath,
    label: 'Pacientes',
    icon: Icons.groups_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.consultasPath,
    label: 'Consultas',
    icon: Icons.medical_services_rounded,
    professionalOnly: true,
  ),
  _Destination(route: '__menu__', label: 'Mais', icon: Icons.menu_rounded),
];

const List<_Destination> _familyDestinations = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Início',
    icon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.patientAreaPath,
    label: 'Família',
    icon: Icons.family_restroom_rounded,
  ),
  _Destination(route: Routes.kidsPath, label: 'Kids', icon: Icons.toys_rounded),
  _Destination(
    route: Routes.diaryPath,
    label: 'Diário',
    icon: Icons.menu_book_rounded,
  ),
  _Destination(
    route: Routes.libraryPath,
    label: 'Biblioteca',
    icon: Icons.local_library_rounded,
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Configurações',
    icon: Icons.settings_rounded,
  ),
];

const List<_Destination> _familyPrimary = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Início',
    icon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.patientAreaPath,
    label: 'Família',
    icon: Icons.family_restroom_rounded,
  ),
  _Destination(route: Routes.kidsPath, label: 'Kids', icon: Icons.toys_rounded),
  _Destination(
    route: Routes.libraryPath,
    label: 'Biblioteca',
    icon: Icons.local_library_rounded,
  ),
  _Destination(route: '__menu__', label: 'Mais', icon: Icons.menu_rounded),
];

/// Casca autenticada: sidebar Crismed no desktop, barra inferior no celular.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  List<_Destination> _sidebarFor(AppUser? user) {
    final bool isPro = user?.role.isProfessional ?? false;
    final List<_Destination> base = isPro
        ? _professionalSidebar
        : _familyDestinations;
    return base
        .where((_Destination d) => !d.professionalOnly || isPro)
        .toList(growable: false);
  }

  List<_Destination> _primaryFor(AppUser? user) {
    final bool isPro = user?.role.isProfessional ?? false;
    final List<_Destination> base = isPro
        ? _professionalPrimary
        : _familyPrimary;
    return base
        .where((_Destination d) => !d.professionalOnly || isPro)
        .toList(growable: false);
  }

  int _indexFor(List<_Destination> destinations) {
    int best = 0;
    int bestLen = -1;
    for (int i = 0; i < destinations.length; i++) {
      final String route = destinations[i].route;
      if (route == '__menu__') continue;
      if (location == route || location.startsWith('$route/')) {
        if (route.length > bestLen) {
          best = i;
          bestLen = route.length;
        }
      }
    }
    return bestLen < 0 ? 0 : best;
  }

  bool _matches(List<_Destination> destinations) {
    for (final _Destination d in destinations) {
      if (d.route == '__menu__') continue;
      if (location == d.route || location.startsWith('${d.route}/'))
        return true;
    }
    return false;
  }

  void _go(
    BuildContext context,
    _Destination destination,
    List<_Destination> menu,
  ) {
    if (destination.route == '__menu__') {
      _openMenu(context, menu);
      return;
    }
    if (location == destination.route ||
        location.startsWith('${destination.route}/')) {
      return;
    }
    context.go(destination.route);
  }

  void _openMenu(BuildContext context, List<_Destination> menu) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            children: <Widget>[
              for (final _Destination d in menu)
                ListTile(
                  leading: Icon(d.icon, color: AppColors.brand),
                  title: Text(d.label),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(d.route);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final List<_Destination> primary = _primaryFor(user);
    final List<_Destination> sidebar = _sidebarFor(user);
    final int primaryIndex = _indexFor(primary);
    final int sidebarIndex = _indexFor(sidebar);
    final bool primaryHit = _matches(primary);
    final int unread = ref.watch(unreadCountProvider);
    final bool isOnline = ref.watch(isOnlineProvider);
    final int pending = ref.watch(pendingSyncCountProvider);

    final Widget content = Column(
      children: <Widget>[
        if (!isOnline)
          OfflineBanner(pendingCount: pending)
        else
          const SyncBanner(),
        Expanded(child: child),
      ],
    );

    final bool wide =
        context.screenSize == ScreenSize.expanded ||
        context.screenSize == ScreenSize.large;

    if (!wide) {
      return Scaffold(
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: primaryIndex.clamp(0, primary.length - 1),
          indicatorColor: primaryHit ? AppColors.softPink : Colors.transparent,
          onDestinationSelected: (int i) => _go(context, primary[i], sidebar),
          destinations: <NavigationDestination>[
            for (final _Destination d in primary)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: <Widget>[
          _CrismedSidebar(
            destinations: sidebar,
            selectedIndex: _matches(sidebar) ? sidebarIndex : -1,
            onSelected: (int i) => _go(context, sidebar[i], sidebar),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                PremiumTopBar(notificationCount: unread),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrismedSidebar extends ConsumerWidget {
  const _CrismedSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 248,
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: <Widget>[
                  const CrismedLogo(onDark: true, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppConfig.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppConfig.appTagline,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: destinations.length,
                itemBuilder: (BuildContext context, int i) {
                  final _Destination d = destinations[i];
                  final bool selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: selected
                          ? AppColors.pinkActive
                          : Colors.transparent,
                      borderRadius: AppRadius.lgAll,
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: AppRadius.lgAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(d.icon, size: 20, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  d.label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: TiaCrisMascot(height: 108),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text('Sair', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
