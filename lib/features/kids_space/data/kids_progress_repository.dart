import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/firestore_paths.dart';
import '../domain/kids_catalog.dart';
import '../domain/kids_progress.dart';

/// Progresso Kids em colecao propria + cache local.
/// Nunca le/escreve encounters, prescricoes ou financeiro.
class KidsProgressRepository {
  KidsProgressRepository(this._db);

  final FirebaseFirestore _db;
  static const String _localPrefix = 'kids_progress_v1_';

  DocumentReference<Map<String, dynamic>> _doc(String ownerUid) =>
      _db.collection(FirestorePaths.kidsPlayProgress).doc(ownerUid);

  Future<KidsProgressProfile> load(String ownerUid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _doc(ownerUid).get();
      if (snap.exists && snap.data() != null) {
        return KidsProgressProfile.fromFirestore(ownerUid, snap.data()!);
      }
    } catch (_) {
      // Offline / rules: cai no cache local.
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_localPrefix$ownerUid');
    if (raw != null && raw.isNotEmpty) {
      // Formato minimo: avatar|band|stars|muted|limit
      final List<String> parts = raw.split('|');
      return KidsProgressProfile.empty(ownerUid).copyWith(
        avatarId: parts.isNotEmpty ? parts[0] : KidsAvatar.options.first.id,
        ageBand: KidsAgeBand.values.firstWhere(
          (KidsAgeBand b) => parts.length > 1 && b.name == parts[1],
          orElse: () => KidsAgeBand.preschool,
        ),
        totalStars: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
        muted: parts.length > 3 ? parts[3] == '1' : false,
        dailyMinutesLimit: parts.length > 4 ? int.tryParse(parts[4]) ?? 30 : 30,
      );
    }
    return KidsProgressProfile.empty(ownerUid);
  }

  Future<void> save(KidsProgressProfile profile) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_localPrefix${profile.ownerUid}',
      <String>[
        profile.avatarId,
        profile.ageBand.name,
        '${profile.totalStars}',
        profile.muted ? '1' : '0',
        '${profile.dailyMinutesLimit}',
      ].join('|'),
    );
    try {
      await _doc(profile.ownerUid).set(
        profile.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (_) {
      // Persistencia remota pode falhar sem Blaze/rules publicadas; local ok.
    }
  }

  Future<KidsProgressProfile> recordWin({
    required KidsProgressProfile profile,
    required KidsGameId gameId,
    required int stars,
  }) async {
    final Map<KidsGameId, KidsGameProgress> games =
        Map<KidsGameId, KidsGameProgress>.of(profile.games);
    final KidsGameProgress prev = games[gameId] ??
        KidsGameProgress(gameId: gameId, stars: 0, plays: 0, bestStars: 0);
    final KidsGameProgress next = prev.copyWith(
      stars: stars,
      plays: prev.plays + 1,
      bestStars: stars > prev.bestStars ? stars : prev.bestStars,
    );
    games[gameId] = next;
    final int total = games.values.fold<int>(
      0,
      (int a, KidsGameProgress g) => a + g.bestStars,
    );
    final KidsProgressProfile updated = profile.copyWith(
      games: games,
      totalStars: total,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }
}
