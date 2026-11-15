/// Linha do tempo do paciente e comparação entre atendimentos.
library;

import 'growth.dart';

enum TimelineKind {
  consulta('Consultas'),
  evolucao('Evoluções'),
  receita('Prescrições'),
  atestado('Atestados'),
  encaminhamento('Encaminhamentos'),
  exame('Exames'),
  orientacao('Orientações'),
  crescimento('Crescimento'),
  preConsulta('Pré-consultas'),
  agenda('Faltas e cancelamentos');

  const TimelineKind(this.label);

  final String label;

  /// Tipo de documento clínico (slug de DocKind) na linha do tempo.
  static TimelineKind forDocument(String slug) => switch (slug) {
    'receituario' => TimelineKind.receita,
    'atestado' || 'declaracao' => TimelineKind.atestado,
    'encaminhamento' => TimelineKind.encaminhamento,
    'exames' => TimelineKind.exame,
    _ => TimelineKind.orientacao,
  };
}

class TimelineEvent {
  const TimelineEvent({
    required this.at,
    required this.kind,
    required this.title,
    this.detail,
    this.route,
    this.author,
    this.draft = false,
  });

  final DateTime at;
  final TimelineKind kind;
  final String title;
  final String? detail;

  /// Tela que abre o registro.
  final String? route;
  final String? author;
  final bool draft;
}

/// Mais recente primeiro; filtro vazio mostra tudo.
List<TimelineEvent> buildTimeline(
  Iterable<TimelineEvent> events, {
  Set<TimelineKind> only = const <TimelineKind>{},
}) =>
    events
        .where((TimelineEvent e) => only.isEmpty || only.contains(e.kind))
        .toList()
      ..sort((TimelineEvent a, TimelineEvent b) => b.at.compareTo(a.at));

/// Diferença entre duas medidas (da mais antiga para a mais nova).
class GrowthDelta {
  const GrowthDelta({
    required this.days,
    this.weightKg,
    this.lengthCm,
    this.headCm,
  });

  final int days;
  final double? weightKg;
  final double? lengthCm;
  final double? headCm;

  /// Ganho de peso em gramas por dia.
  double? get gramsPerDay =>
      weightKg == null || days <= 0 ? null : weightKg! * 1000 / days;

  /// Crescimento em cm por mês (30,4375 dias).
  double? get cmPerMonth =>
      lengthCm == null || days <= 0 ? null : lengthCm! / days * daysPerMonth;
}

GrowthDelta compareGrowth(GrowthValues older, GrowthValues newer) {
  double? diff(double? a, double? b) => a == null || b == null ? null : b - a;
  return GrowthDelta(
    days: DateTime(newer.date.year, newer.date.month, newer.date.day)
        .difference(DateTime(older.date.year, older.date.month, older.date.day))
        .inDays,
    weightKg: diff(older.weightKg, newer.weightKg),
    lengthCm: diff(older.lengthCm, newer.lengthCm),
    headCm: diff(older.headCm, newer.headCm),
  );
}

/// Medida da consulta: a lançada nela ou, sem isso, a mais próxima até
/// 7 dias antes ou depois da data.
GrowthMeasurement? measurementForVisit(
  List<GrowthMeasurement> all, {
  required String consultationId,
  required DateTime date,
}) {
  final List<GrowthMeasurement> valid = all
      .where((GrowthMeasurement m) => !m.voided)
      .toList();
  for (final GrowthMeasurement m in valid) {
    if (m.consultationId == consultationId) return m;
  }
  GrowthMeasurement? best;
  int bestDays = 8;
  for (final GrowthMeasurement m in valid) {
    final int d = m.values.date.difference(date).inDays.abs();
    if (d < bestDays) {
      best = m;
      bestDays = d;
    }
  }
  return best;
}
