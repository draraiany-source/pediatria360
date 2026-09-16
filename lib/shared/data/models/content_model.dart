import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/content.dart';

/// Conversor de [Content] entre Firestore, cache (JSON) e domínio.
class ContentMapper {
  const ContentMapper._();

  static Content fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  static Content fromMap(String id, Map<String, dynamic> data) {
    final List<dynamic> rawRange =
        (data['ageRangeMonths'] as List<dynamic>?) ?? const <dynamic>[];

    return Content(
      id: id,
      title: (data['title'] as String?) ?? '',
      summary: (data['summary'] as String?) ?? '',
      type: ContentType.fromName(data['type'] as String?),
      audience: ContentAudience.fromName(data['audience'] as String?),
      category: (data['category'] as String?) ?? 'febre',
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
      sections: ((data['sections'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                ContentSection.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      tags: _stringList(data['tags']),
      searchTerms: _stringList(data['searchTerms']),
      coverUrl: data['coverUrl'] as String?,
      author: data['author'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _date(data['reviewedAt']),
      readMinutes: (data['readMinutes'] as num?)?.toInt() ?? 3,
      ageRangeMonths: rawRange.length == 2
          ? ((rawRange[0] as num).toInt(), (rawRange[1] as num).toInt())
          : null,
      published: (data['published'] as bool?) ?? true,
    );
  }

  /// Serialização para o cache do Hive. Datas viram millis, tuplas viram lista.
  static Map<String, dynamic> toCacheMap(Content content) => <String, dynamic>{
        'id': content.id,
        'title': content.title,
        'summary': content.summary,
        'type': content.type.name,
        'audience': content.audience.name,
        'category': content.category,
        'updatedAt': content.updatedAt.toUtc().millisecondsSinceEpoch,
        'sections': content.sections
            .map((ContentSection s) => s.toMap())
            .toList(growable: false),
        'tags': content.tags,
        'searchTerms': content.searchTerms,
        'coverUrl': content.coverUrl,
        'author': content.author,
        'reviewedBy': content.reviewedBy,
        'reviewedAt': content.reviewedAt?.toUtc().millisecondsSinceEpoch,
        'readMinutes': content.readMinutes,
        'ageRangeMonths': content.ageRangeMonths == null
            ? null
            : <int>[content.ageRangeMonths!.$1, content.ageRangeMonths!.$2],
        'published': content.published,
      };

  static Content fromCacheMap(Map<String, dynamic> map) =>
      fromMap(map['id'] as String? ?? '', map);

  static List<String> _stringList(Object? value) =>
      (value as List<dynamic>?)?.whereType<String>().toList(growable: false) ??
      const <String>[];

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
