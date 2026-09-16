import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../shared/domain/entities/encounter.dart';

/// Geração de PDF dos documentos clínicos.
///
/// ## Decisões de layout que não são estéticas
///
/// **Cabeçalho e rodapé em toda página.** Uma receita de duas folhas onde a
/// segunda não identifica o prescritor é meia receita — a farmácia recusa, e
/// com razão.
///
/// **Código de conferência em destaque.** É por ele que farmácia, escola e
/// empregador validam o documento. Enterrado no rodapé, ninguém usa.
///
/// **Aviso de assinatura quando não há certificado.** Enquanto a integração
/// ICP-Brasil não existir, o documento vale como registro interno. Omitir isso
/// levaria o médico a entregar um papel que ele acredita ter validade legal
/// plena e não tem.
///
/// **Medicamento controlado muda o cabeçalho.** Receituário de controle
/// especial tem exigências próprias e não pode sair no mesmo modelo.
class ClinicalPdfService {
  const ClinicalPdfService._();

  static const PdfColor _petrol = PdfColor.fromInt(0xFF14676B);
  static const PdfColor _ink = PdfColor.fromInt(0xFF17262A);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5C7176);
  static const PdfColor _line = PdfColor.fromInt(0xFFD5E0E1);
  static const PdfColor _alert = PdfColor.fromInt(0xFFB3261E);

  /// Gera o PDF de um documento clínico.
  static Future<Uint8List> build({
    required ClinicalDocument document,
    required String clinicName,
    String? clinicAddress,
    String? clinicPhone,
    String? patientBirthDateLabel,
    String? patientDocument,
  }) async {
    final pw.Document pdf = pw.Document(
      title: '${document.type.label} — ${document.patientName ?? ''}',
      author: document.professionalName,
    );

    final pw.Font regular = await PdfGoogleFonts.interRegular();
    final pw.Font bold = await PdfGoogleFonts.interSemiBold();
    final pw.Font mono = await PdfGoogleFonts.jetBrainsMonoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 56),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (pw.Context context) => _header(
          document: document,
          clinicName: clinicName,
          clinicAddress: clinicAddress,
          clinicPhone: clinicPhone,
          bold: bold,
        ),
        footer: (pw.Context context) => _footer(
          document: document,
          context: context,
          mono: mono,
        ),
        build: (pw.Context context) => <pw.Widget>[
          _patientBlock(
            document: document,
            bold: bold,
            birthDateLabel: patientBirthDateLabel,
            patientDocument: patientDocument,
          ),
          pw.SizedBox(height: 20),
          if (document.type == ClinicalDocumentType.prescription)
            ..._prescriptionBody(document, bold, mono)
          else
            ..._textBody(document, bold),
          pw.SizedBox(height: 28),
          _signatureBlock(document, bold),
          if (document.cancelled) ...<pw.Widget>[
            pw.SizedBox(height: 16),
            _cancelledBanner(document, bold),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Abre o diálogo de impressão ou compartilhamento do sistema.
  static Future<void> printDocument({
    required ClinicalDocument document,
    required String clinicName,
    String? clinicAddress,
    String? clinicPhone,
  }) =>
      Printing.layoutPdf(
        name: '${document.type.label}_${document.id.substring(0, 6)}',
        onLayout: (PdfPageFormat format) => build(
          document: document,
          clinicName: clinicName,
          clinicAddress: clinicAddress,
          clinicPhone: clinicPhone,
        ),
      );

  static Future<void> share({
    required ClinicalDocument document,
    required String clinicName,
  }) async {
    final Uint8List bytes =
        await build(document: document, clinicName: clinicName);

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${document.type.label.toLowerCase().replaceAll(' ', '_')}.pdf',
    );
  }

  // ------------------------------------------------------------- Blocos

  static pw.Widget _header({
    required ClinicalDocument document,
    required String clinicName,
    required String? clinicAddress,
    required String? clinicPhone,
    required pw.Font bold,
  }) {
    // Receituário de controle especial tem exigências próprias e precisa ser
    // visualmente distinto — não pode ser confundido com receita simples.
    final bool controlled = document.hasControlledDrug;

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  clinicName,
                  style: pw.TextStyle(font: bold, fontSize: 13, color: _petrol),
                ),
                if (clinicAddress != null)
                  pw.Text(
                    clinicAddress,
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                if (clinicPhone != null)
                  pw.Text(
                    clinicPhone,
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                controlled
                    ? 'RECEITUÁRIO DE CONTROLE ESPECIAL'
                    : document.type.label.toUpperCase(),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: controlled ? 10 : 12,
                  color: controlled ? _alert : _ink,
                ),
              ),
              pw.Text(
                _formatDate(document.issuedAt),
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _patientBlock({
    required ClinicalDocument document,
    required pw.Font bold,
    String? birthDateLabel,
    String? patientDocument,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF4F8F8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              'PACIENTE',
              style: pw.TextStyle(font: bold, fontSize: 7, color: _muted),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              document.patientName ?? '—',
              style: pw.TextStyle(font: bold, fontSize: 12),
            ),
            if (birthDateLabel != null || patientDocument != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  <String>[
                    if (birthDateLabel != null) 'Nascimento: $birthDateLabel',
                    if (patientDocument != null) patientDocument,
                  ].join('   ·   '),
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
          ],
        ),
      );

  /// Corpo de uma receita: itens numerados, posologia destacada.
  static List<pw.Widget> _prescriptionBody(
    ClinicalDocument document,
    pw.Font bold,
    pw.Font mono,
  ) =>
      <pw.Widget>[
        for (int i = 0; i < document.items.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: i < document.items.length - 1
                  ? const pw.Border(
                      bottom: pw.BorderSide(color: _line, width: 0.5),
                    )
                  : null,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Container(
                  width: 20,
                  child: pw.Text(
                    '${i + 1}.',
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        document.items[i].printedLine,
                        style: pw.TextStyle(font: bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      // Posologia em fonte monoespaçada: números de dose são o
                      // que o responsável precisa ler sem ambiguidade.
                      pw.Text(
                        document.items[i].printedPosology,
                        style: pw.TextStyle(font: mono, fontSize: 10),
                      ),
                      if (document.items[i].instructions != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            document.items[i].instructions!,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: _muted,
                            ),
                          ),
                        ),
                      if (document.items[i].quantity != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            'Quantidade: ${document.items[i].quantity}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (document.content.trim().isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Text(
            'Orientações',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _muted),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            document.content,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ],
      ];

  /// Corpo de atestado, declaração, encaminhamento, relatório e alta.
  static List<pw.Widget> _textBody(
    ClinicalDocument document,
    pw.Font bold,
  ) =>
      <pw.Widget>[
        pw.Text(
          document.content,
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 5),
          textAlign: pw.TextAlign.justify,
        ),
        if (document.validUntil != null) ...<pw.Widget>[
          pw.SizedBox(height: 16),
          pw.Text(
            'Válido até ${_formatDate(document.validUntil!)}.',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _muted),
          ),
        ],
      ];

  static pw.Widget _signatureBlock(
    ClinicalDocument document,
    pw.Font bold,
  ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Container(
            width: 240,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _ink, width: 0.8)),
            ),
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Column(
              children: <pw.Widget>[
                pw.Text(
                  document.professionalName ?? '',
                  style: pw.TextStyle(font: bold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                if (document.professionalCrm != null)
                  pw.Text(
                    'CRM ${document.professionalCrm}',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          // Enquanto não houver certificado ICP-Brasil, o documento precisa
          // dizer o que é. Omitir levaria o médico a entregar um papel que ele
          // acredita ter validade jurídica plena e não tem.
          if (document.signatureProvider == null)
            pw.Container(
              width: 380,
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Documento emitido eletronicamente e selado pela plataforma '
                '(integridade verificável pelo código abaixo). Não possui '
                'assinatura digital ICP-Brasil.',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
                textAlign: pw.TextAlign.center,
              ),
            )
          else
            pw.Text(
              'Assinado digitalmente via ${document.signatureProvider}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
        ],
      );

  static pw.Widget _cancelledBanner(
    ClinicalDocument document,
    pw.Font bold,
  ) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _alert, width: 1),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              'DOCUMENTO CANCELADO',
              style: pw.TextStyle(font: bold, fontSize: 11, color: _alert),
            ),
            if (document.cancellationReason != null)
              pw.Text(
                document.cancellationReason!,
                style: const pw.TextStyle(fontSize: 9),
              ),
          ],
        ),
      );

  static pw.Widget _footer({
    required ClinicalDocument document,
    required pw.Context context,
    required pw.Font mono,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  if (document.verificationCode != null) ...<pw.Widget>[
                    pw.Text(
                      'Código de conferência',
                      style: const pw.TextStyle(fontSize: 6, color: _muted),
                    ),
                    pw.Text(
                      document.verificationCode!,
                      style: pw.TextStyle(font: mono, fontSize: 10),
                    ),
                    pw.Text(
                      'Confira a autenticidade em pediatria360.app/verificar',
                      style: const pw.TextStyle(fontSize: 6, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ],
        ),
      );

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Modelos de texto para os documentos que não são receita.
///
/// São **pontos de partida editáveis**, não texto final. O médico revisa antes
/// de emitir — e é ele quem responde pelo conteúdo.
class DocumentTemplates {
  const DocumentTemplates._();

  static String certificate({
    required String patientName,
    required int days,
    String? cid,
    DateTime? from,
  }) {
    final DateTime start = from ?? DateTime.now();
    final String period = days == 1 ? '1 (um) dia' : '$days dias';

    return 'Atesto, para os devidos fins, que $patientName esteve sob meus '
        'cuidados na presente data, necessitando de afastamento de suas '
        'atividades escolares por $period, a partir de '
        '${ClinicalPdfService._formatDate(start)}.'
        '${cid != null ? '\n\nCID: $cid' : ''}'
        '\n\nO responsável pode solicitar a supressão do CID deste documento.';
  }

  static String attendanceDeclaration({
    required String patientName,
    required DateTime at,
    String? companionName,
  }) =>
      'Declaro que $patientName compareceu a esta unidade em '
      '${ClinicalPdfService._formatDate(at)}, no horário de '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}, para atendimento pediátrico.'
      '${companionName != null ? '\n\nAcompanhado(a) por $companionName.' : ''}';

  static String referral({
    required String patientName,
    required String specialty,
    required String reason,
    String? findings,
    String? cid,
  }) =>
      'Encaminho $patientName para avaliação em $specialty.\n\n'
      'Motivo: $reason'
      '${findings != null ? '\n\nAchados relevantes: $findings' : ''}'
      '${cid != null ? '\n\nHipótese diagnóstica (CID): $cid' : ''}'
      '\n\nColoco-me à disposição para as informações complementares que '
      'forem necessárias.';

  static String examRequest({
    required String patientName,
    required List<String> exams,
    String? clinicalIndication,
  }) =>
      'Solicito para $patientName:\n\n'
      '${exams.asMap().entries.map((MapEntry<int, String> e) => '${e.key + 1}. ${e.value}').join('\n')}'
      '${clinicalIndication != null ? '\n\nIndicação clínica: $clinicalIndication' : ''}';

  static String dischargeSummary({
    required String patientName,
    required DateTime admission,
    required DateTime discharge,
    required String diagnosis,
    required String course,
    required String medications,
    required String followUp,
  }) =>
      'SUMÁRIO DE ALTA\n\n'
      'Paciente: $patientName\n'
      'Internação: ${ClinicalPdfService._formatDate(admission)}\n'
      'Alta: ${ClinicalPdfService._formatDate(discharge)}\n\n'
      'DIAGNÓSTICO\n$diagnosis\n\n'
      'EVOLUÇÃO DURANTE A INTERNAÇÃO\n$course\n\n'
      'MEDICAÇÕES NA ALTA\n$medications\n\n'
      'ORIENTAÇÕES E RETORNO\n$followUp\n\n'
      'Em caso de piora, febre persistente, recusa alimentar, prostração ou '
      'dificuldade respiratória, procurar atendimento imediatamente.';
}
