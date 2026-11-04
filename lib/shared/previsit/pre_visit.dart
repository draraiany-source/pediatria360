/// Pré-consulta preenchida pelo responsável, com anexos: fotos da queixa e
/// exames, laudos e relatórios.
///
/// Regras deste módulo:
/// - o formato do arquivo é conferido pelo conteúdo, não pelo nome;
/// - há limite por arquivo, por quantidade e pela soma dos anexos;
/// - nada aqui lê ou interpreta o conteúdo dos arquivos. O anexo é
///   informação da família para preparar a consulta, não diagnóstico nem
///   resultado validado.
library;

import 'dart:convert';
import 'dart:typed_data';

enum PreVisitDocType {
  fotoQueixa(
    'Foto da queixa',
    'Fotos da queixa',
    'Lesão de pele ou alteração visível',
    dateLabel: 'Data da foto',
    dateRequired: false,
  ),
  exame(
    'Exame',
    'Exames',
    'Resultado de exame de sangue, urina, imagem etc.',
    dateLabel: 'Data do exame',
  ),
  laudo(
    'Laudo',
    'Laudos',
    'Laudo de exame assinado',
    dateLabel: 'Data do exame',
  ),
  relatorio(
    'Relatório médico',
    'Relatórios médicos',
    'Relatório de outro profissional ou serviço',
    dateLabel: 'Data do relatório',
  );

  const PreVisitDocType(
    this.label,
    this.plural,
    this.hint, {
    required this.dateLabel,
    this.dateRequired = true,
  });

  final String label;
  final String plural;
  final String hint;
  final String dateLabel;
  final bool dateRequired;

  bool get isPhoto => this == fotoQueixa;
}

enum PreVisitFormat {
  jpeg('JPG', 'image/jpeg'),
  png('PNG', 'image/png'),
  webp('WEBP', 'image/webp'),
  pdf('PDF', 'application/pdf');

  const PreVisitFormat(this.label, this.mimeType);

  final String label;
  final String mimeType;

  bool get isImage => this != pdf;
}

/// Resultado da conferência de um arquivo escolhido.
class PreVisitFileCheck {
  const PreVisitFileCheck._({this.format, this.error, this.pages});

  final PreVisitFormat? format;
  final String? error;

  /// Páginas do PDF, quando foi possível contar.
  final int? pages;

  bool get ok => error == null;
}

class PreVisitRules {
  const PreVisitRules._();

  static const int maxFiles = 10;
  static const int maxFileBytes = 10 * 1024 * 1024;
  static const int maxTotalBytes = 40 * 1024 * 1024;

  /// `image/*` deixa o celular converter fotos HEIC para JPG ao escolher.
  static const String accept = 'image/*,application/pdf';

  static const String summary =
      'Fotos JPG, PNG ou WEBP e arquivos PDF. Até 10 MB por arquivo, '
      '$maxFiles anexos e 40 MB no total.';

  static const String notDiagnosis =
      'Os anexos ajudam a preparar a consulta. Não são diagnóstico nem '
      'resultado validado: o profissional avalia cada um.';

