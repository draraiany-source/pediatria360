/// Politica de retencao de trilhas de auditoria (FASE 8).
///
/// **Default:** manter indefinidamente ate politica formal da clinica/plataforma.
/// Nao existe job de purge automatico nesta fase — ver pendencias.
/// [RetentionPolicy.description].
class RetentionPolicy {
  RetentionPolicy._();

  static const String description =
      'Logs de seguranca (security_audit_logs) e trilhas de dominio '
      '(finance_audit_logs, billing_audit_logs, inventory_audit_logs) sao '
      'mantidos sem exclusao automatica. Retencao minima recomendada: 5 anos '
      'para dados financeiros/fiscais; prontuario segue normas CFM. Purge '
      'automatico NAO implementado (FASE 8).';

  /// Dias sugeridos para arquivamento futuro (nao aplicado).
  static const int suggestedMinimumRetentionDays = 365 * 5;
}