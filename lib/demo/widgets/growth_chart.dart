import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/growth_pdf.dart' show niceGrowthStep;

/// Curva da OMS com as medidas do paciente.
///
/// `simple` mostra só a faixa entre -2 e +2 escores Z e a mediana, sem
/// números de escore: é a visão do responsável.
class GrowthChart extends StatelessWidget {
  const GrowthChart({
    required this.calc,
    required this.indicator,
    required this.sex,
    required this.window,
    required this.points,
    super.key,
    this.simple = false,
    this.height = 300,
  });

  final GrowthCalculator calc;
  final GrowthIndicator indicator;
  final GrowthSex sex;
  final GrowthWindow window;
  final List<GrowthPoint> points;
  final bool simple;
  final double height;

  static Color zColor(double z) => switch (z.abs().round()) {
    3 => const Color(0xFFB00020),
    2 => const Color(0xFFC2570C),
    _ => const Color(0xFF12877A),
  };

  @override
  Widget build(BuildContext context) {
    final Map<double, List<(double, double)>> curves =
        <double, List<(double, double)>>{
          for (final double z in simple ? <double>[-2, 0, 2] : kGrowthZLines)
            z: calc.curve(
              indicator: indicator,
              sex: sex,
              z: z,
              fromDays: window.fromDays,
              toDays: window.toDays,
            ),
        };
    final List<GrowthPoint> visible = <GrowthPoint>[
      for (final GrowthPoint p in points)
        if (p.lookup != null &&
            p.value != null &&
            p.age.referenceDays >= window.fromDays - 1 &&
            p.age.referenceDays <= window.toDays + 1)
          p,
    ];
    final String unit = indicator.unit;
    final String summary = visible.isEmpty
        ? 'nenhuma medida nesta faixa de idade'
        : '${visible.length} ${visible.length == 1 ? 'medida' : 'medidas'}; '
              'última ${formatGrowthNumber(visible.last.value!, 2)} $unit aos '
              '${formatAgeDays(visible.last.age.referenceDays)}';
    return Semantics(
      container: true,
      label: 'Gráfico ${indicator.title}, ${window.label}: $summary.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _GrowthPainter(
              curves: curves,
              points: visible,
              window: window,
              maxDays: calc.tables.maxAgeDays(indicator),
              simple: simple,
              textStyle:
                  Theme.of(context).textTheme.labelSmall ??
                  const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.curves,
    required this.points,
    required this.window,
    required this.maxDays,
    required this.simple,
    required this.textStyle,
  });

