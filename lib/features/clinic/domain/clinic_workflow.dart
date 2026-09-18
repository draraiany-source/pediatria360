/// Status operacional do fluxo de consultorio (recepcao -> alta).
///
/// Mais granular que AppointmentStatus da agenda: cobre chegada, triagem e
/// sala de espera antes do atendimento medico propriamente dito.
enum ClinicWorkflowStatus {
  scheduled,
  confirmed,
  arrived,
  triage,
  waitingDoctor,
  inService,
  finished,
  noShow,
  cancelled,
  rescheduled;

  String get label => switch (this) {
        ClinicWorkflowStatus.scheduled => 'Agendado',
        ClinicWorkflowStatus.confirmed => 'Confirmado',
        ClinicWorkflowStatus.arrived => 'Chegou',
        ClinicWorkflowStatus.triage => 'Em triagem',
        ClinicWorkflowStatus.waitingDoctor => 'Aguardando medico',
        ClinicWorkflowStatus.inService => 'Em atendimento',
        ClinicWorkflowStatus.finished => 'Finalizado',
        ClinicWorkflowStatus.noShow => 'Nao compareceu',
        ClinicWorkflowStatus.cancelled => 'Cancelado',
        ClinicWorkflowStatus.rescheduled => 'Remarcado',
      };

  /// Colunas tipicas da recepcao (fluxo ativo do dia).
  bool get isReceptionColumn => switch (this) {
        ClinicWorkflowStatus.scheduled ||
        ClinicWorkflowStatus.confirmed ||
        ClinicWorkflowStatus.arrived ||
        ClinicWorkflowStatus.triage ||
        ClinicWorkflowStatus.waitingDoctor ||
        ClinicWorkflowStatus.inService =>
          true,
        _ => false,
      };

  static ClinicWorkflowStatus fromName(String? value) =>
      ClinicWorkflowStatus.values.firstWhere(
        (ClinicWorkflowStatus s) => s.name == value,
        orElse: () => ClinicWorkflowStatus.scheduled,
      );

  /// Mapeia o status legado da agenda (AppointmentStatus) para o fluxo
  /// de consultorio. Status intermediarios (chegada/triagem) so existem no
  /// campo workflowStatus do agendamento.
  static ClinicWorkflowStatus fromAppointmentStatus(String? status) {
    return switch (status) {
      'requested' => ClinicWorkflowStatus.scheduled,
      'confirmed' => ClinicWorkflowStatus.confirmed,
      'inProgress' => ClinicWorkflowStatus.inService,
      'completed' => ClinicWorkflowStatus.finished,
      'cancelled' => ClinicWorkflowStatus.cancelled,
      'noShow' => ClinicWorkflowStatus.noShow,
      _ => ClinicWorkflowStatus.fromName(status),
    };
  }

  /// Status de agenda correspondente, quando o fluxo precisa refletir na
  /// colecao appointments.status (compatibilidade com telas existentes).
  String? toAppointmentStatusName() => switch (this) {
        ClinicWorkflowStatus.scheduled => 'requested',
        ClinicWorkflowStatus.confirmed ||
        ClinicWorkflowStatus.arrived ||
        ClinicWorkflowStatus.triage ||
        ClinicWorkflowStatus.waitingDoctor =>
          'confirmed',
        ClinicWorkflowStatus.inService => 'inProgress',
        ClinicWorkflowStatus.finished => 'completed',
        ClinicWorkflowStatus.cancelled => 'cancelled',
        ClinicWorkflowStatus.noShow => 'noShow',
        ClinicWorkflowStatus.rescheduled => 'cancelled',
      };
}
