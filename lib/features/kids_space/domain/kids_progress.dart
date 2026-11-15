import 'kids_catalog.dart';

class KidsGameProgress {
  const KidsGameProgress({
    required this.gameId,
    required this.stars,
    required this.plays,
    required this.bestStars,
  });

  final KidsGameId gameId;
  final int stars;
  final int plays;
  final int bestStars;

  KidsGameProgress copyWith({int? stars, int? plays, int? bestStars}) =>
      KidsGameProgress(
        gameId: gameId,
        stars: stars ?? this.stars,
        plays: plays ?? this.plays,
        bestStars: bestStars ?? this.bestStars,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'gameId': gameId.name,
        'stars': stars,
        'plays': plays,
        'bestStars': bestStars,
      };

  static KidsGameProgress fromMap(Map<String, dynamic> map) {
    final String raw = map['gameId'] as String? ?? KidsGameId.memory.name;
    final KidsGameId id = KidsGameId.values.firstWhere(
      (KidsGameId e) => e.name == raw,
      orElse: () => KidsGameId.memory,
    );
    return KidsGameProgress(
      gameId: id,
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      plays: (map['plays'] as num?)?.toInt() ?? 0,
      bestStars: (map['bestStars'] as num?)?.toInt() ?? 0,
    );
  }
}

class KidsProgressProfile {
  const KidsProgressProfile({
    required this.ownerUid,
    required this.avatarId,
    required this.ageBand,
    required this.totalStars,
    required this.games,
    required this.updatedAt,
    this.clinicId,
    this.dailyMinutesLimit = 30,
    this.muted = false,
  });

  final String ownerUid;
  final String avatarId;
  final KidsAgeBand ageBand;
  final int totalStars;
  final Map<KidsGameId, KidsGameProgress> games;
  final DateTime updatedAt;
  final String? clinicId;
  final int dailyMinutesLimit;
  final bool muted;

  KidsProgressProfile copyWith({
    String? avatarId,
    KidsAgeBand? ageBand,
    int? totalStars,
    Map<KidsGameId, KidsGameProgress>? games,
    DateTime? updatedAt,
    String? clinicId,
    int? dailyMinutesLimit,
    bool? muted,
  }) =>
      KidsProgressProfile(
        ownerUid: ownerUid,
        avatarId: avatarId ?? this.avatarId,
        ageBand: ageBand ?? this.ageBand,
        totalStars: totalStars ?? this.totalStars,
        games: games ?? this.games,
        updatedAt: updatedAt ?? this.updatedAt,
        clinicId: clinicId ?? this.clinicId,
        dailyMinutesLimit: dailyMinutesLimit ?? this.dailyMinutesLimit,
        muted: muted ?? this.muted,
      );

  Map<String, Object?> toFirestore() => <String, Object?>{
        'ownerUid': ownerUid,
        'avatarId': avatarId,
        'ageBand': ageBand.name,
        'totalStars': totalStars,
        'dailyMinutesLimit': dailyMinutesLimit,
        'muted': muted,
        if (clinicId != null) 'clinicId': clinicId,
        'updatedAt': updatedAt.toIso8601String(),
        'games': <String, Object?>{
          for (final MapEntry<KidsGameId, KidsGameProgress> e in games.entries)
            e.key.name: e.value.toMap(),
        },
      };

  static KidsProgressProfile empty(String ownerUid) => KidsProgressProfile(
        ownerUid: ownerUid,
        avatarId: KidsAvatar.options.first.id,
        ageBand: KidsAgeBand.preschool,
        totalStars: 0,
        games: <KidsGameId, KidsGameProgress>{},
        updatedAt: DateTime.now().toUtc(),
      );

  static KidsProgressProfile fromFirestore(
    String ownerUid,
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> rawGames =
        (data['games'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<KidsGameId, KidsGameProgress> games =
        <KidsGameId, KidsGameProgress>{};
    for (final MapEntry<String, dynamic> e in rawGames.entries) {
      if (e.value is Map) {
        final KidsGameProgress g = KidsGameProgress.fromMap(
          Map<String, dynamic>.from(e.value as Map),
        );
        games[g.gameId] = g;
      }
    }
    final String band =
        data['ageBand'] as String? ?? KidsAgeBand.preschool.name;
    return KidsProgressProfile(
      ownerUid: ownerUid,
      avatarId: data['avatarId'] as String? ?? KidsAvatar.options.first.id,
      ageBand: KidsAgeBand.values.firstWhere(
        (KidsAgeBand b) => b.name == band,
        orElse: () => KidsAgeBand.preschool,
      ),
      totalStars: (data['totalStars'] as num?)?.toInt() ?? 0,
      games: games,
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      clinicId: data['clinicId'] as String?,
      dailyMinutesLimit: (data['dailyMinutesLimit'] as num?)?.toInt() ?? 30,
      muted: data['muted'] as bool? ?? false,
    );
  }
}
