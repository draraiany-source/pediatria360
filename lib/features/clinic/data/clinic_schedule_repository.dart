import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../domain/agenda_scheduling.dart';

class ClinicRoom {
  const ClinicRoom({
    required this.id,
    required this.name,
    this.unitId = '',
    this.active = true,
  });

  factory ClinicRoom.fromMap(Map<String, dynamic> map, {required String id}) =>
      ClinicRoom(
        id: id,
        name: (map['name'] as String?) ?? '',
        unitId: (map['unitId'] as String?) ?? '',
        active: (map['active'] as bool?) ?? true,
      );

  final String id;
  final String name;
  final String unitId;
  final bool active;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'unitId': unitId,
        'active': active,
      };
}

/// Salas e bloqueios de agenda por clinica (sem segunda agenda).
class ClinicScheduleRepository {
  ClinicScheduleRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _rooms(String clinicId) =>
      _firestore.collection('clinics').doc(clinicId).collection('rooms');

  CollectionReference<Map<String, dynamic>> _blocks(String clinicId) =>
      _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('schedule_blocks');

  Stream<List<ClinicRoom>> watchRooms(String clinicId) =>
      _rooms(clinicId).snapshots().map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      ClinicRoom.fromMap(d.data(), id: d.id),
                )
                .toList(growable: false),
          );

  Stream<List<ScheduleBlock>> watchBlocks(String clinicId) =>
      _blocks(clinicId).snapshots().map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) {
              final Map<String, dynamic> m = d.data();
              return ScheduleBlock(
                id: d.id,
                startsAt: DateTime.tryParse((m['startsAt'] as String?) ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                endsAt: DateTime.tryParse((m['endsAt'] as String?) ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                professionalId: (m['professionalId'] as String?) ?? '',
                roomId: (m['roomId'] as String?) ?? '',
                reason: (m['reason'] as String?) ?? '',
              );
            }).toList(growable: false),
          );

  Future<Result<void>> upsertRoom({
    required String clinicId,
    required ClinicRoom room,
    required ClinicMembership? membership,
  }) =>
      guard(() async {
        _requireAdmin(membership, clinicId);
        await _rooms(clinicId).doc(room.id).set(room.toMap(), SetOptions(merge: true));
      });

  Future<Result<void>> upsertBlock({
    required String clinicId,
    required ScheduleBlock block,
    required ClinicMembership? membership,
  }) =>
      guard(() async {
        _requireAdmin(membership, clinicId);
        await _blocks(clinicId).doc(block.id).set(<String, dynamic>{
          'startsAt': block.startsAt.toIso8601String(),
          'endsAt': block.endsAt.toIso8601String(),
          'professionalId': block.professionalId,
          'roomId': block.roomId,
          'reason': block.reason,
        }, SetOptions(merge: true));
      });

  void _requireAdmin(ClinicMembership? membership, String clinicId) {
    if (membership == null ||
        !membership.active ||
        membership.clinicId != clinicId ||
        membership.role != ClinicRole.clinicAdmin) {
      throw const PermissionFailure(
        'Apenas administrador da clinica pode configurar salas/bloqueios.',
      );
    }
  }
}