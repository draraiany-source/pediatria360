/// Resultados de exames laboratoriais do paciente.
///
/// Regras deste módulo:
/// - o intervalo de referência é o informado no laudo, por resultado; não
///   existe intervalo único por exame, idade ou laboratório;
/// - resultado importado de PDF ou imagem fica pendente de conferência e
///   não entra no prontuário, nas comparações nem na avaliação de
///   suplementação até ser conferido;
/// - nenhum diagnóstico ou prescrição é gerado a partir de um resultado.
library;

import 'dart:typed_data';

enum LabSource {
  manual('Digitado'),
  importedPdf('Importado de PDF'),
  importedImage('Importado de imagem');

  const LabSource(this.label);

  final String label;

  bool get isImport => this != LabSource.manual;
}

enum LabStatus {
  pendingReview('Pendente de conferência'),
  confirmed('Conferido');

  const LabStatus(this.label);

  final String label;
}

/// Arquivo original do laudo. Na demonstração fica só na memória da aba.
class LabAttachment {
  const LabAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  String get sizeLabel {
    final int n = bytes.length;
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  static const int maxBytes = 10 * 1024 * 1024;

  static LabSource? sourceFor(String mimeType) {
    if (mimeType == 'application/pdf') return LabSource.importedPdf;
    if (mimeType.startsWith('image/')) return LabSource.importedImage;
    return null;
  }
}

/// Intervalo de referência como está no laudo.
class ReportedRange {
  const ReportedRange({this.text = '', this.low, this.high});

  final String text;
  final double? low;
  final double? high;

  bool get isEmpty => text.trim().isEmpty && low == null && high == null;

  String get label {
    if (text.trim().isNotEmpty) return text.trim();
    if (low != null && high != null) {
      return '${formatLabNumber(low!)} a ${formatLabNumber(high!)}';
    }
    if (low != null) return '>= ${formatLabNumber(low!)}';
    if (high != null) return '<= ${formatLabNumber(high!)}';
    return '';
  }
}

/// Posição do valor em relação ao intervalo impresso no próprio laudo.
enum RangePosition {
  below('Abaixo do intervalo do laudo'),
  within('Dentro do intervalo do laudo'),
  above('Acima do intervalo do laudo');

  const RangePosition(this.label);

  final String label;
}

class LabValues {
  const LabValues({
    required this.testName,
    required this.value,
    required this.unit,
    required this.collectedAt,
    required this.laboratory,
    this.range = const ReportedRange(),
  });

  final String testName;

  /// Texto como no laudo (ex.: "12,4" ou "não reagente").
  final String value;
  final String unit;
  final DateTime? collectedAt;
  final String laboratory;
  final ReportedRange range;

  double? get numeric => parseLabNumber(value);

  bool sameAs(LabValues o) =>
      testName == o.testName &&
      value == o.value &&
      unit == o.unit &&
      collectedAt == o.collectedAt &&
      laboratory == o.laboratory &&
      range.text == o.range.text &&
      range.low == o.range.low &&
      range.high == o.range.high;

  String summary() => <String>[
    testName.isEmpty ? '(sem nome)' : testName,
    '${value.isEmpty ? '-' : value} ${unit.trim()}'.trim(),
    if (collectedAt != null) 'coleta ${formatLabDate(collectedAt!)}',
    if (laboratory.isNotEmpty) laboratory,
    if (!range.isEmpty) 'ref. laudo: ${range.label}',
  ].join(' - ');

  /// O que falta para o resultado entrar no prontuário.
  List<String> get missing => <String>[
    if (testName.trim().isEmpty) 'Exame',
    if (value.trim().isEmpty) 'Resultado',
    if (unit.trim().isEmpty && numeric != null) 'Unidade',
    if (collectedAt == null) 'Data da coleta',
    if (laboratory.trim().isEmpty) 'Laboratório',
  ];
}

class LabRevision {
  const LabRevision({
    required this.at,
    required this.author,
    required this.action,
    this.reason = '',
    this.before,
    this.after,
  });

  final DateTime at;
  final String author;

  /// Ex.: "Registrado", "Importado", "Conferido", "Corrigido".
  final String action;
  final String reason;
  final LabValues? before;
  final LabValues? after;
}

class LabResult {
  const LabResult({
    required this.id,
    required this.patientId,
    required this.values,
    required this.source,
    required this.status,
    required this.author,
    required this.recordedAt,
    this.attachment,
    this.consultationId,
    this.topicIds = const <String>{},
    this.revisions = const <LabRevision>[],
  });

