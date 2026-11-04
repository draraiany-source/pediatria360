import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_clinical.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/documents_screens.dart';
import 'package:pediatria360/shared/branding/brand_logo.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/file_input.dart';

import 'support/png_fixture.dart';

/// Logomarca própria por conta, com contas e pacientes fictícios.
void main() {
  tearDown(() => debugPickFile = null);

  Future<void> pumpDemo(
    WidgetTester tester, {
    Size size = const Size(430, 932),
    DemoProfile profile = DemoProfile.profissional,
  }) async {
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
    demoSession.enter(profile);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
  }

  Future<void> waitAsync(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await settle(tester);
    }
  }

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    for (final ScaffoldMessengerState m
        in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger),
        )) {
      m.clearSnackBars();
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey<String>(key)));

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  void offerFile(String name, Uint8List bytes, String mime) {
    debugPickFile = (String accept) async {
      expect(accept, BrandLogoRules.accept);
      return PickedFile(name: name, mimeType: mime, bytes: bytes);
    };
  }

  Future<void> upload(WidgetTester tester, String name, Uint8List bytes) async {
    offerFile(name, bytes, 'image/png');
    await tapKey(tester, 'logo-enviar');
    await waitAsync(tester);
    await tapKey(tester, 'logo-confirmar');
  }

  Finder logoImage(BrandLogo l) => find.byKey(ValueKey<String>('logo-${l.id}'));

  ClinicalDocRecord newOrientation(String title) {
    final DemoPatient p = demoSession.patientById('p1')!;
    final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
      id: demoSession.newDocumentId(),
      kind: DocKind.orientacoes,
      patientId: p.id,
      author: demoSession.currentAuthor,
      context: demoDocContext(p),
      now: DateTime.now(),
      fields: <String, String>{
        'titulo': title,
        'texto': 'Texto fictício de orientação.',
      },
    );
    demoSession.saveDocument(doc);
    return demoSession.documentById(doc.id)!;
  }

  String pdfText() => latin1.decode(demoSession.lastPdf!.$2);

  for (final (String label, Size size) in <(String, Size)>[
    ('celular', const Size(430, 932)),
    ('computador', const Size(1280, 860)),
  ]) {
    testWidgets('$label: enviar, visualizar, trocar e remover; emitido fica '
        'com a logomarca da emissão', (WidgetTester tester) async {
      await pumpDemo(tester, size: size);

      await goTo(tester, '/inicio');
      expect(
        find.byKey(const ValueKey<String>('painel-marca')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sem logomarca: painel e documentos usam'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('painel-marca')),
          matching: find.text('Pedi360'),
        ),
        findsOneWidget,
      );

      await goTo(tester, '/perfil');
      expect(find.text('Logomarca da clínica ou profissional'), findsOneWidget);
      await tapKey(tester, 'perfil-logomarca');
      expect(
        find.textContaining('Nenhuma logomarca cadastrada'),
        findsOneWidget,
      );

      // Formato recusado pelo conteúdo, com o motivo na tela.
      offerFile(
        'logo.svg',
        Uint8List.fromList(utf8.encode('<svg></svg>')),
        'image/svg+xml',
      );
      await tapKey(tester, 'logo-enviar');
      await waitAsync(tester);
      expect(find.byKey(const ValueKey<String>('logo-erro')), findsOneWidget);
      expect(find.textContaining('Formato não aceito'), findsOneWidget);
      expect(demoSession.myLogo, isNull);

      await upload(tester, 'logo-clinica-a.png', solidPng(300, 100));
      final BrandLogo first = demoSession.myLogo!;
      expect(first.fileName, 'logo-clinica-a.png');
      expect(logoImage(first), findsWidgets);
      expect(find.byKey(const ValueKey<String>('logo-erro')), findsNothing);
      expect(find.textContaining('300 x 100 px'), findsOneWidget);

      await tapKey(tester, 'logo-visualizar');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Logomarca atual'),
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Fechar');

      await goTo(tester, '/inicio');
      expect(logoImage(first), findsOneWidget);
      expect(find.textContaining('Sem logomarca'), findsNothing);

      // Documento emitido antes da logomarca continua com a identidade padrão.
      await goTo(tester, '/pacientes/p1/documentos/d1');
      expect(find.text('Identidade padrão do Pediatria360'), findsOneWidget);

      // Rascunho mostra a logomarca atual; a emissão grava essa logomarca.
      final ClinicalDocRecord doc = newOrientation('Cuidados (teste)');
      await goTo(tester, '/pacientes/p1/documentos/${doc.id}');
      expect(find.byKey(const ValueKey<String>('doc-header')), findsOneWidget);
      expect(logoImage(first), findsOneWidget);
      await tapKey(tester, 'review-check');
      await tapText(tester, 'Marcar como revisado');
      await tapText(tester, 'Emitir documento');
      expect(demoSession.documentById(doc.id)!.current.logoId, first.id);
      expect(
        find.textContaining('Logomarca da conta (logo-clinica-a.png'),
        findsOneWidget,
      );
      await tapText(tester, 'Visualizar PDF');
      await waitAsync(tester);
      expect(pdfText(), startsWith('%PDF-'));
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(pdfText()), isTrue);
      expect(RegExp(r'/Width\s*300\b').hasMatch(pdfText()), isTrue);

      // Trocar: o emitido mantém a anterior; o PDF também.
      await goTo(tester, '/perfil/logomarca');
      offerFile(
        'logo-clinica-a-v2.png',
        solidPng(400, 100, r: 200),
        'image/png',
      );
      await tapKey(tester, 'logo-enviar');
      await waitAsync(tester);
      expect(find.text('Trocar a logomarca?'), findsOneWidget);
      await tapKey(tester, 'logo-confirmar');
      final BrandLogo second = demoSession.myLogo!;
      expect(second.id, isNot(first.id));
      expect(logoImage(second), findsWidgets);

      await goTo(tester, '/pacientes/p1/documentos/${doc.id}');
      expect(logoImage(first), findsOneWidget);
      expect(logoImage(second), findsNothing);
      await tapText(tester, 'Imprimir');
      await waitAsync(tester);
      expect(RegExp(r'/Width\s*300\b').hasMatch(pdfText()), isTrue);
      expect(RegExp(r'/Width\s*400\b').hasMatch(pdfText()), isFalse);

      // Remover: próximos documentos voltam à identidade padrão.
      await goTo(tester, '/perfil/logomarca');
      await tapKey(tester, 'logo-remover');
      expect(find.text('Remover logomarca?'), findsOneWidget);
      await tapKey(tester, 'logo-remover-confirmar');
      expect(demoSession.myLogo, isNull);
      expect(
        find.textContaining('Nenhuma logomarca cadastrada'),
        findsOneWidget,
      );

      await goTo(tester, '/pacientes/p1/documentos/${doc.id}');
      expect(logoImage(first), findsOneWidget);
      final ClinicalDocRecord other = newOrientation('Outro (teste)');
      await goTo(tester, '/pacientes/p1/documentos/${other.id}');
      expect(find.text('Identidade padrão do Pediatria360'), findsOneWidget);
      await tapText(tester, 'Gerar PDF');
      await waitAsync(tester);
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(pdfText()), isFalse);

      await goTo(tester, '/inicio');
      expect(find.textContaining('Sem logomarca'), findsOneWidget);
    });
  }

  testWidgets('a logomarca de uma conta não aparece para outra', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    final BrandLogo mine = demoSession.uploadLogo(
      bytes: solidPng(300, 100),
      fileName: 'logo-conta-a.png',
    );
    final ClinicalDocRecord docA = newOrientation('Da conta A');

    await goTo(tester, '/perfil');
    await tapKey(tester, 'trocar-conta');
    await tapKey(tester, 'conta-${DemoProfessional.colleague.id}');
    expect(demoSession.account.id, DemoProfessional.colleague.id);
    expect(demoSession.myLogo, isNull);
    expect(find.text('Dr. Exemplo Colega'), findsOneWidget);

    await goTo(tester, '/inicio');
    expect(find.text('Clínica Exemplo Dois (fictícia)'), findsOneWidget);
    expect(find.textContaining('Sem logomarca'), findsOneWidget);
    expect(logoImage(mine), findsNothing);

    await goTo(tester, '/perfil/logomarca');
    expect(find.textContaining('Nenhuma logomarca cadastrada'), findsOneWidget);
    expect(logoImage(mine), findsNothing);

    // Documentos e modelos da outra conta não abrem.
    expect(demoSession.documentsFor('p1'), isEmpty);
    await goTo(tester, '/pacientes/p1/documentos/${docA.id}');
    expect(find.text('Registro não encontrado'), findsOneWidget);
    expect(logoImage(mine), findsNothing);
    await goTo(tester, '/modelos-receita');
    expect(find.text('0 de 0 modelos'), findsOneWidget);

    // A conta B envia a sua; cada conta vê só a própria.
    await goTo(tester, '/perfil/logomarca');
    await upload(tester, 'logo-conta-b.png', solidPng(200, 200, g: 10));
    final BrandLogo theirs = demoSession.myLogo!;
    expect(theirs.ownerId, DemoProfessional.colleague.id);

    demoSession.switchAccount(DemoProfessional.id);
    await goTo(tester, '/inicio');
    expect(logoImage(mine), findsOneWidget);
    expect(logoImage(theirs), findsNothing);
    await goTo(tester, '/pacientes/p1/documentos/${docA.id}');
    expect(logoImage(mine), findsOneWidget);
    expect(logoImage(theirs), findsNothing);
  });

  testWidgets(
    'recepção e responsável não têm logomarca nem veem a da clínica',
    (WidgetTester tester) async {
      await pumpDemo(tester);
      final BrandLogo logo = demoSession.uploadLogo(
        bytes: solidPng(300, 100),
        fileName: 'logo-conta-a.png',
      );

      for (final DemoProfile p in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.responsavel,
      ]) {
        demoSession.enter(p);
        await goTo(tester, '/perfil/logomarca');
        expect(find.text('Acesso restrito'), findsOneWidget, reason: p.name);
        await goTo(tester, '/perfil');
        expect(
          find.byKey(const ValueKey<String>('perfil-logomarca')),
          findsNothing,
        );
        await goTo(tester, '/inicio');
        expect(
          find.byKey(const ValueKey<String>('painel-marca')),
          findsNothing,
        );
        expect(logoImage(logo), findsNothing);
        expect(demoSession.myLogo, isNull);
      }
    },
  );
}
