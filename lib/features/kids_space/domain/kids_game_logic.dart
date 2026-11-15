import 'dart:math';

import 'kids_catalog.dart';

/// Motores de jogo deterministicos (sem Firebase, sem dados clinicos).
class MemoryEngine {
  MemoryEngine({required this.pairCount, Random? random})
      : _random = random ?? Random() {
    reset();
  }

  final int pairCount;
  final Random _random;
  late List<int> values;
  late List<bool> matched;
  late List<bool> faceUp;
  int? firstIndex;
  int moves = 0;

  bool get completed => matched.every((bool m) => m);

  void reset() {
    final List<int> deck = <int>[];
    for (int i = 0; i < pairCount; i++) {
      deck
        ..add(i)
        ..add(i);
    }
    deck.shuffle(_random);
    values = deck;
    matched = List<bool>.filled(deck.length, false);
    faceUp = List<bool>.filled(deck.length, false);
    firstIndex = null;
    moves = 0;
  }

  /// Retorna true se o lance fechou um par.
  bool tap(int index) {
    if (matched[index] || faceUp[index]) {
      return false;
    }
    faceUp[index] = true;
    if (firstIndex == null) {
      firstIndex = index;
      return false;
    }
    moves += 1;
    final int a = firstIndex!;
    firstIndex = null;
    if (values[a] == values[index]) {
      matched[a] = true;
      matched[index] = true;
      return true;
    }
    faceUp[a] = false;
    faceUp[index] = false;
    return false;
  }
}

class MatchPair {
  const MatchPair(this.prompt, this.answer);
  final String prompt;
  final String answer;
}

class MatchEngine {
  MatchEngine({required this.pairs, Random? random})
      : _random = random ?? Random() {
    reset();
  }

  final List<MatchPair> pairs;
  final Random _random;
  late List<String> prompts;
  late List<String> options;
  late Map<String, String> answerOf;
  int index = 0;
  int correct = 0;

  bool get completed => index >= prompts.length;

  void reset() {
    final List<MatchPair> shuffled = List<MatchPair>.of(pairs)..shuffle(_random);
    prompts = shuffled.map((MatchPair p) => p.prompt).toList();
    answerOf = <String, String>{
      for (final MatchPair p in shuffled) p.prompt: p.answer,
    };
    options = shuffled.map((MatchPair p) => p.answer).toList()..shuffle(_random);
    index = 0;
    correct = 0;
  }

  bool answer(String option) {
    if (completed) {
      return false;
    }
    final bool ok = answerOf[prompts[index]] == option;
    if (ok) {
      correct += 1;
    }
    index += 1;
    return ok;
  }
}

class OrderEngine {
  OrderEngine({required this.sequence, Random? random})
      : _random = random ?? Random() {
    reset();
  }

  final List<String> sequence;
  final Random _random;
  late List<String> pool;
  final List<String> built = <String>[];

  bool get completed =>
      built.length == sequence.length &&
      List<String>.of(built).toString() == List<String>.of(sequence).toString();

  void reset() {
    pool = List<String>.of(sequence)..shuffle(_random);
    built.clear();
  }

  bool pick(String value) {
    if (!pool.contains(value)) {
      return false;
    }
    pool.remove(value);
    built.add(value);
    if (built.last != sequence[built.length - 1]) {
      pool.add(built.removeLast());
      pool.shuffle(_random);
      return false;
    }
    return true;
  }
}

class AttentionEngine {
  AttentionEngine({
    required this.oddOne,
    required this.others,
    Random? random,
  }) : _random = random ?? Random() {
    reset();
  }

  final String oddOne;
  final List<String> others;
  final Random _random;
  late List<String> choices;
  bool solved = false;

  void reset() {
    choices = <String>[oddOne, ...others]..shuffle(_random);
    solved = false;
  }

  bool pick(String value) {
    if (value == oddOne) {
      solved = true;
      return true;
    }
    return false;
  }
}

class KidsGameFactory {
  static MemoryEngine memory({KidsAgeBand band = KidsAgeBand.preschool}) {
    final int pairs = switch (band) {
      KidsAgeBand.toddler => 3,
      KidsAgeBand.preschool => 4,
      KidsAgeBand.school => 6,
    };
    return MemoryEngine(pairCount: pairs, random: Random(42));
  }

  static MatchEngine colorsShapes() => MatchEngine(
        pairs: const <MatchPair>[
          MatchPair('Circulo', 'Amarelo'),
          MatchPair('Quadrado', 'Azul'),
          MatchPair('Triangulo', 'Verde'),
          MatchPair('Estrela', 'Rosa'),
        ],
        random: Random(7),
      );

  static MatchEngine hygieneFood() => MatchEngine(
        pairs: const <MatchPair>[
          MatchPair('Antes de comer', 'Lavar as maos'),
          MatchPair('Depois do banheiro', 'Lavar as maos'),
          MatchPair('Lanche bom', 'Fruta'),
          MatchPair('Beber mais', 'Agua'),
        ],
        random: Random(11),
      );

  static OrderEngine numbersLetters({required bool letters}) {
    if (letters) {
      return OrderEngine(
        sequence: const <String>['A', 'B', 'C', 'D'],
        random: Random(3),
      );
    }
    return OrderEngine(
      sequence: const <String>['1', '2', '3', '4'],
      random: Random(5),
    );
  }

  static OrderEngine puzzle() => OrderEngine(
        sequence: const <String>['1', '2', '3', '4'],
        random: Random(9),
      );

  static AttentionEngine attention() => AttentionEngine(
        oddOne: 'star',
        others: const <String>['circle', 'circle', 'circle'],
        random: Random(13),
      );

  static int starsFor({
    required KidsGameId id,
    required bool won,
    int moves = 0,
  }) {
    if (!won) {
      return 0;
    }
    return switch (id) {
      KidsGameId.memory => moves <= 8 ? 3 : (moves <= 14 ? 2 : 1),
      _ => 3,
    };
  }
}
