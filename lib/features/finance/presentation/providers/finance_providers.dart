import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dev_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/agenda_providers.dart'
    show unitScopedMyAgendaProvider;
import '../../data/finance_repository.dart';
import '../../domain/finance_access.dart';
import '../../domain/finance_aggregators.dart';
import '../../domain/finance_models.dart';

final Provider<FinanceRepository> financeRepositoryProvider =
    Provider<FinanceRepository>(
  (Ref ref) => FinanceRepository(firestore: ref.watch(firestoreProvider)),
);

final StateProvider<FinancePeriodFilter> financePeriodFilterProvider =
    StateProvider<FinancePeriodFilter>(
  (Ref ref) => FinancePeriodFilter.month,
);

final Provider<FinancePeriod> financePeriodProvider = Provider<FinancePeriod>(
  (Ref ref) {
    final FinancePeriodFilter filter = ref.watch(financePeriodFilterProvider);
    return FinancePeriod.resolve(filter: filter, now: DateTime.now());
  },
);

final StreamProvider<List<FinanceReceivable>> financeReceivablesProvider =
    StreamProvider<List<FinanceReceivable>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<FinanceReceivable>>.value(const <FinanceReceivable>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<FinanceReceivable>>.value(const <FinanceReceivable>[]);
  }
  return ref.watch(financeRepositoryProvider).watchReceivables(uid);
});

final StreamProvider<List<FinancePayable>> financePayablesProvider =
    StreamProvider<List<FinancePayable>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<FinancePayable>>.value(const <FinancePayable>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<FinancePayable>>.value(const <FinancePayable>[]);
  }
  return ref.watch(financeRepositoryProvider).watchPayables(uid);
});

final StreamProvider<List<FinanceReceipt>> financeReceiptsProvider =
    StreamProvider<List<FinanceReceipt>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<FinanceReceipt>>.value(const <FinanceReceipt>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<FinanceReceipt>>.value(const <FinanceReceipt>[]);
  }
  return ref.watch(financeRepositoryProvider).watchReceipts(uid);
});

final StreamProviderFamily<List<FinanceReceivable>, String>
    patientFinanceReceivablesProvider =
    StreamProvider.family<List<FinanceReceivable>, String>((Ref ref, String childId) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<FinanceReceivable>>.value(const <FinanceReceivable>[]);
  }
  return ref
      .watch(financeRepositoryProvider)
      .watchReceivablesForPatient(ownerId: uid, childId: childId);
});

final Provider<FinanceAccessLevel> financeAccessLevelProvider =
    Provider<FinanceAccessLevel>((Ref ref) {
  return FinanceAccess.level(
    user: ref.watch(currentUserProvider),
    clinicMembership: ref.watch(activeClinicMembershipProvider),
  );
});

final Provider<FinanceDashboardKpis> financeDashboardKpisProvider =
    Provider<FinanceDashboardKpis>((Ref ref) {
  final List<FinanceReceivable> recv =
      ref.watch(financeReceivablesProvider).valueOrNull ??
          const <FinanceReceivable>[];
  final List<FinancePayable> pay =
      ref.watch(financePayablesProvider).valueOrNull ?? const <FinancePayable>[];
  final FinancePeriod period = ref.watch(financePeriodProvider);
  return FinanceDashboardKpis.compute(
    receivables: recv,
    payables: pay,
    period: period,
    now: DateTime.now(),
  );
});

final Provider<CashFlowSeries> financeCashFlowProvider =
    Provider<CashFlowSeries>((Ref ref) {
  final List<FinanceReceivable> recv =
      ref.watch(financeReceivablesProvider).valueOrNull ??
          const <FinanceReceivable>[];
  final List<FinancePayable> pay =
      ref.watch(financePayablesProvider).valueOrNull ?? const <FinancePayable>[];
  final FinancePeriod period = ref.watch(financePeriodProvider);
  return CashFlowSeries.build(
    receivables: recv,
    payables: pay,
    period: period,
  );
});

final FutureProvider<void> financeSyncFromAgendaProvider =
    FutureProvider<void>((Ref ref) async {
  final String? uid = ref.read(currentUserProvider)?.uid;
  if (uid == null) return;
  final List<Appointment> agenda =
      ref.read(unitScopedMyAgendaProvider).valueOrNull ??
          const <Appointment>[];
  await ref.read(financeRepositoryProvider).syncFromAppointments(
        ownerId: uid,
        appointments: agenda,
        membership: ref.read(activeClinicMembershipProvider),
      );
  ref.invalidate(financeReceivablesProvider);
});
