import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/child.dart';

/// Conversor de [Child] entre tres representacoes: Firestore, linha SQLite e
/// entidade de dominio.
///
/// A linha SQLite guarda listas (alergias, condicoes) como JSON em coluna TEXT.
/// Normalizar em tabelas separadas so faria sentido se houvesse consulta por
/// alergia — nao ha; o que existe e leitura da crianca inteira.
class ChildMapper {
  const ChildMapper._();

  // ------------------------------------------------------------- Firestore

  static Child fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return Child(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? doc.reference.parent.parent!.id,
      name: (data['name'] as String?) ?? '',
      birthDate: _date(data['birthDate']) ?? DateTime.now(),
      sex: ChildSex.fromName(data['sex'] as String?),
      photoUrl: data['photoUrl'] as String?,
      bloodType: data['bloodType'] as String?,
      allergies: _stringList(data['allergies']),
      conditions: _stringList(data['conditions']),
      medications: _stringList(data['medications']),
      gestationalWeeks: (data['gestationalWeeks'] as num?)?.toInt(),
      birthWeightKg: (data['birthWeightKg'] as num?)?.toDouble(),
      birthHeightCm: (data['birthHeightCm'] as num?)?.toDouble(),
      guardianName: data['guardianName'] as String?,
      guardianPhone: data['guardianPhone'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      cpf: data['cpf'] as String?,
      insurance: data['insurance'] as String?,
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toFirestore(Child child) => <String, dynamic>{
        'ownerId': child.ownerId,
        'name': child.name,
        'birthDate': Timestamp.fromDate(child.birthDate),
        'sex': child.sex.name,
        'photoUrl': child.photoUrl,
        'bloodType': child.bloodType,
        'allergies': child.allergies,
        'conditions': child.conditions,
        'medications': child.medications,
        'gestationalWeeks': child.gestationalWeeks,
        'birthWeightKg': child.birthWeightKg,
        'birthHeightCm': child.birthHeightCm,
        'guardianName': child.guardianName,
        'guardianPhone': child.guardianPhone,
        'phone': child.phone,
        'address': child.address,
        'cpf': child.cpf,
        'insurance': child.insurance,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Payload serializavel para a outbox (nao pode conter `FieldValue`, que
  /// nao sobrevive a um `jsonEncode`).
  ///
  /// `guardianName` não vive na tabela SQLite local (`toRow`/`fromRow`
  /// abaixo não têm coluna pra ele) — mudar o schema local sob pressa é
  /// exatamente o tipo de coisa que arrisca corromper dado já sincronizado.
  /// Efeito prático: o campo só chega vindo direto do Firestore, some ao
  /// reabrir o app offline até a próxima sincronização. Limitação real,
  /// documentada, não escondida.
  static Map<String, dynamic> toOutboxPayload(Child child) => <String, dynamic>{
        'ownerId': child.ownerId,
        'name': child.name,
        'birthDate': child.birthDate.toUtc().toIso8601String(),
        'sex': child.sex.name,
        'photoUrl': child.photoUrl,
        'bloodType': child.bloodType,
        'allergies': child.allergies,
        'conditions': child.conditions,
        'medications': child.medications,
        'gestationalWeeks': child.gestationalWeeks,
        'birthWeightKg': child.birthWeightKg,
        'birthHeightCm': child.birthHeightCm,
        'guardianName': child.guardianName,
        'guardianPhone': child.guardianPhone,
        'phone': child.phone,
        'address': child.address,
        'cpf': child.cpf,
        'insurance': child.insurance,
      };

  /// Converte o payload da outbox em dados prontos para o Firestore.
  static Map<String, dynamic> outboxPayloadToFirestore(
    Map<String, dynamic> payload,
  ) =>
      <String, dynamic>{
        ...payload,
        'birthDate': Timestamp.fromDate(
          DateTime.parse(payload['birthDate'] as String),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  // ---------------------------------------------------------------- SQLite

  static Child fromRow(Map<String, Object?> row) => Child(
        id: row['id']! as String,
        ownerId: row['owner_id']! as String,
        name: row['name']! as String,
        birthDate: DateTime.fromMillisecondsSinceEpoch(
          row['birth_date']! as int,
          isUtc: true,
        ).toLocal(),
        sex: ChildSex.fromName(row['sex'] as String?),
        photoUrl: row['photo_url'] as String?,
        bloodType: row['blood_type'] as String?,
        allergies: _decodeList(row['allergies'] as String?),
        conditions: _decodeList(row['conditions'] as String?),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
          isUtc: true,
        ).toLocal(),
        pendingSync: (row['dirty'] as int? ?? 0) == 1,
      );

  static Map<String, Object?> toRow(Child child, {bool dirty = false}) =>
      <String, Object?>{
        'id': child.id,
        'owner_id': child.ownerId,
        'name': child.name,
        'birth_date': child.birthDate.toUtc().millisecondsSinceEpoch,
        'sex': child.sex.name,
        'photo_url': child.photoUrl,
        'blood_type': child.bloodType,
        'allergies': jsonEncode(child.allergies),
        'conditions': jsonEncode(child.conditions),
        'updated_at': child.updatedAt.toUtc().millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
        'deleted': 0,
      };

  // ------------------------------------------------------------- Auxiliares

  static List<String> _stringList(Object? value) =>
      (value as List<dynamic>?)?.whereType<String>().toList(growable: false) ??
      const <String>[];

  static List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<String>()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}
