import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/bunny_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/course.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/courses_repository.dart';

final Provider<BunnyService> bunnyServiceProvider = Provider<BunnyService>(
  (Ref ref) => BunnyService(
    dio: ref.watch(dioProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final Provider<CoursesRepository> coursesRepositoryProvider =
    Provider<CoursesRepository>(
  (Ref ref) => CoursesRepository(
    firestore: ref.watch(firestoreProvider),
    cache: ref.watch(cacheServiceProvider),
  ),
);

/// Catálogo, com o cache pintando a tela antes da rede responder.
final FutureProvider<List<Course>> courseCatalogProvider =
    FutureProvider<List<Course>>((Ref ref) async {
  final CoursesRepository repository = ref.watch(coursesRepositoryProvider);
  final AppUser? user = ref.watch(currentUserProvider);

  final Result<List<Course>> result = await repository.catalog(user: user);

  return result.fold(
    (List<Course> courses) => courses,
    (Failure failure) {
      final List<Course> cached = repository.cachedCatalog();
      if (cached.isNotEmpty) return cached;
      throw failure;
    },
  );
});

final FutureProviderFamily<Course, String> courseProvider =
    FutureProvider.family<Course, String>((Ref ref, String courseId) async {
  final Result<Course> result =
      await ref.watch(coursesRepositoryProvider).course(courseId);
  return result.fold(
    (Course course) => course,
    (Failure failure) => throw failure,
  );
});

final FutureProviderFamily<List<Lesson>, String> lessonsProvider =
    FutureProvider.family<List<Lesson>, String>((Ref ref, String courseId) async {
  final CoursesRepository repository = ref.watch(coursesRepositoryProvider);
  final Result<List<Lesson>> result = await repository.lessons(courseId);

  return result.fold(
    (List<Lesson> lessons) => lessons,
    (Failure failure) {
      final List<Lesson> cached = repository.cachedLessons(courseId);
      if (cached.isNotEmpty) return cached;
      throw failure;
    },
  );
});

final StreamProviderFamily<List<LessonProgress>, String>
    courseProgressProvider =
    StreamProvider.family<List<LessonProgress>, String>(
        (Ref ref, String courseId) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<LessonProgress>>.value(const <LessonProgress>[]);
  }
  return ref
      .watch(coursesRepositoryProvider)
      .watchProgress(uid: uid, courseId: courseId);
});

/// Resumo do progresso de um curso, já cruzado com o total de aulas.
final ProviderFamily<CourseProgress, String> courseProgressSummaryProvider =
    Provider.family<CourseProgress, String>((Ref ref, String courseId) {
  final List<LessonProgress> progress =
      ref.watch(courseProgressProvider(courseId)).valueOrNull ??
          const <LessonProgress>[];
  final List<Lesson> lessons =
      ref.watch(lessonsProvider(courseId)).valueOrNull ?? const <Lesson>[];

  if (lessons.isEmpty) return CourseProgress.empty(courseId);

  final int completed =
      progress.where((LessonProgress p) => p.completed).length;

  LessonProgress? last;
  for (final LessonProgress p in progress) {
    if (last == null || p.updatedAt.isAfter(last.updatedAt)) last = p;
  }

  return CourseProgress(
    courseId: courseId,
    completedLessons: completed,
    totalLessons: lessons.length,
    lastLessonId: last?.lessonId,
  );
});

/// Motivo pelo qual uma aula está bloqueada, se estiver.
enum LessonLock {
  none,
  requiresPlan,
  requiresProfessional;

  String get message => switch (this) {
        LessonLock.none => '',
        LessonLock.requiresPlan =>
          'Esta aula faz parte do plano Premium. A primeira aula do curso '
              'está aberta para você conhecer.',
        LessonLock.requiresProfessional =>
          'Conteúdo para profissionais de saúde com registro verificado.',
      };
}

/// Decide se o usuário pode assistir a uma aula.
///
/// A verificação também existe nas regras do Firestore e na Function que
/// assina a URL de reprodução. Aqui é conveniência de interface — bloquear só
/// no cliente seria contornável trocando um booleano na memória.
LessonLock lockFor({
  required Course course,
  required Lesson lesson,
  required AppUser? user,
}) {
  if (course.professionalOnly && !(user?.canPrescribe ?? false)) {
    return LessonLock.requiresProfessional;
  }
  // Aula marcada como amostra abre para qualquer um: é o que converte.
  if (lesson.isFree) return LessonLock.none;
  if (course.requiresPlan && !(user?.planActive ?? false)) {
    return LessonLock.requiresPlan;
  }
  return LessonLock.none;
}

/// Um curso está completo quando toda aula dele foi marcada como concluída.
///
/// Extraída como função nomeada, pura, para poder ser testada sem precisar
/// simular Firestore — a lógica de contagem é o que importa verificar, não
/// a leitura em si.
///
/// `totalLessons == 0` nunca conta como completo: um curso sem aula
/// carregada (falha de rede, curso ainda vazio) não deveria disparar XP por
/// engano só porque `0 >= 0` é tecnicamente verdadeiro.
bool isCourseFullyCompleted(CourseProgress progress, int totalLessons) {
  if (totalLessons == 0) return false;
  return progress.completedLessons >= totalLessons;
}

/// Salva a posição de reprodução.
///
/// ## XP por conclusão — por que fica aqui, não espalhado
///
/// Este é o único funil por onde toda conclusão de aula passa — chamar o
/// `awardXp` aqui, uma vez, cobre qualquer tela que reproduza uma aula, sem
/// duplicar a lógica em cada lugar que chama `save`.
///
/// A idempotência (não pontuar duas vezes pela mesma aula) já é garantida
/// no servidor via `referenceId` — chamar toda vez que `completed` for
/// `true`, mesmo que já tivesse sido marcado antes, é seguro: o servidor
/// decide sozinho se já foi premiado.
class PlaybackController extends Notifier<void> {
  @override
  void build() {}

  Future<void> save({
    required String courseId,
    required String lessonId,
    required int positionSeconds,
    required bool completed,
  }) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    await ref.read(coursesRepositoryProvider).saveProgress(
          uid: uid,
          courseId: courseId,
          lessonId: lessonId,
          positionSeconds: positionSeconds,
          completed: completed,
        );

    if (!completed) return;

    await _awardXp(action: 'lessonCompleted', referenceId: '${courseId}_$lessonId');

    // Curso inteiro concluído: só depois que ESTA aula foi salva como
    // concluída, confere se todas as outras do curso também estão.
    final List<Lesson> lessons =
        (await ref.read(coursesRepositoryProvider).lessons(courseId))
            .valueOrNull ??
        const <Lesson>[];
    if (lessons.isEmpty) return;

    final Map<String, CourseProgress> allProgress =
        (await ref.read(coursesRepositoryProvider).allProgress(uid))
            .valueOrNull ??
        const <String, CourseProgress>{};
    final CourseProgress? progress = allProgress[courseId];

    if (progress != null && isCourseFullyCompleted(progress, lessons.length)) {
      await _awardXp(action: 'courseCompleted', referenceId: courseId);
    }
  }

  Future<void> _awardXp({required String action, required String referenceId}) async {
    try {
      await ref.read(firebaseFunctionsProvider).httpsCallable('awardXp').call(
        <String, dynamic>{'action': action, 'referenceId': referenceId},
      );
    } catch (_) {
      // XP é reforço, não requisito — se a chamada falhar (rede, por
      // exemplo), a aula continua salva como concluída; só o pontinho de
      // experiência não chega desta vez. Não vale interromper o fluxo do
      // usuário por isso.
    }
  }
}

final NotifierProvider<PlaybackController, void> playbackControllerProvider =
    NotifierProvider<PlaybackController, void>(PlaybackController.new);
