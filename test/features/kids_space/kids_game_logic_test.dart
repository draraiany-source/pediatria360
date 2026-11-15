import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/kids_space/domain/kids_catalog.dart';
import 'package:pediatria360/features/kids_space/domain/kids_game_logic.dart';

void main() {
  group('KidsGameFactory', () {
    test('memoria completa pares com baralho fixo', () {
      final MemoryEngine engine = KidsGameFactory.memory();
      expect(engine.values.length, 8);
      // Resolve forcado: vira cada valor com seu par.
      final Map<int, List<int>> byValue = <int, List<int>>{};
      for (int i = 0; i < engine.values.length; i++) {
        byValue.putIfAbsent(engine.values[i], () => <int>[]).add(i);
      }
      for (final List<int> idxs in byValue.values) {
        engine.tap(idxs[0]);
        engine.tap(idxs[1]);
      }
      expect(engine.completed, isTrue);
      expect(KidsGameFactory.starsFor(id: KidsGameId.memory, won: true, moves: engine.moves), greaterThan(0));
    });

    test('cores e formas exige resposta correta', () {
      final MatchEngine engine = KidsGameFactory.colorsShapes();
      final String prompt = engine.prompts.first;
      final String wrong = engine.options.firstWhere(
        (String o) => o != engine.answerOf[prompt],
      );
      expect(engine.answer(wrong), isFalse);
      // apos resposta (certa ou errada) avanca
      expect(engine.index, 1);
    });

    test('atencao so aceita o diferente', () {
      final AttentionEngine engine = KidsGameFactory.attention();
      expect(engine.pick('circle'), isFalse);
      expect(engine.pick('star'), isTrue);
      expect(engine.solved, isTrue);
    });

    test('catalogo nao expoe rotas clinicas', () {
      for (final KidsGameInfo g in KidsGameInfo.all) {
        expect(g.title.toLowerCase().contains('prontuario'), isFalse);
      }
    });
  });
}
