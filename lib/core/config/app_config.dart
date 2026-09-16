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
  // Enquanto a integração real não existir, o recurso fica desligado por uma
  // flag central — não apagado. Isso preserva o código já testado (criação
  // de pedido, baixa de estoque em transação) e torna a reativação um único
  // valor, no dia em que o gateway for conectado, em vez de reconstruir a
  // tela do zero.
  static const bool paymentGatewayEnabled = false;
  static const bool videoConsultationEnabled = false;

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
