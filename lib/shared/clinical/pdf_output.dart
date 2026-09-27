import 'dart:typed_data';

import 'pdf_output_stub.dart'
    if (dart.library.js_interop) 'pdf_output_web.dart'
    as impl;

enum PdfDelivery { download, print }

/// Entrega o PDF ao navegador: baixar ou abrir a impressão.
///
/// Devolve como foi entregue ('download', 'iframe', 'tab') ou `null` quando
/// a plataforma não oferece a saída.
Future<String?> deliverPdf(
  Uint8List bytes, {
  required String fileName,
  required PdfDelivery delivery,
}) => impl.deliverPdf(bytes, fileName, delivery == PdfDelivery.print);
