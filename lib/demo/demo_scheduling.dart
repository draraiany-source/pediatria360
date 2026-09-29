import '../shared/scheduling/agenda_conflicts.dart';
import '../shared/previsit/pre_visit.dart';
import '../shared/scheduling/assistant_text.dart' show AssistantIntent;
import '../shared/scheduling/booking_assistant.dart';
import '../shared/scheduling/follow_up.dart';
import '../shared/scheduling/reminders.dart';
import '../shared/scheduling/slots.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_session.dart';

/// Unidade (clínica) da demonstração e seus profissionais.
class DemoUnit {
  const DemoUnit(this.id, this.name, this.professionalIds);

  final String id;
  final String name;
  final List<String> professionalIds;
}

class DemoContactAttempt {
  const DemoContactAttempt({
    required this.patientId,
    required this.at,
    required this.channel,
    required this.outcome,
    required this.by,
    this.note = '',
  });

  final String patientId;
  final DateTime at;
  final ContactChannel channel;
  final String outcome;
  final String by;
  final String note;
}

enum DemoAlertKind {
  falhaEnvio('Falha no envio do lembrete'),
  semConsentimento('Sem autorização para lembretes'),
  preferenciaManual('Prefere outro canal de contato'),
  reagendamento('Pediu reagendamento'),
  cancelamentoForaDoPrazo('Pediu cancelamento fora do prazo'),
  cancelado('Cancelou - horário liberado'),
  assistente('Encaminhado pelo assistente');

  const DemoAlertKind(this.label);

  final String label;
}

/// Pendência da recepção (contato manual).
class DemoReceptionAlert {
  DemoReceptionAlert({
    required this.id,
    required this.kind,
    required this.text,
    required this.at,
    this.patientId,
    this.appointmentId,
  });

  final String id;
  final DemoAlertKind kind;
  final String text;
  final DateTime at;
  final String? patientId;
  final String? appointmentId;
  DateTime? resolvedAt;
  String? resolution;

  bool get open => resolvedAt == null;
}

/// Resultado de uma rodada do agendador de lembretes.
class DemoReminderRun {
  const DemoReminderRun({
    required this.sent,
    required this.failed,
    required this.blocked,
  });

  final int sent;
  final int failed;
  final int blocked;

  int get total => sent + failed + blocked;
}

/// Simulador do WhatsApp Business Platform (Cloud API oficial da Meta).
///
/// Na demonstração nada sai do navegador: o simulador devolve o mesmo
/// formato de resposta e de eventos de status que a API real. No app real o
/// envio fica em `functions/src/whatsapp.ts`, desligado até haver
/// credenciais e autorização.
class DemoWhatsAppSimulator {
  DemoWhatsAppSimulator();

  static const String provider =
      'WhatsApp Business Platform - Cloud API (Meta)';
  static const String templateName = 'lembrete_consulta_v1';

  /// Número fictício "sem WhatsApp": o envio falha como na API real
  /// (erro 131026, destinatário não alcançável).
  static const Set<String> unreachable = <String>{'5511900000003'};

  int _seq = 1;

  ({bool ok, String? messageId, String? error}) sendTemplate(String e164) {
    if (unreachable.contains(e164)) {
      return (
        ok: false,
        messageId: null,
        error: 'Número sem WhatsApp (erro 131026 simulado).',
      );
    }
    return (ok: true, messageId: 'wamid.demo${_seq++}', error: null);
  }
}

/// Acompanhamento, lembretes e agendamento na demonstração (só memória).
class DemoScheduling {
  DemoScheduling(this.s) {
    reset();
  }

  final DemoSession s;
  final DemoWhatsAppSimulator whatsApp = DemoWhatsAppSimulator();

  late FollowUpCriteria criteria;
  late ReminderSettings reminderSettings;
  SchedulingPolicy policy = const SchedulingPolicy();
  late Map<String, GuardianContact> contacts;
  late Map<String, (DateTime, String)> recommendedReturns;
  late List<DemoContactAttempt> attempts;
  late List<ReminderRecord> reminders;
  late Map<String, Set<int>> handledOffsets;
  late List<DemoReceptionAlert> alerts;
  late Map<String, List<ReminderEvent>> history;

  /// Resposta automática enviada à família depois do toque no botão.
  late Map<String, String> replyAnswers;
  late List<ScheduleBlock> blocks;
  late Map<String, WorkingHours> hours;

  /// Conversa em andamento da família (sobrevive à ida à pré-consulta).
  BookingAssistant? familyAssistant;

  static final List<DemoUnit> units = <DemoUnit>[
    const DemoUnit('clinica-a', DemoProfessional.clinic, <String>['prof-a']),
    DemoUnit('clinica-b', DemoProfessional.colleague.clinic, <String>[
      DemoProfessional.colleague.id,
    ]),
  ];

