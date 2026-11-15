import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_clinical.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_previsit_seed.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/shared/clinical/file_input.dart';
import 'package:pediatria360/shared/previsit/pre_visit.dart';

import 'support/png_fixture.dart';

/// Anexos da pré-consulta, com crianças e arquivos fictícios.
void main() {
  tearDown(() => debugPickFile = null);

  Future<void> pumpDemo(
    WidgetTester tester, {
    Size size = const Size(430, 932),
    DemoProfile profile = DemoProfile.responsavel,
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

  String location() =>
      demoRouter.routerDelegate.currentConfiguration.uri.toString();

  /// A lista da tela só constrói o que está perto da área visível.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    final Finder list = find.byKey(
      const ValueKey<String>('pre-consulta-lista'),
    );
    if (f.evaluate().isNotEmpty || list.evaluate().isEmpty) return;
    final Finder scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    for (final double delta in <double>[250, -250]) {
      try {
        await tester.scrollUntilVisible(f, delta, scrollable: scrollable);
        await tester.pumpAndSettle();
        return;
      } on StateError {
        continue;
      }
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

  Future<void> tapText(WidgetTester tester, String text) async {
    await reveal(tester, find.text(text));
    await tapFinder(tester, find.text(text).last);
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await reveal(tester, find.bySemanticsLabel(label));
    await tapFinder(tester, find.bySemanticsLabel(label).last);
  }

  Future<void> expectShown(
    WidgetTester tester,
    Finder f, [
    Matcher m = findsOneWidget,
  ]) async {
    await reveal(tester, f);
    expect(f, m);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (Widget w) => w is TextField && w.decoration?.labelText == label,
  );

  void offer(String name, Uint8List bytes, {String? accept}) {
    debugPickFile = (String a) async {
      if (accept != null) expect(a, accept);
      return PickedFile(name: name, mimeType: '', bytes: bytes);
    };
  }

  DemoAppointment appt(String id) => demoSession.appointmentById(id)!;

  String dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  for (final (String label, Size size) in <(String, Size)>[
    ('celular', const Size(390, 844)),
    ('computador', const Size(1280, 860)),
  ]) {
    testWidgets('$label: família anexa foto e PDF, confere, remove o errado '
        'e envia; profissional vê organizado', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpDemo(tester, size: size);
      final String day = dmy(appt('a6').start);

      await goTo(tester, '/inicio');
      await tester.dragUntilVisible(
        find.textContaining('Pré-consulta: Enviada em'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      expect(find.textContaining('Pré-consulta: Enviada em'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Preencher pré-consulta de $day'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await settle(tester);
      expect(find.text('Pré-consulta: Não preenchida'), findsWidgets);
      await tapText(tester, 'Preencher pré-consulta de $day');
      expect(location(), '/pre-consulta/a6?de=inicio');
      expect(find.text('Não preenchida'), findsOneWidget);
      expect(find.text(PreVisitRules.notDiagnosis), findsOneWidget);

      await tester.enterText(
        field('Motivo da consulta'),
        'Febre baixa e mancha',
      );
      await settle(tester);
      expect(find.text('Rascunho: a clínica ainda não vê'), findsOneWidget);

      // Foto da queixa: prévia antes de incluir.
      offer('mancha.png', solidPng(40, 30), accept: 'image/*');
      await tapText(tester, 'Adicionar foto da queixa');
      expect(find.text('Conferir anexo antes de incluir'), findsOneWidget);
      expect(find.bySemanticsLabel('Prévia de mancha.png'), findsOneWidget);
      expect(find.text('Data da foto (opcional)'), findsOneWidget);
      await tester.enterText(field('Descrição (opcional)'), 'Mancha na perna');
      await tapText(tester, 'Incluir anexo');
      expect(find.text('Conferir anexo antes de incluir'), findsNothing);
      await expectShown(tester, find.text('Fotos da queixa (1)'));
      await expectShown(tester, find.text('Ainda não enviado'));

      // PDF de laudo: tipo e data obrigatórios.
      offer(
        'laudo.pdf',
        DemoPreVisitSeed.samplePdf(),
        accept: PreVisitRules.accept,
      );
      await tapText(tester, 'Adicionar exame, laudo ou relatório');
      expect(find.text('PDF com 1 página'), findsOneWidget);
      expect(find.text('Abrir PDF para conferir'), findsOneWidget);
      await tapText(tester, 'Incluir anexo');
      expect(find.text('Escolha o tipo do documento.'), findsOneWidget);
      await tapText(tester, 'Laudo');
      await tapText(tester, 'Incluir anexo');
      expect(
        find.text('Informe a data do exame (dd/mm/aaaa).'),
        findsOneWidget,
      );
      final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.enterText(field('Data do exame *'), dmy(tomorrow));
      await tapText(tester, 'Incluir anexo');
      expect(find.text('A data não pode ser futura.'), findsOneWidget);
      final DateTime examDay = DateTime.now().subtract(const Duration(days: 5));
      await tester.enterText(field('Data do exame *'), dmy(examDay));
      await tapText(tester, 'Incluir anexo');
      await expectShown(tester, find.text('Exames, laudos e relatórios (1)'));
      await expectShown(
        tester,
        find.text('Laudo - Data do exame: ${dmy(examDay)}'),
      );

      // Selecionado por engano: removido antes do envio.
      offer('errado.png', solidPng(20, 20));
      await tapText(tester, 'Adicionar foto da queixa');
      await tapText(tester, 'Incluir anexo');
      await expectShown(tester, find.text('Fotos da queixa (2)'));
      await tapLabel(tester, 'Remover errado.png');
      expect(find.text('Remover anexo?'), findsOneWidget);
      await tapText(tester, 'Remover');
      await expectShown(tester, find.text('Fotos da queixa (1)'));
      expect(demoSession.preVisits['a6']!.attachments.length, 2);
      expect(find.textContaining('errado.png'), findsNothing);

      // Visualizar antes do envio.
      await tapLabel(tester, 'Ver mancha.png');
      expect(
        find.text(
          'Arquivo enviado pela família. Não é diagnóstico nem resultado '
          'validado.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Fechar');

      // Rascunho não chega à clínica.
      demoSession.enter(DemoProfile.profissional);
      expect(
        demoSession
            .sentPreVisitsFor('p1')
            .map(((DemoAppointment, PreVisit) e) => e.$1.id),
        <String>['a1'],
      );
      demoSession.enter(DemoProfile.responsavel);
      await settle(tester);

      await tapText(tester, 'Enviar à clínica');
      expect(
        find.textContaining('Confirme que as informações e os anexos'),
        findsOneWidget,
      );
      await reveal(tester, find.byType(Checkbox));
      await tapFinder(tester, find.byType(Checkbox));
      await tapText(tester, 'Enviar à clínica');
      expect(
        find.text('Pré-consulta enviada à clínica com 2 anexos.'),
        findsOneWidget,
      );
      expect(demoSession.preVisits['a6']!.drafts, isEmpty);
      await expectShown(tester, find.text('Enviar alterações'));

      // Profissional autorizado: organizado por consulta e por tipo.
      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/pacientes/p1/pre-consulta');
      expect(find.text('Consulta de $day às 09:30'), findsOneWidget);
      final List<(DemoAppointment, PreVisit)> sent = demoSession
          .sentPreVisitsFor('p1');
      expect(sent.map(((DemoAppointment, PreVisit) e) => e.$1.id), <String>[
        'a6',
        'a1',
      ]);
      for (final (DemoAppointment _, PreVisit v) in sent) {
        expect(
          groupSentAttachments(v).map(
            ((String, List<PreVisitAttachment>) g) => '${g.$1} ${g.$2.length}',
          ),
          <String>['Fotos da queixa 1', 'Exames, laudos e relatórios 1'],
        );
      }
      // Resumo organizado por regras e a resposta original da família.
      await expectShown(
        tester,
        find.textContaining('Febre baixa e mancha'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('Organizado por regras, sem IA'),
        findsWidgets,
      );
      await expectShown(tester, find.text('Mancha na perna'));
      expect(find.text('Remover'), findsNothing);
      await tapLabel(tester, 'Ver laudo.pdf');
      expect(find.text('Abrir PDF para conferir'), findsOneWidget);
      await tapText(tester, 'Fechar');
      await expectShown(tester, find.text('Mancha no braço (fictícia)'));
      await expectShown(tester, find.text('Hemograma (fictício)'));
      expect(find.text('Remover'), findsNothing);
      expect(find.text('Adicionar foto da queixa'), findsNothing);
      semantics.dispose();
    });
  }

  testWidgets('mensagens claras para arquivos recusados', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await goTo(tester, '/pre-consulta/a6');

    Future<void> refused(String name, Uint8List bytes, String part) async {
      offer(name, bytes);
      await tapText(tester, 'Adicionar exame, laudo ou relatório');
      expect(find.text('Arquivo não anexado'), findsOneWidget);
      expect(find.textContaining(part), findsOneWidget);
      await tapText(tester, 'Entendi');
      expect(demoSession.preVisits['a6']!.attachments, isEmpty);
    }

    await refused(
      'IMG_1.HEIC',
      Uint8List.fromList(<int>[0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0]),
      'formato HEIC',
    );
    await refused(
      'exame.pdf',
      Uint8List.fromList(utf8.encode('não é PDF')),
      'embora o nome termine como um deles',
    );
    final Uint8List big = Uint8List(PreVisitRules.maxFileBytes + 1)
      ..setAll(0, solidPng(1, 1).sublist(0, 8));
    await refused('enorme.png', big, 'O limite é 10 MB por arquivo');
    await refused(
      'senha.pdf',
      Uint8List.fromList(latin1.encode('%PDF-1.7 /Encrypt 3 0 R')),
      'protegido por senha',
    );
    await refused('vazio.jpg', Uint8List(0), 'está vazio');

    // PDF escolhido pelo botão de foto: "Foto da queixa" fica desativado.
    offer('exame.pdf', DemoPreVisitSeed.samplePdf());
    await tapText(tester, 'Adicionar foto da queixa');
    final ChoiceChip photoChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Foto da queixa'),
    );
    expect(photoChip.onSelected, isNull);
    await tapText(tester, 'Cancelar');
    expect(demoSession.preVisits['a6']!.attachments, isEmpty);
  });

  testWidgets('consulta do profissional mostra a pré-consulta e volta para '
      'ela', (WidgetTester tester) async {
    await pumpDemo(tester, profile: DemoProfile.profissional);
    await goTo(tester, '/pacientes/p1/consulta/c1');
    expect(find.text('Pré-consulta enviada pela família'), findsOneWidget);
    expect(
      find.textContaining('1 foto(s) da queixa e 1 exame(s), laudo(s)'),
      findsOneWidget,
    );
    await tapText(tester, 'Ver pré-consulta');
    expect(location(), '/pacientes/p1/pre-consulta?consulta=c1');
    await expectShown(tester, find.text('Mancha no braço (fictícia)'));
    await expectShown(tester, find.text('Hemograma (fictício)'));
    await tapFinder(tester, find.byType(BackButton));
    expect(location(), '/pacientes/p1/consulta/c1');

    await goTo(tester, '/pacientes/p1');
    expect(find.text('Pré-consulta enviada pela família'), findsOneWidget);
    await goTo(tester, '/agenda/a1');
    expect(find.textContaining('com 2 anexos.'), findsOneWidget);
    await tapText(tester, 'Ver pré-consulta');
    expect(location(), '/pacientes/p1/pre-consulta');
    await settle(tester);
  });

  testWidgets('permissões: só o responsável vinculado e a equipe '
      'autorizada', (WidgetTester tester) async {
    await pumpDemo(tester, profile: DemoProfile.recepcao);

    // Recepção: só a situação.
    await goTo(tester, '/agenda/a1');
    expect(find.textContaining('com 2 anexos.'), findsOneWidget);
    expect(
      find.text('Respostas e anexos só o profissional abre.'),
      findsOneWidget,
    );
    expect(find.text('Ver pré-consulta'), findsNothing);
    await goTo(tester, '/pacientes/p1/pre-consulta');
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(demoSession.sentPreVisitsFor('p1'), isEmpty);

    for (final DemoProfile p in <DemoProfile>[
      DemoProfile.financeiro,
      DemoProfile.administrador,
    ]) {
      demoSession.enter(p);
      await goTo(tester, '/pacientes/p1/pre-consulta');
      expect(find.text('Acesso restrito'), findsOneWidget, reason: p.name);
      await goTo(tester, '/pre-consulta/a1');
      expect(find.text('Acesso restrito'), findsOneWidget, reason: p.name);
      expect(demoSession.preVisitStatus('a1'), isNull);
    }

    // Profissional de outra clínica.
    demoSession.enter(DemoProfile.profissional);
    await goTo(tester, '/pre-consulta/a1');
    expect(find.text('Acesso restrito'), findsOneWidget);
    demoSession.switchAccount(DemoProfessional.colleague.id);
    await goTo(tester, '/pacientes/p1/pre-consulta');
    expect(
      find.textContaining('Esta conta é de outra clínica'),
      findsOneWidget,
    );
    await goTo(tester, '/pacientes/p1/consulta/c1');
    expect(find.text('Pré-consulta enviada pela família'), findsNothing);
    expect(demoSession.sentPreVisitsFor('p1'), isEmpty);
    demoSession.switchAccount(DemoProfessional.id);

    // Responsável: criança de outra família.
    demoSession.enter(DemoProfile.responsavel);
    await goTo(tester, '/pre-consulta/a2');
    expect(find.text('Pré-consulta indisponível'), findsOneWidget);
    expect(
      () => demoSession.addPreVisitAttachment(
        'a2',
        name: 'x.png',
        bytes: solidPng(4, 4),
        type: PreVisitDocType.fotoQueixa,
      ),
      throwsStateError,
    );
    expect(demoSession.sentPreVisitsFor('p1'), isEmpty);

    // Consulta concluída: só leitura.
    demoSession.setAppointmentStatus(
      appt('a1'),
      DemoAppointmentStatus.concluido,
    );
    await goTo(tester, '/pre-consulta/a1');
    expect(
      find.textContaining('Consulta concluída: a pré-consulta fica apenas'),
      findsOneWidget,
    );
    await expectShown(tester, find.text('Ver'), findsNWidgets(2));
    expect(find.text('Adicionar foto da queixa'), findsNothing);
    expect(find.text('Remover'), findsNothing);
    expect(
      () => demoSession.removePreVisitAttachment('a1', 'pa1'),
      throwsStateError,
    );
  });

  test('remover anexo já enviado fica no histórico e some para a clínica', () {
    demoSession.leave();
    demoSession.enter(DemoProfile.responsavel);
    demoSession.removePreVisitAttachment('a1', 'pa1');
    final PreVisit v = demoSession.preVisits['a1']!;
    expect(
      v.history.last.text,
      'A família removeu o anexo "foto_braco.png" já enviado',
    );
    demoSession.enter(DemoProfile.profissional);
    expect(
      demoSession
          .sentPreVisitsFor('p1')
          .single
          .$2
          .sentAttachments
          .map((PreVisitAttachment a) => a.id),
      <String>['pa2'],
    );
    demoSession.leave();
  });
}