  /// Lançamento digitado pelo profissional: já entra conferido.
  factory LabResult.manual({
    required String id,
    required String patientId,
    required LabValues values,
    required String author,
    required DateTime now,
    LabAttachment? attachment,
    String? consultationId,
    Set<String> topicIds = const <String>{},
  }) {
    final List<String> missing = values.missing;
    if (missing.isNotEmpty) {
      throw StateError('Faltam: ${missing.join(', ')}.');
    }
    return LabResult(
      id: id,
      patientId: patientId,
      values: values,
      source: LabSource.manual,
      status: LabStatus.confirmed,
      author: author,
      recordedAt: now,
      attachment: attachment,
      consultationId: consultationId,
      topicIds: topicIds,
      revisions: <LabRevision>[
        LabRevision(
          at: now,
          author: author,
          action: 'Registrado',
          after: values,
        ),
      ],
    );
  }

  /// Laudo importado: fica pendente até alguém conferir os campos com o
  /// arquivo original. Nada é lido automaticamente do arquivo.
  factory LabResult.imported({
    required String id,
    required String patientId,
    required LabAttachment attachment,
    required String author,
    required DateTime now,
    LabValues? values,
    String? consultationId,
  }) {
    final LabSource? source = LabAttachment.sourceFor(attachment.mimeType);
    if (source == null) {
      throw StateError('Envie um PDF ou uma imagem do laudo.');
    }
    return LabResult(
      id: id,
      patientId: patientId,
      values:
          values ??
          const LabValues(
            testName: '',
            value: '',
            unit: '',
            collectedAt: null,
            laboratory: '',
          ),
      source: source,
      status: LabStatus.pendingReview,
      author: author,
      recordedAt: now,
      attachment: attachment,
      consultationId: consultationId,
      revisions: <LabRevision>[
        LabRevision(
          at: now,
          author: author,
          action: 'Importado (${attachment.name})',
        ),
      ],
    );
  }

  final String id;
  final String patientId;
  final LabValues values;
  final LabSource source;
  final LabStatus status;
  final String author;
  final DateTime recordedAt;
  final LabAttachment? attachment;
  final String? consultationId;

  /// Temas de suplementação a que o profissional relacionou o resultado.
  final Set<String> topicIds;
  final List<LabRevision> revisions;

  bool get isPending => status == LabStatus.pendingReview;

  /// Só resultado conferido entra no prontuário e nas comparações.
  bool get inRecord => status == LabStatus.confirmed;

  RangePosition? get rangePosition {
    final double? v = values.numeric;
    final ReportedRange r = values.range;
    if (v == null || (r.low == null && r.high == null)) return null;
    if (r.low != null && v < r.low!) return RangePosition.below;
    if (r.high != null && v > r.high!) return RangePosition.above;
    return RangePosition.within;
  }

  LabResult copyWith({
    LabValues? values,
    LabStatus? status,
    LabAttachment? attachment,
    String? consultationId,
    bool clearConsultation = false,
    Set<String>? topicIds,
    LabRevision? addRevision,
  }) => LabResult(
    id: id,
    patientId: patientId,
    values: values ?? this.values,
    source: source,
    status: status ?? this.status,
    author: author,
    recordedAt: recordedAt,
    attachment: attachment ?? this.attachment,
    consultationId: clearConsultation
        ? null
        : consultationId ?? this.consultationId,
    topicIds: topicIds ?? this.topicIds,
    revisions: addRevision == null
        ? revisions
        : <LabRevision>[...revisions, addRevision],
  );

  /// Conferência do resultado importado contra o arquivo original.
  LabResult confirm({
    required LabValues values,
    required String reviewer,
    required DateTime at,
  }) {
    if (!isPending) throw StateError('Resultado já conferido.');
    final List<String> missing = values.missing;
    if (missing.isNotEmpty) {
      throw StateError('Faltam: ${missing.join(', ')}.');
    }
    return copyWith(
      values: values,
      status: LabStatus.confirmed,
      addRevision: LabRevision(
        at: at,
        author: reviewer,
        action: 'Conferido com o laudo original',
        before: this.values,
        after: values,
      ),
    );
  }

  /// Rascunho da conferência: salva os campos sem liberar o resultado.
  LabResult saveReview({
    required LabValues values,
    required String author,
    required DateTime at,
  }) {
    if (!isPending) {
      throw StateError('Use a correção para resultado conferido.');
    }
    return copyWith(
      values: values,
      addRevision: LabRevision(
        at: at,
        author: author,
        action: 'Conferência em andamento',
        before: this.values,
        after: values,
      ),
    );
  }

  /// Corrige um resultado já no prontuário, mantendo o valor anterior.
  LabResult correct({
    required LabValues values,
    required String reason,
    required String author,
    required DateTime at,
  }) {
    if (isPending) throw StateError('Confira o resultado antes de corrigir.');
    if (reason.trim().isEmpty) {
      throw StateError('Informe o motivo da correção.');
    }
    final List<String> missing = values.missing;
    if (missing.isNotEmpty) {
      throw StateError('Faltam: ${missing.join(', ')}.');
    }
    if (values.sameAs(this.values)) {
      throw StateError('Nenhum valor foi alterado.');
    }
    return copyWith(
      values: values,
      addRevision: LabRevision(
        at: at,
        author: author,
        action: 'Corrigido',
        reason: reason.trim(),
        before: this.values,
        after: values,
      ),
    );
  }
}

/// Resultados de um mesmo exame ao longo do tempo.
class LabSeries {
  const LabSeries({required this.testName, required this.byUnit});