  static DemoUnit unitOf(String professionalId) => units.firstWhere(
    (DemoUnit u) => u.professionalIds.contains(professionalId),
  );

  static String professionalName(String id) => DemoProfessional.byId(id).name;

  void reset() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    criteria = const FollowUpCriteria();
    reminderSettings = const ReminderSettings();
    policy = const SchedulingPolicy();
    familyAssistant = null;
    contacts = <String, GuardianContact>{
      'Responsável Exemplo A': _contact('A', '+55 11 90000-0001', now),
      'Responsável Exemplo B': _contact('B', '+55 11 90000-0002', now),
      'Responsável Exemplo C': _contact('C', '+55 11 90000-0003', now),
      'Responsável Exemplo D': _contact(
        'D',
        '+55 11 90000-0004',
        now,
        preferred: ContactChannel.telefone,
      ),
      'Responsável Exemplo E': _contact(
        'E',
        '+55 11 90000-0005',
        now,
        consent: false,
      ),
      'Responsável Exemplo F': _contact('F', '+55 21 90000-0006', now),
      'Responsável Exemplo G': _contact('G', '+55 21 90000-0007', now),
    };
    recommendedReturns = <String, (DateTime, String)>{
      'p1': (today.add(const Duration(days: 20)), 'prof-a'),
      'p2': (today.add(const Duration(days: 7)), 'prof-a'),
      'p3': (today.add(const Duration(days: 12)), 'prof-a'),
      'p8': (today.subtract(const Duration(days: 5)), 'prof-b'),
    };
    attempts = <DemoContactAttempt>[
      DemoContactAttempt(
        patientId: 'p6',
        at: today.subtract(const Duration(days: 20)),
        channel: ContactChannel.telefone,
        outcome: 'Não atendeu',
        by: 'Recepção',
      ),
      DemoContactAttempt(
        patientId: 'p6',
        at: today.subtract(const Duration(days: 9)),
        channel: ContactChannel.telefone,
        outcome: 'Pediu para ligar depois',
        by: 'Recepção',
      ),
      DemoContactAttempt(
        patientId: 'p8',
        at: today.subtract(const Duration(days: 3)),
        channel: ContactChannel.whatsapp,
        outcome: 'Sem resposta',
        by: 'Recepção',
      ),
    ];
    hours = <String, WorkingHours>{
      'prof-a': const WorkingHours(<int, List<WorkingRange>>{
        1: _fullDay,
        2: _fullDay,
        3: _fullDay,
        4: _fullDay,
        5: _fullDay,
      }),
      'prof-b': const WorkingHours(<int, List<WorkingRange>>{
        1: _afternoon,
        2: _afternoon,
        3: _afternoon,
        4: _afternoon,
        5: <WorkingRange>[WorkingRange(8 * 60, 12 * 60)],
      }),
    };
    final DateTime blockDay = today.add(const Duration(days: 2));
    blocks = <ScheduleBlock>[
      ScheduleBlock(
        id: 'blk1',
        startsAt: blockDay.add(const Duration(hours: 8)),
        endsAt: blockDay.add(const Duration(hours: 12)),
        professionalId: 'prof-a',
        reason: 'Reunião clínica (exemplo)',
      ),
    ];
    reminders = <ReminderRecord>[];
    handledOffsets = <String, Set<int>>{};
    alerts = <DemoReceptionAlert>[];
    history = <String, List<ReminderEvent>>{};
    replyAnswers = <String, String>{};
    _seedReminders(now);
  }

  static const List<WorkingRange> _fullDay = <WorkingRange>[
    WorkingRange(8 * 60, 12 * 60),
    WorkingRange(14 * 60, 18 * 60),
  ];

  static const List<WorkingRange> _afternoon = <WorkingRange>[
    WorkingRange(13 * 60, 19 * 60),
  ];

  GuardianContact _contact(
    String letter,
    String phone,
    DateTime now, {
    ContactChannel preferred = ContactChannel.whatsapp,
    bool consent = true,
  }) => GuardianContact(
    name: 'Responsável Exemplo $letter',
    phone: phone,
    preferred: preferred,
    reminderConsent: consent,
    consentAt: consent ? now.subtract(const Duration(days: 60)) : null,
  );

  /// Histórico coerente com a agenda de hoje: um lembrete respondido, um
  /// aguardando resposta, uma falha e um bloqueado pela preferência.
  void _seedReminders(DateTime now) {
    DemoAppointment? byId(String id) {
      for (final DemoAppointment a in s.appointments) {
        if (a.id == id) return a;
      }
      return null;
    }

    final DemoAppointment? a2 = byId('a2');
    final DemoAppointment? a3 = byId('a3');
    final DemoAppointment? a4 = byId('a4');
    final DemoAppointment? a5 = byId('a5');
    if (a2 != null) {
      final ReminderRecord r = _dispatch(a2, 24, at: _before(a2, 24))!;
      r
        ..deliveredAt = r.sentAt!.add(const Duration(seconds: 4))
        ..readAt = r.sentAt!.add(const Duration(minutes: 12))
        ..status = ReminderStatus.respondido
        ..reply = ReminderReply.confirmar
        ..repliedAt = r.sentAt!.add(const Duration(minutes: 13));
      r.events.addAll(<ReminderEvent>[
        ReminderEvent(r.deliveredAt!, 'Entregue'),
        ReminderEvent(r.readAt!, 'Lido'),
        ReminderEvent(r.repliedAt!, 'Resposta: Confirmar'),
      ]);
      _log(a2.id, r.repliedAt!, 'Confirmado pela família (WhatsApp)');
      handledOffsets[a2.id] = <int>{48, 24};
    }
    if (a3 != null) {
      _dispatch(a3, 24, at: _before(a3, 24));
      handledOffsets[a3.id] = <int>{48, 24};
    }
    if (a4 != null) {
      final ReminderRecord r = _dispatch(a4, 24, at: _before(a4, 24))!;
      r
        ..deliveredAt = r.sentAt!.add(const Duration(seconds: 3))
        ..status = ReminderStatus.entregue;
      r.events.add(ReminderEvent(r.deliveredAt!, 'Entregue'));
      handledOffsets[a4.id] = <int>{48, 24};
    }
    if (a5 != null) {
      _dispatch(a5, 48, at: _before(a5, 48));
      handledOffsets[a5.id] = <int>{48};
    }
  }

  DateTime _before(DemoAppointment a, int hours) =>
      a.start.subtract(Duration(hours: hours));

  // ------------------------------------------------------------ Perfis

  DemoProfile? get _profile => s.profile;

  bool get canSeeFollowUp =>
      _profile == DemoProfile.profissional ||
      _profile == DemoProfile.recepcao ||
      _profile == DemoProfile.administrador;

  bool get canEditClinicSettings => _profile == DemoProfile.administrador;

  bool get canSeeReminders => canSeeFollowUp;

  /// Recepção e administração processam envios, registram contato e
  /// resolvem pendências. O profissional só consulta.
  bool get canOperate =>
      _profile == DemoProfile.recepcao || _profile == DemoProfile.administrador;

  bool get canManageAgenda => _profile == DemoProfile.recepcao;

  bool get isFamily => _profile == DemoProfile.responsavel;

  /// O profissional vê só os próprios pacientes no painel.
  String? get lockedProfessionalId =>
      _profile == DemoProfile.profissional ? s.account.id : null;

  String get _actor => switch (_profile) {
    DemoProfile.recepcao => 'Recepção',
    DemoProfile.administrador => 'Administração',
    DemoProfile.profissional => s.account.name,
    DemoProfile.responsavel => 'Família',
    _ => 'Sistema',
  };

  // ------------------------------------------------------------ Acompanhamento

  List<String> _scope({String? professionalId, String? unitId}) {
    final String? locked = lockedProfessionalId;
    if (locked != null) return <String>[locked];
    if (professionalId != null) return <String>[professionalId];
    if (unitId != null) {
      return units.firstWhere((DemoUnit u) => u.id == unitId).professionalIds;
    }
    return <String>[for (final DemoUnit u in units) ...u.professionalIds];
  }

  /// Pacientes com vínculo no escopo, já classificados.
  List<(DemoPatient, FollowUpStatus)> followUp({
    String? professionalId,
    String? unitId,
    int? periodMonths,
  }) {
    if (!canSeeFollowUp) return const <(DemoPatient, FollowUpStatus)>[];
    final List<String> scope = _scope(
      professionalId: professionalId,
      unitId: unitId,
    );
    final DateTime now = s.now;
    final List<(DemoPatient, FollowUpStatus)> out =
        <(DemoPatient, FollowUpStatus)>[];
    for (final DemoPatient p in s.patients) {
      final List<DateTime> visits = <DateTime>[
        for (final DemoEncounter e in s.encounters)
          if (e.patientId == p.id && scope.contains(e.professionalId)) e.date,
        for (final DemoConsultation c in s.consultations)
          if (c.patientId == p.id &&
              c.status == DemoConsultationStatus.finished &&
              scope.contains(c.ownerId ?? DemoProfessional.id))
            c.startedAt,
        for (final DemoAppointment a in s.appointments)
          if (a.patientId == p.id &&
              a.status == DemoAppointmentStatus.concluido &&
              scope.contains(a.professionalId))
            a.start,
      ];
      final List<DemoAppointment> future =
          s.appointments
              .where(
                (DemoAppointment a) =>
                    a.patientId == p.id &&
                    a.status.holdsSlot &&
                    a.status != DemoAppointmentStatus.concluido &&
                    scope.contains(a.professionalId) &&
                    a.start.isAfter(now),
              )
              .toList()
            ..sort(
              (DemoAppointment a, DemoAppointment b) =>
                  a.start.compareTo(b.start),
            );
      final (DateTime, String)? ret = recommendedReturns[p.id];
      final DateTime? recommended = ret != null && scope.contains(ret.$2)
          ? ret.$1
          : null;
      if (visits.isEmpty && future.isEmpty && recommended == null) continue;
      out.add((
        p,
        classifyFollowUp(
          FollowUpInput(
            patientId: p.id,
            visits: visits,
            nextAppointment: future.isEmpty ? null : future.first.start,
            recommendedReturn: recommended,
            contactAttempts: attemptsFor(p.id).length,
          ),
          criteria,
          now: now,
          periodMonths: periodMonths,
        ),
      ));
    }
    return out;
  }

  List<DemoContactAttempt> attemptsFor(String patientId) =>
      attempts
          .where((DemoContactAttempt a) => a.patientId == patientId)
          .toList()
        ..sort(
          (DemoContactAttempt a, DemoContactAttempt b) => b.at.compareTo(a.at),
        );

  void setCriteria(FollowUpCriteria next) {
    if (!canEditClinicSettings) {
      throw StateError('Só a administração da clínica altera os critérios.');
    }
    final String? error = next.validate();
    if (error != null) throw StateError(error);
    criteria = next;
    s.changed();
  }

  void addContactAttempt(
    String patientId, {
    required ContactChannel channel,
    required String outcome,
    String note = '',
  }) {
    if (!canOperate) {
      throw StateError('Só recepção e administração registram contato.');
    }
    attempts.add(
      DemoContactAttempt(
        patientId: patientId,
        at: s.now,
        channel: channel,
        outcome: outcome,
        by: _actor,
        note: note.trim(),
      ),
    );
    s.changed();
  }

  // ------------------------------------------------------------ Lembretes

  GuardianContact? contactForPatient(String patientId) {
    for (final DemoPatient p in s.patients) {
      if (p.id == patientId) return contacts[p.guardianName];
    }
    return null;
  }

  /// Contato do responsável da demonstração (área da família).
  GuardianContact get familyContact => contacts[DemoSession.guardianOfDemo]!;

  void setFamilyContact({bool? consent, ContactChannel? preferred}) {
    if (!isFamily) throw StateError('Só o responsável altera a preferência.');
    final GuardianContact c = familyContact;
    if (consent != null && consent != c.reminderConsent) {
      c
        ..reminderConsent = consent
        ..consentAt = consent ? s.now : null;
    }
    if (preferred != null) c.preferred = preferred;
    s.changed();
  }

  void setReminderSettings(ReminderSettings next) {
    if (!canEditClinicSettings) {
      throw StateError('Só a administração da clínica altera os intervalos.');
    }
    final String? error = next.validate();
    if (error != null) throw StateError(error);
    reminderSettings = next;
    s.changed();
  }

  List<ReminderRecord> remindersFor(String appointmentId) =>
      reminders
          .where((ReminderRecord r) => r.appointmentId == appointmentId)
          .toList()
        ..sort(
          (ReminderRecord a, ReminderRecord b) =>
              b.createdAt.compareTo(a.createdAt),
        );

  List<ReminderRecord> get reminderLog => List<ReminderRecord>.of(reminders)
    ..sort(
      (ReminderRecord a, ReminderRecord b) =>
          b.createdAt.compareTo(a.createdAt),
    );

  ReminderRecord? _dispatch(DemoAppointment a, int offset, {DateTime? at}) {
    final DateTime t = at ?? s.now;
    DemoPatient? patient;
    for (final DemoPatient p in s.patients) {
      if (p.id == a.patientId) patient = p;
    }
    if (patient == null) return null;
    final GuardianContact? c = contacts[patient.guardianName];
    if (c == null) return null;
    final String text = reminderText(
      guardianFirstName: c.firstName,
      childFirstName: patient.name.split(' ').first,
      clinicName: unitOf(a.professionalId).name,
      start: a.start,
      teleconsulta: a.kind == DemoAppointmentKind.teleconsulta,
    );
    final ReminderRecord r = ReminderRecord(
      id: s.newId('r'),
      appointmentId: a.id,
      patientId: patient.id,
      offsetHours: offset,
      recipientName: c.name,
      recipientMasked: maskPhone(c.phone),
      channel: ContactChannel.whatsapp,
      text: text,
      status: ReminderStatus.naoEnviado,
      createdAt: t,
    );
    reminders.add(r);
    final ReminderBlock block = whatsAppEligibility(c);
    if (block != ReminderBlock.none) {
      r.failureReason = blockReason(block, c);
      r.events.add(ReminderEvent(t, 'Não enviado: ${r.failureReason}'));
      _alert(
        block == ReminderBlock.noConsent
            ? DemoAlertKind.semConsentimento
            : block == ReminderBlock.preferenceNotWhatsApp
            ? DemoAlertKind.preferenciaManual
            : DemoAlertKind.falhaEnvio,
        'Confirmar a consulta de ${patient.name} '
        '(${reminderWhen(a.start)}) por contato manual. ${r.failureReason}',
        patientId: patient.id,
        appointmentId: a.id,
        at: t,
      );
      return r;
    }
    final ({bool ok, String? messageId, String? error}) res = whatsApp
        .sendTemplate(normalizePhone(c.phone)!);
    if (!res.ok) {
      r
        ..status = ReminderStatus.falhou
        ..failureReason = res.error;
      r.events.add(ReminderEvent(t, 'Falhou: ${res.error}'));
      _alert(
        DemoAlertKind.falhaEnvio,
        'O lembrete de ${patient.name} (${reminderWhen(a.start)}) não foi '
        'entregue. Fazer contato manual. ${res.error}',
        patientId: patient.id,
        appointmentId: a.id,
        at: t,
      );
      return r;
    }
    r
      ..status = ReminderStatus.enviado
      ..providerMessageId = res.messageId
      ..sentAt = t;
    r.events.add(ReminderEvent(t, 'Enviado (${offsetLabel(offset)})'));
    return r;
  }

  /// Uma rodada do agendador (no app real, uma função agendada).
  DemoReminderRun processReminders() {
    if (!canOperate) {
      throw StateError('Só recepção e administração disparam os envios.');
    }
    final DateTime now = s.now;
    int sent = 0, failed = 0, blocked = 0;
    if (!reminderSettings.enabled) {
      return const DemoReminderRun(sent: 0, failed: 0, blocked: 0);
    }
    for (final DemoAppointment a in s.appointments) {
      if (a.status != DemoAppointmentStatus.agendado &&
          a.status != DemoAppointmentStatus.confirmado) {
        continue;
      }
      final Set<int> handled = handledOffsets.putIfAbsent(a.id, () => <int>{});
      final int? due = dueReminderOffset(
        appointmentStart: a.start,
        offsetsHours: reminderSettings.offsetsHours,
        alreadyHandled: handled,
        now: now,
      );
      if (due == null) continue;
      handled
        ..addAll(
          skippedOffsets(
            appointmentStart: a.start,
            offsetsHours: reminderSettings.offsetsHours,
            alreadyHandled: handled,
            sending: due,
            now: now,
          ),
        )
        ..add(due);
      final ReminderRecord? r = _dispatch(a, due);
      if (r == null) continue;
      switch (r.status) {
        case ReminderStatus.enviado:
          sent++;
          // Webhook "delivered" simulado.
          r
            ..status = ReminderStatus.entregue
            ..deliveredAt = now;
          r.events.add(ReminderEvent(now, 'Entregue'));
        case ReminderStatus.falhou:
          failed++;
        default:
          blocked++;
      }
    }
    s.changed();
    return DemoReminderRun(sent: sent, failed: failed, blocked: blocked);
  }

  /// Mensagens que chegaram ao WhatsApp da família (crianças visíveis).
  List<ReminderRecord> familyMessages() {
    if (!isFamily) return const <ReminderRecord>[];
    final Set<String> kids = <String>{
      for (final DemoPatient p in s.visiblePatients) p.id,
    };
    return reminders
        .where(
          (ReminderRecord r) =>
              kids.contains(r.patientId) &&
              r.sentAt != null &&
              r.status != ReminderStatus.falhou,
        )
        .toList()
      ..sort(
        (ReminderRecord a, ReminderRecord b) =>
            a.createdAt.compareTo(b.createdAt),
      );
  }

  int get unreadFamilyMessages =>
      familyMessages().where((ReminderRecord r) => r.readAt == null).length;

  /// Webhook "read" simulado quando a família abre a conversa.
  void markFamilyMessagesRead() {
    bool changed = false;
    for (final ReminderRecord r in familyMessages()) {
      if (r.readAt != null) continue;
      r.readAt = s.now;
      if (r.status == ReminderStatus.entregue ||
          r.status == ReminderStatus.enviado) {
        r.status = ReminderStatus.lido;
      }
      r.events.add(ReminderEvent(s.now, 'Lido'));
      changed = true;
    }
    if (changed) s.changed();
  }

  /// Toque num botão do lembrete (webhook de resposta).
  String replyToReminder(String reminderId, ReminderReply reply) {
    if (!isFamily) throw StateError('Só o responsável responde ao lembrete.');
    final ReminderRecord r = familyMessages().firstWhere(
      (ReminderRecord x) => x.id == reminderId,
      orElse: () => throw StateError('Mensagem não encontrada.'),
    );
    if (!r.awaitingReply) throw StateError('Este lembrete já foi respondido.');
    final DemoAppointment? a = s.appointmentById(r.appointmentId);
    if (a == null || !a.status.holdsSlot) {
      throw StateError('Esta consulta não está mais marcada.');
    }
    final DateTime now = s.now;
    r
      ..reply = reply
      ..repliedAt = now
      ..status = ReminderStatus.respondido
      ..readAt ??= now;
    r.events.add(ReminderEvent(now, 'Resposta: ${reply.label}'));
    final String child = _patientName(a.patientId);
    String answer;
    switch (reply) {
      case ReminderReply.confirmar:
        if (a.status == DemoAppointmentStatus.agendado ||
            a.status == DemoAppointmentStatus.reagendar) {
          a.status = DemoAppointmentStatus.confirmado;
        }
        _log(a.id, now, 'Confirmado pela família (WhatsApp)');
        answer = 'Presença confirmada. Obrigado!';
      case ReminderReply.reagendar:
        a.status = DemoAppointmentStatus.reagendar;
        _log(a.id, now, 'Família pediu reagendamento (WhatsApp)');
        _alert(
          DemoAlertKind.reagendamento,
          '$child pediu outro horário para ${reminderWhen(a.start)}.',
          patientId: a.patientId,
          appointmentId: a.id,
          at: now,
        );
        answer = policy.canSelfReschedule(a.start, now)
            ? 'Pedido registrado. Escolha um novo horário no assistente de '
                  'agendamento ou aguarde o contato da recepção.'
            : 'Pedido registrado. A recepção vai entrar em contato para '
                  'combinar o novo horário.';
      case ReminderReply.cancelar:
        if (policy.canSelfCancel(a.start, now)) {
          a.status = DemoAppointmentStatus.cancelado;
          _log(a.id, now, 'Cancelado pela família (WhatsApp)');
          _alert(
            DemoAlertKind.cancelado,
            '$child cancelou ${reminderWhen(a.start)}. Horário liberado.',
            patientId: a.patientId,
            appointmentId: a.id,
            at: now,
          );
          answer = 'Consulta cancelada. Se precisar, marque de novo pelo app.';
        } else {
          _log(a.id, now, 'Família pediu cancelamento fora do prazo');
          _alert(
            DemoAlertKind.cancelamentoForaDoPrazo,
            '$child pediu para cancelar ${reminderWhen(a.start)} com menos de '
            '${policy.selfCancelUntilHours} h. Ligar para a família.',
            patientId: a.patientId,
            appointmentId: a.id,
            at: now,
          );
          answer =
              'Pedido registrado. Como falta pouco para a consulta, a '
              'recepção vai confirmar o cancelamento com você.';
        }
    }
    replyAnswers[r.id] = answer;
    s.changed();
    return answer;
  }

  // ------------------------------------------------------------ Recepção

  List<DemoReceptionAlert> get openAlerts =>
      alerts.where((DemoReceptionAlert a) => a.open).toList()..sort(
        (DemoReceptionAlert a, DemoReceptionAlert b) => b.at.compareTo(a.at),
      );

  void _alert(
    DemoAlertKind kind,
    String text, {
    String? patientId,
    String? appointmentId,
    DateTime? at,
  }) {
    alerts.add(
      DemoReceptionAlert(
        id: s.newId('al'),
        kind: kind,
        text: text,
        at: at ?? s.now,
        patientId: patientId,
        appointmentId: appointmentId,
      ),
    );
  }

  void resolveAlert(String alertId, {required String resolution}) {
    if (!canOperate) {
      throw StateError('Só recepção e administração resolvem pendências.');
    }
    final DemoReceptionAlert a = alerts.firstWhere(
      (DemoReceptionAlert x) => x.id == alertId,
    );
    a
      ..resolvedAt = s.now
      ..resolution = resolution;
    if (a.patientId != null) {
      attempts.add(
        DemoContactAttempt(
          patientId: a.patientId!,
          at: s.now,
          channel: ContactChannel.telefone,
          outcome: resolution,
          by: _actor,
          note: a.kind.label,
        ),
      );
    }
    s.changed();
  }

  // ------------------------------------------------------------ Agenda

  List<ReminderEvent> historyFor(String appointmentId) =>
      List<ReminderEvent>.of(history[appointmentId] ?? const <ReminderEvent>[])
        ..sort((ReminderEvent a, ReminderEvent b) => b.at.compareTo(a.at));

  void _log(String appointmentId, DateTime at, String text) => history
      .putIfAbsent(appointmentId, () => <ReminderEvent>[])
      .add(ReminderEvent(at, text));

  String _patientName(String id) {
    for (final DemoPatient p in s.patients) {
      if (p.id == id) return p.name;
    }
    return 'Paciente';
  }

  List<BookedInterval> get _booked => <BookedInterval>[
    for (final DemoAppointment a in s.appointments)
      BookedInterval(
        id: a.id,
        startsAt: a.start,
        durationMinutes: a.durationMinutes,
        professionalId: a.professionalId,
        patientId: a.patientId,
        status: a.status.holdsSlot ? 'confirmed' : 'cancelled',
      ),
  ];

  List<DateTime> findSlots(SlotQuery query, {int limit = 4}) {
    final WorkingHours? h = hours[query.professionalId];
    if (h == null) return const <DateTime>[];
    return availableSlots(
      query: query,
      hours: h,
      existing: _booked,
      blocks: blocks,
      policy: policy,
      now: s.now,
      limit: limit,
    );
  }

  String? _problem(
    DateTime start,
    int duration,
    String professionalId, {
    String? patientId,
    String? ignore,
  }) {
    final WorkingHours? h = hours[professionalId];
    if (h == null) return 'Profissional sem agenda configurada.';
    return slotProblem(
      start: start,
      durationMinutes: duration,
      professionalId: professionalId,
      hours: h,
      existing: _booked,
      blocks: blocks,
      policy: policy,
      now: s.now,
      patientId: patientId,
      ignoreAppointmentId: ignore,
    );
  }

  bool _familyOwns(String patientId) =>
      isFamily && s.patientById(patientId) != null;

  DemoAppointment book({
    required String patientId,
    required String professionalId,
    required DateTime start,
    required int durationMinutes,
    required bool teleconsulta,
    required VisitType type,
    required String reason,
  }) {
    if (!(canManageAgenda || _familyOwns(patientId))) {
      throw const BookingException(
        'Sem permissão para agendar para esta criança.',
      );
    }
    final String? problem = _problem(
      start,
      durationMinutes,
      professionalId,
      patientId: patientId,
    );
    if (problem != null) throw BookingException(problem, slotTaken: true);
    final DemoAppointment a = DemoAppointment(
      id: s.newId('a'),
      patientId: patientId,
      start: start,
      kind: teleconsulta
          ? DemoAppointmentKind.teleconsulta
          : DemoAppointmentKind.presencial,
      status: DemoAppointmentStatus.agendado,
      reason: type.label,
      professionalId: professionalId,
      durationMinutes: durationMinutes,
      typeLabel: type.label,
    );
    s.appointments = <DemoAppointment>[...s.appointments, a];
    _log(
      a.id,
      s.now,
      isFamily
          ? 'Agendado pela família (assistente)'
          : 'Agendado pela recepção',
    );
    if (isFamily && reason.trim().isNotEmpty) {
      s.preVisits[a.id] = PreVisit(appointmentId: a.id, patientId: patientId)
        ..answers = PreVisitAnswers(reason: reason.trim());
    }
    s.changed();
    return a;
  }

  void reschedule(String appointmentId, DateTime start) {
    final DemoAppointment? a = s.appointmentById(appointmentId);
    if (a == null || !a.status.holdsSlot) {
      throw const BookingException('Consulta não encontrada.');
    }
    final bool family = _familyOwns(a.patientId);
    if (!(canManageAgenda || family)) {
      throw const BookingException('Sem permissão para remarcar.');
    }
    if (family && !policy.canSelfReschedule(a.start, s.now)) {
      throw BookingException(
        'Remarcações com menos de ${policy.selfRescheduleUntilHours} h são '
        'feitas pela recepção.',
      );
    }
    final String? problem = _problem(
      start,
      a.durationMinutes,
      a.professionalId,
      patientId: a.patientId,
      ignore: a.id,
    );
    if (problem != null) throw BookingException(problem, slotTaken: true);
    final DateTime old = a.start;
    a
      ..start = start
      ..status = DemoAppointmentStatus.agendado;
    handledOffsets.remove(a.id);
    for (final DemoReceptionAlert al in alerts) {
      if (al.appointmentId == a.id &&
          al.open &&
          al.kind == DemoAlertKind.reagendamento) {
        al
          ..resolvedAt = s.now
          ..resolution = 'Remarcado para ${reminderWhen(start)}';
      }
    }
    _log(
      a.id,
      s.now,
      'Remarcado por ${family ? 'família (assistente)' : 'recepção'}: '
      '${reminderWhen(old)} para ${reminderWhen(start)}',
    );
    s.changed();
  }

  void cancel(String appointmentId) {
    final DemoAppointment? a = s.appointmentById(appointmentId);
    if (a == null || !a.status.holdsSlot) {
      throw const BookingException('Consulta não encontrada.');
    }
    final bool family = _familyOwns(a.patientId);
    if (!(canManageAgenda || family)) {
      throw const BookingException('Sem permissão para cancelar.');
    }
    if (family && !policy.canSelfCancel(a.start, s.now)) {
      throw BookingException(
        'Cancelamentos com menos de ${policy.selfCancelUntilHours} h são '
        'feitos pela recepção.',
      );
    }
    a.status = DemoAppointmentStatus.cancelado;
    _log(
      a.id,
      s.now,
      'Cancelado por ${family ? 'família (assistente)' : 'recepção'}',
    );
    if (family) {
      _alert(
        DemoAlertKind.cancelado,
        '${_patientName(a.patientId)} cancelou ${reminderWhen(a.start)} pelo '
        'assistente. Horário liberado.',
        patientId: a.patientId,
        appointmentId: a.id,
      );
    }
    s.changed();
  }

  void handoff(String summary) {
    _alert(DemoAlertKind.assistente, summary);
    s.changed();
  }

  DemoProfile? _assistantProfile;

  /// Conversa em andamento (família ou recepção); `restart` descarta a atual
  /// e a troca de perfil começa outra.
  BookingAssistant assistantFor({
    AssistantIntent? intent,
    String? appointmentId,
    bool restart = false,
  }) {
    if (restart ||
        intent != null ||
        familyAssistant == null ||
        _assistantProfile != s.profile) {
      _assistantProfile = s.profile;
      familyAssistant = BookingAssistant(
        DemoAssistantBackend(this),
        startWith: intent,
        appointmentId: appointmentId,
      );
    }
    return familyAssistant!;
  }
}

