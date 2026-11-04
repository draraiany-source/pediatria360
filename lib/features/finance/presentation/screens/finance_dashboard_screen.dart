import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart' show AuthFailure, ServerFailure;
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'
    show activeClinicMembershipProvider;
import '../../domain/finance_access.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';

class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = FinanceAccess.canViewDashboard(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('Financeiro')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para o modulo financeiro.'),
        ),
      );
    }

    ref.watch(financeSyncFromAgendaProvider);

    final AsyncValue<List<FinanceReceivable>> recvAsync =
        ref.watch(financeReceivablesProvider);
    final kpis = ref.watch(financeDashboardKpisProvider);
    final FinancePeriodFilter filter = ref.watch(financePeriodFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Financeiro'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: recvAsync.when(
        loading: () => const LoadingState(label: 'Carregando financeiro…'),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(e.toString()),
          onRetry: () {
            ref.invalidate(financeReceivablesProvider);
            ref.invalidate(financeSyncFromAgendaProvider);
          },
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financeReceivablesProvider);
            ref.invalidate(financePayablesProvider);
            ref.invalidate(financeSyncFromAgendaProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                children: FinancePeriodFilter.values
                    .where((FinancePeriodFilter f) => f != FinancePeriodFilter.custom)
                    .map(
                      (FinancePeriodFilter f) => ChoiceChip(
                        label: Text(f.label),
                        selected: filter == f,
                        onSelected: (_) =>
                            ref.read(financePeriodFilterProvider.notifier).state = f,
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.md),
              _KpiRow(label: 'Receita', value: formatCents(kpis.revenueMonth)),
              _KpiRow(label: 'Despesas', value: formatCents(kpis.expensesMonth)),
              _KpiRow(label: 'Saldo', value: formatCents(kpis.balance)),
              _KpiRow(
                label: 'Ticket medio',
                value: formatCents(kpis.ticketAvg),
              ),
              _KpiRow(
                label: 'A receber',
                value: formatCents(kpis.accountsReceivable),
              ),
              _KpiRow(
                label: 'A pagar',
                value: formatCents(kpis.accountsPayable),
              ),
              _KpiRow(
                label: 'Inadimplencia',
                value:
                    '${(kpis.delinquencyRate * 100).toStringAsFixed(1)}% (${formatCents(kpis.overdueAmount)})',
              ),
              const SizedBox(height: AppSpacing.lg),
              const BrandSectionHeader(title: 'Modulos'),
              QuickAccessCard(
                label: 'Contas a receber',
                subtitle: 'Cobrancas e recebimentos',
                icon: Icons.request_quote_outlined,
                color: AppColors.brand,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/receber'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'Contas a pagar',
                subtitle: 'Despesas e fornecedores',
                icon: Icons.payments_outlined,
                color: AppColors.teal,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/pagar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'Fluxo de caixa',
                subtitle: 'Entradas e saidas',
                icon: Icons.show_chart,
                color: AppColors.navy,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/fluxo'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'DRE',
                subtitle: 'Resultado do periodo',
                icon: Icons.account_balance_outlined,
                color: AppColors.raspberry,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/dre'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'Inadimplencia',
                subtitle: 'Titulos em atraso',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/inadimplencia'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'Producao',
                subtitle: 'Por profissional',
                icon: Icons.medical_services_outlined,
                color: AppColors.brand,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/producao'),
              ),
              const SizedBox(height: AppSpacing.sm),
              QuickAccessCard(
                label: 'Relatorios',
                subtitle: 'Exportar CSV / PDF',
                icon: Icons.summarize_outlined,
                color: AppColors.navy,
                wide: true,
                onTap: () => context.push('${Routes.financePath}/relatorios'),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
          ),
        ],
      ),
    );
  }
}
