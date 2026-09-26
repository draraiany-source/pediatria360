import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../billing/domain/billing_models.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../clinic/domain/clinic_dashboard_stats.dart';
import '../../../clinic/presentation/providers/clinic_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../finance/domain/finance_aggregators.dart';
import '../../../finance/domain/finance_models.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../inventory/domain/inventory_aggregators.dart';
import '../../../inventory/domain/inventory_models.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../pending/domain/pending_item.dart';
import '../../../pending/presentation/providers/pending_providers.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/agenda_providers.dart'
    show unitScopedMyAgendaProvider;
import '../../domain/bi_access.dart';
import '../../domain/bi_aggregators.dart';
import '../../domain/bi_models.dart';

/// Reutiliza o filtro de periodo do financeiro (unica fonte).
final StateProvider<BiPeriodFilter> biPeriodFilterProvider =
    financePeriodFilterProvider;

final Provider<FinancePeriod> biPeriodProvider = financePeriodProvider;

final Provider<BiAccessLevel> biAccessLevelProvider =
    Provider<BiAccessLevel>((Ref ref) {
  return BiAccess.level(
    user: ref.watch(currentUserProvider),
    clinicMembership: ref.watch(activeClinicMembershipProvider),
  );
});

final Provider<BiExecutiveSnapshot> executiveSnapshotProvider =
    Provider<BiExecutiveSnapshot>((Ref ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  final ClinicMembership? membership = ref.watch(activeClinicMembershipProvider);
  final bool finance = BiAccess.canSeeFinance(
    user: user,
    clinicMembership: membership,
  );
  final bool billing = finance;
  final bool inventory = BiAccess.canSeeInventory(
    user: user,
    clinicMembership: membership,
  );

  final FinancePeriod period = ref.watch(biPeriodProvider);
  final List<Appointment> agenda =
      ref.watch(unitScopedMyAgendaProvider).valueOrNull ??
          const <Appointment>[];
  final PendingAttentionCounts pending =
      ref.watch(pendingAttentionCountsProvider);
  final int openPendings = ref
          .watch(professionalPendingItemsProvider)
          .valueOrNull
          ?.length ??
      0;

  final ClinicDashboardStats? clinic = ref
      .watch(clinicDashboardStatsProvider)
      .valueOrNull;

  FinanceDashboardKpis? financeKpis;
  if (finance) {
    financeKpis = ref.watch(financeDashboardKpisProvider);
  }
  BillingDashboardKpis? billingKpis;
  if (billing) {
    billingKpis = ref.watch(billingDashboardKpisProvider);
  }
  InventoryDashboardKpis? inventoryKpis;
  if (inventory) {
    inventoryKpis = ref.watch(inventoryDashboardKpisProvider);
  }

  return BiAggregators.compose(
    clinic: clinic,
    finance: financeKpis,
    billing: billingKpis,
    inventory: inventoryKpis,
    pendingAttention: pending,
    appointments: agenda,
    period: period,
    openPendings: openPendings,
  );
});

final Provider<List<BiKpiCardData>> biVisibleKpiCardsProvider =
    Provider<List<BiKpiCardData>>((Ref ref) {
  final BiExecutiveSnapshot snapshot = ref.watch(executiveSnapshotProvider);
  final AppUser? user = ref.watch(currentUserProvider);
  final ClinicMembership? membership = ref.watch(activeClinicMembershipProvider);
  return BiAggregators.kpiCardsForSnapshot(
    snapshot: snapshot,
    includeFinance: BiAccess.canSeeFinance(
      user: user,
      clinicMembership: membership,
    ),
    includeBilling: BiAccess.canSeeFinance(
      user: user,
      clinicMembership: membership,
    ),
    includeInventory: BiAccess.canSeeInventory(
      user: user,
      clinicMembership: membership,
    ),
    includeClinical: BiAccess.canSeeClinical(
      user: user,
      clinicMembership: membership,
    ),
    includeOps: BiAccess.canSeeOps(
      user: user,
      clinicMembership: membership,
    ),
  );
});
