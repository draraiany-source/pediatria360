import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/ai/ai_policy.dart';

/// Etiqueta única de texto produzido por assistente, até a revisão humana.
class DemoAiLabel extends StatelessWidget {
  const DemoAiLabel({
    super.key,
    this.source = AiSource.regras,
    this.detail = true,
  });

  final AiSource source;

  /// Mostra a explicação da revisão abaixo da etiqueta.
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.honey.withValues(alpha: 0.18),
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: AppColors.honey),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: AppColors.navy,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  AiPolicy.badge(source),
                  style: t.labelMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (detail)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AiPolicy.reviewDetail,
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }
}
