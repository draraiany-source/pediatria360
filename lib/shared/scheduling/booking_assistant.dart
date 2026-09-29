/// Conversa de agendamento assistido.
///
/// O motor conduz a conversa e só chama as operações do [SchedulingBackend]
/// — consultar horários, gravar, reagendar, cancelar, encaminhar. Nada é
/// gravado sem a confirmação explícita do responsável, e quem valida
/// permissão, conflito e bloqueio é sempre o backend.
library;

import 'assistant_text.dart';
import 'reminders.dart' show reminderWhen;
import 'slots.dart';

class AssistantChild {
  const AssistantChild({
    required this.id,
    required this.name,
    required this.ageMonths,
  });

  final String id;
  final String name;
  final int ageMonths;

  String get firstName => name.split(' ').first;
}

class AssistantProfessional {
  const AssistantProfessional({
    required this.id,
    required this.name,
    required this.clinic,
  });

  final String id;
  final String name;
  final String clinic;
}

class AssistantAppointment {
  const AssistantAppointment({
    required this.id,
    required this.childId,
    required this.childName,
    required this.professionalId,
    required this.professionalName,
    required this.start,
    required this.durationMinutes,
    required this.teleconsulta,
  });

  final String id;
  final String childId;
  final String childName;
  final String professionalId;
  final String professionalName;
  final DateTime start;
  final int durationMinutes;
  final bool teleconsulta;

  String get label => '${childName.split(' ').first} - ${reminderWhen(start)}';
}

class BookingDraft {
  const BookingDraft({
    required this.childId,
    required this.reason,
    required this.type,
    required this.teleconsulta,
    required this.professionalId,
    required this.start,
    required this.durationMinutes,
  });

  final String childId;
  final String reason;
  final VisitType type;
  final bool teleconsulta;
  final String professionalId;
  final DateTime start;
  final int durationMinutes;
}

/// Erro de negócio devolvido pelo backend (mensagem pronta para a família).
class BookingException implements Exception {
  const BookingException(this.message, {this.slotTaken = false});

  final String message;

  /// O horário foi ocupado entre a oferta e a confirmação.
  final bool slotTaken;

  @override
  String toString() => message;
}

abstract class SchedulingBackend {
  DateTime get now;
  SchedulingPolicy get policy;
  List<AssistantChild> children();
  List<AssistantProfessional> professionals();
  List<AssistantAppointment> upcoming();
  List<DateTime> findSlots(SlotQuery query, {int limit});

  /// Grava e devolve o id do agendamento.
  String book(BookingDraft draft);
  void reschedule(String appointmentId, DateTime start);
  void cancel(String appointmentId);

  /// Encaminha à recepção com um resumo do que já foi dito.
  void handoff(String summary);
}

enum AssistantCardKind {
  urgency,
  summary,
  booked,
  rescheduled,
  cancelled,
  handoff,
}

class AssistantCard {
  const AssistantCard({
    required this.kind,
    required this.title,
    this.lines = const <String>[],
    this.appointmentId,
  });

  final AssistantCardKind kind;
  final String title;
  final List<String> lines;
  final String? appointmentId;
}

class AssistantMessage {
  const AssistantMessage({
    required this.fromUser,
    required this.text,
    this.options = const <String>[],
    this.card,
  });

  final bool fromUser;
  final String text;
  final List<String> options;
  final AssistantCard? card;
}

enum _Step {
  menu,
  child,
  reason,
  type,
  modality,
  professional,
  availability,
  slot,
  confirm,
  pickReschedule,
  pickCancel,
  cancelConfirm,
  done,
}

