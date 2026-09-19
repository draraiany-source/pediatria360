import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../../tools/domain/calculators.dart';
import '../screens/patient_summary_formatting.dart';

/// Cabeçalho clínico premium do prontuário 360.
class PatientChartHeader extends StatelessWidget {
  const PatientChartHeader({
    required this.patientId,
    required this.displayName,
    this.child,
    this.birthDate,
    this.sexLabel,
    this.allergies = const <String>[],
    this.conditions = const <String>[],
    this.overdueVaccines = 0,
    this.onEditProfile,
    super.key,
  });

  final String patientId;
  final String displayName;
  final Child? child;
  final DateTime? birthDate;
  final String? sexLabel;
  final List<String> allergies;
  final List<String> conditions;
  final int overdueVaccines;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? birth = child?.birthDate ?? birthDate;
    final String sex = child?.sex.label ?? sexLabel ?? '';
    final String? guardian = child?.guardianName;
    final String? phone = child?.guardianPhone ?? child?.phone;
    final List<String> allergyList =
        child?.allergies.isNotEmpty == true ? child!.allergies : allergies;
    final List<String> conditionList =
        child?.conditions.isNotEmpty == true ? child!.conditions : conditions;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PersonAvatar(
                name: displayName,
                seed: patientId,
                photoUrl: child?.photoUrl,
                radius: 36,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      <String>[
                        if (birth != null) Formatters.pediatricAge(birth),
                        if (birth != null) 'nasc. ${Formatters.date(birth)}',
                        if (sex.isNotEmpty) sex,
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (guardian != null && guardian.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Responsável: $guardian',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                    if (phone != null && phone.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Telefone: $phone',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                    if ((child?.insurance ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Convênio: ${child!.insurance}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEditProfile != null)
                IconButton(
                  onPressed: onEditProfile,
                  tooltip: 'Editar cadastro',
                  icon: const AppIcon(
                    asset: AppIcons.edit,
                    size: 22,
                    fallback: Icons.edit_outlined,
                    color: AppColors.brand,
                  ),
                ),
            ],
          ),
          if (allergyList.isNotEmpty ||
              conditionList.isNotEmpty ||
              overdueVaccines > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (allergyList.isNotEmpty)
                  ClinicalAlertChip(
                    label: 'Alergias: ${allergyList.join(', ')}',
                    tone: ClinicalAlertTone.danger,
                    icon: Icons.warning_amber_rounded,
                    asset: AppIcons.allergy,
                  ),
                if (conditionList.isNotEmpty)
                  ClinicalAlertChip(
                    label: 'Comorbidades: ${conditionList.join(', ')}',
                    tone: ClinicalAlertTone.warning,
                    icon: Icons.medical_information_outlined,
                    asset: AppIcons.medicalRecord,
                  ),
                if (overdueVaccines > 0)
                  ClinicalAlertChip(
                    label: '$overdueVaccines vacina(s) atrasada(s)',
                    tone: ClinicalAlertTone.warning,
                    icon: Icons.vaccines_outlined,
                    asset: AppIcons.vaccineOverdue,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Grade de indicadores clínicos do resumo.
class ClinicalSummaryGrid extends StatelessWidget {
  const ClinicalSummaryGrid({
    required this.latestGrowth,
    required this.encounters,
    required this.labs,
    required this.vaccineSummary,
    this.childId,
    this.nextReturnLabel,
    super.key,
  });

  final GrowthRecord? latestGrowth;
  final List<Encounter> encounters;
  final List<LabResult> labs;
  final VaccineSummary vaccineSummary;
  final String? childId;
  final String? nextReturnLabel;

  @override
  Widget build(BuildContext context) {
    final double? weight = latestGrowth?.weightKg;
    final double? height = latestGrowth?.heightCm;
    final double? pc = latestGrowth?.headCircumferenceCm;
    final String bmi = (weight != null && height != null)
        ? Formatters.decimal(
            PediatricCalculators.bmi(weightKg: weight, heightCm: height),
          )
        : '—';

    final Encounter? last = encounters.isEmpty
        ? null
        : encounters.reduce(
            (Encounter a, Encounter b) =>
                a.startedAt.isAfter(b.startedAt) ? a : b,
          );

    final int pendingLabs =
        labs.where((LabResult l) => l.isOutOfRange).length;

    final List<_Kpi> items = <_Kpi>[
      _Kpi(
        label: 'Peso',
        value: weight == null ? '—' : '${Formatters.decimal(weight)} kg',
        icon: Icons.monitor_weight_outlined,
        color: AppColors.teal,
      ),
      _Kpi(
        label: 'Altura',
        value: height == null ? '—' : '${Formatters.decimal(height)} cm',
        icon: Icons.height_rounded,
        color: AppColors.brand,
      ),
      _Kpi(
        label: 'IMC',
        value: bmi,
        icon: Icons.analytics_outlined,
        color: AppColors.moduleLibrary,
      ),
      _Kpi(
        label: 'Perímetro cefálico',
        value: pc == null ? '—' : '${Formatters.decimal(pc)} cm',
        icon: Icons.face_retouching_natural_outlined,
        color: AppColors.moduleGrowth,
      ),
      _Kpi(
        label: 'Última consulta',
        value: last == null ? '—' : Formatters.date(last.startedAt),
        icon: Icons.event_available_outlined,
        asset: AppIcons.consultation,
        color: AppColors.navy,
      ),
      _Kpi(
        label: 'Próximo retorno',
        value: nextReturnLabel ?? 'A agendar',
        icon: Icons.event_repeat_rounded,
        asset: AppIcons.followUp,
        color: AppColors.tealDeep,
      ),
      _Kpi(
        label: 'Vacinas pendentes',
        value: vaccineSummary.total == 0
            ? '—'
            : '${vaccineSummary.overdue + vaccineSummary.upcoming}',
        icon: Icons.vaccines_outlined,
        asset: vaccineSummary.overdue > 0
            ? AppIcons.vaccineOverdue
            : AppIcons.vaccinePending,
        color: vaccineSummary.overdue > 0
            ? AppColors.danger
            : AppColors.moduleVaccines,
        onTap: childId == null
            ? null
            : () => context.push(Routes.vaccines(childId!)),
      ),
      _Kpi(
        label: 'Exames fora da faixa',
        value: '$pendingLabs',
        icon: Icons.science_outlined,
        asset: AppIcons.exams,
        color: pendingLabs > 0 ? AppColors.warning : AppColors.moduleExams,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = c.maxWidth > 720
            ? 4
            : c.maxWidth > 420
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: cols == 1 ? 3.6 : 1.55,
          children: items
              .map(
                (_Kpi k) => AppCard(
                  onTap: k.onTap,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: k.color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: k.asset != null
                            ? AppIcon(
                                asset: k.asset!,
                                size: 20,
                                fallback: k.icon,
                                color: k.color,
                              )
                            : Icon(k.icon, color: k.color, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              k.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              k.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.asset,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? asset;
  final Color color;
  final VoidCallback? onTap;
}

/// Atalho de módulo interno do prontuário (vacinas, crescimento, etc.).
class ChartModuleLinkCard extends StatelessWidget {
  const ChartModuleLinkCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.asset,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? asset;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: asset != null
                      ? AppIcon(
                          asset: asset!,
                          size: 28,
                          fallback: icon,
                          color: color,
                        )
                      : Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: actionLabel!,
                    icon: Icons.open_in_new_rounded,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helpers de texto curto para o resumo (reexporta formatação existente).
String chartGrowthLine(GrowthRecord? latest) => formatGrowthSummary(latest);
String chartConsultLine(List<Encounter> encounters) =>
    formatConsultationsSummary(encounters);
String chartLabsLine(List<LabResult> labs) => formatLabsSummary(labs);
String chartDocsLine(List<ClinicalDocument> documents) =>
    formatDocumentsSummary(documents);
