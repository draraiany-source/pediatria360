import '../shared/clinical/audit_trail.dart';
import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/clinical_tasks.dart';
import '../shared/clinical/consultation_organizer.dart';
import '../shared/clinical/growth.dart';
import '../shared/clinical/lab_results.dart';
import '../shared/clinical/patient_notes.dart';
import '../shared/clinical/patient_timeline.dart';
import '../shared/clinical/visit_diary.dart';
import '../shared/previsit/pre_visit.dart';
import '../shared/scheduling/agenda_range.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_session.dart';

/// Linha do diário de atendimentos.
class DemoDiaryEntry {
  const DemoDiaryEntry({
    required this.appointment,
    required this.patient,
    required this.classification,
    this.consultation,
  });

  final DemoAppointment appointment;
  final DemoPatient patient;
  final VisitClassification classification;
  final DemoConsultation? consultation;
}

/// Área clínica do profissional: diário, tarefas, observações, resumo,
/// histórico e registro de alterações. Vive só na memória da aba.
class DemoWorkspace {
  DemoWorkspace(this.s) {
    _seed();
  }

  final DemoSession s;
  final List<PatientNote> notes = <PatientNote>[];
  final List<ClinicalTask> tasks = <ClinicalTask>[];
  final List<AuditEntry> audit = <AuditEntry>[];
  final Map<String, OrganizedDraft> drafts = <String, OrganizedDraft>{};
  final Map<String, Map<String, String>> _snapshots =
      <String, Map<String, String>>{};

  DateTime get _now => s.now;

  String get _actor => switch (s.profile) {
    DemoProfile.recepcao => 'Recepção',
    DemoProfile.responsavel => 'Família',
    DemoProfile.administrador => 'Administração',
    DemoProfile.financeiro => 'Financeiro',
    _ => s.currentAuthor,
  };

  // ------------------------------------------------------------ Semente

  void _seed() {
    final DateTime now = _now;
    DateTime ago(int days, [int hour = 10]) =>
        DateTime(now.year, now.month, now.day - days, hour);
    notes.addAll(<PatientNote>[
      PatientNote(
        id: 'n1',
        patientId: 'p1',
        authorId: DemoProfessional.id,
        author: DemoProfessional.name,
        createdAt: ago(12),
        text: 'Família prefere consultas pela manhã (exemplo).',
        visibility: NoteVisibility.interna,
      ),
      PatientNote(
        id: 'n2',
        patientId: 'p1',
        authorId: DemoProfessional.id,
        author: DemoProfessional.name,
        createdAt: ago(10, 11),
        text: 'Trazer a caderneta de vacinação na próxima consulta (exemplo).',
        visibility: NoteVisibility.responsavel,
        consultationId: 'c1',
      ),
      PatientNote(
        id: 'n3',
        patientId: 'p5',
        authorId: DemoProfessional.id,
        author: DemoProfessional.name,
        createdAt: ago(5),
        text: 'Acompanhar o sono na próxima consulta (exemplo).',
        visibility: NoteVisibility.interna,
      ),
      PatientNote(
        id: 'n4',
        patientId: 'p1',
        authorId: DemoProfessional.colleague.id,
        author: DemoProfessional.colleague.name,
        createdAt: ago(3),
        text: 'Anotação de outra clínica (exemplo).',
        visibility: NoteVisibility.interna,
      ),
    ]);
    ClinicalTask task(
      String id,
      String title, {
      required TaskKind kind,
      DateTime? due,
      String? patientId,
      String owner = DemoProfessional.id,
    }) => ClinicalTask(
      id: id,
      ownerId: owner,
      title: title,
      kind: kind,
      createdAt: ago(6),
      createdBy: DemoProfessional.byId(owner).name,
      due: due,
      patientId: patientId,
    );
    tasks.addAll(<ClinicalTask>[
      task(
        't1',
        'Conferir resultado de exame (exemplo)',
        kind: TaskKind.acompanhamento,
        due: ago(0),
        patientId: 'p1',
      ),
      task(
        't2',
        'Ligar para a família depois da falta (exemplo)',
        kind: TaskKind.tarefa,
        due: ago(1),
        patientId: 'p3',
      ),
      task(
        't3',
        'Revisar modelos de orientação (exemplo)',
        kind: TaskKind.tarefa,
        due: DateTime(now.year, now.month, now.day + 5),
      ),
      task(
          't4',
          'Enviar orientações de sono (exemplo)',
          kind: TaskKind.acompanhamento,
          patientId: 'p5',
        )
        ..doneAt = ago(2, 16)
        ..doneBy = DemoProfessional.name,
      task(
        't5',
        'Tarefa da outra clínica (exemplo)',
        kind: TaskKind.tarefa,
        patientId: 'p8',
        owner: 'prof-b',
      ),
    ]);
    for (final DemoConsultation c in s.consultations) {
      _snapshots[c.id] = _fieldsOf(c);
    }
    audit.addAll(<AuditEntry>[
      AuditEntry(
        at: ago(40, 9),
        actor: DemoProfessional.name,
        entity: AuditEntity.consulta,
        entityId: 'c3',
        action: 'Consulta de puericultura finalizada',
        patientId: 'p1',
      ),
      AuditEntry(
        at: ago(10, 9),
        actor: DemoProfessional.name,
        entity: AuditEntity.consulta,
        entityId: 'c1',
        action: 'Consulta finalizada',
        patientId: 'p1',
        detail: 'Retorno recomendado em 30 dias.',
      ),
      AuditEntry(
        at: ago(3, 11),
        actor: 'Recepção',
        entity: AuditEntity.agendamento,
        entityId: 'a9',
        action: 'Status alterado: Agendado para Falta',
        patientId: 'p3',
      ),
    ]);
  }

