import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/voice_consultation.dart';

/// Faixa permanente de aviso: saida da IA e sempre rascunho.
class AiMedicalDisclaimerBanner extends StatelessWidget {
  const AiMedicalDisclaimerBanner({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.softOrange,
        border: Border(
          bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: compact ? 18 : 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              VoiceConsultationSession.aiDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
