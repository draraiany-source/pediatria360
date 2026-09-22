import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/billing/domain/billing_aggregators.dart';
import 'package:pediatria360/features/billing/domain/billing_models.dart';

void main() {
  test('KPIs compute billed month and glosa rate', () {
    final DateTime now = DateTime(2026, 6, 15);
    final BillingDashboardKpis kpis = BillingDashboardKpisComputer.compute(
      now: now,
      guides: <BillingGuide>[
        BillingGuide(
          id: 'g1',
          ownerId: 'o',
          type: BillingGuideType.consultation,
          childId: 'c',
          serviceDate: DateTime(2026, 6, 10),
          amountCents: 10000,
          planId: 'p1',
          status: BillingGuideStatus.sent,
        ),
      ],
      batches: <BillingBatch>[
        BillingBatch(
          id: 'b1',
          ownerId: 'o',
          periodStart: DateTime(2026, 6, 1),
          periodEnd: DateTime(2026, 6, 30),
          totalCents: 10000,
          status: BillingBatchStatus.paid,
          sentAt: DateTime(2026, 6, 5),
          returnAt: DateTime(2026, 6, 20),
        ),
      ],
      glosas: <BillingGlosa>[
        BillingGlosa(
          id: 'gl1',
          ownerId: 'o',
          childId: 'c',
          billedCents: 10000,
          glosedCents: 1000,
          glosaDate: DateTime(2026, 6, 21),
          planId: 'p1',
        ),
      ],
      planLabels: <String, String>{'p1': 'Unimed'},
    );
    expect(kpis.billedMonth, 10000);
    expect(kpis.received, 10000);
    expect(kpis.glosed, 1000);
    expect(kpis.glosaRate, closeTo(0.1, 0.001));
    expect(kpis.avgDaysToReceive, closeTo(15.0, 0.1));
  });
}
