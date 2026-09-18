import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../widgets/ai_medical_disclaimer_banner.dart';

/// Entrada do fluxo de consulta por voz / IA.
class VoiceHomeScreen extends ConsumerWidget {
  const VoiceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? childId =
        GoRouterState.of(context).uri.queryParameters['childId'];
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Consulta com IA'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                Text(
                  'Prontuario assistido por voz',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Grave a consulta, revise o rascunho gerado e so entao '
                  'confirme no prontuario. Nada e assinado automaticamente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      PrimaryButton(
                        label: 'Iniciar nova sessao',
                        icon: Icons.mic_rounded,
                        onPressed: () {
                          final String path = childId == null
                              ? Routes.clinicVoiceConsentPath
                              : '${Routes.clinicVoiceConsentPath}'
                                  '?childId=$childId';
                          context.push(path);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Para continuar, abra a sessao pelo ID '
                                'recebido apos o consentimento.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Continuar sessao existente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
