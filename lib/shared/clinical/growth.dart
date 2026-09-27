/// Curvas de crescimento: escore Z e percentil pelas tabelas LMS oficiais
/// da OMS (Padrões 2006, 0 a 5 anos; Referência 2007, 5 a 19 anos).
///
/// As tabelas vêm de `assets/data/who_growth_lms.json`, gerado por
/// `tool/generate_who_reference.py` a partir dos arquivos publicados pela
/// OMS. Este módulo não interpreta o resultado clinicamente: calcula,
/// identifica a referência usada e mostra quando ela não se aplica.
library;

import 'dart:math' as math;

enum GrowthSex {
  male('Masculino'),
  female('Feminino');

  const GrowthSex(this.label);

  final String label;

  static GrowthSex? fromLabel(String label) {
    final String l = label.trim().toLowerCase();
    if (l == 'menino' || l.startsWith('masc')) return GrowthSex.male;
    if (l == 'menina' || l.startsWith('fem')) return GrowthSex.female;
    return null;
  }
}

enum GrowthIndicator {
  weightForAge('weight_for_age', 'Peso para idade', 'Peso', 'kg'),
  lengthHeightForAge(
    'length_height_for_age',
    'Comprimento/altura para idade',
    'Comprimento/altura',
    'cm',
  ),
  bmiForAge('bmi_for_age', 'IMC para idade', 'IMC', 'kg/m²'),
  headForAge(
    'head_for_age',
    'Perímetro cefálico para idade',
    'Perímetro cefálico',
    'cm',
  );

  const GrowthIndicator(this.key, this.title, this.short, this.unit);

  final String key;
  final String title;
  final String short;
  final String unit;
}

/// Como o comprimento/altura foi medido.
enum MeasurePosition {
  lying('Deitado (comprimento)'),
  standing('Em pé (altura)');

  const MeasurePosition(this.label);

  final String label;
}

class LmsValues {
  const LmsValues(this.l, this.m, this.s);

  final double l;
  final double m;
  final double s;

  double zFor(double x) =>
      l.abs() < 1e-9 ? math.log(x / m) / s : (math.pow(x / m, l) - 1) / (l * s);

  double valueAt(double z) => l.abs() < 1e-9
      ? m * math.exp(s * z)
      : m * math.pow(1 + l * s * z, 1 / l).toDouble();

  static LmsValues lerp(LmsValues a, LmsValues b, double t) => LmsValues(
    a.l + (b.l - a.l) * t,
    a.m + (b.m - a.m) * t,
    a.s + (b.s - a.s) * t,
  );
}

class _Segment {
  _Segment({
    required this.source,
    required this.table,
    required this.byDay,
    required this.start,
    required this.end,
    required this.measure,
    required this.rows,
  });

  factory _Segment.fromJson(Map<String, dynamic> j) {
    double n(Object? v) => (v! as num).toDouble();
    List<LmsValues> parse(Object? raw) => <LmsValues>[
      for (final Object? r in raw! as List<Object?>)
        LmsValues(
          n((r! as List<Object?>)[0]),
          n((r as List<Object?>)[1]),
          n(r[2]),
        ),
    ];
    return _Segment(
      source: j['source']! as String,
      table: j['table']! as String,
      byDay: j['ageUnit'] == 'day',
      start: j['start']! as int,
      end: j['end']! as int,
      measure: j['measure'] as String?,
      rows: <GrowthSex, List<LmsValues>>{
        GrowthSex.male: parse(j['male']),
        GrowthSex.female: parse(j['female']),
      },
    );
  }

  final String source;
  final String table;
  final bool byDay;
  final int start;
  final int end;
  final String? measure;
  final Map<GrowthSex, List<LmsValues>> rows;

  double get startDays => byDay ? start.toDouble() : start * daysPerMonth;
  double get endDays => byDay ? end.toDouble() : end * daysPerMonth;

