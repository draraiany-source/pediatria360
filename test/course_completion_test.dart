import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/courses/presentation/providers/courses_providers.dart';
import 'package:pediatria360/shared/domain/entities/course.dart';

/// Testa `isCourseFullyCompleted` — a condição que decide se um curso
/// inteiro (não só uma aula) deve render XP de `courseCompleted`.
///
/// A idempotência de não pontuar duas vezes pela mesma aula/curso vive no
/// servidor (`referenceId` em `awardXp`), não é testável aqui sem simular
/// Firestore e Functions. O que É testável, e o que este arquivo cobre, é
/// a contagem que decide SE o curso terminou — errar essa conta faria
/// `courseCompleted` disparar cedo demais ou nunca disparar.
void main() {
  CourseProgress progress({required int completed, required int total}) =>
      CourseProgress(
        courseId: 'curso-1',
        completedLessons: completed,
        totalLessons: total,
      );

  group('isCourseFullyCompleted', () {
    test('todas as aulas concluídas → completo', () {
      expect(
        isCourseFullyCompleted(progress(completed: 5, total: 5), 5),
        isTrue,
      );
    });

    test('faltam aulas → não completo', () {
      expect(
        isCourseFullyCompleted(progress(completed: 3, total: 5), 5),
        isFalse,
      );
    });

    test('nenhuma aula concluída → não completo', () {
      expect(
        isCourseFullyCompleted(progress(completed: 0, total: 5), 5),
        isFalse,
      );
    });

    test('curso sem aula carregada (total=0) nunca conta como completo', () {
      // Guarda contra o caso degenerado: 0 >= 0 seria tecnicamente
      // verdadeiro, mas um curso sem aula carregada — falha de rede, curso
      // vazio — não deveria disparar XP por engano.
      expect(
        isCourseFullyCompleted(progress(completed: 0, total: 0), 0),
        isFalse,
      );
    });

    test('mais aulas concluídas do que o total (dado inconsistente) ainda conta como completo', () {
      // completedLessons vem de uma contagem separada de totalLessons —
      // não são garantidamente a mesma fonte no momento da chamada. `>=`
      // em vez de `==` absorve essa inconsistência sem quebrar.
      expect(
        isCourseFullyCompleted(progress(completed: 6, total: 5), 5),
        isTrue,
      );
    });
  });
}
