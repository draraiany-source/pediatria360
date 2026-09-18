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

/// Revisao do rascunho estruturado — aceitar / editar / ignorar sugestoes.
class VoiceReviewScreen extends ConsumerStatefulWidget {
  const VoiceReviewScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<VoiceReviewScreen> createState() => _VoiceReviewScreenState();
}

class _VoiceReviewScreenState extends ConsumerState<VoiceReviewScreen> {
  String _template = 'SOAP';
  bool _structuring = false;
  final Set<String> _ignored = <String>{};

  Future<void> _structure() async {
    setState(() => _structuring = true);
    final result = await ref
        .read(voiceConsultationRepositoryProvider)
        .structureDraft(widget.sessionId, evolutionTemplate: _template);
    if (!mounted) return;
    setState(() => _structuring = false);
    result.fold(
      (_) => ref.invalidate(voiceSessionProvider(widget.sessionId)),
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
        title: const Text('Revisar rascunho'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(compact: true),
          Expanded(
            child: async.when(
              loading: () => const LoadingState(label: 'Carregando…'),
              error: (Object e, StackTrace _) => ErrorState(
                failure: ServerFailure(e.toString()),
              ),
              data: (VoiceConsultationSession? session) {
                final VoiceStructuredDraft? draft = session?.draft;
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    Text(
                      'Modelo de evolucao',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: <String>['SOAP', 'DAP', 'Livre']
                          .map(
                            (String t) => ChoiceChip(
                              label: Text(t),
                              selected: _template == t,
                              onSelected: (_) => setState(() => _template = t),
                              selectedColor: AppColors.softBlue,
                              labelStyle: TextStyle(
                                color: _template == t
                                    ? AppColors.brand
                                    : AppColors.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Estruturar rascunho ($_template)',
                      icon: Icons.auto_awesome,
                      isLoading: _structuring,
                      onPressed: _structuring ? null : _structure,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (draft == null)
                      const EmptyState(
                        title: 'Sem rascunho ainda',
                        message:
                            'Finalize a gravacao e estruture o texto com a IA.',
                        icon: Icons.description_outlined,
                      )
                    else ...<Widget>[
                      _field(
                        context,
                        keyName: 'chiefComplaint',
                        title: 'Queixa principal',
                        value: draft.chiefComplaint,
                      ),
                      _field(
                        context,
                        keyName: 'hpi',
                        title: 'Historia da doenca atual',
                        value: draft.historyOfPresentIllness,
                      ),
                      _field(
                        context,
                        keyName: 'assessment',
                        title: 'Avaliacao',
                        value: draft.assessment,
                      ),
                      _field(
                        context,
                        keyName: 'plan',
                        title: 'Plano',
                        value: draft.plan,
                      ),
                      _field(
                        context,
                        keyName: 'evolution',
                        title: 'Evolucao ($_template)',
                        value: draft.evolutionText,
                      ),
                      if (draft.hypotheses.isNotEmpty)
                        _field(
                          context,
                          keyName: 'hypotheses',
                          title: 'Hipotese(s)',
                          value: draft.hypotheses.join('; '),
                        ),
                      if (draft.suggestedCids.isNotEmpty)
                        _field(
                          context,
                          keyName: 'cids',
                          title: 'CIDs sugeridos',
                          value: draft.suggestedCids.join(', '),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Ir para confirmacao final',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => context.push(
                          Routes.clinicVoiceFinal(widget.sessionId),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String keyName,
    required String title,
    required String value,
  }) {
    if (_ignored.contains(keyName)) {
      return const SizedBox.shrink();
    }
    final String display =
        value.trim().isEmpty ? 'Nao informado' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(display),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sugestao aceita para o rascunho.'),
                      ),
                    );
                  },
                  child: const Text('Aceitar'),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Edite no prontuario apos confirmar o rascunho.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Editar depois'),
                ),
                TextButton(
                  onPressed: () => setState(() => _ignored.add(keyName)),
                  child: const Text('Ignorar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
