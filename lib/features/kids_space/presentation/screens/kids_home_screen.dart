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
              Color(0xFFFFF3D6),
              Color(0xFFE8F6FF),
              Color(0xFFF3E8FF),
            ],
          ),
        ),
        child: SafeArea(
          child: asyncProgress.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace s) => Center(child: Text('Erro: $e')),
            data: (profile) {
              final band = profile?.ageBand ?? KidsAgeBand.preschool;
              final avatar = KidsAvatar.options.firstWhere(
                (KidsAvatar a) => a.id == (profile?.avatarId ?? 'capi'),
                orElse: () => KidsAvatar.options.first,
              );
              final games = KidsGameInfo.forBand(band);
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.go(Routes.homePath),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Espaco Kids 360',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: audio.muted ? 'Ativar som' : 'Sem audio',
                        onPressed: () => ref
                            .read(kidsAudioProvider.notifier)
                            .setMuted(!audio.muted),
                        icon: Icon(
                          audio.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Area do responsavel',
                        onPressed: () => context.go(Routes.kidsGuardianPath),
                        icon: const Icon(Icons.family_restroom_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6D35C8), Color(0xFFD02F7A)],
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x336D35C8),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(avatar.emoji, style: const TextStyle(fontSize: 56)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Ola, ${avatar.label}!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${profile?.totalStars ?? 0} estrelas · '
                                'sem anuncios e sem dados clinicos',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (audio.lastCaption.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      audio.lastCaption,
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Escolha um jogo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                        childAspectRatio: 1.35,
                        children: <Widget>[
                          for (final KidsGameInfo g in games)
                            _GameCard(
                              info: g,
                              onTap: () async {
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.info, required this.onTap});
  final KidsGameInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                info.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                info.subtitle,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const Spacer(),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.brand, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
