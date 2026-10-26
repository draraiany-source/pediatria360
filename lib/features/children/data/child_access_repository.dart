import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/utils/result.dart';
import '../domain/child_access_grant.dart';

/// Autorizações do responsável a profissionais (escrita direta, validada
/// pelas regras: só o titular do child_registry, até 366 dias, e depois só
/// revoga).
class ChildAccessRepository {
  ChildAccessRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    DateTime Function()? clock,
  })  : _db = firestore,
        _functions = functions,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> _grants(
    String ownerId,
    String childId,
  ) =>
      _db
          .collection('users')
          .doc(ownerId)
          .collection('children')
          .doc(childId)
          .collection('authorized_professionals');

  static DateTime? _toDate(Object? v) => v is Timestamp ? v.toDate() : null;

  Stream<List<ChildAccessGrant>> watchGrants({
    required String ownerId,
    required String childId,
  }) {
    return _grants(ownerId, childId).snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ChildAccessGrant.fromMap(
                  d.id,
                  d.data(),
                  now: _clock(),
                  toDate: _toDate,
                ),
              )
              .toList(growable: false),
        );
  }

  /// Concede (ou renova) a autorização. Substitui a anterior inteira: o
  /// titular escolhe de novo escopo, clínica e validade.
  Future<Result<void>> grant({
    required String ownerId,
    required String childId,
    required String professionalId,
    required String professionalName,
    required ChildAccessLevel level,
    required int days,
    String? clinicId,
    String? clinicName,
  }) =>
      guard(() async {
        if (days < 1 || days > 365) {
          throw ArgumentError('Validade deve ficar entre 1 e 365 dias.');
        }
        final DateTime expires = _clock().add(Duration(days: days));
        await _grants(ownerId, childId).doc(professionalId).set(<String, dynamic>{
          'scopes': level.scopes,
          'source': ChildAccessGrant.sourceGuardian,
          'authorizedBy': ownerId,
          'grantedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expires),
          'revokedAt': null,
          'clinicId': clinicId,
          'professionalName': professionalName,
          if (clinicName != null) 'clinicName': clinicName,
        });
      });

  Future<Result<void>> revoke({
    required String ownerId,
    required String childId,
    required String professionalId,
  }) =>
      guard(() async {
        await _grants(ownerId, childId).doc(professionalId).update(
          <String, dynamic>{
            'revokedAt': FieldValue.serverTimestamp(),
            'revokedBy': ownerId,
          },
        );
      });

  /// Profissionais das consultas da própria família.
  Future<Result<List<AccessCandidate>>> candidatesFromMyAppointments(
    String ownerId,
  ) =>
      guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snap = await _db
            .collection('appointments')
            .where('patientId', isEqualTo: ownerId)
            .limit(100)
            .get();
        return candidatesFromAppointments(
          snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data()),
        );
      });

  /// Busca profissional com registro conferido pelo e-mail.
  Future<Result<AccessCandidate>> lookupProfessional(String email) =>
      guard(() async {
        final HttpsCallableResult<dynamic> res = await _functions
            .httpsCallable('lookupProfessional')
            .call(<String, dynamic>{'email': email.trim()});
        final Map<dynamic, dynamic> data = res.data as Map<dynamic, dynamic>;
        return AccessCandidate(
          professionalId: data['uid'] as String,
          professionalName: (data['name'] as String?) ?? 'Profissional',
          specialty: data['specialty'] as String?,
        );
      });
}
