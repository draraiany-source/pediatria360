/// Configuracao central do aplicativo.
///
/// Valores sensiveis (chaves de API, zonas do Bunny.net) sao lidos de
/// `--dart-define`, nunca ficam hardcoded no repositorio.
///
/// Exemplo:
/// ```
/// flutter run --dart-define=BUNNY_STREAM_LIBRARY_ID=123456 \
///             --dart-define=BUNNY_CDN_HOSTNAME=vz-abc.b-cdn.net
/// ```
class AppConfig {
  const AppConfig._();

  static const String appName = 'Pediatria 360';
  static const String supportEmail = 'suporte@pediatria360.app';

  // ------------------------------------------------------------------- Legal
  //
  // Placeholders deliberados — não é URL real. O aceite obrigatório no
  // cadastro (ver RoleSetupScreen) precisa de algo para abrir, mas o texto
  // dos documentos ainda não foi escrito nem revisado por advogado. Trocar
  // por URL real antes de publicar é bloqueador de lançamento, não detalhe.
  static const String termsOfServiceUrl =
      'https://pediatria360.app/termos-de-uso';
  static const String privacyPolicyUrl =
      'https://pediatria360.app/politica-de-privacidade';

  // ------------------------------------------------------- Recursos incompletos
  //
  // Flags da v1 de teste fechado: só o que funciona ponta a ponta fica
  // navegável. Código permanece no repo; a reativação é um booleano.
  static const bool paymentGatewayEnabled = false;
  static const bool videoConsultationEnabled = false;

  /// Prontuário por voz / consulta com IA. UI e fluxo de rascunho existem,
  /// mas sem STT/ASR real de ponta a ponta — fora do escopo do teste fechado.
  static const bool voiceConsultationEnabled = false;

  /// Conector TISS com operadora. Há esqueleto XML local; envio real ausente.
  static const bool tissOperatorEnabled = false;

  /// Assinatura digital ICP-Brasil. Encounters usam hash interno, não ICP.
  static const bool icpDigitalSignatureEnabled = false;

  /// App Check: ativar só com `--dart-define=ENABLE_APP_CHECK=true` após
  /// registrar apps no Console. Rules NÃO exigem token até você decidir.
  static const bool appCheckEnabled =
      bool.fromEnvironment('ENABLE_APP_CHECK', defaultValue: false);

  /// Site key reCAPTCHA v3 (web) — fornecida no Console; não inventar.
  static const String appCheckRecaptchaSiteKey =
      String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');

  // ---------------------------------------------------------------- Ambiente
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProduction => environment == 'prod';
  static bool get isDevelopment => environment == 'dev';

  /// Quando `true`, o app usa os emuladores locais do Firebase.
  static const bool useFirebaseEmulator =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  static const String emulatorHost =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

  // -------------------------------------------------------------- Bunny.net
  /// Id da biblioteca do Bunny Stream (videos, lives, podcasts).
  static const String bunnyStreamLibraryId =
      String.fromEnvironment('BUNNY_STREAM_LIBRARY_ID');

  /// Hostname do CDN de video, ex.: `vz-1a2b3c.b-cdn.net`.
  static const String bunnyCdnHostname =
      String.fromEnvironment('BUNNY_CDN_HOSTNAME');

  /// Zona de storage do Bunny (imagens e PDFs da biblioteca medica).
  static const String bunnyStorageZone =
      String.fromEnvironment('BUNNY_STORAGE_ZONE');

  /// Hostname publico do Bunny Storage (pull zone), ex.: `p360.b-cdn.net`.
  static const String bunnyStorageHostname =
      String.fromEnvironment('BUNNY_STORAGE_HOSTNAME');

  static const String bunnyStreamApiBase = 'https://video.bunnycdn.com';
  static const String bunnyStorageApiBase = 'https://storage.bunnycdn.com';

  static bool get hasBunnyConfigured =>
      bunnyStreamLibraryId.isNotEmpty && bunnyCdnHostname.isNotEmpty;

  // --------------------------------------------------------------------- IA
  /// A IA pediatrica roda em Cloud Function (`aiChat`); o app nunca carrega a
  /// chave do provedor. Aqui ficam apenas os limites de uso do cliente.
  static const int aiFreeMessagesPerDay = 10;
  static const int aiMaxContextMessages = 20;

  // -------------------------------------------------------------- Paginacao
  static const int defaultPageSize = 20;
  static const int feedPageSize = 10;

  // ------------------------------------------------------------------ Cache
  static const Duration cacheTtlShort = Duration(minutes: 5);
  static const Duration cacheTtlMedium = Duration(hours: 6);
  static const Duration cacheTtlLong = Duration(days: 7);
}
