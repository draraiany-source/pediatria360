import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/result.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/billing_finance_integration.dart';
import '../domain/billing_models.dart';
import '../domain/billing_validation.dart';

class BillingRepository {
  BillingRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('insurance_plans');
  CollectionReference<Map<String, dynamic>> get _patientInsurances =>
      _firestore.collection('patient_insurances');
  CollectionReference<Map<String, dynamic>> get _authorizations =>
      _firestore.collection('insurance_authorizations');
  CollectionReference<Map<String, dynamic>> get _guides =>
      _firestore.collection('billing_guides');
  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection('billing_batches');
  CollectionReference<Map<String, dynamic>> get _glosas =>
      _firestore.collection('billing_glosas');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _firestore.collection('billing_audit_logs');

  Stream<List<InsurancePlan>> watchPlans(String ownerId) => _plans
      .where('ownerId', isEqualTo: ownerId)
      .limit(200)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(InsurancePlan.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<PatientInsurance>> watchPatientInsurances(String ownerId) =>
      _patientInsurances
          .where('ownerId', isEqualTo: ownerId)
          .limit(500)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(PatientInsurance.fromFirestore)
                .toList(growable: false),
          );

  Stream<List<PatientInsurance>> watchInsurancesForChild({
    required String ownerId,
    required String childId,
  }) =>
      watchPatientInsurances(ownerId).map(
        (List<PatientInsurance> list) => list
            .where((PatientInsurance p) => p.childId == childId)
            .toList(growable: false),
      );

