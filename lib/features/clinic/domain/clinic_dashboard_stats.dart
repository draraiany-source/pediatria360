/// KPIs do painel Consultorio 360.
class ClinicDashboardStats {
  const ClinicDashboardStats({
    required this.todayAppointments,
    required this.waiting,
    required this.inService,
    required this.finished,
    required this.pendingReturns,
    required this.pendingVaccines,
    required this.pendingExams,
    required this.pendingMessages,
    required this.newPatients,
    required this.billingTodayCents,
    required this.billingMonthCents,
    required this.noShowRate,
    required this.upcomingBirthdays,
    required this.clinicalAlerts,
    required this.adminPending,
  });

  factory ClinicDashboardStats.empty() => const ClinicDashboardStats(
        todayAppointments: 0,
        waiting: 0,
        inService: 0,
        finished: 0,
        pendingReturns: 0,
        pendingVaccines: 0,
        pendingExams: 0,
        pendingMessages: 0,
        newPatients: 0,
        billingTodayCents: 0,
        billingMonthCents: 0,
        noShowRate: 0,
        upcomingBirthdays: 0,
        clinicalAlerts: 0,
        adminPending: 0,
      );

  final int todayAppointments;
  final int waiting;
  final int inService;
  final int finished;
  final int pendingReturns;
  final int pendingVaccines;
  final int pendingExams;
  final int pendingMessages;
  final int newPatients;
  final int billingTodayCents;
  final int billingMonthCents;
  final double noShowRate;
  final int upcomingBirthdays;
  final int clinicalAlerts;
  final int adminPending;
}
