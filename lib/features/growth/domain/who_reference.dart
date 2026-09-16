import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../../../shared/domain/entities/child.dart';
import '../../../shared/domain/entities/growth_record.dart';

/// Um ponto da tabela LMS: assimetria (L), mediana (M) e coeficiente de
/// variação (S) para uma idade em meses.
class LmsPoint {
  const LmsPoint({
    required this.month,
    required this.l,
    required this.m,
    required this.s,
  });

  factory LmsPoint.fromJson(Map<String, dynamic> json) => LmsPoint(
        month: (json['mes'] as num).toInt(),
        l: (json['L'] as num).toDouble(),
        m: (json['M'] as num).toDouble(),
        s: (json['S'] as num).toDouble(),
      );

  final int month;
  final double l;
  final double m;
  final double s;
}

/// Resultado da avaliação de uma medida contra a referência.
class GrowthAssessment {
  const GrowthAssessment({
    required this.indicator,
    required this.value,
    required this.ageMonths,
    required this.zScore,
    required this.percentile,
    required this.median,
  });

  final GrowthIndicator indicator;
  final double value;
  final int ageMonths;

  /// Escore-Z (desvios-padrão em relação à mediana).
  final double zScore;

  /// Percentil correspondente, de 0 a 100.
  final double percentile;

  /// Valor mediano esperado para a idade e o sexo.
  final double median;

  /// Classificação da OMS por faixa de escore-Z.
  ///
  /// Os pontos de corte (-3, -2, +1, +2, +3) são os adotados pela OMS e pela
  /// Caderneta da Criança do Ministério da Saúde.
  GrowthClassification get classification {
    if (indicator == GrowthIndicator.heightForAge) {
      // Estatura não tem faixa de excesso: ser alto não é agravo.
      if (zScore < -3) return GrowthClassification.severelyLow;
      if (zScore < -2) return GrowthClassification.low;
      return GrowthClassification.adequate;
    }

    if (zScore < -3) return GrowthClassification.severelyLow;
    if (zScore < -2) return GrowthClassification.low;
    if (zScore <= 1) return GrowthClassification.adequate;
    if (zScore <= 2) return GrowthClassification.attention;
    if (zScore <= 3) return GrowthClassification.high;
    return GrowthClassification.severelyHigh;
  }
}

/// Faixas de classificação exibidas ao usuário.
enum GrowthClassification {
  severelyLow,
  low,
  adequate,
  attention,
  high,
  severelyHigh;

  /// Rótulo depende do indicador: "magreza" e "obesidade" só fazem sentido
  /// para peso e IMC.
  String labelFor(GrowthIndicator indicator) {
    if (indicator == GrowthIndicator.heightForAge) {
      return switch (this) {
        GrowthClassification.severelyLow => 'Estatura muito baixa',
        GrowthClassification.low => 'Estatura baixa',
        _ => 'Estatura adequada',
      };
    }

    if (indicator == GrowthIndicator.headForAge) {
      return switch (this) {
        GrowthClassification.severelyLow ||
        GrowthClassification.low =>
          'Abaixo do esperado',
        GrowthClassification.high ||
        GrowthClassification.severelyHigh =>
          'Acima do esperado',
        _ => 'Dentro do esperado',
      };
    }

    if (indicator == GrowthIndicator.bmiForAge) {
      return switch (this) {
        GrowthClassification.severelyLow => 'Magreza acentuada',
        GrowthClassification.low => 'Magreza',
        GrowthClassification.adequate => 'Adequado',
        GrowthClassification.attention => 'Risco de sobrepeso',
        GrowthClassification.high => 'Sobrepeso',
        GrowthClassification.severelyHigh => 'Obesidade',
      };
    }

    return switch (this) {
      GrowthClassification.severelyLow => 'Peso muito baixo',
      GrowthClassification.low => 'Peso baixo',
      GrowthClassification.adequate => 'Peso adequado',
      GrowthClassification.attention => 'Peso elevado para a idade',
      GrowthClassification.high => 'Peso elevado para a idade',
      GrowthClassification.severelyHigh => 'Peso muito elevado',
    };
  }

