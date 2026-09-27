import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_growth.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/file_input.dart';
import 'package:pediatria360/shared/clinical/growth.dart';
import 'package:pediatria360/shared/clinical/lab_results.dart';
import 'package:pediatria360/shared/clinical/supplement_library.dart';

/// Crescimento, exames e suplementação do paciente na demonstração, com
/// pacientes fictícios.
void main() {
  tearDown(() => debugPickFile = null);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDemo(
    WidgetTester tester, {
    Size size = const Size(430, 932),
    DemoProfile profile = DemoProfile.profissional,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadWhoTables);
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

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
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

  Future<void> tapText(WidgetTester tester, String text, {bool last = false}) =>
      tapFinder(tester, last ? find.text(text).last : find.text(text));

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final Finder f = find.widgetWithText(TextField, label);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, value);
    await tester.pump();
  }

  Future<void> choose(WidgetTester tester, String label, String option) async {
    final Finder field = find.widgetWithText(
      DropdownButtonFormField<String>,
      label,
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester, String key) async {
    final Finder f = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pump();
  }

  Future<void> waitPdf(WidgetTester tester) async {
    for (int i = 0; i < 20 && demoSession.lastPdf == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  String today() => formatDocDate(DateTime.now());

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('curva de crescimento', () {
    testWidgets('profissional: escore Z, percentil, idade corrigida e PDF', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, size: const Size(1280, 900));
      await goTo(tester, '/pacientes/p1/crescimento');
      expect(find.text('Curva de crescimento'), findsOneWidget);
      expect(
        rich('Idade gestacional ao nascer: 34 semanas e 2 dias'),
        findsOneWidget,
      );
      expect(rich('Idade corrigida hoje: '), findsOneWidget);
      expect(find.textContaining('OMS 2006'), findsWidgets);
      expect(find.textContaining('Escore Z '), findsWidgets);
      expect(find.textContaining('percentil'), findsWidgets);
      expect(find.textContaining('- corrigida '), findsWidgets);
      expect(find.text('Corrigida'), findsWidgets);
      expect(find.text('Histórico de alterações'), findsOneWidget);
      expect(find.textContaining('Dígitos invertidos'), findsWidgets);
      expect(find.text('Nova medida'), findsOneWidget);

      for (final String chip in <String>[
        'Comprimento/altura',
        'IMC',
        'Perímetro cefálico',
      ]) {
        await tapFinder(tester, find.widgetWithText(ChoiceChip, chip));
        expect(find.textContaining('Escore Z '), findsWidgets);
      }

      await tapText(tester, 'Exportar PDF');
      await waitPdf(tester);
      final (String, List<int>, String)? pdf = demoSession.lastPdf;
      expect(pdf, isNotNull);
      expect(ascii.decode(pdf!.$2.sublist(0, 5)), '%PDF-');
      expect(pdf.$1, startsWith('curvas-luna'));
      expect(pdf.$3, 'download');

      await tapText(tester, 'Imprimir');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      expect(demoSession.lastPdf!.$3, 'print');
    });

    testWidgets('corrigir medida exige motivo e guarda o valor anterior', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final GrowthMeasurement before = demoSession.measurementById('g8')!;
      expect(before.values.weightKg, 9.5);
      await goTo(tester, '/pacientes/p1/crescimento/g8/corrigir');
      expect(find.text('Corrigir medida'), findsOneWidget);
      await fill(tester, 'Peso', '9,4');
      await tapText(tester, 'Salvar correção');
      expect(
        find.textContaining('Informe o motivo da correção.'),
        findsOneWidget,
      );
      expect(demoSession.measurementById('g8')!.values.weightKg, 9.5);

      await fill(tester, 'Motivo da correção *', 'Balança sem tara (teste)');
      await tapText(tester, 'Salvar correção');
      final GrowthMeasurement after = demoSession.measurementById('g8')!;
      expect(after.values.weightKg, 9.4);
      expect(after.revisions, hasLength(1));
      expect(after.revisions.single.before.weightKg, 9.5);
      expect(after.revisions.single.reason, 'Balança sem tara (teste)');
      expect(find.text('Curva de crescimento'), findsOneWidget);
      expect(find.textContaining('Balança sem tara (teste)'), findsWidgets);
    });

    testWidgets('nova medida entra na curva e atualiza o peso do paciente', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final int count = demoSession.growthFor('p1').length;
      await goTo(tester, '/pacientes/p1/crescimento/nova');
      await fill(tester, 'Data da medida *', today());
      await fill(tester, 'Peso', '10,6');
      expect(find.text('Prévia do cálculo'), findsOneWidget);
      await tapText(tester, 'Salvar medida');
      expect(demoSession.growthFor('p1'), hasLength(count + 1));
      expect(demoSession.patientById('p1')!.weightKg, 10.6);
      expect(find.text('Curva de crescimento'), findsOneWidget);
    });

    testWidgets('Davi acima de 5 anos usa a Referência OMS 2007', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p4/crescimento');
      expect(find.textContaining('OMS 2007'), findsWidgets);
      expect(rich('Idade cronológica hoje: '), findsOneWidget);
      expect(rich('Idade corrigida hoje: '), findsNothing);
    });

    testWidgets('responsável vê a visão simples, sem escore nem edição', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, profile: DemoProfile.responsavel);
      await goTo(tester, '/pacientes/p1/crescimento');
      expect(find.text('Crescimento'), findsWidgets);
      expect(find.text('Últimas medidas'), findsOneWidget);
      expect(find.textContaining('Escore Z'), findsNothing);
      expect(find.text('Exportar PDF'), findsNothing);
      expect(find.text('Nova medida'), findsNothing);
      expect(find.byTooltip(RegExp('^Corrigir medida')), findsNothing);

      await goTo(tester, '/pacientes/p2/crescimento');
      expect(find.text('Paciente não encontrado'), findsOneWidget);
    });

    testWidgets('recepção, financeiro e administração não abrem a curva', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      for (final DemoProfile profile in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.administrador,
      ]) {
        demoSession.enter(profile);
        await goTo(tester, '/pacientes/p1/crescimento');
        expect(find.text('Acesso restrito'), findsOneWidget);
      }
    });
  });

  group('exames laboratoriais', () {
    testWidgets(
      'laudo importado fica pendente fora do prontuário até ser conferido',
      (WidgetTester tester) async {
        await pumpDemo(tester);
        debugPickFile = (String accept) async => PickedFile(
          name: 'laudo-teste.pdf',
          mimeType: 'application/pdf',
          bytes: fictitiousLabPdf(),
        );
        await goTo(tester, '/pacientes/p1/exames');
        expect(find.text('Pendentes de conferência (1)'), findsOneWidget);
        await tapText(tester, 'Importar laudo (PDF ou imagem)');
        expect(find.text('Conferir laudo importado'), findsOneWidget);
        expect(find.textContaining('laudo-teste.pdf'), findsOneWidget);

        final LabResult pending = demoSession
            .labsFor('p1')
            .firstWhere(
              (LabResult r) => r.attachment?.name == 'laudo-teste.pdf',
            );
        expect(pending.isPending, isTrue);
        expect(pending.inRecord, isFalse);
        expect(pending.values.missing, isNotEmpty);

        await fill(tester, 'Exame *', 'Ferritina');
        await fill(tester, 'Resultado *', '22');
        await fill(tester, 'Unidade *', 'ng/mL');
        await fill(tester, 'Data da coleta *', today());
        await fill(tester, 'Laboratório *', 'Laboratório Exemplo C');
        await fill(
          tester,
          'Intervalo como no laudo',
          '15 a 160 ng/mL (laudo C)',
        );
        await fill(tester, 'Limite inferior', '15');
        await fill(tester, 'Limite superior', '160');

        await tapText(tester, 'Confirmar e liberar');
        expect(
          find.textContaining('Marque que conferiu os valores'),
          findsOneWidget,
        );
        expect(demoSession.labById(pending.id)!.isPending, isTrue);

        await tapText(tester, 'Conferi os valores com o arquivo original');
        await tapText(tester, 'Confirmar e liberar');
        final LabResult confirmed = demoSession.labById(pending.id)!;
        expect(confirmed.inRecord, isTrue);
        expect(confirmed.values.range.text, '15 a 160 ng/mL (laudo C)');
        expect(confirmed.rangePosition, RangePosition.within);
        expect(confirmed.revisions, isNotEmpty);
        expect(find.text('Abrir arquivo original'), findsOneWidget);
      },
    );

    testWidgets('arquivo que não é PDF nem imagem é recusado', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final int count = demoSession.labsFor('p1').length;
      debugPickFile = (String accept) async => PickedFile(
        name: 'planilha.csv',
        mimeType: 'text/csv',
        bytes: utf8.encode('a;b'),
      );
      await goTo(tester, '/pacientes/p1/exames');
      await tapText(tester, 'Importar laudo (PDF ou imagem)');
      expect(find.text('Envie o laudo em PDF ou imagem.'), findsOneWidget);
      expect(demoSession.labsFor('p1'), hasLength(count));
    });

    testWidgets('cada resultado mantém o intervalo do próprio laudo', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, size: const Size(1280, 900));
      await goTo(tester, '/pacientes/p1/exames/l1');
      expect(find.textContaining('7 a 140 ng/mL (laudo B)'), findsWidgets);
      expect(find.textContaining('12 a 150'), findsNothing);
      await goTo(tester, '/pacientes/p1/exames/l2');
      expect(find.textContaining('12 a 150 ng/mL (laudo A)'), findsWidgets);

      await goTo(tester, '/pacientes/p1/exames');
      await tapFinder(tester, find.widgetWithText(ChoiceChip, 'Ferritina (2)'));
      expect(find.textContaining('laudo B'), findsWidgets);
      expect(find.textContaining('laudo A'), findsWidgets);
    });

    testWidgets('corrigir valor exige motivo e mantém o histórico', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1/exames/l3/editar');
      await fill(tester, 'Resultado *', '11,0');
      await tapText(tester, 'Salvar alteração');
      expect(demoSession.labById('l3')!.values.value, '10,9');
      await fill(
        tester,
        'Motivo da correção (obrigatório se mudar valores)',
        'Erro de digitação (teste)',
      );
      await tapText(tester, 'Salvar alteração');
      final LabResult r = demoSession.labById('l3')!;
      expect(r.values.value, '11,0');
      expect(
        r.revisions.any(
          (LabRevision v) =>
              v.reason == 'Erro de digitação (teste)' &&
              v.before?.value == '10,9',
        ),
        isTrue,
      );
    });
  });

  group('suplementação do paciente', () {
    testWidgets('decisão indicada leva à calculadora e ao receituário', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, size: const Size(1280, 900));
      await goTo(tester, '/pacientes/p1/suplementacao');
      expect(find.text('Suplementação do paciente'), findsOneWidget);
      expect(find.text('Ficha em rascunho'), findsWidgets);

      await goTo(tester, '/pacientes/p1/suplementacao/ferro?consulta=c1');
      expect(find.textContaining('Acompanhar e reavaliar'), findsWidgets);
      expect(find.text('Levar à calculadora e ao receituário'), findsNothing);

      await tapFinder(
        tester,
        find.widgetWithText(ChoiceChip, 'Suplementação indicada'),
      );
      await fill(
        tester,
        'Justificativa e registro da decisão *',
        'Decisão fictícia para teste.',
      );
      await tapText(tester, 'Salvar nova versão');
      final SupplementDecision d = demoSession.decisionFor('p1', 'ferro')!;
      expect(d.versions, hasLength(2));
      expect(d.current.kind, SupplementDecisionKind.indicated);
      expect(d.current.sheetStatus, SheetStatus.draft);

      await tapText(tester, 'Levar à calculadora e ao receituário');
      expect(find.text('Calculadora de doses'), findsOneWidget);
      expect(
        find.textContaining('Origem: decisão de suplementação - Ferro'),
        findsOneWidget,
      );
      await choose(tester, 'Medicamento *', 'Suplemento Exemplo D');
      await choose(tester, 'Apresentação *', 'Gotas 10 mg/mL');
      await tester.enterText(
        find.byKey(const ValueKey<String>('duracao')),
        '30 dias',
      );
      await tester.pump();
      await check(tester, 'confirm-result');
      await check(tester, 'confirm-presentation');
      await tapText(tester, 'Inserir na receita');

      final SupplementDecision after = demoSession.decisionFor('p1', 'ferro')!;
      expect(after.prescriptionDocIds, hasLength(1));
      final ClinicalDocRecord doc = demoSession.documentById(
        after.prescriptionDocIds.single,
      )!;
      expect(doc.kind, DocKind.receituario);
      expect(doc.status, DocStatus.draft);
      expect(doc.consultationId, 'c1');
      expect(doc.current.items, hasLength(1));
    });

    testWidgets('decisão sem justificativa não é salva', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1/suplementacao/zinco');
      await tapFinder(
        tester,
        find.widgetWithText(ChoiceChip, 'Sem indicação no momento'),
      );
      await tapText(tester, 'Salvar decisão');
      expect(find.text('Registre a justificativa da decisão.'), findsOneWidget);
      expect(demoSession.decisionFor('p1', 'zinco'), isNull);
    });
  });
}
