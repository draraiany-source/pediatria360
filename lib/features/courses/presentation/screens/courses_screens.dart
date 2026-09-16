import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/bunny_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/course.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/courses_providers.dart';
import '../widgets/lesson_player.dart';

// ---------------------------------------------------------------- Catálogo

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Course>> catalog =
        ref.watch(courseCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: catalog.when(
        loading: () => const SkeletonList(itemCount: 4, itemHeight: 96),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.play_circle_outline_rounded,
          title: 'Não foi possível carregar',
          message: 'Verifique sua conexão e tente novamente.',
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(courseCatalogProvider),
        ),
        data: (List<Course> courses) {
          if (courses.isEmpty) {
            return const EmptyState(
              icon: Icons.play_circle_outline_rounded,
              title: 'Nenhum curso publicado',
              message: 'Os cursos são cadastrados pelo painel administrativo '
                  'e aparecem aqui assim que forem publicados.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(courseCatalogProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: courses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) => ContentBounds(
                child: _CourseCard(course: courses[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CourseProgress progress =
        ref.watch(courseProgressSummaryProvider(course.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.course(course.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CourseCover(course: course, height: 148),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AppTag(label: course.level.label),
                      const SizedBox(width: AppSpacing.sm),
                      if (course.professionalOnly)
                        const AppTag(
                          label: 'Profissional',
                          color: AppColors.raspberry,
                          icon: Icons.medical_services_outlined,
                        )
                      else if (course.requiresPlan)
                        const AppTag(
                          label: 'Premium',
                          color: AppColors.honey,
                          icon: Icons.workspace_premium_outlined,
                        ),
                      const Spacer(),
                      Text(
                        '${course.lessonCount} aulas · '
                        '${course.durationLabel}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(course.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    course.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (progress.isStarted) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillAll,
                            child: LinearProgressIndicator(
                              value: progress.ratio,
                              minHeight: 5,
                              backgroundColor:
                                  theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          '${progress.percent}%',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCover extends ConsumerWidget {
  const _CourseCover({required this.course, required this.height});

  final Course course;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BunnyService bunny = ref.watch(bunnyServiceProvider);

    final String? url = course.coverUrl ??
        (course.trailerVideoGuid != null && bunny.isConfigured
            ? bunny.thumbnailUrl(course.trailerVideoGuid!)
            : null);

    if (url == null) {
      return Image.asset(
        AppAssets.mediaPlaceholder,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      // `height` já é conhecida — decodificar na resolução original só
      // para exibir num card de altura fixa desperdiça memória à toa,
      // principalmente numa lista com vários cursos na tela ao mesmo tempo.
      memCacheHeight: (height * 2).round(),
      placeholder: (_, __) => Skeleton(height: height, radius: BorderRadius.zero),
      errorWidget: (_, __, ___) => Image.asset(
        AppAssets.mediaPlaceholder,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ------------------------------------------------------------ Detalhe

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Course> course = ref.watch(courseProvider(courseId));
    final AsyncValue<List<Lesson>> lessons =
        ref.watch(lessonsProvider(courseId));
    final CourseProgress progress =
        ref.watch(courseProgressSummaryProvider(courseId));
    final AppUser? user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: course.when(
        loading: () => const LoadingState(),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.play_disabled_rounded,
          title: 'Curso indisponível',
          message: 'Não foi possível abrir agora.',
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(courseProvider(courseId)),
        ),
        data: (Course c) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[
            _CourseCover(course: c, height: 200),
            ContentBounds(
              maxWidth: 720,
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      AppTag(label: c.level.label),
                      AppTag(
                        label: '${c.lessonCount} aulas',
                        icon: Icons.list_alt_rounded,
                      ),
                      AppTag(
                        label: c.durationLabel,
                        icon: Icons.schedule_rounded,
                      ),
                      if (c.certificateEnabled)
                        const AppTag(
                          label: 'Com certificado',
                          color: AppColors.success,
                          icon: Icons.workspace_premium_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(c.title, style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    c.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (c.instructor != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.avatarFor(c.instructor!),
                          child: Text(
                            c.instructor!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              c.instructor!,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (c.instructorTitle != null)
                              Text(
                                c.instructorTitle!,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  if (progress.isStarted) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    progress.isComplete
                                        ? 'Curso concluído'
                                        : 'Seu progresso',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  '${progress.completedLessons} de '
                                  '${progress.totalLessons}',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: AppRadius.pillAll,
                              child: LinearProgressIndicator(
                                value: progress.ratio,
                                minHeight: 6,
                                color: progress.isComplete
                                    ? AppColors.success
                                    : null,
                                backgroundColor:
                                    theme.colorScheme.outlineVariant,
                              ),
                            ),
                            if (progress.lastLessonId != null &&
                                !progress.isComplete) ...<Widget>[
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                label: 'Continuar de onde parei',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () => context.push(
                                  Routes.lesson(
                                    courseId,
                                    progress.lastLessonId!,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SectionHeader(title: 'Aulas', eyebrow: 'Conteúdo'),
                  lessons.when(
                    loading: () => const SkeletonList(itemCount: 4, itemHeight: 56),
                    error: (Object e, StackTrace s) => const Text(
                      'Não foi possível carregar as aulas.',
                    ),
                    data: (List<Lesson> list) => list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Text(
                              'Nenhuma aula publicada ainda.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : Column(
                      children: <Widget>[
                        for (int i = 0; i < list.length; i++)
                          _LessonTile(
                            lesson: list[i],
                            index: i + 1,
                            lock: lockFor(
                              course: c,
                              lesson: list[i],
                              user: user,
                            ),
                            completed: ref
                                    .watch(courseProgressProvider(courseId))
                                    .valueOrNull
                                    ?.any(
                                      (LessonProgress p) =>
                                          p.lessonId == list[i].id &&
                                          p.completed,
                                    ) ??
                                false,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.index,
    required this.lock,
    required this.completed,
  });

  final Lesson lesson;
  final int index;
  final LessonLock lock;
  final bool completed;

  IconData get _icon => switch (lesson.kind) {
        LessonKind.video => Icons.play_circle_outline_rounded,
        LessonKind.audio => Icons.headphones_outlined,
        LessonKind.text => Icons.article_outlined,
        LessonKind.quiz => Icons.quiz_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool locked = lock != LessonLock.none;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          onTap: locked
              ? () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(lock.message)))
              : () => context.push(
                    Routes.lesson(lesson.courseId, lesson.id),
                  ),
          leading: CircleAvatar(
            backgroundColor: completed
                ? AppColors.success.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            child: completed
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 20,
                  )
                : Text('$index', style: theme.textTheme.labelMedium),
          ),
          title: Text(
            lesson.title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: <Widget>[
              Icon(_icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${lesson.kind.label} · ${lesson.durationLabel}',
                style: theme.textTheme.bodySmall,
              ),
              if (lesson.isFree) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const AppTag(label: 'Amostra', color: AppColors.success),
              ],
            ],
          ),
          trailing: Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            size: 20,
            color: locked ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Aula

class LessonScreen extends ConsumerWidget {
  const LessonScreen({
    required this.courseId,
    required this.lessonId,
    super.key,
  });

  final String courseId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Course> course = ref.watch(courseProvider(courseId));
    final AsyncValue<List<Lesson>> lessons =
        ref.watch(lessonsProvider(courseId));
    final AppUser? user = ref.watch(currentUserProvider);

    final Course? c = course.valueOrNull;
    final List<Lesson> list = lessons.valueOrNull ?? const <Lesson>[];

    Lesson? lesson;
    for (final Lesson l in list) {
      if (l.id == lessonId) lesson = l;
    }

    if (c == null || lesson == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
          ),
        ),
        body: course.isLoading || lessons.isLoading
            ? const LoadingState()
            : const EmptyState(
                icon: Icons.play_disabled_rounded,
                title: 'Aula não encontrada',
                message: 'Ela pode ter sido removida do curso.',
              ),
      );
    }

    final LessonLock lock =
        lockFor(course: c, lesson: lesson, user: user);

    if (lock != LessonLock.none) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
          ),
        ),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: lock == LessonLock.requiresPlan
              ? 'Aula do plano Premium'
              : 'Conteúdo profissional',
          message: lock.message,
          actionLabel: lock == LessonLock.requiresPlan ? 'Ver planos' : null,
          onAction: lock == LessonLock.requiresPlan
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Assinaturas chegam no próximo módulo.'),
                    ),
                  )
              : null,
        ),
      );
    }

    // Retoma de onde parou.
    final List<LessonProgress> progress =
        ref.watch(courseProgressProvider(courseId)).valueOrNull ??
            const <LessonProgress>[];

    Duration startAt = Duration.zero;
    for (final LessonProgress p in progress) {
      if (p.lessonId == lessonId && !p.completed) {
        startAt = p.position;
      }
    }

    final int currentIndex = list.indexOf(lesson);
    final Lesson? next =
        currentIndex >= 0 && currentIndex + 1 < list.length
            ? list[currentIndex + 1]
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.title,
          style: theme.textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          if (lesson.kind == LessonKind.video)
            LessonPlayer(lesson: lesson, course: c, startAt: startAt),
          ContentBounds(
            maxWidth: 720,
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(lesson.title, style: theme.textTheme.headlineSmall),
                if (lesson.description != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    lesson.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
                if (lesson.body != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    lesson.body!,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                  ),
                ],
                if (lesson.attachments.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: 'Material de apoio'),
                  for (final LessonAttachment file in lesson.attachments)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(file.title),
                        subtitle: Text(file.sizeLabel),
                        trailing: const Icon(Icons.download_rounded),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download inicia no navegador.'),
                          ),
                        ),
                      ),
                    ),
                ],
                if (next != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Próxima aula: ${next.title}',
                    icon: Icons.skip_next_rounded,
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.pushReplacement(
                      Routes.lesson(courseId, next.id),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
