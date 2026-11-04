import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/clinic_dashboard_stats.dart';
import '../../../security/domain/security_access.dart';
import '../providers/clinic_providers.dart';
import '../widgets/ai_medical_disclaimer_banner.dart';

/// Painel Consultorio 360 — KPIs e atalhos do dia.
class ClinicDashboardScreen extends ConsumerWidget {
  const ClinicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ClinicDashboardStats> statsAsync =
        ref.watch(clinicDashboardStatsProvider);
    final ThemeData theme = Theme.of(context);
    final bool showAudit = SecurityAccess.canAdministerAudit(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Consultorio 360'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(compact: true),
          Expanded(
            child: statsAsync.when(
              loading: () => const LoadingState(label: 'Carregando painel…'),
              error: (Object e, StackTrace _) => ErrorState(
                failure: ServerFailure(e.toString()),
                onRetry: () => ref.invalidate(clinicDashboardStatsProvider),
              ),
              data: (ClinicDashboardStats stats) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(clinicDashboardStatsProvider);
                    ref.invalidate(todayClinicAppointmentsProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: <Widget>[
                      Text(
                        'Visao do dia',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _KpiGrid(stats: stats),
                      const SizedBox(height: AppSpacing.xl),
                      const BrandSectionHeader(title: 'Atalhos'),
                      if (AppConfig.voiceConsultationEnabled) ...<Widget>[
                        QuickAccessCard(
                          label: 'Iniciar consulta com IA',
                          subtitle: 'Gravacao, rascunho e revisao medica',
                          icon: Icons.mic_rounded,
                          asset: AppIcons.microphone,
                          color: AppColors.raspberry,
                          wide: true,
                          onTap: () => context.push(Routes.clinicVoicePath),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      QuickAccessCard(
                        label: 'Recepcao',
                        subtitle: 'Fila e check-in do dia',
                        icon: Icons.how_to_reg_rounded,
                        asset: AppIcons.waitingQueue,
                        color: AppColors.teal,
                        wide: true,
                        onTap: () => context.push(Routes.clinicReceptionPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Agenda',
                        subtitle: 'Consultas e retornos',
                        icon: Icons.calendar_month_rounded,
                        asset: AppIcons.schedule,
                        color: AppColors.brand,
                        wide: true,
                        onTap: () => context.go(Routes.agendaPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Pacientes',
                        subtitle: 'Carteira e prontuario',
                        icon: Icons.groups_rounded,
                        asset: AppIcons.patients,
                        color: AppColors.navy,
                        wide: true,
                        onTap: () => context.go(Routes.patientsPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Central de Pendencias',
                        subtitle: 'Retornos, vacinas, exames e financeiro',
                        icon: Icons.inbox_outlined,
                        asset: AppIcons.notification,
                        color: AppColors.warning,
                        wide: true,
                        onTap: () => context.push(Routes.clinicPendingPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'CRM clinico',
                        subtitle: 'Segmentos e automacoes',
                        icon: Icons.insights_outlined,
                        asset: AppIcons.patients,
                        color: AppColors.brand,
                        wide: true,
                        onTap: () => context.push(Routes.clinicCrmPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'BI / Indicadores',
                        subtitle: 'KPIs executivos e dashboards',
                        icon: Icons.insights_outlined,
                        color: AppColors.honey,
                        wide: true,
                        onTap: () => context.push(Routes.biPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Financeiro',
                        subtitle: 'Receitas, despesas e inadimplencia',
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.navy,
                        wide: true,
                        onTap: () => context.push(Routes.financePath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Faturamento',
                        subtitle: 'Convenios, lotes e glosas',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.tealDeep,
                        wide: true,
                        onTap: () => context.push(Routes.billingPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Estoque',
                        subtitle: 'Lotes, validade e alertas',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.tealDeep,
                        wide: true,
                        onTap: () => context.push(Routes.inventoryPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Crescimento',
                        subtitle: 'Curvas e antropometria',
                        icon: Icons.show_chart_rounded,
                        asset: AppIcons.growth,
                        color: AppColors.tealDeep,
                        wide: true,
                        onTap: () => context.push(Routes.childrenPath),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      QuickAccessCard(
                        label: 'Vacinas',
                        subtitle: 'Calendario e doses',
                        icon: Icons.vaccines_outlined,
                        asset: AppIcons.vaccines,
                        color: AppColors.warning,
                        wide: true,
                        onTap: () => context.push(Routes.childrenPath),
                      ),
                      if (showAudit) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        QuickAccessCard(
                          label: 'Auditoria',
                          subtitle: 'Trilha de seguranca e exportacoes',
                          icon: Icons.shield_outlined,
                          color: AppColors.navy,
                          wide: true,
                          onTap: () => context.push(Routes.auditPath),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        QuickAccessCard(
                          label: 'Permissoes',
                          subtitle: 'Matriz read-only (admin)',
                          icon: Icons.admin_panel_settings_outlined,
                          color: AppColors.tealDeep,
                          wide: true,
                          onTap: () => context.push(Routes.permissionsPath),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final ClinicDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final List<_Kpi> items = <_Kpi>[
      _Kpi('Hoje', '${stats.todayAppointments}', AppColors.brand),
      _Kpi('Espera', '${stats.waiting}', AppColors.honey),
      _Kpi('Em sala', '${stats.inService}', AppColors.teal),
      _Kpi('Concluidas', '${stats.finished}', AppColors.navy),
      _Kpi('Retornos', '${stats.pendingReturns}', AppColors.raspberry),
      _Kpi(
        'Faltas',
        '${(stats.noShowRate * 100).toStringAsFixed(0)}%',
        AppColors.danger,
      ),
      _Kpi('Rascunhos', '${stats.clinicalAlerts}', AppColors.moduleAgenda),
      _Kpi('Msgs', '${stats.pendingMessages}', AppColors.moduleLibrary),
      _Kpi('Novos/mes', '${stats.newPatients}', AppColors.tealDeep),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = c.maxWidth > 640 ? 3 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.55,
          children: items
              .map(
                (_Kpi k) => AppCard(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        k.value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                          color: k.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        k.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}
