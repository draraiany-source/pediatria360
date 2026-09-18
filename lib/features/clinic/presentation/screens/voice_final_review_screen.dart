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

/// Confirmacao final: aplica rascunho no prontuario — NUNCA assina.
class VoiceFinalReviewScreen extends ConsumerStatefulWidget {
  const VoiceFinalReviewScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<VoiceFinalReviewScreen> createState() =>
      _VoiceFinalReviewScreenState();
}

class _VoiceFinalReviewScreenState
    extends ConsumerState<VoiceFinalReviewScreen> {
  bool _busy = false;
  String? _appliedEncounterId;

  Future<void> _apply() async {
    setState(() => _busy = true);
    final result = await ref
        .read(voiceConsultationRepositoryProvider)
        .applyDraftToEncounter(widget.sessionId);
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (String? encounterId) {
        setState(() => _appliedEncounterId = encounterId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rascunho confirmado no prontuario. Assinatura permanece manual.',
            ),
          ),
        );
      },
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  Future<void> _discard() async {
    setState(() => _busy = true);
    await ref
        .read(voiceConsultationRepositoryProvider)
        .discardSession(widget.sessionId);
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(Routes.clinicPath);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VoiceConsultationSession?> async =
        ref.watch(voiceSessionProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Confirmacao final'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(),
          Expanded(
            child: async.when(
              loading: () => const LoadingState(label: 'Carregando…'),
              error: (Object e, StackTrace _) => ErrorState(
                failure: ServerFailure(e.toString()),
              ),
              data: (VoiceConsultationSession? session) {
                final VoiceStructuredDraft? draft = session?.draft;
                final String? encounterId =
                    _appliedEncounterId ?? session?.encounterId;

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    AppCard(
                      color: AppColors.softOrange,
                      child: Text(
                        'Esta acao grava campos clinicos como RASCUNHO. '
                        'Nao assina o atendimento. Voce deve revisar e '
                        'assinar no editor de prontuario.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (draft != null) ...<Widget>[
                      Text(
                        'Resumo do rascunho',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        draft.chiefComplaint.isEmpty
                            ? 'Queixa: Nao informado'
                            : 'Queixa: ${draft.chiefComplaint}',
                      ),
                      Text(
                        draft.assessment.isEmpty
                            ? 'Avaliacao: Nao informado'
                            : 'Avaliacao: ${draft.assessment}',
                      ),
                      Text(
                        draft.plan.isEmpty
                            ? 'Plano: Nao informado'
                            : 'Plano: ${draft.plan}',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Confirmar rascunho no prontuario',
                      icon: Icons.check_circle_outline,
                      isLoading: _busy,
                      onPressed: _busy ? null : _apply,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => context.push(
                                Routes.clinicVoiceReview(widget.sessionId),
                              ),
                      child: const Text('Voltar e editar sugestoes'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy ? null : _discard,
                      child: const Text('Descartar sessao'),
                    ),
                    if (encounterId != null && encounterId.isNotEmpty) ...<
                        Widget>[
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Abrir prontuario (rascunho)',
                        icon: Icons.folder_open_rounded,
                        onPressed: () => context.go(Routes.patientsPath),
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
}
