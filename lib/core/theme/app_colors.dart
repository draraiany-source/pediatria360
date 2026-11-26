import 'package:flutter/material.dart';

/// Design System Crismed — gestão clínica em pediatria.
///
/// Lilás de fundo, roxo de marca, rosa no item ativo e verde nas ações
/// principais (Salvar, Finalizar, Aprovar). Os nomes antigos (`brand`,
/// `navy`, `teal`, `petrol`) continuam para não quebrar as telas já
/// existentes: eles passam a apontar para a paleta Crismed.
class AppColors {
  const AppColors._();

  // ------------------------------------------------------------ Marca
  static const Color brand = Color(0xFF7A4EBF);
  static const Color brandSoft = Color(0xFFB794F4);
  static const Color navy = Color(0xFF3C2463);
  static const Color teal = Color(0xFF2EAF6A);
  static const Color tealDeep = Color(0xFF1E8A52);

  /// Alias legados → marca atual.
  static const Color petrol = brand;
  static const Color petrolDeep = navy;
  static const Color petrolSoft = brandSoft;
  static const Color violet = brand;
  static const Color violetSoft = brandSoft;
  static const Color violetDeep = navy;
  static const Color raspberry = Color(0xFFF26B9A);
  static const Color raspberrySoft = Color(0xFFFFC2D6);
  static const Color magenta = raspberry;
  static const Color magentaSoft = raspberrySoft;

  static const Color honey = Color(0xFFFFB020);
  static const Color honeySoft = Color(0xFFFFE6B8);

  static const Color vital = Color(0xFF8B6AD6);

  /// Ação principal (Salvar, Finalizar, Aprovar).
  static const Color action = Color(0xFF2EAF6A);

  /// Item ativo da sidebar.
  static const Color pinkActive = Color(0xFFF26B9A);

  static const Color sidebarTop = Color(0xFF6A45B0);
  static const Color sidebarBottom = Color(0xFF8E6CC8);

  // ------------------------------------------------------------ Semântica
  static const Color success = Color(0xFF2EAF6A);
  static const Color warning = Color(0xFFFF8A3D);
  static const Color danger = Color(0xFFFF5A6B);
  static const Color info = brand;
  static const Color emergency = Color(0xFFE11D48);

  static const Color badgeBronze = Color(0xFFB87333);
  static const Color badgeSilver = Color(0xFF9DA6AD);

  // ------------------------------------------------------------ Neutros light
  static const Color ink = Color(0xFF3C2463);
  static const Color inkMuted = Color(0xFF8B7BA3);
  static const Color line = Color(0xFFE7DDF3);

  static const Color lightBackground = Color(0xFFF6F1FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFE6F8);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color softBlue = Color(0xFFF3E9FF);
  static const Color softTeal = Color(0xFFE7F8EE);
  static const Color softPink = Color(0xFFFFF0F5);
  static const Color softLilac = Color(0xFFF3E9FF);
  static const Color softOrange = Color(0xFFFFF4E8);
  static const Color softMint = Color(0xFFE7F8EE);

  // ------------------------------------------------------------ Dark (opcional)
  static const Color darkBackground = Color(0xFF1A1028);
  static const Color darkSurface = Color(0xFF261838);
  static const Color darkSurfaceAlt = Color(0xFF322248);
  static const Color darkSurfaceElevated = Color(0xFF3E2C58);
  static const Color darkInk = Color(0xFFF8F4FF);
  static const Color darkInkMuted = Color(0xFFC4B6D6);
  static const Color darkLine = Color(0xFF4A3668);

  // ------------------------------------------------------------ Glass
  static const Color glassLightFill = Color(0xCCFFFFFF);
  static const Color glassLightBorder = Color(0x33FFFFFF);
  static const Color glassDarkFill = Color(0x33261838);
  static const Color glassDarkBorder = Color(0x337A4EBF);

  // ------------------------------------------------------------ Gradientes
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sidebarTop, brand, sidebarBottom],
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[sidebarTop, sidebarBottom],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[brand, raspberry],
  );

  static const LinearGradient ambientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFF8F4FC), Color(0xFFF1E8FA)],
  );

  static const LinearGradient ambientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF261838), Color(0xFF1A1028)],
  );

  static const LinearGradient cardGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x147A4EBF), Color(0x0AF26B9A)],
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
  static const Color moduleTelemedicine = Color(0xFF7C6CF0);
  static const Color moduleGamification = honey;
  static const Color moduleAgenda = Color(0xFFFF8A3D);
  static const Color moduleDevelopment = Color(0xFF8B7CF6);
  static const Color moduleExams = Color(0xFF6B8CFF);
  static const Color moduleMedications = Color(0xFF7C6CF0);
  static const Color moduleAllergies = danger;
  static const Color moduleAdministration = Color(0xFF8B7BA3);

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