  static String sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    final String mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '${mb.replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')} MB';
  }

  static PreVisitFileCheck check({
    required String name,
    required Uint8List bytes,
    List<PreVisitAttachment> existing = const <PreVisitAttachment>[],
  }) {
    PreVisitFileCheck fail(String m) => PreVisitFileCheck._(error: m);
    if (existing.length >= maxFiles) {
      return fail(
        'Limite de $maxFiles anexos por pré-consulta. Remova um anexo para '
        'incluir outro.',
      );
    }
    if (bytes.isEmpty) {
      return fail('O arquivo "$name" está vazio. Escolha outro arquivo.');
    }
    if (bytes.length > maxFileBytes) {
      return fail(
        '"$name" tem ${sizeLabel(bytes.length)}. O limite é 10 MB por '
        'arquivo. Envie uma foto com resolução menor ou o PDF em partes.',
      );
    }
    final int total = existing.fold<int>(
      bytes.length,
      (int s, PreVisitAttachment a) => s + a.bytes.length,
    );
    if (total > maxTotalBytes) {
      return fail(
        'Com "$name", os anexos somariam ${sizeLabel(total)}. O limite é '
        '40 MB por pré-consulta. Remova um anexo ou envie um arquivo menor.',
      );
    }
    if (_isHeic(bytes)) {
      return fail(
        'A foto "$name" está no formato HEIC (padrão do iPhone), que nem '
        'todos os aparelhos abrem. Escolha a foto pela galeria do navegador, '
        'que converte para JPG, ou use no iPhone Ajustes > Câmera > '
        'Formatos > "Mais compatível".',
      );
    }
    final PreVisitFormat? format = formatOf(bytes);
    if (format == null) {
      final bool looksAccepted = RegExp(
        r'\.(jpe?g|png|webp|pdf)$',
        caseSensitive: false,
      ).hasMatch(name);
      return fail(
        '"$name" não é uma imagem JPG, PNG ou WEBP nem um PDF'
        '${looksAccepted ? ', embora o nome termine como um deles' : ''}. '
        'Formatos aceitos: JPG, PNG, WEBP e PDF.',
      );
    }
    int? pages;
    if (format == PreVisitFormat.pdf) {
      final String text = latin1.decode(bytes, allowInvalid: true);
      if (text.contains('/Encrypt')) {
        return fail(
          '"$name" é um PDF protegido por senha e a equipe não conseguiria '
          'abri-lo. Envie o PDF sem senha ou uma foto do documento.',
        );
      }
      final int n = RegExp(r'/Type\s*/Page(?![a-zA-Z])').allMatches(text).length;
      pages = n == 0 ? null : n;
    }
    for (final PreVisitAttachment a in existing) {
      if (_same(a.bytes, bytes)) {
        return fail('"$name" já foi anexado nesta pré-consulta.');
      }
    }
    return PreVisitFileCheck._(format: format, pages: pages);
  }

  static String? typeError(PreVisitDocType type, PreVisitFormat format) =>
      type.isPhoto && !format.isImage
      ? 'Foto da queixa precisa ser uma imagem (JPG, PNG ou WEBP). Para um '
            'PDF, escolha exame, laudo ou relatório médico.'
      : null;

  static String? dateError(
    PreVisitDocType type,
    DateTime? date, {
    required DateTime today,
    DateTime? birth,
  }) {
    if (date == null) {
      return type.dateRequired
          ? 'Informe a ${type.dateLabel.toLowerCase()} (dd/mm/aaaa).'
          : null;
    }
    final DateTime d = DateTime(date.year, date.month, date.day);
    if (d.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'A data não pode ser futura.';
    }
    if (birth != null &&
        d.isBefore(DateTime(birth.year, birth.month, birth.day))) {
      return 'A data é anterior ao nascimento da criança.';
    }
    return null;
  }

  static PreVisitFormat? formatOf(Uint8List b) {
    bool starts(List<int> sig, [int at = 0]) {
      if (b.length < at + sig.length) return false;
      for (int i = 0; i < sig.length; i++) {
        if (b[at + i] != sig[i]) return false;
      }
      return true;
    }

    if (starts(const <int>[0xFF, 0xD8, 0xFF])) return PreVisitFormat.jpeg;
    if (starts(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return PreVisitFormat.png;
    }
    if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) {
      return PreVisitFormat.webp;
    }
    if (starts('%PDF-'.codeUnits)) return PreVisitFormat.pdf;
    return null;
  }

  static bool _isHeic(Uint8List b) {
    if (b.length < 12) return false;
    if (String.fromCharCodes(b.sublist(4, 8)) != 'ftyp') return false;
    const Set<String> brands = <String>{
      'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1', //
    };
    return brands.contains(String.fromCharCodes(b.sublist(8, 12)));
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class PreVisitAttachment {
  PreVisitAttachment({
    required this.id,
    required this.name,
    required this.format,
    required this.bytes,
    required this.type,
    required this.addedAt,
    this.date,
    this.description = '',
    this.pages,
    this.sentAt,
  });

  final String id;
  final String name;
  final PreVisitFormat format;
  final Uint8List bytes;
  final PreVisitDocType type;
  final DateTime addedAt;
  final DateTime? date;
  final String description;
  final int? pages;

  /// `null` enquanto não foi enviado: a clínica ainda não vê.
  DateTime? sentAt;

  bool get isSent => sentAt != null;
  String get sizeLabel => PreVisitRules.sizeLabel(bytes.length);
}

/// Respostas escritas da pré-consulta.
class PreVisitAnswers {
  const PreVisitAnswers({
    this.reason = '',
    this.symptoms = '',
    this.medications = '',
    this.notes = '',
  });

  final String reason;
  final String symptoms;
  final String medications;
  final String notes;

  bool get isEmpty =>
      reason.trim().isEmpty &&
      symptoms.trim().isEmpty &&
      medications.trim().isEmpty &&
      notes.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is PreVisitAnswers &&
      other.reason == reason &&
      other.symptoms == symptoms &&
      other.medications == medications &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(reason, symptoms, medications, notes);
}

class PreVisitEvent {
  const PreVisitEvent(this.at, this.text);

  final DateTime at;
  final String text;
}

/// Pré-consulta de um agendamento.
class PreVisit {
  PreVisit({required this.appointmentId, required this.patientId});

  final String appointmentId;
  final String patientId;

  /// Rascunho da família.
  PreVisitAnswers answers = const PreVisitAnswers();

  /// O que a clínica vê: a última versão enviada.
  PreVisitAnswers? sentAnswers;
  DateTime? sentAt;

  final List<PreVisitAttachment> attachments = <PreVisitAttachment>[];
  final List<PreVisitEvent> history = <PreVisitEvent>[];

  bool get isSent => sentAt != null;

  List<PreVisitAttachment> get sentAttachments =>
      attachments.where((PreVisitAttachment a) => a.isSent).toList();

  List<PreVisitAttachment> get drafts =>
      attachments.where((PreVisitAttachment a) => !a.isSent).toList();

  int get totalBytes => attachments.fold<int>(
    0,
    (int s, PreVisitAttachment a) => s + a.bytes.length,
  );

  bool get hasUnsentChanges =>
      drafts.isNotEmpty ||
      (sentAnswers == null ? !answers.isEmpty : sentAnswers != answers);

  bool get hasContent => !answers.isEmpty || attachments.isNotEmpty;
}

/// Anexos enviados, em dois grupos e do mais recente para o mais antigo.
List<(String, List<PreVisitAttachment>)> groupSentAttachments(PreVisit v) {
  int byDate(PreVisitAttachment a, PreVisitAttachment b) =>
      (b.date ?? b.addedAt).compareTo(a.date ?? a.addedAt);
  final List<PreVisitAttachment> sent = v.sentAttachments;
  final List<PreVisitAttachment> photos =
      sent.where((PreVisitAttachment a) => a.type.isPhoto).toList()
        ..sort(byDate);
  final List<PreVisitAttachment> docs =
      sent.where((PreVisitAttachment a) => !a.type.isPhoto).toList()
        ..sort(byDate);
  return <(String, List<PreVisitAttachment>)>[
    if (photos.isNotEmpty) ('Fotos da queixa', photos),
    if (docs.isNotEmpty) ('Exames, laudos e relatórios', docs),
  ];
}
