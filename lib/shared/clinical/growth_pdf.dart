/// PDF das curvas de crescimento (visão do profissional).
///
/// Usa só as fontes padrão do PDF, como os documentos clínicos, para
/// funcionar sob a política de segurança da versão web.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../branding/brand_pdf.dart';
import 'clinical_pdf.dart';
import 'growth.dart';

class GrowthPdf {
  const GrowthPdf._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF0E2A66);
  static const PdfColor _muted = PdfColor.fromInt(0xFF4A5B7A);
  static const PdfColor _line = PdfColor.fromInt(0xFFCBD5E4);
  static const PdfColor _danger = PdfColor.fromInt(0xFFD42A42);
  static const PdfColor _point = PdfColor.fromInt(0xFF0B6BCB);

  static PdfColor _zColor(double z) => switch (z.abs().round()) {
    3 => const PdfColor.fromInt(0xFFB00020),
    2 => const PdfColor.fromInt(0xFFE07A00),
    _ => const PdfColor.fromInt(0xFF1B7F3B),
  };

  static String fileName(String patientName, DateTime now) {
    final String who = patientName
        .split(' ')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String d =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'curvas-$who-$d.pdf';
  }

  static Future<Uint8List> build({
    required WhoGrowthTables tables,
    required List<GrowthMeasurement> measurements,
    required GrowthSex sex,
    required String patientName,
    required DateTime birthDate,
    required String professionalName,
    required String professionalRegistry,
    required DateTime now,
    int? gestationalAgeDays,
    String? guardianName,
    String? clinicName,
    Uint8List? logo,
    bool demo = false,
  }) async {
    String s(String t) => ClinicalPdf.sanitize(t);
    final GrowthCalculator calc = GrowthCalculator(tables);
    const pw.TextStyle small = pw.TextStyle(fontSize: 8.5, color: _muted);
    const pw.TextStyle cell = pw.TextStyle(fontSize: 8.5);

    final pw.Document pdf = pw.Document(
      title: s('Curvas de crescimento - $patientName'),
      author: s(professionalName),
      creator: 'Pediatria 360',
    );

    final bool preterm =
        gestationalAgeDays != null &&
        gestationalAgeDays < GrowthAge.pretermBelowDays;

    final List<pw.Widget> body = <pw.Widget>[
      pw.Text(
        'Curvas de crescimento',
        style: const pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
      ),
      pw.SizedBox(height: 8),
      _box(<pw.Widget>[
        _kv('Paciente', s(patientName)),
        _kv(
          'Nascimento',
          s(
            '${formatGrowthDate(birthDate)} - idade atual '
            '${GrowthAge.of(birthDate: birthDate, at: now).chronologicalLabel}',
          ),
        ),
        _kv('Sexo', s(sex.label)),
        _kv(
          'Idade gestacional ao nascer',
          gestationalAgeDays == null
              ? 'não informada'
              : s(
                  '${formatGestationalAge(gestationalAgeDays)}'
                  '${preterm ? ' (prematuro: idade corrigida até 24 meses)' : ''}',
                ),
        ),
        if (guardianName != null) _kv('Responsável', s(guardianName)),
      ]),
      pw.SizedBox(height: 6),
      pw.Text(
        s(
          'Referências: ${tables.references['who2006']}; '
          '${tables.references['who2007']}. Tabelas LMS oficiais da OMS '
          '(versão ${tables.version}). Escore Z pelo método LMS; peso e IMC '
          'com o método restrito da OMS além de ±3. Comprimento deitado até '
          '24 meses e altura em pé depois (ajuste de 0,7 cm quando a posição '
          'não corresponde à idade).',
        ),
        style: small,
      ),
    ];

    for (final GrowthIndicator g in GrowthIndicator.values) {
      final List<GrowthPoint> points = calc.series(
        measurements: measurements,
        indicator: g,
        sex: sex,
        birthDate: birthDate,
        gestationalAgeDays: gestationalAgeDays,
      );
      if (points.isEmpty) continue;
      final GrowthPoint last = points.last;
      final GrowthWindow window = GrowthWindow.forAge(
        math.max(0, last.age.referenceDays),
      );
      final List<GrowthPoint> inWindow = <GrowthPoint>[
        for (final GrowthPoint p in points)
          if (p.z != null &&
              p.age.referenceDays >= window.fromDays - 1 &&
              p.age.referenceDays <= window.toDays + 1)
            p,
      ];
      body
        ..add(pw.SizedBox(height: 14))
        ..add(
          pw.Text(
            s('${g.title} (${g.unit}) - ${window.label}'),
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        );
      if (tables.maxAgeDays(g) > window.fromDays) {
        body.add(
          pw.SizedBox(
            height: 200,
            child: _chart(calc, g, sex, window, inWindow),
          ),
        );
        body.add(
          pw.Text(
            s(
              'Linhas: escores Z -3, -2, 0 (mediana), +2 e +3. Pontos: medidas '
              'do paciente${preterm ? ' pela idade corrigida' : ''}.',
            ),
            style: small,
          ),
        );
      }
      body
        ..add(pw.SizedBox(height: 4))
        ..add(
          pw.TableHelper.fromTextArray(
            headerStyle: const pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: cell,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEAF0F8),
            ),
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: <pw.TableColumnWidth>[
              const pw.FixedColumnWidth(54),
              const pw.FixedColumnWidth(62),
              if (preterm) const pw.FixedColumnWidth(66),
              const pw.FixedColumnWidth(48),
              const pw.FlexColumnWidth(),
              const pw.FixedColumnWidth(38),
              const pw.FixedColumnWidth(46),
            ].asMap(),
            headers: <String>[
              'Data',
              'Idade',
              if (preterm) 'Idade corrigida',
              'Valor',
              'Referência',
              'Z',
              'Percentil',
            ].map(s).toList(),
            data: <List<String>>[
              for (final GrowthPoint p in points)
                <String>[
                  formatGrowthDate(p.measurement.values.date),
                  p.age.chronologicalLabel,
                  if (preterm)
                    p.age.correctedDays == null ? '-' : p.age.correctedLabel!,
                  '${formatGrowthNumber(p.measured, g == GrowthIndicator.weightForAge ? 3 : 1)}'
                      '${p.adjustment == null ? '' : ' *'}'
                      '${p.measurement.wasCorrected ? ' (c)' : ''}',
                  p.lookup == null
                      ? (p.unavailable ?? '-')
                      : '${p.lookup!.referenceId == 'who2006' ? 'OMS 2006' : 'OMS 2007'}'
                            '${p.lookup!.measure == null
                                ? ''
                                : p.lookup!.measure == 'length'
                                ? ' comprimento'
                                : ' altura'}',
                  p.z == null ? '-' : formatZ(p.z!),
                  p.z == null ? '-' : formatPercentile(p.z!),
                ].map(s).toList(),
            ],
          ),
        );
      if (points.any((GrowthPoint p) => p.adjustment != null)) {
        body.add(
          pw.Text(
            s('* Valor ajustado em 0,7 cm pela posição da medida.'),
            style: small,
          ),
        );
      }
    }

    final List<GrowthMeasurement> corrected = <GrowthMeasurement>[
      for (final GrowthMeasurement m in measurements)
        if (m.revisions.isNotEmpty) m,
    ];
    if (corrected.isNotEmpty) {
      body
        ..add(pw.SizedBox(height: 14))
        ..add(
          pw.Text(
            s('Histórico de correções (c)'),
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        );
      for (final GrowthMeasurement m in corrected) {
        for (final GrowthRevision r in m.revisions) {
          body.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                s(
                  '${formatGrowthDate(r.at)} - ${r.author} - '
                  '${r.voided ? 'Anulado' : 'Corrigido'}: ${r.reason}. '
                  'Antes: ${r.before.summary()}.'
                  '${r.voided ? '' : ' Depois: ${r.after.summary()}.'}',
                ),
                style: cell,
              ),
            ),
          );
        }
      }
    }

    body
      ..add(pw.SizedBox(height: 16))
      ..add(
        pw.Text(
          s(
            'Este relatório apresenta cálculos sobre as medidas registradas. '
            'A interpretação é do profissional responsável.',
          ),
          style: small,
        ),
      );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
          buildBackground: !demo
              ? null
              : (pw.Context c) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: 0.55,
                      child: pw.Opacity(
                        opacity: 0.08,
                        child: pw.Text(
                          'DEMONSTRACAO',
                          style: const pw.TextStyle(
                            fontSize: 60,
                            fontWeight: pw.FontWeight.bold,
                            color: _danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        header: (pw.Context c) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            children: <pw.Widget>[
              BrandPdf.mark(logo, height: 30),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Text(
                  s(
                    '${clinicName ?? professionalName} - '
                    '$professionalName - $professionalRegistry',
                  ),
                  style: small,
                ),
              ),
              pw.Text(
                'CURVAS DE CRESCIMENTO',
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
            ],
          ),
        ),
        footer: (pw.Context c) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  s(
                    '${demo ? 'DEMONSTRAÇÃO - dados fictícios. ' : ''}'
                    'Gerado em ${formatGrowthDate(now)} por $professionalName.',
                  ),
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: demo ? _danger : _muted,
                    fontWeight: demo ? pw.FontWeight.bold : null,
                  ),
                ),
              ),
              pw.Text('${c.pageNumber}/${c.pagesCount}', style: small),
            ],
          ),
        ),
        build: (pw.Context c) => body,
      ),
    );
    return pdf.save();
  }

  static pw.Widget _chart(
    GrowthCalculator calc,
    GrowthIndicator g,
    GrowthSex sex,
    GrowthWindow window,
    List<GrowthPoint> points,
  ) {
    final Map<double, List<(double, double)>> curves =
        <double, List<(double, double)>>{
          for (final double z in kGrowthZLines)
            z: calc.curve(
              indicator: g,
              sex: sex,
              z: z,
              fromDays: window.fromDays,
              toDays: window.toDays,
            ),
        };
    final double x0 = window.fromDays / daysPerMonth;
    final double x1 =
        math.min(window.toDays, calc.tables.maxAgeDays(g)) / daysPerMonth;
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
    final double yStep = niceGrowthStep((yMax - yMin) / 6);
    yMin = (yMin / yStep).floorToDouble() * yStep;
    yMax = (yMax / yStep).ceilToDouble() * yStep;
    final double xStep = x1 - x0 <= 25 ? 3 : (x1 - x0 <= 40 ? 6 : 12);

    List<num> ticks(double a, double b, double step) => <num>[
      for (double v = a; v <= b + 1e-6; v += step) v,
    ];

    String fmt(num v) => formatGrowthNumber(v.toDouble(), 1);

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis<num>(
          ticks(x0, x1, xStep),
          format: (num v) => '${v.round()}',
          textStyle: const pw.TextStyle(fontSize: 7, color: _muted),
          divisions: true,
          divisionsColor: _line,
          divisionsWidth: 0.3,
        ),
        yAxis: pw.FixedAxis<num>(
          ticks(yMin, yMax, yStep),
          format: fmt,
          textStyle: const pw.TextStyle(fontSize: 7, color: _muted),
          divisions: true,
          divisionsColor: _line,
          divisionsWidth: 0.3,
        ),
      ),
      datasets: <pw.Dataset>[
        for (final MapEntry<double, List<(double, double)>> e in curves.entries)
          pw.LineDataSet(
            drawPoints: false,
            lineWidth: e.key == 0 ? 1.2 : 0.8,
            color: _zColor(e.key),
            data: <pw.PointChartValue>[
              for (final (double, double) p in e.value)
                pw.PointChartValue(p.$1, p.$2),
            ],
          ),
        if (points.isNotEmpty)
          pw.LineDataSet(
            drawPoints: true,
            pointSize: 2.5,
            lineWidth: 1,
            color: _point,
            data: <pw.PointChartValue>[
              for (final GrowthPoint p in points)
                pw.PointChartValue(p.ageMonths, p.value!),
            ],
          ),
      ],
    );
  }

  static pw.Widget _box(List<pw.Widget> children) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    ),
  );

  static pw.Widget _kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: <pw.TextSpan>[
          pw.TextSpan(
            text: '$k: ',
            style: const pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
}

/// Passo "redondo" (1, 2, 2,5 ou 5 x 10^n) para eixos de gráfico.
double niceGrowthStep(double raw) {
  if (raw <= 0) return 1;
  final double p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final double m in <double>[1, 2, 2.5, 5, 10]) {
    if (raw <= m * p) return m * p;
  }
  return 10 * p;
}
