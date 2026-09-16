import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/firestore_paths.dart';
import 'app_logger.dart';
import 'connectivity_service.dart';
import 'local_database.dart';
import 'sync_conflict.dart';

/// Entidades que participam da sincronizacao offline.
class SyncEntity {
  const SyncEntity._();

  static const String children = 'children';
  static const String growth = 'growth_records';
  static const String vaccineDoses = 'vaccine_doses';
}

/// Estado publico da sincronizacao, exibido na UI.
@immutable
class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.pending = 0,
    this.lastSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final int pending;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get hasPending => pending > 0;

  SyncStatus copyWith({
    bool? isSyncing,
    int? pending,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        isSyncing: isSyncing ?? this.isSyncing,
        pending: pending ?? this.pending,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// Drena a fila de escritas feitas offline.
///
/// Por que uma outbox propria se o Firestore ja tem fila offline nativa?
/// Porque a fila do SDK e opaca: nao da para mostrar ao usuario quantas
/// alteracoes faltam, nem reordenar, nem descartar um item envenenado. Para
/// dado de saude — "registrei a vacina e nao sei se salvou" — essa visibilidade
/// e requisito, nao luxo.
///
/// Politica de conflito: **ultima escrita vence, por horario do dispositivo**.
/// Cada linha carrega `updatedAt`; se o servidor tiver versao mais nova, a
/// escrita local e descartada. Funciona porque o dado e sempre de um unico dono
/// (o responsavel pela crianca) — nao ha edicao concorrente entre pessoas.
class SyncService {
  SyncService({
    required LocalDatabase? database,
    required FirebaseFirestore firestore,
    required ConnectivityService connectivity,
  })  : _db = database,
        _firestore = firestore,
        _connectivity = connectivity {
    _subscription = _connectivity.onStatusChange.listen((bool online) {
      if (online) unawaited(sync());
    });
    unawaited(_refreshPending());
  }

  final LocalDatabase? _db;
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivity;

  late final StreamSubscription<bool> _subscription;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status = const SyncStatus();

  SyncStatus get status => _status;
  Stream<SyncStatus> get onStatusChange => _statusController.stream;

  bool _running = false;

  void _emit(SyncStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  Future<void> _refreshPending() async {
    if (_db == null) return;
    final int pending = await _db.pendingOutboxCount();
    _emit(_status.copyWith(pending: pending));
  }

  /// Processa a fila. Seguro chamar a qualquer momento: se ja estiver rodando
  /// ou estiver offline, retorna sem fazer nada.
  Future<void> sync() async {
    if (_db == null || _running || _connectivity.isOffline) return;

    _running = true;
    _emit(_status.copyWith(isSyncing: true, clearError: true));

    try {
      List<OutboxEntry> batch = await _db.pendingOutbox();

      while (batch.isNotEmpty && _connectivity.isOnline) {
        for (final OutboxEntry entry in batch) {
          await _process(entry);
        }
        batch = await _db.pendingOutbox();
        // Se todos os itens da rodada falharam e continuam na fila com
        // tentativas crescendo, `_process` acabara descartando os envenenados,
        // entao o laco sempre termina.
        if (batch.isNotEmpty && batch.every((OutboxEntry e) => e.attempts > 0)) {
          final int stillPending = await _db.pendingOutboxCount();
          if (stillPending == batch.length &&
              batch.first.attempts >= OutboxEntry.poisonThreshold) {
            break;
          }
        }
      }

      await _db.setLastSyncAt(SyncEntity.children, DateTime.now());
      await _refreshPending();
      _emit(_status.copyWith(isSyncing: false, lastSyncAt: DateTime.now()));
    } catch (error, stack) {
      await AppLogger.error(error, stack, reason: 'sync');
      _emit(
        _status.copyWith(
          isSyncing: false,
          lastError: 'Nao foi possivel sincronizar agora.',
        ),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _process(OutboxEntry entry) async {
    final LocalDatabase db = _db!;

    // Backoff: item que falhou há pouco não é tentado de novo agora.
    // Repetir a cada ciclo contra um servidor fora do ar queima bateria e
    // não acelera nada.
    if (!SyncBackoff.isReady(
      attempts: entry.attempts,
      lastAttemptAt: entry.lastAttemptAt,
    )) {
      return;
    }

    if (entry.isPoisoned) {
      // Item que falha sempre trava a fila inteira. Sai, com registro para a
      // equipe investigar — o dado local continua marcado como pendente.
      await AppLogger.error(
        StateError('Item de sincronizacao descartado apos 5 tentativas'),
        StackTrace.current,
        reason: 'sync.poisoned',
        context: <String, Object>{
          'entity': entry.entity,
          'entityId': entry.entityId,
          'lastError': entry.lastError ?? 'desconhecido',
        },
      );
      await db.recordSyncEvent(
        SyncEvent(
          id: entry.id,
          at: DateTime.now(),
          entity: entry.entity,
          entityId: entry.entityId,
          outcome: SyncOutcome.abandoned,
          error: entry.lastError,
          attempts: entry.attempts,
        ),
      );
      await db.dequeue(entry.id);
      return;
    }

    try {
      await db.markOutboxAttempted(entry.id);
      final DocumentReference<Map<String, dynamic>> ref =
          _referenceFor(entry);

      switch (entry.operation) {
        case OutboxOperation.create:
        case OutboxOperation.update:
          final ConflictResolution resolution =
              await _resolveConflict(ref, entry);

          if (!resolution.shouldWrite) {
            // A versão do servidor prevaleceu inteira. Registra para o
            // usuário poder conferir o que aconteceu com o dado dele.
            await db.recordSyncEvent(
              SyncEvent(
                id: entry.id,
                at: DateTime.now(),
                entity: entry.entity,
                entityId: entry.entityId,
                outcome: SyncOutcome.discardedLocal,
                strategy: resolution.strategy.name,
                conflictedFields: resolution.conflictedFields,
                attempts: entry.attempts,
              ),
            );
            await db.dequeue(entry.id);
            await _clearDirty(entry);
            return;
          }

          await ref.set(
            <String, dynamic>{
              ...resolution.merged!,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          await db.recordSyncEvent(
            SyncEvent(
              id: entry.id,
              at: DateTime.now(),
              entity: entry.entity,
              entityId: entry.entityId,
              outcome: resolution.hasConflict
                  ? SyncOutcome.merged
                  : SyncOutcome.sent,
              strategy: resolution.strategy.name,
              conflictedFields: resolution.conflictedFields,
              attempts: entry.attempts,
            ),
          );

        case OutboxOperation.delete:
          await ref.delete();
      }

      await db.dequeue(entry.id);
      await _clearDirty(entry);
    } catch (error, stack) {
      await db.markOutboxError(entry.id, error.toString());
      await db.recordSyncEvent(
        SyncEvent(
          id: '${entry.id}-${DateTime.now().microsecondsSinceEpoch}',
          at: DateTime.now(),
          entity: entry.entity,
          entityId: entry.entityId,
          outcome: SyncOutcome.failed,
          error: error.toString(),
          attempts: entry.attempts + 1,
        ),
      );
      await AppLogger.error(
        error,
        stack,
        reason: 'sync.${entry.entity}.${entry.operation.name}',
      );
    }
  }

  /// Decide o que gravar quando o servidor mudou desde a escrita local.
  ///
  /// Substitui a política anterior de "servidor mais novo vence", que
  /// descartava o dado do usuário em silêncio usando o relógio do aparelho
  /// como critério. Ver [ConflictResolver] para a estratégia de cada entidade.
  Future<ConflictResolution> _resolveConflict(
    DocumentReference<Map<String, dynamic>> ref,
    OutboxEntry entry,
  ) async {
    final Map<String, dynamic> local = _firestorePayload(entry);

    // Criação não tem com o que conflitar.
    if (entry.operation == OutboxOperation.create) {
      return ConflictResolution(
        strategy: ConflictResolver.strategyFor(entry.entity),
        merged: local,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();

    // Documento não existe mais no servidor: a escrita local recria.
    if (!snapshot.exists) {
      return ConflictResolution(
        strategy: ConflictResolver.strategyFor(entry.entity),
        merged: local,
      );
    }

    final Object? updatedAt = snapshot.data()?['updatedAt'];
    final bool serverChanged = updatedAt is Timestamp &&
        updatedAt.toDate().isAfter(entry.createdAt);

    // Servidor intocado desde a escrita local: sem conflito.
    if (!serverChanged) {
      return ConflictResolution(
        strategy: ConflictResolver.strategyFor(entry.entity),
        merged: local,
      );
    }

    return ConflictResolver.resolve(
      entity: entry.entity,
      local: local,
      remote: snapshot.data() ?? const <String, dynamic>{},
    );
  }

  Future<void> _clearDirty(OutboxEntry entry) async {
    final String? table = switch (entry.entity) {
      SyncEntity.children => LocalDatabase.tableChildren,
      SyncEntity.growth => LocalDatabase.tableGrowth,
      SyncEntity.vaccineDoses => LocalDatabase.tableVaccineDoses,
      _ => null,
    };
    if (table == null) return;

    if (entry.operation == OutboxOperation.delete) {
      await _db!.hardDelete(table, entry.entityId);
      return;
    }
    await _db!.upsert(table, <String, Object?>{
      'id': entry.entityId,
      'dirty': 0,
    });
  }

  DocumentReference<Map<String, dynamic>> _referenceFor(OutboxEntry entry) {
    final String ownerId = entry.payload['ownerId'] as String? ?? '';
    final String childId = entry.payload['childId'] as String? ?? '';

    return switch (entry.entity) {
      SyncEntity.children => _firestore
          .doc(FirestorePaths.childDoc(ownerId, entry.entityId)),
      SyncEntity.growth => _firestore
          .collection(FirestorePaths.childGrowth(ownerId, childId))
          .doc(entry.entityId),
      SyncEntity.vaccineDoses => _firestore
          .collection(FirestorePaths.childVaccines(ownerId, childId))
          .doc(entry.entityId),
      _ => throw StateError('Entidade desconhecida: ${entry.entity}'),
    };
  }

  /// Remove campos de controle e converte datas ISO em `Timestamp`.
  Map<String, dynamic> _firestorePayload(OutboxEntry entry) {
    final Map<String, dynamic> payload =
        Map<String, dynamic>.from(entry.payload);

    for (final String key in <String>['birthDate', 'measuredAt', 'appliedAt', 'dueAt']) {
      final Object? value = payload[key];
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) payload[key] = Timestamp.fromDate(parsed);
      }
    }

    payload['updatedAt'] = FieldValue.serverTimestamp();
    return payload;
  }

  /// Enfileira uma escrita e tenta enviar na hora, se houver rede.
  Future<void> enqueue({
    required String id,
    required String entity,
    required String entityId,
    required OutboxOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    if (_db == null) return;

    await _db.enqueue(
      id: id,
      entity: entity,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
    await _refreshPending();

    if (_connectivity.isOnline) unawaited(sync());
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _statusController.close();
  }
}