  final String testName;

  /// Resultados agrupados por unidade, em ordem de coleta. Unidades
  /// diferentes não são convertidas nem comparadas entre si.
  final Map<String, List<LabResult>> byUnit;

  bool get hasMixedUnits => byUnit.length > 1;
  int get count =>
      byUnit.values.fold<int>(0, (int a, List<LabResult> l) => a + l.length);

  static String normalize(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  /// Agrupa apenas resultados conferidos.
  static List<LabSeries> group(Iterable<LabResult> results) {
    final Map<String, List<LabResult>> byTest = <String, List<LabResult>>{};
    for (final LabResult r in results) {
      if (!r.inRecord) {
        continue;
      }
      byTest
          .putIfAbsent(normalize(r.values.testName), () => <LabResult>[])
          .add(r);
    }
    final List<LabSeries> out = <LabSeries>[];
    for (final List<LabResult> list in byTest.values) {
      list.sort(
        (LabResult a, LabResult b) =>
            a.values.collectedAt!.compareTo(b.values.collectedAt!),
      );
      final Map<String, List<LabResult>> units = <String, List<LabResult>>{};
      for (final LabResult r in list) {
        units.putIfAbsent(r.values.unit.trim(), () => <LabResult>[]).add(r);
      }
      out.add(LabSeries(testName: list.last.values.testName, byUnit: units));
    }
    out.sort((LabSeries a, LabSeries b) => a.testName.compareTo(b.testName));
    return out;
  }
}

/// Nomes de exames para autocompletar, com temas de suplementação que
/// costumam se relacionar. Só sugestão de vínculo: nenhum valor de
/// referência, interpretação ou conduta.
class LabTestSuggestion {
  const LabTestSuggestion(this.name, this.topicIds);

  final String name;
  final Set<String> topicIds;
}

const List<LabTestSuggestion> kLabTestSuggestions = <LabTestSuggestion>[
  LabTestSuggestion('Hemoglobina', <String>{'ferro', 'b12', 'acido-folico'}),
  LabTestSuggestion('Hematócrito', <String>{'ferro'}),
  LabTestSuggestion('VCM', <String>{'ferro', 'b12', 'acido-folico'}),
  LabTestSuggestion('Ferritina', <String>{'ferro'}),
  LabTestSuggestion('Ferro sérico', <String>{'ferro'}),
  LabTestSuggestion('Saturação de transferrina', <String>{'ferro'}),
  LabTestSuggestion('Vitamina B12', <String>{'b12', 'complexo-b'}),
  LabTestSuggestion('Ácido fólico', <String>{'acido-folico', 'complexo-b'}),
  LabTestSuggestion('Zinco', <String>{'zinco'}),
  LabTestSuggestion('Vitamina B6', <String>{'b6', 'complexo-b'}),
  LabTestSuggestion('Retinol (vitamina A)', <String>{'vit-a'}),
  LabTestSuggestion('25-hidroxivitamina D', <String>{'vit-d'}),
  LabTestSuggestion('Vitamina E', <String>{'vit-e'}),
  LabTestSuggestion('Tempo de protrombina', <String>{'vit-k'}),
  LabTestSuggestion('Vitamina C', <String>{'vit-c'}),
  LabTestSuggestion('Magnésio', <String>{'magnesio'}),
  LabTestSuggestion('Cálcio total', <String>{'calcio', 'vit-d'}),
  LabTestSuggestion('Cálcio iônico', <String>{'calcio', 'vit-d'}),
  LabTestSuggestion('Fósforo', <String>{'calcio', 'vit-d'}),
  LabTestSuggestion('Fosfatase alcalina', <String>{'vit-d', 'zinco'}),
  LabTestSuggestion('PTH', <String>{'vit-d', 'calcio'}),
  LabTestSuggestion('Selênio', <String>{'selenio'}),
  LabTestSuggestion('Cobre', <String>{'cobre'}),
  LabTestSuggestion('Ceruloplasmina', <String>{'cobre'}),
];

Set<String> suggestedTopicsFor(String testName) {
  final String n = LabSeries.normalize(testName);
  for (final LabTestSuggestion s in kLabTestSuggestions) {
    if (LabSeries.normalize(s.name) == n) return s.topicIds;
  }
  return const <String>{};
}

/// Vírgula decimal; ponto só como separador de milhar (ex.: 250.000).
double? parseLabNumber(String text) {
  String t = text.trim().replaceAll(RegExp(r'\s'), '');
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t) ? double.parse(t) : null;
}

String formatLabNumber(double v) {
  String s = v.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}

String formatLabDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
