/// PDF dos documentos clínicos.
///
/// Usa só as fontes padrão do PDF (Helvetica), sem baixar nada da rede, para
/// funcionar também sob a política de segurança da versão web.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'clinical_documents.dart';
import 'dose_calculator.dart';

class ClinicalPdf {
  const ClinicalPdf._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF0E2A66);
  static const PdfColor _muted = PdfColor.fromInt(0xFF4A5B7A);
  static const PdfColor _line = PdfColor.fromInt(0xFFCBD5E4);
  static const PdfColor _danger = PdfColor.fromInt(0xFFD42A42);

  static String fileName(ClinicalDocRecord doc, String patientName) {
    final String who = patientName
        .split(' ')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${doc.kind.slug}-$who-v${doc.current.number}.pdf';
  }

  /// As fontes padrão do PDF só cobrem Latin-1; o resto vira equivalente
  /// simples em vez de quebrar a geração.
  static String sanitize(String text) {
    const Map<String, String> map = <String, String>{
      '\u2014': '-',
      '\u2013': '-',
      '\u2212': '-',
      '\u2018': "'",
      '\u2019': "'",
      '\u201C': '"',
      '\u201D': '"',
      '\u2026': '...',
      '\u2022': '-',
      '\u2265': '>=',
      '\u2264': '<=',
      '\u2192': '->',
    };
    final StringBuffer b = StringBuffer();
    for (final int r in text.runes) {
      final String ch = String.fromCharCode(r);
      if (map.containsKey(ch)) {
        b.write(map[ch]);
      } else if (r == 0x0A ||
          (r >= 0x20 && r <= 0x7E) ||
          (r >= 0xA0 && r <= 0xFF)) {
        b.write(ch);
      } else {
        b.write('?');
      }
    }
    return b.toString();
  }

  static Future<Uint8List> build({
    required ClinicalDocRecord doc,
    required DocContext context,
    required DateTime now,
    bool demo = false,
  }) async {
    final DocVersion v = doc.current;
    final bool issued = v.status == DocStatus.issued;
    String s(String t) => sanitize(t);

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );
    const pw.TextStyle small = pw.TextStyle(fontSize: 8.5, color: _muted);

    final List<String> watermark = <String>[
      if (!issued) 'RASCUNHO - SEM VALIDADE',
      if (demo) 'DEMONSTRACAO',
    ];

    final pw.Document pdf = pw.Document(
      title: s('${doc.title} - ${context.patientName}'),
      author: s(v.author),
      creator: 'Pediatria 360',
    );

    final String? age = context.patientBirthDate == null
        ? null
        : formatAgeMonths(ageInMonths(context.patientBirthDate!, context.date));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
          theme: theme,
          buildBackground: watermark.isEmpty
              ? null
              : (pw.Context c) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: 0.55,
                      child: pw.Opacity(
                        opacity: 0.10,
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: <pw.Widget>[
                            for (final String w in watermark)
                              pw.Text(
                                w,
                                style: const pw.TextStyle(
                                  fontSize: 44,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _danger,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        header: (pw.Context c) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          margin: const pw.EdgeInsets.only(bottom: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      s(context.clinicName ?? context.professionalName),
                      style: const pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.Text(
                      s(
                        <String>[
                          context.professionalName,
                          context.professionalRegistry,
                          if (context.professionalSpecialty != null)
                            context.professionalSpecialty!,
                        ].join(' - '),
                      ),
                      style: small,
                    ),
                    if (context.clinicAddress != null)
                      pw.Text(s(context.clinicAddress!), style: small),
                  ],
                ),
              ),
              pw.Text(
                s(doc.kind.label.toUpperCase()),
                style: const pw.TextStyle(
                  fontSize: 10,
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
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(
                    child: pw.Text(
                      s(
                        'Versão ${v.number} - ${v.status.label}'
                        '${v.issuedAt == null ? '' : ' em ${formatDocDateTime(v.issuedAt!)}'}'
                        ' - autor: ${v.author} - ${doc.signature.label}',
                      ),
                      style: small,
                    ),
                  ),
                  pw.Text('${c.pageNumber}/${c.pagesCount}', style: small),
                ],
              ),
              if (demo)
                pw.Text(
                  s(
                    'DEMONSTRAÇÃO - dados fictícios, documento sem validade. '
                    'Gerado em ${formatDocDateTime(now)}.',
                  ),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _danger,
                  ),
                ),
            ],
          ),
        ),
        build: (pw.Context c) => <pw.Widget>[
          pw.Text(
            s(doc.title),
            style: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _kv('Paciente', s(context.patientName)),
                if (context.patientBirthDate != null)
                  _kv(
                    'Nascimento',
                    s('${formatDocDate(context.patientBirthDate!)} ($age)'),
                  ),
                if (context.guardianName != null)
                  _kv('Responsável', s(context.guardianName!)),
                if (doc.kind == DocKind.receituario) ...<pw.Widget>[
                  _kv(
                    'Peso',
                    context.weightKg == null
                        ? 'não registrado'
                        : s(
                            '${formatDoseNumber(context.weightKg!)} kg'
                            '${context.weighedAt == null ? '' : ' (pesado em ${formatDocDate(context.weighedAt!)})'}',
                          ),
                  ),
                  _kv(
                    'Alergias',
                    s(
                      context.allergies.isEmpty
                          ? 'nenhuma registrada'
                          : context.allergies.join(', '),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          for (final String para in v.body.split('\n'))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                para.isEmpty ? ' ' : s(para),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
            ),
          pw.SizedBox(height: 28),
          pw.Text(
            s(
              '${context.city ?? ''}${context.city == null ? '' : ', '}'
              '${formatDocDate(context.date)}',
            ),
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 44),
          pw.Container(width: 240, height: 0.8, color: _navy),
          pw.SizedBox(height: 4),
          pw.Text(
            s(context.professionalName),
            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(s(context.professionalRegistry), style: small),
          pw.SizedBox(height: 10),
          pw.Text(
            s(
              doc.signature.isSigned
                  ? doc.signature.label
                  : '${doc.signature.label}. Assinatura digital '
                        '(${doc.kind.signatureRequirement.digital}) não configurada; '
                        'para validade, assinar manualmente: '
                        '${doc.kind.signatureRequirement.printed}',
            ),
            style: small,
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: <pw.TextSpan>[
          pw.TextSpan(
            text: '$k: ',
            style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
}
