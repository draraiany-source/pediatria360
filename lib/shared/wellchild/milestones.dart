/// Marcos do desenvolvimento registrados na consulta de puericultura.
///
/// A lista de sugestões por faixa é um exemplo para a demonstração: não traz
/// idades esperadas nem critérios de alerta, e precisa ser substituída pela
/// referência adotada pelo serviço (validação clínica pendente).
library;

import 'age_band.dart';

enum MilestoneArea {
  motorGrosso('Motor grosso'),
  motorFino('Motor fino'),
  linguagem('Linguagem'),
  social('Social e afetivo'),
  cognitivo('Cognitivo');

  const MilestoneArea(this.label);
  final String label;
}

enum MilestoneState {
  adquirido('Adquirido'),
  emAquisicao('Em aquisição'),
  naoObservado('Não observado'),
  seguimento('Requer seguimento');

  const MilestoneState(this.label);
  final String label;
}

class MilestoneSuggestion {
  const MilestoneSuggestion(this.code, this.title, this.area, this.band);

  final String code;
  final String title;
  final MilestoneArea area;
  final ChildAgeBand band;
}

const String kMilestoneListNotice =
    'Lista de exemplo para a demonstração, sem idades de referência. '
    'Substituir pela referência adotada pelo serviço (validação clínica '
    'pendente).';

const List<MilestoneSuggestion> kMilestoneExamples = <MilestoneSuggestion>[
  MilestoneSuggestion(
    'b0-sorriso',
    'Sorri em resposta',
    MilestoneArea.social,
    ChildAgeBand.ate3m,
  ),
  MilestoneSuggestion(
    'b0-olhar',
    'Acompanha rostos e objetos com o olhar',
    MilestoneArea.cognitivo,
    ChildAgeBand.ate3m,
  ),
  MilestoneSuggestion(
    'b0-sons',
    'Reage a sons e vozes',
    MilestoneArea.linguagem,
    ChildAgeBand.ate3m,
  ),
  MilestoneSuggestion(
    'b0-cabeca',
    'Levanta a cabeça quando de bruços',
    MilestoneArea.motorGrosso,
    ChildAgeBand.ate3m,
  ),
  MilestoneSuggestion(
    'b1-rola',
    'Rola',
    MilestoneArea.motorGrosso,
    ChildAgeBand.de4a11m,
  ),
  MilestoneSuggestion(
    'b1-senta',
    'Senta sem apoio',
    MilestoneArea.motorGrosso,
    ChildAgeBand.de4a11m,
  ),
  MilestoneSuggestion(
    'b1-transfere',
    'Passa objetos de uma mão para a outra',
    MilestoneArea.motorFino,
    ChildAgeBand.de4a11m,
  ),
  MilestoneSuggestion(
    'b1-balbucia',
    'Balbucia',
    MilestoneArea.linguagem,
    ChildAgeBand.de4a11m,
  ),
  MilestoneSuggestion(
    'b1-estranha',
    'Estranha pessoas desconhecidas',
    MilestoneArea.social,
    ChildAgeBand.de4a11m,
  ),
  MilestoneSuggestion(
    'b2-anda',
    'Anda sem apoio',
    MilestoneArea.motorGrosso,
    ChildAgeBand.de1a2a,
  ),
  MilestoneSuggestion(
    'b2-palavras',
    'Fala palavras com significado',
    MilestoneArea.linguagem,
    ChildAgeBand.de1a2a,
  ),
  MilestoneSuggestion(
    'b2-aponta',
    'Aponta para mostrar o que quer',
    MilestoneArea.social,
    ChildAgeBand.de1a2a,
  ),
  MilestoneSuggestion(
    'b2-empilha',
    'Empilha blocos',
    MilestoneArea.motorFino,
    ChildAgeBand.de1a2a,
  ),
  MilestoneSuggestion(
    'b2-imita',
    'Imita tarefas do dia a dia',
    MilestoneArea.cognitivo,
    ChildAgeBand.de1a2a,
  ),
  MilestoneSuggestion(
    'b3-pula',
    'Pula com os dois pés',
    MilestoneArea.motorGrosso,
    ChildAgeBand.de3a5a,
  ),
  MilestoneSuggestion(
    'b3-frases',
    'Forma frases',
    MilestoneArea.linguagem,
    ChildAgeBand.de3a5a,
  ),
  MilestoneSuggestion(
    'b3-fazdeconta',
    'Brinca de faz de conta',
    MilestoneArea.social,
    ChildAgeBand.de3a5a,
  ),
  MilestoneSuggestion(
    'b3-desenha',
    'Desenha figuras simples',
    MilestoneArea.motorFino,
    ChildAgeBand.de3a5a,
  ),
  MilestoneSuggestion(
    'b4-regras',
    'Participa de jogos com regras',
    MilestoneArea.social,
    ChildAgeBand.de6a,
  ),
  MilestoneSuggestion(
    'b4-escola',
    'Acompanha as atividades da etapa escolar',
    MilestoneArea.cognitivo,
    ChildAgeBand.de6a,
  ),
  MilestoneSuggestion(
    'b4-coordena',
    'Anda de bicicleta ou pratica atividade com coordenação',
    MilestoneArea.motorGrosso,
    ChildAgeBand.de6a,
  ),
];

List<MilestoneSuggestion> milestoneSuggestions(ChildAgeBand band) =>
    kMilestoneExamples
        .where((MilestoneSuggestion s) => s.band == band)
        .toList(growable: false);

class MilestoneObservation {
  const MilestoneObservation({
    required this.code,
    required this.title,
    required this.area,
    required this.state,
    this.note = '',
    this.custom = false,
  });

  factory MilestoneObservation.from(
    MilestoneSuggestion s,
    MilestoneState state,
  ) => MilestoneObservation(
    code: s.code,
    title: s.title,
    area: s.area,
    state: state,
  );

  final String code;
  final String title;
  final MilestoneArea area;
  final MilestoneState state;
  final String note;

  /// Marco escrito pelo profissional, fora da lista de sugestões.
  final bool custom;

  MilestoneObservation copyWith({MilestoneState? state, String? note}) =>
      MilestoneObservation(
        code: code,
        title: title,
        area: area,
        state: state ?? this.state,
        note: note ?? this.note,
        custom: custom,
      );

  bool sameAs(MilestoneObservation o) =>
      code == o.code &&
      title == o.title &&
      area == o.area &&
      state == o.state &&
      note.trim() == o.note.trim();

  String describe() =>
      '$title (${area.label}): ${state.label}'
      '${note.trim().isEmpty ? '' : ' - ${note.trim()}'}';
}
