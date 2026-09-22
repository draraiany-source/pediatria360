import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/bi/domain/bi_aggregators.dart';
import 'package:pediatria360/features/bi/domain/bi_models.dart';
import 'package:pediatria360/features/finance/domain/finance_aggregators.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';

void main() {
  final DateTime now = DateTime(2026, 3, 15, 10);

  FinancePeriod month = FinancePeriod.resolve(
    filter: FinancePeriodFilter.month,
    now: now,
  );

  test('compose zeros when inputs empty', () {
    final BiExecutiveSnapshot snap = BiAggregators.compose(
      appointments: const <Appointment>[],
      period: month,
      openPendings: 0,
    );
    expect(snap.agenda.totalInPeriod, 0);
    expect(snap.financeRevenueCents, isNull);
    expect(snap.clinical.openDrafts, 0);
    expect(snap.growth.assessmentCount, 0);
  });

  test('finance numbers pass through from FinanceDashboardKpis', () {
    final FinanceDashboardKpis finance = FinanceDashboardKpis.compute(
      receivables: const <FinanceReceivable>[],
      payables: const <FinancePayable>[],
      period: month,
      now: now,
    );
    final BiExecutiveSnapshot snap = BiAggregators.compose(
      finance: finance,
      appointments: const <Appointment>[],
      period: month,
      openPendings: 0,
    );
    expect(snap.financeRevenueCents, finance.revenueMonth);
    expect(snap.financeBalanceCents, finance.balance);
    expect(snap.financeDelinquencyRate, finance.delinquencyRate);
  });

  test('agenda attendance and no-show rates', () {
    final List<Appointment> appts = <Appointment>[
      Appointment(
        id: '1',
        patientId: 'p',
        professionalId: 'pro',
        professionalName: 'Dr',
        startsAt: DateTime(2026, 3, 10, 9),
        durationMinutes: 30,
        status: AppointmentStatus.completed,
        createdAt: now,
      ),
      Appointment(
        id: '2',
        patientId: 'p',
        professionalId: 'pro',
        professionalName: 'Dr',
        startsAt: DateTime(2026, 3, 11, 10),
        durationMinutes: 30,
        status: AppointmentStatus.noShow,
        createdAt: now,
      ),
    ];
    final BiAgendaStats stats = BiAggregators.fromAppointments(
      appointments: appts,
      period: month,
    );
    expect(stats.completed, 1);
    expect(stats.noShow, 1);
    expect(stats.attendanceRate, 0.5);
    expect(stats.peakHoursHistogram[9], 1);
    expect(stats.peakHoursHistogram[10], 1);
  });

  test('csv export includes card values', () {
    const BiKpiCardData card = BiKpiCardData(
      id: 'x',
      title: 'Receita',
      valueLabel: '0',
      rawValue: 0,
      category: BiKpiCategory.finance,
      unit: 'cents',
    );
    final String csv = BiAggregators.exportCsv(<BiKpiCardData>[card]);
    expect(csv, contains('id,titulo,valor,unidade,categoria'));
    expect(csv, contains('x,Receita,0,cents,finance'));
  });

  test('compose does not invent revenue without finance kpis', () {
    final BiExecutiveSnapshot snap = BiAggregators.compose(
      appointments: const <Appointment>[],
      period: month,
      openPendings: 0,
    );
    expect(snap.financeRevenueCents, isNull);
    expect(snap.financeBalanceCents, isNull);
  });
}
