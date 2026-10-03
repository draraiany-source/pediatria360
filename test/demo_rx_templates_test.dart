import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/documents_screens.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/dose_calculator.dart';
import 'package:pediatria360/shared/clinical/rx_templates.dart';

/// "Meus modelos de receita" na demonstração, com pacientes fictícios.
void main() {
  Future<void> pumpDemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
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
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
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

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey<String>(key)));

  Future<void> type(WidgetTester tester, String key, String text) async {
    final Finder f = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
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

  Future<void> waitPdf(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
  }

  String expectedDose(DemoPatient p, String refId, String presId) {
    final DoseReference ref = demoSession.doseReferences.firstWhere(
      (DoseReference r) => r.id == refId,
    );
    return PediatricDoseCalculator.calculate(
      reference: ref,
      presentation: ref.presentations.firstWhere(
        (DrugPresentation x) => x.id == presId,
      ),
      patient: DosePatientData(
        weightKg: p.weightKg,
        weighedAt: p.weighedAt,
        birthDate: p.birthDate,
      ),
      now: DateTime.now(),
    ).perAdministrationLabel;
  }

  testWidgets('lista, busca, duplicar e editar cria nova versão', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await goTo(tester, '/modelos-receita');
    expect(find.text('Meus modelos de receita'), findsOneWidget);
    expect(find.text('Febre - Medicamento Exemplo A'), findsOneWidget);
    expect(find.text('Suplemento D + lavagem nasal'), findsOneWidget);

    await type(tester, 'busca-modelo', 'solucao nasal');
    expect(find.text('Suplemento D + lavagem nasal'), findsOneWidget);
    expect(find.text('Febre - Medicamento Exemplo A'), findsNothing);
    await type(tester, 'busca-modelo', 'tosse');
    expect(find.text('Nenhum modelo encontrado.'), findsOneWidget);
    await type(tester, 'busca-modelo', '');

    await tapKey(tester, 'duplicar-m1');
    expect(find.text('Editar modelo de receita'), findsOneWidget);
    final RxTemplate copy = demoSession.rxTemplates.first;
    expect(copy.name, 'Cópia de Febre - Medicamento Exemplo A');
    expect(copy.id, isNot('m1'));

    await type(tester, 'modelo-nome', 'Febre - revisado (teste)');
    await type(tester, 'modelo-nota', 'Duração ajustada');
    await tapText(tester, 'Salvar modelo');
    final RxTemplate saved = demoSession.rxTemplateById(copy.id)!;
    expect(saved.current.number, 2);
    expect(saved.name, 'Febre - revisado (teste)');
    expect(saved.current.note, 'Duração ajustada');
    expect(demoSession.rxTemplateById('m1')!.current.number, 1);
    expect(find.text('Febre - revisado (teste)'), findsOneWidget);
  });

  testWidgets('novo modelo: item pelo peso (só mg/kg) e item de dose fixa', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await goTo(tester, '/modelos-receita/novo');
    final int before = demoSession.rxTemplates.length;
    await tapText(tester, 'Salvar modelo');
    expect(demoSession.rxTemplates.length, before);
    expect(find.textContaining('Dê um nome ao modelo'), findsWidgets);

    await type(tester, 'modelo-nome', 'Modelo novo (teste)');
    await tapText(tester, 'Adicionar item');
    await choose(tester, 'Referência de dose *', 'Medicamento Exemplo B');
    await choose(tester, 'Apresentação *', 'Suspensão 250 mg/5 mL');
    expect(find.text('Frequência da referência: de 12/12h'), findsOneWidget);
    await type(tester, 'item-duration', '7 dias');
    await type(tester, 'item-quantity', '1 frasco');
    await tapText(tester, 'Salvar item');
    expect(find.textContaining('40 mg/kg/dia, recalculada'), findsOneWidget);

    await tapText(tester, 'Adicionar item');
    await tapText(tester, 'Fixa');
    await type(tester, 'item-drug', 'Solução Exemplo F (fictícia)');
    await type(tester, 'item-presentation', 'Solução nasal');
    await type(tester, 'item-concentration', '0,9%');
    await type(tester, 'item-dose', '1 jato em cada narina');
    await type(tester, 'item-volume', 'não se aplica');
    await type(tester, 'item-frequency', '3 vezes ao dia');
    await type(tester, 'item-route', 'via nasal');
    await type(tester, 'item-duration', '5 dias');
    await type(tester, 'item-quantity', '1 frasco');
    await tapText(tester, 'Salvar item');
    await type(tester, 'modelo-orientacoes', 'Lavar as mãos de {{crianca}}.');
    await tapText(tester, 'Salvar modelo');

    final RxTemplate t = demoSession.rxTemplates.firstWhere(
      (RxTemplate x) => x.name == 'Modelo novo (teste)',
    );
    expect(t.items.length, 2);
    expect(t.items[0].mode, RxDoseMode.weight);
    expect(t.items[0].referenceId, 'ref-b');
    expect(t.items[0].mgPerKg, 40);
    expect(t.items[1].mode, RxDoseMode.fixed);
    expect(t.items[1].fixedDose, '1 jato em cada narina');
    expect(t.orientations, 'Lavar as mãos de {{crianca}}.');
  });

  testWidgets('na consulta: modelo gera rascunho com o peso atual, exige '
      'conferência, emite no histórico e não muda se o modelo for editado', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    final DemoPatient alice = demoSession.patientById('p5')!;
    await goTo(tester, '/pacientes/p5/consulta/c2?etapa=documentos');
    await tapText(tester, 'Receita a partir de modelo');
    expect(find.text('Escolher modelo de receita'), findsOneWidget);
    await tapText(tester, 'Febre - Medicamento Exemplo A');

    final ClinicalDocRecord draft = demoSession.documentsFor('p5').first;
    expect(draft.kind, DocKind.receituario);
    expect(draft.consultationId, 'c2');
    expect(draft.status, DocStatus.draft);
    final RxItem item = draft.current.items.single;
    final String dose = expectedDose(alice, 'ref-a', 'a-susp');
    expect(item.dose, dose);
    expect(item.weightDosing!.weightKg, alice.weightKg);
    expect(
      item.calculation,
      contains('× ${formatDoseNumber(alice.weightKg!)} kg'),
    );
    expect(item.calculation, contains(alice.name));
    expect(draft.current.fields['orientacoes'], contains(alice.name));
    expect(find.text('Editar: Receituário'), findsOneWidget);
    expect(find.text('Conferência do item (0 de 9)'), findsOneWidget);
    expect(find.text('Conta com o peso deste paciente'), findsOneWidget);

    await tapText(tester, 'Salvar e revisar');
    expect(
      find.textContaining('confira medicamento, apresentação'),
      findsOneWidget,
    );
    final CheckboxListTile review = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey<String>('review-check')),
    );
    expect(review.onChanged, isNull, reason: 'sem conferência, sem revisão');

    await goTo(tester, '/pacientes/p5/documentos/${draft.id}/editar');
    for (final RxCheck c in item.requiredChecks) {
      await tapKey(tester, 'conf-0-${c.name}');
    }
    expect(find.text('Conferência do item (9 de 9)'), findsOneWidget);
    await tapText(tester, 'Salvar e revisar');
    await tapKey(tester, 'review-check');
    await tapText(tester, 'Marcar como revisado');
    await tapText(tester, 'Emitir documento');
    final ClinicalDocRecord issued = demoSession.documentById(draft.id)!;
    expect(issued.status, DocStatus.issued);
    expect(issued.current.body, contains(dose));
    expect(
      find.textContaining('Modelo "Febre - Medicamento Exemplo A" · v1'),
      findsWidgets,
    );

    await tapText(tester, 'Visualizar PDF');
    await waitPdf(tester);
    expect(demoSession.lastPdf!.$3, 'view');
    expect(ascii.decode(demoSession.lastPdf!.$2.sublist(0, 5)), '%PDF-');
    await tapText(tester, 'Imprimir');
    await waitPdf(tester);
    expect(demoSession.lastPdf!.$3, 'print');

    await goTo(tester, '/pacientes/p5/consulta/c2?etapa=documentos');
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is DemoDocTile && w.doc.id == issued.id,
      ),
      findsOneWidget,
    );

    final String body = issued.current.body;
    await goTo(tester, '/modelos-receita/m1/editar');
    await type(tester, 'modelo-orientacoes', 'Orientação nova do modelo.');
    await tapText(tester, 'Salvar modelo');
    expect(demoSession.rxTemplateById('m1')!.current.number, 2);
    final ClinicalDocRecord after = demoSession.documentById(issued.id)!;
    expect(after.current.body, body);
    expect(after.current.body, isNot(contains('Orientação nova')));
    expect(after.current.items.single.origin, contains('v1'));
  });

  testWidgets('outra criança: dose refeita com o peso dela; peso novo exige '
      'recalcular', (WidgetTester tester) async {
    await pumpDemo(tester);
    await goTo(tester, '/modelos-receita?paciente=p4');
    await tapKey(tester, 'usar-m1');
    final DemoPatient davi = demoSession.patientById('p4')!;
    final ClinicalDocRecord d = demoSession.documentsFor('p4').first;
    final RxItem it = d.current.items.single;
    expect(it.dose, expectedDose(davi, 'ref-a', 'a-susp'));
    expect(it.alerts.join(), contains('Volume por dose'));
    expect(it.requiredChecks, contains(RxCheck.alerts));

    demoSession.updateWeight(davi, 33, DateTime.now());
    await goTo(tester, '/pacientes/p4/documentos/${d.id}/editar');
    expect(find.textContaining('O peso mudou'), findsOneWidget);
    expect(find.textContaining('Recalcule'), findsWidgets);
    await tapKey(tester, 'recalc-0');
    await tapText(tester, 'Salvar rascunho');
    final RxItem again = demoSession.documentById(d.id)!.current.items.single;
    expect(again.weightDosing!.weightKg, 33);
    expect(again.dose, '24,8 mL (495 mg) por dose');
    expect(again.checked, isEmpty);

    demoSession.updateWeight(davi, 34, DateTime.now());
    await tester.pumpAndSettle();
    await tapKey(tester, 'recalc-0');
    await tapText(tester, 'Salvar rascunho');
    final RxItem over = demoSession.documentById(d.id)!.current.items.single;
    expect(over.dose, isEmpty, reason: '510 mg passa do máximo: sem dose');
    expect(over.blockers.join(), contains('acima do máximo'));
    expect(find.textContaining('Dose não calculada'), findsOneWidget);

    await goTo(tester, '/modelos-receita?paciente=p3');
    await tapKey(tester, 'usar-m1');
    final RxItem maya = demoSession
        .documentsFor('p3')
        .first
        .current
        .items
        .single;
    expect(maya.dose, isEmpty, reason: 'sem peso, nenhuma dose copiada');
    expect(maya.blockers, contains('Peso não registrado.'));
    expect(find.textContaining('Dose não calculada'), findsOneWidget);
  });

  testWidgets('salvar receita como modelo não leva a dose da criança', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await goTo(tester, '/pacientes/p1/documentos/d3');
    await tapText(tester, 'Salvar como modelo');
    await type(tester, 'nome-modelo-receita', 'Da receita da Luna (teste)');
    await tapText(tester, 'Salvar modelo');
    final RxTemplate t = demoSession.rxTemplates.firstWhere(
      (RxTemplate x) => x.name == 'Da receita da Luna (teste)',
    );
    expect(t.items.length, 2);
    for (final RxTemplateItem i in t.items) {
      expect(i.mode, RxDoseMode.atConsultation);
      expect(i.fixedDose, isEmpty);
    }

    await goTo(tester, '/modelos-receita?paciente=p2');
    await type(tester, 'busca-modelo', 'Luna');
    await tapKey(tester, 'usar-${t.id}');
    final ClinicalDocRecord d = demoSession.documentsFor('p2').first;
    expect(d.current.items.every((RxItem i) => i.dose.isEmpty), isTrue);
    expect(d.pendingIssues.join(' '), contains('incompleto'));
  });

  testWidgets('só o profissional acessa os modelos', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    demoSession.enter(DemoProfile.recepcao);
    await goTo(tester, '/modelos-receita');
    expect(find.text('Meus modelos de receita'), findsNothing);
    expect(find.textContaining('restrito'), findsWidgets);
  });
}