  LmsValues? at(GrowthSex sex, int ageDays) {
    final List<LmsValues> list = rows[sex]!;
    if (byDay) {
      if (ageDays < start || ageDays > end) return null;
      return list[ageDays - start];
    }
    final double months = ageDays / daysPerMonth;
    if (months < start || months > end) return null;
    final int i0 = months.floor();
    final int i1 = math.min(i0 + 1, end);
    return LmsValues.lerp(list[i0 - start], list[i1 - start], months - i0);
  }
}

const double daysPerMonth = 30.4375;

/// Referência encontrada para uma idade.
class WhoLookup {
  const WhoLookup({
    required this.lms,
    required this.referenceId,
    required this.referenceLabel,
    required this.table,
    this.measure,
  });

  final LmsValues lms;

  /// `who2006` ou `who2007`.
  final String referenceId;
  final String referenceLabel;

  /// Nome do arquivo oficial de origem (ex.: `lenanthro`).
  final String table;

  /// `length` ou `height` quando a tabela distingue a posição.
  final String? measure;
}

class WhoGrowthTables {
  WhoGrowthTables._(
    this.version,
    this.references,
    this._segments,
    this._restricted,
  );

  factory WhoGrowthTables.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> ind =
        json['indicators']! as Map<String, dynamic>;
    final Map<GrowthIndicator, List<_Segment>> segs =
        <GrowthIndicator, List<_Segment>>{};
    final Set<GrowthIndicator> restricted = <GrowthIndicator>{};
    for (final GrowthIndicator g in GrowthIndicator.values) {
      final Map<String, dynamic> data = ind[g.key]! as Map<String, dynamic>;
      segs[g] = <_Segment>[
        for (final Object? s in data['segments']! as List<Object?>)
          _Segment.fromJson(s! as Map<String, dynamic>),
      ];
      if (data['restricted'] == true) restricted.add(g);
    }
    return WhoGrowthTables._(
      json['_versao'] as String? ?? '',
      <String, String>{
        for (final MapEntry<String, dynamic> e
            in (json['references']! as Map<String, dynamic>).entries)
          e.key: e.value as String,
      },
      segs,
      restricted,
    );
  }

  final String version;
  final Map<String, String> references;
  final Map<GrowthIndicator, List<_Segment>> _segments;
  final Set<GrowthIndicator> _restricted;

  /// Peso e IMC usam o método restrito da OMS além de ±3 escores Z.
  bool usesRestrictedZ(GrowthIndicator g) => _restricted.contains(g);

  /// Última idade (em dias) coberta pela referência do indicador.
  double maxAgeDays(GrowthIndicator g) => _segments[g]!.last.endDays;

  WhoLookup? lookup(GrowthIndicator g, GrowthSex sex, int ageDays) {
    if (ageDays < 0) return null;
    for (final _Segment s in _segments[g]!) {
      // Os Padrões 2006 cobrem até 1826 dias; depois vale a Referência 2007.
      if (!s.byDay && ageDays <= 1826) continue;
      final LmsValues? lms = s.at(sex, ageDays);
      if (lms == null) continue;
      return WhoLookup(
        lms: lms,
        referenceId: s.source,
        referenceLabel: references[s.source] ?? s.source,
        table: s.table,
        measure: s.measure,
      );
    }
    return null;
  }
}

/// Escore Z pelo LMS. Para peso e IMC, a OMS recomenda o cálculo restrito
/// além de ±3, que usa a distância entre as curvas de 2 e 3 escores Z.
double whoZScore(LmsValues lms, double x, {required bool restricted}) {
  final double z = lms.zFor(x);
  if (!restricted || z.abs() <= 3) return z;
  if (z > 3) {
    final double sd3 = lms.valueAt(3);
    final double sd23 = sd3 - lms.valueAt(2);
    return 3 + (x - sd3) / sd23;
  }
  final double sd3 = lms.valueAt(-3);
  final double sd23 = lms.valueAt(-2) - sd3;
  return -3 + (x - sd3) / sd23;
}

