import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class FamilyPortalHeader extends StatelessWidget {
  const FamilyPortalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6A45B0), Color(0xFFB06BC8)],
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.pets_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConfig.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Gestão Completa em Pediatria',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          const Text(
            'Tia Cris',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white,
            child: Text(
              'E',
              style: TextStyle(color: AppColors.brand, fontSize: 12),
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
      ('Início', Icons.home_rounded, Routes.patientAreaPath),
      ('Agenda', Icons.calendar_month_rounded, Routes.familyAgendaPath),
      ('Consultas', Icons.medical_services_rounded, Routes.preVisitPath),
      ('Espaço Kids', Icons.sports_esports_rounded, Routes.kidsPath),
      ('Família', Icons.family_restroom_rounded, Routes.patientAreaPath),
      ('Minha Conta', Icons.person_rounded, Routes.profilePath),
    ];
    return Material(
      color: const Color(0xFF5B3D99),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (final (String, IconData, String) item in items)
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(item.$3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          item.$2,
                          color: current == item.$1
                              ? Colors.white
                              : Colors.white70,
                          size: 20,
                        ),
                        Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: current == item.$1
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 9,
                            fontWeight: current == item.$1
                                ? FontWeight.w800
                                : FontWeight.w500,
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
    );
  }
}
