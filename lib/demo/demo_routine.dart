import 'dart:convert';

import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/lab_results.dart';
import '../shared/routine/child_routine.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_session.dart';

/// Rotina fictícia: compromissos da família, horários da receita d3 e
/// alguns dias de diário para a Luna (p1) e a Alice (p5).
class DemoRoutineSeed {
  DemoRoutineSeed(this.now, this.documents)
    : today = DateTime(now.year, now.month, now.day);

  final DateTime now;
  final DateTime today;
  final List<ClinicalDocRecord> documents;

  static const String _family = DemoSession.guardianOfDemo;

  /// Quadriculado 24x24 gerado para a demonstração (não é foto real).
  static final LabAttachment samplePhoto = LabAttachment(
    name: 'foto-exemplo.png',
    mimeType: 'image/png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAALklEQVR42mPQP74VDb39/B8N'
      'EaOGYdQgOhpEnjZMNaMG0dOg0ZQ9mtdGDaKLQQCg7xuMa1V6iAAAAABJRU5ErkJggg==',
    ),
  );

  DateTime _at(int daysAgo, int h, int m) =>
      DateTime(today.year, today.month, today.day - daysAgo, h, m);

  int _n = 0;
  String _id(String prefix) => '$prefix${++_n}';

  List<RoutineEvent> events() {
    final DateTime swimStart = _at(19, 16, 0);
    String k(int daysAgo) => routineDateKey(_at(daysAgo, 0, 0));
    return <RoutineEvent>[
      RoutineEvent(
        id: 'e1',
        patientId: 'p1',
        kind: RoutineKind.atividade,
        title: 'Natação para bebês (exemplo)',
        start: swimStart,
        durationMinutes: 45,
        repeat: RoutineRepeat.weekly,
        reminders: const <int>[60],
        notes: 'Levar toalha e fralda de piscina.',
        author: _family,
        createdAt: swimStart.subtract(const Duration(days: 2)),
        occurrences: <String, OccurrenceState>{
          k(19): OccurrenceState(
            status: RoutineStatus.done,
            at: _at(19, 17, 0),
            author: _family,
          ),
          k(12): OccurrenceState(
            status: RoutineStatus.cancelled,
            at: _at(12, 9, 0),
            author: _family,
            note: 'Piscina fechada (exemplo)',
          ),
          k(5): OccurrenceState(
            status: RoutineStatus.done,
            at: _at(5, 17, 0),
            author: _family,
          ),
        },
        history: <RoutineChange>[
          RoutineChange(
            at: swimStart.subtract(const Duration(days: 2)),
            author: _family,
            action: 'Criado',
          ),
        ],
      ),
      RoutineEvent(
        id: 'e2',
        patientId: 'p1',
        kind: RoutineKind.lembrete,
        title: 'Levar a carteira de vacinação (exemplo)',
        start: _at(-20, 0, 0),
        allDay: true,
        reminders: const <int>[1440],
        author: _family,
        createdAt: _at(3, 20, 0),
        history: <RoutineChange>[
          RoutineChange(at: _at(3, 20, 0), author: _family, action: 'Criado'),
        ],
      ),
      RoutineEvent(
        id: 'e3',
        patientId: 'p1',
        kind: RoutineKind.lembrete,
        title: 'Comprar fraldas (exemplo)',
        start: _at(1, 18, 0),
        reminders: const <int>[30],
        author: _family,
        createdAt: _at(2, 9, 0),
        occurrences: <String, OccurrenceState>{
          k(1): OccurrenceState(
            status: RoutineStatus.done,
            at: _at(1, 18, 40),
            author: _family,
          ),
        },
        history: <RoutineChange>[
          RoutineChange(at: _at(2, 9, 0), author: _family, action: 'Criado'),
          RoutineChange(
            at: _at(1, 18, 40),
            author: _family,
            action: 'Concluído',
          ),
        ],
      ),
      RoutineEvent(
        id: 'e4',
        patientId: 'p5',
        kind: RoutineKind.atividade,
        title: 'Aula de música (exemplo)',
        start: _at(6, 10, 0),
        durationMinutes: 50,
        repeat: RoutineRepeat.weekly,
        reminders: const <int>[30],
        author: _family,
        createdAt: _at(8, 10, 0),
        history: <RoutineChange>[
          RoutineChange(at: _at(8, 10, 0), author: _family, action: 'Criado'),
        ],
      ),
    ];
  }

  ClinicalDocRecord? get _rx {
    for (final ClinicalDocRecord d in documents) {
      if (d.id == 'd3') return d;
    }
    return null;
  }

  /// Suplemento Exemplo D programado na manhã seguinte à consulta.
  late final MedicationPlan? _supplementPlan = () {
    final ClinicalDocRecord? rx = _rx;
    if (rx == null) return null;
    final DateTime issued = rx.current.issuedAt ?? rx.current.updatedAt;
    final RxItem item = rx.current.items[1];
    final DateTime first = DateTime(
      issued.year,
      issued.month,
      issued.day + 1,
      8,
    );
    return MedicationPlan(
      id: 'm1',
      patientId: 'p1',
      docId: rx.id,
      itemIndex: 1,
      drug: item.drug,
      posology: item.posology,
      firstDose: first,
      intervalHours: parseIntervalHours(item.frequency) ?? 24,
      days: parseDurationDays(item.duration) ?? 30,
      reminders: const <int>[0],
      author: _family,
      createdAt: issued.add(const Duration(hours: 3)),
      history: <RoutineChange>[
        RoutineChange(
          at: issued.add(const Duration(hours: 3)),
          author: _family,
          action: 'Horários programados',
          detail: 'a partir de ${formatDmy(first)} às ${formatHm(first)}',
        ),
      ],
    );
  }();

  final List<DiaryEntry> _doseEntries = <DiaryEntry>[];

  List<MedicationPlan> plans() {
    MedicationPlan? plan = _supplementPlan;
    if (plan == null) return <MedicationPlan>[];
    final DateTime skipDay = addDays(plan.firstDose, 3);
    for (final DateTime t in plan.doseTimes()) {
      final DateTime given = t.add(const Duration(minutes: 5));
      if (!given.isBefore(now)) break;
      final String key = MedicationPlan.doseKey(t);
      if (sameDay(t, skipDay)) {
        plan = plan!.withDose(
          key,
          RoutineStatus.cancelled,
          author: _family,
          at: t.add(const Duration(hours: 12)),
          note: 'Esqueci de dar (exemplo)',
        );
        continue;
      }
      final String id = _id('rd');
      _doseEntries.add(
        DiaryEntry(
          id: id,
          patientId: 'p1',
          kind: DiaryKind.medicamento,
          values: DiaryValues(
            at: given,
            text: plan!.drug,
            quantity: 2,
            unit: 'gotas',
          ),
          author: _family,
          role: DiaryRole.familia,
          recordedAt: given,
          planId: plan.id,
          doseKey: key,
        ),
      );
      plan = plan.withDose(
        key,
        RoutineStatus.done,
        author: _family,
        at: given,
        diaryEntryId: id,
      );
    }
    return <MedicationPlan>[plan!];
  }

  DiaryEntry _e(
    String patientId,
    DiaryKind kind,
    DiaryValues v, {
    LabAttachment? attachment,
    List<DiaryRevision> revisions = const <DiaryRevision>[],
  }) {
    return DiaryEntry(
      id: _id('rs'),
      patientId: patientId,
      kind: kind,
      values: v,
      author: _family,
      role: DiaryRole.familia,
      recordedAt: (v.endAt ?? v.at).add(const Duration(minutes: 2)),
      attachment: attachment,
      revisions: revisions,
    );
  }

  List<DiaryEntry> _lunaDay(int d) => <DiaryEntry>[
    _e(
      'p1',
      DiaryKind.mamada,
      DiaryValues(
        at: _at(d, 6, 40),
        option: 'Os dois peitos',
        durationMinutes: 15,
      ),
    ),
    _e('p1', DiaryKind.fralda, DiaryValues(at: _at(d, 7, 10), option: 'Xixi')),
    _e(
      'p1',
      DiaryKind.alimentacao,
      DiaryValues(
        at: _at(d, 9, 30),
        text: 'Mamão amassado (exemplo)',
        quantity: 4,
        unit: 'colheres',
        option: 'Aceitou bem',
      ),
    ),
    _e(
      'p1',
      DiaryKind.sono,
      DiaryValues(at: _at(d, 10, 15), endAt: _at(d, 11, 30)),
    ),
    _e(
      'p1',
      DiaryKind.alimentacao,
      DiaryValues(
        at: _at(d, 12, 30),
        text: 'Arroz, feijão e legumes (exemplo)',
        quantity: 6,
        unit: 'colheres',
        option: 'Aceitou parte',
      ),
    ),
    _e(
      'p1',
      DiaryKind.fralda,
      DiaryValues(at: _at(d, 14, 0), option: 'Xixi e cocô'),
    ),
    _e(
      'p1',
      DiaryKind.sono,
      DiaryValues(at: _at(d, 15, 0), endAt: _at(d, 16, 20)),
    ),
    _e('p1', DiaryKind.fralda, DiaryValues(at: _at(d, 17, 0), option: 'Xixi')),
    _e(
      'p1',
      DiaryKind.banho,
      DiaryValues(at: _at(d, 18, 30), durationMinutes: 15),
    ),
    _e(
      'p1',
      DiaryKind.mamada,
      DiaryValues(
        at: _at(d, 19, 30),
        option: 'Os dois peitos',
        durationMinutes: 12,
      ),
    ),
    if (d > 0)
      _e(
        'p1',
        DiaryKind.sono,
        DiaryValues(at: _at(d, 20, 30), endAt: _at(d - 1, 6, 0)),
      ),
  ];

  List<DiaryEntry> diary() {
    final List<DiaryEntry> all = <DiaryEntry>[
      for (final int d in <int>[2, 1, 0]) ..._lunaDay(d),
      _e(
        'p1',
        DiaryKind.peso,
        DiaryValues(
          at: _at(2, 11, 0),
          quantity: 10.4,
          unit: 'kg',
          note: 'Balança da farmácia (exemplo)',
        ),
        revisions: <DiaryRevision>[
          DiaryRevision(
            at: _at(2, 11, 20),
            author: _family,
            action: 'Corrigido',
            reason: 'Digitei errado',
            before: DiaryValues(
              at: _at(2, 11, 0),
              quantity: 14,
              unit: 'kg',
              note: 'Balança da farmácia (exemplo)',
            ),
          ),
        ],
      ),
      _e(
        'p1',
        DiaryKind.temperatura,
        DiaryValues(
          at: _at(2, 21, 40),
          quantity: 37.8,
          unit: '°C',
          option: 'Axilar',
          note: 'Logo depois do banho (exemplo)',
        ),
      ),
      _e(
        'p1',
        DiaryKind.temperatura,
        DiaryValues(
          at: _at(1, 19, 0),
          quantity: 36.9,
          unit: '°C',
          option: 'Axilar',
        ),
      ),
      _e(
        'p1',
        DiaryKind.observacao,
        DiaryValues(
          at: _at(1, 16, 30),
          text: 'Deu os primeiros passos sem apoio (exemplo).',
        ),
        attachment: samplePhoto,
      ),
      _e(
        'p5',
        DiaryKind.alimentacao,
        DiaryValues(
          at: _at(1, 8, 0),
          text: 'Pão com queijo (exemplo)',
          quantity: 1,
          unit: 'porção',
          option: 'Aceitou bem',
        ),
      ),
      _e(
        'p5',
        DiaryKind.sono,
        DiaryValues(at: _at(1, 13, 0), endAt: _at(1, 14, 30)),
      ),
      _e(
        'p5',
        DiaryKind.banho,
        DiaryValues(at: _at(1, 19, 0), durationMinutes: 20),
      ),
      _e(
        'p5',
        DiaryKind.alimentacao,
        DiaryValues(
          at: _at(0, 8, 0),
          text: 'Mingau de aveia (exemplo)',
          quantity: 1,
          unit: 'porção',
          option: 'Aceitou parte',
        ),
      ),
      ..._doseEntries,
    ];
    return all
        .where(
          (DiaryEntry e) =>
              e.at.isBefore(now) &&
              (e.values.endAt == null || e.values.endAt!.isBefore(now)),
        )
        .toList()
      ..sort((DiaryEntry a, DiaryEntry b) => a.at.compareTo(b.at));
  }

  /// Um resumo já enviado pela família da Luna, para o profissional ver.
  List<SharedRoutineSummary> sharedSummaries(DemoSession s) {
    final DateTime from = _at(2, 0, 0);
    final DateTime to = _at(1, 0, 0);
    final DateTime sentAt = _at(1, 21, 0);
    final RoutineSummary summary = RoutineSummary.build(
      entries: s.diaryFor('p1'),
      from: from,
      to: to,
    );
    return <SharedRoutineSummary>[
      SharedRoutineSummary(
        id: 's1',
        patientId: 'p1',
        from: from,
        to: to,
        kinds: summary.kinds,
        text: summary.toText(
          patientName: 'Luna Exemplo Souza',
          guardianName: _family,
          generatedAt: sentAt,
        ),
        entryCount: summary.entries.length,
        author: _family,
        sentAt: sentAt,
        message: 'Resumo dos últimos dias antes do retorno (exemplo).',
      ),
    ];
  }
}

