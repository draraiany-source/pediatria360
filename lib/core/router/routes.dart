/// Rotas do aplicativo.
///
/// Nome e caminho ficam juntos: a navegacao usa `context.goNamed(Routes.xName)`
/// e o deep link / push usa `Routes.xPath`. Nenhuma string de rota e escrita
/// solta em tela.
class Routes {
  /// Lista de pacientes do profissional — porta de entrada do prontuário.
  static const String patientsPath = '/pacientes';
  static const String patientsName = 'pacientes';

  const Routes._();

  // Entrada
  static const String splashPath = '/';
  static const String splashName = 'splash';

  static const String onboardingPath = '/onboarding';
  static const String onboardingName = 'onboarding';

  // Autenticacao
  static const String loginPath = '/login';
  static const String loginName = 'login';

  static const String registerPath = '/registro';
  static const String registerName = 'register';

  static const String forgotPasswordPath = '/recuperar-senha';
  static const String forgotPasswordName = 'forgot-password';

  static const String roleSetupPath = '/perfil-inicial';
  static const String roleSetupName = 'role-setup';

  // Shell principal
  static const String homePath = '/inicio';
  static const String homeName = 'home';

  static const String libraryPath = '/biblioteca';
  static const String libraryName = 'library';

  static const String aiPath = '/ia';
  static const String aiName = 'ai';

  static const String toolsPath = '/ferramentas';
  static const String toolsName = 'tools';

  static const String profilePath = '/perfil';
  static const String profileName = 'profile';

  // Criancas
  static const String childrenPath = '/criancas';
  static const String childrenName = 'children';
  static const String childFormPath = 'nova';
  static const String childFormName = 'child-form';
  static const String childDetailPath = ':childId';
  static const String childDetailName = 'child-detail';

  static String childDetail(String childId) => '$childrenPath/$childId';

  // Crescimento e vacinas
  static const String growthPath = 'crescimento';
  static const String growthName = 'growth';
  static const String vaccinesPath = 'vacinas';
  static const String vaccinesName = 'vaccines';

  static String growth(String childId) => '${childDetail(childId)}/$growthPath';
  static String vaccines(String childId) =>
      '${childDetail(childId)}/$vaccinesPath';

  // Biblioteca medica
  static const String articleDetailPath = 'artigo/:articleId';
  static const String articleDetailName = 'article-detail';
  static const String protocolDetailPath = 'protocolo/:protocolId';
  static const String protocolDetailName = 'protocol-detail';

  static String article(String id) => '$libraryPath/artigo/$id';
  static String protocol(String id) => '$libraryPath/protocolo/$id';

  // Calculadoras
  static const String calculatorsPath = 'calculadoras';
  static const String calculatorsName = 'calculators';
  static const String calculatorDetailPath = 'calculadoras/:calculatorId';
  static const String calculatorDetailName = 'calculator-detail';

  static String calculator(String id) => '$toolsPath/calculadoras/$id';

  // Primeiros socorros
  static const String firstAidPath = 'primeiros-socorros';
  static const String firstAidName = 'first-aid';

  // IA
  static const String aiChatPath = 'conversa/:conversationId';
  static const String aiChatName = 'ai-chat';

  static String aiChat(String conversationId) => '$aiPath/conversa/$conversationId';

  // Cursos e streaming
  static const String coursesPath = '/cursos';
  static const String coursesName = 'courses';
  static const String courseDetailPath = ':courseId';
  static const String courseDetailName = 'course-detail';
  static const String lessonPath = ':courseId/aula/:lessonId';
  static const String lessonName = 'lesson';

  static String course(String id) => '$coursesPath/$id';
  static String lesson(String courseId, String lessonId) =>
      '$coursesPath/$courseId/aula/$lessonId';

  // Marketplace
  static const String shopPath = '/loja';
  static const String shopName = 'shop';
  static const String productDetailPath = ':productId';
  static const String productDetailName = 'product-detail';
  static const String cartPath = '/carrinho';
  static const String cartName = 'cart';
  static const String checkoutPath = '/checkout';
  static const String checkoutName = 'checkout';
  static const String ordersPath = '/pedidos';
  static const String ordersName = 'orders';

  static String product(String id) => '$shopPath/$id';

  // Telemedicina
  static const String telemedicinePath = '/telemedicina';
  static const String telemedicineName = 'telemedicine';
  static const String agendaPath = '/agenda';
  static const String agendaName = 'agenda';
  static const String appointmentDetailPath = ':appointmentId';
  static const String appointmentDetailName = 'appointment-detail';
  static const String consultationRoomPath = ':appointmentId/consulta';
  static const String consultationRoomName = 'consultation-room';

  static String appointment(String id) => '$telemedicinePath/$id';
  static String consultationRoom(String id) => '$telemedicinePath/$id/consulta';