  /// `true` quando o resultado merece conversa com o pediatra.
  bool get needsAttention =>
      this == GrowthClassification.severelyLow ||
      this == GrowthClassification.low ||
      this == GrowthClassification.high ||
      this == GrowthClassification.severelyHigh;
}

/// Referência antropométrica da OMS e a matemática de escore-Z.
///
/// ## Sobre os dados
///
/// A tabela vem de `assets/data/who_reference.json`. **Os valores que
/// acompanham o repositório são aproximações de desenvolvimento**, geradas por
/// `tool/generate_who_reference.py`, e precisam ser substituídas pelas tabelas
/// LMS oficiais antes de qualquer uso clínico. O formato do arquivo é o mesmo,
/// então a troca não exige mudança de código.
///
/// A **matemática** implementada aqui, essa sim, segue a fórmula publicada pela
/// OMS e está coberta por testes:
///
/// ```
/// Z = ((X/M)^L − 1) / (L·S)     quando L ≠ 0
/// Z = ln(X/M) / S               quando L = 0
/// ```
class WhoReference {
  WhoReference._(this._tables, this.warning, this.version);

  final Map<String, Map<String, List<LmsPoint>>> _tables;

  /// Aviso embutido no próprio arquivo de dados. Antes desta mudança, o
  /// campo `_aviso` do JSON existia mas nenhum código Dart o lia — o alerta
  /// "valores aproximados, não usar clinicamente" ficava visível só para
  /// quem abrisse o arquivo JSON bruto, nunca para o médico olhando o
  /// gráfico na tela. Ler direto do arquivo, em vez de duplicar a frase
  /// aqui, evita que o aviso do dado e o aviso da tela divirjam com o tempo.
  final String? warning;

  final String? version;

  static WhoReference? _instance;
  static const String assetPath = 'assets/data/who_reference.json';

