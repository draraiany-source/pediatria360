import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/workspace_profile.dart';
import '../providers/workspace_providers.dart';

/// Seletor apenas entre perfis JA concedidos a conta.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<WorkspaceProfile> granted = ref.watch(grantedWorkspacesProvider);
    final WorkspaceProfile current = ref.watch(currentWorkspaceProvider);
    if (granted.length <= 1) {
      return _Chip(label: current.label, onTap: null);
    }

    return PopupMenuButton<WorkspaceProfile>(
      initialValue: current,
      onSelected: (WorkspaceProfile p) {
        ref.read(activeWorkspaceProvider.notifier).select(p);
      },
      itemBuilder: (BuildContext context) => granted
          .map(
            (WorkspaceProfile p) => PopupMenuItem<WorkspaceProfile>(
              value: p,
              child: Text(p.label),
            ),
          )
          .toList(growable: false),
      child: _Chip(label: current.label, onTap: () {}),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softBlue,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: AppColors.navy,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.expand_more, size: 18, color: AppColors.navy),
              ],
            ],
          ),
        ),
      ),
    );
  }
}