  // Consultorio 360 + Prontuario IA
  static const String clinicPath = '/consultorio';
  static const String clinicName = 'clinic';
  static const String clinicReceptionPath = '/consultorio/recepcao';
  static const String clinicReceptionName = 'clinic-reception';
  static const String clinicTriagePath = '/consultorio/triagem/:appointmentId';
  static const String clinicTriageName = 'clinic-triage';
  static const String clinicPatient360Path =
      '/consultorio/paciente/:childId/360';
  static const String clinicPatient360Name = 'clinic-patient-360';
  static const String clinicVoicePath = '/consultorio/ia';
  static const String clinicVoiceName = 'clinic-voice';
  static const String clinicVoiceConsentPath = '/consultorio/ia/consentimento';
  static const String clinicVoiceConsentName = 'clinic-voice-consent';
  static const String clinicVoiceLivePath = '/consultorio/ia/sessao/:sessionId';
  static const String clinicVoiceLiveName = 'clinic-voice-live';
  static const String clinicVoiceReviewPath =
      '/consultorio/ia/revisao/:sessionId';
  static const String clinicVoiceReviewName = 'clinic-voice-review';
  static const String clinicVoiceFinalPath = '/consultorio/ia/final/:sessionId';
  static const String clinicVoiceFinalName = 'clinic-voice-final';

  static String clinicTriage(String appointmentId) =>
      '/consultorio/triagem/$appointmentId';
  static String clinicPatient360(String childId) =>
      '/consultorio/paciente/$childId/360';
  static String clinicVoiceLive(String sessionId) =>
      '/consultorio/ia/sessao/$sessionId';
  static String clinicVoiceReview(String sessionId) =>
      '/consultorio/ia/revisao/$sessionId';
  static String clinicVoiceFinal(String sessionId) =>
      '/consultorio/ia/final/$sessionId';

  // Suplementacao Pediatrica (profissional)
  static const String supplementPath = '/suplementacao';
  static const String supplementName = 'supplement';
  static const String supplementMicronutrientsPath =
      '/suplementacao/micronutrientes';
  static const String supplementMicronutrientsName = 'supplement-micronutrients';
  static const String supplementMicronutrientPath =
      '/suplementacao/micronutrientes/:id';
  static const String supplementMicronutrientName = 'supplement-micronutrient';
  static const String supplementLabsPath = '/suplementacao/exames';
  static const String supplementLabsName = 'supplement-labs';
  static const String supplementLabDetailPath = '/suplementacao/exames/:examId';
  static const String supplementLabDetailName = 'supplement-lab-detail';
  static const String supplementLabRegisterPath =
      '/suplementacao/exames/registrar';
  static const String supplementLabRegisterName = 'supplement-lab-register';
  static const String supplementLabAiPath = '/suplementacao/exames/ia';
  static const String supplementLabAiName = 'supplement-lab-ai';
  static const String supplementCalculatorPath = '/suplementacao/calculadora';
  static const String supplementCalculatorName = 'supplement-calculator';
  static const String supplementPrescriptionPath = '/suplementacao/prescricao';
  static const String supplementPrescriptionName = 'supplement-prescription';
  static const String supplementPrescriptionViewPath =
      '/suplementacao/prescricao/:rxId';
  static const String supplementPrescriptionViewName =
      'supplement-prescription-view';
  static const String supplementProtocolsPath = '/suplementacao/protocolos';
  static const String supplementProtocolsName = 'supplement-protocols';
  static const String supplementFoodsPath = '/suplementacao/alimentos';
  static const String supplementFoodsName = 'supplement-foods';
  static const String supplementParentPath = '/suplementacao/orientacao-pais';
  static const String supplementParentName = 'supplement-parent';
  static const String supplementAiPath = '/suplementacao/ia';
  static const String supplementAiName = 'supplement-ai';
  static const String supplementHistoryPath = '/suplementacao/historico';
  static const String supplementHistoryName = 'supplement-history';
  static const String supplementChartsPath = '/suplementacao/graficos';
  static const String supplementChartsName = 'supplement-charts';
  static const String supplementFavoritesPath = '/suplementacao/favoritos';
  static const String supplementFavoritesName = 'supplement-favorites';

  static String supplementMicronutrient(String id) =>
      '$supplementMicronutrientsPath/$id';
  static String supplementLabDetail(String examId, {String? childId}) {
    final String base = '$supplementLabsPath/$examId';
    if (childId == null || childId.isEmpty) return base;
    return '$base?childId=$childId';
  }

  static String supplementLabRegister({String? childId, String? examId}) {
    final List<String> q = <String>[];
    if (childId != null && childId.isNotEmpty) q.add('childId=$childId');
    if (examId != null && examId.isNotEmpty) q.add('examId=$examId');
    if (q.isEmpty) return supplementLabRegisterPath;
    return '$supplementLabRegisterPath?${q.join('&')}';
  }

  static String supplementPrescriptionView(String rxId) =>
      '$supplementPrescriptionPath/$rxId';

  static String supplementWithChild(String path, String childId) {
    final String sep = path.contains('?') ? '&' : '?';
    return '$path${sep}childId=$childId';
  }

  // Gamificacao
  static const String gamificationPath = '/conquistas';
  static const String gamificationName = 'gamification';
  static const String leaderboardPath = '/ranking';
  static const String leaderboardName = 'leaderboard';

  // Conta
  static const String settingsPath = '/ajustes';
  static const String settingsName = 'settings';
  static const String subscriptionPath = '/assinatura';
  static const String subscriptionName = 'subscription';
  static const String notificationsPath = '/avisos';
  static const String notificationsName = 'notifications';

  // Administracao
  static const String adminPath = '/admin';
  static const String adminName = 'admin';
  static const String adminContentPath = 'conteudo';
  static const String adminContentName = 'admin-content';

  // Erro
  static const String notFoundPath = '/404';
  static const String notFoundName = 'not-found';
  static const String maintenancePath = '/manutencao';
  static const String maintenanceName = 'maintenance';
}
