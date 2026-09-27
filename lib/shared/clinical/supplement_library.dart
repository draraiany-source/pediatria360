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

const List<SheetField> kSheetFields = <SheetField>[
  SheetField('indicacao', 'Indicação'),
  SheetField('faixaEtaria', 'Faixa etária'),
  SheetField('avaliacaoClinica', 'Avaliação clínica'),
  SheetField('avaliacaoLaboratorial', 'Avaliação laboratorial'),
  SheetField('apresentacoes', 'Apresentações'),
  SheetField('cuidados', 'Cuidados'),
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

  /// 'Exames' ou 'Nutrientes'.
  final String group;
  final Map<String, String> content;
  final String source;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final SheetStatus status;

  bool get isDraft => status == SheetStatus.draft;

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
  SupplementSheet(id: 'ferro', title: 'Ferro', group: 'Nutrientes'),
  SupplementSheet(id: 'b12', title: 'Vitamina B12', group: 'Nutrientes'),
  SupplementSheet(
    id: 'acido-folico',
    title: 'Ácido fólico',
    group: 'Nutrientes',
  ),
  SupplementSheet(id: 'zinco', title: 'Zinco', group: 'Nutrientes'),
  SupplementSheet(id: 'b6', title: 'Vitamina B6', group: 'Nutrientes'),
  SupplementSheet(id: 'vit-a', title: 'Vitamina A', group: 'Nutrientes'),
  SupplementSheet(id: 'vit-d', title: 'Vitamina D', group: 'Nutrientes'),
  SupplementSheet(id: 'vit-e', title: 'Vitamina E', group: 'Nutrientes'),
  SupplementSheet(id: 'vit-k', title: 'Vitamina K', group: 'Nutrientes'),
  SupplementSheet(id: 'vit-c', title: 'Vitamina C', group: 'Nutrientes'),
  SupplementSheet(id: 'magnesio', title: 'Magnésio', group: 'Nutrientes'),
  SupplementSheet(id: 'omega-3', title: 'Ômega-3', group: 'Nutrientes'),
  SupplementSheet(id: 'calcio', title: 'Cálcio', group: 'Nutrientes'),
  SupplementSheet(id: 'complexo-b', title: 'Complexo B', group: 'Nutrientes'),
  SupplementSheet(id: 'selenio', title: 'Selênio', group: 'Nutrientes'),
  SupplementSheet(id: 'cobre', title: 'Cobre', group: 'Nutrientes'),
];