/// Percentil (0 a 100) a partir do escore Z pela distribuição normal.
double percentileFromZ(double z) => 50 * (1 + _erf(z / math.sqrt2));

double _erf(double x) {
  // Abramowitz e Stegun 7.1.26 (erro máximo 1,5e-7).
  final double sign = x < 0 ? -1 : 1;
  final double ax = x.abs();
  final double t = 1 / (1 + 0.3275911 * ax);
  final double y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-ax * ax);
  return sign * y;
}

/// Idade usada nas curvas.
///
/// Para nascidos antes de 37 semanas, a idade corrigida (descontando as
/// semanas que faltaram para 40) é usada até 24 meses de idade cronológica.
/// Esses limites seguem a prática usual e dependem de validação clínica.
class GrowthAge {
  const GrowthAge._(this.chronologicalDays, this.correctedDays);

  factory GrowthAge.of({
    required DateTime birthDate,
    required DateTime at,
    int? gestationalAgeDays,
  }) {
    final int chrono = _dateOnly(at).difference(_dateOnly(birthDate)).inDays;
    final bool preterm =
        gestationalAgeDays != null && gestationalAgeDays < pretermBelowDays;
    if (!preterm || chrono > correctUntilChronologicalDays) {
      return GrowthAge._(chrono, null);
    }
    return GrowthAge._(chrono, chrono - (termDays - gestationalAgeDays));
  }

  static const int termDays = 280;
  static const int pretermBelowDays = 37 * 7;
  static const int correctUntilChronologicalDays = 730;

  final int chronologicalDays;

  /// `null` quando a correção não se aplica.
  final int? correctedDays;

  bool get usesCorrected => correctedDays != null;
  int get referenceDays => correctedDays ?? chronologicalDays;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Uma medida, como lançada.
class GrowthValues {
  const GrowthValues({
    required this.date,
    this.weightKg,
    this.lengthCm,
    this.position = MeasurePosition.lying,
    this.headCm,
  });

  final DateTime date;
  final double? weightKg;
  final double? lengthCm;
  final MeasurePosition position;
  final double? headCm;

  bool get isEmpty => weightKg == null && lengthCm == null && headCm == null;

  double? get bmi => weightKg == null || lengthCm == null
      ? null
      : weightKg! / math.pow(lengthCm! / 100, 2);

  bool sameAs(GrowthValues o) =>
      _dateOnly(date) == _dateOnly(o.date) &&
      weightKg == o.weightKg &&
      lengthCm == o.lengthCm &&
      position == o.position &&
      headCm == o.headCm;

  String summary() => <String>[
    formatGrowthDate(date),
    if (weightKg != null) 'peso ${formatGrowthNumber(weightKg!, 3)} kg',
    if (lengthCm != null)
      '${position == MeasurePosition.lying ? 'comprimento' : 'altura'} '
          '${formatGrowthNumber(lengthCm!, 1)} cm',
    if (headCm != null) 'PC ${formatGrowthNumber(headCm!, 1)} cm',
  ].join(' - ');

  /// Erros de preenchimento. Faixas largas: só barram erro de digitação.
  static List<String> validate(
    GrowthValues v, {
    required DateTime birthDate,
    required DateTime now,
  }) => <String>[
    if (_dateOnly(v.date).isBefore(_dateOnly(birthDate)))
      'A data da medida é anterior ao nascimento.',
    if (_dateOnly(v.date).isAfter(_dateOnly(now)))
      'A data da medida está no futuro.',
    if (v.isEmpty) 'Informe ao menos uma medida.',
    if (v.weightKg != null && (v.weightKg! < 0.3 || v.weightKg! > 200))
      'Peso fora da faixa aceita (0,3 a 200 kg).',
    if (v.lengthCm != null && (v.lengthCm! < 25 || v.lengthCm! > 220))
      'Comprimento/altura fora da faixa aceita (25 a 220 cm).',
    if (v.headCm != null && (v.headCm! < 20 || v.headCm! > 70))
      'Perímetro cefálico fora da faixa aceita (20 a 70 cm).',
  ];
}

class GrowthRevision {
  const GrowthRevision({
    required this.at,
    required this.author,
    required this.reason,
    required this.before,
    required this.after,
    this.voided = false,
  });