/// Liga o motor de conversa às regras e dados da demonstração.
class DemoAssistantBackend implements SchedulingBackend {
  DemoAssistantBackend(this.store);

  final DemoScheduling store;

  DemoSession get _s => store.s;

  @override
  DateTime get now => _s.now;

  /// Os prazos de autoatendimento valem para a família; a recepção remarca
  /// e cancela a qualquer momento.
  @override
  SchedulingPolicy get policy => store.canManageAgenda
      ? SchedulingPolicy(
          minLeadHours: store.policy.minLeadHours,
          maxDaysAhead: store.policy.maxDaysAhead,
          selfRescheduleUntilHours: 0,
          selfCancelUntilHours: 0,
          slotStepMinutes: store.policy.slotStepMinutes,
        )
      : store.policy;

  @override
  List<AssistantChild> children() => <AssistantChild>[
    for (final DemoPatient p in _s.visiblePatients)
      AssistantChild(id: p.id, name: p.name, ageMonths: _months(p.birthDate)),
  ];

  int _months(DateTime birth) {
    final DateTime n = now;
    int m = (n.year - birth.year) * 12 + n.month - birth.month;
    if (n.day < birth.day) m--;
    return m;
  }

  @override
  List<AssistantProfessional> professionals() => <AssistantProfessional>[
    for (final DemoAccount a in DemoProfessional.accounts)
      AssistantProfessional(id: a.id, name: a.name, clinic: a.clinic),
  ];

