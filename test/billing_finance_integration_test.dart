import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/billing/domain/billing_aggregators.dart';
import 'package:pediatria360/features/billing/domain/billing_finance_integration.dart';
import 'package:pediatria360/features/billing/domain/billing_models.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';

void main() {
  final DateTime now = DateTime(2026, 1, 1);

  test('paid batch uses guia_ receivable id', () {
    final BillingGuide guide = BillingGuide(
      id: 'guide-abc',
      ownerId: 'owner',
      type: BillingGuideType.consultation,
      childId: 'child',
      serviceDate: now,
      amountCents: 20000,
      planId: 'plan',
      professionalId: 'prof',
    );
    final List<FinanceReceivable> rows =
        BillingFinanceIntegration.receivablesForPaidBatch(
      batch: BillingBatch(
        id: 'batch1',
        ownerId: 'owner',
        periodStart: now,
        periodEnd: now,
        guideIds: <String>['guide-abc'],
        guideCount: 1,
        totalCents: 20000,
        status: BillingBatchStatus.paid,
      ),
      guidesInBatch: <BillingGuide>[guide],
      glosasForBatch: <BillingGlosa>[
        BillingGlosa(
          id: 'gl1',
          ownerId: 'owner',
          childId: 'child',
          guideId: 'guide-abc',
          batchId: 'batch1',
          billedCents: 20000,
          glosedCents: 5000,
          glosaDate: now,
        ),
      ],
      now: now,
    );
    expect(rows.single.id, billingReceivableIdForGuide('guide-abc'));
    expect(rows.single.paidCents, 15000);
    expect(rows.single.origin, RevenueOrigin.insurance);
    expect(rows.single.batchId, 'batch1');
    expect(rows.single.guideId, 'guide-abc');
  });

  test('glosa reduces paid and leaves open balance', () {
    final FinanceReceivable base = FinanceReceivable(
      id: 'guia_x',
      ownerId: 'o',
      totalCents: 10000,
      paidCents: 10000,
      status: ReceivableStatus.paid,
      dueAt: now,
      createdAt: now,
      origin: RevenueOrigin.insurance,
    );
    final FinanceReceivable adjusted =
        BillingFinanceIntegration.applyGlosaToReceivable(
      existing: base,
      glosa: BillingGlosa(
        id: 'g',
        ownerId: 'o',
        childId: 'c',
        billedCents: 10000,
        glosedCents: 3000,
        glosaDate: now,
      ),
      now: now,
    );
    expect(adjusted.paidCents, 7000);
    expect(adjusted.openCents, 3000);
  });
}
