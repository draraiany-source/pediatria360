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
  const String marker = DemoCareTeam.reservedMarker;

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

  String recordId(String title) => demoSession.care.store.records
      .firstWhere((CareRecord r) => r.childId == 'p1' && r.title == title)
      .id;

  CareLink linkOf(String professionalId) => demoSession.care.store.links
      .lastWhere(
        (CareLink l) => l.childId == 'p1' && l.professionalId == professionalId,
      );

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

    await goTo(tester, '/cuidado/p1?aba=fisioterapia');
    expect(
      find.textContaining('Fisioterapia com Fisioterapeuta Exemplo Moura'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Psicologia com'), findsNothing);

    // Na agenda pessoal, cada profissional só tem os próprios horários.
    for (final String id in <String>['psi-a', 'fis-a']) {
      final Set<String> owners = <String>{
        for (final DemoAppointment a in demoSession.appointments)
          if (DemoCare.specialtyOf(a.professionalId) == DemoCare.specialtyOf(id))
            a.professionalId,
      };
      expect(owners, <String>{id});
    }
    await goTo(tester, '/inicio');
    expect(find.text('Próximas sessões'), findsOneWidget);
    expect(find.text('Nenhuma sessão agendada.'), findsNothing);
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

    // Mesma clínica, sem vínculo: nada abre.
    demoSession.switchAccount('psi-c');
    await settle(tester);
    expect(demoSession.visiblePatients, isEmpty);
    await goTo(tester, '/cuidado/p1');
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.textContaining(marker), findsNothing);
  });

  testWidgets('registro reservado: só a psicóloga lê; a equipe vê o resumo', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.profissional, account: 'psi-a');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.textContaining(marker), findsWidgets);
    expect(
      find.text('Reservado ao profissional responsável'.toUpperCase()),
      findsWidgets,
    );

    for (final String other in <String>['prof-a', 'fis-a']) {
      demoSession.switchAccount(other);
      await goTo(tester, '/cuidado/p1?aba=psicologia');
      expect(find.textContaining(marker), findsNothing, reason: other);
      expect(find.text('Plano terapêutico'), findsWidgets, reason: other);
      expect(
        find.text('Resumo compartilhado'.toUpperCase()),
        findsWidgets,
        reason: other,
      );
    }

    // Plano combinado: um só para a equipe toda.
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Plano combinado'), findsOneWidget);
    expect(find.text('Profissionais envolvidos'), findsOneWidget);
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
    expect(find.textContaining(marker), findsNothing);
    expect(find.text('Comunicação da equipe'), findsNothing);

    // A fisioterapeuta libera o exercício; a família passa a ver.
    await as(tester, DemoProfile.profissional, account: 'fis-a');
    await goTo(tester, '/cuidado/p1?aba=fisioterapia');
    await tapKey(tester, 'liberar-${recordId('Degraus alternados')}');

    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    expect(find.textContaining('Degraus alternados'), findsOneWidget);
    expect(find.textContaining(marker), findsNothing);
  });

  testWidgets('troca de profissional: gestão designa, família autoriza, '
      'reservado continua com a autora', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.administrador);
    await goTo(tester, '/cuidado/p1');
    expect(find.textContaining(marker), findsNothing);
    await tapKey(tester, 'encerrar-${linkOf('psi-a').id}');
    await type(tester, 'motivo', 'Troca de profissional (teste)');
    await tapKey(tester, 'confirmar-motivo');
    expect(linkOf('psi-a').active, isFalse);

    await tapKey(tester, 'designar');
    await tapFinder(tester, find.textContaining('Psicólogo Exemplo Teixeira'));
    await type(tester, 'designar-motivo', 'Assume a psicologia (teste)');
    await tapFinder(tester, find.text('Designar'));
    expect(linkOf('psi-c').pending, isTrue);

    // Sem a autorização da família, o novo psicólogo ainda não entra.
    await as(tester, DemoProfile.profissional, account: 'psi-c');
    expect(demoSession.care.canOpen('p1'), isFalse);

    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    expect(find.text('Autorizações pendentes'), findsOneWidget);
    await tapKey(tester, 'autorizar-${linkOf('psi-c').id}');
    expect(linkOf('psi-c').active, isTrue);

    await as(tester, DemoProfile.profissional, account: 'psi-c');
    await goTo(tester, '/cuidado/p1?aba=psicologia');
    expect(find.text('Plano terapêutico'), findsWidgets);
    expect(find.textContaining(marker), findsNothing);

    // A psicóloga anterior vê só o que escreveu, para leitura.
    demoSession.switchAccount('psi-a');
    await goTo(tester, '/cuidado/p1');
    expect(
      find.textContaining('Seu vínculo com a criança foi encerrado'),
      findsOneWidget,
    );
    expect(find.textContaining(marker), findsWidgets);
    expect(find.byKey(const ValueKey<String>('aba-equipe')), findsNothing);
    expect(find.byKey(const ValueKey<String>('novo-registro')), findsNothing);
  });

  testWidgets('troca de clínica: equipe anterior sai e a nova não vê os '
      'registros antigos', (WidgetTester tester) async {
    await pumpDemo(tester);
    await as(tester, DemoProfile.responsavel);
    await goTo(tester, '/cuidado/p1?aba=familia');
    await tapKey(tester, 'trocar-clinica');
    await tapKey(tester, 'confirmar-troca');
    for (final String id in <String>['prof-a', 'psi-a', 'fis-a']) {
      expect(linkOf(id).active, isFalse, reason: id);
    }
    expect(linkOf('prof-b').pending, isTrue);
    // O que já foi liberado continua com a família.
    expect(find.textContaining('Brincadeira do flamingo'), findsOneWidget);
    await tapKey(tester, 'autorizar-${linkOf('prof-b').id}');

    await as(tester, DemoProfile.profissional, account: 'prof-b');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Profissionais envolvidos'), findsOneWidget);
    expect(find.textContaining(marker), findsNothing);
    // Sessões com a equipe anterior não aparecem para a nova clínica.
    expect(
      demoSession.care
          .nextSessions('p1')
          .where((DemoAppointment a) => a.professionalId != 'prof-b'),
      isEmpty,
    );
    expect(find.textContaining('Psicologia com'), findsNothing);
    expect(find.textContaining('Fisioterapia com'), findsNothing);
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final Set<String> fromOtherClinic = <String>{
      for (final CareRecord r in store.records)
        if (r.childId == 'p1' && r.clinicId != actor.clinicId) r.id,
    };
    expect(fromOtherClinic, isNotEmpty);
    expect(
      store
          .sharedView(actor, 'p1')
          .items
          .where((CareSharedItem i) => fromOtherClinic.contains(i.recordId)),
      isEmpty,
    );

    // A fisioterapeuta da clínica anterior perde o acesso à equipe.
    demoSession.switchAccount('fis-a');
    await goTo(tester, '/cuidado/p1?aba=equipe');
    expect(find.text('Profissionais envolvidos'), findsNothing);
  });
}
