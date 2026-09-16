import 'package:equatable/equatable.dart';

/// Especialidades oferecidas para conta profissional — cadastro e edição de
/// perfil usam a mesma lista. Duas cópias divergiriam com o tempo.
const List<String> professionalSpecialties = <String>[
  'Pediatria geral',
  'Neonatologia',
  'Neuropediatria',
  'Gastropediatria',
  'Pneumologia pediatrica',
  'Alergia e imunologia',
  'Endocrinologia pediatrica',
  'Nutricao',
  'Enfermagem pediatrica',
  'Outra',
];

/// Papel do usuario. Define o que ele ve e o que pode escrever.
///
/// - [parent]: pai/mae/responsavel. Ve as proprias criancas, a biblioteca, a
///   IA e a loja. Nao acessa protocolos de prescricao.
/// - [professional]: pediatra, enfermeiro, nutricionista. Acessa protocolos
///   clinicos, calculadoras de dose e telemedicina como atendente.
/// - [admin]: equipe Pediatria 360. Acessa o painel administrativo.
enum UserRole {
  parent,
  professional,
  admin;

  static UserRole fromName(String? value) => UserRole.values.firstWhere(
        (UserRole r) => r.name == value,
        orElse: () => UserRole.parent,
      );

  String get label => switch (this) {
        UserRole.parent => 'Pai, mae ou responsavel',
        UserRole.professional => 'Profissional de saude',
        UserRole.admin => 'Administrador',
      };

  bool get isProfessional => this == UserRole.professional || this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;
}

/// Plano de assinatura.
enum UserPlan {
  free,
  premium,
  pro;

  static UserPlan fromName(String? value) => UserPlan.values.firstWhere(
        (UserPlan p) => p.name == value,
        orElse: () => UserPlan.free,
      );

  String get label => switch (this) {
        UserPlan.free => 'Gratuito',
        UserPlan.premium => 'Premium',
        UserPlan.pro => 'Profissional',
      };

  bool get isPaid => this != UserPlan.free;
}

/// Usuario autenticado, ja combinado com o documento em `users/{uid}`.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.plan,
    required this.createdAt,
    this.photoUrl,
    this.phone,
    this.emailVerified = false,
    this.onboardingDone = false,
    this.crm,
    this.specialty,
    this.professionalVerified = false,
    this.consentPurposes = const <String, dynamic>{},
    this.deletionScheduledFor,
    this.xp = 0,
    this.streakDays = 0,
    this.lastActiveAt,
    this.fcmTokens = const <String>[],
    this.planExpiresAt,
  });

  /// Usuario recem-criado no Auth, antes de o documento existir no Firestore.
  factory AppUser.initial({
    required String uid,
    required String email,
    required String name,
    String? photoUrl,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        name: name,
        photoUrl: photoUrl,
        role: UserRole.parent,
        plan: UserPlan.free,
        createdAt: DateTime.now(),
      );

  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? phone;
  final UserRole role;
  final UserPlan plan;
  final DateTime createdAt;
  final bool emailVerified;

  /// `false` ate o usuario escolher o papel na tela de perfil inicial.
  final bool onboardingDone;

  // Campos do profissional
  final String? crm;
  final String? specialty;

  /// Validado pela equipe (checagem manual do CRM). Somente entao o
  /// profissional ganha acesso a protocolos de prescricao.
  final bool professionalVerified;

  /// Finalidades de tratamento autorizadas pelo titular (LGPD, Art. 14).
  /// Chave da finalidade -> autorizada ou não.
  final Map<String, dynamic> consentPurposes;

  /// Quando não-nulo, a conta tem exclusão agendada para esta data —
  /// espelha o campo que `requestDataDeletion`/`cancelDataDeletion` gravam
  /// e apagam no documento do usuário. É como a tela de privacidade sabe
  /// se deve mostrar "solicitar exclusão" ou "cancelar exclusão".
  final DateTime? deletionScheduledFor;

  // Gamificacao
  final int xp;
  final int streakDays;
  final DateTime? lastActiveAt;

  final List<String> fcmTokens;
  final DateTime? planExpiresAt;

  /// Nivel derivado do XP: cada nivel custa 20% mais que o anterior.
  int get level {
    int level = 1;
    int required = 100;
    int remaining = xp;
    while (remaining >= required) {
      remaining -= required;
      level++;
      required = (required * 1.2).round();
    }
    return level;
  }

  /// Progresso (0..1) dentro do nivel atual.
  double get levelProgress {
    int required = 100;
    int remaining = xp;
    while (remaining >= required) {
      remaining -= required;
      required = (required * 1.2).round();
    }
    return remaining / required;
  }

  /// Primeiro nome — usado na saudacao da home.
  String get firstName => name.trim().split(' ').first;

  String get initials {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Acesso a conteudo de prescricao exige papel profissional *verificado*.
  bool get canPrescribe => role.isProfessional && professionalVerified;

  bool get planActive =>
      plan.isPaid &&
      (planExpiresAt == null || planExpiresAt!.isAfter(DateTime.now()));

  AppUser copyWith({
    String? name,
    String? photoUrl,
    String? phone,
    UserRole? role,
    UserPlan? plan,
    bool? emailVerified,
    bool? onboardingDone,
    String? crm,
    String? specialty,
    bool? professionalVerified,
    int? xp,
    int? streakDays,
    DateTime? lastActiveAt,
    List<String>? fcmTokens,
    DateTime? planExpiresAt,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        createdAt: createdAt,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        plan: plan ?? this.plan,
        emailVerified: emailVerified ?? this.emailVerified,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        crm: crm ?? this.crm,
        specialty: specialty ?? this.specialty,
        professionalVerified:
            professionalVerified ?? this.professionalVerified,
        xp: xp ?? this.xp,
        streakDays: streakDays ?? this.streakDays,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        fcmTokens: fcmTokens ?? this.fcmTokens,
        planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      );

  @override
  List<Object?> get props => <Object?>[
        uid,
        email,
        name,
        photoUrl,
        phone,
        role,
        plan,
        emailVerified,
        onboardingDone,
        crm,
        specialty,
        professionalVerified,
        xp,
        streakDays,
        planExpiresAt,
      ];
}
