import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/supplementation/domain/supplement_ai.dart';
import 'package:pediatria360/features/supplementation/domain/supplement_calculator.dart';
import 'package:pediatria360/features/supplementation/domain/supplement_catalog.dart';

void main() {
  group('supplement catalog', () {
    test('has expected micronutrients', () {
      expect(kMicronutrientCatalog.length, 16);
      expect(micronutrientById('iron')?.name, 'Ferro');
      expect(kLabExamCatalog.any((e) => e.id == 'ferritin'), isTrue);
      expect(kSupplementProtocols.length, greaterThanOrEqualTo(10));
    });

    test('sections use pending placeholder (no invented doses)', () {
      final iron = micronutrientById('iron')!;
      for (final s in iron.sections) {
        expect(s.body, kSupplementContentPending);
      }
    });
  });

  group('calculator engine', () {
    test('does not invent numeric doses', () {
      const engine = SupplementCalculatorEngine();
      final suggestion = engine.suggest(
        const SupplementCalculatorInput(
          micronutrientId: 'iron',
          ageYears: 3,
          weightKg: 14,
          goal: SupplementGoal.treatment,
        ),
      );
      expect(suggestion.doseLine, kSupplementContentPending);
      expect(suggestion.safetyAlerts, isNotEmpty);
      expect(suggestion.summary, contains('CONFERENCIA'));
    });
  });

  group('ai organizer', () {
    test('structures free text without diagnosing', () {
      const org = SupplementAiLocalOrganizer();
      final draft = org.organizeFromFreeText(
        'Crianca de 3 anos, 14 kg, seletividade alimentar, Hb 10,5 e ferritina 8.',
      );
      expect(draft.patientBlock.keys, contains('Idade'));
      expect(draft.examsBlock.keys, contains('Ferritina'));
      expect(draft.disclaimer, contains('responsabilidade'));
      expect(draft.shortcuts, contains('ferro'));
    });
  });
}