  // ------------------------------------------------------------ Permissões

  bool get isProfessional => s.profile == DemoProfile.profissional;
  bool get canUseDiary => isProfessional;
  bool get canWriteNotes => isProfessional;

  /// Recepção vê todos os horários; o profissional, só os dele.
  bool canOpenAppointment(DemoAppointment a) =>
      s.profile == DemoProfile.recepcao ||
      (isProfessional && a.professionalId == s.account.id);

  bool get canSetAppointmentStatus =>
      s.profile == DemoProfile.recepcao || isProfessional;

  bool _sameClinic(String accountId) =>
      DemoProfessional.byId(accountId).clinic == s.account.clinic;

  // ------------------------------------------------------------ Registro

  void log(
    AuditEntity entity,
    String entityId,
    String action, {
    String? patientId,
    String? detail,
  }) {
    audit.add(
      AuditEntry(
        at: _now,
        actor: _actor,
        entity: entity,
        entityId: entityId,
        action: action,
        patientId: patientId,
        detail: detail,
      ),
    );
  }

  /// Mais recente primeiro; no mesmo instante, o último registrado primeiro.
  List<AuditEntry> auditFor(String patientId, {String? entityId}) {
    final List<(int, AuditEntry)> found = <(int, AuditEntry)>[
      for (final (int i, AuditEntry e) in audit.indexed)
        if (e.patientId == patientId &&
            (entityId == null || e.entityId == entityId))
          (i, e),
    ];
    found.sort(((int, AuditEntry) a, (int, AuditEntry) b) {
      final int byTime = b.$2.at.compareTo(a.$2.at);
      return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
    });
    return <AuditEntry>[for (final (_, AuditEntry e) in found) e];
  }

  // ------------------------------------------------------------ Observações

