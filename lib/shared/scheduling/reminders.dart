/// Lembretes de consulta ao responsável.
///
/// Regras puras: intervalos configurados pela clínica, consentimento e
/// preferência de contato, texto discreto (sem dado clínico) e registro de
/// status. O envio em si fica com o provedor (WhatsApp Business Platform,
/// API oficial da Meta) — ver `functions/src/whatsapp.ts`.
library;

enum ContactChannel {
  whatsapp('WhatsApp'),
  sms('SMS'),
  email('E-mail'),
  telefone('Ligação telefônica');

  const ContactChannel(this.label);

  final String label;
}

/// Contato do responsável como está no cadastro.
class GuardianContact {
  GuardianContact({
    required this.name,
    required this.phone,
    this.preferred = ContactChannel.whatsapp,
    this.reminderConsent = false,
    this.consentAt,
  });

  final String name;
  String phone;
  ContactChannel preferred;

  /// Autorizou receber lembretes de consulta (LGPD: finalidade específica).
  bool reminderConsent;
  DateTime? consentAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// Intervalos de envio (horas antes da consulta) definidos pela clínica.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.offsetsHours = const <int>[48, 24, 2],
  });

  final bool enabled;
  final List<int> offsetsHours;

  /// Opções oferecidas na tela de configuração.
  static const List<int> choices = <int>[168, 72, 48, 24, 12, 6, 3, 2, 1];
  static const int maxReminders = 3;

  String? validate() {
    if (!enabled) return null;
    if (offsetsHours.isEmpty) return 'Escolha pelo menos um horário de envio.';
    if (offsetsHours.length > maxReminders) {
      return 'Use no máximo $maxReminders lembretes por consulta.';
    }
    if (offsetsHours.toSet().length != offsetsHours.length) {
      return 'Há horários de envio repetidos.';
    }
    for (final int h in offsetsHours) {
      if (h < 1 || h > 168) return 'Use de 1 hora a 7 dias antes da consulta.';
    }
    return null;
  }

  /// Do mais antecipado para o mais próximo da consulta.
  List<int> get sorted => List<int>.of(offsetsHours)
    ..sort((int a, int b) => b.compareTo(a));

  ReminderSettings copyWith({bool? enabled, List<int>? offsetsHours}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        offsetsHours: offsetsHours ?? this.offsetsHours,
      );
}

String offsetLabel(int hours) {
  if (hours % 24 == 0) {
    final int d = hours ~/ 24;
    return '$d ${d == 1 ? 'dia' : 'dias'} antes';
  }
  return '$hours ${hours == 1 ? 'hora' : 'horas'} antes';
}

/// Decide qual lembrete enviar agora. Se o sistema ficou parado e mais de um
/// horário venceu, envia só o mais próximo da consulta (não manda três
/// mensagens seguidas). Devolve `null` se nada está pendente.
int? dueReminderOffset({
  required DateTime appointmentStart,
  required List<int> offsetsHours,
  required Set<int> alreadyHandled,
  required DateTime now,
}) {
  if (!appointmentStart.isAfter(now)) return null;
  int? due;
  for (final int h in offsetsHours) {
    if (alreadyHandled.contains(h)) continue;
    final DateTime at = appointmentStart.subtract(Duration(hours: h));
    if (at.isAfter(now)) continue;
    if (due == null || h < due) due = h;
  }
  return due;
}

/// Horários vencidos que foram pulados porque um mais recente será enviado.
List<int> skippedOffsets({
  required DateTime appointmentStart,
  required List<int> offsetsHours,
  required Set<int> alreadyHandled,
  required int sending,
  required DateTime now,
}) => <int>[
  for (final int h in offsetsHours)
    if (h > sending &&
        !alreadyHandled.contains(h) &&
        !appointmentStart.subtract(Duration(hours: h)).isAfter(now))
      h,
];

enum ReminderBlock { none, noConsent, preferenceNotWhatsApp, invalidPhone }

