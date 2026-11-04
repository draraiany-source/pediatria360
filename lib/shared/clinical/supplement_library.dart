/// Biblioteca de suplementação pediátrica: fichas de consulta por tema.
///
/// As fichas nascem vazias e em rascunho. Nenhum texto, tabela ou dose de
/// material de terceiros entra aqui sem licença de uso e validação clínica;
/// uma ficha só passa a "validada" com fonte, revisor e data de revisão.
library;

enum SheetStatus {
  draft('Rascunho - não validado'),
  validated('Validado');

  const SheetStatus(this.label);

  final String label;
}

class SheetField {
  const SheetField(this.key, this.label);

  final String key;
  final String label;
}

/// Blocos de cada tema. Todos precisam estar preenchidos para validar.
const List<SheetField> kSheetFields = <SheetField>[
  SheetField('avaliacao', 'Avaliação'),
  SheetField('exames', 'Exames relacionados'),
  SheetField('fontesAlimentares', 'Fontes alimentares'),
  SheetField('cuidados', 'Cuidados'),
  SheetField('conteudoClinico', 'Conteúdo clínico validado'),
];

/// Grupos usados nos filtros da biblioteca.
const List<String> kSheetGroups = <String>[
  'Vitaminas',
  'Minerais',
  'Ácidos graxos',
  'Exames',
];

class SupplementSheet {
  const SupplementSheet({
    required this.id,
    required this.title,
    required this.group,
    this.content = const <String, String>{},
    this.source = '',
    this.reviewedBy = '',
    this.reviewedAt,
    this.status = SheetStatus.draft,
  });

  final String id;
  final String title;

  /// Um dos [kSheetGroups].
  final String group;
  final Map<String, String> content;
  final String source;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final SheetStatus status;

  bool get isDraft => status == SheetStatus.draft;

  /// Texto usado pela busca: título, grupo e conteúdo preenchido.
  String get searchText => <String>[title, group, ...content.values]
      .join(' ')
      .toLowerCase();

  String valueOf(String key) => (content[key] ?? '').trim();

  int get filledFields =>
      kSheetFields.where((SheetField f) => valueOf(f.key).isNotEmpty).length;

  /// O que falta para a ficha poder ser validada.
  List<String> get missingForValidation => <String>[
    for (final SheetField f in kSheetFields)
      if (valueOf(f.key).isEmpty) f.label,
    if (source.trim().isEmpty) 'Fonte',
    if (reviewedBy.trim().isEmpty) 'Revisor',
    if (reviewedAt == null) 'Data de revisão',
  ];

  SupplementSheet copyWith({
    Map<String, String>? content,
    String? source,
    String? reviewedBy,
    DateTime? reviewedAt,
    bool clearReviewedAt = false,
    SheetStatus? status,
  }) => SupplementSheet(
    id: id,
    title: title,
    group: group,
    content: content ?? this.content,
    source: source ?? this.source,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    reviewedAt: clearReviewedAt ? null : reviewedAt ?? this.reviewedAt,
    status: status ?? this.status,
  );

  /// Qualquer edição devolve a ficha a rascunho: a validação vale para o
  /// conteúdo que foi revisado, não para o que veio depois.
  SupplementSheet edit({
    required Map<String, String> content,
    required String source,
    required String reviewedBy,
    required DateTime? reviewedAt,
  }) => copyWith(
    content: Map<String, String>.of(content),
    source: source,
    reviewedBy: reviewedBy,
    reviewedAt: reviewedAt,
    clearReviewedAt: reviewedAt == null,
    status: SheetStatus.draft,
  );

  SupplementSheet validate() {
    final List<String> missing = missingForValidation;
    if (missing.isNotEmpty) {
      throw StateError('Faltam: ${missing.join(', ')}.');
    }
    return copyWith(status: SheetStatus.validated);
  }
}