  final DateTime at;
  final String author;
  final String reason;
  final GrowthValues before;
  final GrowthValues after;
  final bool voided;
}

/// Medida registrada. Correções não apagam o valor anterior: ficam no
/// histórico com motivo, autor e data.
class GrowthMeasurement {
  const GrowthMeasurement({
    required this.id,
    required this.patientId,
    required this.values,
    required this.author,
    required this.recordedAt,
    this.consultationId,
    this.revisions = const <GrowthRevision>[],
    this.voided = false,
  });

  final String id;
  final String patientId;
  final GrowthValues values;
  final String author;
  final DateTime recordedAt;
  final String? consultationId;
  final List<GrowthRevision> revisions;

  /// Lançamento anulado (ex.: paciente errado). Sai das curvas, fica no
  /// histórico.
  final bool voided;

  bool get wasCorrected => revisions.isNotEmpty;

  GrowthMeasurement _with(GrowthValues v, GrowthRevision r, {bool? voided}) =>
      GrowthMeasurement(
        id: id,
        patientId: patientId,
        values: v,
        author: author,
        recordedAt: recordedAt,
        consultationId: consultationId,
        revisions: <GrowthRevision>[...revisions, r],
        voided: voided ?? this.voided,
      );

  GrowthMeasurement correct({
    required GrowthValues values,
    required String reason,
    required String author,
    required DateTime at,
  }) {
    if (reason.trim().isEmpty) {
      throw StateError('Informe o motivo da correção.');
    }
    if (values.sameAs(this.values)) {
      throw StateError('Nenhum valor foi alterado.');
    }
    return _with(
      values,
      GrowthRevision(
        at: at,
        author: author,
        reason: reason.trim(),
        before: this.values,
        after: values,
      ),
    );
  }

  GrowthMeasurement voidEntry({
    required String reason,
    required String author,
    required DateTime at,
  }) {
    if (reason.trim().isEmpty) {
      throw StateError('Informe o motivo da anulação.');
    }
    return _with(
      values,
      GrowthRevision(
        at: at,
        author: author,
        reason: reason.trim(),
        before: values,
        after: values,
        voided: true,
      ),
      voided: true,
    );
  }
}

/// Resultado de uma medida em um indicador.
class GrowthPoint {
  const GrowthPoint({
    required this.measurement,
    required this.indicator,
    required this.age,
    required this.measured,
    this.value,
    this.adjustment,
    this.lookup,
    this.z,
    this.unavailable,
  });

  final GrowthMeasurement measurement;
  final GrowthIndicator indicator;
  final GrowthAge age;

  /// Valor como lançado.
  final double measured;

  /// Valor usado na referência (com o ajuste de posição, se houver).
  final double? value;

  /// Ajuste de 0,7 cm quando a posição não corresponde à idade.
  final String? adjustment;
  final WhoLookup? lookup;
  final double? z;

  /// Por que não há escore (fora da faixa, antes do termo...).
  final String? unavailable;

  double get ageMonths => age.referenceDays / daysPerMonth;
  double? get percentile => z == null ? null : percentileFromZ(z!);
}

class GrowthCalculator {
  const GrowthCalculator(this.tables);

  final WhoGrowthTables tables;

  static const double positionAdjustmentCm = 0.7;

