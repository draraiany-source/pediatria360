import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/dev_mode.dart';
import 'package:pediatria360/core/theme/app_theme.dart';
import 'package:pediatria360/features/auth/presentation/providers/auth_providers.dart';
import 'package:pediatria360/features/auth/presentation/screens/login_screen.dart';
import 'package:pediatria360/features/shell/presentation/screens/home_screen.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginScreen mostra Bem-vinda e Entrar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Bem-vinda'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('HomeScreen com DevMode monta Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(DevMode.user),
          ),
          currentUserProvider.overrideWith((Ref ref) => DevMode.user),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.textContaining('Ola, ${DevMode.user.firstName}'), findsOneWidget);
    expect(find.text('Agenda'), findsWidgets);
  });
}
