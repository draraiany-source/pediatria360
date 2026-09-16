import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/gamification.dart';

void main() {
  group('sequência de dias', () {
    // A tolerância é a decisão de produto mais importante daqui: um app de
    // saúde infantil não pode punir quem passou a noite no pronto-socorro.
    final DateTime day1 = DateTime(2026, 3, 10);

    test('primeira atividade inicia em 1', () {
      const Streak s = Streak(currentDays: 0, longestDays: 0);
      final Streak next = s.registerActivity(at: day1);
      expect(next.currentDays, 1);
      expect(next.longestDays, 1);
    });

    test('mesmo dia não soma duas vezes', () {
      final Streak s = const Streak(currentDays: 0, longestDays: 0)
          .registerActivity(at: day1)
          .registerActivity(at: day1.add(const Duration(hours: 6)));
      expect(s.currentDays, 1);
    });

    test('dias consecutivos somam', () {
      Streak s = const Streak(currentDays: 0, longestDays: 0);
      for (int i = 0; i < 5; i++) {
        s = s.registerActivity(at: day1.add(Duration(days: i)));
      }
      expect(s.currentDays, 5);
      expect(s.longestDays, 5);
    });

    test('um dia perdido não zera: a tolerância cobre', () {
      Streak s = const Streak(currentDays: 0, longestDays: 0)
          .registerActivity(at: day1)
          .registerActivity(at: day1.add(const Duration(days: 1)));
      expect(s.currentDays, 2);

      // Pula o dia 3, volta no dia 4.
      s = s.registerActivity(at: day1.add(const Duration(days: 3)));
      expect(s.currentDays, 3);
      expect(s.graceUsedThisWeek, isTrue);
    });

    test('segundo dia perdido na mesma semana zera', () {
      Streak s = const Streak(currentDays: 0, longestDays: 0)
          .registerActivity(at: day1)
          .registerActivity(at: day1.add(const Duration(days: 2)));
      expect(s.graceUsedThisWeek, isTrue);

      s = s.registerActivity(at: day1.add(const Duration(days: 4)));
      expect(s.currentDays, 1);
    });

    test('três dias de ausência zera mesmo com tolerância disponível', () {
      final Streak s = const Streak(currentDays: 0, longestDays: 0)
          .registerActivity(at: day1)
          .registerActivity(at: day1.add(const Duration(days: 4)));
      expect(s.currentDays, 1);
    });

    test('o recorde não é perdido ao zerar', () {
      Streak s = const Streak(currentDays: 0, longestDays: 0);
      for (int i = 0; i < 10; i++) {
        s = s.registerActivity(at: day1.add(Duration(days: i)));
      }
      expect(s.longestDays, 10);

      s = s.registerActivity(at: day1.add(const Duration(days: 30)));
      expect(s.currentDays, 1);
      expect(s.longestDays, 10);
    });
  });

  group('nível a partir do XP', () {
    AppUser user(int xp) => AppUser(
          uid: 'u',
          email: 'a@b.c',
          name: 'Ana',
          role: UserRole.parent,
          plan: UserPlan.free,
          xp: xp,
          createdAt: DateTime.now(),
        );

    test('começa no nível 1', () {
      expect(user(0).level, 1);
      expect(user(99).level, 1);
    });

    test('100 XP alcança o nível 2', () {
      expect(user(100).level, 2);
    });

    test('cada nível custa 20% mais que o anterior', () {
      // 100 para o nível 2, +120 para o 3, +144 para o 4.
      expect(user(220).level, 3);
      expect(user(364).level, 4);
    });

    test('progresso fica entre 0 e 1', () {
      for (final int xp in <int>[0, 50, 100, 500, 5000]) {
        expect(user(xp).levelProgress, inInclusiveRange(0, 1));
      }
    });

    test('progresso zera ao subir de nível', () {
      expect(user(100).levelProgress, closeTo(0, 0.001));
    });
  });

  group('desafio', () {
    test('proporção não passa de 1', () {
      const Challenge c = Challenge(
        id: 'c',
        title: '',
        description: '',
        xpReward: 50,
        target: 5,
        progress: 9,
      );
      expect(c.ratio, 1);
    });

    test('alvo zero não divide por zero', () {
      const Challenge c = Challenge(
        id: 'c',
        title: '',
        description: '',
        xpReward: 10,
        target: 0,
      );
      expect(c.ratio, 0);
    });
  });
}
