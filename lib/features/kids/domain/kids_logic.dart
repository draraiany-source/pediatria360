/// Regras puras dos jogos do Espaço Kids. Sem Firebase e sem áudio.
class KidsCatalog {
  const KidsCatalog._();

  static const List<KidsGameInfo> games = <KidsGameInfo>[
    KidsGameInfo('doctor', 'Doutor Mirim', 'Consultório e cuidado'),
    KidsGameInfo('brush', 'Escovação Divertida', 'Dentinhos'),
    KidsGameInfo('food', 'Alimentação Colorida', 'Montar o prato'),
    KidsGameInfo('memory', 'Memória dos Animais', 'Pares, sem pressa'),
    KidsGameInfo('puzzle', 'Quebra-Cabeça da Tia Cris', 'Encaixar peças'),
    KidsGameInfo('hands', 'Lavar as Mãos', 'Sequência'),
    KidsGameInfo('feelings', 'Emoções e Sentimentos', 'Sem diagnóstico'),
    KidsGameInfo('vaccine', 'Aventura das Vacinas', 'Revisão profissional'),
    KidsGameInfo('shapes', 'Formas, Cores e Números', 'Classificar'),
    KidsGameInfo('sleep', 'Missão Sono Tranquilo', 'Rotina da noite'),
  ];

  static const List<KidsStory> stories = <KidsStory>[
    KidsStory('pediatra', 'O Ursinho que Foi ao Pediatra', <String>[
      'O ursinho dourado segurou a gravata roxa e entrou no consultório.',
      'A Tia Cris, de jaleco branco, sorriu e explicou cada passo com calma.',
      'Ele ouviu o coração, viu a luzinha e saiu orgulhoso. Consulta também pode ser gentil.',
    ]),
    KidsStory('vacina', 'A Coragem de Tomar Vacina', <String>[
      'A vacina ajuda o corpo a se preparar. Não é castigo.',
      'O ursinho respirou fundo, a família ficou perto e foi rapidinho.',
      'Depois teve um abraço. Texto para revisão de um pediatra antes de publicar.',
    ]),
    KidsStory('floresta', 'A Floresta dos Alimentos Coloridos', <String>[
      'Na floresta havia vermelho, verde, amarelo e roxo no prato.',
      'Ninguém obrigou o ursinho a limpar o prato. Ele experimentou um pedacinho.',
      'Experimentar sem pressão também é cuidado.',
    ]),
    KidsStory('estrela', 'A Estrelinha que Não Queria Dormir', <String>[
      'A estrelinha queria brincar mais um pouquinho.',
      'Escovou os dentes, vestiu o pijama e guardou um brinquedo.',
      'A história ficou baixinha e o quarto, quieto.',
    ]),
    KidsStory('dente', 'O Dentinho Feliz', <String>[
      'O dentinho tinha uma sujeirinha de brincadeira.',
      'A escova macia e o creme, do tamanho de uma ervilha, fizeram cócegas.',
      'Sorriso limpo, sem pressa.',
    ]),
    KidsStory('sentimentos', 'O Ursinho e Seus Sentimentos', <String>[
      'Às vezes o ursinho ficava triste, com medo ou bravo.',
      'A Tia Cris disse que sentir é permitido. Respirar devagar ajuda.',
      'Isto não é avaliação nem diagnóstico.',
    ]),
    KidsStory('maos', 'A Aventura das Mãos Limpinhas', <String>[
      'Abrir a torneira, ensaboar, esfregar, enxaguar e secar.',
      'O ursinho cantou baixinho enquanto contava até dez.',
      'Mãos limpas para brincar de novo.',
    ]),
    KidsStory('cores', 'Tia Cris e o Mundo das Cores', <String>[
      'Roxo, lilás e rosa pintavam o céu do consultório.',
      'Cada forma tinha uma cor e um número de amigos.',
      'O ursinho separou tudo no lugar certo.',
    ]),
  ];
}

class KidsGameInfo {
  const KidsGameInfo(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;
}

class KidsStory {
  const KidsStory(this.id, this.title, this.pages);

  final String id;
  final String title;
  final List<String> pages;
}

class DoctorGame {
  final Set<String> used = <String>{};

