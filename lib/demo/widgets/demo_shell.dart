import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../demo_session.dart';
import 'demo_widgets.dart';

/// Moldura das telas autenticadas-simuladas: faixa de demonstracao em cima,
/// navegacao embaixo (celular) ou na lateral (computador).
class DemoShell extends StatelessWidget {
  const DemoShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const int _maxBottomItems = 5;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final List<DemoModule> modules = demoSession.modules;
        final DemoModule? current = DemoModule.fromLocation(location);
        final bool wide = MediaQuery.sizeOf(context).width >= 840;

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: Column(
            children: <Widget>[
              const DemoBanner(),
              Expanded(
                child: wide
                    ? Row(
                        children: <Widget>[
                          _Rail(modules: modules, current: current),
                          const VerticalDivider(width: 1),
                          Expanded(child: child),
                        ],
                      )
                    : child,
              ),
            ],
          ),
          bottomNavigationBar: wide || modules.isEmpty
              ? null
              : _BottomNav(modules: modules, current: current),
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.modules, required this.current});

  final List<DemoModule> modules;
  final DemoModule? current;

  @override
  Widget build(BuildContext context) {
    final int index = current == null ? -1 : modules.indexOf(current!);
    return NavigationRail(
      extended: MediaQuery.sizeOf(context).width >= 1200,
      minExtendedWidth: 220,
      backgroundColor: Colors.white,
      selectedIndex: index < 0 ? null : index,
      labelType: MediaQuery.sizeOf(context).width >= 1200
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: <Widget>[
            const Icon(Icons.child_care_rounded,
                color: AppColors.brand, size: 32),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pedi360',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
      onDestinationSelected: (int i) => context.go(modules[i].path),
      destinations: <NavigationRailDestination>[
        for (final DemoModule m in modules)
          NavigationRailDestination(
            icon: Icon(m.icon),
            selectedIcon: Icon(m.selectedIcon),
            label: Text(m.label),
          ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.modules, required this.current});

  final List<DemoModule> modules;
  final DemoModule? current;

  @override
  Widget build(BuildContext context) {
    final bool overflow = modules.length > DemoShell._maxBottomItems;
    final List<DemoModule> primary = overflow
        ? <DemoModule>[
            ...modules.take(DemoShell._maxBottomItems - 1),
          ]
        : modules;
    final List<DemoModule> extra =
        overflow ? modules.skip(primary.length).toList() : <DemoModule>[];

    int selected = current == null ? -1 : primary.indexOf(current!);
    if (selected < 0 && current != null && extra.contains(current)) {
      selected = primary.length;
    }

    return NavigationBar(
      backgroundColor: Colors.white,
      selectedIndex: selected < 0 ? 0 : selected,
      indicatorColor:
          selected < 0 ? Colors.transparent : AppColors.softBlue,
      onDestinationSelected: (int i) {
        if (i < primary.length) {
          context.go(primary[i].path);
        } else {
          _openMore(context, extra);
        }
      },
      destinations: <NavigationDestination>[
        for (final DemoModule m in primary)
          NavigationDestination(
            icon: Icon(m.icon),
            selectedIcon: Icon(m.selectedIcon, color: AppColors.brand),
            label: m.label,
          ),
        if (overflow)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
      ],
    );
  }

  void _openMore(BuildContext context, List<DemoModule> extra) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final DemoModule m in extra)
              ListTile(
                leading: Icon(m.icon, color: AppColors.brand),
                title: Text(m.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.go(m.path);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