/// Pode enviar pelo WhatsApp? Sem consentimento ou com outra preferência,
/// NÃO envia: a recepção decide o contato manual.
ReminderBlock whatsAppEligibility(GuardianContact c) {
  if (!c.reminderConsent) return ReminderBlock.noConsent;
  if (c.preferred != ContactChannel.whatsapp) {
    return ReminderBlock.preferenceNotWhatsApp;
  }
  if (normalizePhone(c.phone) == null) return ReminderBlock.invalidPhone;
  return ReminderBlock.none;
}

String blockReason(ReminderBlock b, GuardianContact c) => switch (b) {
  ReminderBlock.none => '',
  ReminderBlock.noConsent =>
    'Responsável não autorizou lembretes. Não enviado.',
  ReminderBlock.preferenceNotWhatsApp =>
    'Preferência de contato: ${c.preferred.label}. Não enviado pelo '
        'WhatsApp.',
  ReminderBlock.invalidPhone => 'Telefone do cadastro incompleto ou inválido.',
};

/// Formato E.164 exigido pela API (só dígitos, com DDI). `null` = inválido.
String? normalizePhone(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 12 || digits.length > 13) return null;
  if (!digits.startsWith('55')) return null;
  return digits;
}

/// Mostra só o final do número no registro e na tela.
String maskPhone(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '••••';
  return '•••• ${digits.substring(digits.length - 4)}';
}

const List<String> _weekdays = <String>[
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
  'dom',
];

String _two(int n) => n.toString().padLeft(2, '0');

String reminderWhen(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)} às '
    '${_two(d.hour)}:${_two(d.minute)}';

/// Texto do lembrete. Discreto de propósito: só primeiro nome da criança,
/// data, hora e modalidade. Nunca motivo, queixa, exame ou especialidade.
String reminderText({
  required String guardianFirstName,
  required String childFirstName,
  required String clinicName,
  required DateTime start,
  required bool teleconsulta,
}) =>
    'Olá, $guardianFirstName! Lembrete de $clinicName: $childFirstName tem '
    'horário marcado ${reminderWhen(start)} '
    '(${teleconsulta ? 'online' : 'presencial'}). '
    'Toque em uma opção abaixo.';

/// Respostas rápidas do modelo de mensagem (botões do WhatsApp).
enum ReminderReply {
  confirmar('Confirmar'),
  reagendar('Reagendar'),
  cancelar('Cancelar');

  const ReminderReply(this.label);

  final String label;

  /// Os botões do modelo aprovado devolvem o `payload` definido no envio.
  static ReminderReply? fromPayload(String payload) {
    for (final ReminderReply r in values) {
      if (payload.endsWith(':${r.name}')) return r;
    }
    return null;
  }
}

/// Status seguem os eventos do webhook do provedor.
enum ReminderStatus {
  naoEnviado('Não enviado'),
  enviado('Enviado'),
  entregue('Entregue'),
  lido('Lido'),
  respondido('Respondido'),
  falhou('Falhou');

  const ReminderStatus(this.label);

  final String label;

  bool get needsManualContact =>
      this == ReminderStatus.falhou || this == ReminderStatus.naoEnviado;
}

class ReminderEvent {
  const ReminderEvent(this.at, this.text);

  final DateTime at;
  final String text;
}

/// Registro de um lembrete: status, horário, destinatário e resposta.
class ReminderRecord {
  ReminderRecord({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.offsetHours,
    required this.recipientName,
    required this.recipientMasked,
    required this.channel,
    required this.text,
    required this.status,
    required this.createdAt,
    this.providerMessageId,
    this.failureReason,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final int offsetHours;
  final String recipientName;
  final String recipientMasked;
  final ContactChannel channel;
  final String text;
  ReminderStatus status;
  final DateTime createdAt;
  String? providerMessageId;
  String? failureReason;
  DateTime? sentAt;
  DateTime? deliveredAt;
  DateTime? readAt;
  DateTime? repliedAt;
  ReminderReply? reply;
  final List<ReminderEvent> events = <ReminderEvent>[];

  /// A família ainda pode tocar num botão.
  bool get awaitingReply =>
      reply == null &&
      (status == ReminderStatus.enviado ||
          status == ReminderStatus.entregue ||
          status == ReminderStatus.lido);
}
