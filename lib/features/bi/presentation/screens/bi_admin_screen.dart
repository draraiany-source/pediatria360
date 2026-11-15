import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_access.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/bi_access.dart';
import '../providers/bi_providers.dart';

class BiAdminScreen extends ConsumerWidget {
  const BiAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeClinicMembershipProvider);
    final bool finance = BiAccess.canSeeFinance(
      user: user,
      clinicMembership: membership,
    );
    final bool inventory = BiAccess.canSeeInventory(
      user: user,
      clinicMembership: membership,
    );
    if (!finance && !inventory) {
      return Scaffold(
        appBar: AppBar(title: const Text('BI Administrativo')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para indicadores administrativos.'),
        ),
      );
    }

    final snapshot = ref.watch(executiveSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('BI Administrativo'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (finance && snapshot.financeRevenueCents != null) ...<Widget>[
            Text(
              'Receita: ${formatCents(snapshot.financeRevenueCents!)} · '
              'Saldo: ${formatCents(snapshot.financeBalanceCents ?? 0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Inadimplencia: '
              '${((snapshot.financeDelinquencyRate ?? 0) * 100).toStringAsFixed(1)}% '
              '(${formatCents(snapshot.financeOverdueCents ?? 0)})',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (finance && snapshot.billingGlosaRate != null)
            Text(
              'Glosa: ${((snapshot.billingGlosaRate ?? 0) * 100).toStringAsFixed(1)}% · '
              'Pendente faturamento: ${formatCents(snapshot.billingPendingCents ?? 0)}',
            ),
          if (inventory && snapshot.inventoryBelowMin != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Estoque critico: ${snapshot.inventoryBelowMin} itens · '
                'Lotes vencidos: ${snapshot.inventoryExpiredLots ?? 0}',
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const BrandSectionHeader(title: 'Modulos'),
          if (finance) ...<Widget>[
            if (canOpenRoute(ref, Routes.financePath))
              QuickAccessCard(
                label: 'Financeiro',
                subtitle: 'Dashboard e inadimplencia',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.navy,
                wide: true,
                onTap: () => context.push(Routes.financePath),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (canOpenRoute(ref, Routes.financeDelinquencyPath))
              QuickAccessCard(
                label: 'Inadimplencia',
                subtitle: 'Titulos em atraso',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                wide: true,
                onTap: () => context.push(Routes.financeDelinquencyPath),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (canOpenRoute(ref, Routes.billingPath))
              QuickAccessCard(
                label: 'Faturamento',
                subtitle: 'Convenios e glosas',
                icon: Icons.receipt_long_outlined,
                color: AppColors.teal,
                wide: true,
                onTap: () => context.push(Routes.billingPath),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (canOpenRoute(ref, Routes.billingGlosasPath))
              QuickAccessCard(
                label: 'Glosas',
                subtitle: 'Recursos e perdas',
                icon: Icons.gavel_outlined,
                color: AppColors.raspberry,
                wide: true,
                onTap: () => context.push(Routes.billingGlosasPath),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (canOpenRoute(ref, Routes.financeProductionPath))
              QuickAccessCard(
                label: 'Producao',
                subtitle: 'Produtividade por profissional',
                icon: Icons.bar_chart,
                color: AppColors.brand,
                wide: true,
                onTap: () => context.push(Routes.financeProductionPath),
              ),
          ],
          if (inventory) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            if (canOpenRoute(ref, Routes.inventoryPath))
              QuickAccessCard(
                label: 'Estoque',
                subtitle: 'Alertas e validade',
                icon: Icons.inventory_2_outlined,
                color: AppColors.tealDeep,
                wide: true,
                onTap: () => context.push(Routes.inventoryPath),
              ),
          ],
          if (canOpenRoute(ref, Routes.clinicPendingPath))
            QuickAccessCard(
              label: 'Pendencias',
              subtitle: 'Central operacional',
              icon: Icons.inbox_outlined,
              color: AppColors.honey,
              wide: true,
              onTap: () => context.push(Routes.clinicPendingPath),
            ),
        ],
      ),
    );
  }
}
