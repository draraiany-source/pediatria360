/// Estrutura de resposta da IA de suplementacao (rascunho clinico).
const String kSupplementAiDisclaimer =
    'Ferramenta de apoio a decisao clinica. A interpretacao e a conduta final '
    'sao de responsabilidade do profissional assistente. Nao fecha diagnostico '
    'automaticamente e nao gera prescricao final.';

class SupplementAiSection {
  const SupplementAiSection({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;
}

class SupplementAiDraft {
  const SupplementAiDraft({
    required this.patientBlock,
    required this.examsBlock,
    required this.attentionPoints,
    required this.nextSteps,
    required this.shortcuts,
    required this.clinicalSummary,
    this.disclaimer = kSupplementAiDisclaimer,
  });

  final Map<String, String> patientBlock;
  final Map<String, String> examsBlock;
  final List<String> attentionPoints;
  final List<String> nextSteps;
  final List<String> shortcuts;
  final String clinicalSummary;
  final String disclaimer;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'patientBlock': patientBlock,
        'examsBlock': examsBlock,
        'attentionPoints': attentionPoints,
        'nextSteps': nextSteps,
        'shortcuts': shortcuts,
        'clinicalSummary': clinicalSummary,
        'disclaimer': disclaimer,
      };
}

/// Parser heuristico local (sem chamar modelo) ? organiza texto livre.
class SupplementAiLocalOrganizer {
  const SupplementAiLocalOrganizer();

  SupplementAiDraft organizeFromFreeText(String raw) {
    final String text = raw.trim();
    final Map<String, String> patient = <String, String>{
      'Idade': _extract(text, <String>['ano', 'anos', 'idade']) ?? 'Nao informado',
      'Peso': _extract(text, <String>['kg', 'peso']) ?? 'Nao informado',
      'Queixa': text.isEmpty ? 'Nao informado' : _firstSentence(text),
      'Alimentacao': _extract(text, <String>['seletividade', 'vegetariano', 'vegano', 'aliment']) ??
          'Nao informado',
    };
    final Map<String, String> exams = <String, String>{
      'Hb': _extract(text, <String>['hb', 'hemoglobina']) ?? 'Nao informado',
      'Ferritina': _extract(text, <String>['ferritina']) ?? 'Nao informado',
      'B12': _extract(text, <String>['b12']) ?? 'Nao informado',
      'Vitamina D': _extract(text, <String>['vitamina d', '25-oh', '25oh']) ?? 'Nao informado',
    };

    return SupplementAiDraft(
      patientBlock: patient,
      examsBlock: exams,
      attentionPoints: <String>[
        'Correlacionar valores laboratoriais com contexto clinico e alimentar.',
        'Revisar grupos de risco e necessidade de investigacao complementar.',
        'Nao interpretar isoladamente um unico marcador.',
      ],
      nextSteps: <String>[
        'Avaliacao clinica completa pelo pediatra.',
        'Considerar exames complementares conforme julgamento clinico.',
        'Abrir protocolos relacionados (ex.: seletividade, anemia) para revisao.',
        'Registrar evolucao no prontuario apos revisao humana.',
      ],
      shortcuts: <String>['ferro', 'exames', 'calculadora', 'nota_clinica'],
      clinicalSummary:
          'Rascunho estruturado a partir do texto informado. Revisar antes de qualquer conduta.\n\n$text',
    );
  }

  String? _extract(String text, List<String> keys) {
    final String lower = text.toLowerCase();
    for (final String key in keys) {
      final int i = lower.indexOf(key);
      if (i >= 0) {
        final int start = (i - 24).clamp(0, text.length);
        final int end = (i + key.length + 24).clamp(0, text.length);
        return text.substring(start, end).trim();
      }
    }
    return null;
  }

  String _firstSentence(String text) {
    final int dot = text.indexOf('.');
    if (dot > 0 && dot < 160) return text.substring(0, dot + 1).trim();
    if (text.length <= 160) return text;
    return '${text.substring(0, 157)}...';
  }
}
