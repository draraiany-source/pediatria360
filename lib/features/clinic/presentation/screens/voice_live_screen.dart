import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/voice_consultation.dart';
import '../providers/clinic_providers.dart';
import '../widgets/ai_medical_disclaimer_banner.dart';

/// Tela ao vivo: timer, pausa/retomada, transcricao e campos faltantes.
class VoiceLiveScreen extends ConsumerStatefulWidget {
  const VoiceLiveScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<VoiceLiveScreen> createState() => _VoiceLiveScreenState();
}

class _VoiceLiveScreenState extends ConsumerState<VoiceLiveScreen> {
  Timer? _tick;
  int _elapsed = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final int m = _elapsed ~/ 60;
    final int s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pause() async {
    setState(() => _busy = true);
    await ref
        .read(voiceConsultationRepositoryProvider)
        .pauseSession(widget.sessionId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resume() async {
    setState(() => _busy = true);
    await ref
        .read(voiceConsultationRepositoryProvider)
        .resumeSession(widget.sessionId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final result = await ref
        .read(voiceConsultationRepositoryProvider)
        .finalizeRecording(widget.sessionId);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (_) => context.push(Routes.clinicVoiceReview(widget.sessionId)),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VoiceConsultationSession?> async =
        ref.watch(voiceSessionProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Consulta ao vivo'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(compact: true),
          Expanded(
            child: async.when(
              loading: () => const LoadingState(label: 'Abrindo sessao…'),
              error: (Object e, StackTrace _) => ErrorState(
                failure: ServerFailure(e.toString()),
              ),
              data: (VoiceConsultationSession? session) {
                if (session == null) {
                  return const EmptyState(
                    title: 'Sessao nao encontrada',
                    message: 'Verifique o identificador ou inicie outra.',
                  );
                }
                final bool paused =
                    session.status == VoiceSessionStatus.paused;
                final List<String> missing =
                    session.draft?.missingFields ?? const <String>[];

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: paused
                                  ? AppColors.honey
                                  : AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            paused ? 'Pausado' : 'Gravando',
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _timerLabel,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (missing.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          children: missing
                              .map(
                                (String f) => Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.sm,
                                  ),
                                  child: Chip(
                                    label: Text(f),
                                    backgroundColor: AppColors.softOrange,
                                    side: BorderSide.none,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    Expanded(
                      child: session.segments.isEmpty
                          ? const EmptyState(
                              title: 'Aguardando fala',
                              message:
                                  'A transcricao ao vivo aparece aqui quando '
                                  'houver segmentos.',
                              icon: Icons.hearing_outlined,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: session.segments.length,
                              itemBuilder: (BuildContext context, int i) {
                                final TranscriptSegment s =
                                    session.segments[i];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: AppCard(
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          s.speaker.label,
                                          style: const TextStyle(
                                            color: AppColors.tealDeep,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(s.text),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    missing.isEmpty
                                        ? 'Pergunte sobre a evolucao desde '
                                            'a ultima consulta.'
                                        : 'Sugestao: explorar "${missing.first}".',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.lightbulb_outline),
                            label: const Text('Sugerir proxima pergunta'),
                          ),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : (paused ? _resume : _pause),
                                  child: Text(paused ? 'Retomar' : 'Pausar'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Finalizar',
                                  icon: Icons.stop_rounded,
                                  isLoading: _busy,
                                  onPressed: _busy ? null : _finish,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
