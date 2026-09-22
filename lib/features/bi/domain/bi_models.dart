import '../../finance/domain/finance_models.dart';

export '../../finance/domain/finance_models.dart'
    show FinancePeriod, FinancePeriodFilter;

/// Filtro de periodo BI — mesmo enum/resolucao do financeiro.
typedef BiPeriodFilter = FinancePeriodFilter;

/// Intervalo de datas BI.
class BiPeriod {
  BiPeriod._();

  static FinancePeriod resolve({
    required BiPeriodFilter filter,
    required DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
  }) =>
      FinancePeriod.resolve(
        filter: filter,
        now: now,
        customStart: customStart,
        customEnd: customEnd,
      );
}

enum BiKpiCategory {
  finance,
  billing,
  inventory,
  clinical,
  agenda,
  reception,
  ops,
  growth,
  development,
  other,
}

/// Cartao KPI executivo (valor + drill-down opcional).
class BiKpiCardData {
  const BiKpiCardData({
    required this.id,
    required this.title,
    required this.valueLabel,
    required this.rawValue,
    required this.category,
    this.unit,
    this.drillRoute,
    this.drillQuery,
  });

  final String id;
  final String title;
  final String valueLabel;
  final num rawValue;
  final String? unit;
  final String? drillRoute;
  final Map<String, String>? drillQuery;
  final BiKpiCategory category;
}

/// Painel neuropediatrico — modulo nao implementado (sem KPIs ficticios).
class BiNeuropedStub {
  const BiNeuropedStub();

  static const String message =
      'Modulo neuropediatrico ainda nao implementado nesta fase. '
      'Nenhum indicador automatico e exibido aqui.';
}

class BiAgendaStats {
  const BiAgendaStats({
    required this.totalInPeriod,
    required this.completed,
    required this.noShow,
    required this.cancelled,
    required this.rescheduled,
    required this.attendanceRate,
    required this.occupancyRate,
    required this.peakHoursHistogram,
    this.rescheduleNote,
  });

  factory BiAgendaStats.empty({String? rescheduleNote}) => BiAgendaStats(
        totalInPeriod: 0,
        completed: 0,
        noShow: 0,
        cancelled: 0,
        rescheduled: 0,
        attendanceRate: 0,
        occupancyRate: 0,
        peakHoursHistogram: const <int, int>{},
        rescheduleNote: rescheduleNote,
      );

  final int totalInPeriod;
  final int completed;
  final int noShow;
  final int cancelled;
  final int rescheduled;
  final double attendanceRate;
  final double occupancyRate;
  final Map<int, int> peakHoursHistogram;
  final String? rescheduleNote;
}

class BiReceptionStats {
  const BiReceptionStats({
    required this.waitingNow,
    required this.inTriage,
    required this.avgWaitMinutes,
    required this.delayedArrivals,
    required this.arrivedToday,
  });

  factory BiReceptionStats.empty() => const BiReceptionStats(
        waitingNow: 0,
        inTriage: 0,
        avgWaitMinutes: 0,
        delayedArrivals: 0,
        arrivedToday: 0,
      );

  final int waitingNow;
  final int inTriage;
  final double avgWaitMinutes;
  final int delayedArrivals;
  final int arrivedToday;
}

class BiAssistentialStats {
  const BiAssistentialStats({
    required this.byEncounterType,
    required this.signedEncounters,
    required this.draftEncounters,
    required this.returnsOverdue,
  });

  factory BiAssistentialStats.empty() => const BiAssistentialStats(
        byEncounterType: <String, int>{},
        signedEncounters: 0,
        draftEncounters: 0,
        returnsOverdue: 0,
      );

  final Map<String, int> byEncounterType;
  final int signedEncounters;
  final int draftEncounters;
  final int returnsOverdue;
}

class BiClinicalLite {
  const BiClinicalLite({
    required this.openDrafts,
    required this.pendingExams,
    required this.vaccinesOverdue,
    required this.openPendingsTotal,
  });

  factory BiClinicalLite.empty() => const BiClinicalLite(
        openDrafts: 0,
        pendingExams: 0,
        vaccinesOverdue: 0,
        openPendingsTotal: 0,
      );

  final int openDrafts;
  final int pendingExams;
  final int vaccinesOverdue;
  final int openPendingsTotal;

  static const String disclaimer =
      'Indicadores operacionais apenas. Nao substituem julgamento clinico '
      'nem geram diagnostico automatico.';
}

class BiGrowthCohort {
  const BiGrowthCohort({
    required this.assessmentCount,
    required this.byClassification,
    required this.distinctChildren,
  });

  factory BiGrowthCohort.empty() => const BiGrowthCohort(
        assessmentCount: 0,
        byClassification: <String, int>{},
        distinctChildren: 0,
      );

  final int assessmentCount;
  final Map<String, int> byClassification;
  final int distinctChildren;

  static const String disclaimer =
      'Agregacao descritiva de curvas ja calculadas. Sem diagnostico '
      'automatico; dados clinicos amplos dependem de exportacao dedicada.';
}

class BiDevelopmentCohort {
  const BiDevelopmentCohort({
    required this.recordCount,
    required this.motor,
    required this.language,
    required this.social,
    required this.cognitive,
    required this.needsFollowUp,
  });

  factory BiDevelopmentCohort.empty() => const BiDevelopmentCohort(
        recordCount: 0,
        motor: 0,
        language: 0,
        social: 0,
        cognitive: 0,
        needsFollowUp: 0,
      );

  final int recordCount;
  final int motor;
  final int language;
  final int social;
  final int cognitive;
  final int needsFollowUp;

  static const String disclaimer =
      'Contagens de marcos registrados pelo profissional. Nao constitui '
      'triagem automatica de atraso global.';
}

/// Snapshot executivo composto a partir de agregadores existentes.
class BiExecutiveSnapshot {
  const BiExecutiveSnapshot({
    required this.agenda,
    required this.reception,
    required this.assistential,
    required this.clinical,
    required this.growth,
    required this.development,
    required this.neuroped,
    this.todayAppointments,
    this.financeRevenueCents,
    this.financeBalanceCents,
    this.financeDelinquencyRate,
    this.financeOverdueCents,
    this.billingGlosaRate,
    this.billingPendingCents,
    this.inventoryBelowMin,
    this.inventoryExpiredLots,
    this.pendingVaccines,
    this.pendingExams,
    this.pendingReturnsDrafts,
  });

  factory BiExecutiveSnapshot.empty() => BiExecutiveSnapshot(
        agenda: BiAgendaStats.empty(),
        reception: BiReceptionStats.empty(),
        assistential: BiAssistentialStats.empty(),
        clinical: BiClinicalLite.empty(),
        growth: BiGrowthCohort.empty(),
        development: BiDevelopmentCohort.empty(),
        neuroped: const BiNeuropedStub(),
      );

  final BiAgendaStats agenda;
  final BiReceptionStats reception;
  final BiAssistentialStats assistential;
  final BiClinicalLite clinical;
  final BiGrowthCohort growth;
  final BiDevelopmentCohort development;
  final BiNeuropedStub neuroped;

  final int? todayAppointments;
  final int? financeRevenueCents;
  final int? financeBalanceCents;
  final double? financeDelinquencyRate;
  final int? financeOverdueCents;
  final double? billingGlosaRate;
  final int? billingPendingCents;
  final int? inventoryBelowMin;
  final int? inventoryExpiredLots;
  final int? pendingVaccines;
  final int? pendingExams;
  final int? pendingReturnsDrafts;
}
