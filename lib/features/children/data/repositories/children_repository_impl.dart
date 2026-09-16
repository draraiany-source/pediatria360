import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/firestore_paths.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/local_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/data/models/child_model.dart';
import '../../../../shared/data/models/growth_record_model.dart';
import '../../../../shared/data/models/vaccine_dose_model.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../../shared/domain/entities/vaccine.dart';
import '../../../vaccines/domain/pni_calendar.dart';
import '../../domain/repositories/children_repository.dart';

/// Implementação offline-first.
///
/// ## Estratégia de leitura
///
/// Cada `watch*` emite **duas vezes ou mais**: primeiro o que está no SQLite
/// (instantâneo, funciona sem rede), depois o que vier do Firestore. O snapshot
/// do servidor sobrescreve a tabela local, exceto nas linhas marcadas como
/// `dirty` — que são alterações do usuário ainda não enviadas e não podem ser
/// perdidas por um snapshot que ainda não as contém.
///
/// ## Estratégia de escrita
///
/// Grava no SQLite com `dirty = 1`, enfileira na outbox e retorna sucesso na
/// hora. A tela atualiza imediatamente; o envio acontece quando houver rede.
/// O usuário nunca fica esperando o servidor para ver o próprio dado.
class ChildrenRepositoryImpl implements ChildrenRepository {
  ChildrenRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required SyncService sync,
    required LocalDatabase? database,
    required String Function() currentUserId,
    required String? Function() currentUserName,
  })  : _firestore = firestore,
        _storage = storage,
        _sync = sync,
        _db = database,
        _uid = currentUserId,
        _userName = currentUserName;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final SyncService _sync;
  final LocalDatabase? _db;
  final String Function() _uid;
  final String? Function() _userName;

  static const Uuid _uuid = Uuid();

  // ------------------------------------------------------------- Crianças

  @override
  Stream<List<Child>> watchChildren() async* {
    final String ownerId = _uid();

    final List<Child> local = await _localChildren(ownerId);
    if (local.isNotEmpty) yield local;

    final Stream<QuerySnapshot<Map<String, dynamic>>> remote = _firestore
        .collection(FirestorePaths.userChildren(ownerId))
        .orderBy('birthDate', descending: true)
        .snapshots();

    await for (final QuerySnapshot<Map<String, dynamic>> snapshot in remote) {
      await _mergeChildren(
        snapshot.docs.map(ChildMapper.fromFirestore).toList(growable: false),
      );
      yield await _localChildren(ownerId);
    }
  }

  Future<List<Child>> _localChildren(String ownerId) async {
    final LocalDatabase? db = _db;
    if (db == null) return const <Child>[];
    final List<Map<String, Object?>> rows = await db.query(
      LocalDatabase.tableChildren,
      where: 'owner_id = ? AND deleted = 0',
      whereArgs: <Object?>[ownerId],
      orderBy: 'birth_date DESC',
    );
    return rows.map(ChildMapper.fromRow).toList(growable: false);
  }

  /// Grava o snapshot do servidor sem atropelar o que ainda não foi enviado.
  Future<void> _mergeChildren(List<Child> remote) async {
    final LocalDatabase? db = _db;
    if (db == null) return;

    for (final Child child in remote) {
      final Map<String, Object?>? existing = await db.queryById(
        LocalDatabase.tableChildren,
        child.id,
      );
      final bool dirty = (existing?['dirty'] as int? ?? 0) == 1;
      if (dirty) continue;

      await db.upsert(
        LocalDatabase.tableChildren,
        ChildMapper.toRow(child),
      );
    }
  }

  @override
  Stream<Child?> watchChild(String childId) =>
      watchChildren().map((List<Child> children) {
        for (final Child child in children) {
          if (child.id == childId) return child;
        }
        return null;
      });

  @override
  Future<Result<Child>> saveChild(Child child) => guard(() async {
        final String ownerId = _uid();
        final bool isNew = child.id.isEmpty;
        final Child prepared = isNew
            ? Child(
                id: _uuid.v4(),
                ownerId: ownerId,
                name: child.name,
                birthDate: child.birthDate,
                sex: child.sex,
                photoUrl: child.photoUrl,
                bloodType: child.bloodType,
                allergies: child.allergies,
                conditions: child.conditions,
                medications: child.medications,
                gestationalWeeks: child.gestationalWeeks,
                birthWeightKg: child.birthWeightKg,
                birthHeightCm: child.birthHeightCm,
                guardianName: child.guardianName?.trim().isNotEmpty == true
                    ? child.guardianName
                    : _userName(),
                guardianPhone: child.guardianPhone,
                phone: child.phone,
                address: child.address,
                cpf: child.cpf,
                insurance: child.insurance,
                updatedAt: DateTime.now(),
              )
            : child.copyWith(updatedAt: DateTime.now());

        await _db?.upsert(
          LocalDatabase.tableChildren,
          ChildMapper.toRow(prepared, dirty: true),
        );

        await _sync.enqueue(
          id: _uuid.v4(),
          entity: SyncEntity.children,
          entityId: prepared.id,
          operation:
              isNew ? OutboxOperation.create : OutboxOperation.update,
          payload: ChildMapper.toOutboxPayload(prepared),
        );

        // Quando a criança é nova, o calendário vacinal é materializado
        // localmente na hora: o responsável abre a aba de vacinas e já vê as
        // datas, mesmo sem rede.
        if (isNew) await _seedVaccineSchedule(prepared);

        return prepared.copyWith(pendingSync: true);
      });

  @override
  Future<Result<void>> deleteChild(String childId) => guard(() async {
        await _db?.softDelete(LocalDatabase.tableChildren, childId);
        await _sync.enqueue(
          id: _uuid.v4(),
          entity: SyncEntity.children,
          entityId: childId,
          operation: OutboxOperation.delete,
          payload: <String, dynamic>{'ownerId': _uid()},
        );
      });

  @override
  Future<Result<String>> uploadPhoto({
    required String childId,
    required List<int> bytes,
    required String fileName,
  }) =>
      guard(() async {
        // Upload de foto exige rede: não faz sentido enfileirar bytes de
        // imagem na outbox, que é feita para payloads pequenos de texto.
        final Reference ref = _storage
            .ref()
            .child('users/${_uid()}/children/$childId/$fileName');

        final TaskSnapshot snapshot = await ref.putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: _contentTypeFor(fileName)),
        );
        return snapshot.ref.getDownloadURL();
      });

  static String _contentTypeFor(String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // ----------------------------------------------------------- Crescimento

  @override
  Stream<List<GrowthRecord>> watchGrowth(String childId) async* {
    final String ownerId = _uid();

    final List<GrowthRecord> local = await _localGrowth(childId);
    if (local.isNotEmpty) yield local;

    final Stream<QuerySnapshot<Map<String, dynamic>>> remote = _firestore
        .collection(FirestorePaths.childGrowth(ownerId, childId))
        .orderBy('measuredAt')
        .snapshots();

    await for (final QuerySnapshot<Map<String, dynamic>> snapshot in remote) {
      final LocalDatabase? db = _db;
      if (db != null) {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, Object?>? existing =
              await db.queryById(LocalDatabase.tableGrowth, doc.id);
          if ((existing?['dirty'] as int? ?? 0) == 1) continue;
          await db.upsert(
            LocalDatabase.tableGrowth,
            GrowthRecordMapper.toRow(
              GrowthRecordMapper.fromFirestore(doc, childId),
            ),
          );
        }
      }
      yield await _localGrowth(childId);
    }
  }

  Future<List<GrowthRecord>> _localGrowth(String childId) async {
    final LocalDatabase? db = _db;
    if (db == null) return const <GrowthRecord>[];
    final List<Map<String, Object?>> rows = await db.query(
      LocalDatabase.tableGrowth,
      where: 'child_id = ? AND deleted = 0',
      whereArgs: <Object?>[childId],
      orderBy: 'measured_at ASC',
    );
    return rows.map(GrowthRecordMapper.fromRow).toList(growable: false);
  }

  @override
  Future<Result<GrowthRecord>> saveGrowth(GrowthRecord record) =>
      guard(() async {
        final bool isNew = record.id.isEmpty;
        final GrowthRecord prepared = isNew
            ? GrowthRecord(
                id: _uuid.v4(),
                childId: record.childId,
                measuredAt: record.measuredAt,
                updatedAt: DateTime.now(),
                weightKg: record.weightKg,
                heightCm: record.heightCm,
                headCircumferenceCm: record.headCircumferenceCm,
                note: record.note,
              )
            : record.copyWith(updatedAt: DateTime.now());

        await _db?.upsert(
          LocalDatabase.tableGrowth,
          GrowthRecordMapper.toRow(prepared, dirty: true),
        );

        await _sync.enqueue(
          id: _uuid.v4(),
          entity: SyncEntity.growth,
          entityId: prepared.id,
          operation:
              isNew ? OutboxOperation.create : OutboxOperation.update,
          payload: GrowthRecordMapper.toOutboxPayload(prepared, _uid()),
        );

        return prepared.copyWith(pendingSync: true);
      });

  @override
  Future<Result<void>> deleteGrowth({
    required String childId,
    required String recordId,
  }) =>
      guard(() async {
        await _db?.softDelete(LocalDatabase.tableGrowth, recordId);
        await _sync.enqueue(
          id: _uuid.v4(),
          entity: SyncEntity.growth,
          entityId: recordId,
          operation: OutboxOperation.delete,
          payload: <String, dynamic>{'ownerId': _uid(), 'childId': childId},
        );
      });

  // --------------------------------------------------------------- Vacinas

  @override
  Stream<List<VaccineDose>> watchVaccineDoses(String childId) async* {
    final String ownerId = _uid();

    final List<VaccineDose> local = await _localDoses(childId);
    if (local.isNotEmpty) yield local;

    final Stream<QuerySnapshot<Map<String, dynamic>>> remote = _firestore
        .collection(FirestorePaths.childVaccines(ownerId, childId))
        .snapshots();

    await for (final QuerySnapshot<Map<String, dynamic>> snapshot in remote) {
      final LocalDatabase? db = _db;
      if (db != null) {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, Object?>? existing =
              await db.queryById(LocalDatabase.tableVaccineDoses, doc.id);
          if ((existing?['dirty'] as int? ?? 0) == 1) continue;
          await db.upsert(
            LocalDatabase.tableVaccineDoses,
            VaccineDoseMapper.toRow(
              VaccineDoseMapper.fromFirestore(doc, childId),
            ),
          );
        }
      }
      yield await _localDoses(childId);
    }
  }

  Future<List<VaccineDose>> _localDoses(String childId) async {
    final LocalDatabase? db = _db;
    if (db == null) return const <VaccineDose>[];
    final List<Map<String, Object?>> rows = await db.query(
      LocalDatabase.tableVaccineDoses,
      where: 'child_id = ? AND deleted = 0',
      whereArgs: <Object?>[childId],
      orderBy: 'due_at ASC',
    );
    return rows.map(VaccineDoseMapper.fromRow).toList(growable: false);
  }

  @override
  Future<Result<VaccineDose>> saveVaccineDose(VaccineDose dose) =>
      guard(() async {
        final VaccineDose prepared = dose.copyWith(updatedAt: DateTime.now());

        await _db?.upsert(
          LocalDatabase.tableVaccineDoses,
          VaccineDoseMapper.toRow(prepared, dirty: true),
        );

        await _sync.enqueue(
          id: _uuid.v4(),
          entity: SyncEntity.vaccineDoses,
          entityId: prepared.id,
          operation: OutboxOperation.update,
          payload: VaccineDoseMapper.toOutboxPayload(prepared, _uid()),
        );

        return prepared.copyWith(pendingSync: true);
      });

  /// Cria as doses previstas a partir da data de nascimento.
  Future<void> _seedVaccineSchedule(Child child) async {
    final LocalDatabase? db = _db;
    if (db == null) return;

    try {
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[];

      for (final VaccineDose dose in _scheduleFor(child)) {
        rows.add(VaccineDoseMapper.toRow(dose));
      }
      await db.upsertAll(LocalDatabase.tableVaccineDoses, rows);
    } catch (error, stack) {
      // Falhar aqui não pode impedir o cadastro da criança: as doses são
      // recriadas na primeira abertura da aba de vacinas.
      await AppLogger.error(error, stack, reason: 'seedVaccineSchedule');
    }
  }

  Iterable<VaccineDose> _scheduleFor(Child child) sync* {
    for (final VaccineDoseSchedule schedule in PniCalendar.schedule) {
      yield VaccineDose(
        id: '${child.id}-${schedule.vaccineId}-${schedule.doseIndex}',
        childId: child.id,
        vaccineId: schedule.vaccineId,
        doseIndex: schedule.doseIndex,
        dueAt: PniCalendar.dueDateFor(child.birthDate, schedule),
        updatedAt: DateTime.now(),
      );
    }
  }
}
