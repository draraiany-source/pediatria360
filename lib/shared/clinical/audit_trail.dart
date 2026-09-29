/// Registro de alterações: quem fez o quê, quando e em qual registro.
library;

enum AuditEntity {
  consulta('Consulta'),
  observacao('Observação'),
  tarefa('Tarefa'),
  agendamento('Agendamento'),
  rascunhoAssistente('Rascunho do assistente');

  const AuditEntity(this.label);

  final String label;
}

class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.actor,
    required this.entity,
    required this.entityId,
    required this.action,
    this.patientId,
    this.detail,
  });

  final DateTime at;
  final String actor;
  final AuditEntity entity;
  final String entityId;
  final String action;
  final String? patientId;
  final String? detail;
}

/// Campos que mudaram entre duas versões (rótulo -> valor).
List<String> changedFields(
  Map<String, String> before,
  Map<String, String> after,
) => <String>[
  for (final String k in after.keys)
    if ((before[k] ?? '').trim() != (after[k] ?? '').trim()) k,
];
