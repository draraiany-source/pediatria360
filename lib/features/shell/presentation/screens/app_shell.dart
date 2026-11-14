import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/sync_banner.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/route_access.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/premium_chrome.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../workspace/domain/workspace_profile.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../domain/account_role_label.dart';
import '../../domain/main_menu.dart';
import '../providers/selected_patient_provider.dart';
import 'patient_module_screen.dart' show formatBirthDate;

/// Destino da navegação inferior / rail.
class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.asset,
    this.showUnreadBadge = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Ícone premium (PNG). Se nulo, usa [icon]/[selectedIcon].
  final String? asset;
  final bool showUnreadBadge;
}

const _Destination _home = _Destination(
  route: Routes.homePath,
  label: 'Início',
  asset: AppIcons.home,
  icon: Icons.home_outlined,
  selectedIcon: Icons.home_rounded,
);

const _Destination _messages = _Destination(
  route: Routes.notificationsPath,
  label: 'Mensagens',
  asset: AppIcons.messages,
  icon: Icons.chat_bubble_outline_rounded,
  selectedIcon: Icons.chat_bubble_rounded,
  showUnreadBadge: true,
);

const _Destination _profile = _Destination(
  route: Routes.profilePath,
  label: 'Perfil',
  asset: AppIcons.profile,
  icon: Icons.person_outline_rounded,
  selectedIcon: Icons.person_rounded,
);

const _Destination _agenda = _Destination(
  route: Routes.agendaPath,
  label: 'Agenda',
  asset: AppIcons.schedule,
  icon: Icons.calendar_month_outlined,
  selectedIcon: Icons.calendar_month_rounded,
);

