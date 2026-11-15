import 'package:equatable/equatable.dart';

/// Autorização do responsável a um profissional, em
/// `users/{dono}/children/{criança}/authorized_professionals/{profissional}`.
///
/// Espelha `grantIsActive` das regras e `grantAllows` das Functions. Só
/// vale o que o titular escolheu: pela tela de autorizações ([sourceGuardian])
/// ou ao aceitar o convite da clínica ([sourceInvite]). Consulta marcada não
/// concede acesso.
enum ChildAccessScope {
  summary,
  chartWrite;

  static ChildAccessScope? fromName(String? v) {
    for (final ChildAccessScope s in ChildAccessScope.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// Os dois níveis oferecidos na tela. "Prontuário" sempre inclui o resumo.
enum ChildAccessLevel {
  summaryOnly,
  chart;

  List<String> get scopes => switch (this) {
        ChildAccessLevel.summaryOnly => const <String>['summary'],
        ChildAccessLevel.chart => const <String>['summary', 'chartWrite'],
      };

  String get label => switch (this) {
        ChildAccessLevel.summaryOnly => 'Somente resumo',
        ChildAccessLevel.chart => 'Resumo e prontuário',
      };

  /// O que este nível permite e o que não permite, em linguagem da família.
  String get allows => switch (this) {
        ChildAccessLevel.summaryOnly =>
          'Vê nome, idade, sexo, alergias e condições cadastradas, para '
              'atender com segurança.',
        ChildAccessLevel.chart =>
          'Tudo do resumo e, além disso, registra atendimentos, exames, '
              'triagem, documentos (receitas, atestados) e pode usar as '
              'ferramentas de IA do prontuário para esta criança.',
      };

  String get denies => switch (this) {
        ChildAccessLevel.summaryOnly =>
          'Não registra atendimento, não emite documentos, não usa IA e não '
              'vê crescimento, vacinas nem registros de outros profissionais.',
        ChildAccessLevel.chart =>
          'Não vê crescimento e vacinas do app da família nem registros '
              'feitos por outros profissionais.',
      };
}

enum ChildAccessStatus { active, expired, revoked, invalid }

class ChildAccessGrant extends Equatable {
  const ChildAccessGrant({
    required this.professionalId,
    required this.status,
    required this.scopes,
    this.source,
    this.professionalName,
    this.clinicId,
    this.clinicName,
    this.grantedAt,
    this.expiresAt,
    this.revokedAt,
  });

  static const String sourceGuardian = 'guardian';
  static const String sourceInvite = 'guardianInvite';
  static const Set<String> validSources = <String>{
    sourceGuardian,
    sourceInvite,
  };

  /// Classifica o documento como as regras o veriam agora.
  factory ChildAccessGrant.fromMap(
    String professionalId,
    Map<String, dynamic> map, {
    required DateTime now,
    DateTime? Function(Object?)? toDate,
  }) {
    final DateTime? Function(Object?) conv = toDate ?? _defaultToDate;
    final String? source = map['source'] as String?;
    final Object? rawScopes = map['scopes'];
    final DateTime? expiresAt = conv(map['expiresAt']);
    final DateTime? revokedAt = conv(map['revokedAt']);
    final List<ChildAccessScope> scopes = rawScopes is List
        ? rawScopes
            .map((Object? s) => ChildAccessScope.fromName(s as String?))
            .whereType<ChildAccessScope>()
            .toList(growable: false)
        : const <ChildAccessScope>[];

    final ChildAccessStatus status;
    if (!validSources.contains(source) ||
        rawScopes is! List ||
        scopes.isEmpty ||
        expiresAt == null) {
      status = ChildAccessStatus.invalid;
    } else if (map['revokedAt'] != null) {
      status = ChildAccessStatus.revoked;
    } else if (!expiresAt.isAfter(now)) {
      status = ChildAccessStatus.expired;
    } else {
      status = ChildAccessStatus.active;
    }

    return ChildAccessGrant(
      professionalId: professionalId,
      status: status,
      scopes: scopes,
      source: source,
      professionalName: map['professionalName'] as String?,
      clinicId: map['clinicId'] as String?,
      clinicName: map['clinicName'] as String?,
      grantedAt: conv(map['grantedAt']),
      expiresAt: expiresAt,
      revokedAt: revokedAt,
    );
  }

  static DateTime? _defaultToDate(Object? v) => v is DateTime ? v : null;

  final String professionalId;
  final ChildAccessStatus status;
  final List<ChildAccessScope> scopes;
  final String? source;
  final String? professionalName;
  final String? clinicId;
  final String? clinicName;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool get isActive => status == ChildAccessStatus.active;

  ChildAccessLevel? get level {
    if (scopes.contains(ChildAccessScope.chartWrite)) {
      return ChildAccessLevel.chart;
    }
    if (scopes.contains(ChildAccessScope.summary)) {
      return ChildAccessLevel.summaryOnly;
    }
    return null;
  }

  String get displayName =>
      (professionalName ?? '').trim().isEmpty ? 'Profissional' : professionalName!;

  String get statusLabel => switch (status) {
        ChildAccessStatus.active => 'Ativa',
        ChildAccessStatus.expired => 'Vencida',
        ChildAccessStatus.revoked => 'Revogada',
        ChildAccessStatus.invalid => 'Antiga (sem efeito)',
      };

  @override
  List<Object?> get props => <Object?>[
        professionalId,
        status,
        scopes,
        source,
        clinicId,
        expiresAt,
        revokedAt,
      ];
}

/// Validades oferecidas. As regras aceitam até 366 dias.
const List<int> kChildAccessDurations = <int>[30, 90, 180, 365];

/// Profissional que a família pode autorizar: das próprias consultas ou
/// achado pelo e-mail (só profissional com registro conferido).
class AccessCandidate extends Equatable {
  const AccessCandidate({
    required this.professionalId,
    required this.professionalName,
    this.clinicId,
    this.clinicName,
    this.specialty,
  });

  final String professionalId;
  final String professionalName;
  final String? clinicId;
  final String? clinicName;
  final String? specialty;

  @override
  List<Object?> get props =>
      <Object?>[professionalId, clinicId, professionalName];
}

/// Uma linha por profissional e clínica, a partir das consultas da família.
List<AccessCandidate> candidatesFromAppointments(
  Iterable<Map<String, dynamic>> appointments,
) {
  final Map<String, AccessCandidate> out = <String, AccessCandidate>{};
  for (final Map<String, dynamic> a in appointments) {
    final String? prof = a['professionalId'] as String?;
    if (prof == null || prof.isEmpty) continue;
    final String? clinicId = a['clinicId'] as String?;
    final String key = '$prof|${clinicId ?? ''}';
    out.putIfAbsent(
      key,
      () => AccessCandidate(
        professionalId: prof,
        professionalName: (a['professionalName'] as String?) ?? 'Profissional',
        clinicId: clinicId,
        clinicName: a['clinicName'] as String?,
        specialty: a['specialty'] as String?,
      ),
    );
  }
  return out.values.toList(growable: false);
}
