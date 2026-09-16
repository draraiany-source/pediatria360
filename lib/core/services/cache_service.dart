import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../error/exceptions.dart';

/// Cache chave/valor sobre Hive, com TTL por entrada.
///
/// Guarda JSON serializado (nao objetos com adapter): o schema do conteudo
/// medico muda com frequencia e um adapter binario obrigaria migracao a cada
/// campo novo. JSON e mais barato de evoluir e ainda e rapido o suficiente.
class CacheService {
  CacheService(this._box);

  final Box<String> _box;

  static const String boxName = 'p360_cache';

  /// Abre a box. Chamado uma vez no bootstrap.
  static Future<CacheService> open() async {
    final Box<String> box = await Hive.openBox<String>(boxName);
    return CacheService(box);
  }

  /// Grava [value] sob [key], com validade opcional.
  Future<void> write(
    String key,
    Object value, {
    Duration? ttl,
  }) async {
    try {
      final Map<String, dynamic> envelope = <String, dynamic>{
        'v': value,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
        'ttl': ttl?.inMilliseconds,
      };
      await _box.put(key, jsonEncode(envelope));
    } catch (e) {
      throw CacheException('Falha ao gravar cache.', code: key, cause: e);
    }
  }

  /// Le [key]. Devolve `null` se ausente ou expirado.
  T? read<T>(String key) {
    final String? raw = _box.get(key);
    if (raw == null) return null;

    try {
      final Map<String, dynamic> envelope =
          jsonDecode(raw) as Map<String, dynamic>;
      final int ts = envelope['ts'] as int;
      final int? ttl = envelope['ttl'] as int?;

      if (ttl != null) {
        final int age =
            DateTime.now().toUtc().millisecondsSinceEpoch - ts;
        if (age > ttl) {
          _box.delete(key);
          return null;
        }
      }
      return envelope['v'] as T?;
    } catch (_) {
      _box.delete(key);
      return null;
    }
  }

  /// Le uma lista de mapas (padrao para listas de documentos do Firestore).
  List<Map<String, dynamic>> readList(String key) {
    final List<dynamic>? raw = read<List<dynamic>>(key);
    if (raw == null) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  Map<String, dynamic>? readMap(String key) {
    final Map<dynamic, dynamic>? raw = read<Map<dynamic, dynamic>>(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Idade da entrada, util para exibir "atualizado ha X".
  DateTime? writtenAt(String key) {
    final String? raw = _box.get(key);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> envelope =
          jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.fromMillisecondsSinceEpoch(
        envelope['ts'] as int,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool contains(String key) => _box.containsKey(key);

  Future<void> delete(String key) => _box.delete(key);

  /// Remove todas as entradas cujo nome comece com [prefix].
  Future<void> deleteWhereKeyStartsWith(String prefix) async {
    final Iterable<String> keys = _box.keys
        .cast<String>()
        .where((String k) => k.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  Future<void> clear() => _box.clear();
}
