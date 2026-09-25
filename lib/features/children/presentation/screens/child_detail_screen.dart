import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/visit_summary.dart';
import '../../../growth/domain/who_reference.dart';
import '../providers/children_providers.dart';
import 'child_guardians_screen.dart';
import 'visit_summaries_screen.dart';

class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Child?> childAsync = ref.watch(childProvider(childId));
    final VaccineSummary vaccines = ref.watch(vaccineSummaryProvider(childId));
    final List<GrowthAssessment> assessments =
        ref.watch(latestAssessmentsProvider(childId));
    final List<VisitSummary> visitSummaries =
        ref.watch(releasedVisitSummariesProvider(childId)).valueOrNull ??
            const <VisitSummary>[];

    final Child? child = childAsync.valueOrNull;

    final bool isDark = theme.brightness == Brightness.dark;
    final Color scaffoldBg = isDark
        ? AppColors.darkBackground
        : theme.colorScheme.surfaceContainerLow;
    final Color ink = isDark ? AppColors.darkInk : theme.colorScheme.onSurface;
    final Color inkMuted =
        isDark ? AppColors.darkInkMuted : theme.colorScheme.onSurfaceVariant;

    if (child == null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: scaffoldBg,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? AppColors.violetSoft : null,
            ),
            tooltip: 'Voltar',
          ),
        ),
        body: childAsync.isLoading
            ? const LoadingState()
            : const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Criança não encontrada',
                message: 'O cadastro pode ter sido removido em outro aparelho.',
              ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 168,
            backgroundColor: scaffoldBg,
            foregroundColor: ink,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? AppColors.violetSoft : null,
              ),
              tooltip: 'Voltar',
            ),
            actions: <Widget>[
              IconButton(
                onPressed: () => context.pushNamed(
                  Routes.childFormName,
                  queryParameters: <String, String>{'id': child.id},
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDark ? AppColors.violetSoft : null,
                ),
                tooltip: 'Editar',
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, ref, child),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: isDark ? AppColors.violetSoft : null,
                ),
                tooltip: 'Excluir',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.lg,
                bottom: AppSpacing.md,
              ),
              title: Text(
                child.firstName,
                style: theme.textTheme.titleLarge?.copyWith(color: ink),
              ),
              background: Padding(
                // top: 72 — não é a escala de espaçamento, é a folga
                // necessária para o conteúdo não ficar sob a barra
                // colapsada do SliverAppBar (toolbar + respiro visual).
                // Mudar exige conferir sobreposição com o título.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  72,
                  AppSpacing.lg,
                  48,
                ),
                child: Row(
                  children: <Widget>[
                    if (child.photoUrl != null)
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(child.photoUrl!),
                      )
                    else
                      PersonAvatar(
                        name: child.name,
                        seed: child.id,
                        radius: 32,
                      ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            Formatters.pediatricAge(child.birthDate),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: ink,
                            ),
                          ),
                          Text(
                            'Nasceu em ${Formatters.date(child.birthDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                ContentBounds(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (child.isPreterm) ...<Widget>[
                        InfoBanner(
                          icon: Icons.info_outline_rounded,
                          color: AppColors.info,
                          text: 'Nasceu com ${child.gestationalWeeks} '
                              'semanas. As curvas usam idade corrigida '
                              '(${child.correctedAgeInMonths} meses); as '
                              'vacinas seguem a idade real.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (child.allergies.isNotEmpty) ...<Widget>[
                        InfoBanner(
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.danger,
                          text: 'Alergias: ${child.allergies.join(', ')}',
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SectionHeader(
                        title: 'Acompanhamento',
                        eyebrow: 'Resumo',
                      ),
                      if (vaccines.overdue > 0) ...<Widget>[
                        ClinicalAlertChip(
                          label: '${vaccines.overdue} vacina(s) em atraso',
                          tone: ClinicalAlertTone.danger,
                          icon: Icons.vaccines_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      QuickActionTile(
                        label: assessments.isEmpty
                            ? 'Crescimento'
                            : 'Crescimento · ${assessments.map((GrowthAssessment a) => '${a.indicator.shortLabel} ${Formatters.decimal(a.value)}').take(2).join(' · ')}',
                        icon: Icons.show_chart_rounded,
                        color: AppColors.moduleGrowth,
                        onTap: () => context.push(Routes.growth(child.id)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QuickActionTile(
                        label: vaccines.total == 0
                            ? 'Vacinas'
                            : vaccines.overdue > 0
                                ? 'Vacinas · ${vaccines.overdue} em atraso'
                                : 'Vacinas · ${vaccines.applied}/${vaccines.total}',
                        icon: Icons.vaccines_outlined,
                        color: vaccines.overdue > 0
                            ? AppColors.danger
                            : AppColors.moduleVaccines,
                        onTap: () => context.push(Routes.vaccines(child.id)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QuickActionTile(
                        label: 'Responsaveis e permissoes',
                        icon: Icons.family_restroom_outlined,
                        color: AppColors.violet,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChildGuardiansScreen(child: child),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QuickActionTile(
                        label: visitSummaries.isEmpty
                            ? 'Consultas'
                            : 'Consultas · ${visitSummaries.length} '
                                '${visitSummaries.length == 1 ? 'resumo' : 'resumos'}',
                        icon: Icons.summarize_outlined,
                        color: AppColors.violet,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                VisitSummariesScreen(childId: child.id),
                          ),
                        ),
                      ),
                      if (assessments.isNotEmpty) ...<Widget>[
                        const SectionHeader(
                          title: 'Última avaliação',
                          eyebrow: 'Padrões da OMS',
                        ),
                        for (final GrowthAssessment a in assessments)
                          _AssessmentTile(assessment: a),
                      ],
                      const SectionHeader(title: 'Dados', eyebrow: 'Ficha'),
                      SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            _DataRow(
                              label: 'Sexo',
                              value: child.sex.label,
                            ),
                            if (child.bloodType != null)
                              _DataRow(
                                label: 'Tipo sanguíneo',
                                value: child.bloodType!,
                              ),
                            if (child.birthWeightKg != null)
                              _DataRow(
                                label: 'Peso ao nascer',
                                value:
                                    '${Formatters.decimal(child.birthWeightKg!, digits: 2)} kg',
                              ),
                            if (child.birthHeightCm != null)
                              _DataRow(
                                label: 'Comprimento ao nascer',
                                value:
                                    '${Formatters.decimal(child.birthHeightCm!)} cm',
                              ),
                            if (child.conditions.isNotEmpty)
                              _DataRow(
                                label: 'Condições',
                                value: child.conditions.join(', '),
                              ),
                          ],
                        ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Excluir ${child.firstName}?'),
        content: const Text(
          'Todas as medições e o histórico de vacinas serão removidos. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if ((ok ?? false) && context.mounted) {
      await ref.read(childrenControllerProvider.notifier).deleteChild(child.id);
      if (context.mounted) context.pop();
    }
  }
}

class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({required this.assessment});

  final GrowthAssessment assessment;

  Color _color() => switch (assessment.classification) {
        GrowthClassification.severelyLow ||
        GrowthClassification.severelyHigh =>
          AppColors.danger,
        GrowthClassification.low || GrowthClassification.high =>
          AppColors.warning,
        GrowthClassification.attention => AppColors.honey,
        GrowthClassification.adequate => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    assessment.indicator.label,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    assessment.classification.labelFor(assessment.indicator),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _color(),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                DataValue(
                  value: Formatters.decimal(assessment.value),
                  unit: assessment.indicator.unit,
                  size: 18,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'percentil ${assessment.percentile.round()}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}