/// Barra inferior / rail da equipe clínica: atalhos; o menu completo fica
/// na gaveta.
const List<_Destination> _professionalPrimary = <_Destination>[
  _home,
  _Destination(
    route: Routes.patientsPath,
    label: 'Pacientes',
    asset: AppIcons.patients,
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  _agenda,
  _messages,
];

const List<_Destination> _receptionPrimary = <_Destination>[
  _home,
  _agenda,
  _Destination(
    route: Routes.clinicReceptionPath,
    label: 'Recepção',
    asset: AppIcons.waitingQueue,
    icon: Icons.how_to_reg_rounded,
    selectedIcon: Icons.how_to_reg_rounded,
  ),
  _messages,
];

const List<_Destination> _financePrimary = <_Destination>[
  _home,
  _Destination(
    route: Routes.financePath,
    label: 'Financeiro',
    asset: AppIcons.finance,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _Destination(
    route: Routes.financeReportsPath,
    label: 'Relatórios',
    icon: Icons.bar_chart_rounded,
    selectedIcon: Icons.bar_chart_rounded,
  ),
  _messages,
];

const List<_Destination> _familyDestinations = <_Destination>[
  _home,
  _Destination(
    route: Routes.libraryPath,
    label: 'Conteúdos',
    asset: AppIcons.library,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  _Destination(
    route: Routes.toolsPath,
    label: 'Cuidados',
    asset: AppIcons.stethoscope,
    icon: Icons.medical_services_outlined,
    selectedIcon: Icons.medical_services_rounded,
  ),
  _messages,
  _profile,
];

const List<_Destination> _adminDestinations = <_Destination>[
  _home,
  _Destination(
    route: Routes.adminPath,
    label: 'Gestão',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
  _Destination(
    route: Routes.notificationsPath,
    label: 'Alertas',
    asset: AppIcons.messages,
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications_rounded,
    showUnreadBadge: true,
  ),
  _profile,
];

/// Item do menu lateral / gaveta.
class _SideItem {
  const _SideItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
}

/// Casca do app autenticado — navegação por papel.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  /// A equipe da clínica usa o menu de 15 módulos; família e plataforma
  /// mantêm os menus próprios.
  static bool _usesMainMenu(WorkspaceProfile workspace) =>
      workspace == WorkspaceProfile.professional ||
      workspace == WorkspaceProfile.receptionist ||
      workspace == WorkspaceProfile.finance;

  static List<_Destination> _primaryFor(WorkspaceProfile workspace) =>
      switch (workspace) {
        WorkspaceProfile.patient => _familyDestinations,
        WorkspaceProfile.admin => _adminDestinations,
        WorkspaceProfile.receptionist => _receptionPrimary,
        WorkspaceProfile.finance => _financePrimary,
        WorkspaceProfile.professional => _professionalPrimary,
      };

  int _indexFor(List<_Destination> destinations) {
    int best = -1;
    int bestLen = -1;
    for (int i = 0; i < destinations.length; i++) {
      final String route = destinations[i].route;
      if (location == route || location.startsWith('$route/')) {
        if (route.length > bestLen) {
          best = i;
          bestLen = route.length;
        }
      }
    }
    return best;
  }

  void _goRoute(BuildContext context, String route) {
    if (location == route) return;
    if (_isShellRoute(route)) {
      context.go(route);
    } else {
      // Rotas fora do ShellRoute abrem por cima para manter o voltar.
      context.push(route);
    }
  }

  void _openEntry(BuildContext context, WidgetRef ref, MainMenuEntry entry) {
    final SelectedPatient? patient = ref.read(selectedPatientProvider);
    if (entry.module.patientScoped && patient != null) {
      context.push(entry.module.patientRoute(patient.childId));
      return;
    }
    _goRoute(context, entry.route);
  }

  static const List<String> _shellRoots = <String>[
    Routes.homePath,
    Routes.clinicPath,
    Routes.agendaPath,
    Routes.patientsPath,
    Routes.notificationsPath,
    Routes.libraryPath,
    Routes.aiPath,
    Routes.toolsPath,
    Routes.profilePath,
    Routes.receptionistAiPath,
  ];

  static bool _isShellRoute(String route) {
    if (route.startsWith('${Routes.clinicPath}/')) {
      return route.startsWith('${Routes.clinicPath}/modulo/');
    }
    return _shellRoots.any((String r) => route == r || route.startsWith('$r/'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final WorkspaceProfile workspace = ref.watch(currentWorkspaceProvider);
    final int unread = ref.watch(unreadCountProvider);
    final bool isOnline = ref.watch(isOnlineProvider);
    final int pending = ref.watch(pendingSyncCountProvider);
    final bool mainMenu = _usesMainMenu(workspace);

    final List<_Destination> primary = _primaryFor(workspace)
        .where((_Destination d) => canOpenRoute(ref, d.route))
        .toList();
    final int primaryIndex = _indexFor(primary);

    final List<_SideItem> sideItems;
    final int sideIndex;
    if (mainMenu) {
      final List<MainMenuEntry> entries =
          buildMainMenu((String route) => canOpenRoute(ref, route));
      sideItems = <_SideItem>[
        for (final MainMenuEntry e in entries)
          _SideItem(
            label: e.label,
            icon: e.icon,
            onTap: () => _openEntry(context, ref, e),
          ),
      ];
      sideIndex = activeMainMenuIndex(entries, location);
    } else {
      sideItems = <_SideItem>[
        for (final _Destination d in primary)
          _SideItem(
            label: d.label,
            icon: d.icon,
            badge: d.showUnreadBadge ? unread : 0,
            onTap: () => _goRoute(context, d.route),
          ),
      ];
      sideIndex = primaryIndex;
    }

    final SelectedPatient? patient =
        mainMenu ? ref.watch(selectedPatientProvider) : null;
    final Widget? patientChip =
        patient == null ? null : _SelectedPatientChip(patient: patient);

    final Widget content = Column(
      children: <Widget>[
        if (!isOnline)
          OfflineBanner(pendingCount: pending)
        else
          const SyncBanner(),
        Expanded(child: child),
      ],
    );

    Widget drawerFor(BuildContext context) => Drawer(
          width: 288,
          child: _MainMenuPanel(
            items: sideItems,
            selectedIndex: sideIndex,
            user: user,
            onItemTap: (int i) {
              Navigator.of(context).pop();
              sideItems[i].onTap();
            },
          ),
        );

    final bool showSearch = canOpenRoute(ref, Routes.patientsPath);

    return switch (context.screenSize) {
      ScreenSize.compact => Scaffold(
          drawer: mainMenu ? Builder(builder: drawerFor) : null,
          body: Column(
            children: <Widget>[
              if (patientChip != null)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: patientChip,
                  ),
                ),
              Expanded(child: content),
            ],
          ),
          bottomNavigationBar: Builder(
            builder: (BuildContext context) => NavigationBar(
              selectedIndex: primaryIndex < 0
                  ? (mainMenu ? primary.length : 0)
                  : primaryIndex,
              onDestinationSelected: (int i) {
                if (i == primary.length) {
                  Scaffold.of(context).openDrawer();
                } else {
                  _goRoute(context, primary[i].route);
                }
              },
              backgroundColor: Colors.white,
              indicatorColor: AppColors.brandIndicator,
              destinations: <NavigationDestination>[
                for (final _Destination d in primary)
                  NavigationDestination(
                    icon: _NavIcon(
                      icon: d.icon,
                      asset: d.asset,
                      selected: false,
                      badge: d.showUnreadBadge ? unread : 0,
                    ),
                    selectedIcon: _NavIcon(
                      icon: d.selectedIcon,
                      asset: d.asset,
                      selected: true,
                      badge: d.showUnreadBadge ? unread : 0,
                    ),
                    label: d.label,
                  ),
                if (mainMenu)
                  const NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    label: 'Menu',
                    tooltip: 'Abrir menu completo',
                  ),
              ],
            ),
          ),
        ),
      ScreenSize.medium || ScreenSize.expanded => Scaffold(
          drawer: mainMenu ? Builder(builder: drawerFor) : null,
          body: Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                PremiumTopBar(
                  notificationCount: unread,
                  showSearch: showSearch,
                  contextChip: patientChip,
                  leading: mainMenu
                      ? IconButton(
                          tooltip: 'Abrir menu completo',
                          icon: const Icon(Icons.menu_rounded),
                          color: AppColors.navy,
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        )
                      : null,
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      NavigationRail(
                        selectedIndex: primaryIndex < 0 ? null : primaryIndex,
                        onDestinationSelected: (int i) =>
                            _goRoute(context, primary[i].route),
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.white,
                        indicatorColor: AppColors.brandIndicator,
                        selectedIconTheme: const IconThemeData(
                          color: AppColors.brand,
                          size: 24,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          color: AppColors.inkMuted,
                          size: 22,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        destinations: <NavigationRailDestination>[
                          for (final _Destination d in primary)
                            NavigationRailDestination(
                              icon: _NavIcon(
                                icon: d.icon,
                                asset: d.asset,
                                selected: false,
                                badge: d.showUnreadBadge ? unread : 0,
                              ),
                              selectedIcon: _NavIcon(
                                icon: d.selectedIcon,
                                asset: d.asset,
                                selected: true,
                                badge: d.showUnreadBadge ? unread : 0,
                              ),
                              label: Text(d.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ScreenSize.large => Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: 272,
                child: _MainMenuPanel(
                  items: sideItems,
                  selectedIndex: sideIndex,
                  user: user,
                  onItemTap: (int i) => sideItems[i].onTap(),
                ),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    PremiumTopBar(
                      notificationCount: unread,
                      showSearch: showSearch,
                      contextChip: patientChip,
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
    };
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.badge,
    this.asset,
  });

  final IconData icon;
  final String? asset;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final Widget child = asset != null
        ? AppIcon(asset: asset!, size: AppIcon.nav, fallback: icon)
        : Icon(icon, color: selected ? AppColors.brand : AppColors.inkMuted);
    if (badge <= 0) return child;
    return Badge(label: Text(badge > 9 ? '9+' : '$badge'), child: child);
  }
}

/// Paciente em foco, com troca confirmada.
class _SelectedPatientChip extends ConsumerWidget {
  const _SelectedPatientChip({required this.patient});

  final SelectedPatient patient;

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Trocar o paciente em foco?'),
        content: Text(
          'Paciente atual: ${patient.name}'
          '${patient.birthDate == null ? '' : ' (nasc. ${formatBirthDate(patient.birthDate!)})'}.\n\n'
          'Você vai escolher outro paciente. Confira nome e data de '
          'nascimento antes de registrar qualquer dado.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Escolher outro'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(selectedPatientProvider.notifier).state = null;
    context.go(Routes.patientModule(MainMenuModule.chart.patientModuleSlug!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: 'Paciente em foco: ${patient.name}',
      child: Container(
        key: const Key('selected-patient-chip'),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.softLilac,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: AppColors.brandIndicator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.person_pin_rounded,
              size: 18,
              color: AppColors.brand,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                patient.birthDate == null
                    ? patient.name
                    : '${patient.name} · ${formatBirthDate(patient.birthDate!)}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _switch(context, ref),
              child: const Text('Trocar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu lateral roxo (desktop) e gaveta (celular / tablet).
class _MainMenuPanel extends ConsumerWidget {
  const _MainMenuPanel({
    required this.items,
    required this.selectedIndex,
    required this.onItemTap,
    required this.user,
  });

  final List<_SideItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String roleLabel = accountRoleLabel(
      user: user,
      membership: ref.watch(activeClinicMembershipProvider),
      workspace: ref.watch(currentWorkspaceProvider),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Row(
                children: <Widget>[
                  Image.asset(
                    AppAssets.logoLight,
                    width: 40,
                    height: 40,
                    semanticLabel: 'Logotipo Pediatria360',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Pediatria360',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (BuildContext context, int i) {
                  final _SideItem item = items[i];
                  final bool selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      selected: selected,
                      button: true,
                      child: Material(
                        color: selected
                            ? AppColors.navSelected
                            : Colors.transparent,
                        borderRadius: AppRadius.lgAll,
                        child: InkWell(
                          key: Key('menu-item-$i'),
                          onTap: () => onItemTap(i),
                          borderRadius: AppRadius.lgAll,
                          hoverColor: Colors.white.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.sidebarMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.sidebarText,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (item.badge > 0)
                                  Badge(
                                    label: Text(
                                      item.badge > 9 ? '9+' : '${item.badge}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.navSelected,
                        foregroundColor: Colors.white,
                        child: Text(
                          user!.initials,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user!.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              roleLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.sidebarMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.sidebarText,
                ),
                title: Text(
                  'Sair',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.sidebarText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  final bool ok =
                      await ref.read(authControllerProvider.notifier).signOut();
                  if (ok && context.mounted) context.go(Routes.loginPath);
                },
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