  @override
  List<AssistantAppointment> upcoming() {
    final DateTime t = now;
    final List<AssistantAppointment> out = <AssistantAppointment>[];
    for (final DemoPatient p in _s.visiblePatients) {
      for (final DemoAppointment a in _s.appointments) {
        if (a.patientId != p.id ||
            !a.status.holdsSlot ||
            a.status == DemoAppointmentStatus.concluido ||
            a.status == DemoAppointmentStatus.chegou ||
            !a.start.isAfter(t)) {
          continue;
        }
        out.add(
          AssistantAppointment(
            id: a.id,
            childId: p.id,
            childName: p.name,
            professionalId: a.professionalId,
            professionalName: DemoScheduling.professionalName(a.professionalId),
            start: a.start,
            durationMinutes: a.durationMinutes,
            teleconsulta: a.kind == DemoAppointmentKind.teleconsulta,
          ),
        );
      }
    }
    out.sort(
      (AssistantAppointment a, AssistantAppointment b) =>
          a.start.compareTo(b.start),
    );
    return out;
  }

  @override
  List<DateTime> findSlots(SlotQuery query, {int limit = 4}) =>
      store.findSlots(query, limit: limit);

  @override
  String book(BookingDraft d) => store
      .book(
        patientId: d.childId,
        professionalId: d.professionalId,
        start: d.start,
        durationMinutes: d.durationMinutes,
        teleconsulta: d.teleconsulta,
        type: d.type,
        reason: d.reason,
      )
      .id;

  @override
  void reschedule(String appointmentId, DateTime start) =>
      store.reschedule(appointmentId, start);

  @override
  void cancel(String appointmentId) => store.cancel(appointmentId);

  @override
  void handoff(String summary) => store.handoff(summary);
}
