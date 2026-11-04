import '../../telemedicine/data/telemedicine_repository.dart';
import 'finance_models.dart';

class FinanceDashboardKpis {
  const FinanceDashboardKpis({
    required this.revenueMonth,
    required this.expensesMonth,
    required this.balance,
    required this.ticketAvg,
    required this.accountsReceivable,
    required this.accountsPayable,
    required this.overdueAmount,
    required this.delinquencyRate,
    required this.productionByProfessional,
    required this.particularVsInsurance,
  });

  final int revenueMonth;
  final int expensesMonth;
  final int balance;
  final int ticketAvg;
  final int accountsReceivable;
  final int accountsPayable;
  final int overdueAmount;
  final double delinquencyRate;
  final Map<String, int> productionByProfessional;
  final Map<RevenueOrigin, int> particularVsInsurance;

  static FinanceDashboardKpis compute({
    required List<FinanceReceivable> receivables,
    required List<FinancePayable> payables,
    required FinancePeriod period,
    required DateTime now,
  }) {
    int revenueInPeriod = 0;
    int paidCount = 0;
    int arOpen = 0;
    int overdue = 0;
    int arTotalOpen = 0;
    final Map<String, int> byProf = <String, int>{};
    final Map<RevenueOrigin, int> byOrigin = <RevenueOrigin, int>{};

    for (final FinanceReceivable r in receivables) {
      final ReceivableStatus eff = r.effectiveStatus(now);
      if (eff.isOpen) {
        arOpen += r.openCents;
        arTotalOpen += r.totalCents;
        if (eff == ReceivableStatus.overdue) {
          overdue += r.openCents;
        }
      }
      if (period.contains(r.createdAt) || r.paidCents > 0) {
        if (period.contains(r.createdAt)) {
          revenueInPeriod += r.paidCents;
          if (r.paidCents > 0) paidCount += 1;
        }
      }
      final String profKey =
          r.professionalName ?? r.professionalId ?? 'Sem profissional';
      byProf[profKey] = (byProf[profKey] ?? 0) + r.paidCents;
      byOrigin[r.origin] = (byOrigin[r.origin] ?? 0) + r.paidCents;
    }

    int expensesInPeriod = 0;
    int apOpen = 0;
    for (final FinancePayable p in payables) {
      if (p.status != PayableStatus.cancelled) {
        apOpen += p.openCents;
      }
      if (period.contains(p.createdAt)) {
        expensesInPeriod += p.paidCents;
      }
    }

    final double delinquency = arTotalOpen > 0 ? overdue / arTotalOpen : 0.0;
    final int ticket = paidCount > 0 ? revenueInPeriod ~/ paidCount : 0;

    return FinanceDashboardKpis(
      revenueMonth: revenueInPeriod,
      expensesMonth: expensesInPeriod,
      balance: revenueInPeriod - expensesInPeriod,
      ticketAvg: ticket,
      accountsReceivable: arOpen,
      accountsPayable: apOpen,
      overdueAmount: overdue,
      delinquencyRate: delinquency,
      productionByProfessional: byProf,
      particularVsInsurance: byOrigin,
    );
  }
}

class CashFlowBucket {
  const CashFlowBucket({
    required this.label,
    required this.start,
    required this.inflows,
    required this.outflows,
    required this.periodBalance,
    required this.cumulative,
    required this.projection,
  });

  final String label;
  final DateTime start;
  final int inflows;
  final int outflows;
  final int periodBalance;
  final int cumulative;
  final int projection;
}

enum CashFlowGranularity { daily, weekly, monthly }

class CashFlowSeries {
  const CashFlowSeries({required this.buckets});

  final List<CashFlowBucket> buckets;

