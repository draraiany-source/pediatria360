/// Regras para todo texto produzido por assistente.
///
/// O texto sai sempre como rascunho identificado. Só vira registro no
/// prontuário, documento emitido ou mensagem clínica depois que o
/// profissional revisa e confirma. Hipótese diagnóstica e dose nunca saem do
/// assistente como decisão.
library;

enum AiSource {
  regras('Organizado por regras, sem IA'),
  simulado('Rascunho simulado, sem IA ativa'),
  ia('Gerado por IA');

  const AiSource(this.label);

  final String label;
}

class AiPolicy {
  const AiPolicy._();

  static const String reviewRequired = 'Revisão humana obrigatória';

  static const String reviewDetail =
      'Confira antes de salvar no prontuário, emitir documento ou enviar '
      'mensagem clínica. Não é diagnóstico nem dose definida.';

  /// Campos que o assistente nunca preenche, mesmo com sugestão pronta.
  static const Set<String> neverSuggested = <String>{
    'hipoteses',
    'avaliacao',
    'dose',
  };

  static String badge(AiSource source) => '${source.label} - $reviewRequired';
}
