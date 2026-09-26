import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/config/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../clinic/presentation/providers/clinic_providers.dart';
import '../../../pending/presentation/providers/pending_providers.dart';
import '../../domain/bi_access.dart';
import '../../domain/bi_aggregators.dart';
import '../../domain/bi_models.dart';
import '../../../security/domain/permission_matrix.dart';
import '../../../security/presentation/providers/security_providers.dart';
import '../providers/bi_providers.dart';
import '../widgets/bi_empty_state.dart';
import '../widgets/bi_kpi_tile.dart';

class BiHubScreen extends ConsumerWidget {
  const BiHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = BiAccess.canAccessModule(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('BI / Indicadores')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para indicadores executivos.'),
        ),
      );
    }

    final BiExecutiveSnapshot snapshot = ref.watch(executiveSnapshotProvider);
    final List<BiKpiCardData> cards = ref.watch(biVisibleKpiCardsProvider);
    final BiPeriodFilter filter = ref.watch(biPeriodFilterProvider);
    final bool canExport = BiAccess.canExport(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('BI / Indicadores'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          if (canExport)
            IconButton(
              tooltip: 'Exportar CSV',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                final String csv = BiAggregators.exportCsv(cards);
                await Clipboard.setData(ClipboardData(text: csv));
                await ref.read(auditLogServiceProvider).logExport(
                      user: ref.read(currentUserProvider),
                      membership: ref.read(activeClinicMembershipProvider),
                      module: PermissionModule.bi,
                      entityType: 'bi_kpi',
                      exportKind: 'csv',
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('KPIs copiados (CSV).')),
                  );
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clinicDashboardStatsProvider);
          ref.invalidate(professionalPendingItemsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              children: BiPeriodFilter.values
                  .where((BiPeriodFilter f) => f != BiPeriodFilter.custom)
                  .map(
                    (BiPeriodFilter f) => ChoiceChip(
                      label: Text(f.label),
                      selected: filter == f,
                      onSelected: (_) => ref
                          .read(biPeriodFilterProvider.notifier)
                          .state = f,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshot.financeRevenueCents != null)
              Text(
                'Receita no periodo: ${formatCents(snapshot.financeRevenueCents!)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (cards.isEmpty)
              BiEmptyState(
                title: 'Nenhum KPI visivel para seu perfil ou periodo.',
                subtitle: 'Ajuste o periodo ou aguarde dados operacionais.',
                illustration: AppAssets.capiLupa,
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final int cols = c.maxWidth > 720 ? 3 : (c.maxWidth > 480 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.45,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (BuildContext context, int i) =>
                        BiKpiTile(data: cards[i]),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.xl),
            const BrandSectionHeader(title: 'Dashboards'),
            QuickAccessCard(
              label: 'Administrativo',
              subtitle: 'Financeiro, faturamento, estoque',
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.navy,
              wide: true,
              onTap: () => context.push(Routes.biAdminPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickAccessCard(
              label: 'Clinico',
              subtitle: 'Pendencias e produtividade medica',
              icon: Icons.medical_services_outlined,
              color: AppColors.brand,
              wide: true,
              onTap: () => context.push(Routes.biClinicalPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickAccessCard(
              label: 'Recepcao',
              subtitle: 'Fila e tempos de espera',
              icon: Icons.how_to_reg_outlined,
              color: AppColors.teal,
              wide: true,
              onTap: () => context.push(Routes.biReceptionPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickAccessCard(
              label: 'Operacional',
              subtitle: 'Agenda e picos de horario',
              icon: Icons.calendar_month_outlined,
              color: AppColors.honey,
              wide: true,
              onTap: () => context.push(Routes.biOpsPath),
            ),
          ],
        ),
      ),
    );
  }
}
