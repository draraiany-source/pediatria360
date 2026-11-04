import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_care.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/shared/care/care_model.dart';
import 'package:pediatria360/shared/care/care_store.dart';

/// Cuidado multidisciplinar na demo: a Luna (p1) é atendida por pediatra,
/// psicóloga e fisioterapeuta da mesma clínica.
void main() {
  const String private = DemoCareTeam.privateMarker;
  const String full = DemoCareTeam.fullRecordMarker;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

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
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    demoRouter.go(location);
    await settle(tester);
  }

  Future<void> as(
    WidgetTester tester,
    DemoProfile profile, {
    String? account,
  }) async {
    demoSession.enter(profile);
    if (account != null) demoSession.switchAccount(account);
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

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey<String>(key)));

  Future<void> type(WidgetTester tester, String key, String text) async {
    final Finder f = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pump();
  }

  CareStore store() => demoSession.care.store;

  CareRecord recordOf(String title) => store().records.firstWhere(
    (CareRecord r) => r.childId == 'p1' && r.title == title,
  );

  CareLink linkOf(String professionalId) => store().links.lastWhere(
    (CareLink l) => l.childId == 'p1' && l.professionalId == professionalId,
  );

  bool checked(WidgetTester tester, String key) => tester
      .widget<CheckboxListTile>(find.byKey(ValueKey<String>(key)))
      .value!;

  testWidgets('agendas separadas: cada área mostra só as próprias sessões', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.text('Agenda da psicologia'), findsOneWidget);
    expect(
      find.textContaining('Psicologia com Psicóloga Exemplo Ramos'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Fisioterapia com'), findsNothing);

    // Na área da fisioterapia, a psicóloga não vê agenda nem registros.
    await goTo(tester, '/cuidado/p1?aba=fisioterapia');
    expect(find.text('Agenda da fisioterapia'), findsNothing);
    expect(find.text('Resumos da fisioterapia para você'), findsOneWidget);

    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=fisioterapia');
    expect(
      find.textContaining('Fisioterapia com Fisioterapeuta Exemplo Moura'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Psicologia com'), findsNothing);

    for (final String id in <String>['psi-a', 'fis-a']) {
      final Set<String> owners = <String>{
        for (final DemoAppointment a in demoSession.appointments)
          if (DemoCare.specialtyOf(a.professionalId) == DemoCare.specialtyOf(id))
            a.professionalId,
      };
      expect(owners, <String>{id});
    }
  });

  testWidgets('psicóloga não usa ferramentas médicas e só vê a criança '
      'vinculada', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    expect(demoSession.isPediatrician, isFalse);
    expect(
      demoSession.visiblePatients.map((DemoPatient p) => p.id),
      <String>['p1'],
    );
    for (final String route in <String>[
      '/calculadora',
      '/pacientes/p1/prontuario',
      '/suplementacao',
    ]) {
      await goTo(tester, route);
      expect(find.text('Acesso restrito'), findsWidgets, reason: route);
    }

    demoSession.switchAccount('psi-c');
    await settle(tester);
    expect(demoSession.visiblePatients, isEmpty);
    await goTo(tester, '/cuidado/p1');
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
  });

  testWidgets('pediatra lê o resumo da psicóloga, não a evolução completa, '
      'as anotações privadas nem o anexo', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.textContaining(full), findsWidgets);
    expect(find.textContaining(private), findsWidgets);
    expect(find.textContaining('desenho-sessao-1-exemplo.png'), findsOneWidget);

    demoSession.switchAccount('prof-a');
    for (final String tab in <String>['equipe', 'psicologia']) {
      await goTo(tester, '/cuidado/p1?aba=$tab');
      expect(find.text('Hipótese de trabalho'), findsOneWidget, reason: tab);
      expect(find.textContaining('Sugiro reforçar a rotina'), findsOneWidget);
      expect(find.textContaining(full), findsNothing, reason: tab);
      expect(find.textContaining(private), findsNothing, reason: tab);
      expect(find.textContaining('desenho-sessao-1-exemplo'), findsNothing);
    }
    expect(find.text('Compartilhado com você'.toUpperCase()), findsOneWidget);

    // A fisioterapeuta não recebeu este resumo.
    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Hipótese de trabalho'), findsNothing);
    expect(find.textContaining('Crescimento adequado'), findsOneWidget);
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.text('Nada desta área foi compartilhado com você.'), findsOneWidget);
    expect(find.textContaining(full), findsNothing);

    // A autora vê quem acessou.
    final CareSummary sum = store().summaryOf(recordOf('Avaliação inicial').id)!;
    expect(
      sum.accessLog.map((CareSummaryAccess a) => a.actorId).toSet(),
      <String>{'prof-a'},
    );
  });

  testWidgets('assistente do resumo: nada marcado, destinatário escolhido, '
      'prévia, confirmação e retirada do acesso', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    final CareRecord session = recordOf('Sessão 2');
    final CareSection clinical = session.sections.firstWhere(
      (CareSection s) => s.kind == CareSectionKind.clinica,
    );
    await tapKey(tester, 'resumo-${session.id}');
    expect(find.text('Passo 1 de 3: Informações'), findsOneWidget);
    expect(checked(tester, 'item-${CareRecord.bodyItemId}'), isFalse);
    expect(checked(tester, 'item-${clinical.id}'), isFalse);
    for (final CareSection s in session.lockedSections) {
      expect(find.byKey(ValueKey<String>('bloqueado-${s.id}')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('item-${s.id}')), findsNothing);
    }

    await tapKey(tester, 'proximo-1');
    expect(find.text('Passo 1 de 3: Informações'), findsOneWidget);
    await tapKey(tester, 'item-${clinical.id}');
    await tapKey(tester, 'proximo-1');
    expect(find.text('Passo 2 de 3: Destinatários'), findsOneWidget);
    await tapKey(tester, 'proximo-2');
    expect(find.text('Passo 2 de 3: Destinatários'), findsOneWidget);
    await tapKey(tester, 'publico-selecionados');
    expect(checked(tester, 'dest-fis-a'), isFalse);
    expect(checked(tester, 'dest-prof-a'), isFalse);
    await tapKey(tester, 'dest-fis-a');
    await tapKey(tester, 'proximo-2');

    expect(find.text('Passo 3 de 3: Prévia e confirmação'), findsOneWidget);
    final Finder preview = find.byKey(const ValueKey<String>('previa'));
    expect(
      find.descendant(of: preview, matching: find.textContaining('Aceitou dormir')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining('Fisioterapeuta Exemplo Moura'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.textContaining(private)),
      findsNothing,
    );
    expect(
      find.descendant(of: preview, matching: find.textContaining(full)),
      findsNothing,
    );
    expect(store().summaryOf(session.id), isNull);
    await tapKey(tester, 'compartilhar');
    await tapKey(tester, 'confirmar-compartilhamento');
    expect(find.text('Resumo compartilhado'), findsOneWidget);
    final CareSummary sum = store().summaryOf(session.id)!;
    expect(sum.recipientIds, <String>['fis-a']);

    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.textContaining('Aceitou dormir com a porta'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
    demoSession.switchAccount('prof-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.textContaining('Aceitou dormir com a porta'), findsNothing);

    // A psicóloga encerra o acesso; a fisioterapeuta deixa de ver.
    demoSession.switchAccount('psi-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    await tapKey(tester, 'encerrar-resumo-${sum.id}');
    await type(tester, 'motivo', 'Conduta revista (teste)');
    await tapKey(tester, 'confirmar-motivo');
    expect(sum.status, CareSummaryStatus.encerrado);
    expect(sum.versions, hasLength(2));
    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.textContaining('Aceitou dormir com a porta'), findsNothing);
  });

  testWidgets('só a autora abre o assistente do resumo', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'prof-a');
    await goTo(tester, '/cuidado/p1/resumo/${recordOf('Sessão 2').id}');
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
  });

  testWidgets('acesso concedido com justificativa mostra o registro sem as '
      'partes privadas e pode ser retirado', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    final CareRecord eval = recordOf('Avaliação inicial');
    await tapKey(tester, 'conceder-${eval.id}');
    await tapKey(tester, 'conceder-para-prof-a');
    await type(tester, 'justificativa', 'Avaliar a medicação em uso (teste)');
    await tapKey(tester, 'salvar-concessao');
    final CareRecordGrant g = store().grants.single;

    demoSession.switchAccount('prof-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.text('Registros com acesso concedido a você'), findsOneWidget);
    expect(find.textContaining(full), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
    expect(find.textContaining('parte(s) privada(s)'), findsOneWidget);
    expect(find.textContaining('desenho-sessao-1-exemplo.png'), findsOneWidget);

    demoSession.switchAccount('psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    await tapFinder(tester, find.byKey(ValueKey<String>('concessoes-${eval.id}')));
    await tapKey(tester, 'revogar-${g.id}');
    await type(tester, 'motivo', 'Avaliação concluída (teste)');
    await tapKey(tester, 'confirmar-motivo');
    expect(g.active, isFalse);

    demoSession.switchAccount('prof-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.textContaining(full), findsNothing);
    expect(find.textContaining('desenho-sessao-1-exemplo'), findsNothing);
  });

  testWidgets('plano terapêutico conjunto: objetivo, contribuição e '
      'reavaliação', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'prof-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Plano terapêutico conjunto'), findsOneWidget);
    expect(find.text('Dormir no próprio quarto 5 noites por semana'), findsOneWidget);
    await tapKey(tester, 'novo-objetivo');
    await type(tester, 'objetivo-texto', 'Subir degraus alternando os pés');
    await tapKey(tester, 'resp-fis-a');
    await tapKey(tester, 'prazo-30');
    await type(tester, 'objetivo-acao', 'Treino de escada (teste)');
    await tapKey(tester, 'salvar-objetivo');
    final CarePlan plan = store().plans.values.firstWhere(
      (CarePlan p) => p.childId == 'p1',
    );
    final CarePlanGoal g = plan.goals.last;
    expect(g.objective, 'Subir degraus alternando os pés');
    expect(g.responsibleId, 'fis-a');
    expect(g.actions.single.text, 'Treino de escada (teste)');
    expect(find.byKey(ValueKey<String>('reavaliar-${g.id}')), findsNothing);

    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    await tapKey(tester, 'contribuir-${g.id}');
    await tapKey(tester, 'contrib-informacao');
    await type(tester, 'contrib-texto', 'Sobe 2 degraus com apoio (teste)');
    await tapKey(tester, 'salvar-contribuicao');
    expect(g.shared.single.authorName, 'Fisioterapeuta Exemplo Moura');
    await tapKey(tester, 'reavaliar-${g.id}');
    await tapKey(tester, 'status-revisar');
    await type(tester, 'reaval-nota', 'Ajustar a frequência (teste)');
    await tapKey(tester, 'salvar-reavaliacao');
    expect(g.status, CareGoalStatus.revisar);
    expect(find.textContaining('Sobe 2 degraus com apoio'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
  });

  testWidgets('família vê só o que cada profissional liberou', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    expect(find.textContaining('Brincadeira do flamingo'), findsOneWidget);
    expect(find.textContaining('Rotina do sono em 3 passos'), findsOneWidget);
    expect(find.textContaining('Degraus alternados'), findsNothing);
    expect(find.textContaining(private), findsNothing);
    expect(find.textContaining(full), findsNothing);
    expect(find.text('Hipótese de trabalho'), findsNothing);
    expect(find.text('Comunicação da equipe'), findsNothing);
    expect(find.text('Plano terapêutico conjunto'), findsNothing);

    await as(tester, DemoProfile.profissional, account: 'fis-a');
    await goTo(tester, '/cuidado/p1?aba=fisioterapia');
    await tapKey(tester, 'liberar-${recordOf('Degraus alternados').id}');

    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    expect(find.textContaining('Degraus alternados'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
  });

  testWidgets('troca de profissional: gestão designa, família autoriza, o '
      'privado continua com a autora', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.administrador);
    await goTo(tester, '/cuidado/p1');
    expect(find.textContaining(private), findsNothing);
    await tapKey(tester, 'encerrar-${linkOf('psi-a').id}');
    await type(tester, 'motivo', 'Troca de profissional (teste)');
    await tapKey(tester, 'confirmar-motivo');
    expect(linkOf('psi-a').active, isFalse);

    await tapKey(tester, 'designar');
    await tapFinder(tester, find.textContaining('Psicólogo Exemplo Teixeira'));
    await type(tester, 'designar-motivo', 'Assume a psicologia (teste)');
    await tapFinder(tester, find.text('Designar'));
    expect(linkOf('psi-c').pending, isTrue);

    await as(tester, DemoProfile.profissional, account: 'psi-c');
    expect(demoSession.care.canOpen('p1'), isFalse);

    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    expect(find.text('Autorizações pendentes'), findsOneWidget);
    await tapKey(tester, 'autorizar-${linkOf('psi-c').id}');
    expect(linkOf('psi-c').active, isTrue);

    await as(tester, DemoProfile.profissional, account: 'psi-c');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.text('Nenhum registro seu nesta área.'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
    expect(find.textContaining(full), findsNothing);

    demoSession.switchAccount('psi-a');
    await goTo(tester, '/cuidado/p1');
    expect(
      find.textContaining('Seu vínculo com a criança foi encerrado'),
      findsOneWidget,
    );
    expect(find.textContaining(private), findsWidgets);
    expect(find.byKey(const ValueKey<String>('aba-equipe')), findsNothing);
    expect(find.byKey(const ValueKey<String>('novo-registro')), findsNothing);
  });

  testWidgets('troca de clínica: equipe anterior sai e a nova não vê '
      'registros nem resumos antigos', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    await tapKey(tester, 'trocar-clinica');
    await tapKey(tester, 'confirmar-troca');
    for (final String id in <String>['prof-a', 'psi-a', 'fis-a']) {
      expect(linkOf(id).active, isFalse, reason: id);
    }
    expect(linkOf('prof-b').pending, isTrue);
    expect(find.textContaining('Brincadeira do flamingo'), findsOneWidget);
    await tapKey(tester, 'autorizar-${linkOf('prof-b').id}');

    await as(tester, DemoProfile.profissional, account: 'prof-b');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Profissionais envolvidos'), findsOneWidget);
    expect(find.textContaining(private), findsNothing);
    expect(find.text('Hipótese de trabalho'), findsNothing);
    expect(find.text('Nenhum resumo compartilhado com você.'), findsOneWidget);
    expect(find.text('Ainda sem objetivos no plano conjunto.'), findsOneWidget);
    expect(
      demoSession.care
          .nextSessions('p1')
          .where((DemoAppointment a) => a.professionalId != 'prof-b'),
      isEmpty,
    );

    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Profissionais envolvidos'), findsNothing);
  });
}
