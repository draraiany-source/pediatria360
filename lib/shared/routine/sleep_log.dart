/// Diário do sono: sono noturno, cochilos e despertares registrados pela
/// família, organizados por dia e por semana.
///
/// Dart puro. Os números só somam o que foi registrado; não há
/// classificação clínica nem comparação com valores de referência.
library;

import 'child_routine.dart';

enum SleepType {
  night(kSleepNight),
  nap(kSleepNap);

  const SleepType(this.label);
  final String label;

  static SleepType? fromLabel(String label) {
    for (final SleepType t in SleepType.values) {
      if (t.label == label) return t;
    }
    return null;
  }
}

/// Tipo sugerido quando a família não escolheu: começou entre 18h e 5h e
/// durou 3 horas ou mais (ou ainda está dormindo) conta como noturno.
SleepType inferSleepType(DateTime start, int? minutes) {
  final bool evening = start.hour >= 18 || start.hour < 5;
  return evening && (minutes == null || minutes >= 180)
      ? SleepType.night
      : SleepType.nap;
}

SleepType sleepTypeOf(DiaryEntry e) =>
    SleepType.fromLabel(e.values.option) ??
    inferSleepType(e.values.at, e.values.minutes);

/// A noite pertence ao dia em que começou; se começou de madrugada (antes
/// do meio-dia), à noite do dia anterior.
DateTime nightOf(DateTime start) =>
    dayOf(start.subtract(const Duration(hours: 12)));

class SleepPeriod {
  const SleepPeriod({
    required this.entry,
    required this.type,
    required this.start,
    this.end,
  });

  final DiaryEntry entry;
  final SleepType type;
  final DateTime start;

  /// `null` enquanto a criança ainda dorme.
  final DateTime? end;

  bool get open => end == null;
  int? get minutes => entry.values.minutes;
  List<SleepWaking> get wakings => entry.values.wakings;

  /// Dia a que o período é atribuído no resumo.
  DateTime get day => type == SleepType.night ? nightOf(start) : dayOf(start);

  String describe() {
    final String span = end == null
        ? 'desde ${formatHm(start)} (sem horário de fim)'
        : '${formatHm(start)} às ${formatHm(end!)} (${formatMinutes(minutes!)})';
    final String w = wakings.isEmpty
        ? ''
        : ', ${wakings.length} ${wakings.length == 1 ? 'despertar' : 'despertares'}';
    return '${type.label}: $span$w';
  }
}

List<SleepPeriod> sleepPeriods(Iterable<DiaryEntry> entries) {
  final List<SleepPeriod> out = <SleepPeriod>[
    for (final DiaryEntry e in entries)
      if (e.kind == DiaryKind.sono && !e.voided)
        SleepPeriod(
          entry: e,
          type: sleepTypeOf(e),
          start: e.values.at,
          end:
              e.values.endAt ??
              (e.values.durationMinutes == null
                  ? null
                  : e.values.at.add(
                      Duration(minutes: e.values.durationMinutes!),
                    )),
        ),
  ]..sort((SleepPeriod a, SleepPeriod b) => a.start.compareTo(b.start));
  return out;
}

/// Resumo de um dia: a noite que começou nele e os cochilos do dia.
class SleepDay {
  SleepDay(this.day, List<SleepPeriod> periods)
    : nights = periods
          .where((SleepPeriod p) => p.type == SleepType.night)
          .toList(),
      naps = periods.where((SleepPeriod p) => p.type == SleepType.nap).toList();

  final DateTime day;
  final List<SleepPeriod> nights;
  final List<SleepPeriod> naps;

  List<SleepPeriod> get periods =>
      <SleepPeriod>[...nights, ...naps]
        ..sort((SleepPeriod a, SleepPeriod b) => a.start.compareTo(b.start));

  bool get isEmpty => nights.isEmpty && naps.isEmpty;

  static int _sum(List<SleepPeriod> l) =>
      l.fold<int>(0, (int s, SleepPeriod p) => s + (p.minutes ?? 0));

  int get nightMinutes => _sum(nights);
  int get napMinutes => _sum(naps);
  int get totalMinutes => nightMinutes + napMinutes;
  int get napCount => naps.length;
  int get openCount => periods.where((SleepPeriod p) => p.open).length;

  int get wakingCount =>
      nights.fold<int>(0, (int s, SleepPeriod p) => s + p.wakings.length);