  static CashFlowSeries build({
    required List<FinanceReceivable> receivables,
    required List<FinancePayable> payables,
    required FinancePeriod period,
    CashFlowGranularity granularity = CashFlowGranularity.daily,
  }) {
    final List<DateTime> starts = _bucketStarts(period, granularity);
    int cumulative = 0;
    final List<CashFlowBucket> buckets = <CashFlowBucket>[];
    int totalIn = 0;
    int bucketCount = 0;

    for (int i = 0; i < starts.length; i++) {
      final DateTime start = starts[i];
      final DateTime end = i + 1 < starts.length
          ? starts[i + 1]
          : period.end;
      int inflows = 0;
      int outflows = 0;

      for (final FinanceReceivable r in receivables) {
        final DateTime paidAt = r.updatedAt ?? r.createdAt;
        if (!paidAt.isBefore(start) && paidAt.isBefore(end)) {
          inflows += r.paidCents;
        }
      }
      for (final FinancePayable p in payables) {
        final DateTime paidAt = p.updatedAt ?? p.createdAt;
        if (!paidAt.isBefore(start) && paidAt.isBefore(end)) {
          outflows += p.paidCents;
        }
      }

      final int bal = inflows - outflows;
      cumulative += bal;
      totalIn += inflows;
      bucketCount += 1;

      buckets.add(
        CashFlowBucket(
          label: _labelFor(start, granularity),
          start: start,
          inflows: inflows,
          outflows: outflows,
          periodBalance: bal,
          cumulative: cumulative,
          projection: 0,
        ),
      );
    }

    if (bucketCount > 0) {
      final int avgIn = totalIn ~/ bucketCount;
      final List<CashFlowBucket> withProjection = <CashFlowBucket>[];
      int projCum = cumulative;
      for (int i = 0; i < buckets.length; i++) {
        final CashFlowBucket b = buckets[i];
        if (i == buckets.length - 1) {
          projCum += avgIn;
          withProjection.add(
            CashFlowBucket(
              label: b.label,
              start: b.start,
              inflows: b.inflows,
              outflows: b.outflows,
              periodBalance: b.periodBalance,
              cumulative: b.cumulative,
              projection: projCum,
            ),
          );
        } else {
          withProjection.add(b);
        }
      }
      return CashFlowSeries(buckets: withProjection);
    }

    return CashFlowSeries(buckets: buckets);
  }
}

class DreReport {
  const DreReport({
    required this.grossRevenue,
    required this.deductions,
    required this.netRevenue,
    required this.costs,
    required this.expenses,
    required this.result,
  });

  final int grossRevenue;
  final int deductions;
  final int netRevenue;
  final int costs;
  final int expenses;
  final int result;

  static DreReport build({
    required List<FinanceReceivable> receivables,
    required List<FinancePayable> payables,
    required FinancePeriod period,
    RevenueOrigin? originFilter,
    String? professionalIdFilter,
  }) {
    int gross = 0;
    int deductions = 0;

    for (final FinanceReceivable r in receivables) {
      if (originFilter != null && r.origin != originFilter) continue;
      if (professionalIdFilter != null &&
          r.professionalId != professionalIdFilter) {
        continue;
      }
      if (period.contains(r.createdAt)) {
        gross += r.totalCents;
        if (r.status == ReceivableStatus.cancelled) {
          deductions += r.totalCents;
        } else {
          deductions += r.refundedCents;
        }
      }
    }

    int exp = 0;
    for (final FinancePayable p in payables) {
      if (period.contains(p.createdAt)) {
        exp += p.paidCents;
      }
    }

    final int net = gross - deductions;
    const int costs = 0;
    return DreReport(
      grossRevenue: gross,
      deductions: deductions,
      netRevenue: net,
      costs: costs,
      expenses: exp,
      result: net - costs - exp,
    );
  }
}

class ProductionReportRow {
  const ProductionReportRow({
    required this.professionalId,
    required this.professionalName,
    required this.consults,
    required this.returns,
    required this.teleconsults,
    required this.revenueCents,
    required this.ticketCents,
    required this.cancellations,
    required this.noShows,
  });

  final String professionalId;
  final String professionalName;
  final int consults;
  final int returns;
  final int teleconsults;
  final int revenueCents;
  final int ticketCents;
  final int cancellations;
  final int noShows;
}

class ProductionReport {
  const ProductionReport({required this.rows});

  final List<ProductionReportRow> rows;

