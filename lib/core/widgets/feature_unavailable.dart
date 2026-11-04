import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'state_views.dart';

/// Tela amigavel para recursos fora do escopo do teste fechado / publicacao.
class FeatureUnavailableScreen extends StatelessWidget {
  const FeatureUnavailableScreen({
    required this.title,
    required this.message,
    this.backLabel = 'Voltar',
    super.key,
  });

  final String title;
  final String message;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: EmptyState(
        title: title,
        message: message,
        icon: Icons.construction_outlined,
        actionLabel: backLabel,
        onAction: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.homePath);
          }
        },
      ),
    );
  }
}

/// Banner fino para avisar que um modulo esta desligado nesta versao.
class FeatureOffBanner extends StatelessWidget {
  const FeatureOffBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.softOrange.withValues(alpha: 0.55),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: AppColors.navy),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}