import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../shared/domain/entities/commerce.dart';
import '../../domain/finance_models.dart';

/// Recibo simples em PDF (FASE 4 — sem assinatura digital ICP).
class ReceiptPdfService {
  const ReceiptPdfService._();

  static Future<Uint8List> build({
    required FinanceReceipt receipt,
    required FinanceReceivable receivable,
    required String clinicName,
    String? patientName,
  }) async {
    final pw.Document pdf = pw.Document(
      title: 'Recibo ${receipt.receiptNumber ?? receipt.id}',
    );
    final pw.Font regular = await PdfGoogleFonts.interRegular();
    final pw.Font bold = await PdfGoogleFonts.interSemiBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(clinicName, style: pw.TextStyle(font: bold, fontSize: 18)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Recibo de pagamento',
              style: pw.TextStyle(font: bold, fontSize: 14),
            ),
            pw.Divider(),
            pw.Text('Numero: ${receipt.receiptNumber ?? receipt.id}'),
            pw.Text(
              'Data: ${receipt.issuedAt.toLocal().toString().substring(0, 16)}',
            ),
            if (patientName != null) pw.Text('Paciente: $patientName'),
            pw.SizedBox(height: 16),
            pw.Text(receivable.description),
            pw.SizedBox(height: 8),
            pw.Text(
              'Valor: ${formatCents(receipt.amountCents)}',
              style: pw.TextStyle(font: bold, fontSize: 16),
            ),
            pw.Text('Forma: ${receipt.method.label}'),
            pw.Spacer(),
            pw.Text(
              'Documento emitido eletronicamente. Assinatura digital ICP-Brasil: pendente (FASE 5).',
              style: pw.TextStyle(font: regular, fontSize: 9),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
