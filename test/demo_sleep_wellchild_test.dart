import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_clinical.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_growth.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_routine.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/documents_screens.dart';
import 'package:pediatria360/demo/screens/family_guidance_screens.dart';
import 'package:pediatria360/demo/widgets/routine_widgets.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/orientation_templates.dart';
import 'package:pediatria360/shared/routine/child_routine.dart';
import 'package:pediatria360/shared/routine/sleep_log.dart';
import 'package:pediatria360/shared/wellchild/age_band.dart';
import 'package:pediatria360/shared/wellchild/milestones.dart';
import 'package:pediatria360/shared/wellchild/well_child_templates.dart';
import 'package:pediatria360/shared/wellchild/well_child_visit.dart';

import 'support/png_fixture.dart';

/// Sono e puericultura na demonstração, com pacientes e contas fictícios.
void main() {
  const Size phone = Size(390, 844);
  const Size desktop = Size(1280, 860);

  tearDown(() => demoSession.clock = DateTime.now);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
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
    final Finder main = find.byWidgetPredicate(
      (Widget w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical,
    );
    if (main.evaluate().isEmpty) return;
    await tester.scrollUntilVisible(f, 250, scrollable: main.last);
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
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text, {bool last = false}) =>
      tapFinder(tester, last ? find.text(text).last : find.text(text).first);

  /// Botão com o rótulo (há textos iguais na legenda e nos títulos).
  Finder button(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
      )
      .first;

  Future<void> typeKey(WidgetTester tester, String key, String text) async {
    final Finder f = find.byKey(ValueKey<String>(key));
    await seek(tester, f);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await seek(tester, find.widgetWithText(TextField, label));
    final Finder f = find.widgetWithText(TextField, label).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, value);
    await tester.pump();
  }

  TextEditingController ctrl(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey<String>(key))).controller!;

  Future<void> waitPdf(WidgetTester tester) async {
    for (int i = 0; i < 6 && demoSession.lastPdf == null; i++) {
      await settle(tester);
    }
  }

  String pdfText() => latin1.decode(demoSession.lastPdf!.$2);
  bool pdfHasImage() => RegExp(r'/Subtype\s*/Image').hasMatch(pdfText());

  DateTime today() => dayOf(DateTime.now());

  group('sono', () {
    testWidgets('família: noite com despertar, cochilo, linha do tempo, '
        'resumo, correção com histórico e volta ao sono', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, profile: DemoProfile.responsavel);
      final DateTime d = today();
      final DateTime night = DateTime(d.year, d.month, d.day, 20, 30);
      demoSession.clock = () => night;

      await goTo(tester, '/rotina/p5?vista=sono');
      expect(find.text('Registrar sono'), findsOneWidget);
      expect(find.text('Resumo da semana'), findsOneWidget);
      expect(find.text('Linha do tempo'), findsOneWidget);

      // Cochilo com horários e um despertar.
      await tapFinder(tester, button('Cochilo'));
      await fill(tester, 'Início', '14:00');
      await fill(tester, 'Fim (HH:MM) - vazio se ainda dorme', '15:10');
      await fill(tester, 'Despertou às (HH:MM)', '14:30');
      await fill(tester, 'Minutos acordado', '5');
      await tapText(tester, 'Incluir');
      expect(find.text('Despertou às 14:30 (5 min)'), findsOneWidget);
      await tapText(tester, 'Salvar');
      final DiaryEntry nap = demoSession.diaryEntries.last;
      expect(nap.kind, DiaryKind.sono);
      expect(nap.values.option, kSleepNap);
      expect(nap.values.minutes, 70);
      expect(nap.values.wakings, hasLength(1));

      // Sono noturno em andamento, despertar e fim na manhã seguinte.
      await tapFinder(tester, button('Dormiu agora (noite)'));
      final DiaryEntry open = demoSession.openSleep('p5')!;
      expect(open.values.option, kSleepNight);
      expect(find.textContaining('Sono noturno desde 20:30'), findsOneWidget);

      demoSession.clock = () => night.add(const Duration(minutes: 70));
      await tapFinder(tester, button('Despertar'));
      await fill(tester, 'Horário (HH:MM)', '21:10');
      await tapFinder(
        tester,
        find
            .ancestor(of: find.text('15 min'), matching: find.byType(RawChip))
            .last,
      );
      await tapText(tester, 'Salvar despertar');
      expect(
        demoSession.diaryEntryById(open.id)!.values.wakings.single.minutesAwake,
        15,
      );
      expect(find.textContaining('1 despertar'), findsWidgets);

      final DateTime morning = DateTime(d.year, d.month, d.day + 1, 6, 10);
      demoSession.clock = () => morning;
      await tapText(tester, 'Acordou');
      final DiaryEntry done = demoSession.diaryEntryById(open.id)!;
      expect(done.isOpenSleep, isFalse);
      expect(done.values.minutes, 9 * 60 + 40);

      // A noite fica no dia em que começou, com o cochilo do mesmo dia.
      final SleepDay day = demoSession
          .sleepWeek('p5', morning)
          .days
          .firstWhere((SleepDay x) => sameDay(x.day, d));
      expect(
        day.describe(),
        'noite 9h40 com 1 despertar - 1 cochilo (1h10) - total 10h50',
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('${formatDm(d)}: ${day.describe()}')),
        ),
        findsOneWidget,
      );
      for (final String l in demoSession.sleepWeek('p5', morning).lines()) {
        expect(find.text(l), findsOneWidget);
      }

      // Tocar no dia mostra os registros; o registro abre e volta ao sono.
      await tapFinder(
        tester,
        find.bySemanticsLabel(RegExp(RegExp.escape('${formatDm(d)}: '))),
      );
      await tapFinder(
        tester,
        find.byWidgetPredicate(
          (Widget w) => w is DiaryEntryTile && w.entry.id == nap.id,
        ),
      );
      expect(location(), '/rotina/p5/registro/${nap.id}?de=sono');
      await tapText(tester, 'Corrigir');
      expect(find.text('Despertou às 14:30 (5 min)'), findsOneWidget);
      await tapFinder(tester, find.byTooltip('Remover despertar das 14:30'));
      await fill(tester, 'Fim (HH:MM) - vazio se ainda dorme', '15:30');
      await fill(
        tester,
        'Motivo da correção (opcional)',
        'Acordou mais tarde (teste)',
      );
      await tapText(tester, 'Salvar correção');
      final DiaryEntry fixed = demoSession.diaryEntryById(nap.id)!;
      expect(fixed.values.minutes, 90);
      expect(fixed.values.wakings, isEmpty);
      expect(find.text('Motivo: Acordou mais tarde (teste)'), findsOneWidget);

      await tapFinder(tester, find.byType(BackButton));
      expect(location(), contains('/rotina/p5?vista=sono'));
      expect(find.text('Resumo da semana'), findsOneWidget);
      expect(
        demoSession
            .sleepWeek('p5', morning)
            .days
            .firstWhere((SleepDay x) => sameDay(x.day, d))
            .describe(),
        'noite 9h40 com 1 despertar - 1 cochilo (1h30) - total 11h10',
      );
    });

    testWidgets('fam\u00edlia: despertar no mesmo minuto em que dormiu \u00e9 '
        'aceito', (WidgetTester tester) async {
      await pumpDemo(tester, profile: DemoProfile.responsavel);
      final DateTime d = today();
      final DateTime night = DateTime(d.year, d.month, d.day, 20, 30, 45);
      demoSession.clock = () => night;

      await goTo(tester, '/rotina/p5?vista=sono');
      await tapFinder(tester, button('Dormiu agora (noite)'));
      final DiaryEntry open = demoSession.openSleep('p5')!;
      expect(open.values.at, DateTime(d.year, d.month, d.day, 20, 30));

      await tapFinder(tester, button('Despertar'));
      final TextField hour = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Hor\u00e1rio (HH:MM)'),
      );
      expect(hour.controller!.text, '20:30');
      await tapText(tester, 'Salvar despertar');
      expect(find.textContaining('fica fora do per\u00edodo'), findsNothing);
      expect(demoSession.diaryEntryById(open.id)!.values.wakings, hasLength(1));
    });
    testWidgets('profissional: diário compartilhado só para leitura, '
        'avaliação revisada no prontuário e volta ao prontuário', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final int before = demoSession.encounters.length;
      await goTo(tester, '/pacientes/p1/prontuario');
      await tapText(tester, 'Diário do sono (família)');
      expect(location(), '/rotina/p1?vista=sono&de=prontuario');
      expect(find.text('Resumo da semana'), findsOneWidget);
      expect(find.text('Registrar sono'), findsNothing);
      expect(find.text('Dormiu agora (noite)'), findsNothing);

      await tapFinder(tester, find.byTooltip('Semana anterior'));
      expect(location(), contains('de=prontuario'));
      await tapText(tester, 'Hoje');

      await tapText(tester, 'Registrar avaliação do sono no prontuário');
      expect(
        ctrl(tester, 'sono-dados-familia').text,
        isNotEmpty,
        reason: 'dados da família chegam para revisão',
      );
      await tapText(tester, 'Salvar no prontuário');
      expect(find.text('Escreva a sua avaliação.'), findsOneWidget);
      await typeKey(
        tester,
        'sono-avaliacao',
        'Padrão compatível com a rotina relatada (teste).',
      );
      await tapText(tester, 'Salvar no prontuário');
      expect(
        find.text('Confirme que revisou os dados informados pela família.'),
        findsOneWidget,
      );
      expect(demoSession.encounters, hasLength(before));
      await tapText(tester, 'Revisei os dados informados pela família');
      await tapText(tester, 'Salvar no prontuário');
      expect(demoSession.encounters, hasLength(before + 1));
      final DemoEncounter e = demoSession.encounters.first;
      expect(e.type, 'Avaliação do sono');
      expect(
        e.summary,
        endsWith('Avaliação: Padrão compatível com a rotina relatada (teste).'),
      );

      await tapFinder(tester, find.byType(BackButton));
      expect(location(), '/pacientes/p1/prontuario');
      expect(find.text('Avaliação do sono'), findsWidgets);
    });
  });

  group('puericultura', () {
    testWidgets('consulta completa: modelo, incorporação revisada, medidas, '
        'marcos, dúvidas, acompanhamento, PDF, finalização, calendário, '
        'correção com motivo, histórico e voltar', (WidgetTester tester) async {
      await pumpDemo(tester);
      await tester.runAsync(loadWhoTables);
      await goTo(tester, '/pacientes/p1/prontuario');
      await tapText(tester, 'Nova consulta de puericultura');
      final Match? m = RegExp(
        r'^/pacientes/p1/consulta/(c\d+)$',
      ).firstMatch(location());
      expect(m, isNotNull, reason: location());
      final String cid = m!.group(1)!;
      DemoConsultation c() => demoSession.consultationById(cid)!;
      expect(c().isWellChild, isTrue);
      expect(c().isDraft, isTrue);
      expect(find.textContaining('Idade corrigida:'), findsWidgets);

      // Modelo por faixa etária (idade corrigida de Luna: 1 a 2 anos).
      await tapText(tester, 'Aplicar modelo');
      expect(find.textContaining('faixa da criança'), findsOneWidget);
      await tapText(tester, 'Puericultura 1 a 2 anos (exemplo)');
      expect(
        find.text('Modelo usado: Puericultura 1 a 2 anos (exemplo) (v1)'),
        findsOneWidget,
      );
      expect(
        ctrl(tester, 'wc-historia').text,
        startsWith('Responsável Exemplo A relata [preencher'),
      );

      await typeKey(tester, 'wc-historia', 'Sem intercorrências (teste).');
      await typeKey(tester, 'wc-alimentacao', 'Refeições da família (teste).');
      await typeKey(tester, 'wc-sono', 'Dorme no berço (teste).');
      await typeKey(tester, 'wc-eliminacoes', 'Sem alterações (teste).');
      await typeKey(tester, 'wc-vacinacao', 'Carteira conferida (teste).');

      // Diário do sono da família: só entra depois da revisão.
      await tapText(tester, 'Incorporar diário do sono');
      final Finder incorporate = find.widgetWithText(
        FilledButton,
        'Incorporar',
      );
      expect(tester.widget<FilledButton>(incorporate).onPressed, isNull);
      await typeKey(
        tester,
        'wc-incorporar-texto',
        'Diário do sono: noites de cerca de 10 horas (teste).',
      );
      await tapText(tester, 'Revisei os dados informados pela família');
      await tapFinder(tester, incorporate);
      expect(ctrl(tester, 'wc-sono').text, contains('Dorme no berço (teste).'));
      expect(
        ctrl(tester, 'wc-sono').text,
        contains('Diário do sono: noites de cerca de 10 horas (teste).'),
      );
      await tapText(tester, 'Salvar rascunho');
      expect(c().wellChild!.imports, hasLength(1));
      expect(c().wellChild!.imports.single.reviewedBy, DemoProfessional.name);

      // Ver o diário a partir da consulta e voltar a ela.
      await tapText(tester, 'Ver diário do sono');
      expect(location(), contains('/rotina/p1?vista=sono'));
      expect(location(), contains('consulta=$cid'));
      await tapFinder(tester, find.byType(BackButton));
      expect(location(), '/pacientes/p1/consulta/$cid');

      // Exame: medidas registradas na consulta entram nas curvas.
      await tapText(tester, 'Próximo');
      expect(find.text('Exame físico e crescimento'), findsOneWidget);
      await typeKey(tester, 'wc-exame', 'Bom estado geral (teste).');
      await tapText(tester, 'Registrar peso, comprimento e PC');
      expect(location(), '/pacientes/p1/crescimento/nova?consulta=$cid');
      await fill(tester, 'Data da medida *', formatDmy(today()));
      await fill(tester, 'Peso', '10,4');
      await fill(tester, 'Comprimento', '76,5');
      await fill(tester, 'Perímetro cefálico', '45,2');
      await tapText(tester, 'Salvar medida');
      await tapText(tester, 'Voltar à consulta');
      expect(location(), '/pacientes/p1/consulta/$cid?etapa=avaliacao');
      expect(find.text('Exame físico e crescimento'), findsOneWidget);
      expect(find.text('nesta consulta'), findsOneWidget);
      expect(ctrl(tester, 'wc-exame').text, 'Bom estado geral (teste).');
      await typeKey(tester, 'wc-crescimento', 'Segue a curva (teste).');

      // Marcos do desenvolvimento.
      await tapText(tester, 'Próximo');
      expect(find.text(kMilestoneListNotice), findsOneWidget);
      expect(
        find.text('Faixa: 1 a 2 anos (pela idade corrigida)'),
        findsOneWidget,
      );
      await tapFinder(tester, find.byTooltip('Anda sem apoio: Adquirido'));
      await tapFinder(
        tester,
        find.byTooltip('Fala palavras com significado: Em aquisição'),
      );
      await tapText(tester, 'Outro marco');
      await typeKey(tester, 'wc-marco-titulo', 'Empilha dois cubos (teste)');
      await tapText(tester, 'Incluir marco');
      expect(find.textContaining('Empilha dois cubos (teste)'), findsOneWidget);
      await typeKey(tester, 'wc-desenvolvimento', 'Adequado (teste).');

      // Conduta: avaliação, plano, dúvidas, orientações e acompanhamento.
      await tapText(tester, 'Próximo');
      await typeKey(tester, 'wc-avaliacao', 'Criança saudável (teste).');
      await typeKey(tester, 'wc-plano', 'Manter acompanhamento (teste).');
      await tapText(tester, 'Dúvida');
      await typeKey(tester, 'wc-duvida', 'Pode usar travesseiro? (teste)');
      await typeKey(
        tester,
        'wc-duvida-resposta',
        'Orientado com o texto revisado (teste).',
      );
      await tapText(tester, 'Salvar dúvida');
      expect(find.text('Pode usar travesseiro? (teste)'), findsOneWidget);
      await typeKey(
        tester,
        'wc-orientacoes',
        'Rotina de sono e alimentação conversadas (teste).',
      );
      await tapText(tester, 'em 2 meses');
      await tapText(tester, 'Item');
      await typeKey(tester, 'wc-item-titulo', 'Reavaliar fala (teste)');
      await tapText(tester, 'Incluir item');
      expect(find.text('Reavaliar fala (teste)'), findsOneWidget);

      // Resumo e PDF do rascunho.
      await tapText(tester, 'Próximo');
      expect(find.text('Resumo, histórico e PDF'), findsOneWidget);
      expect(
        find.textContaining('Anda sem apoio (Motor grosso): Adquirido'),
        findsOneWidget,
      );
      demoSession.lastPdf = null;
      await tapText(tester, 'Resumo em PDF');
      await waitPdf(tester);
      expect(demoSession.lastPdf, isNotNull);
      expect(pdfText(), startsWith('%PDF-'));
      expect(demoSession.lastPdf!.$3, 'download');
      final WellChildVisit saved = c().wellChild!;
      expect(
        saved.milestones.map((MilestoneObservation o) => o.describe()),
        contains(contains('Empilha dois cubos (teste)')),
      );
      expect(saved.questions.single.answer, contains('texto revisado'));
      expect(saved.followUps.single.title, 'Reavaliar fala (teste)');
      expect(saved.nextVisit, isNotNull);
      expect(saved.placeholders, isEmpty);

      // Finalizar.
      final int encounters = demoSession.encounters.length;
      await tapText(tester, 'Finalizar puericultura');
      expect(find.text('Finalizar puericultura?'), findsOneWidget);
      await tapText(tester, 'Finalizar', last: true);
      expect(c().isDraft, isFalse);
      expect(demoSession.encounters, hasLength(encounters + 1));
      expect(
        demoSession.encounters.first.type,
        'Consulta de puericultura (demonstração)',
      );
      expect(
        find.textContaining('Puericultura finalizada: somente leitura'),
        findsOneWidget,
      );
      expect(find.text('Salvar rascunho'), findsNothing);

      // Calendário da criança: próxima consulta e item de acompanhamento.
      final List<CalendarItem> items = demoSession.routineItems(
        'p1',
        today(),
        addDays(today(), 120),
      );
      expect(
        items.any(
          (CalendarItem i) =>
              i.id == 'wc:$cid:next' && sameDay(i.start, saved.nextVisit!),
        ),
        isTrue,
      );
      expect(
        items.any(
          (CalendarItem i) =>
              i.title == 'Acompanhamento: Reavaliar fala (teste)',
        ),
        isTrue,
      );

      // Correção após finalizar: exige motivo e guarda a versão anterior.
      await tapText(tester, 'Corrigir');
      await tapText(tester, 'Conduta');
      await typeKey(tester, 'wc-avaliacao', 'Criança saudável; ok (teste).');
      await tapText(tester, 'Salvar correção');
      expect(find.text('Motivo da correção'), findsOneWidget);
      await typeKey(tester, 'wc-motivo', 'Complemento (teste)');
      await tapText(tester, 'Salvar correção', last: true);
      final VisitRevision rev = c().wellChild!.history.last;
      expect(rev.action, 'Corrigido após finalizar');
      expect(rev.reason, 'Complemento (teste)');
      expect(rev.changes, <String>['Avaliação']);
      expect(
        rev.before!.field(WellChildSection.avaliacao),
        'Criança saudável (teste).',
      );
      expect(
        c().wellChild!.field(WellChildSection.avaliacao),
        'Criança saudável; ok (teste).',
      );

      await tapText(tester, 'Resumo');
      expect(
        find.textContaining(
          'Corrigido após finalizar por ${DemoProfessional.name}: Avaliação '
          '(motivo: Complemento (teste))',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Versão anterior');
      expect(find.text('Antes de: Corrigido após finalizar'), findsOneWidget);
      expect(
        find.textContaining('Avaliação: Criança saudável (teste).'),
        findsOneWidget,
      );
      await tapText(tester, 'Fechar');

      // Voltar percorre as etapas e sai para o prontuário.
      for (int i = 0; i < 4; i++) {
        await tapFinder(tester, find.byTooltip('Voltar'));
      }
      expect(
        find.text('História, alimentação, sono, eliminações e vacinação'),
        findsOneWidget,
      );
      await tapFinder(tester, find.byTooltip('Voltar'));
      expect(location(), '/pacientes/p1/prontuario');
    });

    testWidgets('modelo de evolução salvo sem dados da família, separado por '
        'conta e reutilizado em outro paciente', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1');
      await tapText(tester, 'Consulta de puericultura');
      expect(location(), matches(RegExp(r'^/pacientes/p1/consulta/c\d+$')));

      await typeKey(
        tester,
        'wc-historia',
        'Responsável Exemplo A relata que Luna está bem (teste).',
      );
      await typeKey(tester, 'wc-sono', 'Dorme bem (teste).');
      await tapText(tester, 'Incorporar diário do sono');
      await tapText(tester, 'Revisei os dados informados pela família');
      await tapFinder(tester, find.widgetWithText(FilledButton, 'Incorporar'));

      await tapText(tester, 'Salvar como modelo');
      await typeKey(tester, 'wc-nome-modelo', 'Meu modelo 1 a 2 anos (teste)');
      await tapText(tester, 'Salvar modelo');
      final WellChildTemplate t = demoSession.myWellChildTemplates.firstWhere(
        (WellChildTemplate x) => x.name == 'Meu modelo 1 a 2 anos (teste)',
      );
      expect(
        t.fields[WellChildSection.historia],
        '{{responsavel}} relata que {{crianca}} está bem (teste).',
      );
      expect(t.fields[WellChildSection.sono], 'Dorme bem (teste).');
      expect(t.band, ChildAgeBand.de1a2a);

      demoSession.switchAccount('prof-b');
      expect(
        demoSession.myWellChildTemplates.any(
          (WellChildTemplate x) => x.id == t.id,
        ),
        isFalse,
      );
      demoSession.switchAccount(DemoProfessional.id);

      await goTo(tester, '/pacientes/p5');
      await tapText(tester, 'Consulta de puericultura');
      expect(find.text('Incorporar diário do sono'), findsNothing);
      expect(
        find.textContaining('A família não compartilhou a rotina'),
        findsOneWidget,
      );
      await tapText(tester, 'Aplicar modelo');
      await tapText(tester, 'Meu modelo 1 a 2 anos (teste)');
      expect(
        ctrl(tester, 'wc-historia').text,
        'Responsável Exemplo A relata que Alice está bem (teste).',
      );
      await typeKey(tester, 'wc-historia', 'Editado para esta paciente.');
      expect(
        t.fields[WellChildSection.historia],
        '{{responsavel}} relata que {{crianca}} está bem (teste).',
      );
    });

    testWidgets('PDF do resumo: sem logomarca na consulta anterior; ao '
        'finalizar grava a logomarca vigente', (WidgetTester tester) async {
      await pumpDemo(tester, size: desktop);
      demoSession.uploadLogo(bytes: solidPng(300, 100), fileName: 'logo-a.png');

      await goTo(tester, '/pacientes/p1/consulta/c3?etapa=resumo');
      expect(
        find.textContaining('Puericultura finalizada: somente leitura'),
        findsOneWidget,
      );
      demoSession.lastPdf = null;
      await tapText(tester, 'Resumo em PDF');
      await waitPdf(tester);
      expect(pdfText(), startsWith('%PDF-'));
      expect(pdfHasImage(), isFalse);

      final DemoConsultation c = demoSession.startWellChildVisit('p1');
      demoSession.saveWellChild(
        c,
        c.wellChild!.copyWith(
          fields: <WellChildSection, String>{
            WellChildSection.avaliacao: 'Avaliação (teste).',
            WellChildSection.plano: 'Plano (teste).',
          },
        ),
      );
      await goTo(tester, '/pacientes/p1/consulta/${c.id}?etapa=resumo');
      expect(find.textContaining('marca RASCUNHO'), findsOneWidget);
      await tapText(tester, 'Finalizar puericultura');
      await tapText(tester, 'Finalizar', last: true);
      expect(c.isDraft, isFalse);
      expect(c.wellChild!.logoId, demoSession.myLogo!.id);
      expect(
        find.text('PDF com a logomarca gravada ao finalizar.'),
        findsOneWidget,
      );

      demoSession.lastPdf = null;
      await tapText(tester, 'Resumo em PDF');
      await waitPdf(tester);
      expect(pdfHasImage(), isTrue);
      expect(RegExp(r'/Width\s*300\b').hasMatch(pdfText()), isTrue);

      demoSession.uploadLogo(
        bytes: solidPng(400, 100, r: 200),
        fileName: 'logo-b.png',
      );
      demoSession.lastPdf = null;
      await tapText(tester, 'Imprimir');
      await waitPdf(tester);
      expect(demoSession.lastPdf!.$3, 'print');
      expect(RegExp(r'/Width\s*300\b').hasMatch(pdfText()), isTrue);
      expect(RegExp(r'/Width\s*400\b').hasMatch(pdfText()), isFalse);
    });
  });

  group('área da família e permissões', () {
    testWidgets('família vê só orientações emitidas das próprias crianças, '
        'com PDF e voltar', (WidgetTester tester) async {
      await pumpDemo(tester);
      final DemoPatient p = demoSession.patientById('p1')!;
      final ClinicalDocRecord draft = ClinicalDocRecord.createDraft(
        id: demoSession.newDocumentId(),
        kind: DocKind.orientacoes,
        patientId: p.id,
        author: demoSession.currentAuthor,
        context: demoDocContext(p),
        now: DateTime.now(),
        fields: <String, String>{
          'titulo': 'Orientação em revisão (teste)',
          'texto': 'Texto fictício ainda não emitido.',
        },
      );
      demoSession.saveDocument(draft);

      demoSession.enter(DemoProfile.responsavel);
      expect(
        demoSession.familyOrientations('p1').map((ClinicalDocRecord d) => d.id),
        <String>['d4'],
      );
      await goTo(tester, '/rotina/p1?vista=sono');
      await tapText(tester, 'Orientações da clínica (1)');
      expect(location(), '/rotina/p1/orientacoes');
      expect(find.text('Rotina e sono'), findsOneWidget);
      expect(find.text('Orientação em revisão (teste)'), findsNothing);

      await tapText(tester, 'Rotina e sono');
      expect(location(), '/rotina/p1/orientacoes/d4');
      expect(find.textContaining('Emitida em'), findsOneWidget);
      demoSession.lastPdf = null;
      await tapText(tester, 'Baixar PDF');
      await waitPdf(tester);
      expect(pdfText(), startsWith('%PDF-'));
      await tapFinder(tester, find.byType(BackButton));
      expect(location(), '/rotina/p1/orientacoes');
      await tapFinder(tester, find.byType(BackButton));
      expect(location(), contains('/rotina/p1?vista=sono'));

      await goTo(tester, '/rotina/p1/orientacoes/${draft.id}');
      expect(find.text('Orientação não encontrada'), findsOneWidget);
      await goTo(tester, '/rotina/p1/orientacoes/d1');
      expect(find.text('Orientação não encontrada'), findsOneWidget);
      await goTo(tester, '/rotina/p5/orientacoes');
      expect(find.text('Nenhuma orientação emitida'), findsOneWidget);
      await goTo(tester, '/rotina/p2/orientacoes');
      expect(find.byType(DemoFamilyOrientationsScreen), findsNothing);

      // Depois de revisada e emitida pelo profissional, chega à família.
      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/pacientes/p1/documentos/${draft.id}');
      await tapFinder(
        tester,
        find.byKey(const ValueKey<String>('review-check')),
      );
      await tapText(tester, 'Marcar como revisado');
      await tapText(tester, 'Emitir documento');
      demoSession.enter(DemoProfile.responsavel);
      expect(demoSession.familyOrientations('p1'), hasLength(2));

      // A rota da família não abre para o profissional.
      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/rotina/p1/orientacoes');
      expect(find.text('Acesso restrito'), findsOneWidget);
    });

    testWidgets('editor de orientação: modelos por tema e faixa etária, '
        'sugestão pela idade corrigida e novo modelo com tema', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/pacientes/p1/documentos/novo?tipo=orientacoes');
      expect(
        find.textContaining(
          'Faixa sugerida: 1 a 2 anos (pela idade corrigida)',
        ),
        findsOneWidget,
      );
      await tapFinder(
        tester,
        find
            .ancestor(
              of: find.text('Sono seguro'),
              matching: find.byType(RawChip),
            )
            .first,
      );
      expect(find.textContaining('Sono seguro · 1 a 2 anos'), findsWidgets);
      expect(find.textContaining('Sono seguro · 0 a 3 meses'), findsNothing);
      expect(find.textContaining('Rotina e sono · 1 a 2 anos'), findsNothing);
      await tapFinder(
        tester,
        find
            .ancestor(
              of: find.text('Todas as idades'),
              matching: find.byType(RawChip),
            )
            .first,
      );
      expect(find.textContaining('Sono seguro · 0 a 3 meses'), findsWidgets);

      await tapFinder(tester, find.text('Aplicar').first);
      final String text = ctrl(tester, 'campo-texto').text;
      expect(text, isNotEmpty);
      expect(text, isNot(contains('{{crianca}}')));

      await tapText(tester, 'Salvar texto atual como modelo');
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Sono seguro revisado (teste)',
      );
      await tapFinder(
        tester,
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.ancestor(
                of: find.text('Sono seguro'),
                matching: find.byType(RawChip),
              ),
            )
            .first,
      );
      await tapText(tester, 'Salvar modelo');
      final OrientationTemplate t = demoSession.myOrientationTemplates.first;
      expect(t.title, 'Sono seguro revisado (teste)');
      expect(t.band, ChildAgeBand.de1a2a);
      expect(t.topic, OrientationTopic.sonoSeguro);
      expect(t.ownerId, DemoProfessional.id);
      demoSession.switchAccount('prof-b');
      expect(
        demoSession.myOrientationTemplates.any(
          (OrientationTemplate x) => x.id == t.id,
        ),
        isFalse,
      );
    });

    testWidgets('recepção, financeiro, administrador e responsável não abrem '
        'a puericultura; profissional não edita o diário da família', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      for (final DemoProfile profile in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.administrador,
      ]) {
        demoSession.enter(profile);
        for (final String path in <String>[
          '/pacientes/p1/consulta/c3',
          '/pacientes/p1/consulta/c3?etapa=resumo',
          '/rotina/p1?vista=sono',
          '/rotina/p1/orientacoes',
          '/rotina/p1/orientacoes/d4',
        ]) {
          await goTo(tester, path);
          expect(
            find.text('Acesso restrito'),
            findsOneWidget,
            reason: '${profile.name} em $path',
          );
        }
        await goTo(tester, '/pacientes/p1');
        expect(find.text('Consulta de puericultura'), findsNothing);
      }

      demoSession.enter(DemoProfile.responsavel);
      await goTo(tester, '/pacientes/p1/consulta/c3');
      expect(find.text('Acesso restrito'), findsOneWidget);
      await goTo(tester, '/pacientes/p1');
      expect(find.text('Consulta de puericultura'), findsNothing);
      expect(find.text('Orientações da clínica'), findsOneWidget);

      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/rotina/p5?vista=sono');
      expect(find.text('Rotina não compartilhada'), findsOneWidget);
      await goTo(tester, '/rotina/p1?vista=sono');
      expect(find.text('Resumo da semana'), findsOneWidget);
      expect(find.text('Registrar sono'), findsNothing);
      expect(demoSession.canEditRoutine, isFalse);
    });
  });
}
