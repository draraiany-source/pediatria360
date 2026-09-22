import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dev_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../../shared/domain/entities/vaccine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../children/presentation/providers/children_providers.dart'
    show childrenRepositoryProvider;
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../emr/presentation/screens/patient_timeline_screen.dart';
import '../../../emr/presentation/screens/professional_patients_screen.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../billing/domain/billing_models.dart';
import '../../../billing/presentation/providers/billing_providers.dart'
    show billingRepositoryProvider;
import '../../../finance/domain/finance_models.dart';
import '../../../finance/presentation/providers/finance_providers.dart'
    show financeRepositoryProvider;
import '../../../inventory/domain/inventory_models.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/telemedicine_screen.dart';
import '../../../vaccines/domain/pni_calendar.dart';
import '../../data/pending_repository.dart';
import '../../data/pending_tracking_record.dart';
import '../../domain/pending_access.dart';
import '../../domain/pending_aggregator.dart';
import '../../domain/pending_item.dart';

final Provider<PendingRepository> pendingRepositoryProvider =
    Provider<PendingRepository>(
  (Ref ref) => PendingRepository(firestore: ref.watch(firestoreProvider)),
);

/// Invalida o agregador quando streams principais mudam.
final Provider<void> pendingItemsRefreshCoordinatorProvider =
    Provider<void>((Ref ref) {
  ref.listen(professionalPatientsProvider, (_, __) {
    ref.invalidate(professionalPendingItemsProvider);
  });
  ref.listen(myAgendaProvider, (_, __) {
    ref.invalidate(professionalPendingItemsProvider);
  });
  ref.listen(notificationsProvider, (_, __) {
    ref.invalidate(professionalPendingItemsProvider);
  });
  ref.listen(pendingTrackingMapProvider, (_, __) {
    ref.invalidate(professionalPendingItemsProvider);
  });
});

final StreamProvider<Map<String, PendingTrackingRecord>>
    pendingTrackingMapProvider =
    StreamProvider<Map<String, PendingTrackingRecord>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<Map<String, PendingTrackingRecord>>.value(
      const <String, PendingTrackingRecord>{},
    );
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<Map<String, PendingTrackingRecord>>.value(
      const <String, PendingTrackingRecord>{},
    );
  }
  return ref.watch(pendingRepositoryProvider).watchTrackingBySourceKey(uid);
});