  Stream<List<InsuranceAuthorization>> watchAuthorizations(String ownerId) =>
      _authorizations
          .where('ownerId', isEqualTo: ownerId)
          .limit(500)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(InsuranceAuthorization.fromFirestore)
                .toList(growable: false),
          );

  Stream<List<BillingGuide>> watchGuides(String ownerId) => _guides
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(BillingGuide.fromFirestore).toList(growable: false),
      );

  Stream<List<BillingBatch>> watchBatches(String ownerId) => _batches
      .where('ownerId', isEqualTo: ownerId)
      .limit(200)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(BillingBatch.fromFirestore).toList(growable: false),
      );

  Stream<List<BillingGlosa>> watchGlosas(String ownerId) => _glosas
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(BillingGlosa.fromFirestore).toList(growable: false),
      );

  Future<Result<void>> upsertPlan(InsurancePlan plan) =>
      guard(() async {
        await _plans.doc(plan.id).set(plan.toMap(), SetOptions(merge: true));
      });

  Future<Result<void>> upsertPatientInsurance(PatientInsurance row) =>
      guard(() async {
        await _patientInsurances
            .doc(row.id)
            .set(row.toMap(), SetOptions(merge: true));
      });

  Future<Result<void>> upsertAuthorization(InsuranceAuthorization auth) =>
      guard(() async {
        await _authorizations
            .doc(auth.id)
            .set(auth.toMap(), SetOptions(merge: true));
      });

  Future<Result<void>> upsertGuide(BillingGuide guide) =>
      guard(() async {
        await _guides.doc(guide.id).set(guide.toMap(), SetOptions(merge: true));
      });

  Future<Result<void>> upsertBatch(BillingBatch batch) =>
      guard(() async {
        await _batches.doc(batch.id).set(batch.toMap(), SetOptions(merge: true));
      });

  Future<Result<BillingBatch>> closeBatch({
    required BillingBatch batch,
    required List<BillingGuide> selectedGuides,
    required List<PatientInsurance> insurances,
    required List<InsuranceAuthorization> authorizations,
    required DateTime now,
    required String byUserId,
  }) =>
      guard(() async {
        final List<String> guideIds = <String>[];
        int total = 0;
        for (final BillingGuide g in selectedGuides) {
          PatientInsurance? ins;
          for (final PatientInsurance p in insurances) {
            if (p.childId == g.childId) {
              ins = p;
              break;
            }
          }
          InsuranceAuthorization? auth;
          if (g.authorizationId != null) {
            for (final InsuranceAuthorization a in authorizations) {
              if (a.id == g.authorizationId) {
                auth = a;
                break;
              }
            }
          }
          final List<BillingValidationIssue> issues = validateGuideForBatch(
            guide: g,
            now: now,
            patientInsurance: ins,
            authorization: auth,
          );
          if (issues.isNotEmpty) {
            throw StateError(
              'Guia ${g.id}: ${issues.first.message}',
            );
          }
          guideIds.add(g.id);
          total += g.amountCents;
          await _guides.doc(g.id).set(
            g
                .copyWith(
                  status: BillingGuideStatus.inBatch,
                  batchId: batch.id,
                )
                .toMap(),
            SetOptions(merge: true),
          );
        }

        final BillingBatch closed = batch.copyWith(
          guideIds: guideIds,
          guideCount: guideIds.length,
          totalCents: total,
          status: BillingBatchStatus.closed,
        );
        await _batches.doc(closed.id).set(closed.toMap(), SetOptions(merge: true));
        await _writeAudit(
          ownerId: batch.ownerId,
          action: BillingAuditAction.batchClosed,
          entityType: 'batch',
          entityId: batch.id,
          byUserId: byUserId,
        );
        return closed;
      });

  Future<Result<BillingBatch>> markSent({
    required BillingBatch batch,
    required String protocol,
    required String byUserId,
  }) =>
      guard(() async {
        final BillingBatch updated = batch.copyWith(
          status: BillingBatchStatus.sent,
          protocol: protocol,
          sentAt: DateTime.now(),
        );
        await _batches.doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
        await _writeAudit(
          ownerId: batch.ownerId,
          action: BillingAuditAction.batchSent,
          entityType: 'batch',
          entityId: batch.id,
          byUserId: byUserId,
          metadata: <String, dynamic>{'protocol': protocol},
        );
        return updated;
      });

  Future<Result<BillingBatch>> registerReturn({
    required BillingBatch batch,
    required BillingBatchStatus returnStatus,
    required String returnNotes,
    required String byUserId,
  }) =>
      guard(() async {
        final BillingBatch updated = batch.copyWith(
          status: returnStatus,
          returnAt: DateTime.now(),
          returnNotes: returnNotes,
        );
        await _batches.doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
        await _writeAudit(
          ownerId: batch.ownerId,
          action: BillingAuditAction.batchReturn,
          entityType: 'batch',
          entityId: batch.id,
          byUserId: byUserId,
        );
        return updated;
      });

  Future<Result<BillingGlosa>> createGlosa({
    required BillingGlosa glosa,
    required String byUserId,
    FinanceRepository? finance,
    FinanceReceivable? existingReceivable,
  }) =>
      guard(() async {
        await _glosas.doc(glosa.id).set(glosa.toMap());
        await _writeAudit(
          ownerId: glosa.ownerId,
          action: BillingAuditAction.glosaCreated,
          entityType: 'glosa',
          entityId: glosa.id,
          byUserId: byUserId,
        );
        if (finance != null &&
            existingReceivable != null &&
            glosa.guideId != null) {
          final FinanceReceivable adjusted =
              BillingFinanceIntegration.applyGlosaToReceivable(
            existing: existingReceivable,
            glosa: glosa,
            now: DateTime.now(),
          );
          await finance.upsertReceivable(adjusted);
        }
        if (glosa.guideId != null) {
          await _guides.doc(glosa.guideId!).set(
            <String, dynamic>{'status': BillingGuideStatus.glosed.name},
            SetOptions(merge: true),
          );
        }
        return glosa;
      });

  Future<Result<BillingGlosa>> updateAppeal({
    required BillingGlosa glosa,
    required BillingGlosaStatus status,
    required String byUserId,
    String? justification,
    List<String>? docsUrls,
    String? responseNotes,
  }) =>
      guard(() async {
        final BillingGlosa updated = glosa.copyWith(
          status: status,
          appealJustification: justification,
          appealDocsUrls: docsUrls,
          responseNotes: responseNotes,
        );
        await _glosas.doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
        await _writeAudit(
          ownerId: glosa.ownerId,
          action: BillingAuditAction.appealUpdated,
          entityType: 'glosa',
          entityId: glosa.id,
          byUserId: byUserId,
        );
        return updated;
      });

  Future<Result<void>> syncPaidBatchToFinance({
    required BillingBatch batch,
    required List<BillingGuide> allGuides,
    required List<BillingGlosa> allGlosas,
    required FinanceRepository finance,
    required String byUserId,
  }) =>
      guard(() async {
        if (batch.status != BillingBatchStatus.paid &&
            batch.status != BillingBatchStatus.withGlosa) {
          return;
        }
        final List<BillingGuide> inBatch = allGuides
            .where((BillingGuide g) => batch.guideIds.contains(g.id))
            .toList(growable: false);
        final List<BillingGlosa> batchGlosas = allGlosas
            .where((BillingGlosa g) => g.batchId == batch.id)
            .toList(growable: false);
        final DateTime now = DateTime.now();
        final List<FinanceReceivable> rows =
            BillingFinanceIntegration.receivablesForPaidBatch(
          batch: batch,
          guidesInBatch: inBatch,
          glosasForBatch: batchGlosas,
          now: now,
        );
        for (final FinanceReceivable r in rows) {
          await finance.upsertReceivable(r);
        }
        await _writeAudit(
          ownerId: batch.ownerId,
          action: BillingAuditAction.financeSync,
          entityType: 'batch',
          entityId: batch.id,
          byUserId: byUserId,
          metadata: <String, dynamic>{'receivables': rows.length},
        );
      });

  Future<void> _writeAudit({
    required String ownerId,
    required BillingAuditAction action,
    required String entityType,
    required String entityId,
    required String byUserId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _audit.doc();
    await ref.set(
      BillingAuditEntry(
        id: ref.id,
        ownerId: ownerId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        at: DateTime.now(),
        byUserId: byUserId,
        metadata: metadata,
      ).toMap(),
    );
  }
}
