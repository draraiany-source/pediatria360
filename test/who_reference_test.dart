import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/growth/domain/who_reference.dart';
import 'package:pediatria360/shared/domain/entities/child.dart';
import 'package:pediatria360/shared/domain/entities/growth_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WhoReference who;

  setUpAll(() async {
    who = await WhoReference.load();
  });

  group('percentil a partir do escore-Z', () {
    // Valores da distribuição normal padrão. Se a aproximação de erf quebrar,
    // estes testes acusam antes de o app mostrar um percentil errado.
    test('z = 0 corresponde ao percentil 50', () {
      expect(WhoReference.percentileFromZ(0), closeTo(50, 0.01));
    });

    test('z = -1,96 corresponde ao percentil 2,5', () {
      expect(WhoReference.percentileFromZ(-1.96), closeTo(2.5, 0.05));
    });

    test('z = +1,96 corresponde ao percentil 97,5', () {
      expect(WhoReference.percentileFromZ(1.96), closeTo(97.5, 0.05));
    });

    test('z = +1 corresponde ao percentil 84,1', () {
      expect(WhoReference.percentileFromZ(1), closeTo(84.13, 0.05));
    });
  });

  group('matemática LMS', () {
    test('a mediana da tabela devolve escore-Z zero', () {
      final LmsPoint point = who.pointAt(
        GrowthIndicator.weightForAge,
        ChildSex.male,
        12,
      )!;

      final double? z = who.zScore(
        indicator: GrowthIndicator.weightForAge,
        sex: ChildSex.male,
        ageMonths: 12,
        value: point.m,
      );

      expect(z, isNotNull);
      expect(z!, closeTo(0, 1e-9));
    });

    test('converter z em valor e de volta em z fecha o círculo', () {
      for (final double z in <double>[-3, -2, -1, 0, 1, 2, 3]) {
        final double value = who.valueForZ(
          indicator: GrowthIndicator.weightForAge,
          sex: ChildSex.female,
          ageMonths: 24,
          z: z,
        )!;

        final double back = who.zScore(
          indicator: GrowthIndicator.weightForAge,
          sex: ChildSex.female,
          ageMonths: 24,
          value: value,
        )!;

        expect(back, closeTo(z, 1e-6), reason: 'falhou em z = $z');
      }
    });

    test('peso acima da mediana gera escore-Z positivo', () {
      final LmsPoint point =
          who.pointAt(GrowthIndicator.weightForAge, ChildSex.male, 6)!;
      final double? z = who.zScore(
        indicator: GrowthIndicator.weightForAge,
        sex: ChildSex.male,
        ageMonths: 6,
        value: point.m * 1.2,
      );
      expect(z, isNotNull);
      expect(z!, greaterThan(0));
    });

    test('valor inválido não produz escore', () {
      expect(
        who.zScore(
          indicator: GrowthIndicator.weightForAge,
          sex: ChildSex.male,
          ageMonths: 6,
          value: 0,
        ),
        isNull,
      );
    });
  });

  group('classificação', () {
    GrowthAssessment assess(double z) {
      final double value = who.valueForZ(
        indicator: GrowthIndicator.weightForAge,
        sex: ChildSex.male,
        ageMonths: 12,
        z: z,
      )!;
      return who.assess(
        indicator: GrowthIndicator.weightForAge,
        sex: ChildSex.male,
        ageMonths: 12,
        value: value,
      )!;
    }

    test('entre -2 e +1 é adequado', () {
      expect(assess(0).classification, GrowthClassification.adequate);
      expect(assess(-1.5).classification, GrowthClassification.adequate);
    });

    test('abaixo de -2 é peso baixo', () {
      expect(assess(-2.5).classification, GrowthClassification.low);
    });

    test('abaixo de -3 é peso muito baixo', () {
      expect(assess(-3.5).classification, GrowthClassification.severelyLow);
    });

    test('faixas fora do adequado pedem atenção', () {
      expect(assess(-2.5).classification.needsAttention, isTrue);
      expect(assess(0).classification.needsAttention, isFalse);
    });
  });

  group('curva de referência', () {
    test('produz pontos ao longo de toda a faixa pedida', () {
      final List<({double month, double value})> line = who.referenceLine(
        indicator: GrowthIndicator.heightForAge,
        sex: ChildSex.female,
        z: 0,
        fromMonth: 0,
        toMonth: 24,
      );

      expect(line, isNotEmpty);
      expect(line.first.month, 0);
      expect(line.last.month, lessThanOrEqualTo(24));
      // Estatura só cresce: a curva da mediana precisa ser monotônica.
      for (int i = 1; i < line.length; i++) {
        expect(line[i].value, greaterThan(line[i - 1].value));
      }
    });
  });
}
