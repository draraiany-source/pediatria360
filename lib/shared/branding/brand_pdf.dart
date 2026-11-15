/// Marca no cabeçalho dos PDFs: a logomarca da conta ou, sem ela, a
/// identidade padrão do Pediatria360 desenhada com primitivas do PDF (sem
/// arquivo externo, para funcionar sob a política de segurança da web).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BrandPdf {
  const BrandPdf._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF14676B);
  static const PdfColor _coral = PdfColor.fromInt(0xFFE8566C);
  static const PdfColor _sun = PdfColor.fromInt(0xFFF2B705);
  static const PdfColor _navy = PdfColor.fromInt(0xFF0E2A66);

  /// O cabeçalho do arquivo pode estar certo e o resto corrompido: a
  /// imagem só é aceita se de fato entra num PDF.
  static Future<bool> canEmbed(Uint8List bytes) async {
    try {
      final pw.Document doc = pw.Document()
        ..addPage(
          pw.Page(
            build: (pw.Context c) =>
                pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        );
      await doc.save();
      return true;
    } catch (_) {
      return false;
    }
  }

  static pw.Widget mark(Uint8List? logo, {double height = 40}) {
    if (logo != null) {
      try {
        return pw.Container(
          height: height,
          constraints: pw.BoxConstraints(maxWidth: height * 3.5),
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
        );
      } catch (_) {
        // Imagem ilegível: vale a identidade padrão.
      }
    }
    return defaultMark(height: height);
  }

  static pw.Widget defaultMark({double height = 40}) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: <pw.Widget>[
      pw.CustomPaint(
        size: PdfPoint(height * 0.8, height * 0.8),
        painter: (PdfGraphics g, PdfPoint s) {
          final double r = s.x / 2;
          g
            ..setStrokeColor(_teal)
            ..setLineWidth(s.x * 0.09)
            ..drawEllipse(r, r, r * 0.8, r * 0.8)
            ..strokePath()
            ..setStrokeColor(_coral)
            ..setLineWidth(s.x * 0.07)
            ..moveTo(s.x * 0.27, s.y * 0.36)
            ..curveTo(
              s.x * 0.45,
              s.y * 0.38,
              s.x * 0.60,
              s.y * 0.50,
              s.x * 0.71,
              s.y * 0.63,
            )
            ..strokePath()
            ..setFillColor(_sun)
            ..drawEllipse(s.x * 0.73, s.y * 0.65, s.x * 0.08, s.x * 0.08)
            ..fillPath();
        },
      ),
      pw.SizedBox(width: 6),
      pw.Text(
        'Pediatria 360',
        style: pw.TextStyle(
          fontSize: height * 0.3,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
      ),
    ],
  );
}