  List<PatientNote> notesFor(String patientId, {bool archived = false}) {
    if (s.patientById(patientId) == null) return const <PatientNote>[];
    final Iterable<PatientNote> mine = notes.where(
      (PatientNote n) => n.patientId == patientId && n.archived == archived,
    );
    final Iterable<PatientNote> visible = switch (s.profile) {
      DemoProfile.profissional => mine.where(
        (PatientNote n) => _sameClinic(n.authorId),
      ),
      DemoProfile.responsavel => mine.where(
        (PatientNote n) => n.visibleToGuardian,
      ),
      _ => const <PatientNote>[],
    };
    return visible.toList()..sort(
      (PatientNote a, PatientNote b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  PatientNote _editableNote(String id) {
    if (!canWriteNotes) {
      throw StateError('Só o profissional escreve observações.');
    }
    final PatientNote n = notes.firstWhere(
      (PatientNote x) => x.id == id,
      orElse: () => throw StateError('Observação não encontrada.'),
    );
    if (!_sameClinic(n.authorId)) {
      throw StateError('Observação de outra clínica.');
    }
    return n;
  }

  PatientNote addNote(
    String patientId,
    String text,
    NoteVisibility visibility, {
    String? consultationId,
  }) {
    if (!canWriteNotes) {
      throw StateError('Só o profissional escreve observações.');
    }
    if (s.patientById(patientId) == null) {
      throw StateError('Paciente não encontrado.');
    }
    final String? error = validateNoteText(text);
    if (error != null) throw StateError(error);
    final PatientNote n = PatientNote(
      id: s.newId('n'),
      patientId: patientId,
      authorId: s.account.id,
      author: s.currentAuthor,
      createdAt: _now,
      text: text,
      visibility: visibility,
      consultationId: consultationId,
    );
    notes.add(n);
    log(
      AuditEntity.observacao,
      n.id,
      'Observação criada (${visibility.label.toLowerCase()})',
      patientId: patientId,
    );
    s.changed();
    return n;
  }

  void editNote(
    String id, {
    required String text,
    required NoteVisibility visibility,
    String? reason,
  }) {
    final PatientNote n = _editableNote(id);
    final NoteVisibility before = n.visibility;
    n.edit(
      text: text,
      visibility: visibility,
      author: s.currentAuthor,
      at: _now,
      reason: reason,
    );
    log(
      AuditEntity.observacao,
      n.id,
      before == visibility
          ? 'Observação editada'
          : 'Visibilidade alterada: ${before.label} para ${visibility.label}',
      patientId: n.patientId,
      detail: reason,
    );
    s.changed();
  }

  void archiveNote(String id, String reason) {
    final PatientNote n = _editableNote(id);
    n.archive(author: s.currentAuthor, at: _now, reason: reason);
    log(
      AuditEntity.observacao,
      n.id,
      'Observação arquivada',
      patientId: n.patientId,
      detail: reason,
    );
    s.changed();
  }

  // ------------------------------------------------------------ Tarefas

  List<ClinicalTask> tasksFor({String? patientId}) {
    if (!canUseDiary) return const <ClinicalTask>[];
    return sortTasks(
      tasks.where(
        (ClinicalTask t) =>
            t.ownerId == s.account.id &&
            (patientId == null || t.patientId == patientId),
      ),
    );
  }

  /// Atrasadas e para hoje.
  int get tasksDueNow => tasksFor().where((ClinicalTask t) {
    final TaskDue d = taskDue(t, _now);
    return d == TaskDue.atrasada || d == TaskDue.hoje;
  }).length;

  ClinicalTask addTask({
    required String title,
    required TaskKind kind,
    DateTime? due,
    String? patientId,
    String? consultationId,
  }) {
    if (!canUseDiary) throw StateError('Só o profissional usa as tarefas.');
    final List<String> errors = validateTask(title: title, due: due, now: _now);
    if (errors.isNotEmpty) throw StateError(errors.first);
    if (patientId != null && s.patientById(patientId) == null) {
      throw StateError('Paciente não encontrado.');
    }
    final ClinicalTask t = ClinicalTask(
      id: s.newId('t'),
      ownerId: s.account.id,
      title: title.trim(),
      kind: kind,
      createdAt: _now,
      createdBy: s.currentAuthor,
      due: due == null ? null : dateOnly(due),
      patientId: patientId,
      consultationId: consultationId,
    );
    tasks.add(t);
    log(
      AuditEntity.tarefa,
      t.id,
      '${kind.label} criada: ${t.title}',
      patientId: patientId,
    );
    s.changed();
    return t;
  }

  void setTaskDone(String id, bool done) {
    final ClinicalTask t = tasks.firstWhere(
      (ClinicalTask x) => x.id == id && x.ownerId == s.account.id,
      orElse: () => throw StateError('Tarefa não encontrada.'),
    );
    if (t.done == done) return;
    t
      ..doneAt = done ? _now : null
      ..doneBy = done ? s.currentAuthor : null;
    log(
      AuditEntity.tarefa,
      t.id,
      done ? 'Tarefa concluída: ${t.title}' : 'Tarefa reaberta: ${t.title}',
      patientId: t.patientId,
    );
    s.changed();
  }

  // ------------------------------------------------------------ Agenda e consulta

  DemoConsultation? consultationForAppointment(String appointmentId) {
    for (final DemoConsultation c in s.consultations) {
      if (c.appointmentId == appointmentId) return c;
    }
    return null;
  }

  /// Abre (ou retoma) a consulta do horário, vinculada a ele.
  DemoConsultation startVisit(DemoAppointment a) {
    if (!isProfessional || !canOpenAppointment(a)) {
      throw StateError('Só o profissional do horário inicia a consulta.');
    }
    if (!a.status.holdsSlot || a.status == DemoAppointmentStatus.falta) {
      throw StateError('Horário cancelado ou com falta registrada.');
    }
    final DemoConsultation? existing = consultationForAppointment(a.id);
    if (existing != null) return existing;
    if (a.status == DemoAppointmentStatus.agendado ||
        a.status == DemoAppointmentStatus.confirmado) {
      s.setAppointmentStatus(a, DemoAppointmentStatus.chegou);
    }
    return s.startConsultation(a.patientId, appointmentId: a.id);
  }

  Map<String, String> _fieldsOf(DemoConsultation c) => <String, String>{
    'Queixa': c.complaint,
    'Anamnese': c.history,
    'Exame físico': c.physicalExam,
    'Avaliação': c.assessment,
    'Conduta': c.plan,
    'Plano de retorno': '${c.returnPlan}|${c.returnInDays ?? ''}',
  };

  void onStarted(DemoConsultation c) {
    _snapshots[c.id] = _fieldsOf(c);
    log(
      AuditEntity.consulta,
      c.id,
      c.isWellChild ? 'Consulta de puericultura iniciada' : 'Consulta iniciada',
      patientId: c.patientId,
      detail: c.appointmentId == null
          ? null
          : 'Horário ${_appointmentLabel(c.appointmentId!)}',
    );
  }

  /// Guarda quais campos mudaram (não o conteúdo) a cada salvamento.
  void onSaved(DemoConsultation c) {
    final Map<String, String> now = _fieldsOf(c);
    final List<String> changed = changedFields(
      _snapshots[c.id] ?? const <String, String>{},
      now,
    );
    _snapshots[c.id] = now;
    if (changed.isEmpty) return;
    log(
      AuditEntity.consulta,
      c.id,
      c.isDraft ? 'Rascunho salvo' : 'Consulta alterada',
      patientId: c.patientId,
      detail: 'Campos: ${changed.join(', ')}',
    );
  }

  void onFinished(DemoConsultation c) {
    _snapshots[c.id] = _fieldsOf(c);
    String? returnDetail;
    if (c.appointmentId != null) {
      final DemoAppointment? a = s.appointmentById(c.appointmentId!);
      if (a != null &&
          a.status.holdsSlot &&
          a.status != DemoAppointmentStatus.concluido) {
        s.setAppointmentStatus(a, DemoAppointmentStatus.concluido);
      }
    }
    if (c.returnInDays != null) {
      final DateTime today = dateOnly(_now);
      final DateTime due = DateTime(
        today.year,
        today.month,
        today.day + c.returnInDays!,
      );
      s.scheduling.recommendedReturns[c.patientId] = (due, s.account.id);
      returnDetail = 'Retorno recomendado para ${_dmy(due)}.';
      final String child =
          s.patientById(c.patientId)?.name.split(' ').first ?? 'paciente';
      tasks.add(
        ClinicalTask(
          id: s.newId('t'),
          ownerId: s.account.id,
          title: 'Conferir se o retorno de $child foi agendado',
          kind: TaskKind.acompanhamento,
          createdAt: _now,
          createdBy: s.currentAuthor,
          due: DateTime(due.year, due.month, due.day - 7).isBefore(today)
              ? today
              : DateTime(due.year, due.month, due.day - 7),
          patientId: c.patientId,
          consultationId: c.id,
        ),
      );
    }
    log(
      AuditEntity.consulta,
      c.id,
      c.isWellChild
          ? 'Consulta de puericultura finalizada'
          : 'Consulta finalizada',
      patientId: c.patientId,
      detail: returnDetail,
    );
  }

  void onAppointmentStatus(
    DemoAppointment a,
    DemoAppointmentStatus before,
    DemoAppointmentStatus after,
  ) {
    log(
      AuditEntity.agendamento,
      a.id,
      'Status alterado: ${statusLabel(before)} para ${statusLabel(after)}',
      patientId: a.patientId,
    );
  }

  static String statusLabel(DemoAppointmentStatus st) => switch (st) {
    DemoAppointmentStatus.agendado => 'Agendado',
    DemoAppointmentStatus.confirmado => 'Confirmado',
    DemoAppointmentStatus.chegou => 'Chegou',
    DemoAppointmentStatus.concluido => 'Concluído',
    DemoAppointmentStatus.reagendar => 'Reagendar',
    DemoAppointmentStatus.cancelado => 'Cancelado',
    DemoAppointmentStatus.falta => 'Falta',
  };

  String _appointmentLabel(String id) {
    final DemoAppointment? a = s.appointmentById(id);
    if (a == null) return id;
    return '${_dmy(a.start)} às ${_hm(a.start)}';
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ Diário

  List<DemoDiaryEntry> diary({
    DiaryPeriod period = DiaryPeriod.semana,
    String? patientId,
    VisitOutcome? outcome,
  }) {
    if (!canUseDiary) return const <DemoDiaryEntry>[];
    final List<DemoDiaryEntry> out = <DemoDiaryEntry>[];
    for (final DemoAppointment a in s.appointments) {
      if (a.professionalId != s.account.id) continue;
      if (patientId != null && a.patientId != patientId) continue;
      if (!period.accepts(a.start, _now)) continue;
      final DemoPatient? p = s.patientById(a.patientId);
      if (p == null) continue;
      final DemoConsultation? c = consultationForAppointment(a.id);
      final VisitClassification k = classifyVisit(
        start: a.start,
        cancelled: a.status == DemoAppointmentStatus.cancelado,
        noShow: a.status == DemoAppointmentStatus.falta,
        concluded: a.status == DemoAppointmentStatus.concluido,
        recordFinished: c != null && !c.isDraft,
        recordDraft: c != null && c.isDraft,
        now: _now,
      );
      if (outcome != null && k.outcome != outcome) continue;
      out.add(
        DemoDiaryEntry(
          appointment: a,
          patient: p,
          classification: k,
          consultation: c,
        ),
      );
    }
    out.sort(
      (DemoDiaryEntry a, DemoDiaryEntry b) =>
          b.appointment.start.compareTo(a.appointment.start),
    );
    return out;
  }

  Map<VisitOutcome, int> diaryCounts({
    DiaryPeriod period = DiaryPeriod.semana,
    String? patientId,
  }) {
    final Map<VisitOutcome, int> out = <VisitOutcome, int>{
      for (final VisitOutcome o in VisitOutcome.values) o: 0,
    };
    for (final DemoDiaryEntry e in diary(
      period: period,
      patientId: patientId,
    )) {
      out[e.classification.outcome] = out[e.classification.outcome]! + 1;
    }
    return out;
  }

  // ------------------------------------------------------------ Histórico

  List<TimelineEvent> timelineFor(
    String patientId, {
    Set<TimelineKind> only = const <TimelineKind>{},
  }) {
    if (!s.canSeeClinicalRecord || s.patientById(patientId) == null) {
      return const <TimelineEvent>[];
    }
    final String base = '/pacientes/$patientId';
    final List<TimelineEvent> events = <TimelineEvent>[];
    for (final DemoConsultation c in s.consultationsFor(patientId)) {
      final String first = c.isWellChild
          ? (c.wellChild!.summary.split('\n').first)
          : c.complaint;
      events.add(
        TimelineEvent(
          at: c.startedAt,
          kind: TimelineKind.consulta,
          title: c.isWellChild ? 'Consulta de puericultura' : 'Consulta',
          detail: first.trim().isEmpty ? null : first.trim(),
          route: '$base/consulta/${c.id}/resumo',
          author: c.author,
          draft: c.isDraft,
        ),
      );
      if (c.isWellChild && c.wellChild!.guidance.trim().isNotEmpty) {
        events.add(
          TimelineEvent(
            at: c.updatedAt,
            kind: TimelineKind.orientacao,
            title: 'Orientações da puericultura',
            detail: c.wellChild!.guidance.trim(),
            route: '$base/consulta/${c.id}/resumo',
            author: c.author,
          ),
        );
      }
    }
    for (final DemoEncounter e in s.encounters) {
      if (e.patientId != patientId || e.consultationId != null) continue;
      events.add(
        TimelineEvent(
          at: e.date,
          kind: TimelineKind.evolucao,
          title: e.type,
          detail: e.summary,
          route: '$base/prontuario',
          author: DemoProfessional.byId(e.professionalId).name,
        ),
      );
    }
    for (final ClinicalDocRecord d in s.documentsFor(patientId)) {
      events.add(
        TimelineEvent(
          at: d.current.updatedAt,
          kind: TimelineKind.forDocument(d.kind.slug),
          title: d.kind.label,
          detail: '${d.title} - ${d.status.label} (versão ${d.current.number})',
          route: '$base/documentos/${d.id}',
          author: d.current.author,
          draft: d.status == DocStatus.draft,
        ),
      );
    }
    for (final LabResult r in s.labsFor(patientId)) {
      events.add(
        TimelineEvent(
          at: r.values.collectedAt ?? r.recordedAt,
          kind: TimelineKind.exame,
          title: 'Exame: ${r.values.testName}',
          detail: r.status.label,
          route: '$base/exames',
          author: r.author,
        ),
      );
    }
    for (final GrowthMeasurement m in s.growthFor(patientId)) {
      if (m.voided) continue;
      events.add(
        TimelineEvent(
          at: m.values.date,
          kind: TimelineKind.crescimento,
          title: 'Medidas de crescimento',
          detail: m.values.summary(),
          route: '$base/crescimento',
          author: m.author,
        ),
      );
    }
    for (final (_, PreVisit v) in s.sentPreVisitsFor(patientId)) {
      final int files = v.sentAttachments.length;
      events.add(
        TimelineEvent(
          at: v.sentAt!,
          kind: TimelineKind.preConsulta,
          title: 'Pré-consulta enviada pela família',
          detail: <String>[
            if ((v.sentAnswers?.reason ?? '').trim().isNotEmpty)
              v.sentAnswers!.reason.trim(),
            if (files > 0) '$files anexo(s)',
          ].join(' - '),
          route: '$base/pre-consulta',
          author: 'Família',
        ),
      );
    }
    for (final DemoAppointment a in s.appointments) {
      if (a.patientId != patientId) continue;
      if (a.status != DemoAppointmentStatus.falta &&
          a.status != DemoAppointmentStatus.cancelado) {
        continue;
      }
      events.add(
        TimelineEvent(
          at: a.start,
          kind: TimelineKind.agenda,
          title: a.status == DemoAppointmentStatus.falta
              ? 'Falta'
              : 'Consulta cancelada',
          detail: a.reason,
          route: canOpenAppointment(a) ? '/agenda/${a.id}' : null,
        ),
      );
    }
    return buildTimeline(events, only: only);
  }

  // ------------------------------------------------------------ Resumo

  PreVisit? preVisitFor(DemoConsultation c) {
    if (c.appointmentId == null || !s.canReviewPreVisits) return null;
    final PreVisit? v = s.preVisits[c.appointmentId!];
    return v != null && v.isSent ? v : null;
  }

  Map<SummarySection, String> _sectionsOf(DemoConsultation c) =>
      <SummarySection, String>{
        SummarySection.queixa: c.complaint,
        SummarySection.anamnese: c.history,
        SummarySection.exameFisico: c.physicalExam,
        SummarySection.avaliacao: c.assessment,
        SummarySection.conduta: c.plan,
        SummarySection.retorno: c.returnPlan,
      };

  OrganizedDraft organize(DemoConsultation c, {String transcript = ''}) {
    if (!isProfessional) throw StateError('Só o profissional organiza.');
    if (!c.isDraft || c.isWellChild) {
      throw StateError('Só consultas em rascunho são organizadas.');
    }
    final PreVisitAnswers? pv = preVisitFor(c)?.sentAnswers;
    final OrganizedDraft d = organizeConsultation(
      OrganizerInput(
        current: _sectionsOf(c),
        preVisitReason: pv?.reason ?? '',
        preVisitSymptoms: pv?.symptoms ?? '',
        preVisitMedications: pv?.medications ?? '',
        preVisitNotes: pv?.notes ?? '',
        transcript: transcript,
      ),
      now: _now,
      createdBy: s.currentAuthor,
    );
    drafts[c.id] = d;
    log(
      AuditEntity.rascunhoAssistente,
      c.id,
      'Rascunho organizado pelo assistente (aguardando revisão)',
      patientId: c.patientId,
      detail: d.suggestions.isEmpty
          ? 'Sem sugestões'
          : 'Seções: ${d.suggestions.keys.map((SummarySection x) => x.label).join(', ')}',
    );
    s.changed();
    return d;
  }

  /// Só com a confirmação de revisão; nunca sobrescreve o que já foi escrito.
  void applyDraft(DemoConsultation c, {required bool reviewed}) {
    final OrganizedDraft? d = drafts[c.id];
    if (d == null || d.status != DraftStatus.pendente) {
      throw StateError('Não há rascunho aguardando revisão.');
    }
    if (!reviewed) throw StateError('Confirme que revisou o rascunho.');
    if (!c.isDraft) throw StateError('A consulta já foi finalizada.');
    for (final MapEntry<SummarySection, String> e in d.suggestions.entries) {
      switch (e.key) {
        case SummarySection.queixa:
          if (c.complaint.trim().isEmpty) c.complaint = e.value;
        case SummarySection.anamnese:
          if (c.history.trim().isEmpty) c.history = e.value;
        case SummarySection.exameFisico:
          if (c.physicalExam.trim().isEmpty) c.physicalExam = e.value;
        case SummarySection.conduta:
          if (c.plan.trim().isEmpty) c.plan = e.value;
        case SummarySection.retorno:
          if (c.returnPlan.trim().isEmpty) c.returnPlan = e.value;
        case SummarySection.avaliacao:
          break;
      }
    }
    d
      ..status = DraftStatus.aplicado
      ..reviewedAt = _now
      ..reviewedBy = s.currentAuthor;
    log(
      AuditEntity.rascunhoAssistente,
      c.id,
      'Rascunho do assistente revisado e aplicado',
      patientId: c.patientId,
    );
    s.saveConsultation(c);
  }

  void discardDraft(DemoConsultation c) {
    final OrganizedDraft? d = drafts[c.id];
    if (d == null || d.status != DraftStatus.pendente) return;
    d
      ..status = DraftStatus.descartado
      ..reviewedAt = _now
      ..reviewedBy = s.currentAuthor;
    log(
      AuditEntity.rascunhoAssistente,
      c.id,
      'Rascunho do assistente descartado',
      patientId: c.patientId,
    );
    s.changed();
  }

  void addAddendum(DemoConsultation c, String text) {
    if (!isProfessional) throw StateError('Só o profissional complementa.');
    if (c.isDraft) throw StateError('Edite o rascunho diretamente.');
    if (text.trim().isEmpty) throw StateError('Escreva o complemento.');
    c.addenda.add(
      ConsultationAddendum(
        at: _now,
        author: s.currentAuthor,
        text: text.trim(),
      ),
    );
    log(
      AuditEntity.consulta,
      c.id,
      'Adendo registrado',
      patientId: c.patientId,
    );
    s.changed();
  }
}
