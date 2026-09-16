import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pediatria360/core/config/dev_mode.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/features/auth/presentation/providers/auth_providers.dart';
import 'package:pediatria360/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';

/// Confirma que, com DevMode, a sessão local leva à Home sem tela de login.
void main() {
  testWidgets('DevMode abre Home e não a tela de login', (WidgetTester tester) async {
    expect(DevMode.isEnabled, isTrue);

    final GoRouter router = GoRouter(
      initialLocation: Routes.splashPath,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.splashPath,
          builder: (_, __) => const Scaffold(body: Text('splash')),
        ),
        GoRoute(
          path: Routes.loginPath,
          builder: (_, __) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: Routes.homePath,
          builder: (_, __) => const Scaffold(body: Text('home-dev')),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        if (!DevMode.isEnabled) return Routes.loginPath;
        if (state.matchedLocation == Routes.splashPath ||
            state.matchedLocation == Routes.loginPath) {
          return Routes.homePath;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(DevMode.user),
          ),
          onboardingSeenProvider.overrideWith((Ref ref) async => true),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home-dev'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}
