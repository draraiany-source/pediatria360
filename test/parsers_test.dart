import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/utils/validators.dart';

/// Testa `Parsers.decimal` diretamente.
///
/// ## Por que este arquivo precisava existir
///
/// Todo teste de calculadora clínica neste projeto — dose, TIG, osmolaridade,
/// débito urinário — chama a função de cálculo já com um `double` pronto.
/// Nenhum passava pelo parser de texto de verdade. Um bug ali seria invisível
/// para a suíte inteira: a matemática do cálculo estaria certa, e o número
/// que chega até ela, errado.
///
/// Foi exatamente o que aconteceu: a versão anterior lia "3.000" (três mil,
/// no formato brasileiro) como `3.0` — mil vezes menor, sem erro, sem aviso.
void main() {
  group('separador decimal brasileiro (vírgula)', () {
    test('vírgula simples', () {
      expect(Parsers.decimal('5,5'), 5.5);
      expect(Parsers.decimal('12,5'), 12.5);
      expect(Parsers.decimal('0,5'), 0.5);
    });

    test('negativo com vírgula', () {
      expect(Parsers.decimal('-5,5'), -5.5);
    });
  });

  group('separador de milhar — o bug que motivou este arquivo', () {
    test('milhar com decimal não retorna mais nulo', () {
      // Antes: "1.234,5" virava "1.234.5" (dois pontos) e
      // double.tryParse devolvia null — a calculadora simplesmente não
      // calculava nada, sem explicar por quê.
      expect(Parsers.decimal('1.234,5'), 1234.5);
    });

    test('milhar redondo não perde três ordens de grandeza', () {
      // Antes: "3.000" (dose máxima diária plausível de um medicamento
      // real) retornava 3.0 — silenciosamente, sem erro.
      expect(Parsers.decimal('3.000'), 3000.0);
    });

    test('milhar duplo, sem parte decimal', () {
      expect(Parsers.decimal('1.234.567'), 1234567.0);
    });

    test('milhar de três dígitos exatos', () {
      expect(Parsers.decimal('12.345,67'), 12345.67);
    });
  });

  group('ponto único permanece decimal — ambiguidade resolvida a favor do caso comum', () {
    test('o que um teclado numérico digita para "5 vírgula 5"', () {
      // Um único ponto sem vírgula não tem como ser diferenciado entre
      // "5.5" (decimal, o que o teclado numérico produz) e "1.234" querendo
      // dizer mil e duzentos. A escolha é manter a leitura decimal, que é o
      // caso mais comum na prática — mudar isso quebraria o caso frequente
      // para consertar um caso ambíguo.
      expect(Parsers.decimal('5.5'), 5.5);
      expect(Parsers.decimal('12.5'), 12.5);
    });
  });

  group('casos de borda', () {
    test('nulo', () {
      expect(Parsers.decimal(null), isNull);
    });

    test('vazio ou só espaço', () {
      expect(Parsers.decimal(''), isNull);
      expect(Parsers.decimal('   '), isNull);
    });

    test('texto não numérico', () {
      expect(Parsers.decimal('abc'), isNull);
      expect(Parsers.decimal('12,5mg'), isNull);
    });

    test('inteiro sem separador', () {
      expect(Parsers.decimal('7'), 7.0);
    });

    test('espaços nas bordas são ignorados', () {
      expect(Parsers.decimal('  5,5  '), 5.5);
    });

    test('zero', () {
      expect(Parsers.decimal('0'), 0.0);
      expect(Parsers.decimal('0,0'), 0.0);
    });
  });

  group('Parsers.integer', () {
    test('extrai apenas dígitos', () {
      expect(Parsers.integer('42'), 42);
      expect(Parsers.integer('(11) 98888-7777'), 11988887777);
    });

    test('nulo ou sem dígito nenhum', () {
      expect(Parsers.integer(null), isNull);
      expect(Parsers.integer('abc'), isNull);
    });
  });
}
