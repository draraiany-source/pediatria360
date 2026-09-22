import '../../../shared/domain/entities/clinical_record.dart';
import '../../../shared/domain/entities/encounter.dart';
import '../../billing/domain/billing_models.dart';
import '../../clinic/domain/clinic_dashboard_stats.dart';
import '../../clinic/domain/clinic_workflow.dart';
import '../../clinic/domain/development_milestone.dart';
import '../../finance/domain/finance_aggregators.dart';
import '../../finance/domain/finance_models.dart';
import '../../growth/domain/who_reference.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../pending/domain/pending_item.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import 'bi_models.dart';

/// Agregadores puros BI — envolvem KPIs das fases anteriores.
class BiAggregators {
  BiAggregators._();

  static BiExecutiveSnapshot compose({
    ClinicDashboardStats? clinic,
    FinanceDashboardKpis? finance,
    BillingDashboardKpis? billing,
    InventoryDashboardKpis? inventory,
    PendingAttentionCounts? pendingAttention,
    required List<Appointment> appointments,
    required FinancePeriod period,
    required int openPendings,
    int? vaccineAppliedApprox,
    List<Encounter> encounters = const <Encounter>[],
    List<GrowthAssessment> growthAssessments = const <GrowthAssessment>[],
    List<DevelopmentMilestoneRecord> developmentRecords =
        const <DevelopmentMilestoneRecord>[],
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();
    final BiAgendaStats agenda = fromAppointments(
      appointments: appointments,
      period: period,
    );
    final BiReceptionStats reception = receptionFromAppointments(
      appointments: appointments,
      dayStart: DateTime(clock.year, clock.month, clock.day),
    );
    final int returnsHint = pendingAttention?.returnsAndDrafts ?? 0;
    final BiAssistentialStats assistential = assistentialFromEncounters(
      encounters: encounters,
      period: period,
      returnsOverdueHint: returnsHint,
    );
    final int vaccines =
        vaccineAppliedApprox ?? pendingAttention?.vaccineOverdue ?? 0;
    final BiClinicalLite clinical = BiClinicalLite(
      openDrafts: assistential.draftEncounters,
      pendingExams: pendingAttention?.examsPending ?? 0,
      vaccinesOverdue: vaccines,
      openPendingsTotal: openPendings,
    );

    return BiExecutiveSnapshot(
      agenda: agenda,
      reception: reception,
      assistential: assistential,
      clinical: clinical,
      growth: growthFromAssessments(growthAssessments),
      development: developmentFromRecords(developmentRecords),
      neuroped: const BiNeuropedStub(),
      todayAppointments: clinic?.todayAppointments,
      financeRevenueCents: finance?.revenueMonth,
      financeBalanceCents: finance?.balance,
      financeDelinquencyRate: finance?.delinquencyRate,
      financeOverdueCents: finance?.overdueAmount,
      billingGlosaRate: billing?.glosaRate,
      billingPendingCents: billing?.pending,
      inventoryBelowMin: inventory?.belowMin,
      inventoryExpiredLots: inventory?.expiredLots,
      pendingVaccines: pendingAttention?.vaccineOverdue,
      pendingExams: pendingAttention?.examsPending,
      pendingReturnsDrafts: pendingAttention?.returnsAndDrafts,
    );
  }

  static BiAgendaStats fromAppointments({
    required List<Appointment> appointments,
    required FinancePeriod period,
  }) {
    final Iterable<Appointment> inPeriod = appointments.where(
      (Appointment a) => period.contains(a.startsAt),
    );
    int completed = 0;
    int noShow = 0;
    int cancelled = 0;
    int rescheduled = 0;
    final Map<int, int> peaks = <int, int>{};

    for (final Appointment a in inPeriod) {
      peaks[a.startsAt.hour] = (peaks[a.startsAt.hour] ?? 0) + 1;
      final ClinicWorkflowStatus wf = ClinicWorkflowStatus.resolve(
        workflowStatus: a.workflowStatus,
        appointmentStatus: a.status.name,
      );
      if (wf == ClinicWorkflowStatus.rescheduled) {
        rescheduled += 1;
      }
      switch (a.status) {
        case AppointmentStatus.completed:
          completed += 1;
        case AppointmentStatus.noShow:
          noShow += 1;
        case AppointmentStatus.cancelled:
          cancelled += 1;
        case AppointmentStatus.requested:
        case AppointmentStatus.confirmed:
        case AppointmentStatus.inProgress:
          break;
      }
    }

    final int total = inPeriod.length;
    final int attendedDenom = completed + noShow;
    final double attendance =
        attendedDenom > 0 ? completed / attendedDenom : 0.0;
    final int occupancyDenom = completed + noShow + cancelled;
    final double occupancy =
        occupancyDenom > 0 ? completed / occupancyDenom : 0.0;

    return BiAgendaStats(
      totalInPeriod: total,
      completed: completed,
      noShow: noShow,
      cancelled: cancelled,
      rescheduled: rescheduled,
      attendanceRate: attendance,
      occupancyRate: occupancy,
      peakHoursHistogram: peaks,
      rescheduleNote: rescheduled == 0 && total > 0
          ? 'Remarcacoes so contam com workflowStatus rescheduled.'
          : null,
    );
  }

  static BiReceptionStats receptionFromAppointments({
    required List<Appointment> appointments,
    required DateTime dayStart,
  }) {
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    int waiting = 0;
    int triage = 0;
    int arrivedToday = 0;
    int delayed = 0;
    final List<int> waits = <int>[];

    for (final Appointment a in appointments) {
      if (a.startsAt.isBefore(dayStart) || !a.startsAt.isBefore(dayEnd)) {
        continue;
      }

      final ClinicWorkflowStatus wf = ClinicWorkflowStatus.resolve(
        workflowStatus: a.workflowStatus,
        appointmentStatus: a.status.name,
      );
      if (wf == ClinicWorkflowStatus.arrived ||
          wf == ClinicWorkflowStatus.waitingDoctor ||
          wf == ClinicWorkflowStatus.called) {
        waiting += 1;
      }
      if (wf == ClinicWorkflowStatus.triage) {
        triage += 1;
      }
      if (a.arrivedAt != null) {
        arrivedToday += 1;
        if (a.arrivedAt!.isAfter(a.startsAt.add(const Duration(minutes: 15)))) {
          delayed += 1;
        }
        if (a.status == AppointmentStatus.completed ||
            a.status == AppointmentStatus.inProgress ||
            wf == ClinicWorkflowStatus.inService ||
            wf == ClinicWorkflowStatus.finished) {
          final int wait = a.startsAt.isAfter(a.arrivedAt!)
              ? a.startsAt.difference(a.arrivedAt!).inMinutes
              : 0;
          if (wait >= 0) waits.add(wait);
        }
      }
    }

    final double avgWait = waits.isEmpty
        ? 0.0
        : waits.reduce((int a, int b) => a + b) / waits.length;

    return BiReceptionStats(
      waitingNow: waiting,
      inTriage: triage,
      avgWaitMinutes: avgWait,
      delayedArrivals: delayed,
      arrivedToday: arrivedToday,
    );
  }

  static BiAssistentialStats assistentialFromEncounters({
    required List<Encounter> encounters,
    required FinancePeriod period,
    int returnsOverdueHint = 0,
  }) {
    final Map<String, int> byType = <String, int>{};
    int signed = 0;
    int drafts = 0;

    for (final Encounter e in encounters) {
      if (!period.contains(e.startedAt)) continue;
      byType[e.type.name] = (byType[e.type.name] ?? 0) + 1;
      if (e.status == EncounterStatus.draft) {
        drafts += 1;
      } else if (e.status == EncounterStatus.signed) {
        signed += 1;
      }
    }

    return BiAssistentialStats(
      byEncounterType: byType,
      signedEncounters: signed,
      draftEncounters: drafts,
      returnsOverdue: returnsOverdueHint,
    );
  }

  static BiGrowthCohort growthFromAssessments(
    List<GrowthAssessment> assessments,
  ) {
    if (assessments.isEmpty) return BiGrowthCohort.empty();
    final Map<String, int> byClass = <String, int>{};
    for (final GrowthAssessment g in assessments) {
      final String key = g.classification.name;
      byClass[key] = (byClass[key] ?? 0) + 1;
    }
    return BiGrowthCohort(
      assessmentCount: assessments.length,
      byClassification: byClass,
      distinctChildren: 0,
    );
  }

  static BiDevelopmentCohort developmentFromRecords(
    List<DevelopmentMilestoneRecord> records,
  ) {
    if (records.isEmpty) return BiDevelopmentCohort.empty();
    int motor = 0;
    int language = 0;
    int social = 0;
    int cognitive = 0;
    int followUp = 0;

    for (final DevelopmentMilestoneRecord r in records) {
      switch (r.category) {
        case MilestoneCategory.grossMotor:
        case MilestoneCategory.fineMotor:
          motor += 1;
        case MilestoneCategory.language:
          language += 1;
        case MilestoneCategory.social:
          social += 1;
        case MilestoneCategory.cognitive:
          cognitive += 1;
      }
      if (r.status == MilestoneStatus.needsFollowUp) {
        followUp += 1;
      }
    }

    return BiDevelopmentCohort(
      recordCount: records.length,
      motor: motor,
      language: language,
      social: social,
      cognitive: cognitive,
      needsFollowUp: followUp,
    );
  }

  static List<BiKpiCardData> kpiCardsForSnapshot({
    required BiExecutiveSnapshot snapshot,
    required bool includeFinance,
    required bool includeBilling,
    required bool includeInventory,
    required bool includeClinical,
    required bool includeOps,
  }) {
    final List<BiKpiCardData> cards = <BiKpiCardData>[];

    if (includeOps) {
      cards.addAll(<BiKpiCardData>[
        BiKpiCardData(
          id: 'agenda_total',
          title: 'Consultas no periodo',
          valueLabel: '${snapshot.agenda.totalInPeriod}',
          rawValue: snapshot.agenda.totalInPeriod,
          category: BiKpiCategory.agenda,
          drillRoute: '/agenda',
        ),
        BiKpiCardData(
          id: 'agenda_attendance',
          title: 'Comparecimento',
          valueLabel:
              '${(snapshot.agenda.attendanceRate * 100).toStringAsFixed(0)}%',
          rawValue: snapshot.agenda.attendanceRate,
          unit: 'ratio',
          category: BiKpiCategory.agenda,
          drillRoute: '/agenda',
        ),
        BiKpiCardData(
          id: 'agenda_noshow',
          title: 'Faltas',
          valueLabel: '${snapshot.agenda.noShow}',
          rawValue: snapshot.agenda.noShow,
          category: BiKpiCategory.agenda,
          drillRoute: '/agenda',
        ),
      ]);
    }

    if (includeClinical) {
      cards.addAll(<BiKpiCardData>[
        BiKpiCardData(
          id: 'clinical_drafts',
          title: 'Rascunhos abertos',
          valueLabel: '${snapshot.clinical.openDrafts}',
          rawValue: snapshot.clinical.openDrafts,
          category: BiKpiCategory.clinical,
          drillRoute: '/consultorio/pendencias',
        ),
        BiKpiCardData(
          id: 'clinical_exams',
          title: 'Exames pendentes',
          valueLabel: '${snapshot.clinical.pendingExams}',
          rawValue: snapshot.clinical.pendingExams,
          category: BiKpiCategory.clinical,
          drillRoute: '/consultorio/pendencias',
        ),
        BiKpiCardData(
          id: 'clinical_vaccines',
          title: 'Vacinas em atraso',
          valueLabel: '${snapshot.clinical.vaccinesOverdue}',
          rawValue: snapshot.clinical.vaccinesOverdue,
          category: BiKpiCategory.clinical,
          drillRoute: '/consultorio/pendencias',
          drillQuery: const <String, String>{'focus': 'vaccines'},
        ),
        BiKpiCardData(
          id: 'clinical_pendings',
          title: 'Pendencias abertas',
          valueLabel: '${snapshot.clinical.openPendingsTotal}',
          rawValue: snapshot.clinical.openPendingsTotal,
          category: BiKpiCategory.clinical,
          drillRoute: '/consultorio/pendencias',
        ),
      ]);
    }

    if (includeFinance && snapshot.financeRevenueCents != null) {
      cards.addAll(<BiKpiCardData>[
        BiKpiCardData(
          id: 'finance_revenue',
          title: 'Receita (periodo)',
          valueLabel: '${snapshot.financeRevenueCents}',
          rawValue: snapshot.financeRevenueCents!,
          unit: 'cents',
          category: BiKpiCategory.finance,
          drillRoute: '/financeiro',
        ),
        BiKpiCardData(
          id: 'finance_balance',
          title: 'Saldo (periodo)',
          valueLabel: '${snapshot.financeBalanceCents ?? 0}',
          rawValue: snapshot.financeBalanceCents ?? 0,
          unit: 'cents',
          category: BiKpiCategory.finance,
          drillRoute: '/financeiro/fluxo',
        ),
        BiKpiCardData(
          id: 'finance_delinquency',
          title: 'Inadimplencia',
          valueLabel:
              '${((snapshot.financeDelinquencyRate ?? 0) * 100).toStringAsFixed(1)}%',
          rawValue: snapshot.financeDelinquencyRate ?? 0,
          unit: 'ratio',
          category: BiKpiCategory.finance,
          drillRoute: '/financeiro/inadimplencia',
        ),
      ]);
    }

    if (includeBilling && snapshot.billingGlosaRate != null) {
      cards.add(
        BiKpiCardData(
          id: 'billing_glosa',
          title: 'Taxa de glosa',
          valueLabel:
              '${((snapshot.billingGlosaRate ?? 0) * 100).toStringAsFixed(1)}%',
          rawValue: snapshot.billingGlosaRate ?? 0,
          unit: 'ratio',
          category: BiKpiCategory.billing,
          drillRoute: '/faturamento/glosas',
        ),
      );
      if (snapshot.billingPendingCents != null) {
        cards.add(
          BiKpiCardData(
            id: 'billing_pending',
            title: 'Faturamento pendente',
            valueLabel: '${snapshot.billingPendingCents}',
            rawValue: snapshot.billingPendingCents!,
            unit: 'cents',
            category: BiKpiCategory.billing,
            drillRoute: '/faturamento',
          ),
        );
      }
    }

    if (includeInventory && snapshot.inventoryBelowMin != null) {
      cards.add(
        BiKpiCardData(
          id: 'inventory_critical',
          title: 'Itens abaixo do minimo',
          valueLabel: '${snapshot.inventoryBelowMin}',
          rawValue: snapshot.inventoryBelowMin!,
          category: BiKpiCategory.inventory,
          drillRoute: '/estoque',
        ),
      );
    }

    if (includeOps && snapshot.reception.waitingNow > 0) {
      cards.add(
        BiKpiCardData(
          id: 'reception_waiting',
          title: 'Em espera agora',
          valueLabel: '${snapshot.reception.waitingNow}',
          rawValue: snapshot.reception.waitingNow,
          category: BiKpiCategory.reception,
          drillRoute: '/consultorio/recepcao',
        ),
      );
    }

    return cards;
  }

  static String exportCsv(List<BiKpiCardData> cards) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('id,titulo,valor,unidade,categoria');
    for (final BiKpiCardData c in cards) {
      final String title = c.title.replaceAll(',', ';');
      final String unit = c.unit ?? '';
      sb.writeln(
        '${c.id},$title,${c.valueLabel},$unit,${c.category.name}',
      );
    }
    return sb.toString();
  }
}
