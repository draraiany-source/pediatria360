import '../../finance/domain/finance_models.dart';
import 'billing_aggregators.dart';
import 'billing_models.dart';

/// Regras puras de sync faturamento para finance_receivables.
class BillingFinanceIntegration {
  BillingFinanceIntegration._();

  static FinanceReceivable receivableFromPaidGuide({
    required BillingGuide guide,
    required String batchId,
    required int glosedCents,
    required DateTime now,
  }) {
    final String recvId = billingReceivableIdForGuide(guide.id);
    final int paidCents = guide.amountCents - glosedCents;
    final int clampedPaid = paidCents < 0 ? 0 : paidCents;
    ReceivableStatus status = ReceivableStatus.pending;
    if (clampedPaid >= guide.amountCents) {
      status = ReceivableStatus.paid;
    } else if (clampedPaid > 0) {
      status = ReceivableStatus.partial;
    }

    return FinanceReceivable(
      id: recvId,
      ownerId: guide.ownerId,
      totalCents: guide.amountCents,
      paidCents: clampedPaid,
      status: status,
      dueAt: guide.serviceDate.add(const Duration(days: 30)),
      createdAt: now,
      childId: guide.childId,
      patientId: guide.patientId,
      appointmentId: guide.appointmentId,
      description: 'Convenio guia ${guide.id} lote:$batchId',
      origin: RevenueOrigin.insurance,
      professionalId: guide.professionalId,
      batchId: batchId,
      guideId: guide.id,
      planId: guide.planId,
      updatedAt: now,
    );
  }

  static List<FinanceReceivable> receivablesForPaidBatch({
    required BillingBatch batch,
    required List<BillingGuide> guidesInBatch,
    required List<BillingGlosa> glosasForBatch,
    required DateTime now,
  }) {
    final Map<String, int> glosedByGuide = <String, int>{};
    for (final BillingGlosa g in glosasForBatch) {
      if (g.guideId == null) continue;
      glosedByGuide[g.guideId!] =
          (glosedByGuide[g.guideId!] ?? 0) + g.glosedCents;
    }

    return guidesInBatch
        .map(
          (BillingGuide g) => receivableFromPaidGuide(
            guide: g,
            batchId: batch.id,
            glosedCents: glosedByGuide[g.id] ?? 0,
            now: now,
          ),
        )
        .toList(growable: false);
  }

  /// Ajusta recebivel apos glosa: reduz pago esperado; saldo em aberto = glosado.
  static FinanceReceivable applyGlosaToReceivable({
    required FinanceReceivable existing,
    required BillingGlosa glosa,
    required DateTime now,
  }) {
    final int newPaid = existing.paidCents - glosa.glosedCents;
    final int clampedPaid = newPaid < 0 ? 0 : newPaid;
    ReceivableStatus status;
    if (clampedPaid >= existing.totalCents - existing.refundedCents) {
      status = ReceivableStatus.paid;
    } else if (clampedPaid > 0) {
      status = ReceivableStatus.partial;
    } else {
      status = ReceivableStatus.pending;
    }

    return existing.copyWith(
      paidCents: clampedPaid,
      status: status,
      updatedAt: now,
    );
  }
}
