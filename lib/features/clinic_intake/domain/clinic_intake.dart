import 'package:equatable/equatable.dart';

/// Solicitação de paciente novo (clinic_intakes): provisória e
/// administrativa. Não tem id de criança nem dado clínico; vira consulta só
/// quando o responsável aceita o convite para uma criança dele.
enum ClinicIntakeStatus {
  pendingGuardian,
  linked,
  cancelled;

  static ClinicIntakeStatus fromName(String? v) =>
      ClinicIntakeStatus.values.firstWhere(
        (ClinicIntakeStatus s) => s.name == v,
        orElse: () => ClinicIntakeStatus.cancelled,
      );

  String get label => switch (this) {
        ClinicIntakeStatus.pendingGuardian => 'Aguardando responsável',
        ClinicIntakeStatus.linked => 'Confirmada pela família',
        ClinicIntakeStatus.cancelled => 'Cancelada',
      };
}

class ClinicIntake extends Equatable {
  const ClinicIntake({
    required this.id,
    required this.status,
    required this.professionalId,
    required this.professionalName,
    required this.childName,
    required this.guardianName,
    required this.guardianEmail,
    required this.requestedStartsAt,
    required this.durationMinutes,
    this.clinicId,
    this.clinicName,
    this.childBirthDate,
    this.guardianPhone,
    this.reason,
    this.inviteExpiresAt,
    this.appointmentId,
    this.grantScopes = const <String>[],
  });

  factory ClinicIntake.fromMap(
    String id,
    Map<String, dynamic> m, {
    required DateTime? Function(Object?) toDate,
  }) {
    return ClinicIntake(
      id: id,
      status: ClinicIntakeStatus.fromName(m['status'] as String?),
      clinicId: m['clinicId'] as String?,
      clinicName: m['clinicName'] as String?,
      professionalId: (m['professionalId'] as String?) ?? '',
      professionalName: (m['professionalName'] as String?) ?? '',
      childName: (m['childName'] as String?) ?? '',
      childBirthDate: m['childBirthDate'] as String?,
      guardianName: (m['guardianName'] as String?) ?? '',
      guardianEmail: (m['guardianEmail'] as String?) ?? '',
      guardianPhone: m['guardianPhone'] as String?,
      reason: m['reason'] as String?,
      requestedStartsAt:
          toDate(m['requestedStartsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 30,
      inviteExpiresAt: toDate(m['inviteExpiresAt']),
      appointmentId: m['appointmentId'] as String?,
      grantScopes: ((m['grantScopes'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  final String id;
  final ClinicIntakeStatus status;
  final String? clinicId;
  final String? clinicName;
  final String professionalId;
  final String professionalName;
  final String childName;
  final String? childBirthDate;
  final String guardianName;
  final String guardianEmail;
  final String? guardianPhone;
  final String? reason;
  final DateTime requestedStartsAt;
  final int durationMinutes;
  final DateTime? inviteExpiresAt;
  final String? appointmentId;
  final List<String> grantScopes;

  bool inviteExpired(DateTime now) =>
      status == ClinicIntakeStatus.pendingGuardian &&
      (inviteExpiresAt == null || !inviteExpiresAt!.isAfter(now));

  /// Situação do acesso clínico escolhida pela família ao aceitar.
  String get accessLabel {
    if (status != ClinicIntakeStatus.linked) return '';
    if (grantScopes.contains('chartWrite')) return 'Família autorizou resumo e prontuário';
    if (grantScopes.contains('summary')) return 'Família autorizou somente o resumo';
    return 'Família confirmou sem autorizar acesso clínico';
  }

  @override
  List<Object?> get props => <Object?>[id, status, requestedStartsAt, appointmentId];
}

/// O que a família vê antes de aceitar.
class IntakePreview extends Equatable {
  const IntakePreview({
    required this.professionalName,
    required this.startsAt,
    required this.durationMinutes,
    required this.childName,
    required this.guardianName,
    this.clinicName,
    this.specialty,
    this.childBirthDate,
    this.expiresAt,
  });

  factory IntakePreview.fromMap(Map<dynamic, dynamic> m) => IntakePreview(
        professionalName: (m['professionalName'] as String?) ?? '',
        clinicName: m['clinicName'] as String?,
        specialty: m['specialty'] as String?,
        startsAt: DateTime.parse(m['startsAt'] as String),
        durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 30,
        childName: (m['childName'] as String?) ?? '',
        childBirthDate: m['childBirthDate'] as String?,
        guardianName: (m['guardianName'] as String?) ?? '',
        expiresAt: DateTime.tryParse((m['expiresAt'] as String?) ?? ''),
      );

  final String professionalName;
  final String? clinicName;
  final String? specialty;
  final DateTime startsAt;
  final int durationMinutes;
  final String childName;
  final String? childBirthDate;
  final String guardianName;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => <Object?>[professionalName, startsAt, childName];
}

/// Código devolvido uma única vez à recepção.
class IntakeInvite extends Equatable {
  const IntakeInvite({
    required this.intakeId,
    required this.code,
    required this.expiresAt,
  });

  final String intakeId;
  final String code;
  final DateTime expiresAt;

  /// Mensagem para a recepção enviar (WhatsApp simulado: só copia o texto).
  String messageFor({
    required String guardianName,
    required String childName,
    required String? clinicName,
  }) =>
      'Olá, $guardianName. ${clinicName ?? 'A clínica'} registrou uma '
      'solicitação de consulta para $childName. Para confirmar, abra o app '
      'Pediatria 360 com a conta deste e-mail, toque em "Convite da clínica" '
      'e informe o código $code. O código vale até '
      '${expiresAt.toLocal().day.toString().padLeft(2, '0')}/'
      '${expiresAt.toLocal().month.toString().padLeft(2, '0')}. '
      'Você escolhe no app se autoriza o acesso aos dados da criança.';

  @override
  List<Object?> get props => <Object?>[intakeId, code];
}

/// Profissional que pode atender (para o formulário da recepção).
class IntakeProfessionalOption extends Equatable {
  const IntakeProfessionalOption({
    required this.userId,
    required this.label,
  });

  final String userId;
  final String label;

  @override
  List<Object?> get props => <Object?>[userId];
}

const Set<String> kIntakeCareRoles = <String>{
  'clinicAdmin',
  'physician',
  'healthProfessional',
  'nursing',
  'technician',
};
