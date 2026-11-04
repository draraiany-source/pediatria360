import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/billing_access.dart';
import '../providers/billing_providers.dart';

class BillingDashboardScreen extends ConsumerWidget {
  const BillingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = BillingAccess.canAccessModule(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('Faturamento')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para faturamento/convenios.'),
        ),
      );
    }

    final kpis = ref.watch(billingDashboardKpisProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Faturamento e convenios'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ref.watch(billingGuidesProvider).when(
            loading: () => const LoadingState(label: 'Carregando faturamento…'),
            error: (Object e, StackTrace _) => ErrorState(
              failure: ServerFailure(e.toString()),
              onRetry: () {
                ref.invalidate(billingGuidesProvider);
                ref.invalidate(billingBatchesProvider);
              },
            ),
            data: (_) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(billingGuidesProvider);
                ref.invalidate(billingBatchesProvider);
                ref.invalidate(billingGlosasProvider);
                ref.invalidate(billingPlansProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  _KpiRow(
                    label: 'Faturado no mes',
                    value: formatCents(kpis.billedMonth),
                  ),
                  _KpiRow(label: 'Recebido', value: formatCents(kpis.received)),
                  _KpiRow(label: 'Pendente', value: formatCents(kpis.pending)),
                  _KpiRow(label: 'Glosado', value: formatCents(kpis.glosed)),
                  _KpiRow(
                    label: 'Taxa de glosa',
                    value: '${(kpis.glosaRate * 100).toStringAsFixed(1)}%',
                  ),
                  _KpiRow(
                    label: 'Dias medios p/ receber',
                    value: kpis.avgDaysToReceive.toStringAsFixed(1),
                  ),
                  if (kpis.topRevenuePlan != null)
                    _KpiRow(
                      label: 'Maior receita (plano)',
                      value: kpis.topRevenuePlan!,
                    ),
                  if (kpis.topGlosaPlan != null)
                    _KpiRow(
                      label: 'Mais glosas (plano)',
                      value: kpis.topGlosaPlan!,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const BrandSectionHeader(title: 'Modulos'),
                  QuickAccessCard(
                    label: 'Planos e operadoras',
                    subtitle: 'Tabelas e regras',
                    icon: Icons.health_and_safety_outlined,
                    color: AppColors.brand,
                    wide: true,
                    onTap: () => context.push(Routes.billingPlansPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Autorizacoes',
                    subtitle: 'Senhas e validade',
                    icon: Icons.verified_user_outlined,
                    color: AppColors.teal,
                    wide: true,
                    onTap: () => context.push(Routes.billingAuthorizationsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Guias',
                    subtitle: 'Consultas e procedimentos',
                    icon: Icons.description_outlined,
                    color: AppColors.navy,
                    wide: true,
                    onTap: () => context.push(Routes.billingGuidesPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Lotes',
                    subtitle: 'Fechar, enviar e retorno',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.honey,
                    wide: true,
                    onTap: () => context.push(Routes.billingBatchesPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Glosas e recursos',
                    subtitle: 'Analise e contestacao',
                    icon: Icons.report_problem_outlined,
                    color: AppColors.warning,
                    wide: true,
                    onTap: () => context.push(Routes.billingGlosasPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Relatorios',
                    subtitle: 'Export CSV',
                    icon: Icons.table_chart_outlined,
                    color: AppColors.raspberry,
                    wide: true,
                    onTap: () => context.push(Routes.billingReportsPath),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
          ),
        ],
      ),
    );
  }
}
