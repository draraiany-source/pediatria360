import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/audit_trail.dart';
import 'package:pediatria360/shared/clinical/clinical_tasks.dart';
import 'package:pediatria360/shared/clinical/consultation_organizer.dart';
import 'package:pediatria360/shared/clinical/growth.dart';
import 'package:pediatria360/shared/clinical/patient_notes.dart';
import 'package:pediatria360/shared/clinical/patient_timeline.dart';
import 'package:pediatria360/shared/clinical/visit_diary.dart';
import 'package:pediatria360/shared/scheduling/agenda_range.dart';
import 'package:pediatria360/shared/scheduling/slots.dart';

/// Terça-feira, 29/09/2026, 10h.
final DateTime kNow = DateTime(2026, 9, 29, 10);

void main() {
  group('agenda por dia, semana e mês', () {
    test('semana começa na segunda e o mês tem 6 semanas', () {
      expect(startOfWeek(kNow), DateTime(2026, 9, 28));
      final List<DateTime> grid = monthGrid(kNow);
      expect(grid, hasLength(42));
      expect(grid.first, DateTime(2026, 8, 31));
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.contains(DateTime(2026, 9, 30)), isTrue);
    });

    test('limites, avanço e títulos', () {
      final ({DateTime start, DateTime end}) w = agendaBounds(
        AgendaView.semana,
        kNow,
      );
      expect(w.start, DateTime(2026, 9, 28));
      expect(w.end, DateTime(2026, 10, 5));
      final ({DateTime start, DateTime end}) m = agendaBounds(
        AgendaView.mes,
        kNow,
      );
      expect(m.start, DateTime(2026, 9));
      expect(m.end, DateTime(2026, 10));
      expect(shiftAnchor(AgendaView.dia, kNow, 1), DateTime(2026, 9, 30));
      expect(shiftAnchor(AgendaView.semana, kNow, -1), DateTime(2026, 9, 22));
      expect(shiftAnchor(AgendaView.mes, kNow, 1), DateTime(2026, 10));
      expect(agendaTitle(AgendaView.dia, kNow), 'ter, 29/09/2026');
      expect(agendaTitle(AgendaView.semana, kNow), '28/09 a 04/10');
      expect(agendaTitle(AgendaView.mes, kNow), 'setembro de 2026');
      expect(AgendaView.fromSlug('mes'), AgendaView.mes);
      expect(AgendaView.fromSlug('xyz'), AgendaView.dia);
    });

    test('horários livres descontam consultas, bloqueios e o que passou', () {
      final DateTime d = DateTime(2026, 9, 29);
      final List<TimeSpan> free = freeSpans(
        day: d,
        ranges: const <WorkingRange>[WorkingRange(8 * 60, 12 * 60)],
        busy: <TimeSpan>[
          TimeSpan(DateTime(2026, 9, 29, 10, 20), DateTime(2026, 9, 29, 11)),
          TimeSpan(DateTime(2026, 9, 29, 11, 50), DateTime(2026, 9, 29, 12)),
        ],
        notBefore: kNow,
      );
      expect(free, hasLength(2));
      expect(free[0].start, DateTime(2026, 9, 29, 10));
      expect(free[0].end, DateTime(2026, 9, 29, 10, 20));
      expect(free[1].start, DateTime(2026, 9, 29, 11));
      expect(free[1].end, DateTime(2026, 9, 29, 11, 50));
      expect(freeSlotCount(free, 20), 1 + 2);
    });

    test('trecho menor que o mínimo não aparece', () {
      final List<TimeSpan> free = freeSpans(
        day: DateTime(2026, 9, 29),
        ranges: const <WorkingRange>[WorkingRange(14 * 60, 15 * 60)],
        busy: <TimeSpan>[
          TimeSpan(DateTime(2026, 9, 29, 14, 10), DateTime(2026, 9, 29, 15)),
        ],
        notBefore: kNow,
      );
      expect(free, isEmpty);
    });
  });

  group('diário de atendimentos', () {
    VisitClassification k({
      DateTime? start,
      bool cancelled = false,
      bool noShow = false,
      bool concluded = false,
      bool finished = false,
      bool draft = false,
    }) => classifyVisit(
      start: start ?? kNow.subtract(const Duration(days: 1)),
      cancelled: cancelled,
      noShow: noShow,
      concluded: concluded,
      recordFinished: finished,
      recordDraft: draft,
      now: kNow,
    );

    test('classificação', () {
      expect(k(cancelled: true).outcome, VisitOutcome.cancelada);
      expect(k(noShow: true).outcome, VisitOutcome.falta);
      expect(k(finished: true).outcome, VisitOutcome.realizada);
      expect(k(draft: true).outcome, VisitOutcome.pendente);
      expect(k(draft: true).pendingReason, contains('rascunho'));
      expect(k(concluded: true).outcome, VisitOutcome.pendente);
      expect(k().outcome, VisitOutcome.pendente);
      expect(k().pendingReason, contains('sem registro'));
      expect(
        k(start: kNow.add(const Duration(hours: 1))).outcome,
        VisitOutcome.agendada,
      );
    });

    test('períodos olham para trás até o fim de hoje', () {
      expect(DiaryPeriod.hoje.accepts(DateTime(2026, 9, 29, 18), kNow), isTrue);
      expect(
        DiaryPeriod.hoje.accepts(DateTime(2026, 9, 28, 18), kNow),
        isFalse,
      );
      expect(DiaryPeriod.semana.accepts(DateTime(2026, 9, 23), kNow), isTrue);
      expect(DiaryPeriod.semana.accepts(DateTime(2026, 9, 22), kNow), isFalse);
      expect(DiaryPeriod.mes.accepts(DateTime(2026, 8, 31), kNow), isTrue);
      expect(DiaryPeriod.tudo.accepts(DateTime(2020), kNow), isTrue);
      expect(DiaryPeriod.tudo.accepts(DateTime(2026, 9, 30), kNow), isFalse);
    });
  });

  group('tarefas', () {
    ClinicalTask t(String id, {DateTime? due, bool done = false}) {
      final ClinicalTask x = ClinicalTask(
        id: id,
        ownerId: 'prof-a',
        title: id,
        kind: TaskKind.tarefa,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'Dra. Exemplo',
        due: due,
      );
      if (done) x.doneAt = DateTime(2026, 9, 20);
      return x;
    }

    test('prazo e ordem', () {
      expect(
        taskDue(t('a', due: DateTime(2026, 9, 28)), kNow),
        TaskDue.atrasada,
      );
      expect(taskDue(t('b', due: DateTime(2026, 9, 29)), kNow), TaskDue.hoje);
      expect(
        taskDue(t('c', due: DateTime(2026, 10, 2)), kNow),
        TaskDue.proxima,
      );
      expect(taskDue(t('d'), kNow), TaskDue.semData);
      expect(taskDue(t('e', done: true), kNow), TaskDue.concluida);
      final List<ClinicalTask> sorted = sortTasks(<ClinicalTask>[
        t('sem'),
        t('feita', done: true),
        t('depois', due: DateTime(2026, 10, 2)),
        t('antes', due: DateTime(2026, 9, 28)),
      ]);
      expect(sorted.map((ClinicalTask x) => x.id), <String>[
        'antes',
        'depois',
        'sem',
        'feita',
      ]);
    });

    test('validação', () {
      expect(
        validateTask(title: ' ', due: null, now: kNow),
        contains('Descreva a tarefa.'),
      );
      expect(
        validateTask(title: 'x', due: DateTime(2026, 9, 28), now: kNow),
        contains('A data não pode estar no passado.'),
      );
      expect(validateTask(title: 'x', due: kNow, now: kNow), isEmpty);
    });
  });

  group('observações', () {
    PatientNote note() => PatientNote(
      id: 'n',
      patientId: 'p1',
      authorId: 'prof-a',
      author: 'Dra. Exemplo',
      createdAt: DateTime(2026, 9, 1),
      text: 'Texto',
      visibility: NoteVisibility.interna,
    );

    test('editar guarda versões e exige motivo para mudar visibilidade', () {
      final PatientNote n = note();
      expect(n.visibleToGuardian, isFalse);
      expect(
        () => n.edit(
          text: 'Texto',
          visibility: NoteVisibility.interna,
          author: 'A',
          at: kNow,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => n.edit(
          text: 'Texto',
          visibility: NoteVisibility.responsavel,
          author: 'A',
          at: kNow,
        ),
        throwsA(
          predicate(
            (Object e) => e is StateError && e.message.contains('motivo'),
          ),
        ),
      );
      n.edit(
        text: 'Texto revisado',
        visibility: NoteVisibility.responsavel,
        author: 'A',
        at: kNow,
        reason: 'Orientação para a família',
      );
      expect(n.versions, hasLength(2));
      expect(n.versions.first.text, 'Texto');
      expect(n.visibleToGuardian, isTrue);
      n.archive(author: 'A', at: kNow, reason: 'Duplicada');
      expect(n.visibleToGuardian, isFalse);
      expect(n.archived, isTrue);
    });

    test('texto vazio ou longo é recusado', () {
      expect(validateNoteText('  '), 'Escreva a observação.');
      expect(validateNoteText('a' * 2001), isNotNull);
      expect(validateNoteText('ok'), isNull);
    });
  });

  group('organizador da consulta', () {
    test('só preenche seções vazias e nunca sugere avaliação', () {
      final OrganizedDraft d = organizeConsultation(
        const OrganizerInput(
          current: <SummarySection, String>{
            SummarySection.queixa: 'Tosse há 3 dias',
          },
          preVisitReason: 'Febre',
          preVisitSymptoms: 'Coriza',
          transcript:
              'Mãe relata piora à noite. Ausculta sem alterações. '
              'Orientei lavagem nasal. Retorno em 7 dias se persistir.',
        ),
        now: kNow,
        createdBy: 'Dra. Exemplo',
      );
      expect(d.status, DraftStatus.pendente);
      expect(d.suggestions.containsKey(SummarySection.queixa), isFalse);
      expect(d.suggestions.containsKey(SummarySection.avaliacao), isFalse);
      expect(d.suggestions[SummarySection.exameFisico], contains('Ausculta'));
      expect(d.suggestions[SummarySection.conduta], contains('lavagem'));
      expect(d.suggestions[SummarySection.retorno], contains('7 dias'));
      expect(d.suggestions[SummarySection.anamnese], contains('Coriza'));
      expect(d.source, contains('sem IA ativa'));
      expect(d.notes.join(' '), contains('A avaliação não é sugerida'));
    });

    test('sem entrada, nada a sugerir', () {
      final OrganizedDraft d = organizeConsultation(
        const OrganizerInput(),
        now: kNow,
        createdBy: 'Dra. Exemplo',
      );
      expect(d.isEmpty, isTrue);
    });
  });

  group('linha do tempo e comparação', () {
    test('mais recente primeiro e filtro por tipo', () {
      final List<TimelineEvent> all = <TimelineEvent>[
        TimelineEvent(
          at: DateTime(2026, 9, 1),
          kind: TimelineKind.consulta,
          title: 'A',
        ),
        TimelineEvent(
          at: DateTime(2026, 9, 10),
          kind: TimelineKind.receita,
          title: 'B',
        ),
        TimelineEvent(
          at: DateTime(2026, 9, 5),
          kind: TimelineKind.consulta,
          title: 'C',
        ),
      ];
      expect(buildTimeline(all).map((TimelineEvent e) => e.title), <String>[
        'B',
        'C',
        'A',
      ]);
      expect(
        buildTimeline(
          all,
          only: <TimelineKind>{TimelineKind.consulta},
        ).map((TimelineEvent e) => e.title),
        <String>['C', 'A'],
      );
      expect(TimelineKind.forDocument('receituario'), TimelineKind.receita);
      expect(TimelineKind.forDocument('declaracao'), TimelineKind.atestado);
      expect(
        TimelineKind.forDocument('encaminhamento'),
        TimelineKind.encaminhamento,
      );
    });

    test('ganho de peso por dia e crescimento por mês', () {
      final GrowthDelta d = compareGrowth(
        GrowthValues(date: DateTime(2026, 8, 30), weightKg: 8, lengthCm: 70),
        GrowthValues(date: DateTime(2026, 9, 29), weightKg: 8.6, lengthCm: 72),
      );
      expect(d.days, 30);
      expect(d.weightKg, closeTo(0.6, 1e-9));
      expect(d.gramsPerDay, closeTo(20, 1e-9));
      expect(d.cmPerMonth, closeTo(2 / 30 * daysPerMonth, 1e-9));
      expect(d.headCm, isNull);
    });

    test('medida da consulta: a vinculada ou a mais próxima em 7 dias', () {
      GrowthMeasurement m(String id, DateTime date, {String? cid}) =>
          GrowthMeasurement(
            id: id,
            patientId: 'p1',
            values: GrowthValues(date: date, weightKg: 9),
            author: 'A',
            recordedAt: date,
            consultationId: cid,
          );
      final List<GrowthMeasurement> all = <GrowthMeasurement>[
        m('perto', DateTime(2026, 9, 27)),
        m('vinculada', DateTime(2026, 9, 1), cid: 'c9'),
      ];
      expect(
        measurementForVisit(
          all,
          consultationId: 'c9',
          date: DateTime(2026, 9, 29),
        )?.id,
        'vinculada',
      );
      expect(
        measurementForVisit(
          all,
          consultationId: 'cx',
          date: DateTime(2026, 9, 29),
        )?.id,
        'perto',
      );
      expect(
        measurementForVisit(
          all,
          consultationId: 'cx',
          date: DateTime(2026, 7, 1),
        ),
        isNull,
      );
    });
  });

  test('registro de alterações lista só os campos que mudaram', () {
    expect(
      changedFields(
        <String, String>{'Queixa': 'a', 'Conduta': 'b'},
        <String, String>{'Queixa': 'a ', 'Conduta': 'c', 'Anamnese': 'x'},
      ),
      <String>['Conduta', 'Anamnese'],
    );
  });
}