/// Item de receita emitida, com os horários programados (se houver).
class PrescribedItem {
  const PrescribedItem({
    required this.doc,
    required this.index,
    required this.item,
    required this.issuedAt,
    this.plan,
  });

  final ClinicalDocRecord doc;
  final int index;
  final RxItem item;
  final DateTime issuedAt;
  final MedicationPlan? plan;
}

class PendingVaccine {
  const PendingVaccine(this.record, this.scheduled);

  final DemoVaccineRecord record;

  /// Compromisso da família ligado a esta vacina (evita agendar duas vezes).
  final RoutineEvent? scheduled;
}

class DoseSlot {
  const DoseSlot(this.plan, this.time);

  final MedicationPlan plan;
  final DateTime time;

  String get key => MedicationPlan.doseKey(time);
}

class ReminderAlert {
  const ReminderAlert(this.patient, this.reminder);

  final DemoPatient patient;
  final DueReminder reminder;
}

/// Consultas, vacinas e receitas continuam nos próprios cadastros; a rotina
/// só os lê e junta aos compromissos da família.
extension DemoRoutineQueries on DemoSession {
  List<CalendarItem> routineItems(
    String patientId,
    DateTime from,
    DateTime to,
  ) {
    bool inRange(DateTime t) => !t.isBefore(from) && t.isBefore(to);
    final List<CalendarItem> out = <CalendarItem>[];

    for (final DemoAppointment a in appointments) {
      if (a.patientId != patientId || !inRange(a.start)) continue;
      final String id = 'appt:${a.id}';
      out.add(
        CalendarItem(
          id: id,
          patientId: patientId,
          kind: a.reason.toLowerCase().contains('retorno')
              ? RoutineKind.retorno
              : RoutineKind.consulta,
          title: a.reason,
          start: a.start,
          durationMinutes: 30,
          status: a.status == DemoAppointmentStatus.concluido
              ? RoutineStatus.done
              : RoutineStatus.planned,
          source: RoutineSource.clinica,
          detail:
              '${a.kind == DemoAppointmentKind.teleconsulta ? 'Teleconsulta' : 'Presencial'} - ${DemoProfessional.name}',
          reminders: itemReminders[id] ?? const <int>[],
          appointmentId: a.id,
        ),
      );
    }

    for (final DemoConsultation c in consultations) {
      if (c.patientId != patientId ||
          c.status != DemoConsultationStatus.finished ||
          !inRange(c.startedAt)) {
        continue;
      }
      out.add(
        CalendarItem(
          id: 'cons:${c.id}',
          patientId: patientId,
          kind: RoutineKind.consulta,
          title: 'Consulta realizada',
          start: c.startedAt,
          status: RoutineStatus.done,
          source: RoutineSource.clinica,
          detail: c.author,
        ),
      );
    }

    for (final DemoVaccineRecord v in vaccines) {
      if (v.patientId != patientId ||
          v.status != DemoVaccineStatus.registrada ||
          v.date == null ||
          !inRange(dayOf(v.date!))) {
        continue;
      }
      out.add(
        CalendarItem(
          id: 'vac:$patientId:${v.name}:${v.dose}',
          patientId: patientId,
          kind: RoutineKind.vacina,
          title: '${v.name} - ${v.dose}',
          start: dayOf(v.date!),
          allDay: true,
          status: RoutineStatus.done,
          source: RoutineSource.clinica,
          detail: 'Registrada na carteira de vacinação',
        ),
      );
    }

    for (final RoutineEvent e in routineEvents) {
      if (e.patientId != patientId) continue;
      for (final DateTime s in e.occurrencesBetween(from, to)) {
        final String key = routineDateKey(s);
        out.add(
          CalendarItem(
            id: 'ev:${e.id}:$key',
            patientId: patientId,
            kind: e.kind,
            title: e.title,
            start: s,
            allDay: e.allDay,
            durationMinutes: e.durationMinutes,
            status: e.statusOf(key),
            source: RoutineSource.familia,
            detail: e.notes,
            reminders: e.reminders,
            eventId: e.id,
            occurrenceKey: key,
          ),
        );
      }
    }

    for (final MedicationPlan p in medicationPlans) {
      if (p.patientId != patientId) continue;
      for (final DateTime t in p.dosesBetween(from, to)) {
        final String key = MedicationPlan.doseKey(t);
        out.add(
          CalendarItem(
            id: 'dose:${p.id}:$key',
            patientId: patientId,
            kind: RoutineKind.medicamento,
            title: p.drug,
            start: t,
            status: p.statusOf(key),
            source: RoutineSource.receita,
            detail: p.posology,
            reminders: p.reminders,
            planId: p.id,
            doseKey: key,
            docId: p.docId,
          ),
        );
      }
    }

    for (final PrescribedItem rx in _issuedPrescriptions(patientId)) {
      if (rx.index != 0 || !inRange(dayOf(rx.issuedAt))) continue;
      final List<RxItem> items = rx.doc.current.items;
      out.add(
        CalendarItem(
          id: 'rx:${rx.doc.id}',
          patientId: patientId,
          kind: RoutineKind.medicamento,
          title:
              'Receita emitida (${items.length} ${items.length == 1 ? 'item' : 'itens'})',
          start: dayOf(rx.issuedAt),
          allDay: true,
          status: RoutineStatus.done,
          source: RoutineSource.clinica,
          detail: items.map((RxItem i) => i.drug).join(', '),
          docId: rx.doc.id,
        ),
      );
    }

    out.sort(compareCalendarItems);
    return out;
  }

