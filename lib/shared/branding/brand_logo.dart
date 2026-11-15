/// Logomarca própria de cada clínica ou profissional.
///
/// Regras que valem para a demonstração e para o app real:
/// - a logomarca pertence à conta que a enviou; só essa conta envia, troca,
///   remove e usa a imagem nos próprios documentos;
/// - sem logomarca, os documentos usam a identidade padrão do Pediatria360;
/// - o formato é conferido pelo conteúdo do arquivo (PNG ou JPG), não pelo
///   nome nem pelo tipo informado pelo navegador; SVG não é aceito porque
///   pode carregar código;
/// - documento emitido guarda a logomarca usada na emissão: trocar ou
///   remover a imagem depois não altera o que já foi entregue.
library;

import 'dart:typed_data';

enum LogoFormat {
  png('image/png', 'PNG'),
  jpeg('image/jpeg', 'JPG');

  const LogoFormat(this.mimeType, this.label);

  final String mimeType;
  final String label;
}

/// Resultado da conferência de um arquivo candidato a logomarca.
class LogoInspection {
  const LogoInspection({
    required this.problems,
    this.format,
    this.width,
    this.height,
  });

  final LogoFormat? format;
  final int? width;
  final int? height;
  final List<String> problems;

  bool get ok => problems.isEmpty;
}

class BrandLogoRules {
  const BrandLogoRules._();

  static const int maxBytes = 2 * 1024 * 1024;
  static const int minSide = 64;
  static const int maxSide = 4096;
  static const String accept = 'image/png,image/jpeg';

  static const String summary =
      'PNG ou JPG, até 2 MB, entre 64 e 4096 pixels. Fundo branco ou '
      'transparente fica melhor na impressão.';

