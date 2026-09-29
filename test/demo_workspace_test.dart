import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_clinical.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/demo_workspace.dart';
import 'package:pediatria360/demo/screens/restricted_screen.dart';
import 'package:pediatria360/shared/clinical/audit_trail.dart';
import 'package:pediatria360/shared/clinical/clinical_tasks.dart';
import 'package:pediatria360/shared/clinical/consultation_organizer.dart';
import 'package:pediatria360/shared/clinical/patient_notes.dart';
import 'package:pediatria360/shared/clinical/patient_timeline.dart';
import 'package:pediatria360/shared/clinical/visit_diary.dart';

/// Agenda, diário, resumo, observações e histórico do profissional.
void main() {
  DateTime todayAt(int h, [int m = 0]) {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day, h, m);
  }

  DemoWorkspace fresh(DemoProfile profile) {
    demoSession.leave();
    demoSession.enter(profile);
    final DateTime fixed = todayAt(7);
    demoSession.clock = () => fixed;
    return demoSession.workspace;
  }

  DemoAppointment appt(String id) => demoSession.appointmentById(id)!;

  group('permissões', () {
    test('cada profissional abre só os próprios horários', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      expect(ws.canOpenAppointment(appt('a1')), isTrue);
      expect(ws.canOpenAppointment(appt('a7')), isFalse);
      expect(ws.canUseDiary, isTrue);
      fresh(DemoProfile.recepcao);
      expect(demoSession.workspace.canOpenAppointment(appt('a7')), isTrue);
      expect(demoSession.workspace.canUseDiary, isFalse);
      expect(demoSession.workspace.diary(), isEmpty);
      for (final DemoProfile p in <DemoProfile>[
        DemoProfile.financeiro,
        DemoProfile.administrador,
        DemoProfile.responsavel,
      ]) {
        final DemoWorkspace other = fresh(p);
        expect(other.canUseDiary, isFalse, reason: p.name);
        expect(other.tasksFor(), isEmpty, reason: p.name);
        expect(other.timelineFor('p1'), isEmpty, reason: p.name);
      }
    });

    test('observações: clínica, responsável e outros perfis', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      expect(ws.notesFor('p1').map((PatientNote n) => n.id), <String>[
        'n2',
        'n1',
      ]);
      demoSession.switchAccount(DemoProfessional.colleague.id);
      expect(ws.notesFor('p1').map((PatientNote n) => n.id), <String>['n4']);
      expect(
        () => ws.editNote('n1', text: 'x', visibility: NoteVisibility.interna),
        throwsA(isA<StateError>()),
      );

      final DemoWorkspace family = fresh(DemoProfile.responsavel);
      expect(family.notesFor('p1').map((PatientNote n) => n.id), <String>[
        'n2',
      ]);
      expect(family.notesFor('p3'), isEmpty);
      expect(
        () => family.addNote('p1', 'x', NoteVisibility.responsavel),
        throwsA(isA<StateError>()),
      );
      expect(fresh(DemoProfile.recepcao).notesFor('p1'), isEmpty);
    });

    test('tarefas são do profissional dono', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final List<String> ids = ws
          .tasksFor()
          .map((ClinicalTask t) => t.id)
          .toList();
      expect(ids, containsAll(<String>['t1', 't2', 't3', 't4']));
      expect(ids, isNot(contains('t5')));
      expect(ws.tasksDueNow, 2);
      expect(ws.tasksFor(patientId: 'p3').single.id, 't2');
    });
  });

  group('diário e agenda', () {
    test('classifica realizadas, pendentes, faltas e agendadas', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final Map<String, VisitOutcome> byId = <String, VisitOutcome>{
        for (final DemoDiaryEntry e in ws.diary(period: DiaryPeriod.mes))
          e.appointment.id: e.classification.outcome,
      };
      expect(byId['a8'], VisitOutcome.realizada);
      expect(byId['a9'], VisitOutcome.falta);
      expect(byId['a10'], VisitOutcome.pendente);
      expect(byId['a2'], VisitOutcome.agendada);
      expect(byId.containsKey('a7'), isFalse);
      expect(byId.containsKey('a11'), isFalse);
      expect(
        ws
            .diary(period: DiaryPeriod.tudo)
            .any((DemoDiaryEntry e) => e.appointment.id == 'a11'),
        isTrue,
      );
      expect(
        ws
            .diary(period: DiaryPeriod.tudo, patientId: 'p1')
            .every((DemoDiaryEntry e) => e.patient.id == 'p1'),
        isTrue,
      );
      final Map<VisitOutcome, int> counts = ws.diaryCounts(
        period: DiaryPeriod.mes,
      );
      expect(counts[VisitOutcome.falta], 1);
      expect(counts[VisitOutcome.realizada], 1);
    });

    test('falta só depois do horário e fica no registro', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      expect(
        () => demoSession.setAppointmentStatus(
          appt('a3'),
          DemoAppointmentStatus.falta,
        ),
        throwsA(isA<StateError>()),
      );
      demoSession.setAppointmentStatus(
        appt('a10'),
        DemoAppointmentStatus.falta,
      );
      expect(
        ws.auditFor('p2', entityId: 'a10').first.action,
        'Status alterado: Confirmado para Falta',
      );
      expect(() => ws.startVisit(appt('a10')), throwsA(isA<StateError>()));
    });

    test('agenda, consulta, resumo, retorno e tarefa ficam ligados', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final DemoAppointment a = appt('a10');
      final DemoConsultation c = ws.startVisit(a);
      expect(c.appointmentId, 'a10');
      expect(c.patientId, 'p2');
      expect(a.status, DemoAppointmentStatus.chegou);
      expect(ws.startVisit(a).id, c.id);
      expect(
        ws
            .diary(period: DiaryPeriod.mes)
            .firstWhere((DemoDiaryEntry e) => e.appointment.id == 'a10')
            .classification
            .pendingReason,
        contains('rascunho'),
      );
      c
        ..complaint = 'Retorno de otite (exemplo)'
        ..assessment = 'Boa evolução (exemplo)'
        ..plan = 'Manter orientações (exemplo)'
        ..returnPlan = 'Reavaliar em 15 dias'
        ..returnInDays = 15;
      demoSession.saveConsultation(c);
      expect(
        ws.auditFor('p2', entityId: c.id).first.detail,
        allOf(contains('Queixa'), contains('Plano de retorno')),
      );
      final int tasksBefore = ws.tasksFor(patientId: 'p2').length;
      demoSession.finishConsultation(c);
      expect(a.status, DemoAppointmentStatus.concluido);
      expect(demoSession.scheduling.recommendedReturns['p2'], isNotNull);
      expect(ws.tasksFor(patientId: 'p2').length, tasksBefore + 1);
      expect(ws.tasksFor(patientId: 'p2').first.title, contains('retorno'));
      expect(
        ws.auditFor('p2', entityId: c.id).first.action,
        'Consulta finalizada',
      );
      expect(
        ws
            .diary(period: DiaryPeriod.mes)
            .firstWhere((DemoDiaryEntry e) => e.appointment.id == 'a10')
            .classification
            .outcome,
        VisitOutcome.realizada,
      );
      expect(
        ws
            .timelineFor('p2')
            .any(
              (TimelineEvent e) =>
                  e.route == '/pacientes/p2/consulta/${c.id}/resumo',
            ),
        isTrue,
      );
    });
  });

  group('resumo da consulta', () {
    test('rascunho do assistente só entra depois da revisão', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final DemoConsultation c = ws.startVisit(appt('a1'));
      expect(ws.preVisitFor(c), isNotNull);
      final OrganizedDraft d = ws.organize(
        c,
        transcript: 'Pele com lesão eritematosa. Orientei hidratante.',
      );
      expect(d.status, DraftStatus.pendente);
      expect(d.suggestions[SummarySection.queixa], contains('Mancha'));
      expect(c.complaint, isEmpty);
      expect(c.physicalExam, isEmpty);
      expect(
        () => ws.applyDraft(c, reviewed: false),
        throwsA(isA<StateError>()),
      );
      expect(c.complaint, isEmpty);
      ws.applyDraft(c, reviewed: true);
      expect(c.complaint, contains('Mancha'));
      expect(c.history, contains('Coça'));
      expect(c.physicalExam, contains('Pele'));
      expect(c.plan, contains('hidratante'));
      expect(c.assessment, isEmpty);
      expect(c.isDraft, isTrue);
      expect(d.status, DraftStatus.aplicado);
      final List<String> actions = ws
          .auditFor('p1', entityId: c.id)
          .map((AuditEntry e) => e.action)
          .toList();
      expect(actions, contains('Rascunho do assistente revisado e aplicado'));
      expect(
        actions,
        contains('Rascunho organizado pelo assistente (aguardando revisão)'),
      );
    });

    test('rascunho descartado não altera o registro', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final DemoConsultation c = ws.startVisit(appt('a1'));
      ws.organize(c);
      ws.discardDraft(c);
      expect(ws.drafts[c.id]!.status, DraftStatus.descartado);
      expect(c.complaint, isEmpty);
      expect(
        () => ws.applyDraft(c, reviewed: true),
        throwsA(isA<StateError>()),
      );
    });

    test('adendo só em consulta finalizada, sem mudar o texto', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final DemoConsultation c1 = demoSession.consultationById('c1')!;
      final String before = c1.plan;
      ws.addAddendum(c1, 'Família informou melhora por telefone (exemplo).');
      expect(c1.addenda, hasLength(1));
      expect(c1.plan, before);
      final DemoConsultation draft = ws.startVisit(appt('a1'));
      expect(() => ws.addAddendum(draft, 'x'), throwsA(isA<StateError>()));
    });
  });

  group('observações e histórico', () {
    test('mudar visibilidade exige motivo e fica registrado', () {
      final DemoWorkspace ws = fresh(DemoProfile.profissional);
      final PatientNote n = ws.addNote(
        'p1',
        'Nota nova (exemplo)',
        NoteVisibility.interna,
      );
      expect(
        () => ws.editNote(
          n.id,
          text: n.text,
          visibility: NoteVisibility.responsavel,
        ),
        throwsA(isA<StateError>()),
      );
      ws.editNote(
        n.id,
        text: n.text,
        visibility: NoteVisibility.responsavel,
        reason: 'Orientação para a família',
      );
      expect(n.versions, hasLength(2));
      expect(
        ws.auditFor('p1', entityId: n.id).first.action,
        contains('Visibilidade alterada'),
      );
      ws.archiveNote(n.id, 'Duplicada');
      expect(ws.notesFor('p1').any((PatientNote x) => x.id == n.id), isFalse);
      expect(
        ws.notesFor('p1', archived: true).any((PatientNote x) => x.id == n.id),
        isTrue,
      );
    });

    test(
      'linha do tempo reúne consultas, documentos, crescimento e faltas',
      () {
        final DemoWorkspace ws = fresh(DemoProfile.profissional);
        final Set<TimelineKind> kinds = ws
            .timelineFor('p1')
            .map((TimelineEvent e) => e.kind)
            .toSet();
        expect(kinds, contains(TimelineKind.consulta));
        expect(kinds, contains(TimelineKind.crescimento));
        final List<TimelineEvent> p3 = ws.timelineFor('p3');
        expect(
          p3.any(
            (TimelineEvent e) =>
                e.kind == TimelineKind.agenda && e.title == 'Falta',
          ),
          isTrue,
        );
        final List<TimelineEvent> only = ws.timelineFor(
          'p1',
          only: <TimelineKind>{TimelineKind.consulta},
        );
        expect(
          only.every((TimelineEvent e) => e.kind == TimelineKind.consulta),
          isTrue,
        );
      },
    );
  });

  group('telas', () {
    Future<void> pumpDemo(
      WidgetTester tester,
      DemoProfile profile, {
      Size size = const Size(1280, 900),
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
      final DateTime fixed = todayAt(7);
      demoSession.clock = () => fixed;
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

    testWidgets('agenda: dia, semana e mês, e horário de outro profissional', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.profissional);
      await goTo(tester, '/agenda');
      expect(find.textContaining('Horário livre'), findsWidgets);
      await tap(tester, find.text('Semana'));
      expect(find.textContaining('horário(s) livre(s)'), findsWidgets);
      await tap(tester, find.text('Mês'));
      expect(find.byTooltip('Próximo mês'), findsOneWidget);
      await goTo(tester, '/agenda?vista=semana');
      expect(find.byTooltip('Próxima semana'), findsOneWidget);
      await goTo(tester, '/agenda/a7');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      await goTo(tester, '/agenda/a10');
      expect(find.text('Dados essenciais'), findsOneWidget);
      await tap(tester, find.text('Iniciar consulta'));
      expect(location(), startsWith('/pacientes/p2/consulta/'));
    });

    testWidgets('diário: filtros e nova tarefa', (WidgetTester tester) async {
      await pumpDemo(tester, DemoProfile.profissional);
      await goTo(tester, '/diario');
      expect(find.text('Diário de atendimentos'), findsWidgets);
      expect(find.text('Registrar falta'), findsWidgets);
      await tap(tester, find.widgetWithText(ChoiceChip, 'Falta (1)'));
      expect(find.text('Registrar falta'), findsNothing);
      final int before = demoSession.workspace.tasksFor().length;
      await tap(tester, find.text('Nova tarefa'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Descrição da tarefa'),
        'Ligar para a família (teste)',
      );
      await tap(tester, find.text('Salvar tarefa'));
      expect(demoSession.workspace.tasksFor().length, before + 1);
      expect(find.text('Ligar para a família (teste)'), findsOneWidget);
    });

    testWidgets('resumo, histórico e comparação', (WidgetTester tester) async {
      await pumpDemo(tester, DemoProfile.profissional);
      await goTo(tester, '/pacientes/p1/consulta/c1/resumo');
      expect(find.text('Resumo da consulta'), findsWidgets);
      expect(find.text('Plano de retorno'), findsOneWidget);
      expect(find.text('Retorno recomendado'), findsOneWidget);
      await goTo(tester, '/pacientes/p1/historico');
      expect(find.text('Consulta de puericultura'), findsWidgets);
      await tap(tester, find.text('Comparar consultas'));
      expect(location(), startsWith('/pacientes/p1/historico/comparar'));
      expect(find.text('Crescimento entre as consultas'), findsOneWidget);
      expect(find.text('Desenvolvimento ao longo do tempo'), findsOneWidget);
    });

    testWidgets('família vê só recados visíveis; recepção não abre o diário', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester, DemoProfile.responsavel);
      await goTo(tester, '/pacientes/p1/observacoes');
      expect(find.textContaining('caderneta de vacinação'), findsOneWidget);
      expect(find.textContaining('prefere consultas pela manhã'), findsNothing);
      expect(find.text('Nova observação'), findsNothing);
      await goTo(tester, '/pacientes/p1/historico');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      demoSession.leave();
      demoSession.enter(DemoProfile.recepcao);
      await goTo(tester, '/diario');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
      await goTo(tester, '/pacientes/p1/observacoes');
      expect(find.byType(DemoRestrictedScreen), findsOneWidget);
    });
  });
}