  /// Maior trecho contínuo de sono noturno (entre despertares).
  int? get longestNightStretch {
    int? best;
    for (final SleepPeriod p in nights) {
      if (p.end == null) continue;
      DateTime from = p.start;
      for (final SleepWaking w in p.wakings) {
        final int m = w.at.difference(from).inMinutes;
        if (best == null || m > best) best = m;
        from = w.at.add(Duration(minutes: w.minutesAwake ?? 0));
      }
      final int last = p.end!.difference(from).inMinutes;
      if (best == null || last > best) best = last;
    }
    return best;
  }

  /// Uma linha legível do dia.
  String describe() {
    if (isEmpty) return 'Sem registro de sono.';
    final List<String> p = <String>[
      if (nights.isNotEmpty)
        'noite ${formatMinutes(nightMinutes)}'
            '${wakingCount == 0 ? '' : ' com $wakingCount ${wakingCount == 1 ? 'despertar' : 'despertares'}'}',
      if (naps.isNotEmpty)
        '$napCount ${napCount == 1 ? 'cochilo' : 'cochilos'} (${formatMinutes(napMinutes)})',
      'total ${formatMinutes(totalMinutes)}',
      if (openCount > 0) '$openCount sem horário de fim',
    ];
    return p.join(' - ');
  }
}

/// Resumo de sete dias (segunda a domingo, ou qualquer intervalo).
class SleepWeek {
  SleepWeek._(this.from, this.days, this.observations);

  /// [from] e [to] são dias, inclusive.
  factory SleepWeek.build({
    required Iterable<DiaryEntry> entries,
    required DateTime from,
    required DateTime to,
  }) {
    final DateTime a = dayOf(from);
    final int n = dayOf(to).difference(a).inDays + 1;
    final List<SleepPeriod> all = sleepPeriods(entries);
    final List<SleepDay> days = <SleepDay>[
      for (int i = 0; i < n; i++)
        SleepDay(
          addDays(a, i),
          all.where((SleepPeriod p) => sameDay(p.day, addDays(a, i))).toList(),
        ),
    ];
    final DateTime end = addDays(a, n);
    final List<DiaryEntry> notes = <DiaryEntry>[
      for (final DiaryEntry e in entries)
        if (!e.voided &&
            !e.at.isBefore(a) &&
            e.at.isBefore(end) &&
            ((e.kind == DiaryKind.sono && e.values.note.trim().isNotEmpty) ||
                (e.kind == DiaryKind.observacao &&
                    _mentionsSleep(e.values.text))))
          e,
    ]..sort((DiaryEntry x, DiaryEntry y) => x.at.compareTo(y.at));
    return SleepWeek._(a, days, notes);
  }

  final DateTime from;
  final List<SleepDay> days;

  /// Observações da família sobre o sono no período.
  final List<DiaryEntry> observations;

  DateTime get to => days.last.day;

  List<SleepDay> get recorded =>
      days.where((SleepDay d) => !d.isEmpty).toList();

  int get daysWithRecords => recorded.length;
  bool get isEmpty => recorded.isEmpty;

  int? _avg(Iterable<int> values) {
    final List<int> l = values.toList();
    if (l.isEmpty) return null;
    return (l.fold<int>(0, (int s, int v) => s + v) / l.length).round();
  }

  List<SleepDay> get _withNight =>
      recorded.where((SleepDay d) => d.nights.isNotEmpty).toList();

  int get nightsRecorded => _withNight.length;

  /// Médias só entre os dias com registro.
  int? get avgNightMinutes =>
      _avg(_withNight.map((SleepDay d) => d.nightMinutes));
  int? get avgNapMinutes => _avg(recorded.map((SleepDay d) => d.napMinutes));
  int? get avgTotalMinutes =>
      _avg(recorded.map((SleepDay d) => d.totalMinutes));

  double? get avgNapCount => recorded.isEmpty
      ? null
      : recorded.fold<int>(0, (int s, SleepDay d) => s + d.napCount) /
            recorded.length;

  int get totalWakings =>
      days.fold<int>(0, (int s, SleepDay d) => s + d.wakingCount);

  double? get avgWakings =>
      _withNight.isEmpty ? null : totalWakings / _withNight.length;

