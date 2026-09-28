import 'dart:io';
import 'dart:typed_data';

/// PNG RGB de cor sólida, gerado sem bibliotecas de imagem.
Uint8List solidPng(
  int width,
  int height, {
  int r = 20,
  int g = 103,
  int b = 107,
}) {
  final BytesBuilder raw = BytesBuilder();
  for (int y = 0; y < height; y++) {
    raw.addByte(0);
    for (int x = 0; x < width; x++) {
      raw.add(<int>[r, g, b]);
    }
  }
  return _png(width, height, ZLibCodec().encode(raw.toBytes()));
}

/// Só o cabeçalho de um PNG com as dimensões pedidas; o conteúdo é inválido.
Uint8List pngHeaderOnly(int width, int height) =>
    _png(width, height, const <int>[1, 2, 3, 4]);

Uint8List _png(int width, int height, List<int> idat) {
  final BytesBuilder out = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', <int>[..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]))
    ..add(_chunk('IDAT', idat))
    ..add(_chunk('IEND', const <int>[]));
  return out.toBytes();
}

List<int> _u32(int v) => <int>[
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

List<int> _chunk(String type, List<int> data) {
  final List<int> body = <int>[...type.codeUnits, ...data];
  return <int>[..._u32(data.length), ...body, ..._u32(_crc32(body))];
}

final List<int> _table = List<int>.generate(256, (int n) {
  int c = n;
  for (int k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final int b in bytes) {
    c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Início de um JPEG (SOI, APP0 e SOF0) com as dimensões pedidas.
Uint8List jpegHeader(int width, int height) => Uint8List.fromList(<int>[
  0xFF, 0xD8, //
  0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
  0x00, 0x01, 0x00, 0x01, 0x00, 0x00, //
  0xFF, 0xC0, 0x00, 0x11, 0x08, (height >> 8) & 0xFF, height & 0xFF,
  (width >> 8) & 0xFF, width & 0xFF, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11,
  0x01, 0x03, 0x11, 0x01, //
  0xFF, 0xD9,
]);
