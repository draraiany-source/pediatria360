import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../domain/who_reference.dart';

/// Curva de crescimento com as linhas de referência da OMS ao fundo e as
/// medições da criança por cima.
///
/// As linhas mostradas são z = -3, -2, 0, +2, +3. É a mesma leitura da
/// Caderneta da Criança: o que importa não é o ponto isolado, e sim se a
/// trajetória acompanha as curvas ou as cruza.
class GrowthChart extends StatelessWidget {
  const GrowthChart({
    required this.indicator,
    required this.child,
    required this.records,
    required this.reference,
    super.key,
  });

  final GrowthIndicator indicator;
  final Child child;
  final List<GrowthRecord> records;
  final WhoReference reference;

  /// Extrai o valor do indicador de um registro.
  double? _valueOf(GrowthRecord record) => switch (indicator) {
        GrowthIndicator.weightForAge => record.weightKg,
        GrowthIndicator.heightForAge => record.heightCm,
        GrowthIndicator.headForAge => record.headCircumferenceCm,
        GrowthIndicator.bmiForAge => record.bmi,
      };

  /// Idade em meses na data da medição, com correção para prematuros.
  double _ageAt(DateTime at) {
    int months = (at.year - child.birthDate.year) * 12 +
        (at.month - child.birthDate.month);
    if (at.day < child.birthDate.day) months -= 1;
    if (months < 0) months = 0;

    if (child.isPreterm && months <= 24) {
      final int weeksMissing = 40 - child.gestationalWeeks!;
      final int corrected = months - (weeksMissing / 4.345).round();
      return (corrected < 0 ? 0 : corrected).toDouble();
    }
    return months.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<FlSpot> measured = <FlSpot>[
      for (final GrowthRecord record in records)
        if (_valueOf(record) != null)
          FlSpot(_ageAt(record.measuredAt), _valueOf(record)!),
    ]..sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));

    // Janela de idade: mostra até 6 meses além da última medição, para o
    // responsável enxergar para onde a curva aponta.
    final double lastAge = measured.isEmpty ? 12 : measured.last.x;
    final int maxMonth = ((lastAge + 6).ceil())
        .clamp(6, indicator.maxAgeMonths)
        .toInt();

    final Map<double, Color> zLines = <double, Color>{
      -3: AppColors.danger.withValues(alpha: 0.55),
      -2: AppColors.warning.withValues(alpha: 0.65),
      0: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      2: AppColors.warning.withValues(alpha: 0.65),
      3: AppColors.danger.withValues(alpha: 0.55),
    };

    final List<LineChartBarData> bars = <LineChartBarData>[
      for (final MapEntry<double, Color> entry in zLines.entries)
        _referenceBar(entry.key, entry.value, maxMonth),
      if (measured.isNotEmpty)
        LineChartBarData(
          spots: measured,
          isCurved: true,
          curveSmoothness: 0.22,
          preventCurveOverShooting: true,
          color: AppColors.vital,
          barWidth: 3,
          dotData: FlDotData(
            getDotPainter: (FlSpot spot, double _, LineChartBarData __, int ___) =>
                FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: AppColors.vital,
            ),
          ),
        ),
    ];

    final double? minY = _minY(bars);
    final double? maxY = _maxY(bars);

    return AspectRatio(
      aspectRatio: 1.35,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md, top: AppSpacing.md),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxMonth.toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: bars,
            gridData: FlGridData(
              drawVerticalLine: true,
              horizontalInterval: _yInterval(minY, maxY),
              verticalInterval: maxMonth <= 24 ? 3 : 12,
              getDrawingHorizontalLine: (double value) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (double value) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(color: theme.colorScheme.outlineVariant),
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                axisNameWidget: Text(
                  child.isPreterm
                      ? 'Idade corrigida (meses)'
                      : 'Idade (meses)',
                  style: theme.textTheme.bodySmall,
                ),
                axisNameSize: 22,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: maxMonth <= 24 ? 6 : 12,
                  getTitlesWidget: (double value, TitleMeta meta) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      value.toInt().toString(),
                      style: AppTypography.data(
                        theme.colorScheme.onSurfaceVariant,
                        size: 10,
                      ),
                    ),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: Text(
                  indicator.unit,
                  style: theme.textTheme.bodySmall,
                ),
                axisNameSize: 20,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: _yInterval(minY, maxY),
                  getTitlesWidget: (double value, TitleMeta meta) => Text(
                    value.toStringAsFixed(value < 10 ? 1 : 0),
                    style: AppTypography.data(
                      theme.colorScheme.onSurfaceVariant,
                      size: 10,
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (LineBarSpot spot) =>
                    theme.colorScheme.inverseSurface,
                getTooltipItems: (List<LineBarSpot> spots) => spots
                    .map(
                      (LineBarSpot spot) => spot.barIndex < zLines.length
                          ? null
                          : LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)} ${indicator.unit}\n'
                              '${spot.x.toInt()} meses',
                              theme.textTheme.bodySmall!.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _referenceBar(double z, Color color, int maxMonth) {
    final List<({double month, double value})> points =
        reference.referenceLine(
      indicator: indicator,
      sex: child.sex,
      z: z,
      fromMonth: 0,
      toMonth: maxMonth,
    );

    return LineChartBarData(
      spots: <FlSpot>[
        for (final ({double month, double value}) p in points)
          FlSpot(p.month, p.value),
      ],
      isCurved: true,
      curveSmoothness: 0.15,
      preventCurveOverShooting: true,
      color: color,
      barWidth: z == 0 ? 1.6 : 1,
      dotData: const FlDotData(show: false),
      dashArray: z == 0 ? null : <int>[5, 4],
    );
  }

  double? _minY(List<LineChartBarData> bars) {
    double? min;
    for (final LineChartBarData bar in bars) {
      for (final FlSpot spot in bar.spots) {
        if (min == null || spot.y < min) min = spot.y;
      }
    }
    if (min == null) return null;
    return (min * 0.92).floorToDouble();
  }

  double? _maxY(List<LineChartBarData> bars) {
    double? max;
    for (final LineChartBarData bar in bars) {
      for (final FlSpot spot in bar.spots) {
        if (max == null || spot.y > max) max = spot.y;
      }
    }
    if (max == null) return null;
    return (max * 1.06).ceilToDouble();
  }

  double _yInterval(double? min, double? max) {
    if (min == null || max == null) return 5;
    final double range = max - min;
    if (range <= 6) return 1;
    if (range <= 15) return 2;
    if (range <= 40) return 5;
    if (range <= 90) return 10;
    return 20;
  }
}

/// Legenda do gráfico. Sem ela, as linhas tracejadas não significam nada para
/// quem não é profissional de saúde.
class GrowthChartLegend extends StatelessWidget {
  const GrowthChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget item(Color color, String label, {bool dashed = true}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 18,
              height: 2.5,
              child: CustomPaint(
                painter: _LinePainter(color: color, dashed: dashed),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        item(AppColors.vital, 'Sua criança', dashed: false),
        item(
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          'Mediana',
        ),
        item(AppColors.warning.withValues(alpha: 0.65), 'Limites (±2 DP)'),
        item(AppColors.danger.withValues(alpha: 0.55), 'Alerta (±3 DP)'),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    const double dash = 4;
    const double gap = 3;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
