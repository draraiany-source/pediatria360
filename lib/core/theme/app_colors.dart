import 'package:flutter/material.dart';

/// Design System Pediatria360 — identidade oficial (referências Figma).
///
/// Light-first: azul clínico #315EF5, marinho #0E2A66, turquesa #2FC7B5.
/// Alias legados (`petrol`, `violet`, `raspberry`) apontam para a marca
/// atual para não quebrar telas existentes.
class AppColors {
  const AppColors._();

  // ------------------------------------------------------------ Marca
  static const Color brand = Color(0xFF315EF5);
  static const Color brandSoft = Color(0xFF5B7FF7);
  static const Color navy = Color(0xFF0E2A66);
  static const Color teal = Color(0xFF2FC7B5);
  static const Color tealDeep = Color(0xFF1FA896);

  /// Alias legados → marca oficial.
  static const Color petrol = brand;
  static const Color petrolDeep = navy;
  static const Color petrolSoft = brandSoft;
  static const Color violet = brand;
  static const Color violetSoft = brandSoft;
  static const Color violetDeep = navy;
  static const Color raspberry = Color(0xFFFF6B9D);
  static const Color raspberrySoft = Color(0xFFFFB3C9);
  static const Color magenta = raspberry;
  static const Color magentaSoft = raspberrySoft;

  static const Color honey = Color(0xFFFFB020);
  static const Color honeySoft = Color(0xFFFFE6B8);

  static const Color vital = Color(0xFF4C7DFF);

  // ------------------------------------------------------------ Semântica
  static const Color success = Color(0xFF2FC7B5);
  static const Color warning = Color(0xFFFF8A3D);
  static const Color danger = Color(0xFFFF5A6B);
  static const Color info = brand;
  static const Color emergency = Color(0xFFE11D48);

  static const Color badgeBronze = Color(0xFFB87333);
  static const Color badgeSilver = Color(0xFF9DA6AD);

  // ------------------------------------------------------------ Neutros light
  static const Color ink = Color(0xFF0E2A66);
  static const Color inkMuted = Color(0xFF7A8BA8);
  static const Color line = Color(0xFFE6ECF5);

  static const Color lightBackground = Color(0xFFFAFBFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEDF3FF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color softBlue = Color(0xFFEDF3FF);
  static const Color softTeal = Color(0xFFEAFBF7);
  static const Color softPink = Color(0xFFFFF0F4);
  static const Color softLilac = Color(0xFFF2EFFF);
  static const Color softOrange = Color(0xFFFFF4E8);
  static const Color softMint = Color(0xFFE8F8F4);

  // ------------------------------------------------------------ Dark (opcional)
  static const Color darkBackground = Color(0xFF0A1628);
  static const Color darkSurface = Color(0xFF122033);
  static const Color darkSurfaceAlt = Color(0xFF1A2B45);
  static const Color darkSurfaceElevated = Color(0xFF223552);
  static const Color darkInk = Color(0xFFF8FAFC);
  static const Color darkInkMuted = Color(0xFF94A3B8);
  static const Color darkLine = Color(0xFF2A3F5C);

  // ------------------------------------------------------------ Glass
  static const Color glassLightFill = Color(0xCCFFFFFF);
  static const Color glassLightBorder = Color(0x33FFFFFF);
  static const Color glassDarkFill = Color(0x331A2B45);
  static const Color glassDarkBorder = Color(0x33315EF5);

  // ------------------------------------------------------------ Gradientes
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[navy, brand, teal],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[teal, brand],
  );

  static const LinearGradient ambientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFAFBFD), Color(0xFFEDF3FF)],
  );

  static const LinearGradient ambientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF122033), Color(0xFF0A1628)],
  );

  static const LinearGradient cardGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x14315EF5), Color(0x0A2FC7B5)],
  );

  // ------------------------------------------------- Módulos
  static const Color moduleAi = brand;
  static const Color moduleLibrary = Color(0xFF8B7CF6);
  static const Color moduleGrowth = teal;
  static const Color moduleVaccines = raspberry;
  static const Color moduleNutrition = tealDeep;
  static const Color moduleFirstAid = emergency;
  static const Color moduleCourses = honey;
  static const Color moduleShop = raspberry;
  static const Color moduleTelemedicine = Color(0xFF4C9BFF);
  static const Color moduleGamification = honey;
  static const Color moduleAgenda = Color(0xFFFF8A3D);
  static const Color moduleDevelopment = Color(0xFF8B7CF6);
  static const Color moduleExams = Color(0xFF6B8CFF);
  static const Color moduleMedications = Color(0xFF7C6CF0);
  static const Color moduleAllergies = danger;
  static const Color moduleAdministration = Color(0xFF64748B);

  static Color avatarFor(String seed) {
    const List<Color> palette = <Color>[
      brand,
      teal,
      moduleLibrary,
      moduleVaccines,
      moduleTelemedicine,
      moduleAgenda,
    ];
    if (seed.isEmpty) return brand;
    final int hash = seed.codeUnits.fold<int>(7, (int a, int b) => a * 31 + b);
    return palette[hash.abs() % palette.length];
  }
}
