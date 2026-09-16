import 'package:equatable/equatable.dart';

/// Tipo de mídia de uma aula.
enum LessonKind {
  video,
  audio,
  text,
  quiz;

  static LessonKind fromName(String? value) => LessonKind.values.firstWhere(
        (LessonKind k) => k.name == value,
        orElse: () => LessonKind.video,
      );

  String get label => switch (this) {
        LessonKind.video => 'Vídeo',
        LessonKind.audio => 'Áudio',
        LessonKind.text => 'Leitura',
        LessonKind.quiz => 'Exercício',
      };
}

/// Nível do curso.
enum CourseLevel {
  intro,
  intermediate,
  advanced;

  static CourseLevel fromName(String? value) => CourseLevel.values.firstWhere(
        (CourseLevel l) => l.name == value,
        orElse: () => CourseLevel.intro,
      );

  String get label => switch (this) {
        CourseLevel.intro => 'Introdutório',
        CourseLevel.intermediate => 'Intermediário',
        CourseLevel.advanced => 'Avançado',
      };
}

/// Um curso.
class Course extends Equatable {
  const Course({
    required this.id,
    required this.title,
    required this.summary,
    required this.level,
    required this.updatedAt,
    this.coverUrl,
    this.trailerVideoGuid,
    this.instructor,
    this.instructorTitle,
    this.lessonCount = 0,
    this.totalMinutes = 0,
    this.tags = const <String>[],
    this.requiresPlan = false,
    this.professionalOnly = false,
    this.published = true,
    this.certificateEnabled = false,
  });

  final String id;
  final String title;
  final String summary;
  final CourseLevel level;
  final DateTime updatedAt;

  final String? coverUrl;

  /// Trailer aberto, mesmo em curso pago — quem vai assinar precisa ver a
  /// qualidade antes de decidir.
  final String? trailerVideoGuid;

  final String? instructor;
  final String? instructorTitle;

  final int lessonCount;
  final int totalMinutes;
  final List<String> tags;

  /// Exige assinatura ativa.
  final bool requiresPlan;

  /// Exige registro profissional verificado.
  final bool professionalOnly;

  final bool published;

  /// Emite certificado ao concluir 100%.
  final bool certificateEnabled;

  String get durationLabel {
    if (totalMinutes < 60) return '$totalMinutes min';
    final int hours = totalMinutes ~/ 60;
    final int rest = totalMinutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
  }

  @override
  List<Object?> get props => <Object?>[id, title, updatedAt, lessonCount];
}

/// Uma aula dentro de um curso.
class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    required this.kind,
    this.description,
    this.videoGuid,
    this.audioPath,
    this.body,
    this.durationSeconds = 0,
    this.isFree = false,
    this.attachments = const <LessonAttachment>[],
  });

  final String id;
  final String courseId;
  final String title;
  final int order;
  final LessonKind kind;

  final String? description;

  /// GUID no Bunny Stream.
  final String? videoGuid;

  /// Caminho no Bunny Storage, para podcasts.
  final String? audioPath;

  /// Corpo em texto, para aulas de leitura.
  final String? body;

  final int durationSeconds;

  /// Aula de amostra: reproduz sem assinatura, mesmo em curso pago.
  final bool isFree;

  final List<LessonAttachment> attachments;

  Duration get duration => Duration(seconds: durationSeconds);

  String get durationLabel {
    final int minutes = durationSeconds ~/ 60;
    if (minutes < 1) return '${durationSeconds}s';
    return '$minutes min';
  }

  bool get hasMedia => videoGuid != null || audioPath != null;

  @override
  List<Object?> get props => <Object?>[id, courseId, order, title];
}

/// Material de apoio de uma aula.
class LessonAttachment extends Equatable {
  const LessonAttachment({
    required this.title,
    required this.path,
    this.sizeKb = 0,
  });

  factory LessonAttachment.fromMap(Map<String, dynamic> map) =>
      LessonAttachment(
        title: (map['title'] as String?) ?? '',
        path: (map['path'] as String?) ?? '',
        sizeKb: (map['sizeKb'] as num?)?.toInt() ?? 0,
      );

  final String title;

  /// Caminho no Bunny Storage.
  final String path;

  final int sizeKb;

  String get sizeLabel => sizeKb < 1024
      ? '$sizeKb KB'
      : '${(sizeKb / 1024).toStringAsFixed(1)} MB';

  @override
  List<Object?> get props => <Object?>[title, path];
}

/// Progresso do usuário em uma aula.
class LessonProgress extends Equatable {
  const LessonProgress({
    required this.lessonId,
    required this.courseId,
    required this.positionSeconds,
    required this.updatedAt,
    this.completed = false,
  });

  final String lessonId;
  final String courseId;

  /// Onde parou. Retomar de onde ficou é o que faz alguém voltar ao curso.
  final int positionSeconds;

  final DateTime updatedAt;
  final bool completed;

  Duration get position => Duration(seconds: positionSeconds);

  @override
  List<Object?> get props =>
      <Object?>[lessonId, positionSeconds, completed, updatedAt];
}

/// Progresso agregado de um curso.
class CourseProgress extends Equatable {
  const CourseProgress({
    required this.courseId,
    required this.completedLessons,
    required this.totalLessons,
    this.lastLessonId,
    this.startedAt,
    this.completedAt,
  });

  const CourseProgress.empty(this.courseId)
      : completedLessons = 0,
        totalLessons = 0,
        lastLessonId = null,
        startedAt = null,
        completedAt = null;

  final String courseId;
  final int completedLessons;
  final int totalLessons;

  /// Última aula aberta — alimenta o botão "Continuar".
  final String? lastLessonId;

  final DateTime? startedAt;
  final DateTime? completedAt;

  double get ratio =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  int get percent => (ratio * 100).round();

  bool get isStarted => completedLessons > 0 || lastLessonId != null;
  bool get isComplete => totalLessons > 0 && completedLessons >= totalLessons;

  @override
  List<Object?> get props =>
      <Object?>[courseId, completedLessons, totalLessons, lastLessonId];
}
