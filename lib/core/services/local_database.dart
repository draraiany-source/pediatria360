import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../error/exceptions.dart';
import 'sync_conflict.dart';

/// Banco relacional local (SQLite) do Offline First.
///
/// Divisao de responsabilidade entre as duas persistencias locais:
/// - **Hive (`CacheService`)**: cache volatil de leitura — feed, artigos,
///   catalogos. Pode ser apagado sem perda de dado do usuario.
/// - **SQLite (esta classe)**: dado do usuario que precisa sobreviver e ser
///   consultado (crescimento, vacinas, prontuario) e a *outbox* de escritas
///   pendentes, que precisa de transacao e ordem garantida.
///
/// No Flutter Web o `sqflite` nao esta disponivel; ali o app opera apenas com
/// Hive + a persistencia offline nativa do Firestore. Toda chamada e protegida
/// por [isSupported].
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static const String dbName = 'pediatria360.db';
  /// Versão do schema local.
  ///
  /// v2: tabela `sync_log` (histórico de sincronização) e coluna
  ///     `last_attempt_at` na outbox, para o backoff saber quando esperar.
  static const int dbVersion = 2;

  // Tabelas
  static const String tableChildren = 'children';
  static const String tableGrowth = 'growth_records';
  static const String tableVaccineDoses = 'vaccine_doses';
  static const String tableOutbox = 'outbox';
  static const String tableSyncState = 'sync_state';

  /// Histórico de sincronização. Responde à pergunta que o usuário faz quando
  /// algo some: "o que aconteceu com o registro que fiz ontem?".
  static const String tableSyncLog = 'sync_log';

  /// SQLite roda em Android, iOS, macOS, Windows e Linux — nao na web.
  static bool get isSupported => !kIsWeb;

  static Future<LocalDatabase> open() async {
    if (!isSupported) {
      throw const CacheException(
        'SQLite nao esta disponivel nesta plataforma.',
        code: 'unsupported',
      );
    }
    final String path = p.join(await getDatabasesPath(), dbName);
    final Database db = await openDatabase(
      path,
      version: dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return LocalDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE $tableChildren (
        id            TEXT PRIMARY KEY,
        owner_id      TEXT NOT NULL,
        name          TEXT NOT NULL,
        birth_date    INTEGER NOT NULL,
        sex           TEXT NOT NULL,
        photo_url     TEXT,
        blood_type    TEXT,
        allergies     TEXT,
        conditions    TEXT,
        updated_at    INTEGER NOT NULL,
        dirty         INTEGER NOT NULL DEFAULT 0,
        deleted       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_children_owner ON $tableChildren(owner_id, deleted)',
    );

    batch.execute('''
      CREATE TABLE $tableGrowth (
        id            TEXT PRIMARY KEY,
        child_id      TEXT NOT NULL,
        measured_at   INTEGER NOT NULL,
        weight_kg     REAL,
        height_cm     REAL,
        head_cm       REAL,
        note          TEXT,
        updated_at    INTEGER NOT NULL,
        dirty         INTEGER NOT NULL DEFAULT 0,
        deleted       INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (child_id) REFERENCES $tableChildren (id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_growth_child ON $tableGrowth(child_id, measured_at DESC)',
    );

    batch.execute('''
      CREATE TABLE $tableVaccineDoses (
        id            TEXT PRIMARY KEY,
        child_id      TEXT NOT NULL,
        vaccine_id    TEXT NOT NULL,
        dose_index    INTEGER NOT NULL,
        due_at        INTEGER,
        applied_at    INTEGER,
        lot           TEXT,
        clinic        TEXT,
        proof_url     TEXT,
        updated_at    INTEGER NOT NULL,
        dirty         INTEGER NOT NULL DEFAULT 0,
        deleted       INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (child_id) REFERENCES $tableChildren (id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_doses_child ON $tableVaccineDoses(child_id, due_at)',
    );

    // Outbox: fila de escritas feitas offline, drenada em ordem de criacao.
    batch.execute('''
      CREATE TABLE $tableOutbox (
        id            TEXT PRIMARY KEY,
        entity        TEXT NOT NULL,
        entity_id     TEXT NOT NULL,
        operation     TEXT NOT NULL,
        payload       TEXT NOT NULL,
        created_at    INTEGER NOT NULL,
        attempts      INTEGER NOT NULL DEFAULT 0,
        last_error    TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_outbox_created ON $tableOutbox(created_at ASC)',
    );

    batch.execute('''
      CREATE TABLE $tableSyncLog (
        id                 TEXT PRIMARY KEY,
        at                 INTEGER NOT NULL,
        entity             TEXT NOT NULL,
        entity_id          TEXT NOT NULL,
        outcome            TEXT NOT NULL,
        strategy           TEXT,
        conflicted_fields  TEXT,
        error              TEXT,
        attempts           INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_sync_log_at ON $tableSyncLog(at DESC)',
    );

    batch.execute('''
      CREATE TABLE $tableSyncState (
        entity        TEXT PRIMARY KEY,
        last_sync_at  INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Cada migração é idempotente e cumulativa: quem pula versões passa por
    // todas em ordem. Perder o banco local significaria perder o que ainda
    // não foi enviado.
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSyncLog (
          id                 TEXT PRIMARY KEY,
          at                 INTEGER NOT NULL,
          entity             TEXT NOT NULL,
          entity_id          TEXT NOT NULL,
          outcome            TEXT NOT NULL,
          strategy           TEXT,
          conflicted_fields  TEXT,
          error              TEXT,
          attempts           INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_at '
        'ON $tableSyncLog(at DESC)',
      );

      // SQLite não tem "ADD COLUMN IF NOT EXISTS"; a falha é esperada quando
      // a coluna já existe e não deve interromper a migração.
      try {
        await db.execute(
          'ALTER TABLE $tableOutbox ADD COLUMN last_attempt_at INTEGER',
        );
      } catch (_) {
        // coluna já presente
      }
    }
  }

  // ------------------------------------------------------------------ CRUD

  Future<void> upsert(String table, Map<String, Object?> row) async {
    await _db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final Batch batch = _db.batch();
    for (final Map<String, Object?> row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  Future<Map<String, Object?>?> queryById(String table, String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Marca como excluido (soft delete) para que a exclusao possa ser
  /// sincronizada quando a conexao voltar.
  Future<void> softDelete(String table, String id) async {
    await _db.update(
      table,
      <String, Object?>{
        'deleted': 1,
        'dirty': 1,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> hardDelete(String table, String id) =>
      _db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);

  // --------------------------------------------------------------- Outbox

  Future<void> enqueue({
    required String id,
    required String entity,
    required String entityId,
    required OutboxOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    await _db.insert(
      tableOutbox,
      <String, Object?>{
        'id': id,
        'entity': entity,
        'entity_id': entityId,
        'operation': operation.name,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'attempts': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OutboxEntry>> pendingOutbox({int limit = 50}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      tableOutbox,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList(growable: false);
  }

  Future<int> pendingOutboxCount() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableOutbox',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> dequeue(String id) =>
      _db.delete(tableOutbox, where: 'id = ?', whereArgs: <Object?>[id]);

  Future<void> markOutboxError(String id, String error) async {
    await _db.rawUpdate(
      'UPDATE $tableOutbox SET attempts = attempts + 1, last_error = ? '
      'WHERE id = ?',
      <Object?>[error, id],
    );
  }

  /// Registra um evento no histórico de sincronização.
  ///
  /// Mantém no máximo 500 eventos: o histórico serve para diagnosticar o que
  /// aconteceu nos últimos dias, não para ser um arquivo permanente.
  Future<void> recordSyncEvent(SyncEvent event) async {
    await _db.insert(
      tableSyncLog,
      event.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _db.rawDelete(
      'DELETE FROM $tableSyncLog WHERE id NOT IN ('
      'SELECT id FROM $tableSyncLog ORDER BY at DESC LIMIT 500)',
    );
  }

  /// Histórico, do mais recente para o mais antigo.
  Future<List<SyncEvent>> syncHistory({
    int limit = 100,
    bool onlyProblems = false,
  }) async {
    final List<Map<String, Object?>> rows = await _db.query(
      tableSyncLog,
      where: onlyProblems
          ? 'outcome IN (?, ?, ?)'
          : null,
      whereArgs: onlyProblems
          ? <Object?>['failed', 'abandoned', 'discardedLocal']
          : null,
      orderBy: 'at DESC',
      limit: limit,
    );
    return rows.map(SyncEvent.fromRow).toList(growable: false);
  }

  /// Registra o momento da última tentativa, para o backoff saber esperar.
  Future<void> markOutboxAttempted(String id) async {
    await _db.rawUpdate(
      'UPDATE $tableOutbox SET last_attempt_at = ? WHERE id = ?',
      <Object?>[DateTime.now().toUtc().millisecondsSinceEpoch, id],
    );
  }

  /// Zera o contador de tentativas dos itens travados.
  ///
  /// Um item vira "envenenado" após 5 falhas e para de ser tentado. Quando a
  /// causa é corrigida do lado do servidor — permissão concedida, documento
  /// recriado — zerar o contador devolve o item à fila normal em vez de exigir
  /// que o usuário registre tudo de novo.
  Future<int> resetOutboxAttempts() async {
    return _db.rawUpdate(
      'UPDATE $tableOutbox SET attempts = 0, last_error = NULL '
      'WHERE attempts >= ?',
      <Object?>[OutboxEntry.poisonThreshold],
    );
  }

  /// Remove um item da fila sem enviá-lo.
  ///
  /// Descarta a alteração de vez. Só deve ser chamado com confirmação
  /// explícita do usuário e mostrando o que será perdido.
  Future<void> removeOutboxEntry(String id) => dequeue(id);

  /// Limpa registros locais e a fila — usado no logout.
  Future<void> wipe() async {
    final Batch batch = _db.batch();
    for (final String table in <String>[
      tableOutbox,
      tableVaccineDoses,
      tableGrowth,
      tableChildren,
      tableSyncState,
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  // ----------------------------------------------------------- Sync state

  Future<DateTime?> lastSyncAt(String entity) async {
    final List<Map<String, Object?>> rows = await _db.query(
      tableSyncState,
      where: 'entity = ?',
      whereArgs: <Object?>[entity],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.first['last_sync_at']! as int,
      isUtc: true,
    );
  }

  Future<void> setLastSyncAt(String entity, DateTime at) => _db.insert(
        tableSyncState,
        <String, Object?>{
          'entity': entity,
          'last_sync_at': at.toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> close() => _db.close();
}

/// Operacao registrada na outbox.
enum OutboxOperation { create, update, delete }

/// Item da fila de sincronizacao.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastAttemptAt,
    this.lastError,
  });

  factory OutboxEntry.fromRow(Map<String, Object?> row) => OutboxEntry(
        id: row['id']! as String,
        entity: row['entity']! as String,
        entityId: row['entity_id']! as String,
        operation: OutboxOperation.values.firstWhere(
          (OutboxOperation o) => o.name == row['operation'],
          orElse: () => OutboxOperation.update,
        ),
        payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
          isUtc: true,
        ),
        attempts: (row['attempts'] as int?) ?? 0,
        lastAttemptAt: row['last_attempt_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['last_attempt_at']! as int,
                isUtc: true,
              ).toLocal(),
        lastError: row['last_error'] as String?,
      );

  final String id;
  final String entity;
  final String entityId;
  final OutboxOperation operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  /// Momento da última tentativa de envio. Alimenta o cálculo de espera.
  final DateTime? lastAttemptAt;
  final String? lastError;

  /// Apos [poisonThreshold] tentativas o item e considerado envenenado e sai
  /// da fila, registrando o erro no Crashlytics — melhor perder uma escrita
  /// do que travar a fila inteira para sempre.
  static const int poisonThreshold = 5;

  bool get isPoisoned => attempts >= poisonThreshold;
}