class BookingAssistant {
  BookingAssistant(
    this.backend, {
    AssistantIntent? startWith,
    String? appointmentId,
  }) {
    _say(
      'Olá! Sou o assistente de agendamento. Posso marcar, remarcar ou '
      'cancelar consultas e mostro só horários realmente livres. Nada é '
      'gravado sem a sua confirmação. Se a criança estiver com sinais de '
      'gravidade, procure um pronto-socorro ou ligue 192.',
    );
    if (startWith == AssistantIntent.remarcar ||
        startWith == AssistantIntent.cancelar) {
      final AssistantAppointment? a = _appointment(appointmentId);
      if (a != null) {
        _startChange(startWith!, a);
      } else {
        _pickAppointment(startWith!);
      }
      return;
    }
    if (startWith == AssistantIntent.agendar) {
      _next();
      return;
    }
    _menu();
  }

  final SchedulingBackend backend;
  final List<AssistantMessage> messages = <AssistantMessage>[];

  static const String optBook = 'Agendar consulta';
  static const String optReschedule = 'Remarcar consulta';
  static const String optCancel = 'Cancelar consulta';
  static const String optReception = 'Falar com a recepção';
  static const String optAnyProfessional = 'Sem preferência';
  static const String optPresencial = 'Presencial';
  static const String optTele = 'Teleconsulta';
  static const String optMoreSlots = 'Outros horários';
  static const String optChangePeriod = 'Mudar período';
  static const String optConfirmBooking = 'Confirmar agendamento';
  static const String optConfirmReschedule = 'Confirmar remarcação';
  static const String optOtherSlot = 'Escolher outro horário';
  static const String optGiveUp = 'Desistir';
  static const String optConfirmCancel = 'Sim, cancelar a consulta';
  static const String optKeep = 'Manter a consulta';
  static const String optRestart = 'Recomeçar';
  static const String optNextWeek = 'Próxima semana';

  _Step _step = _Step.menu;
  int _misses = 0;

  AssistantChild? _child;
  String? _reason;
  VisitType? _type;
  bool? _tele;
  AssistantProfessional? _professional;
  bool _anyProfessional = false;
  DayPart? _dayPart;
  Set<int> _weekdays = <int>{};
  DateTime? _searchFrom;

  /// Rótulo da opção → (profissional, início).
  final Map<String, (AssistantProfessional, DateTime)> _offered =
      <String, (AssistantProfessional, DateTime)>{};
  (AssistantProfessional, DateTime)? _chosen;
  AssistantAppointment? _changing;

  /// Id gravado por último (para abrir a pré-consulta).
  String? bookedAppointmentId;

  List<String> get options => messages.isEmpty || messages.last.fromUser
      ? const <String>[]
      : messages.last.options;

  bool get finished => _step == _Step.done;

  // ------------------------------------------------------------ Saída

  void _say(
    String text, {
    List<String> options = const <String>[],
    AssistantCard? card,
  }) => messages.add(
    AssistantMessage(fromUser: false, text: text, options: options, card: card),
  );

  void _menu() {
    _step = _Step.menu;
    _say(
      'Como posso ajudar?',
      options: const <String>[optBook, optReschedule, optCancel, optReception],
    );
  }

  // ------------------------------------------------------------ Entrada

