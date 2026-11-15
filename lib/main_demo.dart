import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'demo/demo_router.dart';

/// Ponto de entrada da DEMONSTRACAO web (homologacao visual).
///
/// Nao inicializa Firebase, autenticacao, IA, pagamentos nem armazenamento:
/// so importa tema, widgets de apresentacao e `lib/demo/`. O teste
/// `test/demo_isolation_test.dart` falha se alguma importacao desse grafo
/// passar a alcancar Firebase ou `lib/features/`.
///
/// Build: flutter build web -t lib/main_demo.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pediatria 360 - Demonstração',
      debugShowCheckedModeBanner: false,
      routerConfig: demoRouter,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
