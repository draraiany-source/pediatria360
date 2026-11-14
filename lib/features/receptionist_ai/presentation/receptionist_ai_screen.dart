import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/router/route_access.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_ui.dart';
import '../../../core/widgets/state_views.dart';

/// Arquivos da personagem. Nulo enquanto a ilustração oficial não for
/// entregue: a área mostra um espaço reservado do mesmo tamanho.
class TiaCrisAssets {
  const TiaCrisAssets._();

  static const String? portrait = null;
}

/// Aba exclusiva da Tia Cris, recepcionista IA.
///
/// O atendimento automático ainda não existe no servidor: a tela mostra o
/// escopo e os limites combinados, sem simular conversa nem agendamento.
class ReceptionistAiScreen extends ConsumerWidget {
  const ReceptionistAiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool canOpenAgenda = canOpenRoute(ref, Routes.agendaPath);
    final bool canOpenReception = canOpenRoute(ref, Routes.clinicReceptionPath);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentBounds(
        maxWidth: 1040,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const TiaCrisPortrait(size: 112),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tia Cris — Recepcionista IA',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Apoio à recepção: dúvidas administrativas, '
                        'orientação sobre agendamento e encaminhamento para '
                        'a equipe humana.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const DataWarningBanner(
              text: 'Atendimento automático ainda não ativado neste ambiente. '
                  'A Tia Cris não responde pacientes nem marca consultas por '
                  'enquanto.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ScopeCard(
              title: 'O que ela vai fazer',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              items: <String>[
                'Informar horários, serviços e valores cadastrados pela clínica.',
                'Oferecer horários livres consultando a agenda real.',
                'Encaminhar para a recepção humana quando não souber responder.',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _ScopeCard(
              title: 'O que ela nunca faz',
              icon: Icons.block_rounded,
              color: AppColors.danger,
              items: <String>[
                'Diagnosticar, prescrever ou interpretar exames.',
                'Inventar horários, preços, profissionais ou serviços.',
                'Acessar prontuário: as permissões dela são as da recepção, '
                    'separadas do assistente clínico.',
              ],
            ),
            if (canOpenAgenda || canOpenReception) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  if (canOpenAgenda)
                    OutlinedButton.icon(
                      onPressed: () => context.go(Routes.agendaPath),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Abrir agenda'),
                    ),
                  if (canOpenReception)
                    OutlinedButton.icon(
                      onPressed: () => context.go(Routes.clinicReceptionPath),
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Abrir recepção'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Retrato da Tia Cris em área de tamanho fixo (nunca cobre o conteúdo).
class TiaCrisPortrait extends StatelessWidget {
  const TiaCrisPortrait({this.size = 96, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    const String? asset = TiaCrisAssets.portrait;
    return Semantics(
      label: asset == null
          ? 'Ilustração da Tia Cris ainda não disponível'
          : 'Tia Cris',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.softPink,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: AppColors.raspberrySoft),
          ),
          child: asset == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.support_agent_rounded,
                      size: size * 0.4,
                      color: AppColors.navSelected,
                    ),
                    Text(
                      'Ilustração\npendente',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: AppRadius.xlAll,
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('•  ', style: TextStyle(color: color)),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
