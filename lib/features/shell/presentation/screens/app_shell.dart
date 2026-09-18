import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/sync_banner.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/premium_chrome.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../../shared/domain/entities/app_user.dart';

/// Destino da navegacao principal.
class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.professionalOnly = false,
    this.showUnreadBadge = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool professionalOnly;
  final bool showUnreadBadge;
}

/// Bottom / rail ? itens essenciais (mobile + tablet).
const List<_Destination> _professionalPrimary = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.patientsPath,
    label: 'Pacientes',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.agendaPath,
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.notificationsPath,
    label: 'Mensagens',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    showUnreadBadge: true,
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Sidebar desktop ? menu completo das referencias.
const List<_Destination> _professionalSidebar = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.patientsPath,
    label: 'Pacientes',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.agendaPath,
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.notificationsPath,
    label: 'Mensagens',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    showUnreadBadge: true,
  ),
  _Destination(
    route: Routes.patientsPath,
    label: 'Prontuario',
    icon: Icons.folder_shared_outlined,
    selectedIcon: Icons.folder_shared_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.childrenPath,
    label: 'Vacinas',
    icon: Icons.vaccines_outlined,
    selectedIcon: Icons.vaccines_rounded,
  ),
  _Destination(
    route: Routes.telemedicinePath,
    label: 'Telemedicina',
    icon: Icons.videocam_outlined,
    selectedIcon: Icons.videocam_rounded,
  ),
  _Destination(
    route: Routes.libraryPath,
    label: 'Biblioteca',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  _Destination(
    route: Routes.clinicPath,
    label: 'Consultorio',
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.supplementPath,
    label: 'Suplementacao',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.clinicOrgPath,
    label: 'Minha clinica',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment_rounded,
    professionalOnly: true,
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<_Destination> _familyDestinations = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.libraryPath,
    label: 'Conteudos',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  _Destination(
    route: Routes.toolsPath,
    label: 'Cuidados',
    icon: Icons.medical_services_outlined,
    selectedIcon: Icons.medical_services_rounded,
  ),
  _Destination(
    route: Routes.notificationsPath,
    label: 'Mensagens',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    showUnreadBadge: true,
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Casca do app autenticado ? navegacao por papel.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  List<_Destination> _primaryFor(AppUser? user) {
    final bool isPro = user?.role.isProfessional ?? false;
    final List<_Destination> base =
        isPro ? _professionalPrimary : _familyDestinations;
    return base
        .where((_Destination d) => !d.professionalOnly || isPro)
        .toList(growable: false);
  }

  List<_Destination> _sidebarFor(AppUser? user) {
    final bool isPro = user?.role.isProfessional ?? false;
    if (!isPro) return _primaryFor(user);
    return _professionalSidebar
        .where((_Destination d) => !d.professionalOnly || isPro)
        .toList(growable: false);
  }

  int _indexFor(List<_Destination> destinations) {
    int best = 0;
    int bestLen = -1;
    for (int i = 0; i < destinations.length; i++) {
      final String route = destinations[i].route;
      if (location == route || location.startsWith('$route/')) {
        // Prefer exact / longer matches; avoid Inicio swallowing everything.
        if (route.length > bestLen) {
          best = i;
          bestLen = route.length;
        }
      }
    }
    return best;
  }

  void _go(BuildContext context, _Destination destination) {
    if (location == destination.route ||
        location.startsWith('${destination.route}/')) {
      return;
    }
    context.go(destination.route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final List<_Destination> primary = _primaryFor(user);
    final List<_Destination> sidebar = _sidebarFor(user);
    final int primaryIndex = _indexFor(primary);
    final int sidebarIndex = _indexFor(sidebar);
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

    return switch (context.screenSize) {
      ScreenSize.compact => Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: primaryIndex.clamp(0, primary.length - 1),
            onDestinationSelected: (int i) => _go(context, primary[i]),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.softBlue,
            destinations: primary
                .map(
                  (_Destination d) => NavigationDestination(
                    icon: _NavIcon(
                      icon: d.icon,
                      selected: false,
                      badge: d.showUnreadBadge ? unread : 0,
                    ),
                    selectedIcon: _NavIcon(
                      icon: d.selectedIcon,
                      selected: true,
                      badge: d.showUnreadBadge ? unread : 0,
                    ),
                    label: d.label,
                  ),
                )
                .toList(),
          ),
        ),
      ScreenSize.medium || ScreenSize.expanded => Scaffold(
          body: Column(
            children: <Widget>[
              PremiumTopBar(notificationCount: unread),
              Expanded(
                child: Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: primaryIndex.clamp(0, primary.length - 1),
                      onDestinationSelected: (int i) =>
                          _go(context, primary[i]),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.white,
                      indicatorColor: AppColors.softBlue,
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
                      destinations: primary
                          .map(
                            (_Destination d) => NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1, color: AppColors.line),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
      ScreenSize.large => Scaffold(
          body: Row(
            children: <Widget>[
              _PremiumSidebar(
                destinations: sidebar,
                selectedIndex: sidebarIndex.clamp(0, sidebar.length - 1),
                onSelected: (int i) => _go(context, sidebar[i]),
                user: user,
                unread: unread,
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
        ),
    };
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.badge,
  });

  final IconData icon;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final Widget child = Icon(
      icon,
      color: selected ? AppColors.brand : AppColors.inkMuted,
    );
    if (badge <= 0) return child;
    return Badge(
      label: Text(badge > 9 ? '9+' : '$badge'),
      child: child,
    );
  }
}

class _PremiumSidebar extends ConsumerWidget {
  const _PremiumSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.user,
    required this.unread,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppUser? user;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 272,
      child: Material(
        color: Colors.white,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.brand,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Pediatria360',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Cuidando de cada infancia',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: AppColors.line),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: destinations.length,
                    itemBuilder: (BuildContext context, int i) {
                      final _Destination d = destinations[i];
                      final bool selected = i == selectedIndex;
                      final int badge =
                          d.showUnreadBadge && unread > 0 ? unread : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(i),
                            borderRadius: AppRadius.lgAll,
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.brand
                                    : Colors.transparent,
                                borderRadius: AppRadius.lgAll,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    selected ? d.selectedIcon : d.icon,
                                    size: 22,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.inkMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      d.label,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        color: selected
                                            ? Colors.white
                                            : AppColors.navy,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (badge > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white
                                            : AppColors.danger,
                                        borderRadius: AppRadius.pillAll,
                                      ),
                                      child: Text(
                                        badge > 9 ? '9+' : '$badge',
                                        style: TextStyle(
                                          color: selected
                                              ? AppColors.brand
                                              : Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
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
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.softBlue,
                            child: Text(
                              user!.initials,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w800,
                              ),
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
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _subtitleFor(user!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.inkMuted,
                        ),
                        title: Text(
                          'Configuracoes',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => context.go(Routes.profilePath),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lgAll,
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          'Sair',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lgAll,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(AppUser user) {
    final List<String> parts = <String>[];
    if ((user.specialty ?? '').isNotEmpty) parts.add(user.specialty!);
    if ((user.crm ?? '').isNotEmpty) parts.add('CRM ${user.crm}');
    if (parts.isNotEmpty) return parts.join(' ? ');
    return user.role.isProfessional ? 'Area profissional' : 'Area da familia';
  }
}
