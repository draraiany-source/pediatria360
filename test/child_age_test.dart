import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/child.dart';

Child build({required DateTime birth, int? gestationalWeeks}) => Child(
      id: 'c1',
      ownerId: 'u1',
      name: 'Ana',
      birthDate: birth,
      sex: ChildSex.female,
      gestationalWeeks: gestationalWeeks,
      updatedAt: DateTime.now(),
    );

void main() {
  group('idade corrigida do prematuro', () {
    test('nascido a termo nao sofre correcao', () {
      final Child child = build(
        birth: DateTime.now().subtract(const Duration(days: 365)),
        gestationalWeeks: 39,
      );
      expect(child.isPreterm, isFalse);
      expect(child.clinicalAgeInMonths, child.ageInMonths);
    });

    test('prematuro de 32 semanas desconta cerca de dois meses', () {
      final Child child = build(
        birth: DateTime.now().subtract(const Duration(days: 365)),
        gestationalWeeks: 32,
      );
      expect(child.isPreterm, isTrue);
      expect(child.correctedAgeInMonths, lessThan(child.ageInMonths));
      expect(child.ageInMonths - child.correctedAgeInMonths, 2);
    });

    test('correcao deixa de valer depois dos 24 meses', () {
      final Child child = build(
        birth: DateTime.now().subtract(const Duration(days: 365 * 3)),
        gestationalWeeks: 30,
      );
      expect(child.clinicalAgeInMonths, child.ageInMonths);
    });
  });
}
