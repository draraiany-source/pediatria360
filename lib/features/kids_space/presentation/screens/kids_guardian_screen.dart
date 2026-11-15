import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../audio/kids_audio_controller.dart';
import '../../domain/kids_catalog.dart';
import '../../domain/kids_progress.dart';
import '../providers/kids_providers.dart';

/// Area protegida do responsavel: avatar, faixa etaria, mute e limite de tempo.
class KidsGuardianScreen extends ConsumerStatefulWidget {
  const KidsGuardianScreen({super.key});

  @override
  ConsumerState<KidsGuardianScreen> createState() => _KidsGuardianScreenState();
}

class _KidsGuardianScreenState extends ConsumerState<KidsGuardianScreen> {
  KidsProgressProfile? _draft;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kidsProgressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsavel — Espaco Kids'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.kidsPath),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => Center(child: Text('$e')),
        data: (KidsProgressProfile? profile) {
          final KidsProgressProfile draft = _draft ??
              profile ??
              KidsProgressProfile.empty('local');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Esta area nao exibe prontuario, receitas nem financeiro. '
                'So preferencias do Espaco Kids.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const Text('Avatar / mascote',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final KidsAvatar a in KidsAvatar.options)
                    ChoiceChip(
                      label: Text('${a.emoji} ${a.label}'),
                      selected: draft.avatarId == a.id,
                      onSelected: (_) => setState(
                        () => _draft = draft.copyWith(avatarId: a.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Faixa etaria do conteudo',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final KidsAgeBand b in KidsAgeBand.values)
                    ChoiceChip(
                      label: Text(switch (b) {
                        KidsAgeBand.toddler => 'Bebe/toddler',
                        KidsAgeBand.preschool => 'Pre-escolar',
                        KidsAgeBand.school => 'Escolar',
                      }),
                      selected: draft.ageBand == b,
                      onSelected: (_) =>
                          setState(() => _draft = draft.copyWith(ageBand: b)),
                    ),
                ],
              ),
              SwitchListTile(
                title: const Text('Sem audio'),
                value: draft.muted,
                onChanged: (bool v) {
                  setState(() => _draft = draft.copyWith(muted: v));
                  ref.read(kidsAudioProvider.notifier).setMuted(v);
                },
              ),
              ListTile(
                title: const Text('Limite diario (minutos)'),
                subtitle: Text('${draft.dailyMinutesLimit} min'),
              ),
              Slider(
                min: 5,
                max: 60,
                divisions: 11,
                value: draft.dailyMinutesLimit.toDouble().clamp(5, 60),
                onChanged: (double v) => setState(
                  () => _draft =
                      draft.copyWith(dailyMinutesLimit: v.round()),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final KidsProgressProfile base =
                      profile ?? KidsProgressProfile.empty(draft.ownerUid);
                  final KidsProgressProfile next = base.copyWith(
                    avatarId: draft.avatarId,
                    ageBand: draft.ageBand,
                    muted: draft.muted,
                    dailyMinutesLimit: draft.dailyMinutesLimit,
                    updatedAt: DateTime.now().toUtc(),
                  );
                  await ref.read(kidsProgressRepositoryProvider).save(next);
                  ref.invalidate(kidsProgressProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferencias salvas')),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
