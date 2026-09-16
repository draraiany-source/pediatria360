import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get none => const <BoxShadow>[];

  static List<BoxShadow> get soft => <BoxShadow>[
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get card => <BoxShadow>[
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.07),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.brand.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get raised => <BoxShadow>[
        BoxShadow(
          color: AppColors.brand.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get glow => raised;
}

class AppIconSize {
  const AppIconSize._();

  static const double xs = 14;
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 36;
}
