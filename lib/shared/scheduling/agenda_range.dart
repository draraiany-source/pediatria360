/// Visões da agenda (dia, semana, mês) e horários livres de um dia.
library;

import 'slots.dart';

enum AgendaView {
  dia('Dia', 'Dia anterior', 'Próximo dia'),
  semana('Semana', 'Semana anterior', 'Próxima semana'),
  mes('Mês', 'Mês anterior', 'Próximo mês');

  const AgendaView(this.label, this.previousLabel, this.nextLabel);

  final String label;
  final String previousLabel;
  final String nextLabel;

  static AgendaView fromSlug(String? slug) => AgendaView.values.firstWhere(
    (AgendaView v) => v.name == slug,
    orElse: () => AgendaView.dia,
  );
}

const List<String> _months = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const List<String> weekdayShort = <String>[
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
  'dom',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Segunda-feira da semana de [d].
DateTime startOfWeek(DateTime d) {
  final DateTime day = dateOnly(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// Intervalo [start, end) coberto pela visão.
({DateTime start, DateTime end}) agendaBounds(AgendaView v, DateTime anchor) {
  final DateTime day = dateOnly(anchor);
  return switch (v) {
    AgendaView.dia => (
      start: day,
      end: DateTime(day.year, day.month, day.day + 1),
    ),
    AgendaView.semana => (
      start: startOfWeek(day),
      end: DateTime(
        startOfWeek(day).year,
        startOfWeek(day).month,
        startOfWeek(day).day + 7,
      ),
    ),
    AgendaView.mes => (
      start: DateTime(day.year, day.month),
      end: DateTime(day.year, day.month + 1),
    ),
  };
}

DateTime shiftAnchor(AgendaView v, DateTime anchor, int step) {
  final DateTime d = dateOnly(anchor);
  return switch (v) {
    AgendaView.dia => DateTime(d.year, d.month, d.day + step),
    AgendaView.semana => DateTime(d.year, d.month, d.day + 7 * step),
    AgendaView.mes => DateTime(d.year, d.month + step),
  };
}

/// 42 dias (6 semanas) a partir da segunda-feira que abre o mês.
List<DateTime> monthGrid(DateTime anchor) {
  final DateTime first = startOfWeek(DateTime(anchor.year, anchor.month));
  return <DateTime>[
    for (int i = 0; i < 42; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String agendaTitle(AgendaView v, DateTime anchor) {
  final DateTime d = dateOnly(anchor);
  return switch (v) {
    AgendaView.dia => '${weekdayShort[d.weekday - 1]}, ${_dm(d)}/${d.year}',
    AgendaView.semana => () {
      final DateTime s = startOfWeek(d);
      final DateTime e = DateTime(s.year, s.month, s.day + 6);
      return '${_dm(s)} a ${_dm(e)}';
    }(),
    AgendaView.mes => '${_months[d.month - 1]} de ${d.year}',
  };
}

/// Trecho de horário (ocupado ou livre) dentro de um dia.
class TimeSpan {
  const TimeSpan(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get minutes => end.difference(start).inMinutes;
}

/// Trechos livres do expediente: tira consultas, bloqueios e o que já
/// passou (com a antecedência mínima). Trechos menores que [minMinutes]
/// não aparecem.
List<TimeSpan> freeSpans({
  required DateTime day,
  required List<WorkingRange> ranges,
  required List<TimeSpan> busy,
  required DateTime notBefore,
  int minMinutes = 20,
}) {
  final DateTime d = dateOnly(day);
  final List<TimeSpan> taken = List<TimeSpan>.of(busy)
    ..sort((TimeSpan a, TimeSpan b) => a.start.compareTo(b.start));
  final List<TimeSpan> out = <TimeSpan>[];
  for (final WorkingRange r in ranges) {
    DateTime cursor = DateTime(d.year, d.month, d.day, 0, r.startMinute);
    final DateTime end = DateTime(d.year, d.month, d.day, 0, r.endMinute);
    if (cursor.isBefore(notBefore)) cursor = notBefore;
    for (final TimeSpan b in taken) {
      if (!b.end.isAfter(cursor) || !b.start.isBefore(end)) continue;
      if (b.start.isAfter(cursor)) out.add(TimeSpan(cursor, b.start));
      if (b.end.isAfter(cursor)) cursor = b.end;
    }
    if (end.isAfter(cursor)) out.add(TimeSpan(cursor, end));
  }
  return out.where((TimeSpan s) => s.minutes >= minMinutes).toList();
}

/// Quantos horários de [slotMinutes] cabem nos trechos livres.
int freeSlotCount(List<TimeSpan> spans, int slotMinutes) =>
    spans.fold(0, (int total, TimeSpan s) => total + s.minutes ~/ slotMinutes);