  /// Horário mais cedo e mais tarde em que a noite começou.
  (DateTime, DateTime)? get bedtimeRange {
    final List<DateTime> starts = <DateTime>[
      for (final SleepDay d in _withNight)
        for (final SleepPeriod p in d.nights) p.start,
    ];
    if (starts.isEmpty) return null;
    int key(DateTime t) => (t.hour < 12 ? t.hour + 24 : t.hour) * 60 + t.minute;
    starts.sort((DateTime a, DateTime b) => key(a).compareTo(key(b)));
    return (starts.first, starts.last);
  }

  String periodLabel() => '${formatDmy(from)} a ${formatDmy(to)}';

  /// Linhas do resumo semanal, sem interpretação.
  List<String> lines() {
    if (isEmpty) return <String>['Nenhum sono registrado no período.'];
    final (DateTime, DateTime)? bed = bedtimeRange;
    return <String>[
      '$daysWithRecords de ${days.length} dias com registro de sono.',
      if (avgNightMinutes != null)
        'Sono noturno: média de ${formatMinutes(avgNightMinutes!)} por noite '
            '($nightsRecorded ${nightsRecorded == 1 ? 'noite' : 'noites'})'
            '${bed == null ? '' : '; início entre ${formatHm(bed.$1)} e ${formatHm(bed.$2)}'}.',
      if (avgWakings != null)
        'Despertares: $totalWakings no período '
            '(média de ${formatDecimal(avgWakings!)} por noite).',
      if (avgNapCount != null)
        'Cochilos: média de ${formatDecimal(avgNapCount!)} por dia, '
            '${formatMinutes(avgNapMinutes ?? 0)} por dia.',
      if (avgTotalMinutes != null)
        'Sono total registrado: média de ${formatMinutes(avgTotalMinutes!)} por dia.',
    ];
  }

  /// Texto para o profissional incorporar à evolução, depois de revisar.
  String toClinicalText() {
    final StringBuffer b = StringBuffer()
      ..writeln('Diário do sono informado pela família (${periodLabel()}):');
    for (final String l in lines()) {
      b.writeln('- $l');
    }
    for (final DiaryEntry e in observations) {
      final String text = e.kind == DiaryKind.sono
          ? e.values.note.trim()
          : e.values.text.trim();
      b.writeln('- Observação da família em ${formatDm(e.at)}: $text');
    }
    b.write('Dados registrados pela família no app; conferir na consulta.');
    return b.toString();
  }
}

bool _mentionsSleep(String text) => RegExp(
  r'\b(sono|dorm|cochil|acord|despert|noite)',
  caseSensitive: false,
).hasMatch(text);

/// Trecho de sono dentro de um dia de calendário (minutos desde 0h), para
/// desenhar a linha do tempo.
class SleepSegment {
  const SleepSegment({
    required this.entryId,
    required this.type,
    required this.fromMinute,
    required this.toMinute,
    this.open = false,
  });

  final String entryId;
  final SleepType type;
  final int fromMinute;
  final int toMinute;
  final bool open;
}

/// Trechos de sono e despertares que caem no dia [day]. Sono em andamento
/// vai até [now].
({List<SleepSegment> segments, List<int> wakings}) sleepOnDay(
  Iterable<DiaryEntry> entries,
  DateTime day, {
  required DateTime now,
}) {
  final DateTime a = dayOf(day);
  final DateTime b = addDays(a, 1);
  final List<SleepSegment> segs = <SleepSegment>[];
  final List<int> wakes = <int>[];
  for (final SleepPeriod p in sleepPeriods(entries)) {
    final DateTime end = p.end ?? now;
    if (!end.isAfter(a) || !p.start.isBefore(b)) continue;
    final DateTime s = p.start.isBefore(a) ? a : p.start;
    final DateTime e = end.isAfter(b) ? b : end;
    if (!e.isAfter(s)) continue;
    segs.add(
      SleepSegment(
        entryId: p.entry.id,
        type: p.type,
        fromMinute: s.difference(a).inMinutes,
        toMinute: e.difference(a).inMinutes,
        open: p.open,
      ),
    );
    for (final SleepWaking w in p.wakings) {
      if (!w.at.isBefore(a) && w.at.isBefore(b)) {
        wakes.add(w.at.difference(a).inMinutes);
      }
    }
  }
  return (segments: segs, wakings: wakes);
}