  static LogoInspection inspect(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const LogoInspection(problems: <String>['Arquivo vazio.']);
    }
    final LogoFormat? format = _formatOf(bytes);
    if (format == null) {
      return const LogoInspection(
        problems: <String>['Formato não aceito: envie uma imagem PNG ou JPG.'],
      );
    }
    final List<String> problems = <String>[];
    if (bytes.length > maxBytes) {
      problems.add(
        'Arquivo com ${_mb(bytes.length)} MB; o limite é '
        '${_mb(maxBytes)} MB.',
      );
    }
    final (int, int)? size = format == LogoFormat.png
        ? _pngSize(bytes)
        : _jpegSize(bytes);
    if (size == null) {
      problems.add('Não foi possível ler as dimensões da imagem.');
      return LogoInspection(problems: problems, format: format);
    }
    final (int w, int h) = size;
    final int shortest = w < h ? w : h;
    final int longest = w > h ? w : h;
    if (shortest < minSide) {
      problems.add(
        'Imagem pequena demais ($w x $h px); use ao menos $minSide px no '
        'menor lado.',
      );
    }
    if (longest > maxSide) {
      problems.add(
        'Imagem grande demais ($w x $h px); use até $maxSide px no maior '
        'lado.',
      );
    }
    return LogoInspection(
      problems: problems,
      format: format,
      width: w,
      height: h,
    );
  }

  static String _mb(int bytes) {
    final double mb = bytes / (1024 * 1024);
    final String t = mb >= 10 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
    return t.replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
  }

  static LogoFormat? _formatOf(Uint8List b) {
    const List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (b.length >= png.length) {
      bool isPng = true;
      for (int i = 0; i < png.length; i++) {
        if (b[i] != png[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return LogoFormat.png;
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return LogoFormat.jpeg;
    }
    return null;
  }

  static int _u16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];

  static int _u32(Uint8List b, int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

  static (int, int)? _pngSize(Uint8List b) {
    if (b.length < 24) return null;
    // IHDR é sempre o primeiro bloco.
    if (String.fromCharCodes(b.sublist(12, 16)) != 'IHDR') return null;
    final int w = _u32(b, 16), h = _u32(b, 20);
    return w > 0 && h > 0 ? (w, h) : null;
  }

  static (int, int)? _jpegSize(Uint8List b) {
    int i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final int marker = b[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
        i += 2;
        continue;
      }
      if (marker == 0xD9 || marker == 0xDA) return null;
      final int length = _u16(b, i + 2);
      final bool sof =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (sof) {
        final int h = _u16(b, i + 5), w = _u16(b, i + 7);
        return w > 0 && h > 0 ? (w, h) : null;
      }
      if (length < 2) return null;
      i += 2 + length;
    }
    return null;
  }
}

/// Imagem enviada por uma conta. Nunca é alterada: trocar a logomarca cria
/// outra, e os documentos emitidos apontam para a que foi usada.
class BrandLogo {
  const BrandLogo({
    required this.id,
    required this.ownerId,
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
    required this.fileName,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  final String id;
  final String ownerId;
  final Uint8List bytes;
  final LogoFormat format;
  final int width;
  final int height;
  final String fileName;
  final DateTime uploadedAt;
  final String uploadedBy;

  String get sizeLabel {
    final double kb = bytes.length / 1024;
    return kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB'
        : '${kb.toStringAsFixed(0)} KB';
  }
}

class BrandingException implements Exception {
  const BrandingException(this.message, {this.problems = const <String>[]});

  final String message;
  final List<String> problems;

  @override
  String toString() =>
      problems.isEmpty ? message : '$message ${problems.join(' ')}';
}

/// Logomarcas por conta.
class BrandLogoStore {
  final Map<String, String> _current = <String, String>{};
  final Map<String, BrandLogo> _archive = <String, BrandLogo>{};

  /// Logomarca vigente da conta, só para a própria conta.
  BrandLogo? currentFor({required String ownerId, required String viewerId}) {
    if (ownerId != viewerId) return null;
    final String? id = _current[ownerId];
    return id == null ? null : _archive[id];
  }

  bool hasLogo(String ownerId) => _current.containsKey(ownerId);

  BrandLogo upload({
    required String actorId,
    required String ownerId,
    required String logoId,
    required Uint8List bytes,
    required String fileName,
    required String uploadedBy,
    required DateTime now,
  }) {
    _checkOwner(actorId, ownerId);
    final LogoInspection check = BrandLogoRules.inspect(bytes);
    if (!check.ok) {
      throw BrandingException('Imagem não aceita.', problems: check.problems);
    }
    final BrandLogo logo = BrandLogo(
      id: logoId,
      ownerId: ownerId,
      bytes: Uint8List.fromList(bytes),
      format: check.format!,
      width: check.width!,
      height: check.height!,
      fileName: fileName,
      uploadedAt: now,
      uploadedBy: uploadedBy,
    );
    _archive[logoId] = logo;
    _current[ownerId] = logoId;
    return logo;
  }

  /// Tira a logomarca dos próximos documentos. Os já emitidos continuam
  /// como foram entregues.
  void remove({required String actorId, required String ownerId}) {
    _checkOwner(actorId, ownerId);
    _current.remove(ownerId);
  }

  /// Logomarca do cabeçalho de um documento.
  ///
  /// Emitido: a imagem gravada na emissão (ou a identidade padrão, se não
  /// havia). Rascunho: a logomarca vigente do dono, e só para o dono.
  BrandLogo? forDocument({
    required String? ownerId,
    required String viewerId,
    required bool issued,
    String? issuedLogoId,
  }) {
    if (ownerId == null) return null;
    if (issued) {
      final BrandLogo? logo = issuedLogoId == null
          ? null
          : _archive[issuedLogoId];
      return logo?.ownerId == ownerId ? logo : null;
    }
    return currentFor(ownerId: ownerId, viewerId: viewerId);
  }

  void _checkOwner(String actorId, String ownerId) {
    if (actorId != ownerId) {
      throw const BrandingException(
        'Só a própria conta pode alterar a sua logomarca.',
      );
    }
  }
}
