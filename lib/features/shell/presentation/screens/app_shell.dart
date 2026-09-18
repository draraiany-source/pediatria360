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
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/domain/entities/app_user.dart';

/// Destino da navegação principal.
class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.professionalOnly = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool professionalOnly;
}

/// Profissional: Início → Consultório → Agenda → Mensagens → Perfil
const List<_Destination> _professionalDestinations = <_Destination>[
  _Destination(
    route: Routes.homePath,
    label: 'Início',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.clinicPath,
    label: 'Consultório',
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital_rounded,
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
    label: 'Início',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    route: Routes.libraryPath,
    label: 'Conteúdos',
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
  ),
  _Destination(
    route: Routes.profilePath,
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Casca do app autenticado — navegação por papel.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  List<_Destination> _visibleFor(AppUser? user) {
    final bool isPro = user?.role.isProfessional ?? false;
    final List<_Destination> base = isPro
        ? _professionalDestinations
        : _familyDestinations;
    return base
        .where((_Destination d) => !d.professionalOnly || isPro)
        .toList(growable: false);
  }

  int _indexFor(List<_Destination> destinations) {
    // Match mais específico primeiro (evita /inicio engolir tudo).
    int best = 0;
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
    final List<_Destination> destinations = _visibleFor(user);
    final int index = _indexFor(destinations);

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
          selectedIndex: index.clamp(0, destinations.length - 1),
          onDestinationSelected: (int i) => _go(context, destinations[i]),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.softBlue,
          destinations: destinations
              .map(
                (_Destination d) => NavigationDestination(
                  icon: Icon(d.icon, color: AppColors.inkMuted),
                  selectedIcon: Icon(d.selectedIcon, color: AppColors.brand),
                  label: d.label,
                ),
              )
              .toList(),
        ),
      ),
      ScreenSize.medium || ScreenSize.expanded => Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: index.clamp(0, destinations.length - 1),
              onDestinationSelected: (int i) => _go(context, destinations[i]),
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
              destinations: destinations
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
      ScreenSize.large => Scaffold(
        body: Row(
          children: <Widget>[
            _Sidebar(
              destinations: destinations,
              selectedIndex: index.clamp(0, destinations.length - 1),
              onSelected: (int i) => _go(context, destinations[i]),
              user: user,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    };
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.user,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 268,
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
                        width: 40,
                        height: 40,
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
                              'Cuidado integral',
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(i),
                            borderRadius: AppRadius.lgAll,
                            hoverColor: AppColors.softBlue.withValues(
                              alpha: 0.65,
                            ),
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.softBlue
                                    : Colors.transparent,
                                borderRadius: AppRadius.lgAll,
                                border: selected
                                    ? Border.all(
                                        color: AppColors.brand.withValues(
                                          alpha: 0.18,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    selected ? d.selectedIcon : d.icon,
                                    size: 22,
                                    color: selected
                                        ? AppColors.brand
                                        : AppColors.inkMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      d.label,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        color: selected
                                            ? AppColors.brand
                                            : AppColors.navy,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.brand,
                                        shape: BoxShape.circle,
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
                                  (user!.specialty ?? '').isNotEmpty
                                      ? user!.specialty!
                                      : (user!.role.isProfessional
                                          ? 'Área profissional'
                                          : 'Área da família'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