  List<CalendarItem> routineItemsOn(String patientId, DateTime day) =>
      routineItems(patientId, dayOf(day), addDays(dayOf(day), 1));

  List<PrescribedItem> _issuedPrescriptions(String patientId) {
    final List<PrescribedItem> out = <PrescribedItem>[];
    for (final ClinicalDocRecord d in documents) {
      if (d.patientId != patientId ||
          d.kind != DocKind.receituario ||
          d.status != DocStatus.issued) {
        continue;
      }
      final DateTime at = d.current.issuedAt ?? d.current.updatedAt;
      for (int i = 0; i < d.current.items.length; i++) {
        out.add(
          PrescribedItem(
            doc: d,
            index: i,
            item: d.current.items[i],
            issuedAt: at,
            plan: planFor(d.id, i),
          ),
        );
      }
    }
    out.sort(
      (PrescribedItem a, PrescribedItem b) => b.issuedAt.compareTo(a.issuedAt),
    );
    return out;
  }

  List<PrescribedItem> prescribedItems(String patientId) =>
      _issuedPrescriptions(patientId);

  PrescribedItem? prescribedItem(String patientId, String docId, int index) {
    for (final PrescribedItem p in _issuedPrescriptions(patientId)) {
      if (p.doc.id == docId && p.index == index) return p;
    }
    return null;
  }