  void send(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return;
    messages.add(AssistantMessage(fromUser: true, text: text));
    final bool picked = _lastOptions.contains(text);

    if (!picked) {
      final UrgencyCheck u = checkUrgency(text, ageInMonths: _child?.ageMonths);
      if (u.urgent) {
        _urgent();
        return;
      }
    }
    if (text == optReception ||
        (!picked && detectIntent(text) == AssistantIntent.recepcao)) {
      _handoff('Pedido de atendimento pela recepção.');
      return;
    }
    if (text == optRestart) {
      _resetDraft();
      _menu();
      return;
    }
    switch (_step) {
      case _Step.menu:
      case _Step.done:
        _onMenu(text);
      case _Step.child:
        _absorb(text);
        _child == null ? _miss('Para qual criança?', _childOptions) : _next();
      case _Step.reason:
        _reason = text;
        _absorb(text, includeChild: false);
        _next();
      case _Step.type:
        final VisitType? t =
            VisitType.fromLabel(text) ??
            detectVisitType(text) ??
            _typeFromOption(text);
        if (t == null) {
          _miss('Qual tipo de consulta?', _typeOptions);
        } else {
          _type = t;
          _next();
        }
      case _Step.modality:
        final bool? tele = text == optTele
            ? true
            : text == optPresencial
            ? false
            : detectTele(text);
        if (tele == null) {
          _miss('Prefere presencial ou teleconsulta?', const <String>[
            optPresencial,
            optTele,
          ]);
        } else {
          _tele = tele;
          _next();
        }
      case _Step.professional:
        if (text == optAnyProfessional ||
            RegExp(
              r'qualquer|tanto faz|sem prefer',
            ).hasMatch(normalizeText(text))) {
          _anyProfessional = true;
          _next();
          return;
        }
        final AssistantProfessional? p = _professionalFrom(text);
        if (p == null) {
          _miss('Com qual profissional?', _professionalOptions);
        } else {
          _professional = p;
          _next();
        }
      case _Step.availability:
        _searchFrom = null;
        if (!_absorbAvailability(text)) {
          _miss(
            'Qual período fica melhor? Pode dizer também o dia da semana.',
            _availabilityOptions,
          );
        } else {
          _showSlots();
        }
      case _Step.slot:
        _onSlot(text);
      case _Step.confirm:
        _onConfirm(text);
      case _Step.pickReschedule:
      case _Step.pickCancel:
        final AssistantAppointment? a = _appointmentFromLabel(text);
        if (a == null) {
          _miss('Qual consulta?', _appointmentOptions);
        } else {
          _startChange(
            _step == _Step.pickCancel
                ? AssistantIntent.cancelar
                : AssistantIntent.remarcar,
            a,
          );
        }
      case _Step.cancelConfirm:
        _onCancelConfirm(text);
    }
  }

