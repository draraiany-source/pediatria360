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
  called,
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
        ClinicWorkflowStatus.waitingDoctor => 'Aguardando médico',
        ClinicWorkflowStatus.called => 'Chamado',
        ClinicWorkflowStatus.inService => 'Em atendimento',
        ClinicWorkflowStatus.finished => 'Finalizado',
        ClinicWorkflowStatus.noShow => 'Não compareceu',
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
        ClinicWorkflowStatus.called ||
        ClinicWorkflowStatus.inService =>
          true,
        _ => false,
      };

  /// Ordem na fila operacional (menor = mais cedo no fluxo).
  int get queueOrder => switch (this) {
        ClinicWorkflowStatus.arrived => 0,
        ClinicWorkflowStatus.triage => 1,
        ClinicWorkflowStatus.waitingDoctor => 2,
        ClinicWorkflowStatus.called => 3,
        ClinicWorkflowStatus.inService => 4,
        _ => 99,
      };

  static ClinicWorkflowStatus fromName(String? value) =>
      ClinicWorkflowStatus.values.firstWhere(
        (ClinicWorkflowStatus s) => s.name == value,
        orElse: () => ClinicWorkflowStatus.scheduled,
      );

  /// Preferência: workflowStatus do documento; senão status legado da agenda.
  static ClinicWorkflowStatus resolve({
    String? workflowStatus,
    String? appointmentStatus,
  }) {
    if (workflowStatus != null && workflowStatus.isNotEmpty) {
      return ClinicWorkflowStatus.fromName(workflowStatus);
    }
    return ClinicWorkflowStatus.fromAppointmentStatus(appointmentStatus);
  }

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
        ClinicWorkflowStatus.waitingDoctor ||
        ClinicWorkflowStatus.called =>
          'confirmed',
        ClinicWorkflowStatus.inService => 'inProgress',
        ClinicWorkflowStatus.finished => 'completed',
        ClinicWorkflowStatus.cancelled => 'cancelled',
        ClinicWorkflowStatus.noShow => 'noShow',
        ClinicWorkflowStatus.rescheduled => 'cancelled',
      };
}
