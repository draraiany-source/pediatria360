import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../core/config/dev_mode.dart';

import '../../../../core/providers/core_providers.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'

    show activeClinicMembershipProvider;

import '../../data/billing_repository.dart';

import '../../domain/billing_access.dart';

import '../../domain/billing_aggregators.dart';

import '../../domain/billing_models.dart';



final Provider<BillingRepository> billingRepositoryProvider =

    Provider<BillingRepository>(

  (Ref ref) => BillingRepository(firestore: ref.watch(firestoreProvider)),

);



Stream<List<T>> _empty<T>() => Stream<List<T>>.value(<T>[]);



final StreamProvider<List<InsurancePlan>> billingPlansProvider =

    StreamProvider<List<InsurancePlan>>((Ref ref) {

  if (DevMode.isEnabled &&

      ref.watch(firebaseAuthProvider).currentUser == null) {

    return _empty<InsurancePlan>();

  }

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<InsurancePlan>();

  return ref.watch(billingRepositoryProvider).watchPlans(uid);

});



final StreamProvider<List<PatientInsurance>> billingPatientInsurancesProvider =

    StreamProvider<List<PatientInsurance>>((Ref ref) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<PatientInsurance>();

  return ref.watch(billingRepositoryProvider).watchPatientInsurances(uid);

});



final StreamProviderFamily<List<PatientInsurance>, String>

    childBillingInsuranceProvider =

    StreamProvider.family<List<PatientInsurance>, String>((Ref ref, String childId) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<PatientInsurance>();

  return ref

      .watch(billingRepositoryProvider)

      .watchInsurancesForChild(ownerId: uid, childId: childId);

});



final StreamProvider<List<InsuranceAuthorization>>

    billingAuthorizationsProvider =

    StreamProvider<List<InsuranceAuthorization>>((Ref ref) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<InsuranceAuthorization>();

  return ref.watch(billingRepositoryProvider).watchAuthorizations(uid);

});



final StreamProvider<List<BillingGuide>> billingGuidesProvider =

    StreamProvider<List<BillingGuide>>((Ref ref) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<BillingGuide>();

  return ref.watch(billingRepositoryProvider).watchGuides(uid);

});



final StreamProvider<List<BillingBatch>> billingBatchesProvider =

    StreamProvider<List<BillingBatch>>((Ref ref) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<BillingBatch>();

  return ref.watch(billingRepositoryProvider).watchBatches(uid);

});



final StreamProvider<List<BillingGlosa>> billingGlosasProvider =

    StreamProvider<List<BillingGlosa>>((Ref ref) {

  final String? uid = ref.watch(currentUserProvider)?.uid;

  if (uid == null) return _empty<BillingGlosa>();

  return ref.watch(billingRepositoryProvider).watchGlosas(uid);

});



final Provider<BillingDashboardKpis> billingDashboardKpisProvider =

    Provider<BillingDashboardKpis>((Ref ref) {

  final List<BillingGuide> guides =

      ref.watch(billingGuidesProvider).valueOrNull ?? const <BillingGuide>[];

  final List<BillingBatch> batches =

      ref.watch(billingBatchesProvider).valueOrNull ?? const <BillingBatch>[];

  final List<BillingGlosa> glosas =

      ref.watch(billingGlosasProvider).valueOrNull ?? const <BillingGlosa>[];

  final List<InsurancePlan> plans =

      ref.watch(billingPlansProvider).valueOrNull ?? const <InsurancePlan>[];

  final Map<String, String> labels = <String, String>{

    for (final InsurancePlan p in plans) p.id: '${p.operatorName} ${p.planName}',

  };

  return BillingDashboardKpisComputer.compute(

    now: DateTime.now(),

    guides: guides,

    batches: batches,

    glosas: glosas,

    planLabels: labels,

  );

});



final Provider<bool> billingModuleAllowedProvider = Provider<bool>((Ref ref) {

  return BillingAccess.canAccessModule(

    user: ref.watch(currentUserProvider),

    clinicMembership: ref.watch(activeClinicMembershipProvider),

  );

});

