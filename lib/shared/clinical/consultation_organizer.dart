/// Organização assistida do registro da consulta.
///
/// O resultado é sempre um rascunho: nada vai para o prontuário antes de o
/// profissional revisar e confirmar. O organizador só distribui o que foi
/// dito ou escrito (pré-consulta, transcrição) nas seções; não sugere
/// avaliação, diagnóstico nem conduta nova.
library;

enum SummarySection {
  queixa('Queixa'),
  anamnese('Anamnese'),
  exameFisico('Exame físico'),
  avaliacao('Avaliação'),
  conduta('Conduta'),
  retorno('Plano de retorno');

  const SummarySection(this.label);

  final String label;
}

class OrganizerInput {
  const OrganizerInput({
    this.current = const <SummarySection, String>{},
    this.preVisitReason = '',
    this.preVisitSymptoms = '',
    this.preVisitMedications = '',
    this.preVisitNotes = '',
    this.transcript = '',
  });

  /// O que já está escrito no registro.
  final Map<SummarySection, String> current;
  final String preVisitReason;
  final String preVisitSymptoms;
  final String preVisitMedications;
  final String preVisitNotes;

  /// Texto transcrito ou colado pelo profissional.
  final String transcript;
}

enum DraftStatus {
  pendente('Aguardando revisão'),
  aplicado('Revisado e aplicado'),
  descartado('Descartado');

  const DraftStatus(this.label);

  final String label;
}

class OrganizedDraft {
  OrganizedDraft({
    required this.createdAt,
    required this.createdBy,
    required this.source,
    required this.suggestions,
    required this.notes,
  });

  final DateTime createdAt;
  final String createdBy;

  /// Quem organizou (no demo, regras fixas; no app real, o modelo de IA).
  final String source;

  /// Só seções que estavam vazias recebem sugestão.
  final Map<SummarySection, String> suggestions;
  final List<String> notes;
  DraftStatus status = DraftStatus.pendente;
  DateTime? reviewedAt;
  String? reviewedBy;

  bool get isEmpty => suggestions.isEmpty;
}

final RegExp _examWords = RegExp(
  r'\b(exame|ausculta|otoscopia|oroscopia|orofaringe|abdome|abdômen|'
  r'pele|temperatura|febril|afebril|peso|pesou|frequência|saturação|'
  r'murmúrio|hidratad|corad)',
  caseSensitive: false,
);
final RegExp _planWords = RegExp(
  r'\b(orient|prescrev|receit|solicit|pedir|encaminh|manter|suspender|'
  r'iniciar|usar|tomar)',
  caseSensitive: false,
);
final RegExp _returnWords = RegExp(
  r'\b(retorno|retornar|voltar em|reavaliar|reavaliação)',
  caseSensitive: false,
);

List<String> _sentences(String text) => text
    .split(RegExp(r'(?<=[.!?;])\s+|\n+'))
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toList();

OrganizedDraft organizeConsultation(
  OrganizerInput input, {
  required DateTime now,
  required String createdBy,
  String source = 'Organização simulada por regras (sem IA ativa)',
}) {
  bool empty(SummarySection s) => (input.current[s] ?? '').trim().isEmpty;
  final Map<SummarySection, List<String>> parts =
      <SummarySection, List<String>>{};
  void add(SummarySection s, String text) {
    if (text.trim().isEmpty) return;
    (parts[s] ??= <String>[]).add(text.trim());
  }

  add(SummarySection.queixa, input.preVisitReason);
  if (input.preVisitSymptoms.trim().isNotEmpty) {
    add(
      SummarySection.anamnese,
      'Relato da família na pré-consulta: ${input.preVisitSymptoms.trim()}',
    );
  }
  if (input.preVisitMedications.trim().isNotEmpty) {
    add(
      SummarySection.anamnese,
      'Medicamentos em uso (informado pela família): '
      '${input.preVisitMedications.trim()}',
    );
  }
  if (input.preVisitNotes.trim().isNotEmpty) {
    add(
      SummarySection.anamnese,
      'Observações da família: ${input.preVisitNotes.trim()}',
    );
  }
  for (final String s in _sentences(input.transcript)) {
    if (_returnWords.hasMatch(s)) {
      add(SummarySection.retorno, s);
    } else if (_planWords.hasMatch(s)) {
      add(SummarySection.conduta, s);
    } else if (_examWords.hasMatch(s)) {
      add(SummarySection.exameFisico, s);
    } else {
      add(SummarySection.anamnese, s);
    }
  }

  final Map<SummarySection, String> suggestions = <SummarySection, String>{
    for (final MapEntry<SummarySection, List<String>> e in parts.entries)
      if (e.key != SummarySection.avaliacao && empty(e.key))
        e.key: e.value.join(e.key == SummarySection.queixa ? ' ' : '\n'),
  };
  final List<String> notes = <String>[
    'A avaliação não é sugerida: escreva a sua conclusão clínica.',
    if (parts.keys.any((SummarySection s) => !empty(s)))
      'Seções já preenchidas foram mantidas como estavam.',
    if (suggestions.isEmpty)
      'Nada novo para organizar: preencha a pré-consulta ou cole a '
          'transcrição.',
  ];
  return OrganizedDraft(
    createdAt: now,
    createdBy: createdBy,
    source: source,
    suggestions: suggestions,
    notes: notes,
  );
}
