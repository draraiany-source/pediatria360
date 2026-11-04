import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/demo_templates.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/doc_templates.dart';

/// Documentos da consulta a partir de modelos: biblioteca, edição, aplicação
/// em crianças diferentes, permissões, emissão, PDF e liberação à família.
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

  void clearSnacks(WidgetTester tester) {
    for (final ScaffoldMessengerState m
        in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger),
        )) {
      m.clearSnackBars();
    }
  }

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    clearSnacks(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey<String>(key)));

  Future<void> type(WidgetTester tester, String key, String text) async {
    final Finder f = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pump();
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<TextField>(find.byKey(ValueKey<String>(key)))
      .controller!
      .text;

  group('biblioteca de modelos', () {
    testWidgets('profissional vê os seus e os da clínica; modelo da clínica '
        'só pode ser usado ou duplicado', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(tester, '/modelos');
      expect(find.text('Modelos de documentos'), findsOneWidget);
      expect(find.text('Atestado 1 dia - escola'), findsOneWidget);
      expect(find.text('Encaminhamento para avaliação da fala'), findsOneWidget);
      expect(find.text('Escola'), findsOneWidget);
      expect(find.text('Atestado do Dr. Colega (exemplo)'), findsNothing);

      await tapKey(tester, 'aba-clinic');
      expect(find.text('Atestado escolar - padrão da clínica'), findsOneWidget);
      expect(find.text('Lavagem nasal - padrão da clínica'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('editar-modelo-mt1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('arquivar-modelo-mt1')),
        findsNothing,
      );
      expect(find.text('Duplicar para meus modelos'), findsWidgets);

      await tapKey(tester, 'duplicar-modelo-mt1');
      final String path =
          demoRouter.routerDelegate.currentConfiguration.uri.path;
      expect(path, matches(RegExp(r'^/modelos/[^/]+/editar$')));
      final String copyId = path.split('/')[2];
      expect(copyId, isNot('mt1'));
      expect(demoSession.templates.canManage(copyId), isTrue);
      expect(
        demoSession.templateLibrary.orgOf(copyId)!.copiedFrom,
        contains('Modelo da clínica'),
      );
      expect(demoSession.templates.canManage('mt1'), isFalse);

      await goTo(tester, '/modelos/mt1/editar');
      expect(find.text('Duplicar para editar'), findsOneWidget);
      expect(find.text('Salvar modelo'), findsNothing);
    });

    testWidgets('criar modelo de atestado com marcadores e pasta', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/modelos/novo?tipo=atestado');
      expect(find.text('Novo modelo: Atestado médico'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('modelo-campo-cid')), findsNothing);
      await type(tester, 'modelo-nome', 'Atestado 2 dias - teste');
      await type(tester, 'modelo-pasta', 'Escola');
      await type(tester, 'modelo-campo-dias', '2');
      await type(
        tester,
        'modelo-campo-textoEditado',
        'Atesto que {{crianca}} esteve em consulta em {{data_consulta}}. '
        'Peso: {{peso}}. [preencher: orientação]',
      );
      await tapText(tester, 'Salvar modelo');
      final TemplateEntry e = demoSession.templates
          .entries(view: TemplateView.mine, query: 'Atestado 2 dias - teste')
          .single;
      expect(e.org.folder, 'Escola');
      expect(demoSession.templates.docTemplate(e.id)!.fields['dias'], '2');
      expect(
        demoRouter.routerDelegate.currentConfiguration.uri.path,
        '/modelos',
      );
    });

    testWidgets('editar modelo cria nova versão; documento já gerado não '
        'muda', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3');
      await tapText(tester, 'Salvar rascunho');
      final ClinicalDocRecord doc = demoSession.documentsFor('p1').first;
      final String before = doc.current.body;
      expect(doc.current.templateOrigin, 'Modelo "Atestado 1 dia - escola" · v1');

      await goTo(tester, '/modelos/mt3/editar');
      expect(find.text('Editar modelo: Atestado médico'), findsOneWidget);
      await type(tester, 'modelo-nome', 'Atestado 1 dia - escola (revisado)');
      await type(tester, 'modelo-nota', 'Texto de retorno ajustado');
      await tapText(tester, 'Salvar modelo');
      final DocTemplate t = demoSession.templates.docTemplate('mt3')!;
      expect(t.current.number, 2);
      expect(t.versions.first.name, 'Atestado 1 dia - escola');
      expect(t.current.note, 'Texto de retorno ajustado');
      expect(demoSession.documentById(doc.id)!.current.body, before);
    });

    testWidgets('organizar: mover de pasta, arquivar e restaurar', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final DemoTemplates tp = demoSession.templates;
      tp.moveTo('mt5', 'Exames');
      expect(tp.library.orgOf('mt5')!.folder, 'Exames');
      tp.archive('mt5');
      expect(tp.usableFor(DocKind.exames).map((DocTemplate t) => t.id),
          isNot(contains('mt5')));
      await goTo(tester, '/modelos');
      await tapKey(tester, 'aba-archived');
      expect(find.text('Exames de acompanhamento (exemplo)'), findsOneWidget);
      await tapKey(tester, 'restaurar-modelo-mt5');
      expect(tp.canUse('mt5'), isTrue);
    });
  });

  group('aplicar modelo em duas crianças', () {
    testWidgets('Luna com consulta: dados confirmados entram e campo variável '
        'fica marcado', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(
        tester,
        '/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1',
      );
      final String text = fieldText(tester, 'campo-textoEditado');
      final DateTime day = demoSession.consultationById('c1')!.startedAt;
      expect(text, contains('Luna Exemplo Souza'));
      expect(text, contains(formatDocDate(day)));
      expect(text, contains('[preencher: orientação para o retorno]'));
      expect(fieldText(tester, 'campo-inicio'), formatDocDate(day));
      expect(
        find.textContaining('Automático (dado confirmado): data da consulta'),
        findsOneWidget,
      );
      expect(find.textContaining('campo(s) marcado(s)'), findsOneWidget);
      expect(find.textContaining('Gerado de: Modelo "Atestado 1 dia'),
          findsOneWidget);

      await tapText(tester, 'Salvar e revisar');
      expect(find.textContaining('Resolva no editor antes de revisar'),
          findsOneWidget);
      final ClinicalDocRecord d = demoSession.documentsFor('p1').first;
      expect(d.current.fields['incluirCid'], 'Não');
      expect(d.current.body, isNot(contains('CID')));
    });

    testWidgets('Maya sem consulta nem peso: nada herdado da Luna e campos '
        'a conferir', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(
        tester,
        '/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1',
      );
      await tapText(tester, 'Salvar rascunho');
      await goTo(tester, '/pacientes/p3/documentos/novo?tipo=atestado&modelo=mt3');
      final String text = fieldText(tester, 'campo-textoEditado');
      expect(text, contains('Maya'));
      expect(text, isNot(contains('Luna')));
      expect(text, contains('[conferir: data da consulta]'));
      expect(fieldText(tester, 'campo-inicio'), '[conferir: data da consulta]');
      expect(find.textContaining('Campo variável'), findsWidgets);
    });

    testWidgets('usar modelo dentro do editor e salvar documento como modelo', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(
        tester,
        '/pacientes/p2/documentos/novo?tipo=encaminhamento',
      );
      await tapKey(tester, 'usar-modelo-doc');
      await tapKey(tester, 'aplicar-modelo-mt4');
      expect(fieldText(tester, 'campo-especialidade'),
          'Fonoaudiologia (exemplo)');
      expect(fieldText(tester, 'campo-motivo'),
          contains('[preencher: o que foi observado'));

      final String theo = demoSession.patientById('p2')!.name;
      await type(tester, 'campo-motivo', '$theo com troca de sons');
      await tapKey(tester, 'salvar-como-modelo-doc');
      await type(tester, 'salvar-modelo-nome', 'Fono a partir do Theo');
      await tapText(tester, 'Salvar modelo');
      final TemplateEntry e = demoSession.templates
          .entries(view: TemplateView.mine, query: 'Fono a partir do Theo')
          .single;
      final DocTemplate t = demoSession.templates.docTemplate(e.id)!;
      expect(t.fields['motivo'], '{{crianca}} com troca de sons');
      expect(t.fields['resumo'], '');
    });
  });

  group('permissões', () {
    testWidgets('recepção, financeiro e família não abrem modelos', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      for (final DemoProfile p in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.responsavel,
      ]) {
        demoSession.enter(p);
        for (final String path in <String>[
          '/modelos',
          '/modelos/mt3/editar',
          '/modelos/novo?tipo=atestado',
        ]) {
          await goTo(tester, path);
          expect(find.text('Acesso restrito'), findsOneWidget,
              reason: '${p.name} em $path');
        }
      }
    });

    testWidgets('gestão da clínica edita os modelos da clínica e não vê os '
        'pessoais', (WidgetTester tester) async {
      await pumpDemo(tester);
      demoSession.enter(DemoProfile.administrador);
      await goTo(tester, '/modelos');
      expect(find.text('Modelos da clínica'), findsWidgets);
      expect(find.text('Atestado escolar - padrão da clínica'), findsOneWidget);
      expect(find.text('Atestado 1 dia - escola'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('editar-modelo-mt1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('usar-modelo-mt1')), findsNothing);
      await goTo(tester, '/modelos/mt1/editar');
      await type(tester, 'modelo-campo-dias', '1');
      await tapText(tester, 'Salvar modelo');
      expect(demoSession.templates.docTemplate('mt1')!.current.number, 2);

      demoSession.enter(DemoProfile.profissional);
      expect(demoSession.templates.canUse('mt1'), isTrue);
      expect(demoSession.templates.canManage('mt1'), isFalse);
      expect(demoSession.templates.docTemplate('mt1')!.fields['dias'], '1');
    });

    testWidgets('outro profissional não vê modelos pessoais nem da clínica '
        'alheia', (WidgetTester tester) async {
      await pumpDemo(tester);
      demoSession.switchAccount('prof-b');
      await goTo(tester, '/modelos');
      expect(find.text('Atestado do Dr. Colega (exemplo)'), findsOneWidget);
      expect(find.text('Atestado 1 dia - escola'), findsNothing);
      expect(demoSession.templates.canUse('mt1'), isFalse);
      expect(demoSession.templates.canUse('mt3'), isFalse);
      await goTo(tester, '/pacientes/p7/documentos/novo?tipo=atestado&modelo=mt3');
      expect(find.textContaining('não está disponível'), findsOneWidget);
    });
  });

  group('emissão, PDF, histórico e família', () {
    testWidgets('documento de modelo: revisar, emitir, PDF, histórico e '
        'liberar para a família', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(
        tester,
        '/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1',
      );
      final String text = fieldText(tester, 'campo-textoEditado').replaceAll(
        '[preencher: orientação para o retorno]',
        'retorno no dia seguinte',
      );
      await type(tester, 'campo-textoEditado', text);
      await tapText(tester, 'Salvar e revisar');
      final String id = demoSession.documentsFor('p1').first.id;
      expect(demoSession.isReleasedToFamily(id), isFalse);
      await tapKey(tester, 'review-check');
      await tapText(tester, 'Marcar como revisado');
      final Finder release = find.byKey(const ValueKey<String>('release-on-issue'));
      await tester.ensureVisible(release);
      final CheckboxListTile tile = tester.widget<CheckboxListTile>(release);
      if (tile.value != true) await tapFinder(tester, release);
      await tapText(tester, 'Emitir documento');

      final ClinicalDocRecord d = demoSession.documentById(id)!;
      expect(d.status, DocStatus.issued);
      expect(d.current.issuedContext, isNotNull);
      expect(d.current.issuedContext!.professionalName, demoSession.account.name);
      expect(demoSession.isReleasedToFamily(id), isTrue);
      expect(find.text('Histórico de versões'), findsOneWidget);
      expect(find.textContaining('Emitida (finalizada) em'), findsOneWidget);

      await tapText(tester, 'Gerar PDF');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester);
      final (String, List<int>, String)? pdf = demoSession.lastPdf;
      expect(pdf, isNotNull);
      expect(ascii.decode(pdf!.$2.sublist(0, 5)), '%PDF-');

      // Dados profissionais alterados depois não mudam o documento emitido.
      demoSession.updateProfessionalData(
        demoSession.account.copyWith(name: 'Dra. Nome Alterado'),
      );
      await goTo(tester, '/pacientes/p1/documentos/$id');
      expect(
        demoSession.documentById(id)!.current.issuedContext!.professionalName,
        isNot('Dra. Nome Alterado'),
      );
      expect(find.textContaining('Dra. Nome Alterado'), findsNothing);

      await goTo(tester, '/pacientes/p1/documentos');
      expect(find.textContaining('Atestado'), findsWidgets);
    });

    testWidgets('rascunho não aparece para a família', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(
        tester,
        '/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1',
      );
      await tapText(tester, 'Salvar rascunho');
      final ClinicalDocRecord d = demoSession.documentsFor('p1').first;
      expect(d.status, DocStatus.draft);
      expect(demoSession.isReleasedToFamily(d.id), isFalse);
      expect(demoSession.familyReleaseBlock(d), isNotNull);
    });

    testWidgets('dados profissionais configuráveis na tela de logomarca', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/perfil/logomarca');
      await tapKey(tester, 'dados-profissionais-editar');
      await type(tester, 'dados-specialty', 'Pediatria e puericultura');
      await type(tester, 'dados-phone', '(00) 0000-0000');
      await tapKey(tester, 'dados-salvar');
      expect(demoSession.account.specialty, 'Pediatria e puericultura');
      expect(demoSession.account.phone, '(00) 0000-0000');
      expect(find.text('Pediatria e puericultura'), findsWidgets);
    });
  });
}
