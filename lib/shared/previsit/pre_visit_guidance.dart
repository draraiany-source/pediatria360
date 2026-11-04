/// Orientações prévias da consulta: o que levar, como se preparar e o que
/// fazer se a criança piorar antes do horário.
///
/// São avisos administrativos, escritos e revisados pela equipe da clínica.
/// Não trazem conduta clínica nem dose. Os textos padrão são sugestões do
/// aplicativo e aparecem marcados como tal até a clínica revisar.
library;

enum VisitCategory {
  rotina('Consulta de rotina e puericultura'),
  queixa('Consulta por queixa ou avaliação'),
  retorno('Retorno'),
  teleconsulta('Teleconsulta');

  const VisitCategory(this.label);

  final String label;

  static VisitCategory? fromName(String? name) {
    for (final VisitCategory c in VisitCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Categoria pelo tipo do agendamento. Teleconsulta vale mais que o tipo.
  static VisitCategory classify({
    required String label,
    bool telehealth = false,
  }) {
    if (telehealth) return VisitCategory.teleconsulta;
    final String l = label.trim().toLowerCase();
    if (l.startsWith('retorno')) return VisitCategory.retorno;
    if (l.startsWith('rotina') ||
        l.startsWith('consulta de rotina') ||
        l.startsWith('puericultura')) {
      return VisitCategory.rotina;
    }
    return VisitCategory.queixa;
  }
}

class PreVisitGuidanceRules {
  const PreVisitGuidanceRules._();

  static const int maxItems = 8;
  static const int maxLength = 200;

  /// Aviso fixo, sempre mostrado, que a clínica não pode apagar.
  static const String safetyNotice =
      'Se a criança piorar antes da consulta, não espere o horário marcado: '
      'procure atendimento de urgência.';

  static const String suggestedLabel =
      'Texto sugerido pelo aplicativo. A clínica ainda não revisou.';

  static const List<String> defaultGeneral = <String>[
    'Leve a caderneta de saúde da criança.',
    'Tenha em mãos o nome e a dose dos medicamentos que a criança usa.',
    'Chegue 10 minutos antes para a recepção conferir o cadastro.',
  ];

  static const Map<VisitCategory, List<String>> defaults =
      <VisitCategory, List<String>>{
        VisitCategory.rotina: <String>[
          'Anote as dúvidas sobre alimentação, sono e desenvolvimento para '
              'conversar na consulta.',
        ],
        VisitCategory.queixa: <String>[
          'Anote quando os sintomas começaram e o que já foi feito em casa.',
          'Se puder, envie fotos da queixa pela pré-consulta.',
        ],
        VisitCategory.retorno: <String>[
          'Leve ou envie pela pré-consulta os exames pedidos na consulta '
              'anterior.',
        ],
        VisitCategory.teleconsulta: <String>[
          'Teste a conexão, a câmera e o som alguns minutos antes.',
          'Fique em um lugar iluminado, com a criança por perto.',
        ],
      };

  /// Erro de uma lista editada pela clínica; `null` quando está boa.
  static String? validate(List<String> items) {
    final List<String> clean = normalize(items);
    if (clean.length > maxItems) return 'Use no máximo $maxItems itens.';
    for (final String s in clean) {
      if (s.length > maxLength) {
        return 'Cada item pode ter até $maxLength caracteres.';
      }
    }
    return null;
  }

  /// Uma orientação por linha, sem linhas vazias nem repetidas.
  static List<String> normalize(Iterable<String> items) {
    final List<String> out = <String>[];
    for (final String raw in items) {
      final String s = raw.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    return out;
  }
}

/// Orientações de uma clínica, editáveis por categoria.
class PreVisitGuidance {
  PreVisitGuidance({
    List<String>? general,
    Map<VisitCategory, List<String>>? byCategory,
    this.reviewedBy,
    this.reviewedAt,
  }) : general = general ?? PreVisitGuidanceRules.defaultGeneral,
       byCategory = byCategory ?? PreVisitGuidanceRules.defaults;

  final List<String> general;
  final Map<VisitCategory, List<String>> byCategory;

  /// Enquanto `null`, os textos são as sugestões do aplicativo.
  final String? reviewedBy;
  final DateTime? reviewedAt;

  bool get isReviewed => reviewedAt != null;

  /// Itens que a família vê para uma consulta, sem o aviso fixo.
  List<String> itemsFor(VisitCategory category) =>
      PreVisitGuidanceRules.normalize(<String>[
        ...general,
        ...?byCategory[category],
      ]);

  PreVisitGuidance edited({
    required List<String> general,
    required Map<VisitCategory, List<String>> byCategory,
    required String reviewer,
    required DateTime now,
  }) {
    final String? e =
        PreVisitGuidanceRules.validate(general) ??
        byCategory.values
            .map(PreVisitGuidanceRules.validate)
            .nonNulls
            .firstOrNull;
    if (e != null) throw ArgumentError(e);
    return PreVisitGuidance(
      general: PreVisitGuidanceRules.normalize(general),
      byCategory: <VisitCategory, List<String>>{
        for (final VisitCategory c in VisitCategory.values)
          c: PreVisitGuidanceRules.normalize(byCategory[c] ?? const <String>[]),
      },
      reviewedBy: reviewer,
      reviewedAt: now,
    );
  }
}