  static const List<String> tools = <String>['ouvir', 'temperatura', 'cuidar'];

  void use(String tool) {
    if (tools.contains(tool)) used.add(tool);
  }

  bool get done => used.length == tools.length;
}

class BrushGame {
  BrushGame({this.teeth = 6}) : clean = List<bool>.filled(teeth, false);

  final int teeth;
  final List<bool> clean;

  void brush(int index) {
    if (index >= 0 && index < clean.length) clean[index] = true;
  }

  bool get done => clean.every((bool c) => c);
}

class PlateGame {
  final Set<String> plate = <String>{};

  static const List<String> foods = <String>[
    'maçã',
    'banana',
    'brócolis',
    'arroz',
    'feijão',
  ];

  void add(String food) {
    if (foods.contains(food)) plate.add(food);
  }

  bool get done => plate.length >= 3;
}

class MemoryGame {
  MemoryGame({this.pairs = 3}) {
    final List<String> faces = <String>[
      for (int i = 0; i < pairs; i++) ...<String>['$i', '$i'],
    ];
    deck = faces;
    open = List<bool>.filled(deck.length, false);
    matched = List<bool>.filled(deck.length, false);
  }

  late final List<String> deck;
  late final List<bool> open;
  late final List<bool> matched;
  final int pairs;
  int? first;
  int moves = 0;

  /// easy 3, medium 4, hard 6 — recria no construtor.
  bool get done => matched.every((bool m) => m);

  void tap(int index) {
    if (matched[index] || open[index]) return;
    open[index] = true;
    if (first == null) {
      first = index;
      return;
    }
    moves += 1;
    if (deck[first!] == deck[index]) {
      matched[first!] = true;
      matched[index] = true;
    } else {
      open[first!] = false;
      open[index] = false;
    }
    first = null;
  }
}

class PuzzleGame {
  PuzzleGame({this.size = 3}) : placed = List<int?>.filled(size, null);

  final int size;
  final List<int?> placed;

  bool place(int piece, int slot) {
    if (slot < 0 || slot >= size || piece != slot) return false;
    if (placed[slot] != null) return false;
    placed[slot] = piece;
    return true;
  }

  bool get done => placed.every((int? p) => p != null);
}

class StepGame {
  StepGame(this.steps);

  final List<String> steps;
  int index = 0;

  bool advance(String step) {
    if (index >= steps.length || step != steps[index]) return false;
    index += 1;
    return true;
  }

  bool get done => index >= steps.length;
}

class FeelingGame {
  String? selected;
  int breaths = 0;

  static const List<String> options = <String>[
    'alegria',
    'tristeza',
    'medo',
    'raiva',
    'surpresa',
  ];

  void choose(String feeling) {
    if (options.contains(feeling)) selected = feeling;
  }

  void breathe() {
    if (selected != null) breaths += 1;
  }

  bool get done => selected != null && breaths >= 3;
}

class ShapeGame {
  final Map<String, String> answer = <String, String>{
    'círculo': 'vermelho',
    'quadrado': 'azul',
    'triângulo': 'amarelo',
  };
  final Map<String, String> placed = <String, String>{};

  bool drop(String shape, String color) {
    if (answer[shape] != color) return false;
    placed[shape] = color;
    return true;
  }

  bool get done => placed.length == answer.length;
}

class KidsProgress {
  final Set<String> completed = <String>{};
  final List<String> log = <String>[];

  void complete(String gameId, {required bool persist}) {
    if (!persist) {
      log.add('sessão-temporária:$gameId');
      return;
    }
    completed.add(gameId);
    log.add(gameId);
  }

  void clearSession() {
    log.removeWhere((String e) => e.startsWith('sessão-temporária:'));
  }
}

class KidsControls {
  bool reducedStimuli = false;
  bool sound = true;
  bool animations = true;
  bool aiAllowed = false;
  bool micAllowed = false;
  int maxMinutes = 20;
  bool reception = false;
  final Set<String> allowed = <String>{
    for (final KidsGameInfo g in KidsCatalog.games) g.id,
  };

  bool allows(String gameId) => allowed.contains(gameId);
}
