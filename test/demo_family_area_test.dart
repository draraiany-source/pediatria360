import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_clinical.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/documents_screens.dart';
import 'package:pediatria360/demo/screens/family_health_screens.dart';
import 'package:pediatria360/shared/clinical/audit_trail.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/family_release.dart';
import 'package:pediatria360/shared/previsit/pre_visit_guidance.dart';

/// Área da família (pós-consulta e saúde), liberação de documentos,
/// orientações antes da consulta e hipóteses. Dados fictícios.
void main() {
  const Size phone = Size(390, 844);
  const Size desktop = Size(1280, 860);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDemo(
    WidgetTester tester, {
    DemoProfile profile = DemoProfile.profissional,
    Size size = phone,
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

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
  }

  String location() =>
      demoRouter.routerDelegate.currentConfiguration.uri.toString();

  Future<void> seek(WidgetTester tester, Finder f) async {
    if (f.evaluate().isNotEmpty) return;
    final Finder lists = find.byWidgetPredicate(
      (Widget w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
    if (lists.evaluate().isEmpty) return;
    final Finder main = find
        .descendant(of: lists.first, matching: find.byType(Scrollable))
        .first;
    for (final double delta in <double>[250, -250]) {
      if (f.evaluate().isNotEmpty) break;
      try {
        await tester.scrollUntilVisible(
          f,
          delta,
          scrollable: main,
          maxScrolls: 40,
        );
      } on StateError {
        // Não está neste sentido.
      }
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    for (final ScaffoldMessengerState m
        in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger),
        )) {
      m.clearSnackBars();
    }
    await tester.pumpAndSettle();
    await seek(tester, f);
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text));

  Future<void> waitPdf(WidgetTester tester) async {
    for (int i = 0; i < 6 && demoSession.lastPdf == null; i++) {
      await settle(tester);
    }
  }

  List<String> ids(List<ClinicalDocRecord> docs) =>
      docs.map((ClinicalDocRecord d) => d.id).toList();

  setUp(() => demoSession.leave());

  group('regras na sessão', () {
    test('família vê só documentos emitidos e liberados das suas crianças', () {
      demoSession.enter(DemoProfile.responsavel);
      expect(ids(demoSession.familyDocuments('p1')), <String>['d3', 'd4']);
      expect(demoSession.familyDocumentById('p1', 'd1'), isNull);
      expect(demoSession.familyDocumentById('p1', 'd2'), isNull);
      expect(demoSession.familyDocuments('p5'), isEmpty);
      // Criança de outra família.
      expect(demoSession.familyDocuments('p2'), isEmpty);
      expect(ids(demoSession.familyOrientations('p1')), <String>['d4']);

      for (final DemoProfile other in <DemoProfile>[
        DemoProfile.profissional,
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.administrador,
      ]) {
        demoSession.enter(other);
        expect(demoSession.familyDocuments('p1'), isEmpty, reason: '$other');
        expect(demoSession.familyVisits('p1'), isEmpty, reason: '$other');
      }
    });

    test('profissional libera e retira com motivo; tudo vai ao registro', () {
      demoSession.enter(DemoProfile.profissional);
      expect(
        demoSession.familyReleaseBlock(demoSession.documentById('d1')!),
        isNull,
      );
      demoSession.releaseToFamily('d1');
      expect(demoSession.isReleasedToFamily('d1'), isTrue);
      expect(
        () => demoSession.releaseToFamily('d1'),
        throwsA(isA<FamilyReleaseException>()),
      );

      demoSession.enter(DemoProfile.responsavel);
      expect(ids(demoSession.familyDocuments('p1')), contains('d1'));

      demoSession.enter(DemoProfile.profissional);
      expect(
        () => demoSession.revokeFamilyRelease('d1', reason: ' '),
        throwsA(isA<FamilyReleaseException>()),
      );
      demoSession.revokeFamilyRelease('d1', reason: 'Enviado por engano');
      demoSession.enter(DemoProfile.responsavel);
      expect(ids(demoSession.familyDocuments('p1')), isNot(contains('d1')));

      demoSession.enter(DemoProfile.profissional);
      final List<AuditEntry> log = demoSession.workspace.auditFor(
        'p1',
        entityId: 'd1',
      );
      expect(log.map((AuditEntry e) => e.action), <String>[
        'Liberação para a família retirada',
        'Documento liberado para a família',
      ]);
      expect(log.first.entity, AuditEntity.documento);
      expect(log.first.detail, contains('Enviado por engano'));
    });

    test('rascunho, colega de outra conta e recepção não liberam', () {
      demoSession.enter(DemoProfile.profissional);
      expect(
        () => demoSession.releaseToFamily('d2'),
        throwsA(isA<FamilyReleaseException>()),
      );
      demoSession.switchAccount('prof-b');
      expect(
        () => demoSession.releaseToFamily('d1'),
        throwsA(isA<FamilyReleaseException>()),
      );
      expect(
        () => demoSession.revokeFamilyRelease('d3', reason: 'Motivo qualquer'),
        throwsA(isA<FamilyReleaseException>()),
      );
      demoSession.enter(DemoProfile.recepcao);
      expect(
        () => demoSession.releaseToFamily('d1'),
        throwsA(isA<FamilyReleaseException>()),
      );
      expect(demoSession.isReleasedToFamily('d1'), isFalse);
      expect(demoSession.isReleasedToFamily('d3'), isTrue);
    });

    test('nova versão em rascunho não chega à família até ser emitida', () {
      demoSession.enter(DemoProfile.profissional);
      final ClinicalDocRecord d4 = demoSession.documentById('d4')!;
      final DemoPatient p = demoSession.patientById('p1')!;
      demoSession.saveDocument(
        d4.saveDraft(
          fields: <String, String>{
            'titulo': 'Rotina e sono',
            'texto': 'Texto em revisão (teste).',
          },
          items: const <RxItem>[],
          context: demoDocContext(p),
          author: demoSession.currentAuthor,
          now: DateTime.now(),
        ),
      );
      demoSession.enter(DemoProfile.responsavel);
      final ClinicalDocRecord seen = demoSession.familyDocumentById(
        'p1',
        'd4',
      )!;
      expect(seen.current.status, DocStatus.issued);
      expect(seen.current.fields['texto'], isNot(contains('em revisão')));
    });

    test('consultas para a família: sem anotações clínicas, com documentos '
        'liberados e retorno', () {
      demoSession.enter(DemoProfile.responsavel);
      final List<FamilyVisit> visits = demoSession.familyVisits('p1');
      expect(visits.map((FamilyVisit v) => v.id), <String>['c1', 'c3']);
      expect(ids(visits.first.documents), <String>['d3']);
      expect(visits.first.returnDate, isNotNull);
      expect(visits.last.kindLabel, 'Consulta de puericultura');
      expect(ids(visits.last.documents), <String>['d4']);
      // Consulta em rascunho não aparece.
      expect(demoSession.familyVisits('p5'), isEmpty);
    });

    test('orientações antes da consulta: por tipo, só da própria criança, '
        'editadas só pelo profissional da clínica', () {
      demoSession.enter(DemoProfile.responsavel);
      final DemoAppointment a6 = demoSession.appointmentById('a6')!;
      expect(demoSession.visitCategoryOf(a6), VisitCategory.retorno);
      expect(
        demoSession.preVisitGuidanceFor(a6),
        contains(startsWith('Leve ou envie pela pré-consulta os exames')),
      );
      final DemoAppointment a2 = demoSession.appointments.firstWhere(
        (DemoAppointment a) => a.id == 'a2',
      );
      expect(demoSession.preVisitGuidanceFor(a2), isEmpty);
      expect(
        () => demoSession.savePreVisitGuidance(
          general: <String>['x'],
          byCategory: const <VisitCategory, List<String>>{},
        ),
        throwsStateError,
      );

      demoSession.enter(DemoProfile.recepcao);
      expect(demoSession.canEditPreVisitGuidance, isFalse);
      demoSession.enter(DemoProfile.profissional);
      demoSession.switchAccount('prof-b');
      expect(demoSession.canEditPreVisitGuidance, isFalse);
      demoSession.switchAccount(DemoProfessional.id);
      demoSession.savePreVisitGuidance(
        general: <String>['Traga a caderneta (teste).'],
        byCategory: <VisitCategory, List<String>>{
          VisitCategory.retorno: <String>['Traga os exames (teste).'],
        },
      );
      expect(demoSession.preVisitGuidance.isReviewed, isTrue);
      demoSession.enter(DemoProfile.responsavel);
      expect(demoSession.preVisitGuidanceFor(a6), <String>[
        'Traga a caderneta (teste).',
        'Traga os exames (teste).',
      ]);
    });

    test('hipóteses: só o profissional escreve; o assistente não preenche', () {
      demoSession.enter(DemoProfile.profissional);
      final DemoConsultation c = demoSession.startConsultation(
        'p1',
        appointmentId: 'a1',
      );
      demoSession.workspace.organize(
        c,
        transcript: 'Exame físico: sem alterações (teste).',
      );
      demoSession.workspace.applyDraft(c, reviewed: true);
      expect(c.hypotheses, isEmpty);
      expect(c.assessment, isEmpty);

      c.hypotheses = 'Hipótese fictícia (teste)';
      demoSession.saveConsultation(c);
      expect(c.summary, contains('Hipóteses: Hipótese fictícia (teste)'));
      expect(
        demoSession.workspace.auditFor('p1', entityId: c.id).first.detail,
        contains('Hipóteses diagnósticas'),
      );
    });
  });

  group('telas', () {
    for (final (String label, Size size) in <(String, Size)>[
      ('celular', phone),
      ('computador', desktop),
    ]) {
      testWidgets('$label: família abre saúde, documentos liberados e PDF', (
        WidgetTester tester,
      ) async {
        await pumpDemo(tester, profile: DemoProfile.responsavel, size: size);
        await goTo(tester, '/pacientes/p1');
        await tapText(tester, 'Saúde e desenvolvimento');
        expect(location(), '/rotina/p1/saude');
        expect(find.byType(DemoFamilyHealthScreen), findsOneWidget);
        await seek(tester, find.textContaining('Antes da consulta'));
        expect(find.textContaining('Antes da consulta'), findsWidgets);
        expect(find.text(PreVisitGuidanceRules.safetyNotice), findsWidgets);
        await seek(tester, find.text('Consultas anteriores'));
        expect(find.text('Consultas anteriores'), findsOneWidget);

        await tapFinder(
          tester,
          find.byKey(const ValueKey<String>('saude-documentos')),
        );
        expect(location(), '/rotina/p1/documentos?de=saude');
        expect(find.text('Receituário'), findsOneWidget);
        await seek(
          tester,
          find.text('Orientações ao responsável: Rotina e sono'),
        );
        expect(
          find.text('Orientações ao responsável: Rotina e sono'),
          findsOneWidget,
        );
        expect(find.textContaining('Atestado médico'), findsNothing);

        await tapFinder(tester, find.widgetWithText(ChoiceChip, 'Receitas'));
        expect(
          find.text('Orientações ao responsável: Rotina e sono'),
          findsNothing,
        );
        await tapText(tester, 'Receituário');
        expect(location(), '/rotina/p1/documentos/d3?de=saude');
        expect(find.textContaining('Emitido em'), findsOneWidget);
        demoSession.lastPdf = null;
        await tapText(tester, 'Baixar PDF');
        await waitPdf(tester);
        expect(latin1.decode(demoSession.lastPdf!.$2), startsWith('%PDF-'));

        await tapFinder(tester, find.byType(BackButton));
        expect(location(), '/rotina/p1/documentos?de=saude');
        await tapFinder(tester, find.byType(BackButton));
        expect(location(), '/rotina/p1/saude');

        await goTo(tester, '/rotina/p1/documentos/d1');
        expect(find.text('Documento não encontrado'), findsOneWidget);
        await goTo(tester, '/rotina/p5/documentos');
        expect(find.text('Nenhum documento liberado'), findsOneWidget);
        await goTo(tester, '/rotina/p2/saude');
        expect(find.byType(DemoFamilyHealthScreen), findsNothing);
        await goTo(tester, '/rotina/p2/documentos');
        expect(find.byType(DemoFamilyDocumentsScreen), findsNothing);
      });
    }

    testWidgets('profissional não abre a área da família; libera e retira '
        'pelo documento', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1/documentos');
      expect(find.text('Acesso restrito'), findsOneWidget);
      await goTo(tester, '/rotina/p1/saude');
      expect(find.text('Acesso restrito'), findsOneWidget);

      await goTo(tester, '/pacientes/p1/documentos/d1');
      await seek(tester, find.text('A família ainda não vê este documento'));
      expect(
        find.text('A família ainda não vê este documento'),
        findsOneWidget,
      );
      await tapText(tester, 'Liberar para a família');
      expect(find.text('Liberar para a família?'), findsOneWidget);
      await tapText(tester, 'Liberar');
      expect(demoSession.isReleasedToFamily('d1'), isTrue);
      await seek(tester, find.text('Liberado para a família'));
      expect(find.text('Liberado para a família'), findsOneWidget);

      await tapText(tester, 'Retirar da área da família');
      await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
      await settle(tester);
      expect(find.text('Informe o motivo da retirada.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo *'),
        'Documento duplicado (teste)',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
      await settle(tester);
      expect(demoSession.isReleasedToFamily('d1'), isFalse);
      expect(
        find.textContaining('Documento duplicado (teste)'),
        findsOneWidget,
      );
    });

    testWidgets('emitir receita pede escolha explícita para liberar', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final DemoPatient p = demoSession.patientById('p1')!;
      final ClinicalDocRecord draft = ClinicalDocRecord.createDraft(
        id: demoSession.newDocumentId(),
        kind: DocKind.exames,
        patientId: p.id,
        author: demoSession.currentAuthor,
        context: demoDocContext(p),
        now: DateTime.now(),
        fields: <String, String>{
          'exames': 'Exame fictício',
          'indicacao': 'Indicação fictícia (teste)',
          'observacoes': '',
        },
      );
      demoSession.saveDocument(draft);
      await goTo(tester, '/pacientes/p1/documentos/${draft.id}');
      await tapFinder(
        tester,
        find.byKey(const ValueKey<String>('review-check')),
      );
      await tapText(tester, 'Marcar como revisado');
      final Finder release = find.byKey(
        const ValueKey<String>('release-on-issue'),
      );
      await seek(tester, release);
      expect(tester.widget<CheckboxListTile>(release).value, isFalse);
      await tapText(tester, 'Emitir documento');
      expect(demoSession.isReleasedToFamily(draft.id), isFalse);
      await tapText(tester, 'Liberar para a família');
      await tapText(tester, 'Liberar');
      demoSession.enter(DemoProfile.responsavel);
      expect(
        demoSession.familyDocuments('p1').map((ClinicalDocRecord d) => d.id),
        contains(draft.id),
      );
    });

    testWidgets('profissional edita as orientações; a família vê na '
        'pré-consulta sem o aviso de texto sugerido', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/inicio');
      await tapText(tester, 'Orientações antes da consulta');
      expect(location(), '/orientacoes-previas');
      expect(find.text(PreVisitGuidanceRules.suggestedLabel), findsOneWidget);
      await seek(
        tester,
        find.byKey(const ValueKey<String>('orientacao-retorno')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('orientacao-retorno')),
        'Traga os exames do retorno (teste).',
      );
      await settle(tester);
      await tapText(tester, 'Revisar e salvar');
      expect(demoSession.preVisitGuidance.isReviewed, isTrue);
      await seek(tester, find.textContaining('Revisado por'));
      expect(find.textContaining('Revisado por'), findsOneWidget);

      demoSession.enter(DemoProfile.responsavel);
      await goTo(tester, '/pre-consulta/a6?de=saude');
      await seek(tester, find.text('Traga os exames do retorno (teste).'));
      expect(find.text('Traga os exames do retorno (teste).'), findsOneWidget);
      expect(find.text(PreVisitGuidanceRules.suggestedLabel), findsNothing);
      await tapFinder(tester, find.byType(BackButton));
      expect(location(), '/rotina/p1/saude');

      demoSession.enter(DemoProfile.recepcao);
      await goTo(tester, '/orientacoes-previas');
      expect(find.text('Acesso restrito'), findsOneWidget);
    });

    testWidgets('consulta: campo de hipóteses na avaliação', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p5/consulta/c2?etapa=avaliacao');
      final Finder f = find.byWidgetPredicate(
        (Widget w) =>
            w is TextField &&
            w.decoration?.labelText == 'Hipóteses diagnósticas',
      );
      await seek(tester, f);
      expect(
        find.text('Escritas por você. O assistente não sugere hipóteses.'),
        findsOneWidget,
      );
      await tester.enterText(f, 'Hipótese fictícia (teste)');
      await settle(tester);
      await tapText(tester, 'Salvar rascunho');
      expect(
        demoSession.consultationById('c2')!.hypotheses,
        'Hipótese fictícia (teste)',
      );
    });
  });
}
