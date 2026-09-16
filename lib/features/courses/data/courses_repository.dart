import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/course.dart';

/// Acesso a cursos, aulas e progresso.
class CoursesRepository {
  const CoursesRepository({
    required FirebaseFirestore firestore,
    required CacheService cache,
  })  : _firestore = firestore,
        _cache = cache;

  final FirebaseFirestore _firestore;
  final CacheService _cache;

  static const String _cacheKey = 'courses:catalog';

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection(FirestorePaths.courses);

  // ------------------------------------------------------------- Catálogo

  /// Catálogo publicado.
  ///
  /// Cursos que exigem plano ou registro profissional continuam **visíveis** —
  /// esconder o que existe impede a pessoa de saber o que ganharia assinando.
  /// O bloqueio acontece na reprodução, não na listagem.
  Future<Result<List<Course>>> catalog({AppUser? user}) => guard(() async {
        Query<Map<String, dynamic>> query = _courses
            .where('published', isEqualTo: true)
            .orderBy('updatedAt', descending: true)
            .limit(50);

        final bool isProfessional = user?.role.isProfessional ?? false;
        if (!isProfessional) {
          query = query.where('professionalOnly', isEqualTo: false);
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        final List<Course> courses = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                _courseFrom(d.id, d.data()))
            .toList(growable: false);

        await _cache.write(
          _cacheKey,
          courses.map(_courseToMap).toList(growable: false),
          ttl: AppConfig.cacheTtlMedium,
        );

        return courses;
      });

  List<Course> cachedCatalog() => _cache
      .readList(_cacheKey)
      .map((Map<String, dynamic> m) => _courseFrom(m['id'] as String? ?? '', m))
      .toList(growable: false);

