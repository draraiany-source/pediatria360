import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/clinic_paths.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

/// Persistencia de clinicas / memberships (FASE 1 ? sem migrar dados legados).
class ClinicOrganizationRepository {
  ClinicOrganizationRepository({required FirebaseFirestore firestore})
      : _db = firestore;

  final FirebaseFirestore _db;

  Future<Result<ClinicOrganization>> createClinic({
    required ClinicOrganization clinic,
    required String ownerUserId,
    ClinicRole ownerRole = ClinicRole.clinicAdmin,
  }) {
    return guard(() async {
      final String id = clinic.id.isEmpty
          ? _db.collection(ClinicPaths.clinics).doc().id
          : clinic.id;
      final ClinicOrganization saved = ClinicOrganization(
        id: id,
        name: clinic.name,
        tradeName: clinic.tradeName,
        cnpj: clinic.cnpj,
        phone: clinic.phone,
        whatsapp: clinic.whatsapp,
        email: clinic.email,
        address: clinic.address,
        logoUrl: clinic.logoUrl,
        active: clinic.active,
        plan: clinic.plan,
        createdAt: clinic.createdAt,
      );
      await _db.doc(ClinicPaths.clinic(id)).set(saved.toMap());

      final String membershipId =
          _db.collection(ClinicPaths.memberships(id)).doc().id;
      final ClinicMembership membership = ClinicMembership(
        id: membershipId,
        clinicId: id,
        userId: ownerUserId,
        role: ownerRole,
        createdAt: DateTime.now(),
      );
      await _db
          .doc(ClinicPaths.membership(id, membershipId))
          .set(membership.toMap());
      await _db.doc(ClinicPaths.userMembership(ownerUserId, id)).set(
            membership.toMap(),
          );
      return saved;
    });
  }

  Stream<List<ClinicMembership>> watchUserMemberships(String userId) {
    return _db.collection(ClinicPaths.userMemberships(userId)).snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ClinicMembership.fromMap(d.data(), id: d.id),
              )
              .where((ClinicMembership m) => m.active)
              .toList(growable: false),
        );
  }

  Future<Result<ClinicOrganization?>> getClinic(String clinicId) {
    return guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _db.doc(ClinicPaths.clinic(clinicId)).get();
      if (!snap.exists || snap.data() == null) return null;
      return ClinicOrganization.fromMap(snap.data()!, id: snap.id);
    });
  }
}
