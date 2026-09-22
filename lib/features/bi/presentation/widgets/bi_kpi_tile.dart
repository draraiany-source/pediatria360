import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/bi_models.dart';

class BiKpiTile extends StatelessWidget {
  const BiKpiTile({super.key, required this.data});

  final BiKpiCardData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool tappable = data.drillRoute != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: tappable ? () => _drill(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                data.valueLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (tappable) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ver detalhes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _drill(BuildContext context) {
    final String? route = data.drillRoute;
    if (route == null) return;
    final Map<String, String> q = data.drillQuery ?? const <String, String>{};
    if (q.isEmpty) {
      context.push(route);
      return;
    }
    final Uri uri = Uri(path: route, queryParameters: q);
    context.push(uri.toString());
  }
}