  Future<Result<Course>> course(String courseId) => guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _courses.doc(courseId).get();
        if (!doc.exists) throw StateError('Curso não encontrado.');
        return _courseFrom(doc.id, doc.data()!);
      });

  Future<Result<List<Lesson>>> lessons(String courseId) => guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection(FirestorePaths.courseLessons(courseId))
            .orderBy('order')
            .get();

        final List<Lesson> lessons = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                _lessonFrom(d.id, courseId, d.data()))
            .toList(growable: false);

        await _cache.write(
          'courses:lessons:$courseId',
          lessons.map(_lessonToMap).toList(growable: false),
          ttl: AppConfig.cacheTtlMedium,
        );

        return lessons;
      });

  List<Lesson> cachedLessons(String courseId) => _cache
      .readList('courses:lessons:$courseId')
      .map(
        (Map<String, dynamic> m) => _lessonFrom(
          m['id'] as String? ?? '',
          courseId,
          m,
        ),
      )
      .toList(growable: false);

  // ------------------------------------------------------------- Progresso

  /// Progresso do usuário em todas as aulas de um curso.
  Stream<List<LessonProgress>> watchProgress({
    required String uid,
    required String courseId,
  }) =>
      _firestore
          .collection(FirestorePaths.userProgress(uid))
          .where('courseId', isEqualTo: courseId)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      LessonProgress(
                    lessonId: (d.data()['lessonId'] as String?) ?? d.id,
                    courseId: courseId,
                    positionSeconds:
                        (d.data()['positionSeconds'] as num?)?.toInt() ?? 0,
                    completed: (d.data()['completed'] as bool?) ?? false,
                    updatedAt:
                        (d.data()['updatedAt'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
                  ),
                )
                .toList(growable: false),
          );

  /// Salva a posição de reprodução.
  ///
  /// Chamado a cada 10 segundos pelo player, não a cada frame — gravar
  /// continuamente queimaria a cota de escrita do Firestore sem nenhum ganho
  /// para o usuário.
  Future<Result<void>> saveProgress({
    required String uid,
    required String courseId,
    required String lessonId,
    required int positionSeconds,
    required bool completed,
  }) =>
      guard(() async {
        await _firestore
            .collection(FirestorePaths.userProgress(uid))
            .doc('${courseId}_$lessonId')
            .set(
          <String, dynamic>{
            'courseId': courseId,
            'lessonId': lessonId,
            'positionSeconds': positionSeconds,
            'completed': completed,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

  /// Progresso agregado de todos os cursos iniciados.
  Future<Result<Map<String, CourseProgress>>> allProgress(String uid) =>
      guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection(FirestorePaths.userProgress(uid))
            .get();

        final Map<String, List<Map<String, dynamic>>> byCourse =
            <String, List<Map<String, dynamic>>>{};

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final String courseId = (doc.data()['courseId'] as String?) ?? '';
          if (courseId.isEmpty) continue;
          byCourse.putIfAbsent(courseId, () => <Map<String, dynamic>>[])
              .add(doc.data());
        }

        final Map<String, CourseProgress> result =
            <String, CourseProgress>{};

        for (final MapEntry<String, List<Map<String, dynamic>>> entry
            in byCourse.entries) {
          final int completed = entry.value
              .where((Map<String, dynamic> m) => m['completed'] == true)
              .length;

          entry.value.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final Timestamp? ta = a['updatedAt'] as Timestamp?;
            final Timestamp? tb = b['updatedAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          result[entry.key] = CourseProgress(
            courseId: entry.key,
            completedLessons: completed,
            totalLessons: entry.value.length,
            lastLessonId: entry.value.first['lessonId'] as String?,
          );
        }

        return result;
      });

  // ------------------------------------------------------------ Conversores

  static Course _courseFrom(String id, Map<String, dynamic> data) => Course(
        id: id,
        title: (data['title'] as String?) ?? '',
        summary: (data['summary'] as String?) ?? '',
        level: CourseLevel.fromName(data['level'] as String?),
        updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
        coverUrl: data['coverUrl'] as String?,
        trailerVideoGuid: data['trailerVideoGuid'] as String?,
        instructor: data['instructor'] as String?,
        instructorTitle: data['instructorTitle'] as String?,
        lessonCount: (data['lessonCount'] as num?)?.toInt() ?? 0,
        totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
        tags: (data['tags'] as List<dynamic>?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const <String>[],
        requiresPlan: (data['requiresPlan'] as bool?) ?? false,
        professionalOnly: (data['professionalOnly'] as bool?) ?? false,
        published: (data['published'] as bool?) ?? true,
        certificateEnabled: (data['certificateEnabled'] as bool?) ?? false,
      );

  static Map<String, dynamic> _courseToMap(Course c) => <String, dynamic>{
        'id': c.id,
        'title': c.title,
        'summary': c.summary,
        'level': c.level.name,
        'updatedAt': c.updatedAt.toUtc().millisecondsSinceEpoch,
        'coverUrl': c.coverUrl,
        'trailerVideoGuid': c.trailerVideoGuid,
        'instructor': c.instructor,
        'instructorTitle': c.instructorTitle,
        'lessonCount': c.lessonCount,
        'totalMinutes': c.totalMinutes,
        'tags': c.tags,
        'requiresPlan': c.requiresPlan,
        'professionalOnly': c.professionalOnly,
        'published': c.published,
        'certificateEnabled': c.certificateEnabled,
      };

  static Lesson _lessonFrom(
    String id,
    String courseId,
    Map<String, dynamic> data,
  ) =>
      Lesson(
        id: id,
        courseId: courseId,
        title: (data['title'] as String?) ?? '',
        order: (data['order'] as num?)?.toInt() ?? 0,
        kind: LessonKind.fromName(data['kind'] as String?),
        description: data['description'] as String?,
        videoGuid: data['videoGuid'] as String?,
        audioPath: data['audioPath'] as String?,
        body: data['body'] as String?,
        durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
        isFree: (data['isFree'] as bool?) ?? false,
        attachments:
            ((data['attachments'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (Map<dynamic, dynamic> m) =>
                      LessonAttachment.fromMap(Map<String, dynamic>.from(m)),
                )
                .toList(growable: false),
      );

  static Map<String, dynamic> _lessonToMap(Lesson l) => <String, dynamic>{
        'id': l.id,
        'title': l.title,
        'order': l.order,
        'kind': l.kind.name,
        'description': l.description,
        'videoGuid': l.videoGuid,
        'audioPath': l.audioPath,
        'body': l.body,
        'durationSeconds': l.durationSeconds,
        'isFree': l.isFree,
        'attachments': l.attachments
            .map(
              (LessonAttachment a) => <String, dynamic>{
                'title': a.title,
                'path': a.path,
                'sizeKb': a.sizeKb,
              },
            )
            .toList(growable: false),
      };

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
