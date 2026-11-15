import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_data.dart';
import 'package:pediatria360/demo/demo_router.dart';
import 'package:pediatria360/demo/demo_routine.dart';
import 'package:pediatria360/demo/demo_session.dart';
import 'package:pediatria360/demo/widgets/routine_widgets.dart';
import 'package:pediatria360/shared/clinical/file_input.dart';
import 'package:pediatria360/shared/routine/child_routine.dart';

/// Rotina da criança (calendário e diário) com dados fictícios, no tamanho
/// de um celular.
void main() {
  tearDown(() => debugPickFile = null);

  const Size phone = Size(390, 844);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDemo(
    WidgetTester tester, {
    DemoProfile profile = DemoProfile.responsavel,
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

  /// Rola a lista principal até o alvo ser construído (listas preguiçosas).
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
      tapFinder(tester, last ? find.text(text).last : find.text(text));

  Future<void> tapChip(WidgetTester tester, String label) => tapFinder(
    tester,
    find.ancestor(of: find.text(label), matching: find.byType(RawChip)).last,
  );

  Future<void> quick(WidgetTester tester, String kind) =>
      tapFinder(tester, find.bySemanticsLabel('Registrar $kind'));

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final Finder f = find.widgetWithText(TextField, label).last;
    await seek(tester, find.widgetWithText(TextField, label));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, value);
    await tester.pump();
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  Future<void> waitPdf(WidgetTester tester) async {
    for (int i = 0; i < 30 && demoSession.lastPdf == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  DateTime today() => dayOf(DateTime.now());

  group('calendário e diário', () {
    testWidgets('troca entre as vistas e o toque no dia mostra o diário', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina');
      expect(find.text('Rotina da criança'), findsOneWidget);
      expect(find.text('Calendário'), findsOneWidget);
      expect(find.text('Diário'), findsOneWidget);
      expect(find.text('Planejado'), findsWidgets);

      final DateTime d1 = today().subtract(const Duration(days: 1));
      final DateTime other = DateTime(
        d1.year,
        d1.month,
        d1.day == 15 ? 16 : 15,
      );
      await goTo(
        tester,
        '/rotina/p1?vista=calendario&modo=mes&dia=${routineDateKey(other)}',
      );
      await tapFinder(
        tester,
        find.bySemanticsLabel(
          RegExp('^${d1.day} de ${kMonthNames[d1.month - 1]}(, hoje)?:'),
        ),
      );
      expect(location(), contains('dia=${routineDateKey(d1)}'));
      expect(find.text('Compromissos - ${formatDm(d1)}'), findsOneWidget);
      expect(find.text('Diário do dia'), findsOneWidget);
      expect(rich('Mamão amassado (exemplo)'), findsOneWidget);
      expect(rich('Informado pela família'), findsWidgets);

      await tapText(tester, 'Abrir no diário');
      expect(location(), contains('vista=diario'));
      expect(location(), contains('dia=${routineDateKey(d1)}'));
      expect(find.bySemanticsLabel('Registrar Mamada'), findsOneWidget);
      expect(find.text('Linha do tempo'), findsOneWidget);

      await tapChip(tester, 'Fralda (3)');
      expect(rich('Mamão amassado'), findsNothing);
      expect(rich('Xixi e cocô'), findsOneWidget);
      await tapChip(
        tester,
        'Todos (${demoSession.diaryFor('p1', day: d1).length})',
      );

      await tapText(tester, 'Calendário');
      expect(location(), contains('vista=calendario'));
      await tapText(tester, 'Semana');
      expect(find.textContaining('Semana de'), findsOneWidget);
      await tapText(tester, 'Dia');
      expect(find.textContaining(', ${d1.day} de'), findsOneWidget);

      await tapChip(tester, 'Vacina');
      expect(demoSession.routineKindFilter, <RoutineKind>{RoutineKind.vacina});
      await tapChip(tester, 'Todos');
      expect(demoSession.routineKindFilter, isEmpty);
    });

    testWidgets('troca de criança mantém a vista', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1?vista=diario');
      await tapChip(tester, 'Alice');
      expect(location(), startsWith('/rotina/p5?vista=diario'));
      expect(find.text('Alice Exemplo Prado'), findsOneWidget);
    });
  });

  group('diário', () {
    testWidgets('fralda em três toques, correção com histórico e exclusão', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1?vista=diario');
      final int before = demoSession.diaryFor('p1').length;

      await quick(tester, 'Fralda');
      await tapChip(tester, 'Xixi');
      await tapText(tester, 'Salvar');

      final List<DiaryEntry> after = demoSession.diaryFor('p1');
      expect(after, hasLength(before + 1));
      final DiaryEntry e = demoSession.diaryEntries.last;
      expect(e.kind, DiaryKind.fralda);
      expect(e.values.option, 'Xixi');
      expect(e.author, DemoSession.guardianOfDemo);
      expect(e.role, DiaryRole.familia);
      expect(find.textContaining('Registro salvo: Fralda'), findsOneWidget);

      await goTo(tester, '/rotina/p1/registro/${e.id}');
      await tapText(tester, 'Corrigir');
      expect(find.text('Corrigir: Fralda'), findsOneWidget);
      await tapChip(tester, 'Xixi e cocô');
      await fill(tester, 'Motivo da correção (opcional)', 'Toquei errado');
      await tapText(tester, 'Salvar correção');
      final DiaryEntry fixed = demoSession.diaryEntryById(e.id)!;
      expect(fixed.values.option, 'Xixi e cocô');
      expect(fixed.wasCorrected, isTrue);
      expect(fixed.revisions.single.before!.option, 'Xixi');
      expect(
        find.textContaining('Corrigido por ${DemoSession.guardianOfDemo}'),
        findsOneWidget,
      );
      expect(find.text('Motivo: Toquei errado'), findsOneWidget);
      expect(find.textContaining('- Xixi'), findsOneWidget);

      await tapText(tester, 'Excluir lançamento');
      await fill(tester, 'Motivo', 'Duplicado');
      await tapText(tester, 'Excluir');
      expect(demoSession.diaryEntryById(e.id)!.voided, isTrue);
      expect(demoSession.diaryFor('p1'), hasLength(before));
      expect(find.textContaining('Lançamento excluído'), findsWidgets);
    });

    testWidgets('mamadeira, temperatura com foto e sono aberto', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1?vista=diario');

      await quick(tester, 'Mamada');
      await tapText(tester, 'Salvar');
      expect(find.text('Escolha peito ou mamadeira.'), findsOneWidget);
      await tapChip(tester, 'Mamadeira');
      await tapText(tester, 'Salvar');
      expect(find.text('Informe quantos mL na mamadeira.'), findsOneWidget);
      await tapChip(tester, '120 mL');
      await tapText(tester, 'Salvar');
      final DiaryEntry feed = demoSession.diaryEntries.last;
      expect(feed.kind, DiaryKind.mamada);
      expect(feed.values.quantity, 120);
      expect(feed.values.unit, 'mL');

      debugPickFile = (String accept) async {
        expect(accept, contains('image/*'));
        return PickedFile(
          name: 'termometro-exemplo.png',
          mimeType: 'image/png',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
          ),
        );
      };
      await quick(tester, 'Temperatura');
      await fill(tester, 'Temperatura (°C)', '37,6');
      await tapText(tester, 'Anexar foto ou arquivo');
      expect(find.textContaining('termometro-exemplo.png'), findsOneWidget);
      await tapText(tester, 'Salvar');
      final DiaryEntry temp = demoSession.diaryEntries.last;
      expect(temp.values.quantity, 37.6);
      expect(temp.values.option, 'Axilar');
      expect(temp.attachment!.name, 'termometro-exemplo.png');

      await quick(tester, 'Sono');
      await tapText(tester, 'Dormiu agora');
      await tapText(tester, 'Salvar');
      final DiaryEntry sleep = demoSession.diaryEntries.last;
      expect(sleep.isOpenSleep, isTrue);
      expect(find.textContaining('Dormindo desde'), findsOneWidget);
      final DateTime later = DateTime.now().add(const Duration(minutes: 40));
      demoSession.clock = () => later;
      await tapText(tester, 'Acordou');
      final DiaryEntry woke = demoSession.diaryEntryById(sleep.id)!;
      expect(woke.isOpenSleep, isFalse);
      expect(woke.values.minutes, greaterThanOrEqualTo(39));
      expect(find.textContaining('Dormindo desde'), findsNothing);
    });

    testWidgets('dia futuro não aceita registro', (WidgetTester tester) async {
      await pumpDemo(tester);
      final DateTime tomorrow = today().add(const Duration(days: 1));
      await goTo(
        tester,
        '/rotina/p1?vista=diario&dia=${routineDateKey(tomorrow)}',
      );
      expect(find.bySemanticsLabel('Registrar Mamada'), findsNothing);
      expect(find.textContaining('recebe registros até hoje'), findsOneWidget);
    });
  });

  group('calendário', () {
    testWidgets('criar com lembrete, editar, concluir, reabrir e cancelar', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1');
      await tapText(tester, 'Novo compromisso');
      expect(find.text('Novo compromisso'), findsOneWidget);
      await tapText(tester, 'Salvar');
      expect(find.text('Informe um título.'), findsOneWidget);

      final DateTime tomorrow = today().add(const Duration(days: 1));
      await tapChip(tester, 'Consulta');
      await fill(tester, 'Título', 'Dentista (exemplo)');
      await fill(tester, 'Data (dd/mm/aaaa)', formatDmy(tomorrow));
      await fill(tester, 'Horário', '10:00');
      await tapChip(tester, '1 hora antes');
      await tapText(tester, 'Salvar');

      final RoutineEvent created = demoSession.routineEvents.last;
      expect(created.title, 'Dentista (exemplo)');
      expect(created.kind, RoutineKind.consulta);
      expect(
        created.start,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
      );
      expect(created.reminders, <int>[30, 60]);
      expect(created.author, DemoSession.guardianOfDemo);
      expect(location(), contains('modo=dia'));
      expect(location(), contains('dia=${routineDateKey(tomorrow)}'));
      expect(find.text('Dentista (exemplo)'), findsOneWidget);

      await tapText(tester, 'Dentista (exemplo)');
      await tapText(tester, 'Editar');
      expect(find.text('Editar compromisso'), findsOneWidget);
      await fill(tester, 'Horário', '11:30');
      await tapText(tester, 'Salvar');
      RoutineEvent e = demoSession.routineEventById(created.id)!;
      expect(e.start.hour, 11);
      expect(e.history.last.action, 'Editado');
      expect(e.history.last.detail, contains('quando'));

      final String key = routineDateKey(tomorrow);
      await tapText(tester, 'Dentista (exemplo)');
      await tapText(tester, 'Concluir');
      e = demoSession.routineEventById(created.id)!;
      expect(e.statusOf(key), RoutineStatus.done);
      expect(find.text('Realizado'), findsWidgets);

      await tapText(tester, 'Dentista (exemplo)');
      await tapText(tester, 'Reabrir');
      expect(
        demoSession.routineEventById(created.id)!.statusOf(key),
        RoutineStatus.planned,
      );

      await tapText(tester, 'Dentista (exemplo)');
      await tapText(tester, 'Cancelar compromisso');
      await fill(tester, 'Motivo (opcional)', 'Remarcado');
      await tapText(tester, 'Cancelar compromisso', last: true);
      e = demoSession.routineEventById(created.id)!;
      expect(e.statusOf(key), RoutineStatus.cancelled);
      expect(e.occurrences[key]!.note, 'Remarcado');
      expect(find.text('Cancelado'), findsWidgets);
    });

    testWidgets('vacina pendente é agendada sem duplicar a carteira', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final int vaccines = demoSession.vaccines.length;
      await goTo(tester, '/rotina/p1');
      expect(find.text('Vacinas pendentes na carteira'), findsOneWidget);
      await tapText(tester, 'Agendar');
      expect(find.textContaining('Ligado à vacina pendente'), findsOneWidget);
      final DateTime day = today().add(const Duration(days: 5));
      await fill(tester, 'Data (dd/mm/aaaa)', formatDmy(day));
      await tapText(tester, 'Salvar');

      final PendingVaccine v = demoSession.pendingVaccines('p1').single;
      expect(v.scheduled, isNotNull);
      expect(v.scheduled!.kind, RoutineKind.vacina);
      expect(v.scheduled!.title, 'Vacina exemplo B - Reforço');
      expect(demoSession.vaccines, hasLength(vaccines));
      expect(v.record.status, DemoVaccineStatus.pendente);

      await goTo(tester, '/rotina/p1');
      expect(find.textContaining('Agendada pela família'), findsOneWidget);
      expect(find.text('Agendar'), findsNothing);
    });

    testWidgets('medicamento da receita: programar horários e dar a dose', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1');
      expect(find.text('Medicamentos prescritos'), findsOneWidget);
      expect(find.textContaining('doses registradas'), findsOneWidget);
      await tapText(tester, 'Programar');
      expect(find.text('Horários do medicamento'), findsOneWidget);
      expect(
        find.text('Intervalo e duração lidos da receita.'),
        findsOneWidget,
      );
      await seek(tester, find.text('15 doses'));
      expect(find.text('15 doses'), findsOneWidget);
      await tapText(tester, 'Programar horários');

      final MedicationPlan plan = demoSession.planFor('d3', 0)!;
      expect(plan.intervalHours, 8);
      expect(plan.days, 5);
      expect(plan.doseCount, 15);
      expect(plan.reminders, <int>[0]);

      final DateTime first = plan.firstDose;
      demoSession.clock = () => first.add(const Duration(minutes: 3));
      await goTo(
        tester,
        '/rotina/p1?vista=calendario&modo=dia&dia=${routineDateKey(first)}',
      );
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Lembrete: Medicamento Exemplo A'), findsOneWidget);
      await tapFinder(
        tester,
        find
            .descendant(
              of: find.byType(RoutineItemTile),
              matching: find.text('Medicamento Exemplo A'),
            )
            .first,
      );
      await tapText(tester, 'Registrar dose dada');
      expect(find.widgetWithText(TextField, 'Medicamento'), findsOneWidget);
      await tapText(tester, 'Salvar');

      final MedicationPlan after = demoSession.planFor('d3', 0)!;
      final String key = MedicationPlan.doseKey(first);
      expect(after.statusOf(key), RoutineStatus.done);
      final DiaryEntry given = demoSession.diaryEntryById(
        after.doses[key]!.diaryEntryId!,
      )!;
      expect(given.kind, DiaryKind.medicamento);
      expect(given.values.text, 'Medicamento Exemplo A');
      expect(given.values.quantity, 5);
      expect(given.values.unit, 'mL');
      expect(find.text('Lembrete: Medicamento Exemplo A'), findsNothing);
    });
  });

  group('lembretes', () {
    testWidgets('aviso aparece no horário, abre o dia e pode ser dispensado', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final DateTime now = DateTime.now();
      final DateTime start = now.add(const Duration(hours: 2));
      demoSession.saveRoutineEvent(
        RoutineEvent(
          id: 'et1',
          patientId: 'p1',
          kind: RoutineKind.lembrete,
          title: 'Buscar exame (exemplo)',
          start: start,
          reminders: const <int>[60],
          author: DemoSession.guardianOfDemo,
          createdAt: now,
        ),
      );
      await goTo(tester, '/inicio');
      expect(find.text('Lembrete: Buscar exame (exemplo)'), findsNothing);

      demoSession.clock = () => start.subtract(const Duration(minutes: 55));
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Lembrete: Buscar exame (exemplo)'), findsOneWidget);

      await tapText(tester, 'Ver');
      expect(location(), contains('/rotina/p1'));
      expect(location(), contains('modo=dia'));
      expect(location(), contains('dia=${routineDateKey(start)}'));
      expect(find.text('Buscar exame (exemplo)'), findsOneWidget);

      await tapText(tester, 'Dispensar');
      expect(find.text('Lembrete: Buscar exame (exemplo)'), findsNothing);
      expect(
        demoSession.dismissedReminders,
        contains('ev:et1:${routineDateKey(start)}@60'),
      );
    });

    testWidgets('lembrete da consulta agendada pela clínica', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      final DemoAppointment a6 = demoSession.appointments.firstWhere(
        (DemoAppointment a) => a.id == 'a6',
      );
      await goTo(
        tester,
        '/rotina/p1?vista=calendario&modo=dia&dia=${routineDateKey(a6.start)}',
      );
      await tapText(tester, 'Retorno (exemplo)');
      expect(find.textContaining('Para remarcar ou cancelar'), findsOneWidget);
      expect(find.text('Concluir'), findsNothing);
      await tapText(tester, 'Lembretes');
      await tapChip(tester, 'No horário');
      await tapText(tester, 'Salvar lembretes');
      expect(demoSession.itemReminders['appt:a6'], <int>[0, 60, 1440]);
    });
  });

  group('resumo para o pediatra', () {
    testWidgets('filtros, envio, PDF e cópia; profissional vê só leitura', (
      WidgetTester tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpDemo(tester);
      await goTo(tester, '/rotina/p1');
      await tapFinder(tester, find.byTooltip('Resumo para o pediatra'));
      expect(find.text('Resumo para o pediatra'), findsOneWidget);
      expect(
        find.textContaining('Resumo da rotina - Luna Exemplo Souza'),
        findsOneWidget,
      );
      expect(find.textContaining('Mamadas:'), findsOneWidget);

      await tapText(tester, 'Limpar');
      await tapChip(tester, 'Fralda');
      expect(find.textContaining('Fraldas:'), findsOneWidget);
      expect(find.textContaining('Mamadas:'), findsNothing);

      final int sent = demoSession.sharedSummariesFor('p1').length;
      await fill(
        tester,
        'Mensagem para o pediatra (opcional)',
        'Dúvida sobre o sono (exemplo)',
      );
      await tapText(tester, 'Enviar ao pediatra');
      final List<SharedRoutineSummary> list = demoSession.sharedSummariesFor(
        'p1',
      );
      expect(list, hasLength(sent + 1));
      expect(list.first.kinds, <DiaryKind>{DiaryKind.fralda});
      expect(list.first.author, DemoSession.guardianOfDemo);
      expect(list.first.message, 'Dúvida sobre o sono (exemplo)');
      expect(list.first.text, contains('Fraldas:'));
      expect(find.textContaining('Resumo enviado ao pediatra'), findsOneWidget);

      demoSession.lastPdf = null;
      await tapText(tester, 'Baixar PDF');
      await waitPdf(tester);
      expect(demoSession.lastPdf!.$1, startsWith('resumo-rotina-luna-'));
      expect(ascii.decode(demoSession.lastPdf!.$2.sublist(0, 4)), '%PDF');

      await tapText(tester, 'Copiar texto');
      expect(copied, contains('Resumo da rotina - Luna Exemplo Souza'));
      expect(copied, contains('Informado pela família'));

      await tapText(tester, 'Compartilhar a rotina com a clínica');
      expect(demoSession.routineSharedWith('p1'), isFalse);
      final FilledButton send = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Enviar ao pediatra'),
          matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
        ),
      );
      expect(send.onPressed, isNull);

      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/rotina/p1');
      expect(find.text('Rotina não compartilhada'), findsOneWidget);
      await goTo(tester, '/pacientes/p1');
      expect(find.text('A família não compartilhou a rotina'), findsOneWidget);

      demoSession.enter(DemoProfile.responsavel);
      demoSession.setRoutineSharing('p1', true);
      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/pacientes/p1');
      await tapText(tester, 'Resumos enviados pela família');
      expect(
        find.textContaining('Enviado por ${DemoSession.guardianOfDemo}'),
        findsNWidgets(sent + 1),
      );
      await tapFinder(tester, find.textContaining('Enviado por').first);
      expect(find.text('Resumo enviado'), findsOneWidget);
      expect(find.text('Informado pela família'), findsOneWidget);
      expect(
        find.textContaining('Mensagem da família: Dúvida sobre o sono'),
        findsOneWidget,
      );

      await goTo(tester, '/rotina/p1?vista=diario');
      expect(
        find.textContaining('Informado pela família. Calendário e diário'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Registrar Mamada'), findsNothing);
      expect(find.text('Novo compromisso'), findsNothing);
      await goTo(tester, '/rotina/p1?vista=calendario');
      expect(find.text('Novo compromisso'), findsNothing);
      expect(find.text('Agendar'), findsNothing);
    });
  });

  group('proteção dos dados', () {
    testWidgets('só responsáveis e profissionais autorizados', (
      WidgetTester tester,
    ) async {
      await pumpDemo(tester);
      await goTo(tester, '/rotina/p2');
      expect(find.text('Criança não encontrada'), findsOneWidget);
      expect(demoSession.routinePatients.map((DemoPatient p) => p.id), <String>[
        'p1',
        'p5',
      ]);

      for (final DemoProfile other in <DemoProfile>[
        DemoProfile.recepcao,
        DemoProfile.financeiro,
        DemoProfile.administrador,
      ]) {
        demoSession.enter(other);
        await goTo(tester, '/rotina');
        expect(
          find.text('Acesso restrito'),
          findsOneWidget,
          reason: other.name,
        );
        await goTo(tester, '/rotina/p1');
        expect(
          find.text('Acesso restrito'),
          findsOneWidget,
          reason: other.name,
        );
        await goTo(tester, '/rotina/p1/registro/rs1');
        expect(
          find.text('Acesso restrito'),
          findsOneWidget,
          reason: other.name,
        );
        expect(demoSession.routinePatient('p1'), isNull);
      }

      demoSession.enter(DemoProfile.profissional);
      await goTo(tester, '/rotina/p5');
      expect(find.text('Rotina não compartilhada'), findsOneWidget);
      await goTo(tester, '/rotina/p1/resumo');
      expect(find.text('Acesso restrito'), findsOneWidget);
      await goTo(tester, '/rotina/p1/evento/novo');
      expect(find.text('Acesso restrito'), findsOneWidget);
      await goTo(tester, '/rotina/p1');
      expect(find.text('Rotina da criança'), findsOneWidget);

      final int count = demoSession.diaryEntries.length;
      expect(
        () => demoSession.addDiaryEntry(
          patientId: 'p1',
          kind: DiaryKind.observacao,
          values: DiaryValues(at: DateTime.now(), text: 'Teste'),
        ),
        throwsStateError,
      );
      final RoutineEvent e1 = demoSession.routineEventById('e1')!;
      demoSession.saveRoutineEvent(e1.copyWith(title: 'Alterado'));
      expect(demoSession.routineEventById('e1')!.title, e1.title);
      expect(demoSession.diaryEntries, hasLength(count));
    });
  });
}
