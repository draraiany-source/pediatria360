import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/app_config.dart';
import 'core/config/dev_mode.dart';
import 'core/providers/core_providers.dart';
import 'core/providers/sync_providers.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/app_logger.dart';
import 'core/services/cache_service.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/local_database.dart';
import 'core/services/notification_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Checagem antes de qualquer coisa: se o projeto ainda não recebeu
  // `flutterfire configure`, `Firebase.initializeApp` chamaria o SDK nativo
  // com uma chave de API inválida. O resultado seria uma exceção de
  // plataforma pouco legível — possivelmente só na primeira tentativa de
  // autenticação, minutos depois de aberto o app, não "no primeiro segundo"
  // como o comentário em firebase_options.dart promete. Aqui a promessa vira
  // código: falha imediata, tela dedicada, sem stack trace na cara de quem
  // só esqueceu de rodar o comando.
  if (DefaultFirebaseOptions.isPlaceholder) {
    runApp(const _FirebaseNotConfiguredApp());
    return;
  }

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Formatacao de data/numero em pt-BR precisa estar carregada antes da
  // primeira tela — senao `DateFormat('pt_BR')` lanca no primeiro uso.
  await initializeDateFormatting('pt_BR');

  await FirebaseBootstrap.run();

  // Servicos que dependem de I/O sao criados aqui, uma unica vez, e injetados
  // no container. Assim nenhuma tela precisa lidar com `AsyncValue` de setup.
  final CacheService cache = await CacheService.open();
  final RemoteConfigService remoteConfig = await RemoteConfigService.init();
  final NotificationService notifications = await NotificationService.init();

  LocalDatabase? database;
  if (LocalDatabase.isSupported) {
    try {
      database = await LocalDatabase.open();
    } catch (error, stack) {
      // Sem SQLite o app perde a fila offline, mas continua utilizavel com
      // a persistencia nativa do Firestore. Nao e motivo para travar a
      // abertura.
      await AppLogger.error(error, stack, reason: 'sqlite.open');
    }
  }

  AppLogger.info(
    'Pediatria 360 iniciado (${AppConfig.environment})',
    tag: 'boot',
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        cacheServiceProvider.overrideWithValue(cache),
        localDatabaseProvider.overrideWithValue(database),
        remoteConfigProvider.overrideWithValue(remoteConfig),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const Pediatria360App(),
    ),
  );
}

class Pediatria360App extends ConsumerStatefulWidget {
  const Pediatria360App({super.key});

  @override
  ConsumerState<Pediatria360App> createState() => _Pediatria360AppState();
}

class _Pediatria360AppState extends ConsumerState<Pediatria360App> {
  ProviderSubscription<AsyncValue<dynamic>>? _authSubscription;
  StreamSubscription<String>? _routeSubscription;

  @override
  void initState() {
    super.initState();
    // Sobe a fila de sincronizacao junto com o app.
    ref.read(syncServiceProvider);
    _listenToNotificationRoutes();
    _listenToAuthForPushToken();
  }

  /// Toque em notificacao leva a tela certa, nao a home.
  void _listenToNotificationRoutes() {
    final NotificationService notifications =
        ref.read(notificationServiceProvider);

    _routeSubscription = notifications.onNotificationRoute.listen(
      (String route) {
        if (route.isEmpty) return;
        ref.read(routerProvider).go(route);
      },
    );
  }

  /// Registra o token de push assim que houver sessao, e o remove ao sair.
  void _listenToAuthForPushToken() {
    _authSubscription = ref.listenManual(
      authStateProvider,
      (AsyncValue<dynamic>? previous, AsyncValue<dynamic> next) async {
        final Object? user = next.valueOrNull;
        if (user == null) return;

        // Usuário local do DevMode não tem sessão Firebase Auth — FCM e
        // Cloud Functions falhariam sem benefício no teste de UI.
        if (DevMode.isEnabled) return;

        final NotificationService notifications =
            ref.read(notificationServiceProvider);
        final bool granted = await notifications.requestPermission();
        if (!granted) return;

        final String? token = await notifications.token();
        if (token == null) return;

        await ref.read(authRepositoryProvider).registerDeviceToken(token);

        // Sequência de dias: o único gatilho correto é "há sessão
        // autenticada", que é exatamente o que este listener já observa.
        // Sem esta chamada, a Function que calcula a tolerância de um dia
        // perdido por semana nunca rodava — o streak exibido na tela de
        // conquistas ficava parado em 0 para sempre, porque nada jamais
        // avisava o servidor que o app abriu.
        try {
          await ref
              .read(firebaseFunctionsProvider)
              .httpsCallable('registerDailyActivity')
              .call();
        } catch (_) {
          // Sem streak hoje não pode impedir o uso do app.
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    unawaited(_routeSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        // Trava o tamanho de fonte num intervalo utilizavel: acima de 1.4x o
        // layout de tabelas clinicas quebra, mas cortar em 1.0 puniria quem
        // precisa de fonte maior.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Tela exibida quando o Firebase não foi configurado.
///
/// Deliberadamente independente do resto do app: não usa `ProviderScope`,
/// tema completo, roteador nem qualquer serviço que dependa do Firebase — a
/// única coisa que pode dar errado aqui é o texto não caber na tela.
class _FirebaseNotConfiguredApp extends StatelessWidget {
  const _FirebaseNotConfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pediatria 360',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF14676B),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.local_hospital_outlined,
                      size: 56,
                      color: Color(0xFF14676B),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Firebase não configurado',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Este build ainda tem as chaves de exemplo do '
                      'Pediatria 360. Configure o projeto antes de abrir '
                      'o app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F8F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SelectableText(
                        'dart pub global activate flutterfire_cli\n'
                        'flutterfire configure --project=SEU_PROJETO',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'O comando gera lib/firebase_options.dart com as '
                      'chaves reais. Nenhuma outra linha do projeto precisa '
                      'mudar — ver SETUP.md.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
