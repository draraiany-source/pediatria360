import 'dart:js_interop';
import 'dart:typed_data';

import 'file_input.dart';

// Definidas em web_demo/pdf_helper.js (arquivo local, permitido pela CSP).
@JS('p360File.pick')
external JSPromise<_JsPicked?> _pick(JSString accept);

@JS('p360File.open')
external JSBoolean _open(JSUint8Array bytes, JSString mimeType);

extension type _JsPicked._(JSObject _) implements JSObject {
  external JSString get name;
  external JSString get type;
  external JSUint8Array get bytes;
}

Future<PickedFile?> pickFile(String accept) async {
  try {
    final _JsPicked? r = await _pick(accept.toJS).toDart;
    if (r == null) return null;
    return PickedFile(
      name: r.name.toDart,
      mimeType: r.type.toDart,
      bytes: r.bytes.toDart,
    );
  } catch (_) {
    return null;
  }
}

bool openFile(Uint8List bytes, String mimeType) {
  try {
    return _open(bytes.toJS, mimeType.toJS).toDart;
  } catch (_) {
    return false;
  }
}