  /// Carrega a tabela uma única vez por sessão (~31 KB de JSON).
  static Future<WhoReference> load() async {
    if (_instance != null) return _instance!;

    final String raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json =
        jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> indicators =
        json['indicadores'] as Map<String, dynamic>;

    final Map<String, Map<String, List<LmsPoint>>> tables =
        <String, Map<String, List<LmsPoint>>>{};

    for (final MapEntry<String, dynamic> entry in indicators.entries) {
      final Map<String, dynamic> bySex = entry.value as Map<String, dynamic>;
      tables[entry.key] = <String, List<LmsPoint>>{
        for (final MapEntry<String, dynamic> sexEntry in bySex.entries)
          sexEntry.key: (sexEntry.value as List<dynamic>)
              .map(
                (dynamic e) =>
                    LmsPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList(growable: false),
      };
    }

    return _instance = WhoReference._(
      tables,
      json['_aviso'] as String?,
      json['_versao'] as String?,
    );
  }

  static String _key(GrowthIndicator indicator) => switch (indicator) {
        GrowthIndicator.weightForAge => 'weight_for_age',
        GrowthIndicator.heightForAge => 'height_for_age',
        GrowthIndicator.bmiForAge => 'bmi_for_age',
        GrowthIndicator.headForAge => 'head_for_age',
      };

  List<LmsPoint>? _table(GrowthIndicator indicator, ChildSex sex) =>
      _tables[_key(indicator)]?[sex.name];

  /// Ponto LMS para a idade, interpolando entre os meses inteiros.
  LmsPoint? pointAt(GrowthIndicator indicator, ChildSex sex, double months) {
    final List<LmsPoint>? table = _table(indicator, sex);
    if (table == null || table.isEmpty) return null;

    if (months <= table.first.month) return table.first;
    if (months >= table.last.month) return table.last;

    final int lower = months.floor();
    final double t = months - lower;
    if (lower + 1 >= table.length) return table.last;

    final LmsPoint a = table[lower];
    final LmsPoint b = table[lower + 1];

    return LmsPoint(
      month: lower,
      l: a.l + (b.l - a.l) * t,
      m: a.m + (b.m - a.m) * t,
      s: a.s + (b.s - a.s) * t,
    );
  }

  /// Escore-Z de um valor medido.
  double? zScore({
    required GrowthIndicator indicator,
    required ChildSex sex,
    required double ageMonths,
    required double value,
  }) {
    final LmsPoint? point = pointAt(indicator, sex, ageMonths);
    if (point == null || value <= 0 || point.m <= 0) return null;

    final double z = point.l.abs() < 1e-7
        ? math.log(value / point.m) / point.s
        : (math.pow(value / point.m, point.l) - 1) / (point.l * point.s);

    if (z.isNaN || z.isInfinite) return null;
    return z;
  }

  /// Valor medido correspondente a um escore-Z — usado para desenhar as
  /// linhas de referência (-3, -2, 0, +2, +3) no gráfico.
  double? valueForZ({
    required GrowthIndicator indicator,
    required ChildSex sex,
    required double ageMonths,
    required double z,
  }) {
    final LmsPoint? point = pointAt(indicator, sex, ageMonths);
    if (point == null) return null;

    final double value = point.l.abs() < 1e-7
        ? point.m * math.exp(point.s * z)
        : point.m * math.pow(1 + point.l * point.s * z, 1 / point.l);

    if (value.isNaN || value.isInfinite || value <= 0) return null;
    return value;
  }

  /// Avalia uma medição completa.
  GrowthAssessment? assess({
    required GrowthIndicator indicator,
    required ChildSex sex,
    required double ageMonths,
    required double value,
  }) {
    final double? z = zScore(
      indicator: indicator,
      sex: sex,
      ageMonths: ageMonths,
      value: value,
    );
    final LmsPoint? point = pointAt(indicator, sex, ageMonths);
    if (z == null || point == null) return null;

    return GrowthAssessment(
      indicator: indicator,
      value: value,
      ageMonths: ageMonths.round(),
      zScore: z,
      percentile: percentileFromZ(z),
      median: point.m,
    );
  }

  /// Converte escore-Z em percentil pela função de distribuição normal.
  ///
  /// Usa a aproximação de Abramowitz & Stegun (7.1.26) para a função erro:
  /// precisão de ~1e-7, muito além do necessário para exibir "percentil 42".
  static double percentileFromZ(double z) {
    const double a1 = 0.254829592;
    const double a2 = -0.284496736;
    const double a3 = 1.421413741;
    const double a4 = -1.453152027;
    const double a5 = 1.061405429;
    const double p = 0.3275911;

    final double x = z / math.sqrt2;
    final int sign = x < 0 ? -1 : 1;
    final double absX = x.abs();

    final double t = 1 / (1 + p * absX);
    final double y = 1 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) *
            t *
            math.exp(-absX * absX);

    final double erf = sign * y;
    return (0.5 * (1 + erf) * 100).clamp(0, 100);
  }

  /// Série de referência para desenhar uma linha do gráfico.
  List<({double month, double value})> referenceLine({
    required GrowthIndicator indicator,
    required ChildSex sex,
    required double z,
    required int fromMonth,
    required int toMonth,
  }) {
    final List<({double month, double value})> points =
        <({double month, double value})>[];

    // Passo de 1 mês no primeiro ano (onde a curva muda rápido) e de 3 meses
    // depois — mantém o gráfico leve sem perder a forma.
    for (int month = fromMonth; month <= toMonth; month += month < 24 ? 1 : 3) {
      final double? value = valueForZ(
        indicator: indicator,
        sex: sex,
        ageMonths: month.toDouble(),
        z: z,
      );
      if (value != null) points.add((month: month.toDouble(), value: value));
    }
    return points;
  }
}
