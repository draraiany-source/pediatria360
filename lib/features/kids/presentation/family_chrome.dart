import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

/// Ilustrações do portal da família. Trocáveis: o layout não depende do arquivo.
class FamilyArt {
  const FamilyArt._();

  static const String wave = 'assets/illustrations/family/tia_wave.jpg';
  static const String kids = 'assets/illustrations/family/tia_kids.jpg';
  static const String agenda = 'assets/illustrations/family/tia_agenda.jpg';
  static const String tablet = 'assets/illustrations/family/tia_tablet.jpg';
  static const String teddy = 'assets/illustrations/family/teddy_bow.jpg';
  static const String bannerChild =
      'assets/illustrations/family/kids_banner_child.jpg';

  static const Map<String, String> games = <String, String>{
    'doctor': 'assets/illustrations/family/game_doctor.jpg',
    'brush': 'assets/illustrations/family/game_brush.jpg',
    'food': 'assets/illustrations/family/game_food.jpg',
    'memory': 'assets/illustrations/family/game_memory.jpg',
    'puzzle': 'assets/illustrations/family/game_puzzle.jpg',
    'hands': 'assets/illustrations/family/game_hands.jpg',
    'feelings': 'assets/illustrations/family/game_feelings.jpg',
    'vaccine': 'assets/illustrations/family/game_vaccine.jpg',
    'shapes': 'assets/illustrations/family/game_shapes.jpg',
    'sleep': 'assets/illustrations/family/game_sleep.jpg',
  };
}

class FamilyPortalHeader extends StatelessWidget {
  const FamilyPortalHeader({this.childName = 'Enzo Gabriel', super.key});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6A3EAE), Color(0xFFC46BD4)],
        ),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Image.asset(FamilyArt.teddy, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConfig.appName,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.05,
                  ),
                ),
                const Text(
                  'Gestão Completa em Pediatria',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white24,
          ),
          const Icon(Icons.favorite, color: Color(0xFFFF8AD4), size: 12),
          const SizedBox(width: 3),
          const Text(
            'Tia Cris',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => context.go(Routes.notificationsPath),
            child: const Badge(
              label: Text('3'),
              child: Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => context.go(Routes.profilePath),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(0xFFFFD6A8),
                  child: Text(
                    'E',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    childName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyBottomBar extends StatelessWidget {
  const FamilyBottomBar({required this.current, super.key});

  final String current;

  @override
  Widget build(BuildContext context) {
    const List<(String, IconData, String)> items = <(String, IconData, String)>[
      ('Início', Icons.home_rounded, Routes.homePath),
      ('Agenda', Icons.calendar_month_rounded, Routes.familyAgendaPath),
      ('Consultas', Icons.medical_services_rounded, Routes.preVisitPath),
      ('Espaço Kids', Icons.sports_esports_rounded, Routes.kidsPath),
      ('Família', Icons.family_restroom_rounded, Routes.patientAreaPath),
      ('Minha Conta', Icons.person_rounded, Routes.profilePath),
    ];
    return Material(
      color: const Color(0xFF5C3D9A),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (final (String, IconData, String) item in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: Material(
                      color: current == item.$1
                          ? const Color(0xFFF26B9A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => context.go(item.$3),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(item.$2, color: Colors.white, size: 18),
                            Text(
                              item.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyScaffold extends StatelessWidget {
  const FamilyScaffold({required this.section, required this.child, super.key});

  final String section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4E9FF),
      body: Column(
        children: <Widget>[
          const FamilyPortalHeader(),
          Expanded(child: child),
          FamilyBottomBar(current: section),
        ],
      ),
    );
  }
}

class FamilyHero extends StatelessWidget {
  const FamilyHero({
    required this.portrait,
    required this.title,
    required this.body,
    this.trailing,
    super.key,
  });

  final String portrait;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 108,
            height: 132,
            child: Image.asset(portrait, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x146A3EAE),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6A3EAE),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

class FamilyTeddy extends StatelessWidget {
  const FamilyTeddy({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(FamilyArt.teddy, fit: BoxFit.cover),
      ),
    );
  }
}
