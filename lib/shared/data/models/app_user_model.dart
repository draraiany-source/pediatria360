import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';

/// Conversor entre [AppUser] e o documento `users/{uid}`.
///
/// A entidade nao conhece `Timestamp` nem `DocumentSnapshot`: a fronteira
/// entre Firestore e dominio fica inteira aqui.
class AppUserMapper {
  const AppUserMapper._();

  static AppUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return fromMap(doc.id, data);
  }

  static AppUser fromMap(String uid, Map<String, dynamic> data) => AppUser(
        uid: uid,
        email: (data['email'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        photoUrl: data['photoUrl'] as String?,
        phone: data['phone'] as String?,
        role: UserRole.fromName(data['role'] as String?),
        plan: UserPlan.fromName(data['plan'] as String?),
        emailVerified: (data['emailVerified'] as bool?) ?? false,
        onboardingDone: (data['onboardingDone'] as bool?) ?? false,
        crm: data['crm'] as String?,
        specialty: data['specialty'] as String?,
        professionalVerified:
            (data['professionalVerified'] as bool?) ?? false,
        consentPurposes: Map<String, dynamic>.from(
          (data['consentPurposes'] as Map<dynamic, dynamic>?) ??
              const <dynamic, dynamic>{},
        ),
        deletionScheduledFor: _date(data['deletionScheduledFor']),
        xp: (data['xp'] as num?)?.toInt() ?? 0,
        streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
        lastActiveAt: _date(data['lastActiveAt']),
        fcmTokens: (data['fcmTokens'] as List<dynamic>?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const <String>[],
        planExpiresAt: _date(data['planExpiresAt']),
        createdAt: _date(data['createdAt']) ?? DateTime.now(),
      );

  /// Payload de escrita. Campos controlados pelo servidor (`xp`, `plan`,
  /// `professionalVerified`) ficam de fora: sao gravados exclusivamente por
  /// Cloud Functions, e as regras do Firestore bloqueiam a escrita do cliente.
  static Map<String, dynamic> toFirestore(AppUser user) => <String, dynamic>{
        'email': user.email,
        'name': user.name,
        'photoUrl': user.photoUrl,
        'phone': user.phone,
        'role': user.role.name,
        'emailVerified': user.emailVerified,
        'onboardingDone': user.onboardingDone,
        'crm': user.crm,
        'specialty': user.specialty,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Documento inicial, criado no primeiro login.
  static Map<String, dynamic> toCreateMap(AppUser user) => <String, dynamic>{
        ...toFirestore(user),
        'plan': UserPlan.free.name,
        'professionalVerified': false,
        'xp': 0,
        'streakDays': 0,
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
