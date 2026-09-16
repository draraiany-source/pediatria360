import 'package:equatable/equatable.dart';

/// Tipo de conteúdo da biblioteca.
enum ContentType {
  article,
  protocol;

  static ContentType fromName(String? value) => ContentType.values.firstWhere(
        (ContentType t) => t.name == value,
        orElse: () => ContentType.article,
      );

  String get label =>
      this == ContentType.protocol ? 'Protocolo' : 'Artigo';
}

/// Público a que o conteúdo se destina.
///
/// A separação não é cosmética: um protocolo de conduta com posologia escrito
/// para o pediatra, lido por um pai ansioso às 3 da manhã, é um risco real de
/// automedicação. Conteúdo `professional` só aparece para quem tem registro
/// verificado.
enum ContentAudience {
  everyone,
  parents,
  professionals;

  static ContentAudience fromName(String? value) =>
      ContentAudience.values.firstWhere(
        (ContentAudience a) => a.name == value,
        orElse: () => ContentAudience.everyone,
      );

  String get label => switch (this) {
        ContentAudience.everyone => 'Para todos',
        ContentAudience.parents => 'Para famílias',
        ContentAudience.professionals => 'Para profissionais',
      };
}

/// Uma seção do corpo do conteúdo.
///
/// O corpo é estruturado em seções em vez de um blob de Markdown porque a
/// leitura de protocolo é por salto ("onde está a conduta?"), não linear.
/// Seções permitem índice, busca por trecho e destaque de alerta.
class ContentSection extends Equatable {
  const ContentSection({
    required this.title,
    required this.body,
    this.kind = SectionKind.text,
  });

  factory ContentSection.fromMap(Map<String, dynamic> map) => ContentSection(
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        kind: SectionKind.fromName(map['kind'] as String?),
      );

  final String title;
  final String body;
  final SectionKind kind;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'body': body,
        'kind': kind.name,
      };

  @override
  List<Object?> get props => <Object?>[title, body, kind];
}

/// Natureza da seção — muda como ela é desenhada.
enum SectionKind {
  text,
  /// Sinal de alarme: procurar atendimento. Sempre destacado em vermelho.
  redFlag,
  /// Passo a passo numerado.
  steps,
  /// Posologia ou dose. Só renderiza para profissional verificado.
  dosage,
  /// Referência bibliográfica.
  reference;

  static SectionKind fromName(String? value) => SectionKind.values.firstWhere(
        (SectionKind k) => k.name == value,
        orElse: () => SectionKind.text,
      );
}

/// Artigo ou protocolo da biblioteca médica.
class Content extends Equatable {
  const Content({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    required this.audience,
    required this.category,
    required this.updatedAt,
    this.sections = const <ContentSection>[],
    this.tags = const <String>[],
    this.searchTerms = const <String>[],
    this.coverUrl,
    this.author,
    this.reviewedBy,
    this.reviewedAt,
    this.readMinutes = 3,
    this.ageRangeMonths,
    this.published = true,
  });

  final String id;
  final String title;

  /// Resumo de uma ou duas frases — é o que aparece na lista e na busca.
  final String summary;

  final ContentType type;
  final ContentAudience audience;

  /// Categoria: 'febre', 'sono', 'amamentacao', 'neuropediatria'...
  final String category;

  final DateTime updatedAt;
  final List<ContentSection> sections;
  final List<String> tags;

  /// Termos normalizados (minúsculos, sem acento) usados na busca do
  /// Firestore com `array-contains-any`.
  final List<String> searchTerms;

  final String? coverUrl;
  final String? author;

  /// Quem revisou clinicamente. Conteúdo médico sem revisor identificado não
  /// deveria ser publicado — a tela mostra isso ao leitor.
  final String? reviewedBy;
  final DateTime? reviewedAt;

  final int readMinutes;

  /// Faixa etária a que se aplica, em meses: `(0, 24)` = do nascimento aos 2
  /// anos. `null` = qualquer idade.
  final (int, int)? ageRangeMonths;

  final bool published;

  bool get isProtocol => type == ContentType.protocol;

  /// `true` se o conteúdo tem alguma seção de posologia — usado para decidir
  /// se exige registro profissional verificado.
  bool get hasDosage =>
      sections.any((ContentSection s) => s.kind == SectionKind.dosage);

  /// Sinais de alarme, extraídos para destaque no topo.
  List<ContentSection> get redFlags => sections
      .where((ContentSection s) => s.kind == SectionKind.redFlag)
      .toList(growable: false);

  bool appliesToAge(int ageMonths) {
    if (ageRangeMonths == null) return true;
    final (int min, int max) = ageRangeMonths!;
    return ageMonths >= min && ageMonths <= max;
  }

  @override
  List<Object?> get props => <Object?>[id, title, updatedAt];
}

/// Categorias fixas da biblioteca.
///
/// Ficam no código (e não no Firestore) porque a navegação depende delas: uma
/// categoria criada no painel sem ícone e sem cor quebraria a grade.
class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static const List<ContentCategory> all = <ContentCategory>[
    ContentCategory(
      id: 'febre',
      label: 'Febre e infecções',
      description: 'Quando observar e quando procurar atendimento',
    ),
    ContentCategory(
      id: 'desenvolvimento',
      label: 'Desenvolvimento',
      description: 'Marcos motores, fala e social',
    ),
    ContentCategory(
      id: 'sono',
      label: 'Sono',
      description: 'Rotina, despertares e sono seguro',
    ),
    ContentCategory(
      id: 'amamentacao',
      label: 'Amamentação',
      description: 'Pega, produção e introdução alimentar',
    ),
    ContentCategory(
      id: 'nutricao',
      label: 'Nutrição',
      description: 'Alimentação por faixa etária e seletividade',
    ),
    ContentCategory(
      id: 'respiratorio',
      label: 'Respiratório',
      description: 'Bronquiolite, asma e alergias',
    ),
    ContentCategory(
      id: 'pele',
      label: 'Pele',
      description: 'Dermatite, assaduras e manchas',
    ),
    ContentCategory(
      id: 'neuropediatria',
      label: 'Neuropediatria',
      description: 'Convulsão, atraso e neurodivergência',
    ),
    ContentCategory(
      id: 'emergencia',
      label: 'Emergência',
      description: 'Primeiros socorros e sinais de gravidade',
    ),
  ];

  static ContentCategory? byId(String id) {
    for (final ContentCategory category in all) {
      if (category.id == id) return category;
    }
    return null;
  }

  static String labelOf(String id) => byId(id)?.label ?? id;
}

/// Normaliza texto para busca: minúsculo, sem acento, sem pontuação.
///
/// O Firestore não tem busca textual nativa. A estratégia aqui é gerar os
/// termos na publicação (Cloud Function) e consultar com `array-contains-any`.
/// Resolve bem o caso real — buscar "febre", "bronquiolite" — sem o custo de
/// manter um Algolia para um catálogo de algumas centenas de documentos.
String normalizeForSearch(String input) {
  const Map<String, String> accents = <String, String>{
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  final StringBuffer buffer = StringBuffer();
  for (final String char in input.toLowerCase().split('')) {
    buffer.write(accents[char] ?? char);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Quebra uma consulta em termos buscáveis, descartando palavras curtas.
List<String> searchTokens(String query) => normalizeForSearch(query)
    .split(' ')
    .where((String t) => t.length >= 3)
    .take(10)
    .toList(growable: false);
