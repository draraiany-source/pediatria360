import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:equatable/equatable.dart';

import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

/// Membro da equipe como a gestão vê (o documento do lado da clínica).
class ClinicTeamMember extends Equatable {
  const ClinicTeamMember({
    required this.membershipId,
    required this.userId,
    required this.role,
    required this.active,
    this.name = '',
    this.specialty = '',
  });

  final String membershipId;
  final String userId;
  final ClinicRole role;
  final bool active;
  final String name;
  final String specialty;

  @override
  List<Object?> get props => <Object?>[membershipId, role, active];
}

/// Papéis oferecidos na tela de equipe. Recepção e financeiro não precisam
/// de registro profissional; papéis clínicos exigem conta de profissional.
const List<ClinicRole> kAssignableClinicRoles = <ClinicRole>[
  ClinicRole.receptionist,
  ClinicRole.finance,
  ClinicRole.physician,
  ClinicRole.healthProfessional,
  ClinicRole.nursing,
  ClinicRole.technician,
  ClinicRole.clinicAdmin,
];

/// Equipe da clínica. Leitura direta (membros da clínica leem os vínculos);
/// inclusão e alteração só pelas Functions addClinicMember e
/// setClinicMemberStatus, que conferem se quem pede é da gestão.
class ClinicTeamRepository {
  ClinicTeamRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _db = firestore,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<ClinicTeamMember>> watchMembers(String clinicId) => _db
      .collection('clinics')
      .doc(clinicId)
      .collection('memberships')
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
              final Map<String, dynamic> m = d.data();
              return ClinicTeamMember(
                membershipId: d.id,
                userId: (m['userId'] as String?) ?? '',
                role: ClinicRole.fromName(m['role'] as String?),
                active: (m['active'] as bool?) ?? false,
                name: (m['name'] as String?) ?? '',
                specialty: (m['specialty'] as String?) ?? '',
              );
            })
            .toList(growable: false),
      );

  Future<Result<void>> addMember({
    required String clinicId,
    required String email,
    required ClinicRole role,
  }) =>
      guard(
        () => _functions.httpsCallable('addClinicMember').call(
          <String, dynamic>{
            'clinicId': clinicId,
            'email': email.trim(),
            'role': role.name,
          },
        ),
      );

  Future<Result<void>> setStatus({
    required String clinicId,
    required String membershipId,
    required bool active,
    ClinicRole? role,
  }) =>
      guard(
        () => _functions.httpsCallable('setClinicMemberStatus').call(
          <String, dynamic>{
            'clinicId': clinicId,
            'membershipId': membershipId,
            'active': active,
            if (role != null) 'role': role.name,
          },
        ),
      );
}
