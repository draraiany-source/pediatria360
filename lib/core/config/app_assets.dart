import 'capi_pose.dart';

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

  static const String _capi = '$_illustrations/capi';
  static const String capiCelebracao = '$_capi/capi_01_celebracao.png';
  static const String capiBoasVindas = '$_capi/capi_02_boas_vindas.png';
  static const String capiBracosAbertos = '$_capi/capi_03_bracos_abertos.png';
  static const String capiLupa = '$_capi/capi_04_lupa.png';
  static const String capiAceno = '$_capi/capi_05_aceno.png';

  static const String _avatars = '$_illustrations/avatars';
  static const String avatarMeninoCachos =
      '$_avatars/avatar_01_menino_cachos.png';
  static const String avatarMeninaCoral =
      '$_avatars/avatar_02_menina_coral.png';
  static const String avatarMeninoOculos =
      '$_avatars/avatar_03_menino_oculos.png';
  static const String avatarMeninaLilas =
      '$_avatars/avatar_04_menina_lilas.png';
  static const String avatarBebeTurquesa =
      '$_avatars/avatar_05_bebe_turquesa.png';
  static const String avatarMeninoAzul =
      '$_avatars/avatar_06_menino_azul.png';
  static const String avatarMeninaLaranja =
      '$_avatars/avatar_07_menina_laranja.png';
  static const String avatarMeninaRoxo =
      '$_avatars/avatar_08_menina_roxo.png';
  static const String avatarMeninaTranca =
      '$_avatars/avatar_09_menina_tranca.png';

  /// Avatares ilustrados opcionais — escolha do responsavel, nunca automatica.
  static const List<String> childAvatarAssets = <String>[
    avatarMeninoCachos,
    avatarMeninaCoral,
    avatarMeninoOculos,
    avatarMeninaLilas,
    avatarBebeTurquesa,
    avatarMeninoAzul,
    avatarMeninaLaranja,
    avatarMeninaRoxo,
    avatarMeninaTranca,
  ];

  static String capiForPose(CapiPose pose) => switch (pose) {
        CapiPose.celebracao => capiCelebracao,
        CapiPose.boasVindas => capiBoasVindas,
        CapiPose.bracosAbertos => capiBracosAbertos,
        CapiPose.lupa => capiLupa,
        CapiPose.aceno => capiAceno,
      };

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
