import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../security/domain/tenant_scope.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../domain/finance_models.dart';

class FinanceRepository {
  FinanceRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Map<String, dynamic> _ledgerPayload(
    Map<String, dynamic> data, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      TenantScope.stampLedgerMap(
        Map<String, dynamic>.from(data),
        membership: membership,
        unitId: unitId,
      );

  CollectionReference<Map<String, dynamic>> get _receivables =>
      _firestore.collection('finance_receivables');

  CollectionReference<Map<String, dynamic>> get _payables =>
      _firestore.collection('finance_payables');

  CollectionReference<Map<String, dynamic>> get _receipts =>
      _firestore.collection('finance_receipts');

  CollectionReference<Map<String, dynamic>> get _audit =>
      _firestore.collection('finance_audit_logs');

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  Stream<List<FinanceReceivable>> watchReceivables(String ownerId) => _receivables
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(FinanceReceivable.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<FinancePayable>> watchPayables(String ownerId) => _payables
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) =>
            snap.docs.map(FinancePayable.fromFirestore).toList(growable: false),
      );

  Stream<List<FinanceReceipt>> watchReceipts(String ownerId) => _receipts
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) =>
            snap.docs.map(FinanceReceipt.fromFirestore).toList(growable: false),
      );

  Stream<List<FinanceReceivable>> watchReceivablesForPatient({
    required String ownerId,
    required String childId,
  }) =>
      watchReceivables(ownerId).map(
        (List<FinanceReceivable> list) => list
            .where(
              (FinanceReceivable r) =>
                  r.childId == childId || r.patientId == childId,
            )
            .toList(growable: false),
      );

  Future<Result<void>> upsertReceivable(
    FinanceReceivable receivable, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        await _receivables.doc(receivable.id).set(
              _ledgerPayload(
                receivable.toMap(),
                membership: membership,
                unitId: unitId,
              ),
              SetOptions(merge: true),
            );
      });

  Future<Result<FinanceReceivable>> registerPayment({
    required FinanceReceivable receivable,
    required int amountCents,
    required PaymentMethodKind method,
    required String byUserId,
    bool issueReceipt = true,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final DateTime now = DateTime.now();
        final int newPaid = receivable.paidCents + amountCents;
        ReceivableStatus newStatus = receivable.status;
        if (newPaid >= receivable.totalCents - receivable.refundedCents) {
          newStatus = ReceivableStatus.paid;
        } else if (newPaid > 0) {
          newStatus = ReceivableStatus.partial;
        }

        final FinanceReceivable updated = receivable.copyWith(
          paidCents: newPaid,
          status: newStatus,
          updatedAt: now,
        );
        await _receivables.doc(updated.id).set(
              _ledgerPayload(
                updated.toMap(),
                membership: membership,
                unitId: unitId ?? receivable.unitId,
              ),
              SetOptions(merge: true),
            );

        if (issueReceipt) {
          await issueReceiptRecord(
            ownerId: receivable.ownerId,
            receivableId: receivable.id,
            patientId: receivable.childId ?? receivable.patientId,
            amountCents: amountCents,
            method: method,
            byUserId: byUserId,
            membership: membership,
            unitId: unitId ?? receivable.unitId,
          );
        }

        await writeAudit(
          ownerId: receivable.ownerId,
          action: FinanceAuditAction.paymentRegistered,
          entityType: 'receivable',
          entityId: receivable.id,
          byUserId: byUserId,
          membership: membership,
          unitId: unitId ?? receivable.unitId,
          metadata: <String, dynamic>{
            'amountCents': amountCents,
            'method': method.name,
          },
        );

        if (newStatus == ReceivableStatus.paid &&
            receivable.appointmentId != null &&
            receivable.appointmentId!.isNotEmpty) {
          await _appointments.doc(receivable.appointmentId!).set(
            <String, dynamic>{'paid': true},
            SetOptions(merge: true),
          );
        }

        return updated;
      });

  Future<Result<void>> cancelReceivable({
    required FinanceReceivable receivable,
    required String byUserId,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final FinanceReceivable updated = receivable.copyWith(
          status: ReceivableStatus.cancelled,
          cancelledAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _receivables.doc(updated.id).set(
              _ledgerPayload(
                updated.toMap(),
                membership: membership,
                unitId: unitId ?? receivable.unitId,
              ),
              SetOptions(merge: true),
            );
        await writeAudit(
          ownerId: receivable.ownerId,
          action: FinanceAuditAction.receivableCancelled,
          entityType: 'receivable',
          entityId: receivable.id,
          byUserId: byUserId,
          membership: membership,
          unitId: unitId ?? receivable.unitId,
        );
      });

  Future<Result<void>> refundReceivable({
    required FinanceReceivable receivable,
    required int refundCents,
    required String byUserId,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final FinanceReceivable updated = receivable.copyWith(
          refundedCents: receivable.refundedCents + refundCents,
          status: ReceivableStatus.refunded,
          updatedAt: DateTime.now(),
        );
        await _receivables.doc(updated.id).set(
              _ledgerPayload(
                updated.toMap(),
                membership: membership,
                unitId: unitId ?? receivable.unitId,
              ),
              SetOptions(merge: true),
            );
        await writeAudit(
          ownerId: receivable.ownerId,
          action: FinanceAuditAction.receivableRefunded,
          entityType: 'receivable',
          entityId: receivable.id,
          byUserId: byUserId,
          membership: membership,
          unitId: unitId ?? receivable.unitId,
          metadata: <String, dynamic>{'refundCents': refundCents},
        );
      });

  Future<Result<void>> createPayable(
    FinancePayable payable, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        await _payables.doc(payable.id).set(
              _ledgerPayload(
                payable.toMap(),
                membership: membership,
                unitId: unitId ?? payable.unitId,
              ),
            );
        await writeAudit(
          ownerId: payable.ownerId,
          action: FinanceAuditAction.payableCreated,
          entityType: 'payable',
          entityId: payable.id,
          byUserId: payable.ownerId,
          membership: membership,
          unitId: unitId ?? payable.unitId,
        );
      });

  Future<Result<void>> markPayablePaid({
    required FinancePayable payable,
    required int amountCents,
    required String byUserId,
  }) =>
      guard(() async {
        final int paid = payable.paidCents + amountCents;
        PayableStatus st = PayableStatus.partial;
        if (paid >= payable.amountCents) st = PayableStatus.paid;
        await _payables.doc(payable.id).set(
          <String, dynamic>{
            'paidCents': paid,
            'status': st.name,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          },
          SetOptions(merge: true),
        );
        await writeAudit(
          ownerId: payable.ownerId,
          action: FinanceAuditAction.payablePaid,
          entityType: 'payable',
          entityId: payable.id,
          byUserId: byUserId,
        );
      });

  Future<Result<void>> markNegotiation({
    required FinancePayable payable,
    required String notes,
    required String byUserId,
  }) =>
      guard(() async {
        await _payables.doc(payable.id).set(
          <String, dynamic>{
            'status': PayableStatus.negotiation.name,
            'negotiationNotes': notes,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          },
          SetOptions(merge: true),
        );
        await writeAudit(
          ownerId: payable.ownerId,
          action: FinanceAuditAction.payableNegotiation,
          entityType: 'payable',
          entityId: payable.id,
          byUserId: byUserId,
        );
      });

  Future<Result<FinanceReceipt>> issueReceiptRecord({
    required String ownerId,
    required String receivableId,
    required int amountCents,
    required PaymentMethodKind method,
    required String byUserId,
    String? patientId,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final String id = _receipts.doc().id;
        final FinanceReceipt receipt = FinanceReceipt(
          id: id,
          ownerId: ownerId,
          receivableId: receivableId,
          amountCents: amountCents,
          method: method,
          issuedAt: DateTime.now(),
          patientId: patientId,
          receiptNumber: 'R-${DateTime.now().millisecondsSinceEpoch}',
          clinicId: membership?.clinicId,
          unitId: unitId,
        );
        await _receipts.doc(id).set(
              _ledgerPayload(
                receipt.toMap(),
                membership: membership,
                unitId: unitId,
              ),
            );
        await writeAudit(
          ownerId: ownerId,
          action: FinanceAuditAction.receiptIssued,
          entityType: 'receipt',
          entityId: id,
          byUserId: byUserId,
          membership: membership,
          unitId: unitId,
        );
        return receipt;
      });

  Future<Result<void>> writeAudit({
    required String ownerId,
    required FinanceAuditAction action,
    required String entityType,
    required String entityId,
    required String byUserId,
    Map<String, dynamic>? metadata,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final String id = _audit.doc().id;
        final FinanceAuditEntry entry = FinanceAuditEntry(
          id: id,
          ownerId: ownerId,
          action: action,
          entityType: entityType,
          entityId: entityId,
          at: DateTime.now(),
          byUserId: byUserId,
          metadata: metadata ?? const <String, dynamic>{},
          clinicId: membership?.clinicId,
          unitId: unitId,
        );
        await _audit.doc(id).set(
              _ledgerPayload(
                entry.toMap(),
                membership: membership,
                unitId: unitId,
              ),
            );
      });

  Future<Result<int>> syncFromAppointments({
    required String ownerId,
    required List<Appointment> appointments,
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        int upserted = 0;
        final DateTime now = DateTime.now();
        for (final Appointment a in appointments) {
          if (a.priceCents <= 0) continue;
          if (a.professionalId != ownerId && a.patientId.isEmpty) continue;
          final String docId = 'appt_${a.id}';
          RevenueOrigin origin = RevenueOrigin.private_;
          if (a.type == AppointmentType.teleconsulta) {
            origin = RevenueOrigin.teleconsult;
          }
          final FinanceReceivable recv = FinanceReceivable(
            id: docId,
            ownerId: ownerId,
            totalCents: a.priceCents,
            paidCents: a.paid ? a.priceCents : 0,
            status: a.paid
                ? ReceivableStatus.paid
                : ReceivableStatus.pending,
            dueAt: a.startsAt,
            createdAt: a.createdAt,
            patientId: a.patientId,
            childId: a.childId,
            appointmentId: a.id,
            description: a.reason ?? 'Consulta',
            origin: origin,
            professionalId: a.professionalId,
            professionalName: a.professionalName,
            updatedAt: now,
          );
          await _receivables.doc(docId).set(
                _ledgerPayload(
                  recv.toMap(),
                  membership: membership,
                  unitId: unitId,
                ),
                SetOptions(merge: true),
              );
          upserted += 1;
        }
        if (upserted > 0) {
          await writeAudit(
            ownerId: ownerId,
            action: FinanceAuditAction.syncFromAppointments,
            entityType: 'sync',
            entityId: 'agenda',
            byUserId: ownerId,
            membership: membership,
            unitId: unitId,
            metadata: <String, dynamic>{'count': upserted},
          );
        }
        return upserted;
      });
}