  List<String> get _lastOptions {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].fromUser) return messages[i].options;
    }
    return const <String>[];
  }

  void _miss(String question, List<String> options) {
    _misses++;
    if (_misses >= 2) {
      _say(
        'Não consegui entender. $question Se preferir, a recepção continua '
        'o atendimento com você.',
        options: <String>[...options, optReception],
      );
    } else {
      _say('Não entendi. $question', options: options);
    }
  }

  void _onMenu(String text) {
    final AssistantIntent? intent = switch (text) {
      optBook => AssistantIntent.agendar,
      optReschedule => AssistantIntent.remarcar,
      optCancel => AssistantIntent.cancelar,
      _ => detectIntent(text),
    };
    switch (intent) {
      case AssistantIntent.agendar:
        _resetDraft();
        _absorb(text);
        _next();
      case AssistantIntent.remarcar:
      case AssistantIntent.cancelar:
        _resetDraft();
        _pickAppointment(intent!);
      case AssistantIntent.recepcao:
        _handoff('Pedido de atendimento pela recepção.');
      case null:
        _miss('Você quer agendar, remarcar ou cancelar?', const <String>[
          optBook,
          optReschedule,
          optCancel,
        ]);
    }
  }

  void _resetDraft() {
    _child = null;
    _reason = null;
    _type = null;
    _tele = null;
    _professional = null;
    _anyProfessional = false;
    _dayPart = null;
    _weekdays = <int>{};
    _searchFrom = null;
    _offered.clear();
    _chosen = null;
    _changing = null;
    _misses = 0;
  }

  /// Aproveita tudo o que a família já disse na mesma frase.
  void _absorb(String text, {bool includeChild = true}) {
    final List<AssistantChild> kids = backend.children();
    if (includeChild && _child == null) {
      if (kids.length == 1) {
        _child = kids.single;
      } else {
        final String? name = matchOption(text, _childOptions);
        if (name != null) {
          _child = kids.firstWhere((AssistantChild c) => c.name == name);
        }
      }
    }
    _type ??= detectVisitType(text);
    _tele ??= detectTele(text);
    if (_professional == null && !_anyProfessional) {
      _professional = _professionalFrom(text);
    }
    _absorbAvailability(text);
  }

  bool _absorbAvailability(String text) {
    final DayPart? part = detectDayPart(text) ?? _dayPartFromOption(text);
    final Set<int> days = detectWeekdays(text);
    final bool nextWeek = text == optNextWeek || mentionsNextWeek(text);
    if (part != null) _dayPart = part;
    if (days.isNotEmpty) _weekdays = days;
    if (nextWeek) {
      final DateTime n = backend.now;
      _searchFrom = DateTime(n.year, n.month, n.day + (8 - n.weekday));
      _dayPart ??= DayPart.qualquer;
    }
    return part != null || days.isNotEmpty || nextWeek;
  }

  DayPart? _dayPartFromOption(String text) {
    for (final DayPart p in DayPart.values) {
      if (p.label == text) return p;
    }
    return null;
  }

  VisitType? _typeFromOption(String text) {
    final String? label = matchOption(text, _typeOptions);
    return label == null ? null : VisitType.fromLabel(label);
  }

  AssistantProfessional? _professionalFrom(String text) {
    final List<AssistantProfessional> all = backend.professionals();
    final String? name = matchOption(text, <String>[
      for (final AssistantProfessional p in all) p.name,
    ]);
    if (name == null) return null;
    return all.firstWhere((AssistantProfessional p) => p.name == name);
  }

  List<String> get _childOptions => <String>[
    for (final AssistantChild c in backend.children()) c.name,
  ];

  List<String> get _typeOptions => <String>[
    for (final VisitType t in VisitType.values) t.label,
  ];

  List<String> get _professionalOptions => <String>[
    for (final AssistantProfessional p in backend.professionals()) p.name,
    optAnyProfessional,
  ];

  List<String> get _availabilityOptions => <String>[
    for (final DayPart p in DayPart.values) p.label,
    optNextWeek,
  ];

  /// Pergunta o próximo dado que falta, na ordem da conversa.
  void _next() {
    _misses = 0;
    if (_child == null) {
      final List<AssistantChild> kids = backend.children();
      if (kids.isEmpty) {
        _handoff('Responsável sem criança vinculada no cadastro.');
        return;
      }
      _step = _Step.child;
      _say('Para qual criança é a consulta?', options: _childOptions);
      return;
    }
    if (_reason == null) {
      _step = _Step.reason;
      _say(
        'Conte em poucas palavras o motivo da consulta de '
        '${_child!.firstName}. Não precisa detalhar sintomas: isso fica '
        'para a pré-consulta.',
      );
      return;
    }
    if (_type == null) {
      _step = _Step.type;
      _say('Qual tipo de consulta?', options: _typeOptions);
      return;
    }
    if (!_type!.allowsTele && _tele != false) {
      final bool askedTele = _tele == true;
      _tele = false;
      _say(
        askedTele
            ? '${_type!.label} precisa de exame físico, então é só '
                  'presencial.'
            : '${_type!.label} é presencial.',
      );
    }
    if (_tele == null) {
      _step = _Step.modality;
      _say(
        'Prefere presencial ou teleconsulta?',
        options: const <String>[optPresencial, optTele],
      );
      return;
    }
    if (_professional == null && !_anyProfessional) {
      _step = _Step.professional;
      _say('Tem preferência de profissional?', options: _professionalOptions);
      return;
    }
    if (_dayPart == null && _weekdays.isEmpty) {
      _step = _Step.availability;
      _say(
        'Qual período fica melhor? Pode dizer também o dia da semana '
        '(por exemplo, "terça de manhã").',
        options: _availabilityOptions,
      );
      return;
    }
    _showSlots();
  }

  int get _duration => _changing != null
      ? _changing!.durationMinutes
      : _type!.durationMinutes(teleconsulta: _tele!);

  void _showSlots() {
    _step = _Step.slot;
    _offered.clear();
    final DateTime from = _searchFrom ?? backend.now;
    final List<AssistantProfessional> pros = _changing != null
        ? backend
              .professionals()
              .where(
                (AssistantProfessional p) => p.id == _changing!.professionalId,
              )
              .toList()
        : _anyProfessional
        ? backend.professionals()
        : <AssistantProfessional>[_professional!];
    final List<(AssistantProfessional, DateTime)> found =
        <(AssistantProfessional, DateTime)>[];
    for (final AssistantProfessional p in pros) {
      for (final DateTime t in backend.findSlots(
        SlotQuery(
          professionalId: p.id,
          durationMinutes: _duration,
          from: from,
          dayPart: _dayPart ?? DayPart.qualquer,
          weekdays: _weekdays,
          patientId: _changing?.childId ?? _child?.id,
          ignoreAppointmentId: _changing?.id,
        ),
        limit: 4,
      )) {
        found.add((p, t));
      }
    }
    found.sort(
      (
        (AssistantProfessional, DateTime) a,
        (AssistantProfessional, DateTime) b,
      ) => a.$2.compareTo(b.$2),
    );
    final List<(AssistantProfessional, DateTime)> top = found.take(4).toList();
    if (top.isEmpty) {
      _say(
        'Não encontrei horário livre nesse período nas próximas duas '
        'semanas. Quer tentar outro período ou falar com a recepção?',
        options: <String>[..._availabilityOptions, optReception],
      );
      _step = _Step.availability;
      return;
    }
    for (final (AssistantProfessional p, DateTime t) in top) {
      final String label = pros.length > 1
          ? '${reminderWhen(t)} - ${p.name}'
          : reminderWhen(t);
      _offered[label] = (p, t);
    }
    _say(
      'Estes horários estão livres agora ($_duration min):',
      options: <String>[..._offered.keys, optMoreSlots, optChangePeriod],
    );
  }

  void _onSlot(String text) {
    if (text == optMoreSlots) {
      final DateTime last = _offered.values
          .map(((AssistantProfessional, DateTime) e) => e.$2)
          .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
      _searchFrom = last.add(const Duration(minutes: 1));
      _showSlots();
      return;
    }
    if (text == optChangePeriod) {
      _dayPart = null;
      _weekdays = <int>{};
      _searchFrom = null;
      _step = _Step.availability;
      _say('Qual período fica melhor?', options: _availabilityOptions);
      return;
    }
    final String? label = _offered.containsKey(text)
        ? text
        : matchOption(text, _offered.keys.toList());
    if (label == null) {
      final DateTime? previous = _searchFrom;
      _searchFrom = null;
      if (_absorbAvailability(text)) {
        _showSlots();
        return;
      }
      _searchFrom = previous;
      _miss('Escolha um dos horários.', <String>[
        ..._offered.keys,
        optMoreSlots,
        optChangePeriod,
      ]);
      return;
    }
    _chosen = _offered[label];
    _step = _Step.confirm;
    _misses = 0;
    final (AssistantProfessional p, DateTime t) = _chosen!;
    if (_changing != null) {
      _say(
        'Confira a remarcação:',
        card: AssistantCard(
          kind: AssistantCardKind.summary,
          title:
              'Remarcar consulta de ${_changing!.childName.split(' ').first}',
          lines: <String>[
            'De: ${reminderWhen(_changing!.start)}',
            'Para: ${reminderWhen(t)}',
            'Profissional: ${p.name}',
          ],
        ),
        options: const <String>[optConfirmReschedule, optOtherSlot, optGiveUp],
      );
      return;
    }
    _say(
      'Confira antes de confirmar. Só depois da sua confirmação o horário é '
      'reservado.',
      card: AssistantCard(
        kind: AssistantCardKind.summary,
        title: 'Resumo do agendamento',
        lines: <String>[
          'Criança: ${_child!.name}',
          'Motivo: ${_reason!}',
          'Tipo: ${_type!.label} ($_duration min)',
          'Modalidade: ${_tele! ? optTele : optPresencial}',
          'Profissional: ${p.name} - ${p.clinic}',
          'Quando: ${reminderWhen(t)}',
        ],
      ),
      options: const <String>[optConfirmBooking, optOtherSlot, optGiveUp],
    );
  }

  void _onConfirm(String text) {
    final bool yes =
        text == optConfirmBooking ||
        text == optConfirmReschedule ||
        (!_lastOptions.contains(text) && isAffirmative(text));
    if (text == optOtherSlot) {
      _showSlots();
      return;
    }
    if (text == optGiveUp || isNegative(text)) {
      _say('Tudo bem, nada foi gravado.');
      _resetDraft();
      _menu();
      return;
    }
    if (!yes) {
      _miss('Confirma este horário?', _lastOptions);
      return;
    }
    final (AssistantProfessional p, DateTime t) = _chosen!;
    try {
      if (_changing != null) {
        backend.reschedule(_changing!.id, t);
        final AssistantAppointment old = _changing!;
        _step = _Step.done;
        _say(
          'Pronto, consulta remarcada.',
          card: AssistantCard(
            kind: AssistantCardKind.rescheduled,
            title: 'Consulta remarcada',
            lines: <String>[
              '${old.childName}: ${reminderWhen(t)}',
              'Profissional: ${p.name}',
              'O horário anterior foi liberado.',
            ],
            appointmentId: old.id,
          ),
          options: const <String>[optBook, optRestart],
        );
        _resetDraft();
        return;
      }
      final String id = backend.book(
        BookingDraft(
          childId: _child!.id,
          reason: _reason!,
          type: _type!,
          teleconsulta: _tele!,
          professionalId: p.id,
          start: t,
          durationMinutes: _duration,
        ),
      );
      bookedAppointmentId = id;
      _step = _Step.done;
      _say(
        'Consulta agendada! Agora, se quiser, preencha a pré-consulta: '
        'dúvidas, queixas, fotos e exames para o profissional avaliar.',
        card: AssistantCard(
          kind: AssistantCardKind.booked,
          title: 'Consulta agendada',
          lines: <String>[
            '${_child!.name} - ${reminderWhen(t)}',
            '${_type!.label} - ${_tele! ? optTele : optPresencial}',
            '${p.name} - ${p.clinic}',
            'Você receberá lembretes conforme sua preferência de contato.',
          ],
          appointmentId: id,
        ),
        options: const <String>[optBook, optRestart],
      );
      _resetDraft();
    } on BookingException catch (e) {
      if (e.slotTaken) {
        _say('${e.message} Veja os horários livres agora:');
        _showSlots();
      } else {
        _handoff(e.message, explain: e.message);
      }
    }
  }

  // ------------------------------------------------ Remarcar e cancelar

  AssistantAppointment? _appointment(String? id) {
    if (id == null) return null;
    for (final AssistantAppointment a in backend.upcoming()) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<String> get _appointmentOptions => <String>[
    for (final AssistantAppointment a in backend.upcoming()) a.label,
  ];

  AssistantAppointment? _appointmentFromLabel(String text) {
    final String? label = _appointmentOptions.contains(text)
        ? text
        : matchOption(text, _appointmentOptions);
    if (label == null) return null;
    return backend.upcoming().firstWhere(
      (AssistantAppointment a) => a.label == label,
    );
  }

  void _pickAppointment(AssistantIntent intent) {
    final List<AssistantAppointment> list = backend.upcoming();
    if (list.isEmpty) {
      _say('Não há consultas futuras para as suas crianças.');
      _menu();
      return;
    }
    if (list.length == 1) {
      _startChange(intent, list.single);
      return;
    }
    _step = intent == AssistantIntent.cancelar
        ? _Step.pickCancel
        : _Step.pickReschedule;
    _say(
      intent == AssistantIntent.cancelar
          ? 'Qual consulta deseja cancelar?'
          : 'Qual consulta deseja remarcar?',
      options: _appointmentOptions,
    );
  }

  void _startChange(AssistantIntent intent, AssistantAppointment a) {
    _misses = 0;
    final SchedulingPolicy policy = backend.policy;
    if (intent == AssistantIntent.cancelar) {
      if (!policy.canSelfCancel(a.start, backend.now)) {
        _handoff(
          'Cancelamento com menos de ${policy.selfCancelUntilHours} h: ${a.label}.',
          explain:
              'Pelas regras da clínica, cancelamentos com menos de '
              '${policy.selfCancelUntilHours} horas de antecedência são feitos '
              'pela recepção.',
        );
        return;
      }
      _changing = a;
      _step = _Step.cancelConfirm;
      _say(
        'Confirma o cancelamento da consulta de ${a.label}, com '
        '${a.professionalName}?',
        options: const <String>[optConfirmCancel, optKeep],
      );
      return;
    }
    if (!policy.canSelfReschedule(a.start, backend.now)) {
      _handoff(
        'Remarcação com menos de ${policy.selfRescheduleUntilHours} h: ${a.label}.',
        explain:
            'Pelas regras da clínica, remarcações com menos de '
            '${policy.selfRescheduleUntilHours} horas de antecedência são '
            'feitas pela recepção.',
      );
      return;
    }
    _changing = a;
    _step = _Step.availability;
    _say(
      'Vamos remarcar a consulta de ${a.label} com ${a.professionalName}. '
      'Qual período fica melhor?',
      options: _availabilityOptions,
    );
  }

  void _onCancelConfirm(String text) {
    if (text == optKeep || isNegative(text)) {
      _say('Certo, a consulta continua marcada.');
      _resetDraft();
      _menu();
      return;
    }
    if (text != optConfirmCancel &&
        !(isAffirmative(text) && !_lastOptions.contains(text))) {
      _miss('Confirma o cancelamento?', const <String>[
        optConfirmCancel,
        optKeep,
      ]);
      return;
    }
    final AssistantAppointment a = _changing!;
    try {
      backend.cancel(a.id);
    } on BookingException catch (e) {
      _handoff(e.message, explain: e.message);
      return;
    }
    _step = _Step.done;
    _say(
      'Consulta cancelada e horário liberado.',
      card: AssistantCard(
        kind: AssistantCardKind.cancelled,
        title: 'Consulta cancelada',
        lines: <String>[a.label, a.professionalName],
        appointmentId: a.id,
      ),
      options: const <String>[optBook, optRestart],
    );
    _resetDraft();
  }

  // ------------------------------------------------ Encaminhamentos

  void _urgent() {
    _step = _Step.done;
    _say(
      urgencyGuidance,
      card: const AssistantCard(
        kind: AssistantCardKind.urgency,
        title: 'Possível urgência',
        lines: <String>[
          'Procure agora um pronto-socorro.',
          'Emergência: ligue 192 (SAMU).',
          'Não aguarde por consulta agendada.',
        ],
      ),
      options: const <String>[optReception, optRestart],
    );
    _resetDraft();
  }

  void _handoff(String reason, {String? explain}) {
    final List<String> parts = <String>[
      reason,
      if (_child != null) 'Criança: ${_child!.name}',
      if (_reason != null) 'Motivo informado: $_reason',
      if (_changing != null) 'Consulta: ${_changing!.label}',
    ];
    backend.handoff(parts.join(' | '));
    _step = _Step.done;
    _say(
      '${explain == null ? '' : '$explain '}Encaminhei sua conversa à '
      'recepção, que entrará em contato pelo seu canal preferido.',
      card: const AssistantCard(
        kind: AssistantCardKind.handoff,
        title: 'Encaminhado à recepção',
        lines: <String>['A recepção recebeu o resumo desta conversa.'],
      ),
      options: const <String>[optRestart],
    );
    _resetDraft();
  }
}