  final Map<double, List<(double, double)>> curves;
  final List<GrowthPoint> points;
  final GrowthWindow window;
  final double maxDays;
  final bool simple;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 44;
    const double bottom = 34;
    const double top = 10;
    final double right = simple ? 12 : 30;
    final Rect plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );

    final double x0 = window.fromDays / daysPerMonth;
    final double x1 = math.min(window.toDays, maxDays) / daysPerMonth;
    double yMin = double.infinity;
    double yMax = -double.infinity;
    for (final List<(double, double)> c in curves.values) {
      for (final (double, double) p in c) {
        yMin = math.min(yMin, p.$2);
        yMax = math.max(yMax, p.$2);
      }
    }
    for (final GrowthPoint p in points) {
      yMin = math.min(yMin, p.value!);
      yMax = math.max(yMax, p.value!);
    }
    if (!yMin.isFinite) return;
    final double yStep = niceGrowthStep((yMax - yMin) / 6);
    yMin = (yMin / yStep).floorToDouble() * yStep;
    yMax = (yMax / yStep).ceilToDouble() * yStep;
    final double xStep = x1 - x0 <= 25 ? 3 : (x1 - x0 <= 40 ? 6 : 12);

    Offset at(double x, double y) => Offset(
      plot.left + (x - x0) / (x1 - x0) * plot.width,
      plot.bottom - (y - yMin) / (yMax - yMin) * plot.height,
    );

    final Paint grid = Paint()
      ..color = AppColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 0.7;
    final TextStyle label = textStyle.copyWith(color: AppColors.inkMuted);

    void text(
      String s,
      Offset o, {
      TextAlign align = TextAlign.center,
      TextStyle? style,
    }) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: s, style: style ?? label),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      final double dx = switch (align) {
        TextAlign.right => o.dx - tp.width,
        TextAlign.left => o.dx,
        _ => o.dx - tp.width / 2,
      };
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    for (double y = yMin; y <= yMax + 1e-6; y += yStep) {
      final Offset a = at(x0, y);
      canvas.drawLine(a, Offset(plot.right, a.dy), grid);
      text(
        formatGrowthNumber(y, 1),
        Offset(plot.left - 6, a.dy),
        align: TextAlign.right,
      );
    }
    for (
      double x = (x0 / xStep).ceilToDouble() * xStep;
      x <= x1 + 1e-6;
      x += xStep
    ) {
      final Offset a = at(x, yMin);
      canvas.drawLine(Offset(a.dx, plot.top), a, grid);
      text('${x.round()}', Offset(a.dx, plot.bottom + 10));
    }
    text('Idade (meses)', Offset(plot.center.dx, plot.bottom + 26));

    canvas.save();
    canvas.clipRect(plot.inflate(1));

    if (simple && curves[-2] != null && curves[2] != null) {
      final Path band = Path();
      final List<(double, double)> lo = curves[-2]!;
      final List<(double, double)> hi = curves[2]!;
      for (int i = 0; i < hi.length; i++) {
        final Offset o = at(hi[i].$1, hi[i].$2);
        i == 0 ? band.moveTo(o.dx, o.dy) : band.lineTo(o.dx, o.dy);
      }
      for (int i = lo.length - 1; i >= 0; i--) {
        final Offset o = at(lo[i].$1, lo[i].$2);
        band.lineTo(o.dx, o.dy);
      }
      band.close();
      canvas.drawPath(
        band,
        Paint()..color = AppColors.success.withValues(alpha: 0.13),
      );
    }

    for (final MapEntry<double, List<(double, double)>> e in curves.entries) {
      if (simple && e.key != 0) continue;
      final Path path = Path();
      for (int i = 0; i < e.value.length; i++) {
        final Offset o = at(e.value[i].$1, e.value[i].$2);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.key == 0 ? 2 : 1.3
          ..color = GrowthChart.zColor(e.key),
      );
    }

    if (points.isNotEmpty) {
      final Path line = Path();
      for (int i = 0; i < points.length; i++) {
        final Offset o = at(points[i].ageMonths, points[i].value!);
        i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.navy,
      );
      for (final GrowthPoint p in points) {
        final Offset o = at(p.ageMonths, p.value!);
        canvas.drawCircle(o, 5, Paint()..color = Colors.white);
        canvas.drawCircle(o, 4, Paint()..color = AppColors.brand);
        if (p.measurement.wasCorrected) {
          canvas.drawCircle(
            o,
            7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = AppColors.warning,
          );
        }
      }
    }
    canvas.restore();

    if (!simple) {
      for (final MapEntry<double, List<(double, double)>> e in curves.entries) {
        if (e.value.isEmpty) continue;
        final Offset o = at(e.value.last.$1, e.value.last.$2);
        if (o.dy < plot.top - 4 || o.dy > plot.bottom + 4) continue;
        text(
          e.key == 0
              ? '0'
              : (e.key > 0 ? '+${e.key.round()}' : '${e.key.round()}'),
          Offset(plot.right + 4, o.dy),
          align: TextAlign.left,
          style: label.copyWith(
            color: GrowthChart.zColor(e.key),
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }
    canvas.drawRect(
      plot,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.line,
    );
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter old) =>
      old.curves != curves ||
      old.points != points ||
      old.window != window ||
      old.simple != simple;
}

/// Legenda da curva.
class GrowthChartLegend extends StatelessWidget {
  const GrowthChartLegend({super.key, this.simple = false});

  final bool simple;

  @override
  Widget build(BuildContext context) {
    final TextStyle? t = Theme.of(context).textTheme.bodySmall;
    Widget item(Color c, String label, {bool dot = false, bool band = false}) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: dot ? 10 : 18,
              height: dot ? 10 : (band ? 10 : 3),
              decoration: BoxDecoration(
                color: c,
                shape: dot ? BoxShape.circle : BoxShape.rectangle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: t),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        item(AppColors.brand, 'Medidas da criança', dot: true),
        item(GrowthChart.zColor(0), 'Mediana da OMS'),
        if (simple)
          item(
            AppColors.success.withValues(alpha: 0.25),
            'Faixa de referência da OMS',
            band: true,
          )
        else ...<Widget>[
          item(GrowthChart.zColor(2), 'Escores Z -2 e +2'),
          item(GrowthChart.zColor(3), 'Escores Z -3 e +3'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warning, width: 1.6),
                ),
              ),
              const SizedBox(width: 6),
              Text('Medida corrigida', style: t),
            ],
          ),
        ],
      ],
    );
  }
}
