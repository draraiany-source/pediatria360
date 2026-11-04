import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';

/// Percorre a demonstracao como um avaliador faria. Usa tema padrao para
/// nao depender do download de fontes do Google durante o teste.
void main() {
  Future<void> pumpDemo(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    demoSession.leave();
    demoRouter.go('/');
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: demoRouter,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
  }

  for (final Size size in const <Size>[Size(320, 640), Size(430, 932), Size(1280, 800)]) {
    testWidgets('perfis e telas abrem sem erro de layout em $size',
        (WidgetTester tester) async {
      await pumpDemo(tester, size);
      expect(find.textContaining('DEMONSTRAÇÃO'), findsOneWidget);

      for (final DemoProfile profile in DemoProfile.values) {
        await goTo(tester, '/');
        await tester.ensureVisible(find.text(profile.label));
        await tester.tap(find.text(profile.label));
        await settle(tester);
        expect(demoSession.profile, profile);
        expect(find.text(profile.label), findsWidgets);
        for (final DemoModule m in demoSession.modules) {
          await goTo(tester, m.path);
          expect(find.text('Acesso restrito'), findsNothing,
              reason: '${profile.name} deveria abrir ${m.path}');
          expect(find.textContaining('DEMONSTRAÇÃO'), findsOneWidget);
        }
      }
    });
  }

  testWidgets('perfil sem permissao vê Acesso restrito ao digitar a rota',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.recepcao);
    await goTo(tester, '/pacientes/p1/prontuario');
    expect(find.text('Acesso restrito'), findsOneWidget);
    await goTo(tester, '/financeiro');
    expect(find.text('Acesso restrito'), findsOneWidget);

    demoSession.enter(DemoProfile.financeiro);
    await goTo(tester, '/pacientes');
    expect(find.text('Acesso restrito'), findsOneWidget);
  });

  testWidgets('responsável só vê as proprias crianças',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.responsavel);
    await goTo(tester, '/pacientes');
    expect(find.text('Luna Exemplo Souza'), findsOneWidget);
    expect(find.text('Theo Exemplo Lima'), findsNothing);
    await goTo(tester, '/pacientes/p2');
    expect(find.text('Paciente não encontrado'), findsOneWidget);
  });

  testWidgets('lista -> detalhe -> prontuário e volta pelo botão da barra',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    await tester.tap(find.text('Profissional de saúde'));
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Pacientes'),
    ));
    await settle(tester);
    await tester.tap(find.text('Luna Exemplo Souza'));
    await settle(tester);
    expect(find.text('Responsável: Responsável Exemplo A'), findsOneWidget);
    await tester.tap(find.text('Prontuário'));
    await settle(tester);
    expect(find.text('Nova evolução'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Responsável: Responsável Exemplo A'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Buscar por nome'), findsOneWidget);
  });

  testWidgets('rascunho simulado exige revisão antes de confirmar',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.profissional);
    await goTo(tester, '/pacientes/p1/prontuario/nova');

    await tester.tap(find.text('Inserir rascunho simulado'));
    await settle(tester);
    final Finder confirm =
        find.widgetWithText(FilledButton, 'Confirmar evolução');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    final int before = demoSession.encounters.length;
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(find.textContaining('Revise o rascunho'), findsOneWidget);
    expect(demoSession.encounters.length, before,
        reason: 'Rascunho com campos a preencher não pode ser registrado.');
  });

  testWidgets('cadastro valida campos e avisa antes de descartar',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.profissional);
    await goTo(tester, '/pacientes/novo');

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    expect(find.text('Informe a data de nascimento.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Teste');
    await tester.pump();
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cadastro?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Teste'), findsOneWidget);
  });

  testWidgets('falha de conexão simulada mostra erro e recupera',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.profissional);
    demoSession.setSimulateOffline(true);
    await goTo(tester, '/biblioteca');
    expect(find.text('Recarregar'), findsOneWidget);

    demoSession.setSimulateOffline(false);
    await tester.tap(find.text('Recarregar'));
    await settle(tester);
    expect(find.text('Recarregar'), findsNothing);
    expect(find.textContaining('Rotina de sono'), findsOneWidget);
  });

  testWidgets('sair da demonstração volta para a escolha de perfil',
      (WidgetTester tester) async {
    await pumpDemo(tester, const Size(430, 932));
    demoSession.enter(DemoProfile.profissional);
    await goTo(tester, '/perfil');
    await tester.ensureVisible(find.text('Sair da demonstração'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da demonstração'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await settle(tester);
    expect(demoSession.profile, isNull);
    expect(find.text('Entrar como'), findsOneWidget);
  });
}
