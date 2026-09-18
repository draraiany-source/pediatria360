import 'package:flutter/widgets.dart';

/// Escala de espacamento (base 4).
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Preenchimento do texto de unidade dentro de um campo (kg, cm, mg/kg).
  ///
  /// Não é um valor da escala principal — é o que centraliza verticalmente
  /// um `Text` de unidade dentro da altura padrão de 56px de um
  /// `AppTextField`. Existia repetido à mão (`EdgeInsets.all(14)`) em 13
  /// lugares antes desta constante; qualquer ajuste futuro na altura do
  /// campo só precisa mudar aqui.
  static const double fieldSuffix = 14;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(20); // premium 20?24px
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
}

/// Raios de canto. O app usa cantos generosos (fala com pais), mas as
/// superficies de dado clinico usam raio menor para nao "amolecer" o numero.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Duracoes e curvas — motion discreto, coerente entre telas.
class AppMotion {
  const AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration ambient = Duration(milliseconds: 1400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve spring = Curves.elasticOut;
}

/// Elevacoes em forma de sombra (Material 3 usa tonal elevation; aqui as
/// sombras sao suaves e coloridas com o petroleo, nao pretas puras).
class AppElevation {
  const AppElevation._();

  static const double none = 0;
  static const double card = 1;
  static const double raised = 3;
  static const double overlay = 8;
}
