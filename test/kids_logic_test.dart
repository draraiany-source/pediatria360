import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/kids/domain/kids_logic.dart';

void main() {
  test('dez jogos no catálogo e oito histórias', () {
    expect(KidsCatalog.games, hasLength(10));
    expect(KidsCatalog.stories, hasLength(8));
  });

  test('doutor mirim conclui os três instrumentos', () {
    final DoctorGame game = DoctorGame();
    for (final String tool in DoctorGame.tools) {
      game.use(tool);
    }
    expect(game.done, isTrue);
  });

  test('escovação marca cada dente', () {
    final BrushGame game = BrushGame(teeth: 3);
    game.brush(0);
    game.brush(1);
    expect(game.done, isFalse);
    game.brush(2);
    expect(game.done, isTrue);
  });

  test('prato pede três alimentos', () {
    final PlateGame game = PlateGame();
    game.add('maçã');
    game.add('banana');
    expect(game.done, isFalse);
    game.add('brócolis');
    expect(game.done, isTrue);
  });

  test('memória sem cronômetro forma pares', () {
    final MemoryGame game = MemoryGame(pairs: 2);
    final int a = game.deck.indexOf('0');
    final int b = game.deck.lastIndexOf('0');
    game.tap(a);
    game.tap(b);
    expect(game.matched[a], isTrue);
    expect(game.matched[b], isTrue);
  });

  test('quebra-cabeça só encaixa a peça no lugar certo', () {
    final PuzzleGame game = PuzzleGame(size: 2);
    expect(game.place(0, 1), isFalse);
    expect(game.place(0, 0), isTrue);
    expect(game.place(1, 1), isTrue);
    expect(game.done, isTrue);
  });

  test('lavar as mãos segue a ordem', () {
    final StepGame game = StepGame(const <String>['torneira', 'sabonete']);
    expect(game.advance('sabonete'), isFalse);
    expect(game.advance('torneira'), isTrue);
    expect(game.advance('sabonete'), isTrue);
    expect(game.done, isTrue);
  });

  test('emoções exigem escolha e três respirações', () {
    final FeelingGame game = FeelingGame();
    game.breathe();
    expect(game.done, isFalse);
    game.choose('medo');
    game.breathe();
    game.breathe();
    game.breathe();
    expect(game.done, isTrue);
  });

  test('formas só aceitam a cor certa', () {
    final ShapeGame game = ShapeGame();
    expect(game.drop('círculo', 'azul'), isFalse);
    expect(game.drop('círculo', 'vermelho'), isTrue);
    game.drop('quadrado', 'azul');
    game.drop('triângulo', 'amarelo');
    expect(game.done, isTrue);
  });

  test('recepção não guarda conquista permanente', () {
    final KidsProgress progress = KidsProgress();
    progress.complete('memory', persist: false);
    expect(progress.completed, isEmpty);
    progress.clearSession();
    expect(progress.log, isEmpty);
  });

  test('controle parental pode desligar um jogo', () {
    final KidsControls controls = KidsControls();
    controls.allowed.remove('doctor');
    expect(controls.allows('doctor'), isFalse);
    expect(controls.allows('brush'), isTrue);
  });
}
