import 'package:equatable/equatable.dart';

/// Tipo de vinculo do responsavel com a crianca.
enum GuardianRelationship {
  mother,
  father,
  legalGuardian,
  other;

  static GuardianRelationship fromName(String? value) =>
      GuardianRelationship.values.firstWhere(
        (GuardianRelationship r) => r.name == value,
        orElse: () => GuardianRelationship.other,
      );

  String get label => switch (this) {
        GuardianRelationship.mother => 'Mae',
        GuardianRelationship.father => 'Pai',
        GuardianRelationship.legalGuardian => 'Tutor legal',
        GuardianRelationship.other => 'Outro',
      };
}

/// Status da autorizacao de acesso do responsavel vinculado.
enum GuardianAuthStatus {
  pending,
  active,
  revoked;

  static GuardianAuthStatus fromName(String? value) =>
      GuardianAuthStatus.values.firstWhere(
        (GuardianAuthStatus s) => s.name == value,
        orElse: () => GuardianAuthStatus.pending,
      );

  String get label => switch (this) {
        GuardianAuthStatus.pending => 'Pendente de autorizacao',
        GuardianAuthStatus.active => 'Ativo',
        GuardianAuthStatus.revoked => 'Revogado',
      };
}

/// Vinculo de um responsavel a uma crianca (cadastro unico existente).
///
/// Persistido em ``users/{ownerId}/children/{childId}/guardians/{guardianUid}``.
/// O dono do documento da crianca continua sendo [ownerId]; este vinculo
/// adiciona responsaveis secundarios com permissoes explicitas.
class ChildGuardianLink extends Equatable {
  const ChildGuardianLink({
    required this.guardianUid,
    required this.ownerId,
    required this.childId,
    required this.relationship,
    required this.status,
    required this.createdAt,
    this.displayName = '',
    this.email = '',
    this.canViewData = false,
    this.canSendDocuments = false,
    this.canMakeRequests = false,
    this.updatedAt,
    this.notes = '',
  });

  factory ChildGuardianLink.fromMap(
    Map<String, dynamic> map, {
    required String guardianUid,
  }) {
    return ChildGuardianLink(
      guardianUid: guardianUid,
      ownerId: (map['ownerId'] as String?) ?? '',
      childId: (map['childId'] as String?) ?? '',
      relationship: GuardianRelationship.fromName(map['relationship'] as String?),
      status: GuardianAuthStatus.fromName(map['status'] as String?),
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      displayName: (map['displayName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      canViewData: (map['canViewData'] as bool?) ?? false,
      canSendDocuments: (map['canSendDocuments'] as bool?) ?? false,
      canMakeRequests: (map['canMakeRequests'] as bool?) ?? false,
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? ''),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  final String guardianUid;
  final String ownerId;
  final String childId;
  final GuardianRelationship relationship;
  final GuardianAuthStatus status;
  final DateTime createdAt;
  final String displayName;
  final String email;
  final bool canViewData;
  final bool canSendDocuments;
  final bool canMakeRequests;
  final DateTime? updatedAt;
  final String notes;

  bool get isPendingAuthorization =>
      status == GuardianAuthStatus.pending ||
      (status == GuardianAuthStatus.active &&
          !canViewData &&
          !canSendDocuments &&
          !canMakeRequests);

  bool get mayViewChildData =>
      status == GuardianAuthStatus.active && canViewData;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'guardianUid': guardianUid,
        'ownerId': ownerId,
        'childId': childId,
        'relationship': relationship.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'displayName': displayName,
        'email': email,
        'canViewData': canViewData,
        'canSendDocuments': canSendDocuments,
        'canMakeRequests': canMakeRequests,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'notes': notes,
      };

  ChildGuardianLink copyWith({
    GuardianAuthStatus? status,
    bool? canViewData,
    bool? canSendDocuments,
    bool? canMakeRequests,
    String? displayName,
    String? notes,
    DateTime? updatedAt,
  }) =>
      ChildGuardianLink(
        guardianUid: guardianUid,
        ownerId: ownerId,
        childId: childId,
        relationship: relationship,
        status: status ?? this.status,
        createdAt: createdAt,
        displayName: displayName ?? this.displayName,
        email: email,
        canViewData: canViewData ?? this.canViewData,
        canSendDocuments: canSendDocuments ?? this.canSendDocuments,
        canMakeRequests: canMakeRequests ?? this.canMakeRequests,
        updatedAt: updatedAt ?? this.updatedAt,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props =>
      <Object?>[guardianUid, childId, status, canViewData, canSendDocuments];
}