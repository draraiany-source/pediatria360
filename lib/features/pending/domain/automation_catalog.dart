/// Regras de automação preparadas — envio real depende de integração externa.
class AutomationRuleDefinition {
  const AutomationRuleDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.triggerKind,
    this.channel = AutomationChannel.none,
  });

  final String id;
  final String title;
  final String description;
  final String triggerKind;
  final AutomationChannel channel;

  String get integrationPendingLabel =>
      channel == AutomationChannel.none
          ? 'Pendência de integração (canal não configurado)'
          : 'Canal ${channel.label} — aguardando credenciais';
}

enum AutomationChannel {
  none,
  whatsApp,
  sms,
  email;

  String get label => switch (this) {
        AutomationChannel.none => 'Nenhum',
        AutomationChannel.whatsApp => 'WhatsApp',
        AutomationChannel.sms => 'SMS',
        AutomationChannel.email => 'E-mail',
      };
}

const List<AutomationRuleDefinition> automationRuleCatalog =
    <AutomationRuleDefinition>[
  AutomationRuleDefinition(
    id: 'return_reminder',
    title: 'Lembrete de retorno',
    description:
        'Dispara quando há retorno indicado na conduta e nenhuma consulta futura.',
    triggerKind: 'returnNotScheduled',
    channel: AutomationChannel.none,
  ),
  AutomationRuleDefinition(
    id: 'vaccine_overdue',
    title: 'Vacina atrasada',
    description: 'Notifica responsável sobre dose vencida no calendário PNI.',
    triggerKind: 'vaccineOverdue',
    channel: AutomationChannel.none,
  ),
  AutomationRuleDefinition(
    id: 'appointment_upcoming',
    title: 'Consulta próxima',
    description: 'Lembrete 24h antes de consulta confirmada.',
    triggerKind: 'teleconsultPending',
    channel: AutomationChannel.none,
  ),
  AutomationRuleDefinition(
    id: 'exam_pending',
    title: 'Exame pendente',
    description: 'Alerta profissional sobre resultado fora da faixa ou marcado.',
    triggerKind: 'examPending',
    channel: AutomationChannel.none,
  ),
  AutomationRuleDefinition(
    id: 'payment_overdue',
    title: 'Pagamento vencido',
    description: 'Cobrança após consulta realizada sem quitação.',
    triggerKind: 'paymentPending',
    channel: AutomationChannel.none,
  ),
  AutomationRuleDefinition(
    id: 'inactive_patient',
    title: 'Paciente sem consulta há X meses',
    description: 'Reengajamento quando último atendimento supera o limiar.',
    triggerKind: 'patientInactive',
    channel: AutomationChannel.none,
  ),
];
