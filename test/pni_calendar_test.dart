import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/vaccines/domain/pni_calendar.dart';
import 'package:pediatria360/shared/domain/entities/vaccine.dart';

void main() {
  group('calendário do PNI', () {
    test('não tem dose duplicada (mesma vacina e mesmo índice)', () {
      final Set<String> seen = <String>{};
      for (final VaccineDoseSchedule dose in PniCalendar.schedule) {
        final String key = '${dose.vaccineId}-${dose.doseIndex}';
        expect(seen.add(key), isTrue, reason: 'dose repetida: $key');
      }
    });

    test('doses da mesma vacina crescem em idade junto com o índice', () {
      final Map<String, List<VaccineDoseSchedule>> byVaccine =
          <String, List<VaccineDoseSchedule>>{};
      for (final VaccineDoseSchedule dose in PniCalendar.schedule) {
        byVaccine.putIfAbsent(dose.vaccineId, () => <VaccineDoseSchedule>[])
            .add(dose);
      }

      for (final List<VaccineDoseSchedule> doses in byVaccine.values) {
        doses.sort(
          (VaccineDoseSchedule a, VaccineDoseSchedule b) =>
              a.doseIndex.compareTo(b.doseIndex),
        );
        for (int i = 1; i < doses.length; i++) {
          expect(
            doses[i].ageMonths,
            greaterThanOrEqualTo(doses[i - 1].ageMonths),
            reason: '${doses[i].vaccineName} fora de ordem',
          );
        }
      }
    });

    test('toda dose declara o que previne', () {
      for (final VaccineDoseSchedule dose in PniCalendar.schedule) {
        expect(
          dose.protects,
          isNotEmpty,
          reason: '${dose.vaccineName} sem descrição de proteção',
        );
      }
    });

    test('data prevista soma os meses ao nascimento', () {
      final DateTime birth = DateTime(2025, 3, 10);
      final VaccineDoseSchedule penta = PniCalendar.find('penta', 2)!;

      expect(penta.ageMonths, 4);
      expect(
        PniCalendar.dueDateFor(birth, penta),
        DateTime(2025, 7, 10),
      );
    });

    test('vacina ao nascer vence no próprio dia', () {
      final DateTime birth = DateTime(2025, 3, 10);
      final VaccineDoseSchedule bcg = PniCalendar.find('bcg', 1)!;
      expect(PniCalendar.dueDateFor(birth, bcg), birth);
    });

    test('upTo devolve apenas o que já venceu, em ordem', () {
      final List<VaccineDoseSchedule> upToSixMonths = PniCalendar.upTo(6);

      expect(upToSixMonths, isNotEmpty);
      expect(
        upToSixMonths.every((VaccineDoseSchedule d) => d.ageMonths <= 6),
        isTrue,
      );
      for (int i = 1; i < upToSixMonths.length; i++) {
        expect(
          upToSixMonths[i].ageMonths,
          greaterThanOrEqualTo(upToSixMonths[i - 1].ageMonths),
        );
      }
    });
  });

  group('estado da dose', () {
    VaccineDose dose({DateTime? due, DateTime? applied}) => VaccineDose(
          id: 'd1',
          childId: 'c1',
          vaccineId: 'bcg',
          doseIndex: 1,
          dueAt: due,
          appliedAt: applied,
          updatedAt: DateTime.now(),
        );

    final DateTime now = DateTime(2026, 1, 15);

    test('dose aplicada nunca conta como atrasada', () {
      final VaccineDose d = dose(
        due: DateTime(2025, 1, 1),
        applied: DateTime(2025, 1, 5),
      );
      expect(d.isApplied, isTrue);
      expect(d.isOverdue(at: now), isFalse);
    });

    test('vencida e não aplicada está em atraso', () {
      expect(dose(due: DateTime(2025, 12, 1)).isOverdue(at: now), isTrue);
    });

    test('dentro de 30 dias é próxima, além disso não', () {
      expect(dose(due: DateTime(2026, 2, 1)).isUpcoming(at: now), isTrue);
      expect(dose(due: DateTime(2026, 6, 1)).isUpcoming(at: now), isFalse);
    });
  });
}
