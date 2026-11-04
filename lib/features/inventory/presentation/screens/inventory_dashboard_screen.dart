import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../domain/inventory_access.dart';
import '../providers/inventory_providers.dart';

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = InventoryAccess.canView(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('Estoque')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para o modulo de estoque.'),
        ),
      );
    }

    final kpis = ref.watch(inventoryDashboardKpisProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Estoque'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ref.watch(inventoryItemsProvider).when(
            loading: () => const LoadingState(label: 'Carregando estoque…'),
            error: (Object e, StackTrace _) => ErrorState(
              failure: ServerFailure(e.toString()),
              onRetry: () {
                ref.invalidate(inventoryItemsProvider);
                ref.invalidate(inventoryLotsProvider);
              },
            ),
            data: (_) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryItemsProvider);
                ref.invalidate(inventoryLotsProvider);
                ref.invalidate(inventoryMovementsProvider);
                ref.invalidate(inventoryPurchaseOrdersProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  _KpiRow(label: 'Itens ativos', value: '${kpis.totalItems}'),
                  _KpiRow(label: 'Abaixo do minimo', value: '${kpis.belowMin}'),
                  _KpiRow(
                    label: 'Lotes perto do vencimento',
                    value: '${kpis.nearExpiryLots}',
                  ),
                  _KpiRow(label: 'Lotes vencidos', value: '${kpis.expiredLots}'),
                  _KpiRow(
                    label: 'Valor em estoque',
                    value: formatCents(kpis.stockValueCents),
                  ),
                  _KpiRow(
                    label: 'Consumo no mes',
                    value: '${kpis.monthConsumption} un.',
                  ),
                  _KpiRow(label: 'Perdas no mes', value: '${kpis.losses} un.'),
                  _KpiRow(
                    label: 'Compras pendentes',
                    value: '${kpis.pendingPurchases}',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _NavTile(
                    title: 'Itens',
                    subtitle: 'Cadastro e niveis minimos',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => context.push('${Routes.inventoryPath}/itens'),
                  ),
                  _NavTile(
                    title: 'Lotes',
                    subtitle: 'Validade e saldo por lote',
                    icon: Icons.qr_code_2_outlined,
                    onTap: () => context.push('${Routes.inventoryPath}/lotes'),
                  ),
                  _NavTile(
                    title: 'Movimentacoes',
                    subtitle: 'Entradas, saidas e ajustes',
                    icon: Icons.swap_vert_rounded,
                    onTap: () =>
                        context.push('${Routes.inventoryPath}/movimentos'),
                  ),
                  _NavTile(
                    title: 'Fornecedores',
                    subtitle: 'Contatos e documentos',
                    icon: Icons.local_shipping_outlined,
                    onTap: () =>
                        context.push('${Routes.inventoryPath}/fornecedores'),
                  ),
                  _NavTile(
                    title: 'Pedidos de compra',
                    subtitle: 'Solicitacao ate recebimento',
                    icon: Icons.shopping_cart_outlined,
                    onTap: () => context.push('${Routes.inventoryPath}/compras'),
                  ),
                  _NavTile(
                    title: 'Inventario fisico',
                    subtitle: 'Contagem e divergencias',
                    icon: Icons.fact_check_outlined,
                    onTap: () =>
                        context.push('${Routes.inventoryPath}/inventario'),
                  ),
                  _NavTile(
                    title: 'Relatorios',
                    subtitle: 'Exportar CSV',
                    icon: Icons.table_chart_outlined,
                    onTap: () =>
                        context.push('${Routes.inventoryPath}/relatorios'),
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
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.tealDeep),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
