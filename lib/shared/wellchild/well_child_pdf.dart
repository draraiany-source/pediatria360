/// Resumo da consulta de puericultura em PDF, com a logomarca da conta
/// (ou a identidade padrão do Pediatria360).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../branding/brand_pdf.dart';
import '../clinical/clinical_documents.dart';
import '../clinical/clinical_pdf.dart';
import '../clinical/growth.dart';
import 'age_band.dart';
import 'milestones.dart';
import 'well_child_visit.dart';

/// Medida mostrada no resumo.
class ReportMeasure {
  const ReportMeasure(this.values, {this.current = false});

  final GrowthValues values;

  /// Registrada nesta consulta.
  final bool current;
}

class WellChildPdf {
  const WellChildPdf._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF0E2A66);
  static const PdfColor _muted = PdfColor.fromInt(0xFF4A5B7A);
  static const PdfColor _line = PdfColor.fromInt(0xFFCBD5E4);
  static const PdfColor _soft = PdfColor.fromInt(0xFFF1F5FB);
  static const PdfColor _danger = PdfColor.fromInt(0xFFD42A42);

  static String fileName(String patientName, DateTime date) {
    final String who = patientName
        .split(' ')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    String two(int n) => n.toString().padLeft(2, '0');
    return 'puericultura-$who-${date.year}${two(date.month)}${two(date.day)}.pdf';
  }

  static Future<Uint8List> build({
    required WellChildVisit visit,
    required DocContext context,
    required VisitAge age,
    required bool finished,
    required String author,
    required DateTime now,
    List<ReportMeasure> measures = const <ReportMeasure>[],
    Uint8List? logo,
    bool demo = false,
  }) async {
    String s(String t) => ClinicalPdf.sanitize(t);
    const pw.TextStyle small = pw.TextStyle(fontSize: 8.5, color: _muted);
    const pw.TextStyle body = pw.TextStyle(fontSize: 10, lineSpacing: 1.5);
    final List<String> watermark = <String>[
      if (!finished) 'RASCUNHO',
      if (demo) 'DEMONSTRACAO',
    ];

    final pw.Document pdf = pw.Document(
      title: s('Resumo da consulta de puericultura - ${context.patientName}'),
      author: s(author),
      creator: 'Pediatria 360',
    );

    pw.Widget section(String title, List<pw.Widget> children) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: _soft,
            child: pw.Text(
              s(title),
              style: const pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    );

    List<pw.Widget> paragraphs(String text) => <pw.Widget>[
      for (final String p in text.trim().split('\n'))
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(p.isEmpty ? ' ' : s(p), style: body),
        ),
    ];

    pw.Widget kv(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: <pw.TextSpan>[
            pw.TextSpan(
              text: s('$k: '),
              style: const pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(text: s(v), style: const pw.TextStyle(fontSize: 9.5)),
          ],
        ),
      ),
    );

    final List<ReportMeasure> sorted = List<ReportMeasure>.of(measures)
      ..sort(
        (ReportMeasure a, ReportMeasure b) =>
            b.values.date.compareTo(a.values.date),
      );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
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
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              BrandPdf.mark(logo),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      s(context.clinicName ?? context.professionalName),
                      style: const pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.Text(
                      s(
                        '${context.professionalName} - '
                        '${context.professionalRegistry}',
                      ),
                      style: small,
                    ),
                    if (context.clinicAddress != null)
                      pw.Text(s(context.clinicAddress!), style: small),
                  ],
                ),
              ),
              pw.Text(
                'PUERICULTURA',
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
                        '${finished ? 'Consulta finalizada' : 'Rascunho da consulta'}'
                        ' - ${context.professionalName} - gerado em '
                        '${formatDocDateTime(now)}',
                      ),
                      style: small,
                    ),
                  ),
                  pw.Text('${c.pageNumber}/${c.pagesCount}', style: small),
                ],
              ),
              if (demo)
                pw.Text(
                  s('DEMONSTRAÇÃO - dados fictícios, documento sem validade.'),
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
            'Resumo da consulta de puericultura',
            style: const pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                kv('Paciente', context.patientName),
                if (context.patientBirthDate != null)
                  kv('Nascimento', formatDocDate(context.patientBirthDate!)),
                if (context.guardianName != null)
                  kv('Responsável', context.guardianName!),
                kv('Data da consulta', formatDocDate(context.date)),
                kv(
                  age.usesCorrected ? 'Idade (prematuro)' : 'Idade',
                  age.usesCorrected
                      ? age.label.replaceFirst(
                          'Idade cronológica: ',
                          'cronológica ',
                        )
                      : age.chronologicalLabel,
                ),
                if (visit.templateName != null)
                  kv('Modelo de evolução usado', visit.templateName!),
              ],
            ),
          ),
          if (sorted.isNotEmpty)
            section('Crescimento: medidas desta e das consultas anteriores', <
              pw.Widget
            >[
              pw.TableHelper.fromTextArray(
                headers: <String>[
                  'Data',
                  'Peso',
                  'Comprimento/altura',
                  'PC',
                  '',
                ],
                data: <List<String>>[
                  for (final ReportMeasure m in sorted.take(8))
                    <String>[
                      formatGrowthDate(m.values.date),
                      m.values.weightKg == null
                          ? '-'
                          : '${formatGrowthNumber(m.values.weightKg!, 3)} kg',
                      m.values.lengthCm == null
                          ? '-'
                          : s(
                              '${formatGrowthNumber(m.values.lengthCm!, 1)} cm '
                              '(${m.values.position == MeasurePosition.lying ? 'deitado' : 'em pé'})',
                            ),
                      m.values.headCm == null
                          ? '-'
                          : '${formatGrowthNumber(m.values.headCm!, 1)} cm',
                      m.current ? s('nesta consulta') : '',
                    ],
                ],
                headerStyle: const pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: _soft),
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: _line, width: 0.5),
                  bottom: pw.BorderSide(color: _line, width: 0.5),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3,
                ),
              ),
              if (age.usesCorrected)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    s('Curvas avaliadas pela idade corrigida até 24 meses.'),
                    style: small,
                  ),
                ),
            ]),
          for (final WellChildSection sec in WellChildSection.values)
            if (visit.field(sec).trim().isNotEmpty)
              section(sec.label, paragraphs(visit.field(sec))),
          if (visit.milestones.isNotEmpty)
            section('Marcos do desenvolvimento', <pw.Widget>[
              for (final MilestoneObservation m in visit.milestones)
                pw.Bullet(text: s(m.describe()), style: body),
            ]),
          if (visit.questions.isNotEmpty)
            section('Dúvidas dos responsáveis', <pw.Widget>[
              for (final GuardianQuestion q in visit.questions)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        s('Dúvida: ${q.question}'),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (q.answer.trim().isNotEmpty)
                        pw.Text(s('Orientação: ${q.answer}'), style: body),
                    ],
                  ),
                ),
            ]),
          if (visit.guidance.trim().isNotEmpty)
            section('Orientações dadas', paragraphs(visit.guidance)),
          if (visit.nextVisit != null || visit.followUps.isNotEmpty)
            section('Acompanhamento', <pw.Widget>[
              if (visit.nextVisit != null)
                kv(
                  'Próxima consulta sugerida',
                  formatDocDate(visit.nextVisit!),
                ),
              for (final FollowUpItem f in visit.sortedFollowUps)
                pw.Bullet(
                  text: s('${formatDocDate(f.due)}: ${f.title}'),
                  style: body,
                ),
            ]),
          if (visit.imports.isNotEmpty)
            section('Dados informados pela família', <pw.Widget>[
              for (final FamilyImport i in visit.imports)
                pw.Text(
                  s(
                    '${i.source} (${i.period}) incorporado em '
                    '${i.section.label}, revisado por ${i.reviewedBy} em '
                    '${formatDocDateTime(i.at)}.',
                  ),
                  style: small,
                ),
            ]),
          pw.SizedBox(height: 22),
          pw.Text(
            s(
              '${context.city ?? ''}${context.city == null ? '' : ', '}'
              '${formatDocDate(context.date)}',
            ),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 30),
          pw.Container(width: 220, height: 0.8, color: _navy),
          pw.SizedBox(height: 3),
          pw.Text(
            s(context.professionalName),
            style: const pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(s(context.professionalRegistry), style: small),
        ],
      ),
    );
    return pdf.save();
  }
}
