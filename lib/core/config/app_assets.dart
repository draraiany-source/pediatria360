/// Caminhos dos assets, tipados.
///
/// Uma tela nunca escreve `'assets/icons/ai.svg'` na mao: se um arquivo for
/// renomeado, o erro aparece na compilacao, nao em producao.
class AppAssets {
  const AppAssets._();

  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _lottie = 'assets/lottie';

  // ------------------------------------------------------------ Imagens
  static const String logo = '$_images/logo.png';
  static const String logoLight = '$_images/logo_light.png';
  static const String appIcon = '$_images/app_icon.png';
  static const String splash = '$_images/splash.png';
  static const String splashDark = '$_images/splash_dark.png';
  static const String avatarPlaceholder = '$_images/avatar_placeholder.png';
  static const String mediaPlaceholder = '$_images/media_placeholder.png';
  static const String productPlaceholder = '$_images/product_placeholder.png';
  static const String noise = '$_images/noise.png';

  static const String onboarding1 = '$_images/onboarding_1.png';
  static const String onboarding2 = '$_images/onboarding_2.png';
  static const String onboarding3 = '$_images/onboarding_3.png';

  static const List<String> onboarding = <String>[
    onboarding1,
    onboarding2,
    onboarding3,
  ];

  static const String _illustrations = 'assets/illustrations';

  static const String illustTeddyTip = '$_illustrations/teddy_tip.png';
  static const String illustHeroChild = '$_illustrations/hero_child.png';
  static const String illustLoginToys = '$_illustrations/login_toys.png';
  static const String illustVaccineShield = '$_illustrations/vaccine_shield.png';

  // -------------------------------------------------------------- Icones
  static const String iconLogo = '$_icons/logo.svg';
  static const String iconAi = '$_icons/ai.svg';
  static const String iconGrowth = '$_icons/growth.svg';
  static const String iconVaccine = '$_icons/vaccine.svg';
  static const String iconLibrary = '$_icons/library.svg';
  static const String iconNutrition = '$_icons/nutrition.svg';
  static const String iconFirstAid = '$_icons/first_aid.svg';
  static const String iconTelemedicine = '$_icons/telemedicine.svg';
  static const String iconShop = '$_icons/shop.svg';
  static const String iconBadge = '$_icons/badge.svg';
  static const String iconGoogle = '$_icons/google.svg';
  static const String iconEmptyChildren = '$_icons/empty_children.svg';

  // -------------------------------------------------------------- Lottie
  static const String lottieLoading = '$_lottie/loading.json';
  static const String lottieSuccess = '$_lottie/success.json';
  /// Ícones dimensionais dos cartões de módulo.
  ///
  /// Usados só na home, onde aparecem grandes. As telas clínicas seguem com
  /// Material Icons planos: a 16–24px, profundidade vira borrão e atrapalha
  /// quem varre uma lista.
  static const String _modules = '$_icons/modules';

  static String moduleIcon(String name) => '$_modules/$name.svg';

  static const String lottieEmpty = '$_lottie/empty.json';
  static const String lottieHeartbeat = '$_lottie/heartbeat.json';
  static const String lottieConfetti = '$_lottie/confetti.json';
  static const String lottieAiThinking = '$_lottie/ai_thinking.json';
}
