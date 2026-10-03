import 'dart:js_interop';
import 'dart:typed_data';

// Definidas em web_demo/pdf_helper.js (arquivo local, permitido pela CSP).
@JS('p360Pdf.download')
external JSString? _download(JSUint8Array bytes, JSString name);

@JS('p360Pdf.print')
external JSString? _print(JSUint8Array bytes, JSString name);

@JS('p360Pdf.view')
external JSString? _view(JSUint8Array bytes, JSString name);

Future<String?> deliverPdf(
  Uint8List bytes,
  String fileName,
  String mode,
) async {
  try {
    final JSUint8Array b = bytes.toJS;
    final JSString n = fileName.toJS;
    final JSString? r = switch (mode) {
      'print' => _print(b, n),
      'view' => _view(b, n),
      _ => _download(b, n),
    };
    return r?.toDart;
  } catch (_) {
    return null;
  }
}
