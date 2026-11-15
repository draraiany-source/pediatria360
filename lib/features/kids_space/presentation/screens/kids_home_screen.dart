import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../audio/kids_audio_controller.dart';
import '../../domain/kids_catalog.dart';
import '../providers/kids_providers.dart';

/// Home infantil do Espaco Kids — identidade propria, sem dados clinicos.
class KidsHomeScreen extends ConsumerWidget {
  const KidsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool enabled = ref.watch(kidsSpaceEnabledProvider);
    final asyncProgress = ref.watch(kidsProgressProvider);
    final KidsAudioState audio = ref.watch(kidsAudioProvider);
    final KidsAccessibilityPrefs a11y = ref.watch(kidsAccessibilityProvider);

    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espaco Kids')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Espaco Kids desativado neste ambiente '
              '(flag kids_space_enabled / KIDS_SPACE_ENABLED).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF6F2FD),
              Color(0xFFFFF7DD),
              Color(0xFFEAF2FF),
            ],
          ),
        ),
        child: SafeArea(
          child: asyncProgress.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace s) => Center(child: Text('Erro: $e')),
            data: (profile) {
              final band = profile?.ageBand ?? KidsAgeBand.preschool;
              final games = KidsGameInfo.forBand(band);
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => context.go(Routes.homePath),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Voltar para a familia'),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Icon(
                            audio.muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 4),
                          Text(audio.muted ? 'Som desligado' : 'Som ligado'),
                          Switch(
                            value: !audio.muted,
                            onChanged: (bool on) => ref
                                .read(kidsAudioProvider.notifier)
                                .setMuted(!on),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => context.go(Routes.kidsGuardianPath),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Area dos responsaveis'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Espaco Kids da Tia Cris',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vamos aprender brincando?',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 16),
                  ),
                  if (audio.lastCaption.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      audio.lastCaption,
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int cols = c.maxWidth > 900
                          ? 3
                          : (c.maxWidth > 560 ? 2 : 1);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                        children: <Widget>[
                          for (final KidsGameInfo g in games)
                            _GameCard(
                              info: g,
                              guided: g.id == KidsGameId.hygieneFood,
                              onPlay: () async {
                                await ref
                                    .read(kidsAudioProvider.notifier)
                                    .playCue(g.caption);
                                if (context.mounted) {
                                  context.go(Routes.kidsPlay(g.id.name));
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(Icons.tune_rounded, color: AppColors.brand),
                              SizedBox(width: 8),
                              Text(
                                'Do seu jeito',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              FilterChip(
                                label: const Text('Sem cronometro'),
                                selected: a11y.noTimer,
                                onSelected: (bool v) => ref
                                    .read(kidsAccessibilityProvider.notifier)
                                    .state = a11y.copyWith(noTimer: v),
                              ),
                              FilterChip(
                                label: const Text('Movimento reduzido'),
                                selected: a11y.reducedMotion,
                                onSelected: (bool v) => ref
                                    .read(kidsAccessibilityProvider.notifier)
                                    .state = a11y.copyWith(reducedMotion: v),
                              ),
                              FilterChip(
                                label: const Text('Pausar a qualquer momento'),
                                selected: a11y.pauseAnytime,
                                onSelected: (bool v) => ref
                                    .read(kidsAccessibilityProvider.notifier)
                                    .state = a11y.copyWith(pauseAnytime: v),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text('Ajuda por voz'),
                                  Switch(
                                    value: a11y.voiceHelp,
                                    onChanged: (bool v) {
                                      ref
                                          .read(
                                            kidsAccessibilityProvider.notifier,
                                          )
                                          .state = a11y.copyWith(voiceHelp: v);
                                      if (v) {
                                        ref
                                            .read(kidsAudioProvider.notifier)
                                            .playCue(
                                              'Ajuda por voz ligada',
                                            );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Material(
                    color: AppColors.softYellow,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Uma pausa tambem faz parte da brincadeira',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () =>
                                context.go(Routes.kidsGuardianPath),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Configurar pausa'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Brincadeiras recreativas · Sem anuncios · Sem dados clinicos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.info,
    required this.onPlay,
    this.guided = false,
  });

  final KidsGameInfo info;
  final VoidCallback onPlay;
  final bool guided;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  String _level = 'Facil';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.guided)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.honeySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Brincadeira guiada',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            Text(
              widget.info.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.info.subtitle,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
            const Spacer(),
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(
                labelText: 'Nivel',
                isDense: true,
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'Facil', child: Text('Facil')),
                DropdownMenuItem<String>(
                  value: 'Medio',
                  child: Text('Medio'),
                ),
                DropdownMenuItem<String>(
                  value: 'Desafio',
                  child: Text('Desafio'),
                ),
              ],
              onChanged: (String? v) {
                if (v != null) setState(() => _level = v);
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: widget.onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Jogar'),
            ),
          ],
        ),
      ),
    );
  }
}
