import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/finance/domain/finance_aggregators.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 15, 12);

  FinanceReceivable recv({
    required String id,
    int total = 10000,
    int paid = 0,
    DateTime? due,
    ReceivableStatus status = ReceivableStatus.pending,
    RevenueOrigin origin = RevenueOrigin.private_,
    String? appointmentId,
  }) =>
      FinanceReceivable(
        id: id,
        ownerId: 'o1',
        totalCents: total,
        paidCents: paid,
        status: status,
        dueAt: due ?? now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 10)),
        origin: origin,
        appointmentId: appointmentId,
      );

  group('FinanceDashboardKpis', () {
    test('computes balance and delinquency', () {
      final FinancePeriod period = FinancePeriod.resolve(
        filter: FinancePeriodFilter.month,
        now: now,
      );
      final FinanceDashboardKpis kpis = FinanceDashboardKpis.compute(
        receivables: <FinanceReceivable>[
          recv(id: 'r1', paid: 5000, total: 10000),
          recv(id: 'r2', due: now.subtract(const Duration(days: 2))),
        ],
        payables: const <FinancePayable>[],
        period: period,
        now: now,
      );
      expect(kpis.accountsReceivable, greaterThan(0));
      expect(kpis.overdueAmount, greaterThan(0));
      expect(kpis.delinquencyRate, greaterThan(0));
    });

    test('partial payment status via open cents', () {
      final FinanceReceivable r = recv(id: 'p', paid: 3000, total: 10000);
      expect(r.openCents, 7000);
      expect(r.effectiveStatus(now), ReceivableStatus.overdue);
    });
  });

  group('CashFlowSeries', () {
    test('builds buckets with cumulative', () {
      final FinancePeriod period = FinancePeriod.resolve(
        filter: FinancePeriodFilter.week,
        now: now,
      );
      final CashFlowSeries series = CashFlowSeries.build(
        receivables: <FinanceReceivable>[
          recv(
            id: 'c1',
            paid: 2000,
            total: 2000,
            status: ReceivableStatus.paid,
          ),
        ],
        payables: const <FinancePayable>[],
        period: period,
      );
      expect(series.buckets, isNotEmpty);
    });
  });

  group('DreReport', () {
    test('net revenue subtracts refunds', () {
      final FinancePeriod period = FinancePeriod.resolve(
        filter: FinancePeriodFilter.month,
        now: now,
      );
      final DreReport dre = DreReport.build(
        receivables: <FinanceReceivable>[
          recv(id: 'd1', total: 10000).copyWith(refundedCents: 1000),
        ],
        payables: const <FinancePayable>[],
        period: period,
      );
      expect(dre.grossRevenue, 10000);
      expect(dre.deductions, 1000);
      expect(dre.netRevenue, 9000);
    });
  });

  group('OriginBreakdown', () {
    test('splits particular vs insurance', () {
      final List<OriginBreakdown> rows = OriginBreakdown.fromReceivables(
        <FinanceReceivable>[
          recv(id: 'a', paid: 5000, total: 5000, status: ReceivableStatus.paid),
          recv(
            id: 'b',
            paid: 5000,
            total: 5000,
            status: ReceivableStatus.paid,
            origin: RevenueOrigin.insurance,
          ),
        ],
      );
      expect(rows.length, 2);
      expect(rows.first.percent, closeTo(0.5, 0.01));
    });
  });

  group('ProductionReport', () {
    test('counts consult types', () {
      final FinancePeriod period = FinancePeriod.resolve(
        filter: FinancePeriodFilter.month,
        now: now,
      );
      final ProductionReport report = ProductionReport.fromAppointments(
        appointments: <Appointment>[
          Appointment(
            id: 'a1',
            patientId: 'p1',
            professionalId: 'pro1',
            professionalName: 'Dr A',
            startsAt: now,
            durationMinutes: 30,
            status: AppointmentStatus.completed,
            createdAt: now,
            type: AppointmentType.presencial,
            priceCents: 15000,
            paid: true,
          ),
        ],
        period: period,
      );
      expect(report.rows.single.consults, 1);
      expect(report.rows.single.revenueCents, 15000);
    });
  });
}