  List<GrowthPoint> series({
    required List<GrowthMeasurement> measurements,
    required GrowthIndicator indicator,
    required GrowthSex sex,
    required DateTime birthDate,
    int? gestationalAgeDays,
  }) {
    final List<GrowthMeasurement> sorted =
        measurements.where((GrowthMeasurement m) => !m.voided).toList()..sort(
          (GrowthMeasurement a, GrowthMeasurement b) =>
              a.values.date.compareTo(b.values.date),
        );
    return <GrowthPoint>[
      for (final GrowthMeasurement m in sorted)
        if (assess(
              measurement: m,
              indicator: indicator,
              sex: sex,
              birthDate: birthDate,
              gestationalAgeDays: gestationalAgeDays,
            )
            case final GrowthPoint p)
          p,
    ];
  }

  /// `null` quando a medida não tem o dado do indicador.
  GrowthPoint? assess({
    required GrowthMeasurement measurement,
    required GrowthIndicator indicator,
    required GrowthSex sex,
    required DateTime birthDate,
    int? gestationalAgeDays,
  }) {
    final GrowthValues v = measurement.values;
    final GrowthAge age = GrowthAge.of(
      birthDate: birthDate,
      at: v.date,
      gestationalAgeDays: gestationalAgeDays,
    );
    final int days = age.referenceDays;

    // Comprimento (deitado) até 730 dias e altura (em pé) depois: a OMS
    // soma ou subtrai 0,7 cm quando a posição não corresponde à idade.
    double? length = v.lengthCm;
    String? adjustment;
    if (length != null && days >= 0) {
      if (days <= 730 && v.position == MeasurePosition.standing) {
        length += positionAdjustmentCm;
        adjustment = 'Medido em pé antes dos 24 meses: +0,7 cm (regra da OMS).';
      } else if (days > 730 && v.position == MeasurePosition.lying) {
        length -= positionAdjustmentCm;
        adjustment = 'Medido deitado após os 24 meses: -0,7 cm (regra da OMS).';
      }
    }

    final double? measured = switch (indicator) {
      GrowthIndicator.weightForAge => v.weightKg,
      GrowthIndicator.lengthHeightForAge => v.lengthCm,
      GrowthIndicator.headForAge => v.headCm,
      GrowthIndicator.bmiForAge => v.bmi,
    };
    if (measured == null) return null;
    final double? value = switch (indicator) {
      GrowthIndicator.lengthHeightForAge => length,
      GrowthIndicator.bmiForAge =>
        length == null ? null : v.weightKg! / math.pow(length / 100, 2),
      _ => measured,
    };

    if (days < 0) {
      return GrowthPoint(
        measurement: measurement,
        indicator: indicator,
        age: age,
        measured: measured,
        value: value,
        adjustment: adjustment,
        unavailable:
            'Idade corrigida anterior ao termo (40 semanas). As curvas da '
            'OMS começam no termo; para este período use uma referência '
            'neonatal para prematuros (não incluída nesta versão).',
      );
    }
    final WhoLookup? ref = tables.lookup(indicator, sex, days);
    if (ref == null) {
      return GrowthPoint(
        measurement: measurement,
        indicator: indicator,
        age: age,
        measured: measured,
        value: value,
        adjustment: adjustment,
        unavailable: switch (indicator) {
          GrowthIndicator.weightForAge =>
            'A OMS não publica peso para idade após 10 anos; use o IMC.',
          GrowthIndicator.headForAge =>
            'A referência de perímetro cefálico da OMS vai até 5 anos.',
          _ => 'Idade fora da faixa da referência da OMS (até 19 anos).',
        },
      );
    }
    return GrowthPoint(
      measurement: measurement,
      indicator: indicator,
      age: age,
      measured: measured,
      value: value,
      adjustment: adjustment,
      lookup: ref,
      z: whoZScore(
        ref.lms,
        value!,
        restricted: tables.usesRestrictedZ(indicator),
      ),
    );
  }