/// Temas da biblioteca. Conteúdo vazio de propósito.
const List<SupplementSheet> kSupplementSheets = <SupplementSheet>[
  SupplementSheet(id: 'exames', title: 'Exames laboratoriais', group: 'Exames'),
  SupplementSheet(id: 'ferro', title: 'Ferro', group: 'Minerais'),
  SupplementSheet(id: 'b12', title: 'Vitamina B12', group: 'Vitaminas'),
  SupplementSheet(
    id: 'acido-folico',
    title: 'Ácido fólico',
    group: 'Vitaminas',
  ),
  SupplementSheet(id: 'zinco', title: 'Zinco', group: 'Minerais'),
  SupplementSheet(id: 'b6', title: 'Vitamina B6', group: 'Vitaminas'),
  SupplementSheet(id: 'vit-a', title: 'Vitamina A', group: 'Vitaminas'),
  SupplementSheet(id: 'vit-d', title: 'Vitamina D', group: 'Vitaminas'),
  SupplementSheet(id: 'vit-e', title: 'Vitamina E', group: 'Vitaminas'),
  SupplementSheet(id: 'vit-k', title: 'Vitamina K', group: 'Vitaminas'),
  SupplementSheet(id: 'vit-c', title: 'Vitamina C', group: 'Vitaminas'),
  SupplementSheet(id: 'magnesio', title: 'Magnésio', group: 'Minerais'),
  SupplementSheet(id: 'omega-3', title: 'Ômega-3', group: 'Ácidos graxos'),
  SupplementSheet(id: 'calcio', title: 'Cálcio', group: 'Minerais'),
  SupplementSheet(id: 'complexo-b', title: 'Complexo B', group: 'Vitaminas'),
  SupplementSheet(id: 'selenio', title: 'Selênio', group: 'Minerais'),
  SupplementSheet(id: 'cobre', title: 'Cobre', group: 'Minerais'),
];

// ------------------------------------------------ Decisão por paciente

enum SupplementDecisionKind {
  notIndicated('Sem indicação no momento'),
  monitor('Acompanhar e reavaliar'),
  indicated('Suplementação indicada'),
  suspended('Suplementação suspensa');

  const SupplementDecisionKind(this.label);

  final String label;

  /// Só a indicação leva o item à calculadora e ao receituário.
  bool get goesToPrescription => this == SupplementDecisionKind.indicated;
}

class SupplementDecisionVersion {
  const SupplementDecisionVersion({
    required this.kind,
    required this.note,
    required this.author,
    required this.at,
    required this.sheetStatus,
    this.labResultIds = const <String>[],
    this.consultationId,
  });

  final SupplementDecisionKind kind;
  final String note;
  final String author;
  final DateTime at;

  /// Situação da ficha do tema no momento da decisão.
  final SheetStatus sheetStatus;

  /// Resultados conferidos considerados na decisão.
  final List<String> labResultIds;
  final String? consultationId;
}

/// Decisão do profissional sobre um tema, para um paciente. Cada edição
/// cria uma versão nova; as anteriores continuam visíveis.
class SupplementDecision {
  const SupplementDecision({
    required this.id,
    required this.patientId,
    required this.topicId,
    required this.versions,
    this.prescriptionDocIds = const <String>[],
  });

  factory SupplementDecision.create({
    required String id,
    required String patientId,
    required String topicId,
    required SupplementDecisionVersion first,
  }) {
    _check(first);
    return SupplementDecision(
      id: id,
      patientId: patientId,
      topicId: topicId,
      versions: <SupplementDecisionVersion>[first],
    );
  }

  final String id;
  final String patientId;
  final String topicId;
  final List<SupplementDecisionVersion> versions;

  /// Receituários em rascunho gerados a partir desta decisão.
  final List<String> prescriptionDocIds;

  SupplementDecisionVersion get current => versions.last;

  static void _check(SupplementDecisionVersion v) {
    if (v.note.trim().isEmpty) {
      throw StateError('Registre a justificativa da decisão.');
    }
  }

  SupplementDecision revise(SupplementDecisionVersion next) {
    _check(next);
    return SupplementDecision(
      id: id,
      patientId: patientId,
      topicId: topicId,
      versions: <SupplementDecisionVersion>[...versions, next],
      prescriptionDocIds: prescriptionDocIds,
    );
  }

  SupplementDecision withPrescription(String docId) {
    if (!current.kind.goesToPrescription) {
      throw StateError('Só a suplementação indicada vai ao receituário.');
    }
    return SupplementDecision(
      id: id,
      patientId: patientId,
      topicId: topicId,
      versions: versions,
      prescriptionDocIds: <String>[...prescriptionDocIds, docId],
    );
  }
}
