import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/services/bunny_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/course.dart';
import '../providers/courses_providers.dart';

/// Player de aula.
///
/// Três comportamentos que fazem diferença real no uso:
///
/// - **Retoma de onde parou.** A posição é gravada a cada 10 s e restaurada na
///   abertura. Quem assiste uma aula de 40 min em três sessões não perde tempo
///   procurando o ponto.
/// - **Marca como concluída aos 92%.** Créditos finais e despedida fazem quase
///   ninguém chegar aos 100% — exigir isso deixaria cursos eternamente
///   "quase completos".
/// - **Grava em intervalo, não continuamente.** Escrever no Firestore a cada
///   frame queimaria a cota sem ganho nenhum.
class LessonPlayer extends ConsumerStatefulWidget {
  const LessonPlayer({
    required this.lesson,
    required this.course,
    this.startAt = Duration.zero,
    super.key,
  });

  final Lesson lesson;
  final Course course;
  final Duration startAt;

  @override
  ConsumerState<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<LessonPlayer> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Timer? _saveTimer;

  bool _initializing = true;
  String? _error;
  bool _markedComplete = false;

  static const Duration _saveInterval = Duration(seconds: 10);
  static const double _completionRatio = 0.92;

  @override
  void initState() {
    super.initState();
    unawaited(_setup());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Grava a última posição ao sair — sem isso, fechar a tela perderia até
    // 10 segundos de progresso.
    _persist();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final String? guid = widget.lesson.videoGuid;
    if (guid == null || guid.isEmpty) {
      setState(() {
        _initializing = false;
        _error = 'Esta aula não tem vídeo.';
      });
      return;
    }

    final BunnyService bunny = ref.read(bunnyServiceProvider);

    if (!bunny.isConfigured) {
      setState(() {
        _initializing = false;
        _error = 'O streaming não está configurado neste ambiente. '
            'Informe BUNNY_CDN_HOSTNAME e BUNNY_STREAM_LIBRARY_ID.';
      });
      return;
    }

    try {
      // Curso pago usa URL assinada com expiração; conteúdo aberto dispensa a
      // ida ao servidor.
      final String url = widget.course.requiresPlan && !widget.lesson.isFree
          ? (await bunny.signedPlaybackUrl(videoGuid: guid)).valueOrNull ??
              bunny.hlsUrl(guid)
          : bunny.hlsUrl(guid);

      final VideoPlayerController video =
          VideoPlayerController.networkUrl(Uri.parse(url));

      await video.initialize();

      if (widget.startAt > Duration.zero &&
          widget.startAt < video.value.duration) {
        await video.seekTo(widget.startAt);
      }

      final ChewieController chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: false,
        looping: false,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const <double>[0.75, 1, 1.25, 1.5, 2],
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.petrol,
          handleColor: AppColors.petrol,
          bufferedColor: AppColors.petrolSoft.withValues(alpha: 0.4),
          backgroundColor: Colors.white24,
        ),
        placeholder: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Image.network(
              bunny.thumbnailUrl(guid),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        errorBuilder: (BuildContext context, String message) => _PlayerError(
          message: 'Não foi possível reproduzir esta aula.',
          onRetry: _setup,
        ),
      );

      if (!mounted) {
        video.dispose();
        chewie.dispose();
        return;
      }

      setState(() {
        _video = video;
        _chewie = chewie;
        _initializing = false;
      });

      _saveTimer = Timer.periodic(_saveInterval, (_) => _persist());
    } catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = ErrorMapper.map(error, stack).message;
      });
    }
  }

  void _persist() {
    final VideoPlayerController? video = _video;
    if (video == null || !video.value.isInitialized) return;

    final Duration position = video.value.position;
    final Duration total = video.value.duration;
    if (total == Duration.zero) return;

    final bool completed = _markedComplete ||
        position.inMilliseconds / total.inMilliseconds >= _completionRatio;

    if (completed) _markedComplete = true;

    unawaited(
      ref.read(playbackControllerProvider.notifier).save(
            courseId: widget.course.id,
            lessonId: widget.lesson.id,
            positionSeconds: position.inSeconds,
            completed: completed,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: LoadingState(),
        ),
      );
    }

    if (_error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _PlayerError(message: _error!, onRetry: _setup),
      );
    }

    final ChewieController? chewie = _chewie;
    if (chewie == null) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: _video?.value.aspectRatio ?? 16 / 9,
      child: Chewie(controller: chewie),
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar de novo'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
