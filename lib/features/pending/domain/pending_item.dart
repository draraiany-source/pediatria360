import 'package:equatable/equatable.dart';

/// Tipo operacional da pendencia (fonte de dados).
enum PendingKind {
  draftEncounter,
  returnNotScheduled,
  returnOverdue,
  vaccineOverdue,
  examPending,
  messageUnread,
  documentUnsigned,
  paymentPending,
  teleconsultPending,
  patientInactive,
  patientNew,
  activeFollowUp,
  adminAppointmentConfirm,
  automationIntegration,
  authExpiring,
  guideIncomplete,
  batchNotSent,
  batchReturnPending,
  glosaWithoutAppeal,
  appealDeadlineSoon,
  stockBelowMin,
  stockZero,
  lotNearExpiry,
  lotExpired,
  stockDivergence,
}

/// Area para filtros e RBAC.
enum PendingCategory {
  clinical,
  administrative,
  financial,
}

/// Status persistido ou padrao aberta.
enum PendingWorkflowStatus {
  open,
  inProgress,
  resolved,
  ignored;

  static PendingWorkflowStatus fromName(String? value) =>
      PendingWorkflowStatus.values.firstWhere(
        (PendingWorkflowStatus s) => s.name == value,
        orElse: () => PendingWorkflowStatus.open,
      );

  String get label => switch (this) {
        PendingWorkflowStatus.open => 'Aberta',
        PendingWorkflowStatus.inProgress => 'Em andamento',
        PendingWorkflowStatus.resolved => 'Resolvida',
        PendingWorkflowStatus.ignored => 'Ignorada',
      };
}

/// Segmentos do CRM clinico.
enum CrmSegment {
  noReturnScheduled,
  returnOverdue,
  vaccineOverdue,
  examPending,
  patientInactive,
  patientNew,
  activeFollowUp,
  teleconsultPending,
  paymentPending,
  documentPending,
  messageUnanswered,
}

extension CrmSegmentLabels on CrmSegment {
  String get label => switch (this) {
        CrmSegment.noReturnScheduled => 'Sem retorno agendado',
        CrmSegment.returnOverdue => 'Retorno atrasado',
        CrmSegment.vaccineOverdue => 'Vacina atrasada',
        CrmSegment.examPending => 'Exame pendente',
        CrmSegment.patientInactive => 'Paciente inativo',
        CrmSegment.patientNew => 'Paciente novo',
        CrmSegment.activeFollowUp => 'Acompanhamento ativo',
        CrmSegment.teleconsultPending => 'Teleconsulta pendente',
        CrmSegment.paymentPending => 'Pagamento pendente',
        CrmSegment.documentPending => 'Documento pendente',
        CrmSegment.messageUnanswered => 'Mensagem nao respondida',
      };

  bool matches(PendingItem item) => switch (this) {
        CrmSegment.noReturnScheduled =>
          item.kind == PendingKind.returnNotScheduled,
        CrmSegment.returnOverdue => item.kind == PendingKind.returnOverdue,
        CrmSegment.vaccineOverdue => item.kind == PendingKind.vaccineOverdue,
        CrmSegment.examPending => item.kind == PendingKind.examPending,
        CrmSegment.patientInactive => item.kind == PendingKind.patientInactive,
        CrmSegment.patientNew => item.kind == PendingKind.patientNew,
        CrmSegment.activeFollowUp => item.kind == PendingKind.activeFollowUp,
        CrmSegment.teleconsultPending =>
          item.kind == PendingKind.teleconsultPending,
        CrmSegment.paymentPending => item.kind == PendingKind.paymentPending,
        CrmSegment.documentPending =>
          item.kind == PendingKind.documentUnsigned,
        CrmSegment.messageUnanswered =>
          item.kind == PendingKind.messageUnread,
      };
}

/// Filtros da Central de Pendencias.
enum PendingCenterFilter {
  today,
  thisWeek,
  clinical,
  administrative,
  financial,
  urgent,
  resolved,
}

