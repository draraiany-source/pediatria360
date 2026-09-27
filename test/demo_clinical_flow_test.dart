import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/documents_screens.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';

/// Fluxos da área do profissional na demonstração, com pacientes fictícios.
void main() {
  Future<void> pumpDemo(
    WidgetTester tester, {
    Size size = const Size(430, 932),
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
    demoSession.enter(DemoProfile.profissional);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    // Telas empilhadas abaixo (lista de pacientes) terminam o carregamento
    // simulado depois da transição.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
  }

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool last = false,
  }) async {
    for (final ScaffoldMessengerState m
        in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger),
        )) {
      m.clearSnackBars();
    }
    await tester.pumpAndSettle();
    final Finder f = last ? find.text(text).last : find.text(text);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
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

  FilledButton filled(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
        ),
      );

  group('calculadora', () {
    testWidgets('mg/kg/dose e conversão mg -> mL com as duas conferências', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/calculadora?paciente=p1');
      expect(find.textContaining('10,2 kg em'), findsOneWidget);

      await choose(tester, 'Medicamento *', 'Medicamento Exemplo A');
      await choose(tester, 'Apresentação *', 'Suspensão 100 mg/5 mL');
      expect(find.text('7,7 mL por dose'), findsOneWidget);
      expect(find.text('153 mg'), findsOneWidget);
      expect(find.text('612 mg/dia'), findsOneWidget);
      expect(
        find.textContaining('15 mg/kg/dose × 10,2 kg = 153 mg por dose'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '153 mg ÷ 20 mg/mL (Suspensão 100 mg/5 mL) = 7,65 mL por dose',
        ),
        findsOneWidget,
      );

      const String insert = 'Inserir em novo receituário';
      expect(filled(tester, insert).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey<String>('duracao')),
        '5 dias',
      );
      await tester.pump();
      expect(
        filled(tester, insert).onPressed,
        isNull,
        reason: 'faltam as conferências',
      );
      await check(tester, 'confirm-result');
      expect(
        filled(tester, insert).onPressed,
        isNull,
        reason: 'falta conferir a apresentação',
      );
      await check(tester, 'confirm-presentation');
      expect(filled(tester, insert).onPressed, isNotNull);

      final int before = demoSession.documentsFor('p1').length;
      await tapText(tester, insert);
      final List<ClinicalDocRecord> docs = demoSession.documentsFor('p1');
      expect(docs.length, before + 1);
      final ClinicalDocRecord rx = docs.first;
      expect(rx.kind, DocKind.receituario);
      expect(rx.status, DocStatus.draft, reason: 'inserir não emite nada');
      expect(rx.current.items.single.dose, '7,7 mL (153 mg) por dose');
      expect(rx.current.items.single.frequency, 'de 6/6h');
      expect(find.text('Editar: Receituário'), findsOneWidget);
    });

    testWidgets('mg/kg/dia divide a dose diária pelas tomadas', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/calculadora?paciente=p5');
      await choose(tester, 'Medicamento *', 'Medicamento Exemplo B');
      await choose(tester, 'Apresentação *', 'Suspensão 250 mg/5 mL');
      expect(
        find.textContaining('40 mg/kg/dia × 12,8 kg = 512 mg/dia'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '512 mg/dia ÷ 2 doses (de 12/12h) = 256 mg por dose',
        ),
        findsOneWidget,
      );
      expect(find.text('5,1 mL por dose'), findsOneWidget);
    });

    testWidgets('dose acima do máximo bloqueia; limitar exige ciência', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/calculadora?paciente=p4');
      await choose(tester, 'Medicamento *', 'Medicamento Exemplo A');
      await choose(tester, 'Apresentação *', 'Suspensão 100 mg/5 mL');
      await tester.enterText(find.byKey(const ValueKey<String>('mgkg')), '16');
      await tester.pump();
      expect(find.textContaining('acima do máximo de 500 mg'), findsOneWidget);
      expect(find.textContaining('Impede a inserção'), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey<String>('duracao')),
        '3 dias',
      );
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey<String>('confirm-result')),
            )
            .onChanged,
        isNull,
      );

      await tapText(tester, 'Limitar à dose máxima da referência');
      expect(find.text('Limitado à dose máxima'), findsOneWidget);
      expect(find.text('25 mL por dose'), findsOneWidget);
      expect(find.textContaining('fora da faixa configurada'), findsOneWidget);
      await check(tester, 'confirm-result');
      await check(tester, 'confirm-presentation');
      expect(
        filled(tester, 'Inserir em novo receituário').onPressed,
        isNull,
        reason: 'alertas de atenção ainda sem ciência',
      );
      final Finder ack = find.text('Estou ciente e mantenho a conduta');
      expect(
        ack,
        findsNWidgets(3),
        reason: 'limitada, fora da faixa e volume acima',
      );
      for (int i = 0; i < 3; i++) {
        await tester.ensureVisible(ack.at(i));
        await tester.pumpAndSettle();
        await tester.tap(ack.at(i));
        await tester.pump();
      }
      expect(
        filled(tester, 'Inserir em novo receituário').onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'dados ausentes, referência não validada, alergia e idade bloqueiam',
      (WidgetTester tester) async {
        await pumpDemo(tester);
        await goTo(tester, '/calculadora?paciente=p3');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo A');
        await choose(tester, 'Apresentação *', 'Suspensão 100 mg/5 mL');
        expect(find.text('Cálculo bloqueado'), findsOneWidget);
        expect(find.textContaining('Peso não registrado.'), findsOneWidget);

        await goTo(tester, '/calculadora?paciente=p1');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo C');
        expect(find.textContaining('ainda não foi validada'), findsOneWidget);
        expect(find.textContaining('não informa a fonte'), findsOneWidget);

        await goTo(tester, '/calculadora?paciente=p4');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo B');
        await choose(tester, 'Apresentação *', 'Suspensão 250 mg/5 mL');
        expect(find.textContaining('Alergia registrada'), findsOneWidget);

        await goTo(tester, '/calculadora?paciente=p1');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo B');
        await choose(tester, 'Apresentação *', 'Suspensão 250 mg/5 mL');
        expect(find.textContaining('restrição de idade'), findsOneWidget);

        await goTo(tester, '/calculadora?paciente=p2');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo A');
        await choose(tester, 'Apresentação *', 'Suspensão 100 mg/5 mL');
        expect(
          find.textContaining('Considere pesar novamente'),
          findsOneWidget,
        );

        await goTo(tester, '/calculadora?paciente=p1');
        await choose(tester, 'Medicamento *', 'Medicamento Exemplo A');
        await choose(tester, 'Apresentação *', 'Comprimido 500 mg');
        expect(find.textContaining('não é adequada para'), findsOneWidget);
      },
    );
  });

  group('documentos', () {
    const Map<DocKind, Map<String, String>> fill =
        <DocKind, Map<String, String>>{
          DocKind.atestado: <String, String>{},
          DocKind.comparecimento: <String, String>{
            'horaInicio': '08:00',
            'horaFim': '09:00',
          },
          DocKind.encaminhamento: <String, String>{
            'especialidade': 'Especialidade Exemplo',
            'motivo': 'Motivo fictício',
            'resumo': 'Resumo clínico fictício',
            'exames': 'Exame exemplo',
            'tratamentos': 'Tratamento exemplo',
          },
          DocKind.orientacoes: <String, String>{
            'titulo': 'Cuidados',
            'texto': 'Texto fictício de orientação.',
          },
          DocKind.exames: <String, String>{
            'exames': 'Exame A\nExame B',
            'indicacao': 'Indicação fictícia',
          },
          DocKind.receituario: <String, String>{},
        };

    for (final DocKind kind in DocKind.values) {
      testWidgets(
        '${kind.label}: preencher, revisar, emitir, PDF, imprimir e histórico',
        (WidgetTester tester) async {
          await pumpDemo(tester);
          await goTo(tester, '/pacientes/p2/documentos/novo?tipo=${kind.slug}');
          expect(find.text('Novo: ${kind.label}'), findsOneWidget);
          for (final MapEntry<String, String> e in fill[kind]!.entries) {
            final Finder f = find.byKey(ValueKey<String>('campo-${e.key}'));
            await tester.ensureVisible(f);
            await tester.enterText(f, e.value);
            await tester.pump();
          }
          if (kind == DocKind.receituario) {
            await tapText(tester, 'Adicionar item manualmente');
            final List<String> values = <String>[
              'Medicamento Exemplo A',
              'Suspensão 100 mg/5 mL',
              '5 mL',
              'via oral',
              'de 8/8h',
              '3 dias',
              '',
            ];
            final Finder fields = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            );
            for (int i = 0; i < values.length; i++) {
              await tester.enterText(fields.at(i), values[i]);
            }
            await tester.tap(find.text('Salvar item'));
            await settle(tester);
            expect(find.text('Manual'), findsOneWidget);
          }
          await tapText(tester, 'Salvar e revisar');

          final ClinicalDocRecord doc = demoSession.documentsFor('p2').first;
          expect(doc.kind, kind);
          expect(doc.status, DocStatus.draft);
          expect(doc.current.author, demoSession.currentAuthor);
          expect(
            doc.pendingIssues,
            isEmpty,
            reason: doc.pendingIssues.join('; '),
          );
          expect(
            find.text('Emitir documento'),
            findsNothing,
            reason: 'emitir só depois de revisar',
          );
          expect(filled(tester, 'Marcar como revisado').onPressed, isNull);
          await check(tester, 'review-check');
          await tapText(tester, 'Marcar como revisado');
          expect(demoSession.documentById(doc.id)!.status, DocStatus.reviewed);
          await tapText(tester, 'Emitir documento');
          final ClinicalDocRecord issued = demoSession.documentById(doc.id)!;
          expect(issued.status, DocStatus.issued);
          expect(issued.signature.isSigned, isFalse);
          expect(find.text('Não assinado'), findsWidgets);
          expect(find.textContaining('Assinado digitalmente'), findsNothing);

          await tapText(tester, 'Gerar PDF');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await settle(tester);
          final (String, List<int>, String)? pdf = demoSession.lastPdf;
          expect(pdf, isNotNull);
          expect(ascii.decode(pdf!.$2.sublist(0, 5)), '%PDF-');
          expect(pdf.$1, startsWith('${kind.slug}-theo-v1'));
          expect(pdf.$3, 'download');
          await tapText(tester, 'Imprimir');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await settle(tester);
          expect(demoSession.lastPdf!.$3, 'print');

          await tapText(tester, 'Voltar aos documentos');
          expect(find.text(issued.title), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(DemoDocTile),
              matching: find.text(issued.title),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('v1 · ${demoSession.currentAuthor}'),
            findsWidgets,
          );
        },
      );
    }

    testWidgets(
      'editar documento emitido cria nova versão e mantém a anterior',
      (WidgetTester tester) async {
        await pumpDemo(tester);
        await goTo(tester, '/pacientes/p1/documentos/d1');
        expect(find.text('v1 · Emitido'), findsOneWidget);
        expect(find.text('v2 · Emitido'), findsOneWidget);
        await tapText(tester, 'Criar nova versão');
        expect(find.textContaining('Salvar cria a versão 3'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey<String>('campo-dias')),
          '3',
        );
        await tester.pump();
        await tapText(tester, 'Salvar rascunho');
        final ClinicalDocRecord d = demoSession.documentById('d1')!;
        expect(d.versions.length, 3);
        expect(d.versions[1].status, DocStatus.issued);
        expect(d.current.status, DocStatus.draft);
        expect(d.current.body, contains('por 3 dias'));
        expect(d.versions[1].body, contains('por 2 dias'));
      },
    );

    testWidgets(
      'orientação: modelo personalizado exige edição e vira novo modelo',
      (WidgetTester tester) async {
        await pumpDemo(tester);
        await goTo(tester, '/pacientes/p1/documentos/novo?tipo=orientacoes');
        await tester.tap(find.text('Aplicar').first);
        await settle(tester);
        final TextField texto = tester.widget<TextField>(
          find.byKey(const ValueKey<String>('campo-texto')),
        );
        expect(texto.controller!.text, contains('Luna Exemplo Souza'));
        expect(texto.controller!.text, contains('Responsável Exemplo A'));
        expect(
          find.textContaining('Há campos entre colchetes a preencher'),
          findsOneWidget,
        );

        final int before = demoSession.orientationTemplates.length;
        await tapText(tester, 'Salvar texto atual como modelo');
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Meu modelo',
        );
        await tester.tap(find.text('Salvar modelo'));
        await settle(tester);
        expect(demoSession.orientationTemplates.length, before + 1);
        final String body = demoSession.orientationTemplates.first.body;
        expect(body, contains('{{crianca}}'));
        expect(body, isNot(contains('Luna')));
      },
    );

    testWidgets('encaminhamento pendente não pode ser revisado', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1/documentos/d2');
      expect(find.textContaining('Resumo clínico obrigatório'), findsNothing);
      expect(find.textContaining('Resolva no editor'), findsNothing);
      final ClinicalDocRecord d = demoSession.documentById('d2')!;
      expect(d.pendingIssues, isEmpty);
    });
  });

  testWidgets('consulta: etapas, peso, rascunho, documentos e finalização', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await goTo(tester, '/pacientes/p3/prontuario');
    await tapText(tester, 'Nova consulta');
    expect(find.textContaining('Consulta · Rascunho'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo da consulta *'),
      'Motivo fictício',
    );
    await tapText(tester, 'Próximo');
    await tester.enterText(find.byKey(const ValueKey<String>('peso')), '8,4');
    await tester.enterText(
      find.widgetWithText(TextField, 'Avaliação *'),
      'Avaliação fictícia',
    );
    await tapText(tester, 'Salvar rascunho');
    expect(demoSession.patientById('p3')!.weightKg, 8.4);
    await tapText(tester, 'Voltar');
    expect(
      find.widgetWithText(TextField, 'Motivo da consulta *'),
      findsOneWidget,
    );
    await tapText(tester, 'Próximo');
    await tapText(tester, 'Próximo');
    await tapText(tester, 'Próximo');
    expect(find.text('Criar documento'), findsOneWidget);
    await tapText(tester, 'Finalizar consulta');
    expect(find.textContaining('preencha: Conduta'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Conduta *'),
      'Conduta fictícia',
    );
    await tapText(tester, 'Próximo');
    await tapText(tester, 'Atestado médico');
    expect(find.text('Novo: Atestado médico'), findsOneWidget);
    await tapText(tester, 'Salvar e revisar');
    final ClinicalDocRecord doc = demoSession.documentsFor('p3').first;
    expect(doc.consultationId, isNotNull);
    await tapText(tester, 'Voltar à consulta');
    expect(find.text(doc.title), findsWidgets);
    await tapText(tester, 'Finalizar consulta');
    await tapText(tester, 'Finalizar', last: true);
    expect(find.text('Prontuário'), findsOneWidget);
    expect(demoSession.consultationById(doc.consultationId!)!.isDraft, isFalse);
  });

  testWidgets(
    'biblioteca de suplementação: 17 temas em rascunho e validação exige campos',
    (WidgetTester tester) async {
      await pumpDemo(tester, size: const Size(1280, 900));
      await goTo(tester, '/suplementacao');
      expect(find.textContaining('17 temas · 0 validados'), findsOneWidget);
      await tapText(tester, 'Ferro');
      expect(
        find.textContaining('RASCUNHO - não usar como conduta'),
        findsOneWidget,
      );
      expect(find.text('Não preenchido'), findsNWidgets(9));
      await tapText(tester, 'Editar ficha');
      await tapText(tester, 'Validar ficha');
      expect(find.textContaining('Para validar, faltam'), findsOneWidget);
      expect(demoSession.sheetById('ferro')!.isDraft, isTrue);
    },
  );

  testWidgets(
    'perfis sem permissão não abrem consulta, documentos, calculadora nem suplementação',
    (WidgetTester tester) async {
      await pumpDemo(tester);
      for (final DemoProfile profile in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.administrador,
        DemoProfile.responsavel,
      ]) {
        demoSession.enter(profile);
        for (final String path in <String>[
          '/calculadora',
          '/suplementacao',
          '/suplementacao/ferro',
          '/pacientes/p1/documentos',
          '/pacientes/p1/documentos/d1',
          '/pacientes/p1/documentos/novo?tipo=receituario',
          '/pacientes/p1/consulta/c1',
        ]) {
          await goTo(tester, path);
          expect(
            find.text('Acesso restrito'),
            findsOneWidget,
            reason: '${profile.name} em $path',
          );
        }
      }
    },
  );
}