  List<PendingVaccine> pendingVaccines(String patientId) {
    final List<PendingVaccine> out = <PendingVaccine>[];
    for (final DemoVaccineRecord v in vaccines) {
      if (v.patientId != patientId || v.status != DemoVaccineStatus.pendente) {
        continue;
      }
      RoutineEvent? scheduled;
      for (final RoutineEvent e in routineEvents) {
        if (e.patientId == patientId &&
            e.vaccineName == v.name &&
            e.vaccineDose == v.dose &&
            e.statusOf(routineDateKey(e.start)) != RoutineStatus.cancelled) {
          scheduled = e;
        }
      }
      out.add(PendingVaccine(v, scheduled));
    }
    return out;
  }

  List<DiaryEntry> diaryFor(
    String patientId, {
    DateTime? day,
    Set<DiaryKind>? kinds,
    bool includeVoided = false,
  }) {
    return diaryEntries
        .where(
          (DiaryEntry e) =>
              e.patientId == patientId &&
              (includeVoided || !e.voided) &&
              (day == null || sameDay(e.at, day)) &&
              (kinds == null || kinds.isEmpty || kinds.contains(e.kind)),
        )
        .toList()
      ..sort((DiaryEntry a, DiaryEntry b) => a.at.compareTo(b.at));
  }

