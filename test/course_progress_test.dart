import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/services/bunny_service.dart';
import 'package:pediatria360/features/courses/presentation/providers/courses_providers.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/course.dart';

Course course({
  bool requiresPlan = false,
  bool professionalOnly = false,
}) =>
    Course(
      id: 'c1',
      title: 'Curso',
      summary: '',
      level: CourseLevel.intro,
      updatedAt: DateTime.now(),
      requiresPlan: requiresPlan,
      professionalOnly: professionalOnly,
    );

Lesson lesson({bool isFree = false}) => Lesson(
      id: 'l1',
      courseId: 'c1',
      title: 'Aula',
      order: 1,
      kind: LessonKind.video,
      isFree: isFree,
    );

AppUser user({
  UserPlan plan = UserPlan.free,
  UserRole role = UserRole.parent,
  bool verified = false,
  DateTime? planExpiresAt,
}) =>
    AppUser(
      uid: 'u1',
      email: 'a@b.c',
      name: 'Ana Silva',
      role: role,
      plan: plan,
      professionalVerified: verified,
      planExpiresAt: planExpiresAt,
      createdAt: DateTime.now(),
    );

void main() {
  group('bloqueio de aula', () {
    test('curso aberto libera para qualquer um', () {
      expect(
        lockFor(course: course(), lesson: lesson(), user: user()),
        LessonLock.none,
      );
    });

    test('curso pago bloqueia usuário do plano gratuito', () {
      expect(
        lockFor(
          course: course(requiresPlan: true),
          lesson: lesson(),
          user: user(),
        ),
        LessonLock.requiresPlan,
      );
    });

    test('aula de amostra abre mesmo em curso pago', () {
      expect(
        lockFor(
          course: course(requiresPlan: true),
          lesson: lesson(isFree: true),
          user: user(),
        ),
        LessonLock.none,
      );
    });

    test('plano ativo libera curso pago', () {
      expect(
        lockFor(
          course: course(requiresPlan: true),
          lesson: lesson(),
          user: user(plan: UserPlan.premium),
        ),
        LessonLock.none,
      );
    });

    test('plano expirado não libera', () {
      expect(
        lockFor(
          course: course(requiresPlan: true),
          lesson: lesson(),
          user: user(
            plan: UserPlan.premium,
            planExpiresAt: DateTime(2020),
          ),
        ),
        LessonLock.requiresPlan,
      );
    });

    test('curso profissional exige registro verificado', () {
      // Declarar-se profissional no cadastro não basta.
      expect(
        lockFor(
          course: course(professionalOnly: true),
          lesson: lesson(),
          user: user(role: UserRole.professional),
        ),
        LessonLock.requiresProfessional,
      );

      expect(
        lockFor(
          course: course(professionalOnly: true),
          lesson: lesson(),
          user: user(role: UserRole.professional, verified: true),
        ),
        LessonLock.none,
      );
    });

    test('amostra não fura a barreira profissional', () {
      // Aula gratuita libera pagamento, mas não competência clínica.
      expect(
        lockFor(
          course: course(professionalOnly: true),
          lesson: lesson(isFree: true),
          user: user(),
        ),
        LessonLock.requiresProfessional,
      );
    });

    test('deslogado é tratado como plano gratuito', () {
      expect(
        lockFor(
          course: course(requiresPlan: true),
          lesson: lesson(),
          user: null,
        ),
        LessonLock.requiresPlan,
      );
    });
  });

  group('progresso do curso', () {
    test('curso vazio não divide por zero', () {
      const CourseProgress p = CourseProgress.empty('c1');
      expect(p.ratio, 0);
      expect(p.percent, 0);
      expect(p.isComplete, isFalse);
    });

    test('calcula proporção e percentual', () {
      const CourseProgress p = CourseProgress(
        courseId: 'c1',
        completedLessons: 3,
        totalLessons: 8,
      );
      expect(p.ratio, closeTo(0.375, 0.001));
      expect(p.percent, 38);
      expect(p.isStarted, isTrue);
      expect(p.isComplete, isFalse);
    });

    test('conclusão total', () {
      const CourseProgress p = CourseProgress(
        courseId: 'c1',
        completedLessons: 8,
        totalLessons: 8,
      );
      expect(p.isComplete, isTrue);
      expect(p.percent, 100);
    });
  });

  group('formatação de duração', () {
    test('curso abaixo de uma hora', () {
      expect(
        Course(
          id: 'c',
          title: '',
          summary: '',
          level: CourseLevel.intro,
          updatedAt: DateTime.now(),
          totalMinutes: 45,
        ).durationLabel,
        '45 min',
      );
    });

    test('horas exatas omitem os minutos', () {
      expect(
        Course(
          id: 'c',
          title: '',
          summary: '',
          level: CourseLevel.intro,
          updatedAt: DateTime.now(),
          totalMinutes: 120,
        ).durationLabel,
        '2h',
      );
    });

    test('horas com resto', () {
      expect(
        Course(
          id: 'c',
          title: '',
          summary: '',
          level: CourseLevel.intro,
          updatedAt: DateTime.now(),
          totalMinutes: 95,
        ).durationLabel,
        '1h 35min',
      );
    });
  });

  group('estado do vídeo no Bunny', () {
    test('mapeia os códigos da API', () {
      expect(BunnyVideoStatus.fromCode(0), BunnyVideoStatus.queued);
      expect(BunnyVideoStatus.fromCode(2), BunnyVideoStatus.processing);
      expect(BunnyVideoStatus.fromCode(3), BunnyVideoStatus.encoding);
      expect(BunnyVideoStatus.fromCode(4), BunnyVideoStatus.ready);
    });

    test('código desconhecido é tratado como falha, não como pronto', () {
      // Tratar o desconhecido como pronto faria o player tentar reproduzir um
      // vídeo inexistente e mostrar erro genérico ao usuário.
      expect(BunnyVideoStatus.fromCode(99), BunnyVideoStatus.failed);
      expect(BunnyVideoStatus.fromCode(5).isPlayable, isFalse);
    });

    test('apenas ready é reproduzível', () {
      expect(BunnyVideoStatus.ready.isPlayable, isTrue);
      expect(BunnyVideoStatus.encoding.isPlayable, isFalse);
    });
  });
}
