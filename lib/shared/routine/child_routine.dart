/// Rotina da criança: compromissos do calendário e registros do diário.
///
/// Dart puro, sem Flutter. Consultas, vacinas e receitas continuam nos
/// próprios cadastros; aqui ficam só os compromissos criados pela família,
/// os horários programados das receitas e o diário.
library;

import '../clinical/lab_results.dart' show LabAttachment;

// ---------------------------------------------------------------------------
// Datas
// ---------------------------------------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

String routineDateKey(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime? parseRoutineDateKey(String? key) {
  if (key == null) return null;
  final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final DateTime d = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return routineDateKey(d) == key ? d : null;
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Segunda-feira da semana de [d].
DateTime weekStart(DateTime d) =>
    dayOf(d).subtract(Duration(days: d.weekday - 1));

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

String formatHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatDm(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

String formatDmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

const List<String> kWeekdayShort = <String>[
  'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom', //
];
const List<String> kWeekdayLong = <String>[
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const List<String> kMonthNames = <String>[
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String formatDayLong(DateTime d) =>
    '${kWeekdayLong[d.weekday - 1]}, ${d.day} de ${kMonthNames[d.month - 1]}';

/// "HH:MM" -> (hora, minuto).
({int hour, int minute})? parseHm(String text) {
  final RegExpMatch? m = RegExp(
    r'^\s*(\d{1,2})\s*[:h]\s*(\d{2})\s*$',
  ).firstMatch(text);
  if (m == null) return null;
  final int h = int.parse(m.group(1)!);
  final int min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return (hour: h, minute: min);
}

/// "dd/mm/aaaa" -> data.
DateTime? parseDmy(String text) {
  final RegExpMatch? m = RegExp(
    r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})\s*$',
  ).firstMatch(text);
  if (m == null) return null;
  final int d = int.parse(m.group(1)!);
  final int mo = int.parse(m.group(2)!);
  final int y = int.parse(m.group(3)!);
  final DateTime r = DateTime(y, mo, d);
  return r.day == d && r.month == mo && r.year == y ? r : null;
}

String formatMinutes(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '${h}h';
  return '${h}h${_two(m)}';
}

String formatDecimal(double v, {int digits = 1}) {
  String s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

double? parseDecimal(String text) {
  final String t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

// ---------------------------------------------------------------------------
// Receitas: leitura da posologia
// ---------------------------------------------------------------------------

/// Intervalo em horas a partir da frequência escrita na receita
/// ("de 8/8h", "1 vez ao dia (24/24h)", "a cada 6 horas", "2 vezes ao dia").
int? parseIntervalHours(String frequency) {
  final String f = frequency.toLowerCase();
  final RegExpMatch? slash = RegExp(r'(\d+)\s*/\s*(\d+)\s*h').firstMatch(f);
  if (slash != null) {
    final int h = int.parse(slash.group(2)!);
    return h > 0 && h <= 72 ? h : null;
  }
  final RegExpMatch? every = RegExp(
    r'a\s+cada\s+(\d+)\s*(h\b|hora)',
  ).firstMatch(f);
  if (every != null) {
    final int h = int.parse(every.group(1)!);
    return h > 0 && h <= 72 ? h : null;
  }
  final RegExpMatch? times = RegExp(
    r'(\d+|uma|duas|tr[eê]s|quatro)\s*vez(es)?\s*(ao|por)\s*dia',
  ).firstMatch(f);
  if (times != null) {
    const Map<String, int> words = <String, int>{
      'uma': 1,
      'duas': 2,
      'tres': 3,
      'três': 3,
      'quatro': 4,
    };
    final String g = times.group(1)!;
    final int n = int.tryParse(g) ?? words[g] ?? 0;
    if (n > 0 && 24 % n == 0) return 24 ~/ n;
  }
  return null;
}

/// Duração em dias ("5 dias", "2 semanas", "30 dias").
int? parseDurationDays(String duration) {
  final String d = duration.toLowerCase();
  final RegExpMatch? days = RegExp(r'(\d+)\s*dia').firstMatch(d);
  if (days != null) {
    final int n = int.parse(days.group(1)!);
    return n > 0 && n <= 365 ? n : null;
  }
  final RegExpMatch? weeks = RegExp(r'(\d+)\s*semana').firstMatch(d);
  if (weeks != null) {
    final int n = int.parse(weeks.group(1)!) * 7;
    return n > 0 && n <= 365 ? n : null;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Calendário
// ---------------------------------------------------------------------------

enum RoutineKind {
  consulta('Consulta'),
  retorno('Retorno'),
  vacina('Vacina'),
  medicamento('Medicamento'),
  atividade('Atividade'),
  lembrete('Lembrete');

  const RoutineKind(this.label);
  final String label;

  /// Tipos que a família pode criar diretamente no calendário.
  static const List<RoutineKind> familyCreatable = <RoutineKind>[
    atividade,
    lembrete,
    consulta,
    retorno,
    vacina,
  ];
}

enum RoutineStatus {
  planned('Planejado'),
  done('Realizado'),
  cancelled('Cancelado');

  const RoutineStatus(this.label);
  final String label;
}

/// De onde vem o item mostrado no calendário.
enum RoutineSource {
  familia('Família'),
  clinica('Clínica'),
  receita('Receita');

  const RoutineSource(this.label);
  final String label;
}

enum RoutineRepeat {
  none('Não repete'),
  daily('Todos os dias'),
  weekly('Toda semana');

  const RoutineRepeat(this.label);
  final String label;
}

/// Antecedências de lembrete oferecidas (minutos antes do horário).
const List<int> kReminderOptions = <int>[0, 10, 30, 60, 1440];

String reminderLabel(int minutes) => switch (minutes) {
  0 => 'No horário',
  1440 => '1 dia antes',
  60 => '1 hora antes',
  _ when minutes % 60 == 0 => '${minutes ~/ 60} horas antes',
  _ => '$minutes min antes',
};

/// Compromissos de dia inteiro lembram a partir deste horário.
const int kAllDayReminderHour = 8;

class RoutineChange {
  const RoutineChange({
    required this.at,
    required this.author,
    required this.action,
    this.detail = '',
  });

  final DateTime at;
  final String author;
  final String action;
  final String detail;
}

/// Situação de uma ocorrência (um dia de um compromisso que se repete, ou a
/// única ocorrência de um compromisso simples).
class OccurrenceState {
  const OccurrenceState({
    required this.status,
    required this.at,
    required this.author,
    this.note = '',
    this.diaryEntryId,
  });

  final RoutineStatus status;
  final DateTime at;
  final String author;
  final String note;
  final String? diaryEntryId;
}

class RoutineEvent {
  const RoutineEvent({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.title,
    required this.start,
    required this.author,
    required this.createdAt,
    this.allDay = false,
    this.durationMinutes,
    this.notes = '',
    this.repeat = RoutineRepeat.none,
    this.until,
    this.reminders = const <int>[],
    this.occurrences = const <String, OccurrenceState>{},
    this.history = const <RoutineChange>[],
    this.vaccineName,
    this.vaccineDose,
  });

  final String id;
  final String patientId;
  final RoutineKind kind;
  final String title;
  final DateTime start;
  final bool allDay;
  final int? durationMinutes;
  final String notes;
  final RoutineRepeat repeat;
  final DateTime? until;
  final List<int> reminders;
  final Map<String, OccurrenceState> occurrences;
  final String author;
  final DateTime createdAt;
  final List<RoutineChange> history;

  /// Liga o compromisso a uma vacina pendente da carteira, sem duplicá-la.
  final String? vaccineName;
  final String? vaccineDose;

  bool get repeats => repeat != RoutineRepeat.none;

  static const int maxOccurrences = 366;

  /// Início de cada ocorrência que cai em [from, to).
  List<DateTime> occurrencesBetween(DateTime from, DateTime to) {
    final List<DateTime> out = <DateTime>[];
    final int step = switch (repeat) {
      RoutineRepeat.none => 0,
      RoutineRepeat.daily => 1,
      RoutineRepeat.weekly => 7,
    };
    if (step == 0) {
      if (!start.isBefore(from) && start.isBefore(to)) out.add(start);
      return out;
    }
    final DateTime last = until == null
        ? to
        : DateTime(until!.year, until!.month, until!.day + 1);
    int skip = 0;
    if (from.isAfter(start)) {
      skip =
          (dayOf(from).difference(dayOf(start)).inHours / 24).floor() ~/ step;
      if (skip > 0) skip -= 1;
    }
    for (int i = skip; i < skip + maxOccurrences; i++) {
      final DateTime s = addDays(start, i * step);
      if (!s.isBefore(to) || !s.isBefore(last)) break;
      if (!s.isBefore(from)) out.add(s);
    }
    return out;
  }

  bool occursOn(DateTime day) =>
      occurrencesBetween(dayOf(day), addDays(dayOf(day), 1)).isNotEmpty;

  RoutineStatus statusOf(String key) =>
      occurrences[key]?.status ?? RoutineStatus.planned;

  RoutineEvent copyWith({
    RoutineKind? kind,
    String? title,
    DateTime? start,
    bool? allDay,
    int? Function()? durationMinutes,
    String? notes,
    RoutineRepeat? repeat,
    DateTime? Function()? until,
    List<int>? reminders,
    Map<String, OccurrenceState>? occurrences,
    List<RoutineChange>? history,
  }) {
    return RoutineEvent(
      id: id,
      patientId: patientId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      start: start ?? this.start,
      allDay: allDay ?? this.allDay,
      durationMinutes: durationMinutes != null
          ? durationMinutes()
          : this.durationMinutes,
      notes: notes ?? this.notes,
      repeat: repeat ?? this.repeat,
      until: until != null ? until() : this.until,
      reminders: reminders ?? this.reminders,
      occurrences: occurrences ?? this.occurrences,
      author: author,
      createdAt: createdAt,
      history: history ?? this.history,
      vaccineName: vaccineName,
      vaccineDose: vaccineDose,
    );
  }

  String get whenLabel {
    final String day = formatDmy(start);
    return allDay ? '$day (dia inteiro)' : '$day às ${formatHm(start)}';
  }

  /// Aplica uma edição e registra no histórico o que mudou.
  RoutineEvent edited(
    RoutineEvent next, {
    required String author,
    required DateTime at,
  }) {
    final List<String> changes = <String>[];
    if (next.kind != kind) {
      changes.add('tipo: ${kind.label} -> ${next.kind.label}');
    }
    if (next.title != title) changes.add('título: "$title" -> "${next.title}"');
    if (next.start != start || next.allDay != allDay) {
      changes.add('quando: $whenLabel -> ${next.whenLabel}');
    }
    if (next.durationMinutes != durationMinutes) changes.add('duração');
    if (next.repeat != repeat || next.until != until) {
      changes.add('repetição: ${repeat.label} -> ${next.repeat.label}');
    }
    if (!_sameInts(next.reminders, reminders)) {
      changes.add(
        'lembretes: ${next.reminders.isEmpty ? 'nenhum' : next.reminders.map(reminderLabel).join(', ')}',
      );
    }
    if (next.notes != notes) changes.add('observações');
    if (changes.isEmpty) return this;
    return next.copyWith(
      history: <RoutineChange>[
        ...history,
        RoutineChange(
          at: at,
          author: author,
          action: 'Editado',
          detail: changes.join('; '),
        ),
      ],
    );
  }

  RoutineEvent withStatus(
    String key,
    RoutineStatus status, {
    required String author,
    required DateTime at,
    String note = '',
    String? diaryEntryId,
  }) {
    final Map<String, OccurrenceState> occ = Map<String, OccurrenceState>.of(
      occurrences,
    );
    if (status == RoutineStatus.planned) {
      occ.remove(key);
    } else {
      occ[key] = OccurrenceState(
        status: status,
        at: at,
        author: author,
        note: note,
        diaryEntryId: diaryEntryId,
      );
    }
    final String action = switch (status) {
      RoutineStatus.done => 'Concluído',
      RoutineStatus.cancelled => 'Cancelado',
      RoutineStatus.planned => 'Reaberto',
    };
    final DateTime? day = parseRoutineDateKey(key);
    return copyWith(
      occurrences: occ,
      history: <RoutineChange>[
        ...history,
        RoutineChange(
          at: at,
          author: author,
          action: action,
          detail: <String>[
            if (repeats && day != null) 'ocorrência de ${formatDmy(day)}',
            if (note.trim().isNotEmpty) note.trim(),
          ].join(' - '),
        ),
      ],
    );
  }

  List<String> validate() {
    final List<String> e = <String>[];
    if (title.trim().isEmpty) e.add('Informe um título.');
    if (title.trim().length > 80) e.add('Use um título de até 80 caracteres.');
    if (durationMinutes != null &&
        (durationMinutes! <= 0 || durationMinutes! > 24 * 60)) {
      e.add('A duração deve ficar entre 1 minuto e 24 horas.');
    }
    if (repeats && until != null && dayOf(until!).isBefore(dayOf(start))) {
      e.add('A data final da repetição deve ser depois do início.');
    }
    if (reminders.any((int m) => m < 0)) e.add('Lembrete inválido.');
    return e;
  }
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  final List<int> x = List<int>.of(a)..sort();
  final List<int> y = List<int>.of(b)..sort();
  for (int i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

/// Horários de um item de receita emitida, programados pela família.
class MedicationPlan {
  const MedicationPlan({
    required this.id,
    required this.patientId,
    required this.docId,
    required this.itemIndex,
    required this.drug,
    required this.posology,
    required this.firstDose,
    required this.intervalHours,
    required this.days,
    required this.author,
    required this.createdAt,
    this.reminders = const <int>[0],
    this.doses = const <String, OccurrenceState>{},
    this.history = const <RoutineChange>[],
  });

  final String id;
  final String patientId;
  final String docId;
  final int itemIndex;
  final String drug;
  final String posology;
  final DateTime firstDose;
  final int intervalHours;
  final int days;
  final String author;
  final DateTime createdAt;
  final List<int> reminders;
  final Map<String, OccurrenceState> doses;
  final List<RoutineChange> history;

  static String doseKey(DateTime t) => '${routineDateKey(t)}T${formatHm(t)}';

  int get doseCount => (days * 24) ~/ intervalHours;

  DateTime get lastDose =>
      firstDose.add(Duration(hours: intervalHours * (doseCount - 1)));

  List<DateTime> doseTimes() => <DateTime>[
    for (int i = 0; i < doseCount; i++)
      firstDose.add(Duration(hours: intervalHours * i)),
  ];

  List<DateTime> dosesBetween(DateTime from, DateTime to) => doseTimes()
      .where((DateTime t) => !t.isBefore(from) && t.isBefore(to))
      .toList();

  RoutineStatus statusOf(String key) =>
      doses[key]?.status ?? RoutineStatus.planned;

  int get givenCount => doses.values
      .where((OccurrenceState s) => s.status == RoutineStatus.done)
      .length;

  MedicationPlan copyWith({
    DateTime? firstDose,
    int? intervalHours,
    int? days,
    List<int>? reminders,
    Map<String, OccurrenceState>? doses,
    List<RoutineChange>? history,
  }) {
    return MedicationPlan(
      id: id,
      patientId: patientId,
      docId: docId,
      itemIndex: itemIndex,
      drug: drug,
      posology: posology,
      firstDose: firstDose ?? this.firstDose,
      intervalHours: intervalHours ?? this.intervalHours,
      days: days ?? this.days,
      author: author,
      createdAt: createdAt,
      reminders: reminders ?? this.reminders,
      doses: doses ?? this.doses,
      history: history ?? this.history,
    );
  }

  MedicationPlan withDose(
    String key,
    RoutineStatus status, {
    required String author,
    required DateTime at,
    String note = '',
    String? diaryEntryId,
  }) {
    final Map<String, OccurrenceState> d = Map<String, OccurrenceState>.of(
      doses,
    );
    if (status == RoutineStatus.planned) {
      d.remove(key);
    } else {
      d[key] = OccurrenceState(
        status: status,
        at: at,
        author: author,
        note: note,
        diaryEntryId: diaryEntryId,
      );
    }
    return copyWith(
      doses: d,
      history: <RoutineChange>[
        ...history,
        RoutineChange(
          at: at,
          author: author,
          action: switch (status) {
            RoutineStatus.done => 'Dose administrada',
            RoutineStatus.cancelled => 'Dose não administrada',
            RoutineStatus.planned => 'Dose reaberta',
          },
          detail: <String>[
            'horário previsto ${key.replaceFirst('T', ' ')}',
            if (note.trim().isNotEmpty) note.trim(),
          ].join(' - '),
        ),
      ],
    );
  }

  List<String> validate() {
    final List<String> e = <String>[];
    if (intervalHours <= 0 || intervalHours > 72) {
      e.add('Informe o intervalo entre as doses em horas (1 a 72).');
    }
    if (days <= 0 || days > 365) e.add('Informe por quantos dias (1 a 365).');
    return e;
  }
}

/// Item já pronto para exibir no calendário, venha de onde vier.
class CalendarItem {
  const CalendarItem({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.title,
    required this.start,
    required this.status,
    required this.source,
    this.allDay = false,
    this.durationMinutes,
    this.detail = '',
    this.reminders = const <int>[],
    this.eventId,
    this.occurrenceKey,
    this.planId,
    this.doseKey,
    this.docId,
    this.appointmentId,
  });

  final String id;
  final String patientId;
  final RoutineKind kind;
  final String title;
  final DateTime start;
  final bool allDay;
  final int? durationMinutes;
  final RoutineStatus status;
  final RoutineSource source;
  final String detail;
  final List<int> reminders;
  final String? eventId;
  final String? occurrenceKey;
  final String? planId;
  final String? doseKey;
  final String? docId;
  final String? appointmentId;

  bool get isPlanned => status == RoutineStatus.planned;

  /// Compromissos da família e doses programadas mudam de situação no app;
  /// consultas e vacinas seguem o cadastro da clínica.
  bool get familyCanChangeStatus => eventId != null || planId != null;

  bool isOverdue(DateTime now) {
    if (!isPlanned) return false;
    final DateTime due = allDay ? addDays(dayOf(start), 1) : start;
    return due.isBefore(now);
  }

  String get timeLabel => allDay ? 'Dia inteiro' : formatHm(start);
}

int compareCalendarItems(CalendarItem a, CalendarItem b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final int c = a.start.compareTo(b.start);
  return c != 0 ? c : a.title.compareTo(b.title);
}

class DueReminder {
  const DueReminder({
    required this.item,
    required this.minutesBefore,
    required this.at,
  });

  final CalendarItem item;
  final int minutesBefore;
  final DateTime at;

  String get key => '${item.id}@$minutesBefore';
}

DateTime reminderTime(CalendarItem item, int minutesBefore) {
  final DateTime base = item.allDay
      ? DateTime(
          item.start.year,
          item.start.month,
          item.start.day,
          kAllDayReminderHour,
        )
      : item.start;
  return base.subtract(Duration(minutes: minutesBefore));
}

/// Lembretes de itens ainda planejados cujo horário de aviso já chegou,
/// dentro da janela [from, to].
List<DueReminder> dueReminders(
  Iterable<CalendarItem> items, {
  required DateTime from,
  required DateTime to,
  Set<String> dismissed = const <String>{},
}) {
  final List<DueReminder> out = <DueReminder>[];
  for (final CalendarItem item in items) {
    if (!item.isPlanned) continue;
    for (final int m in item.reminders) {
      final DateTime at = reminderTime(item, m);
      if (at.isAfter(to) || at.isBefore(from)) continue;
      final DueReminder r = DueReminder(item: item, minutesBefore: m, at: at);
      if (!dismissed.contains(r.key)) out.add(r);
    }
  }
  out.sort((DueReminder a, DueReminder b) => b.at.compareTo(a.at));
  final Set<String> seen = <String>{};
  return out.where((DueReminder r) => seen.add(r.item.id)).toList();
}

/// Próximo lembrete ainda por disparar, para mostrar "próximo aviso".
DueReminder? nextReminder(Iterable<CalendarItem> items, DateTime now) {
  DueReminder? best;
  for (final CalendarItem item in items) {
    if (!item.isPlanned) continue;
    for (final int m in item.reminders) {
      final DateTime at = reminderTime(item, m);
      if (!at.isAfter(now)) continue;
      if (best == null || at.isBefore(best.at)) {
        best = DueReminder(item: item, minutesBefore: m, at: at);
      }
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Diário
// ---------------------------------------------------------------------------

enum DiaryKind {
  mamada('Mamada'),
  alimentacao('Alimentação'),
  fralda('Fralda'),
  sono('Sono'),
  banho('Banho'),
  temperatura('Temperatura'),
  peso('Peso'),
  medicamento('Medicamento'),
  observacao('Observação');

  const DiaryKind(this.label);
  final String label;

  bool get allowsAttachment => switch (this) {
    alimentacao ||
    fralda ||
    temperatura ||
    peso ||
    medicamento ||
    observacao => true,
    _ => false,
  };

  List<String> get options => switch (this) {
    mamada => kFeedOptions,
    fralda => kDiaperOptions,
    temperatura => kTemperatureMethods,
    alimentacao => kFoodAcceptance,
    sono => kSleepTypes,
    _ => const <String>[],
  };

  List<String> get units => switch (this) {
    mamada => const <String>['mL'],
    alimentacao => kFoodUnits,
    temperatura => const <String>['°C'],
    peso => const <String>['kg'],
    medicamento => kMedicationUnits,
    _ => const <String>[],
  };

  bool get hasDuration => this == mamada || this == sono || this == banho;
}

const List<String> kFeedOptions = <String>[
  'Peito esquerdo',
  'Peito direito',
  'Os dois peitos',
  'Mamadeira',
];
const List<String> kDiaperOptions = <String>['Xixi', 'Cocô', 'Xixi e cocô'];
const List<String> kTemperatureMethods = <String>[
  'Axilar',
  'Testa',
  'Ouvido',
  'Oral',
];
const List<String> kFoodAcceptance = <String>[
  'Aceitou bem',
  'Aceitou parte',
  'Recusou',
];
const List<String> kFoodUnits = <String>['colheres', 'g', 'mL', 'porção'];
const String kSleepNight = 'Sono noturno';
const String kSleepNap = 'Cochilo';
const List<String> kSleepTypes = <String>[kSleepNight, kSleepNap];

/// Despertar durante um período de sono.
class SleepWaking {
  const SleepWaking({required this.at, this.minutesAwake});

  final DateTime at;

  /// Quanto tempo ficou sem dormir, quando a família informa.
  final int? minutesAwake;

  String describe() =>
      '${formatHm(at)}'
      '${minutesAwake == null ? '' : ' (${formatMinutes(minutesAwake!)})'}';

  bool sameAs(SleepWaking o) => at == o.at && minutesAwake == o.minutesAwake;
}

const List<String> kMedicationUnits = <String>[
  'mL',
  'gotas',
  'mg',
  'comprimido',
  'sachê',
];

enum DiaryRole {
  familia('Família'),
  profissional('Profissional');

  const DiaryRole(this.label);
  final String label;
}

class DiaryValues {
  const DiaryValues({
    required this.at,
    this.endAt,
    this.durationMinutes,
    this.quantity,
    this.unit = '',
    this.option = '',
    this.text = '',
    this.note = '',
    this.wakings = const <SleepWaking>[],
  });

  final DateTime at;
  final DateTime? endAt;
  final int? durationMinutes;
  final double? quantity;
  final String unit;

  /// Lado da mamada, tipo de fralda, método da temperatura, aceitação.
  final String option;

  /// Alimento, nome do medicamento ou texto da observação.
  final String text;
  final String note;

  /// Despertares do sono, em ordem.
  final List<SleepWaking> wakings;

  int? get minutes {
    if (endAt != null) return endAt!.difference(at).inMinutes;
    return durationMinutes;
  }

  DiaryValues copyWith({
    DateTime? at,
    DateTime? Function()? endAt,
    int? Function()? durationMinutes,
    double? Function()? quantity,
    String? unit,
    String? option,
    String? text,
    String? note,
    List<SleepWaking>? wakings,
  }) {
    return DiaryValues(
      at: at ?? this.at,
      endAt: endAt != null ? endAt() : this.endAt,
      durationMinutes: durationMinutes != null
          ? durationMinutes()
          : this.durationMinutes,
      quantity: quantity != null ? quantity() : this.quantity,
      unit: unit ?? this.unit,
      option: option ?? this.option,
      text: text ?? this.text,
      note: note ?? this.note,
      wakings: wakings ?? this.wakings,
    );
  }

  bool sameAs(DiaryValues o) =>
      at == o.at &&
      endAt == o.endAt &&
      durationMinutes == o.durationMinutes &&
      quantity == o.quantity &&
      unit == o.unit &&
      option == o.option &&
      text.trim() == o.text.trim() &&
      note.trim() == o.note.trim() &&
      wakings.length == o.wakings.length &&
      <bool>[
        for (int i = 0; i < wakings.length; i++)
          wakings[i].sameAs(o.wakings[i]),
      ].every((bool b) => b);

  String quantityLabel() {
    if (quantity == null) return '';
    final String u = unit.trim();
    final String q = formatDecimal(quantity!, digits: 2);
    if (u.isEmpty) return q;
    return u == '°C' ? '$q $u' : '$q $u';
  }

  /// Uma linha legível, sem interpretação clínica.
  String describe(DiaryKind kind) {
    final List<String> p = <String>[];
    final int? mins = minutes;
    switch (kind) {
      case DiaryKind.mamada:
        if (option.isNotEmpty) p.add(option);
        if (quantity != null) p.add(quantityLabel());
        if (mins != null) p.add(formatMinutes(mins));
      case DiaryKind.alimentacao:
        if (text.trim().isNotEmpty) p.add(text.trim());
        if (quantity != null) p.add(quantityLabel());
        if (option.isNotEmpty) p.add(option.toLowerCase());
      case DiaryKind.fralda:
        if (option.isNotEmpty) p.add(option);
      case DiaryKind.sono:
        if (option.isNotEmpty) p.add(option);
        if (endAt != null) {
          p.add('${formatHm(at)} às ${formatHm(endAt!)}');
          p.add(formatMinutes(mins!));
        } else if (mins != null) {
          p.add(formatMinutes(mins));
        } else {
          p.add('dormindo desde ${formatHm(at)}');
        }
        if (wakings.isNotEmpty) {
          p.add(
            '${wakings.length} ${wakings.length == 1 ? 'despertar' : 'despertares'}'
            ' (${wakings.map((SleepWaking w) => w.describe()).join(', ')})',
          );
        }
      case DiaryKind.banho:
        if (mins != null) p.add(formatMinutes(mins));
      case DiaryKind.temperatura:
        if (quantity != null) p.add(quantityLabel());
        if (option.isNotEmpty) p.add(option.toLowerCase());
      case DiaryKind.peso:
        if (quantity != null) p.add(quantityLabel());
      case DiaryKind.medicamento:
        if (text.trim().isNotEmpty) p.add(text.trim());
        if (quantity != null) p.add(quantityLabel());
      case DiaryKind.observacao:
        if (text.trim().isNotEmpty) p.add(text.trim());
    }
    return p.join(' - ');
  }

  List<String> validate(DiaryKind kind, {required DateTime now}) {
    final List<String> e = <String>[];
    if (at.isAfter(now.add(const Duration(minutes: 5)))) {
      e.add('O horário não pode estar no futuro.');
    }
    if (endAt != null) {
      if (!endAt!.isAfter(at)) e.add('O fim deve ser depois do início.');
      if (endAt!.isAfter(now.add(const Duration(minutes: 5)))) {
        e.add('O fim não pode estar no futuro.');
      }
    }
    final int? mins = minutes;
    if (mins != null && (mins <= 0 || mins > 24 * 60)) {
      e.add('A duração deve ficar entre 1 minuto e 24 horas.');
    }
    if (quantity != null && quantity! <= 0) {
      e.add('A quantidade deve ser maior que zero.');
    }
    if (quantity != null && unit.trim().isEmpty && kind.units.isNotEmpty) {
      e.add('Informe a unidade.');
    }
    switch (kind) {
      case DiaryKind.mamada:
        if (option.isEmpty) e.add('Escolha peito ou mamadeira.');
        if (option == 'Mamadeira' && quantity == null) {
          e.add('Informe quantos mL na mamadeira.');
        }
        if (quantity != null && quantity! > 500) {
          e.add('Confira a quantidade: acima de 500 mL.');
        }
      case DiaryKind.alimentacao:
        if (text.trim().isEmpty) e.add('Informe o que a criança comeu.');
      case DiaryKind.fralda:
        if (option.isEmpty) e.add('Escolha xixi, cocô ou os dois.');
      case DiaryKind.temperatura:
        if (quantity == null) {
          e.add('Informe a temperatura.');
        } else if (quantity! < 34 || quantity! > 43) {
          e.add('Confira a temperatura: use graus Celsius entre 34 e 43.');
        }
      case DiaryKind.peso:
        if (quantity == null) {
          e.add('Informe o peso.');
        } else if (quantity! < 0.3 || quantity! > 150) {
          e.add('Confira o peso: use quilos (ex.: 10,4).');
        }
      case DiaryKind.medicamento:
        if (text.trim().isEmpty) e.add('Informe o medicamento.');
      case DiaryKind.observacao:
        if (text.trim().isEmpty) e.add('Escreva a observação.');
      case DiaryKind.sono:
        for (final SleepWaking w in wakings) {
          if (w.at.isBefore(at) ||
              (endAt != null && w.at.isAfter(endAt!)) ||
              w.at.isAfter(now.add(const Duration(minutes: 5)))) {
            e.add(
              'O despertar das ${formatHm(w.at)} fica fora do período de sono.',
            );
          }
          if (w.minutesAwake != null &&
              (w.minutesAwake! <= 0 || w.minutesAwake! > 600)) {
            e.add('Tempo sem dormir no despertar: use de 1 a 600 minutos.');
          }
        }
      case DiaryKind.banho:
        break;
    }
    return e;
  }
}

class DiaryRevision {
  const DiaryRevision({
    required this.at,
    required this.author,
    required this.action,
    this.reason = '',
    this.before,
  });

  final DateTime at;
  final String author;
  final String action;
  final String reason;

  /// Valores antes da mudança (a versão anterior fica guardada).
  final DiaryValues? before;
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.values,
    required this.author,
    required this.role,
    required this.recordedAt,
    this.attachment,
    this.revisions = const <DiaryRevision>[],
    this.voided = false,
    this.planId,
    this.doseKey,
  });

  final String id;
  final String patientId;
  final DiaryKind kind;
  final DiaryValues values;
  final String author;
  final DiaryRole role;
  final DateTime recordedAt;
  final LabAttachment? attachment;
  final List<DiaryRevision> revisions;
  final bool voided;

  /// Dose programada de uma receita que este registro confirma.
  final String? planId;
  final String? doseKey;

  DateTime get at => values.at;

  bool get wasCorrected =>
      revisions.any((DiaryRevision r) => r.action == 'Corrigido');

  bool get isOpenSleep =>
      kind == DiaryKind.sono &&
      !voided &&
      values.endAt == null &&
      values.durationMinutes == null;

  String get describe => values.describe(kind);

  DiaryEntry _copy({
    DiaryValues? values,
    LabAttachment? Function()? attachment,
    List<DiaryRevision>? revisions,
    bool? voided,
  }) {
    return DiaryEntry(
      id: id,
      patientId: patientId,
      kind: kind,
      values: values ?? this.values,
      author: author,
      role: role,
      recordedAt: recordedAt,
      attachment: attachment != null ? attachment() : this.attachment,
      revisions: revisions ?? this.revisions,
      voided: voided ?? this.voided,
      planId: planId,
      doseKey: doseKey,
    );
  }

  /// Corrige o lançamento guardando a versão anterior. Devolve o próprio
  /// registro se nada mudou.
  DiaryEntry corrected({
    required DiaryValues values,
    required String author,
    required DateTime at,
    String reason = '',
    LabAttachment? Function()? attachment,
  }) {
    final bool attachmentChanged =
        attachment != null && !identical(attachment(), this.attachment);
    if (values.sameAs(this.values) && !attachmentChanged) return this;
    return _copy(
      values: values,
      attachment: attachment,
      revisions: <DiaryRevision>[
        ...revisions,
        DiaryRevision(
          at: at,
          author: author,
          action: 'Corrigido',
          reason: reason.trim(),
          before: this.values,
        ),
      ],
    );
  }

  DiaryEntry finishedSleep({
    required DateTime end,
    required String author,
    required DateTime at,
  }) {
    return _copy(
      values: values.copyWith(endAt: () => end),
      revisions: <DiaryRevision>[
        ...revisions,
        DiaryRevision(
          at: at,
          author: author,
          action: 'Fim do sono',
          before: values,
        ),
      ],
    );
  }

  /// Despertar anotado durante o sono em andamento (ou já encerrado).
  DiaryEntry withWaking(
    SleepWaking waking, {
    required String author,
    required DateTime at,
  }) {
    final List<SleepWaking> list = <SleepWaking>[...values.wakings, waking]
      ..sort((SleepWaking a, SleepWaking b) => a.at.compareTo(b.at));
    return _copy(
      values: values.copyWith(wakings: list),
      revisions: <DiaryRevision>[
        ...revisions,
        DiaryRevision(
          at: at,
          author: author,
          action: 'Despertar registrado',
          reason: waking.describe(),
          before: values,
        ),
      ],
    );
  }

  /// Marca como lançado por engano. O registro continua no histórico.
  DiaryEntry voidedBy({
    required String author,
    required DateTime at,
    required String reason,
  }) {
    return _copy(
      voided: true,
      revisions: <DiaryRevision>[
        ...revisions,
        DiaryRevision(
          at: at,
          author: author,
          action: 'Excluído',
          reason: reason.trim(),
          before: values,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resumo para o pediatra
// ---------------------------------------------------------------------------

class SummaryLine {
  const SummaryLine(
    this.at,
    this.text, {
    this.corrected = false,
    this.hasAttachment = false,
  });
  final DateTime at;
  final String text;
  final bool corrected;
  final bool hasAttachment;
}

class RoutineSummary {
  RoutineSummary._({
    required this.from,
    required this.to,
    required this.kinds,
    required this.entries,
    required this.upcoming,
  });

  /// [from] e [to] são dias (inclusive).
  factory RoutineSummary.build({
    required Iterable<DiaryEntry> entries,
    required DateTime from,
    required DateTime to,
    Set<DiaryKind>? kinds,
    Iterable<CalendarItem> upcoming = const <CalendarItem>[],
  }) {
    final DateTime a = dayOf(from);
    final DateTime b = addDays(dayOf(to), 1);
    final Set<DiaryKind> k = kinds == null || kinds.isEmpty
        ? DiaryKind.values.toSet()
        : kinds;
    final List<DiaryEntry> list =
        entries
            .where(
              (DiaryEntry e) =>
                  !e.voided &&
                  k.contains(e.kind) &&
                  !e.at.isBefore(a) &&
                  e.at.isBefore(b),
            )
            .toList()
          ..sort((DiaryEntry x, DiaryEntry y) => x.at.compareTo(y.at));
    return RoutineSummary._(
      from: a,
      to: dayOf(to),
      kinds: k,
      entries: list,
      upcoming: upcoming.toList()..sort(compareCalendarItems),
    );
  }

  final DateTime from;
  final DateTime to;
  final Set<DiaryKind> kinds;
  final List<DiaryEntry> entries;
  final List<CalendarItem> upcoming;

  int get days => to.difference(from).inDays + 1;

  bool get isEmpty => entries.isEmpty;

  List<DiaryEntry> of(DiaryKind k) =>
      entries.where((DiaryEntry e) => e.kind == k).toList();

  int count(DiaryKind k) => of(k).length;

  String _perDay(int n) {
    if (days <= 1) return '';
    return ' (média de ${formatDecimal(n / days)} por dia)';
  }

  /// Totais por tipo, uma linha por tipo presente.
  List<String> totals() {
    final List<String> out = <String>[];
    for (final DiaryKind k in DiaryKind.values) {
      if (!kinds.contains(k)) continue;
      final List<DiaryEntry> l = of(k);
      if (l.isEmpty) continue;
      switch (k) {
        case DiaryKind.mamada:
          final int bottle = l
              .where((DiaryEntry e) => e.values.option == 'Mamadeira')
              .length;
          final double ml = l.fold<double>(
            0,
            (double s, DiaryEntry e) =>
                s + (e.values.unit == 'mL' ? e.values.quantity ?? 0 : 0),
          );
          out.add(
            'Mamadas: ${l.length}${_perDay(l.length)}'
            '${bottle > 0 ? '; mamadeira $bottle vez(es), total ${formatDecimal(ml)} mL' : ''}',
          );
        case DiaryKind.fralda:
          int xixi = 0;
          int coco = 0;
          for (final DiaryEntry e in l) {
            if (e.values.option.contains('Xixi')) xixi++;
            if (e.values.option.toLowerCase().contains('cocô')) coco++;
          }
          out.add(
            'Fraldas: ${l.length}${_perDay(l.length)}; com xixi $xixi, com cocô $coco',
          );
        case DiaryKind.sono:
          int total = 0;
          int longest = 0;
          int open = 0;
          for (final DiaryEntry e in l) {
            final int? m = e.values.minutes;
            if (m == null) {
              open++;
              continue;
            }
            total += m;
            if (m > longest) longest = m;
          }
          out.add(
            'Sono registrado: ${formatMinutes(total)} em ${l.length} período(s)'
            '${days > 1 ? ' (média de ${formatMinutes(total ~/ days)} por dia)' : ''}'
            '${longest > 0 ? '; maior período ${formatMinutes(longest)}' : ''}'
            '${open > 0 ? '; $open sem horário de fim' : ''}',
          );
        case DiaryKind.temperatura:
          final List<DiaryEntry> t = l
              .where((DiaryEntry e) => e.values.quantity != null)
              .toList();
          final DiaryEntry? max = t.isEmpty
              ? null
              : t.reduce(
                  (DiaryEntry x, DiaryEntry y) =>
                      y.values.quantity! > x.values.quantity! ? y : x,
                );
          out.add(
            'Temperatura: ${l.length} medição(ões)'
            '${max == null ? '' : '; maior valor registrado ${max.values.quantityLabel()} em ${formatDm(max.at)} às ${formatHm(max.at)}'}',
          );
        case DiaryKind.peso:
          final DiaryEntry last = l.last;
          out.add(
            'Peso informado pela família: ${last.values.quantityLabel()} em ${formatDm(last.at)}'
            '${l.length > 1 ? ' (${l.length} registros)' : ''}',
          );
        case DiaryKind.medicamento:
          final Map<String, int> byName = <String, int>{};
          for (final DiaryEntry e in l) {
            final String n = e.values.text.trim();
            byName[n] = (byName[n] ?? 0) + 1;
          }
          out.add(
            'Medicamentos administrados: ${byName.entries.map((MapEntry<String, int> m) => '${m.key} (${m.value}x)').join(', ')}',
          );
        case DiaryKind.alimentacao:
        case DiaryKind.banho:
        case DiaryKind.observacao:
          out.add('${k.label}: ${l.length} registro(s)${_perDay(l.length)}');
      }
    }
    return out;
  }

  /// Registros que merecem aparecer um a um (texto livre e medidas).
  List<SummaryLine> details() {
    const Set<DiaryKind> itemized = <DiaryKind>{
      DiaryKind.temperatura,
      DiaryKind.peso,
      DiaryKind.medicamento,
      DiaryKind.alimentacao,
      DiaryKind.observacao,
    };
    return <SummaryLine>[
      for (final DiaryEntry e in entries)
        if (itemized.contains(e.kind))
          SummaryLine(
            e.at,
            '${e.kind.label}: ${e.describe}'
            '${e.values.note.trim().isEmpty ? '' : ' (${e.values.note.trim()})'}',
            corrected: e.wasCorrected,
            hasAttachment: e.attachment != null,
          ),
    ];
  }

  String periodLabel() => sameDay(from, to)
      ? formatDmy(from)
      : '${formatDmy(from)} a ${formatDmy(to)}';

  String toText({
    required String patientName,
    required String guardianName,
    required DateTime generatedAt,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('Resumo da rotina - $patientName')
      ..writeln('Período: ${periodLabel()} ($days dia(s))')
      ..writeln('Informado pela família ($guardianName) pelo diário do app.')
      ..writeln();
    if (isEmpty) {
      b.writeln('Nenhum registro no período para os tipos escolhidos.');
    } else {
      b.writeln('Totais');
      for (final String t in totals()) {
        b.writeln('- $t');
      }
      final List<SummaryLine> d = details();
      if (d.isNotEmpty) {
        b
          ..writeln()
          ..writeln('Registros');
        for (final SummaryLine l in d) {
          b.writeln(
            '- ${formatDm(l.at)} ${formatHm(l.at)} ${l.text}'
            '${l.corrected ? ' [corrigido pela família]' : ''}'
            '${l.hasAttachment ? ' [com anexo]' : ''}',
          );
        }
      }
    }
    if (upcoming.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Próximos compromissos');
      for (final CalendarItem i in upcoming) {
        b.writeln(
          '- ${formatDm(i.start)} ${i.allDay ? '' : '${formatHm(i.start)} '}${i.kind.label}: ${i.title}',
        );
      }
    }
    b
      ..writeln()
      ..writeln(
        'Gerado em ${formatDmy(generatedAt)} às ${formatHm(generatedAt)}. '
        'Estes dados foram registrados pela família e não substituem a '
        'avaliação do pediatra.',
      );
    return b.toString().trimRight();
  }
}

/// Resumo que a família enviou ao pediatra (fica visível na área do
/// profissional, marcado como informado pela família).
class SharedRoutineSummary {
  const SharedRoutineSummary({
    required this.id,
    required this.patientId,
    required this.from,
    required this.to,
    required this.kinds,
    required this.text,
    required this.entryCount,
    required this.author,
    required this.sentAt,
    this.message = '',
  });

  final String id;
  final String patientId;
  final DateTime from;
  final DateTime to;
  final Set<DiaryKind> kinds;
  final String text;
  final int entryCount;
  final String author;
  final DateTime sentAt;
  final String message;
}
