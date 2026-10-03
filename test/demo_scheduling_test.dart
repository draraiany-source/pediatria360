import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_scheduling.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/screens/restricted_screen.dart';
import 'package:pediatria360/shared/scheduling/booking_assistant.dart';
import 'package:pediatria360/shared/scheduling/follow_up.dart';
import 'package:pediatria360/shared/scheduling/reminders.dart';
import 'package:pediatria360/shared/scheduling/slots.dart';

/// Acompanhamento, lembretes e agendamento assistido na demonstração.
void main() {
  DateTime todayAt(int h, [int m = 0]) {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day, h, m);
  }

  DemoScheduling fresh(DemoProfile profile, {DateTime? at}) {
    demoSession.leave();
    demoSession.enter(profile);
    final DateTime fixed = at ?? todayAt(7);
    demoSession.clock = () => fixed;
    return demoSession.scheduling;
  }

  Map<FollowUpCategory, int> counts(
    DemoScheduling s, {
    String? professionalId,
    String? unitId,
  }) => countFollowUp(
    s
        .followUp(professionalId: professionalId, unitId: unitId)
        .map(((DemoPatient, FollowUpStatus) e) => e.$2),
  );

  test('troca de perfil não reaproveita a conversa do assistente', () {
    final DemoScheduling s = fresh(DemoProfile.responsavel);
    final BookingAssistant family = s.assistantFor();
    expect(identical(s.assistantFor(), family), isTrue);
    demoSession.enter(DemoProfile.recepcao);
    final BookingAssistant reception = s.assistantFor();
    expect(identical(reception, family), isFalse);
    expect(reception.options, contains(BookingAssistant.optBook));
  });

  group('painel de acompanhamento', () {
    test('indicadores com os critérios padrão', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      final Map<FollowUpCategory, int> c = counts(s);
      expect(c[FollowUpCategory.frequente], 2);
      expect(c[FollowUpCategory.inativo], 2);
      expect(c[FollowUpCategory.retornoProximo], 3);
      final List<(DemoPatient, FollowUpStatus)> all = s.followUp();
      final Set<String> inactive = <String>{
        for (final (DemoPatient p, FollowUpStatus st) in all)
          if (st.isIn(FollowUpCategory.inativo)) p.id,
      };
      expect(inactive, <String>{'p6', 'p8'});
      final Set<String> protectedIds = <String>{
        for (final (DemoPatient p, FollowUpStatus st) in all)
          if (st.inactiveButScheduled) p.id,
      };
      expect(protectedIds, <String>{
        'p4',
        'p5',
      }, reason: 'têm consulta futura: não contam como inativos');
    });

    test('indicadores não mudam depois do horário das consultas de hoje', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao, at: todayAt(18));
      final Map<FollowUpCategory, int> c = counts(s);
      expect(c[FollowUpCategory.inativo], 2);
      expect(c[FollowUpCategory.retornoProximo], 3);
    });
    test('filtros por profissional e por clínica', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      final Map<FollowUpCategory, int> b = counts(s, professionalId: 'prof-b');
      expect(b[FollowUpCategory.frequente], 1);
      expect(b[FollowUpCategory.inativo], 1);
      expect(b[FollowUpCategory.retornoProximo], 1);
      final Map<FollowUpCategory, int> a = counts(s, unitId: 'clinica-a');
      expect(a[FollowUpCategory.inativo], 1);
      expect(a[FollowUpCategory.retornoProximo], 2);
    });

    test('critério configurado pela administração muda a lista', () {
      final DemoScheduling s = fresh(DemoProfile.administrador);
      s.setCriteria(s.criteria.copyWith(inactiveAfterMonths: 12));
      expect(counts(s)[FollowUpCategory.inativo], 0);
      s.setCriteria(s.criteria.copyWith(returnSoonDays: 30));
      expect(counts(s)[FollowUpCategory.retornoProximo], 4);
    });

    test('só a administração altera critérios', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      expect(
        () => s.setCriteria(s.criteria.copyWith(inactiveAfterMonths: 3)),
        throwsStateError,
      );
    });

    test('profissional vê só os próprios pacientes', () {
      final DemoScheduling s = fresh(DemoProfile.profissional);
      final Set<String> ids = <String>{
        for (final (DemoPatient p, FollowUpStatus _) in s.followUp(
          professionalId: 'prof-b',
        ))
          p.id,
      };
      expect(ids.contains('p7'), isFalse);
      expect(ids.contains('p8'), isFalse);
      expect(ids.contains('p6'), isTrue);
    });

    test('financeiro não vê o painel', () {
      final DemoScheduling s = fresh(DemoProfile.financeiro);
      expect(s.followUp(), isEmpty);
    });

    test('tentativas de contato ficam registradas', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      s.addContactAttempt(
        'p6',
        channel: ContactChannel.telefone,
        outcome: 'Agendou consulta',
      );
      expect(s.attemptsFor('p6'), hasLength(3));
      expect(s.attemptsFor('p6').first.outcome, 'Agendou consulta');
    });
  });

  group('lembretes', () {
    test('rodada respeita intervalo, consentimento e preferência', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao, at: todayAt(12, 40));
      final int before = s.openAlerts.length;
      final DemoReminderRun run = s.processReminders();
      expect(run.sent, 1, reason: 'a4 (14:30): lembrete de 2 h');
      expect(run.blocked, 1, reason: 'a5: responsável prefere ligação');
      expect(run.failed, 0);
      final ReminderRecord a4 = s.remindersFor('a4').first;
      expect(a4.offsetHours, 2);
      expect(a4.status, ReminderStatus.entregue);
      expect(a4.recipientMasked, '•••• 0001');
      expect(a4.text, isNot(contains('rotina')));
      final ReminderRecord a5 = s.remindersFor('a5').first;
      expect(a5.status, ReminderStatus.naoEnviado);
      expect(
        s.openAlerts.length,
        before,
        reason: 'a5 já tinha pendência aberta de contato manual',
      );
      expect(s.processReminders().total, 0, reason: 'não repete o envio');
    });

    test('rodada inclui sessões de psicologia sem interromper as demais', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao, at: todayAt(16));
      final DemoReminderRun run = s.processReminders();
      final ReminderRecord mp1 = s.remindersFor('mp1').single;
      expect(mp1.offsetHours, 48);
      expect(mp1.text, contains(DemoScheduling.unitOf('prof-a').name));
      expect(DemoScheduling.unitOf('psi-a').id, 'clinica-a');
      expect(run.total, greaterThan(1));
    });

    test('falha de envio vira pendência de contato manual', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      final ReminderRecord r = s.remindersFor('a3').single;
      expect(r.status, ReminderStatus.falhou);
      expect(
        s.openAlerts.any(
          (DemoReceptionAlert a) =>
              a.kind == DemoAlertKind.falhaEnvio && a.appointmentId == 'a3',
        ),
        isTrue,
      );
    });

    test('sem consentimento não envia', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      s.setFamilyContact(consent: false);
      demoSession.enter(DemoProfile.recepcao);
      final DateTime at = todayAt(12, 40);
      demoSession.clock = () => at;
      s.processReminders();
      final ReminderRecord r = s.remindersFor('a4').first;
      expect(r.status, ReminderStatus.naoEnviado);
      expect(r.failureReason, contains('não autorizou'));
    });

    test('pendência de contato manual não se repete na mesma consulta', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao, at: todayAt(12, 40));
      s.processReminders();
      expect(s.remindersFor('a5').length, greaterThan(1));
      final Iterable<DemoReceptionAlert> open = s.openAlerts.where(
        (DemoReceptionAlert a) =>
            a.appointmentId == 'a5' &&
            a.kind == DemoAlertKind.preferenciaManual,
      );
      expect(open, hasLength(1));
    });

    test('resposta Confirmar atualiza a agenda', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      final ReminderRecord r = s.familyMessages().single;
      expect(r.appointmentId, 'a4');
      s.replyToReminder(r.id, ReminderReply.confirmar);
      expect(
        demoSession.appointmentById('a4')!.status,
        DemoAppointmentStatus.confirmado,
      );
      expect(r.status, ReminderStatus.respondido);
      expect(
        () => s.replyToReminder(r.id, ReminderReply.cancelar),
        throwsStateError,
      );
    });

    test('Reagendar marca a agenda e avisa a recepção', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      final ReminderRecord r = s.familyMessages().single;
      s.replyToReminder(r.id, ReminderReply.reagendar);
      expect(
        demoSession.appointmentById('a4')!.status,
        DemoAppointmentStatus.reagendar,
      );
      expect(
        s.alerts.any(
          (DemoReceptionAlert a) =>
              a.kind == DemoAlertKind.reagendamento && a.open,
        ),
        isTrue,
      );
    });

    test('Cancelar fora do prazo vai para a recepção', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      final ReminderRecord r = s.familyMessages().single;
      s.replyToReminder(r.id, ReminderReply.cancelar);
      expect(
        demoSession.appointmentById('a4')!.status,
        DemoAppointmentStatus.agendado,
        reason: 'a4 é hoje: dentro das 12 h',
      );
      expect(
        s.alerts.any(
          (DemoReceptionAlert a) =>
              a.kind == DemoAlertKind.cancelamentoForaDoPrazo,
        ),
        isTrue,
      );
    });

    test('só a administração altera os intervalos', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      expect(
        () => s.setReminderSettings(
          const ReminderSettings(offsetsHours: <int>[24]),
        ),
        throwsStateError,
      );
      demoSession.enter(DemoProfile.administrador);
      s.setReminderSettings(const ReminderSettings(offsetsHours: <int>[72, 3]));
      expect(s.reminderSettings.offsetsHours, <int>[72, 3]);
    });
  });

  group('agendar, remarcar e cancelar', () {
    test(
      'família agenda pelo assistente e a pré-consulta já traz o motivo',
      () {
        final DemoScheduling s = fresh(DemoProfile.responsavel);
        final BookingAssistant a = s.assistantFor(intent: null, restart: true);
        a.send(BookingAssistant.optBook);
        a.send('Luna Exemplo Souza');
        a.send('Tosse leve há dois dias');
        a.send(VisitType.queixa.label);
        a.send(BookingAssistant.optPresencial);
        a.send('Dra. Exemplo Demonstração');
        a.send(DayPart.tarde.label);
        a.send(a.options.first);
        final int before = demoSession.appointments.length;
        a.send(BookingAssistant.optConfirmBooking);
        expect(demoSession.appointments.length, before + 1);
        final DemoAppointment created = demoSession.appointments.last;
        expect(created.patientId, 'p1');
        expect(created.durationMinutes, 40);
        expect(created.status, DemoAppointmentStatus.agendado);
        expect(
          demoSession.preVisits[created.id]!.answers.reason,
          'Tosse leve há dois dias',
        );
        expect(a.bookedAppointmentId, created.id);
      },
    );

    test('não grava horário duplicado nem para criança de outra família', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      final DateTime slot = s
          .findSlots(
            SlotQuery(
              professionalId: 'prof-a',
              durationMinutes: 40,
              from: demoSession.now,
            ),
          )
          .first;
      s.book(
        patientId: 'p1',
        professionalId: 'prof-a',
        start: slot,
        durationMinutes: 40,
        teleconsulta: false,
        type: VisitType.queixa,
        reason: 'Teste',
      );
      expect(
        () => s.book(
          patientId: 'p5',
          professionalId: 'prof-a',
          start: slot.add(const Duration(minutes: 20)),
          durationMinutes: 40,
          teleconsulta: false,
          type: VisitType.queixa,
          reason: 'Teste',
        ),
        throwsA(isA<BookingException>()),
      );
      expect(
        () => s.book(
          patientId: 'p2',
          professionalId: 'prof-a',
          start: slot.add(const Duration(days: 1)),
          durationMinutes: 40,
          teleconsulta: false,
          type: VisitType.queixa,
          reason: 'Teste',
        ),
        throwsA(isA<BookingException>()),
      );
    });

    test('recepção remarca e cancela; o horário volta a ficar livre', () {
      final DemoScheduling s = fresh(DemoProfile.recepcao);
      final DemoAppointment a5 = demoSession.appointmentById('a5')!;
      final DateTime old = a5.start;
      final DateTime next = s
          .findSlots(
            SlotQuery(
              professionalId: 'prof-a',
              durationMinutes: 40,
              from: old.add(const Duration(days: 1)),
              patientId: 'p4',
              ignoreAppointmentId: 'a5',
            ),
          )
          .first;
      s.reschedule('a5', next);
      expect(a5.start, next);
      expect(s.handledOffsets['a5'], isNull, reason: 'lembretes recomeçam');
      s.cancel('a5');
      expect(a5.status, DemoAppointmentStatus.cancelado);
      final List<DateTime> free = s.findSlots(
        SlotQuery(professionalId: 'prof-a', durationMinutes: 40, from: next),
      );
      expect(free.first, next);
    });

    test('profissional não remarca nem cancela', () {
      final DemoScheduling s = fresh(DemoProfile.profissional);
      expect(() => s.cancel('a5'), throwsA(isA<BookingException>()));
    });

    test('urgência orienta e encaminha, sem agendar', () {
      final DemoScheduling s = fresh(DemoProfile.responsavel);
      final BookingAssistant a = s.assistantFor(restart: true);
      a.send(BookingAssistant.optBook);
      a.send('Alice Exemplo Prado');
      final int before = demoSession.appointments.length;
      a.send('Ela teve uma convulsão agora');
      expect(a.messages.last.card?.kind, AssistantCardKind.urgency);
      expect(demoSession.appointments.length, before);
    });
  });

  group('telas', () {
    Future<void> pumpDemo(WidgetTester tester, DemoProfile profile) async {
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
      demoSession.enter(profile);
      final DateTime fixed = todayAt(7);
      demoSession.clock = () => fixed;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    Future<void> goTo(WidgetTester tester, String location) async {
      demoRouter.go(location);
      await settle(tester);
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      for (final ScaffoldMessengerState m
          in tester.stateList<ScaffoldMessengerState>(
            find.byType(ScaffoldMessenger),
          )) {
        m.clearSnackBars();
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await settle(tester);
    }

    String location() =>
        demoRouter.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('recepção: painel, filtro e registro de contato', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.recepcao);
      await goTo(tester, '/acompanhamento');
      expect(find.bySemanticsLabel('Indicador Inativos: 2'), findsOneWidget);
      expect(find.text('Bento Exemplo Alves'), findsOneWidget);
      expect(find.textContaining('já têm consulta marcada'), findsOneWidget);
      await tap(tester, find.text('Registrar contato com Bento Exemplo Alves'));
      await tap(tester, find.text('Salvar contato'));
      expect(demoSession.scheduling.attemptsFor('p6'), hasLength(3));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Dr. Exemplo Colega'));
      expect(find.bySemanticsLabel('Indicador Inativos: 1'), findsOneWidget);
      expect(find.text('Heitor Exemplo Melo'), findsOneWidget);
      expect(find.text('Bento Exemplo Alves'), findsNothing);
    });

    testWidgets('administração altera critérios; recepção só consulta', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.administrador);
      await goTo(tester, '/acompanhamento/criterios');
      for (int i = 0; i < 6; i++) {
        await tap(
          tester,
          find.byTooltip('Aumentar: Inativo após (meses sem consulta)'),
        );
      }
      await tap(tester, find.text('Salvar critérios'));
      expect(demoSession.scheduling.criteria.inactiveAfterMonths, 12);

      demoSession.enter(DemoProfile.recepcao);
      await goTo(tester, '/acompanhamento/criterios');
      expect(find.textContaining('Só a administração'), findsOneWidget);
      expect(find.text('Salvar critérios'), findsNothing);
    });

    testWidgets('família agenda pelo assistente e abre a pré-consulta', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.responsavel);
      await goTo(tester, '/agendar?acao=agendar');
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Luna Exemplo Souza'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mensagem para o assistente'),
        'Tosse leve',
      );
      await tap(tester, find.byTooltip('Enviar mensagem'));
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Consulta por queixa'),
      );
      await tap(tester, find.widgetWithText(OutlinedButton, 'Presencial'));
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Dra. Exemplo Demonstração'),
      );
      await tap(tester, find.widgetWithText(OutlinedButton, 'Tarde'));
      final String first =
          demoSession.scheduling.familyAssistant!.options.first;
      await tap(tester, find.widgetWithText(OutlinedButton, first));
      expect(find.text('Resumo do agendamento'), findsOneWidget);
      final int before = demoSession.appointments.length;
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Confirmar agendamento'),
      );
      expect(demoSession.appointments.length, before + 1);
      await tap(tester, find.text('Preencher pré-consulta'));
      expect(location(), startsWith('/pre-consulta/'));
      expect(location(), endsWith('de=agendar'));
      expect(find.text('Tosse leve'), findsWidgets);
    });

    testWidgets('família confirma pelo lembrete', (WidgetTester tester) async {
      await pumpDemo(tester, DemoProfile.responsavel);
      await goTo(tester, '/mensagens');
      await tap(tester, find.widgetWithText(OutlinedButton, 'Confirmar'));
      expect(
        demoSession.appointmentById('a4')!.status,
        DemoAppointmentStatus.confirmado,
      );
      expect(find.text('Presença confirmada. Obrigado!'), findsOneWidget);
    });

    testWidgets('recepção remarca e cancela pelo detalhe', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.recepcao);
      await goTo(tester, '/agenda/a5');
      final DateTime old = demoSession.appointmentById('a5')!.start;
      await tap(tester, find.widgetWithText(OutlinedButton, 'Remarcar'));
      await tap(tester, find.byType(SimpleDialogOption));
      await tap(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar remarcação'),
      );
      expect(demoSession.appointmentById('a5')!.start, isNot(old));
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Cancelar consulta'),
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Cancelar consulta'));
      expect(
        demoSession.appointmentById('a5')!.status,
        DemoAppointmentStatus.cancelado,
      );
      expect(find.text('Remarcar'), findsNothing);
    });

    testWidgets('profissional vê lembretes, sem ações da recepção', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.profissional);
      await goTo(tester, '/agenda/a4');
      await tester.scrollUntilVisible(
        find.text('Lembretes enviados'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lembretes enviados'), findsOneWidget);
      expect(find.text('Remarcar'), findsNothing);
    });

    testWidgets('perfis sem acesso', (WidgetTester tester) async {
      await pumpDemo(tester, DemoProfile.financeiro);
      await goTo(tester, '/acompanhamento');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      await goTo(tester, '/lembretes');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/agendar');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      demoSession.enter(DemoProfile.recepcao);
      await goTo(tester, '/mensagens');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
    });
  });
}
