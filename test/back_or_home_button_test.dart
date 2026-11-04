import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/core/widgets/back_or_home_button.dart';

GoRouter _router(String initial) => GoRouter(
      initialLocation: initial,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.homePath,
          builder: (_, __) => const Scaffold(body: Text('inicio')),
        ),
        GoRoute(
          path: '/avulsa',
          builder: (_, __) => Scaffold(
            appBar: AppBar(leading: const BackOrHomeButton()),
            body: const Text('avulsa'),
          ),
        ),
      ],
    );

void main() {
  testWidgets('sem historico, voltar leva ao inicio', (WidgetTester t) async {
    await t.pumpWidget(MaterialApp.router(routerConfig: _router('/avulsa')));
    expect(find.text('avulsa'), findsOneWidget);

    await t.tap(find.byType(BackOrHomeButton));
    await t.pumpAndSettle();

    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('com historico, voltar desempilha', (WidgetTester t) async {
    final GoRouter router = _router(Routes.homePath);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/avulsa'));
    await t.pumpAndSettle();
    expect(find.text('avulsa'), findsOneWidget);

    await t.tap(find.byType(BackOrHomeButton));
    await t.pumpAndSettle();

    expect(find.text('inicio'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
