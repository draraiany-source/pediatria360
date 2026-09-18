import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';

/// Visao 360 do paciente — atalhos para rotas existentes.
class Patient360Screen extends ConsumerWidget {
  const Patient360Screen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Paciente 360'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            color: Colors.white,
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.softTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    color: AppColors.tealDeep,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Visao integral',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ID: $childId',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const BrandSectionHeader(title: 'Acompanhar'),
          QuickAccessCard(
            label: 'Prontuario / pacientes',
            subtitle: 'Linha do tempo e atendimentos',
            icon: Icons.folder_shared_outlined,
            color: AppColors.brand,
            wide: true,
            onTap: () => context.go(Routes.patientsPath),
          ),
          const SizedBox(height: AppSpacing.sm),
          QuickAccessCard(
            label: 'Crescimento',
            subtitle: 'Peso, altura e curvas',
            icon: Icons.show_chart_rounded,
            color: AppColors.teal,
            wide: true,
            onTap: () => context.push(Routes.growth(childId)),
          ),
          const SizedBox(height: AppSpacing.sm),
          QuickAccessCard(
            label: 'Vacinas',
            subtitle: 'Calendario e doses',
            icon: Icons.vaccines_outlined,
            color: AppColors.raspberry,
            wide: true,
            onTap: () => context.push(Routes.vaccines(childId)),
          ),
          const SizedBox(height: AppSpacing.sm),
          QuickAccessCard(
            label: 'Consulta com IA',
            subtitle: 'Iniciar gravacao assistida',
            icon: Icons.mic_rounded,
            color: AppColors.navy,
            wide: true,
            onTap: () => context.push(
              '${Routes.clinicVoicePath}?childId=$childId',
            ),
          ),
        ],
      ),
    );
  }
}