extension PendingCenterFilterLabels on PendingCenterFilter {
  String get label => switch (this) {
        PendingCenterFilter.today => 'Hoje',
        PendingCenterFilter.thisWeek => 'Esta semana',
        PendingCenterFilter.clinical => 'Clinico',
        PendingCenterFilter.administrative => 'Administrativo',
        PendingCenterFilter.financial => 'Financeiro',
        PendingCenterFilter.urgent => 'Urgente',
        PendingCenterFilter.resolved => 'Resolvido',
      };
}

/// Acao sugerida na UI (navegacao tratada na camada de apresentacao).
enum PendingActionKind {
  openPatient,
  openPatient360,
  scheduleReturn,
  rescheduleAppointment,
  openVaccines,
  registerVaccineDose,
  openLabResult,
  markExamReviewed,
  openSupplementLabs,
  replyMessage,
  openDocument,
  signDocument,
  downloadDocument,
  openAppointment,
  registerPayment,
  openEncounterDraft,
  openAgenda,
  openBilling,
  openInventory,
  none,
}

/// Estado de exibicao (inclui vencida calculada).
enum PendingDisplayStatus {
  open,
  inProgress,
  resolved,
  ignored,
  overdue,
}

class PendingItem extends Equatable {
  const PendingItem({
    required this.sourceKey,
    required this.kind,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.dueAt,
    this.patientId,
    this.childId,
    this.patientName,
    this.referenceId,
    this.urgent = false,
    this.workflowStatus = PendingWorkflowStatus.open,
    this.resolvedAt,
    this.resolvedBy,
    this.primaryAction = PendingActionKind.none,
    this.secondaryAction = PendingActionKind.none,
    this.crmSegments = const <CrmSegment>[],
  });

  final String sourceKey;
  final PendingKind kind;
  final PendingCategory category;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final DateTime? dueAt;
  final String? patientId;
  final String? childId;
  final String? patientName;
  final String? referenceId;
  final bool urgent;
  final PendingWorkflowStatus workflowStatus;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final PendingActionKind primaryAction;
  final PendingActionKind secondaryAction;
  final List<CrmSegment> crmSegments;

  PendingDisplayStatus displayStatus(DateTime now) {
    if (workflowStatus == PendingWorkflowStatus.resolved) {
      return PendingDisplayStatus.resolved;
    }
    if (workflowStatus == PendingWorkflowStatus.ignored) {
      return PendingDisplayStatus.ignored;
    }
    if (workflowStatus == PendingWorkflowStatus.inProgress) {
      return PendingDisplayStatus.inProgress;
    }
    if (dueAt != null && dueAt!.isBefore(now)) {
      return PendingDisplayStatus.overdue;
    }
    return PendingDisplayStatus.open;
  }

  bool get isActive =>
      workflowStatus != PendingWorkflowStatus.resolved &&
      workflowStatus != PendingWorkflowStatus.ignored;

  PendingItem copyWith({
    PendingWorkflowStatus? workflowStatus,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) =>
      PendingItem(
        sourceKey: sourceKey,
        kind: kind,
        category: category,
        title: title,
        subtitle: subtitle,
        createdAt: createdAt,
        dueAt: dueAt,
        patientId: patientId,
        childId: childId,
        patientName: patientName,
        referenceId: referenceId,
        urgent: urgent,
        workflowStatus: workflowStatus ?? this.workflowStatus,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        resolvedBy: resolvedBy ?? this.resolvedBy,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
        crmSegments: crmSegments,
      );

  @override
  List<Object?> get props =>
      <Object?>[sourceKey, kind, workflowStatus, dueAt, urgent];
}

/// Contagens para o bloco "Atencao necessaria" do dashboard.
class PendingAttentionCounts {
  const PendingAttentionCounts({
    required this.vaccineOverdue,
    required this.unreadMessages,
    required this.returnsAndDrafts,
    required this.examsPending,
  });

  final int vaccineOverdue;
  final int unreadMessages;
  final int returnsAndDrafts;
  final int examsPending;

  bool get allClear =>
      vaccineOverdue == 0 &&
      unreadMessages == 0 &&
      returnsAndDrafts == 0 &&
      examsPending == 0;
}
