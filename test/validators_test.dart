import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pediatria360/core/utils/validators.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  group('Validators.cpf', () {
    test('aceita CPF valido', () {
      expect(Validators.cpf('529.982.247-25'), isNull);
    });

    test('rejeita digito verificador errado', () {
      expect(Validators.cpf('529.982.247-24'), isNotNull);
    });

    test('rejeita sequencia repetida', () {
      expect(Validators.cpf('111.111.111-11'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('exige oito caracteres', () {
      expect(Validators.password('ab12'), isNotNull);
    });

    test('exige letra e numero', () {
      expect(Validators.password('abcdefghij'), isNotNull);
      expect(Validators.password('1234567890'), isNotNull);
    });

    test('aceita senha valida', () {
      expect(Validators.password('pediatria360'), isNull);
    });
  });

  group('Validators.weightKg', () {
    test('aceita virgula decimal', () {
      expect(Validators.weightKg('3,4'), isNull);
    });

    test('rejeita peso fora da faixa pediatrica', () {
      expect(Validators.weightKg('200'), isNotNull);
    });
  });

  group('Formatters.pediatricAge', () {
    // Convencao clinica: meses ate os 2 anos, anos depois disso.
    test('conta em dias no primeiro mes', () {
      final DateTime hoje = DateTime(2026, 1, 20);
      expect(
        Formatters.pediatricAge(DateTime(2026, 1, 10), at: hoje),
        '10 dias',
      );
    });

    test('conta em meses ate 24 meses', () {
      final DateTime hoje = DateTime(2026, 1, 10);
      expect(
        Formatters.pediatricAge(DateTime(2024, 7, 10), at: hoje),
        '18 meses',
      );
    });

    test('passa a anos a partir de 24 meses', () {
      final DateTime hoje = DateTime(2026, 1, 10);
      expect(
        Formatters.pediatricAge(DateTime(2023, 1, 10), at: hoje),
        '3 anos',
      );
    });
  });
}
