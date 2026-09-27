import 'dart:js_interop';
import 'dart:typed_data';

// Definidas em web_demo/pdf_helper.js (arquivo local, permitido pela CSP).
@JS('p360Pdf.download')
external JSString? _download(JSUint8Array bytes, JSString name);

@JS('p360Pdf.print')
external JSString? _print(JSUint8Array bytes, JSString name);

Future<String?> deliverPdf(Uint8List bytes, String fileName, bool print) async {
  try {
    final JSString? r = print
        ? _print(bytes.toJS, fileName.toJS)
        : _download(bytes.toJS, fileName.toJS);
    return r?.toDart;
  } catch (_) {
    return null;
  }
}