  /// Curva de referência (idade em meses, valor) para um escore Z.
  List<(double, double)> curve({
    required GrowthIndicator indicator,
    required GrowthSex sex,
    required double z,
    required double fromDays,
    required double toDays,
  }) {
    final double end = math.min(toDays, tables.maxAgeDays(indicator));
    final List<(double, double)> out = <(double, double)>[];
    double d = fromDays;
    while (d <= end + 0.01) {
      final int day = d.round();
      final WhoLookup? ref = tables.lookup(indicator, sex, day);
      if (ref != null) {
        final double y =
            indicator == GrowthIndicator.weightForAge ||
                indicator == GrowthIndicator.bmiForAge
            ? _restrictedValueAt(ref.lms, z)
            : ref.lms.valueAt(z);
        out.add((day / daysPerMonth, y));
      }
      d += day < 730 ? 7 : (day <= 1826 ? 15 : daysPerMonth);
    }
    return out;
  }

  static double _restrictedValueAt(LmsValues lms, double z) {
    if (z.abs() <= 3) return lms.valueAt(z);
    final double sd3 = lms.valueAt(z.sign * 3);
    final double sd23 = (sd3 - lms.valueAt(z.sign * 2)).abs();
    return sd3 + z.sign * (z.abs() - 3) * sd23;
  }
}

/// Janelas de visualização, como nas curvas impressas da OMS.
enum GrowthWindow {
  upTo2y('0 a 2 anos', 0, 730),
  from2to5y('2 a 5 anos', 730, 1826),
  from5to19y('5 a 19 anos', 1826, 228 * daysPerMonth);

  const GrowthWindow(this.label, this.fromDays, this.toDays);

  final String label;
  final double fromDays;
  final double toDays;

  static List<GrowthWindow> availableFor(
    GrowthIndicator g,
    WhoGrowthTables t,
  ) => <GrowthWindow>[
    for (final GrowthWindow w in GrowthWindow.values)
      if (w.fromDays < t.maxAgeDays(g)) w,
  ];

  static GrowthWindow forAge(int days) {
    if (days <= 730) return GrowthWindow.upTo2y;
    if (days <= 1826) return GrowthWindow.from2to5y;
    return GrowthWindow.from5to19y;
  }
}

/// Linhas de escore Z desenhadas nas curvas.
const List<double> kGrowthZLines = <double>[-3, -2, 0, 2, 3];

String formatGrowthNumber(double v, int decimals) {
  String s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

String formatGrowthDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatZ(double z) {
  final String s = z.abs().toStringAsFixed(2).replaceAll('.', ',');
  return z < 0 ? '-$s' : '+$s';
}

/// Percentil para exibição; além de ±3,09 escores Z mostra só o limite.
String formatPercentile(double z) {
  if (z < -3.09) return '< P0,1';
  if (z > 3.09) return '> P99,9';
  final double p = percentileFromZ(z);
  if (p < 1 || p > 99) {
    return 'P${p.toStringAsFixed(1).replaceAll('.', ',')}';
  }
  return 'P${p.round()}';
}

String formatAgeDays(int days) {
  if (days < 0) {
    final int w = (-days / 7).ceil();
    return '$w ${w == 1 ? 'semana' : 'semanas'} antes do termo';
  }
  final int months = (days / daysPerMonth).floor();
  if (months < 1) return '$days ${days == 1 ? 'dia' : 'dias'}';
  if (months < 24) {
    final int rest = (days - months * daysPerMonth).floor();
    final String m = '$months ${months == 1 ? 'mês' : 'meses'}';
    return rest == 0 ? m : '$m e $rest ${rest == 1 ? 'dia' : 'dias'}';
  }
  final int years = months ~/ 12;
  final int rm = months % 12;
  final String y = '$years anos';
  return rm == 0 ? y : '$y e $rm ${rm == 1 ? 'mês' : 'meses'}';
}

String formatGestationalAge(int days) {
  final int w = days ~/ 7;
  final int d = days % 7;
  return d == 0 ? '$w semanas' : '$w semanas e $d ${d == 1 ? 'dia' : 'dias'}';
}
