import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/consent_history.dart';

/// Historico de consentimento LGPD.
///
/// Primario: `users/{uid}/consents` (Cloud Functions de privacidade).
/// Alternativa legada (se migrar): `users/{uid}/consent_history`.
///
/// Consulta: `orderBy('grantedAt', descending: true).limit(50)`.
/// Indice: single-field automatico em `grantedAt` (DESC) — ver
/// `tools/firestore-rules-tests/CONSENTS_QUERY.md`. Sem indice composto
/// em [firestore.indexes.json] enquanto nao houver filtro + orderBy.
class ConsentHistoryRepository {
  ConsentHistoryRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<ConsentHistoryEntry>> watchForUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('consents')
        .orderBy('grantedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(ConsentHistoryEntry.fromFirestore)
              .toList(),
        );
  }
}
