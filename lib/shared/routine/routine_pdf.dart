/// PDF do resumo da rotina que a família leva ou envia ao pediatra.
///
/// Só fontes padrão do PDF, como os demais documentos da versão web.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../clinical/clinical_pdf.dart';
import 'child_routine.dart';

class RoutinePdf {
  const RoutinePdf._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF0E2A66);
  static const PdfColor _muted = PdfColor.fromInt(0xFF4A5B7A);
  static const PdfColor _family = PdfColor.fromInt(0xFF0B6B8A);

  static String fileName(String patientName, DateTime at) {
    final String who = patientName
        .split(' ')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String d =
        '${at.year}${at.month.toString().padLeft(2, '0')}'
        '${at.day.toString().padLeft(2, '0')}';
    return 'resumo-rotina-$who-$d.pdf';
  }

  /// [text] é o mesmo texto de [RoutineSummary.toText]: a primeira linha
  /// vira título e as linhas sem "- " viram subtítulos.
  static Future<Uint8List> build({
    required String text,
    required String patientName,
    required String guardianName,
    bool demo = false,
  }) async {
    String s(String t) => ClinicalPdf.sanitize(t);
    final List<String> lines = text.split('\n');
    final String title = lines.isEmpty ? 'Resumo da rotina' : lines.first;
    final pw.Document pdf = pw.Document(
      title: s(title),
      author: s(guardianName),
      creator: 'Pediatria 360',
    );
    final List<pw.Widget> body = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFE3F2F7),
          border: pw.Border.all(color: _family),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          s('INFORMADO PELA FAMÍLIA'),
          style: const pw.TextStyle(
            fontSize: 9,
            color: _family,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        s(title),
        style: const pw.TextStyle(
          fontSize: 16,
          color: _navy,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
    ];
    for (final String raw in lines.skip(1)) {
      final String line = raw.trimRight();
      if (line.isEmpty) {
        body.add(pw.SizedBox(height: 6));
      } else if (line.startsWith('- ')) {
        body.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
            child: pw.Text(s(line), style: const pw.TextStyle(fontSize: 10)),
          ),
        );
      } else if (const <String>[
        'Totais',
        'Registros',
        'Próximos compromissos',
      ].contains(line)) {
        body.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              s(line),
              style: const pw.TextStyle(
                fontSize: 12,
                color: _navy,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        body.add(
          pw.Text(
            s(line),
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
        );
      }
    }
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
                          style: const pw.TextStyle(fontSize: 72, color: _navy),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        footer: (pw.Context c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            s('$patientName - página ${c.pageNumber} de ${c.pagesCount}'),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (pw.Context c) => body,
      ),
    );
    return pdf.save();
  }
}