final FutureProvider<List<PendingItem>> professionalPendingItemsProvider =
    FutureProvider<List<PendingItem>>((Ref ref) async {
  ref.watch(pendingItemsRefreshCoordinatorProvider);

  if (DevMode.isEnabled &&
      ref.read(firebaseAuthProvider).currentUser == null) {
    return const <PendingItem>[];
  }

  final String? uid = ref.read(currentUserProvider)?.uid;
  if (uid == null) return const <PendingItem>[];

  final List<PatientSummary> rawPatients =
      ref.read(professionalPatientsProvider).valueOrNull ??
          const <PatientSummary>[];
  final List<PendingPatientSnapshot> patients = rawPatients
      .map(
        (PatientSummary p) => PendingPatientSnapshot(
          patientId: p.patientId,
          childId: p.childId,
          name: p.name,
          lastEncounterAt: p.lastEncounterAt,
          hasOpenDraft: p.hasOpenDraft,
          encounterCount: p.encounterCount,
        ),
      )
      .toList(growable: false);
  final List<Encounter> encounters = await ref
      .read(encounterRepositoryProvider)
      .watchProfessionalEncounters(uid)
      .first;
  final List<Appointment> agenda =
      ref.read(myAgendaProvider).valueOrNull ?? const <Appointment>[];
  final List<AppNotification> notifications =
      ref.read(notificationsProvider).valueOrNull ?? const <AppNotification>[];
  final Map<String, PendingTrackingRecord> tracking =
      ref.read(pendingTrackingMapProvider).valueOrNull ??
          const <String, PendingTrackingRecord>{};

  final List<ClinicalDocument> unsigned = await ref
      .read(encounterRepositoryProvider)
      .fetchUnsignedDocumentsForProfessional(uid);

  final List<String> patientIds =
      patients.map((PendingPatientSnapshot p) => p.patientId).toList(growable: false);
  final List<LabResult> labs = await ref
      .read(encounterRepositoryProvider)
      .fetchPendingLabsForPatients(patientIds);

  final List<VaccineOverdueInput> vaccineOverdue = <VaccineOverdueInput>[];
  for (final PendingPatientSnapshot p in patients.take(30)) {
    final List<VaccineDose> doses =
        await ref.read(childrenRepositoryProvider).watchVaccineDoses(p.childId).first;
    for (final VaccineDose dose in doses) {
      if (!dose.isOverdue()) continue;
      final VaccineDoseSchedule? schedule =
          PniCalendar.find(dose.vaccineId, dose.doseIndex);
      vaccineOverdue.add(
        VaccineOverdueInput(
          childId: p.childId,
          doseId: dose.id,
          vaccineLabel: schedule?.vaccineName ?? dose.vaccineId,
          dueAt: dose.dueAt ?? DateTime.now(),
          patientName: p.name,
        ),
      );
    }
  }

  final List<FinanceReceivable> receivables = await ref
      .read(financeRepositoryProvider)
      .watchReceivables(uid)
      .first;
  final DateTime now = DateTime.now();
  final List<FinanceReceivable> openReceivables = receivables
      .where((FinanceReceivable r) => r.effectiveStatus(now).isOpen)
      .toList(growable: false);

  final billingRepo = ref.read(billingRepositoryProvider);
  final List<InsuranceAuthorization> authorizations =
      await billingRepo.watchAuthorizations(uid).first;
  final List<BillingGuide> billingGuides =
      await billingRepo.watchGuides(uid).first;
  final List<BillingBatch> billingBatches =
      await billingRepo.watchBatches(uid).first;
  final List<BillingGlosa> billingGlosas =
      await billingRepo.watchGlosas(uid).first;
  final List<PatientInsurance> patientInsurances =
      await billingRepo.watchPatientInsurances(uid).first;

  final inventoryRepo = ref.read(inventoryRepositoryProvider);
  final List<InventoryItem> inventoryItems =
      await inventoryRepo.watchItems(uid).first;
  final List<InventoryLot> inventoryLots =
      await inventoryRepo.watchLots(uid).first;
  final List<InventoryCount> inventoryCounts =
      await inventoryRepo.watchCounts(uid).first;

  final List<PendingItem> built = PendingAggregator.build(
    PendingAggregatorInput(
      now: now,
      patients: patients,
      encounters: encounters,
      agenda: agenda,
      notifications: notifications,
      unsignedDocuments: unsigned,
      pendingLabs: labs,
      vaccineOverdue: vaccineOverdue,
      trackingBySourceKey: tracking,
      openReceivables: openReceivables,
      authorizations: authorizations,
      billingGuides: billingGuides,
      billingBatches: billingBatches,
      billingGlosas: billingGlosas,
      patientInsurances: patientInsurances,
      inventoryItems: inventoryItems,
      inventoryLots: inventoryLots,
      inventoryCounts: inventoryCounts,
    ),
  );

  final user = ref.read(currentUserProvider);
  final ClinicMembership? membership =
      ref.read(activeClinicMembershipProvider);
  return PendingAccess.filterVisible(
    items: built,
    user: user,
    clinicMembership: membership,
  );
});

final Provider<PendingAttentionCounts> pendingAttentionCountsProvider =
    Provider<PendingAttentionCounts>((Ref ref) {
  final AsyncValue<List<PendingItem>> async =
      ref.watch(professionalPendingItemsProvider);
  return async.maybeWhen(
    data: PendingAggregator.attentionCounts,
    orElse: () => const PendingAttentionCounts(
      vaccineOverdue: 0,
      unreadMessages: 0,
      returnsAndDrafts: 0,
      examsPending: 0,
    ),
  );
});

final FutureProviderFamily<List<PendingItem>, String>
    patientPendingItemsProvider =
    FutureProvider.family<List<PendingItem>, String>((Ref ref, String id) async {
  final List<PendingItem> all =
      await ref.watch(professionalPendingItemsProvider.future);
  return PendingAggregator.forPatient(all, id);
});

final FutureProviderFamily<PendingItem?, String>
    patientRecommendedActionProvider =
    FutureProvider.family<PendingItem?, String>((Ref ref, String id) async {
  final List<PendingItem> patientItems =
      await ref.watch(patientPendingItemsProvider(id).future);
  return PendingAggregator.recommendedNextAction(
    patientItems,
    DateTime.now(),
  );
});