  DiaryEntry? openSleep(String patientId) {
    for (final DiaryEntry e in diaryFor(patientId).reversed) {
      if (e.isOpenSleep) return e;
    }
    return null;
  }

  DateTime? lastConsultationDay(String patientId) {
    DateTime? last;
    for (final DemoConsultation c in consultations) {
      if (c.patientId != patientId ||
          c.status != DemoConsultationStatus.finished) {
        continue;
      }
      if (last == null || c.startedAt.isAfter(last)) last = c.startedAt;
    }
    return last == null ? null : dayOf(last);
  }

  /// Doses ainda planejadas perto de [t], da mais próxima para a mais
  /// distante (para o botão "Medicamento" do diário).
  List<DoseSlot> dosesNear(String patientId, DateTime t) {
    final List<DoseSlot> out = <DoseSlot>[];
    for (final MedicationPlan p in medicationPlans) {
      if (p.patientId != patientId) continue;
      for (final DateTime d in p.dosesBetween(
        t.subtract(const Duration(hours: 12)),
        t.add(const Duration(hours: 4)),
      )) {
        if (p.statusOf(MedicationPlan.doseKey(d)) == RoutineStatus.planned) {
          out.add(DoseSlot(p, d));
        }
      }
    }
    out.sort(
      (DoseSlot a, DoseSlot b) =>
          a.time.difference(t).abs().compareTo(b.time.difference(t).abs()),
    );
    return out;
  }

  /// Lembretes vencidos nas últimas 12 horas, para as crianças do
  /// responsável. O app real usaria notificação do sistema.
  List<ReminderAlert> activeReminders() {
    if (!canEditRoutine) return const <ReminderAlert>[];
    final DateTime t = now;
    final List<ReminderAlert> out = <ReminderAlert>[];
    for (final DemoPatient p in routinePatients) {
      final List<CalendarItem> items = routineItems(
        p.id,
        dayOf(t).subtract(const Duration(days: 1)),
        addDays(dayOf(t), 3),
      );
      for (final DueReminder r in dueReminders(
        items,
        from: t.subtract(const Duration(hours: 12)),
        to: t,
        dismissed: dismissedReminders,
      )) {
        out.add(ReminderAlert(p, r));
      }
    }
    out.sort(
      (ReminderAlert a, ReminderAlert b) =>
          b.reminder.at.compareTo(a.reminder.at),
    );
    return out;
  }
}
