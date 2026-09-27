import 'dart:typed_data';

import 'file_input_stub.dart'
    if (dart.library.js_interop) 'file_input_web.dart'
    as impl;

class PickedFile {
  const PickedFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Substitui o seletor do navegador nos testes.
Future<PickedFile?> Function(String accept)? debugPickFile;

/// Abre o seletor de arquivos do navegador. `null` se cancelado ou se a
/// plataforma não oferece seletor.
Future<PickedFile?> pickFile({required String accept}) {
  final Future<PickedFile?> Function(String accept)? fake = debugPickFile;
  if (fake != null) return fake(accept);
  return impl.pickFile(accept);
}

/// Abre o arquivo original em outra aba. Devolve `false` se não abriu.
bool openFileInNewTab(Uint8List bytes, String mimeType) =>
    impl.openFile(bytes, mimeType);