  static ProductionReport fromAppointments({
    required List<Appointment> appointments,
    required FinancePeriod period,
  }) {
    final Map<String, _ProdAcc> acc = <String, _ProdAcc>{};

    for (final Appointment a in appointments) {
      if (!period.contains(a.startsAt)) continue;
      final String pid = a.professionalId;
      acc.putIfAbsent(pid, () => _ProdAcc(a.professionalName));
      final _ProdAcc row = acc[pid]!;

      if (a.status == AppointmentStatus.cancelled) {
        row.cancellations += 1;
        continue;
      }
      if (a.status == AppointmentStatus.noShow) {
        row.noShows += 1;
        continue;
      }
      if (a.status != AppointmentStatus.completed) continue;

      if (a.type == AppointmentType.teleconsulta) {
        row.teleconsults += 1;
      } else {
        final String reason = (a.reason ?? '').toLowerCase();
        if (reason.contains('retorno')) {
          row.returns += 1;
        } else {
          row.consults += 1;
        }
      }
      if (a.paid) {
        row.revenue += a.priceCents;
        row.paidCount += 1;
      }
    }

    return ProductionReport(
      rows: acc.entries
          .map(
            (MapEntry<String, _ProdAcc> e) => ProductionReportRow(
              professionalId: e.key,
              professionalName: e.value.name,
              consults: e.value.consults,
              returns: e.value.returns,
              teleconsults: e.value.teleconsults,
              revenueCents: e.value.revenue,
              ticketCents: e.value.paidCount > 0
                  ? e.value.revenue ~/ e.value.paidCount
                  : 0,
              cancellations: e.value.cancellations,
              noShows: e.value.noShows,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ProdAcc {
  _ProdAcc(this.name);

  final String name;
  int consults = 0;
  int returns = 0;
  int teleconsults = 0;
  int revenue = 0;
  int paidCount = 0;
  int cancellations = 0;
  int noShows = 0;
}

class OriginBreakdown {
  const OriginBreakdown({
    required this.origin,
    required this.valueCents,
    required this.count,
    required this.ticketCents,
    required this.percent,
  });

  final RevenueOrigin origin;
  final int valueCents;
  final int count;
  final int ticketCents;
  final double percent;

  static List<OriginBreakdown> fromReceivables(
    List<FinanceReceivable> receivables,
  ) {
    final Map<RevenueOrigin, _OriginAcc> acc = <RevenueOrigin, _OriginAcc>{};
    int total = 0;
    for (final FinanceReceivable r in receivables) {
      if (r.status == ReceivableStatus.cancelled) continue;
      total += r.paidCents;
      acc.putIfAbsent(r.origin, () => _OriginAcc());
      final _OriginAcc o = acc[r.origin]!;
      o.value += r.paidCents;
      if (r.paidCents > 0) o.count += 1;
    }
    return acc.entries
        .map(
          (MapEntry<RevenueOrigin, _OriginAcc> e) => OriginBreakdown(
            origin: e.key,
            valueCents: e.value.value,
            count: e.value.count,
            ticketCents:
                e.value.count > 0 ? e.value.value ~/ e.value.count : 0,
            percent: total > 0 ? e.value.value / total : 0.0,
          ),
        )
        .toList(growable: false);
  }
}

class _OriginAcc {
  int value = 0;
  int count = 0;
}

List<DateTime> _bucketStarts(FinancePeriod period, CashFlowGranularity g) {
  final List<DateTime> out = <DateTime>[];
  DateTime cursor = period.start;
  while (cursor.isBefore(period.end)) {
    out.add(cursor);
    switch (g) {
      case CashFlowGranularity.daily:
        cursor = cursor.add(const Duration(days: 1));
      case CashFlowGranularity.weekly:
        cursor = cursor.add(const Duration(days: 7));
      case CashFlowGranularity.monthly:
        cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }
  if (out.isEmpty) out.add(period.start);
  return out;
}

String _labelFor(DateTime start, CashFlowGranularity g) {
  return switch (g) {
    CashFlowGranularity.daily =>
      '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}',
    CashFlowGranularity.weekly => 'S${start.day}/${start.month}',
    CashFlowGranularity.monthly => '${start.month}/${start.year}',
  };
}
