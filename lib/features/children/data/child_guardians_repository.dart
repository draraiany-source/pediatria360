import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../domain/child_guardian.dart';

/// Gestao de responsaveis vinculados ao cadastro unico da crianca.
class ChildGuardiansRepository {
  ChildGuardiansRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _guardians(
    String ownerId,
    String childId,
  ) =>
      _firestore
          .collection(FirestorePaths.userChildren(ownerId))
          .doc(childId)
          .collection('guardians');

  CollectionReference<Map<String, dynamic>> _changeLog(
    String ownerId,
    String childId,
  ) =>
      _firestore
          .collection(FirestorePaths.userChildren(ownerId))
          .doc(childId)
          .collection('change_log');

  DocumentReference<Map<String, dynamic>> _linkedChild(
    String guardianUid,
    String childId,
  ) =>
      _firestore
          .collection('users')
          .doc(guardianUid)
          .collection('linked_children')
          .doc(childId);

  Stream<List<ChildGuardianLink>> watchGuardians({
    required String ownerId,
    required String childId,
  }) =>
      _guardians(ownerId, childId).snapshots().map(
            (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      ChildGuardianLink.fromMap(d.data(), guardianUid: d.id),
                )
                .toList(growable: false),
          );

  Stream<List<ChildGuardianLink>> watchMyLinkedChildren(String guardianUid) =>
      _firestore
          .collection('users')
          .doc(guardianUid)
          .collection('linked_children')
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      ChildGuardianLink.fromMap(d.data(), guardianUid: guardianUid),
                )
                .toList(growable: false),
          );

  Future<Result<void>> upsertGuardian({
    required ChildGuardianLink link,
    required String actorUid,
  }) =>
      guard(() async {
        if (link.guardianUid.isEmpty || link.childId.isEmpty) {
          throw const ValidationFailure('Responsavel ou crianca invalidos.');
        }
        if (link.guardianUid == link.ownerId &&
            link.status == GuardianAuthStatus.active) {
          // Dono primario: sempre ativo com acesso total.
        }
        final ChildGuardianLink? previous = await _readOptional(link);
        final Map<String, dynamic> payload = link
            .copyWith(updatedAt: DateTime.now().toUtc())
            .toMap();
        await _guardians(link.ownerId, link.childId)
            .doc(link.guardianUid)
            .set(payload, SetOptions(merge: true));
        await _linkedChild(link.guardianUid, link.childId).set(
          payload,
          SetOptions(merge: true),
        );
        await _appendChange(
          ownerId: link.ownerId,
          childId: link.childId,
          actorUid: actorUid,
          action: previous == null ? 'guardianAdded' : 'guardianUpdated',
          before: previous?.toMap(),
          after: payload,
        );
      });

  Future<Result<void>> revokeGuardian({
    required String ownerId,
    required String childId,
    required String guardianUid,
    required String actorUid,
  }) =>
      guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> snap =
            await _guardians(ownerId, childId).doc(guardianUid).get();
        final Map<String, dynamic>? before = snap.data();
        final ChildGuardianLink revoked = ChildGuardianLink.fromMap(
          <String, dynamic>{
            ...?before,
            'ownerId': ownerId,
            'childId': childId,
            'status': GuardianAuthStatus.revoked.name,
            'canViewData': false,
            'canSendDocuments': false,
            'canMakeRequests': false,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          guardianUid: guardianUid,
        );
        await _guardians(ownerId, childId)
            .doc(guardianUid)
            .set(revoked.toMap(), SetOptions(merge: true));
        await _linkedChild(guardianUid, childId)
            .set(revoked.toMap(), SetOptions(merge: true));
        await _appendChange(
          ownerId: ownerId,
          childId: childId,
          actorUid: actorUid,
          action: 'guardianRevoked',
          before: before,
          after: revoked.toMap(),
        );
      });

  Future<ChildGuardianLink?> _readOptional(ChildGuardianLink link) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _guardians(link.ownerId, link.childId).doc(link.guardianUid).get();
    if (!snap.exists) return null;
    return ChildGuardianLink.fromMap(snap.data()!, guardianUid: snap.id);
  }

  Future<void> _appendChange({
    required String ownerId,
    required String childId,
    required String actorUid,
    required String action,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _changeLog(ownerId, childId).doc();
    await ref.set(<String, dynamic>{
      'id': ref.id,
      'action': action,
      'actorUid': actorUid,
      'at': DateTime.now().toUtc().toIso8601String(),
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    });
  }
}