import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/result.dart';
import '../domain/lab_result.dart';
import '../domain/supplement_prescription.dart';
import '../domain/supplement_timeline.dart';
import 'supplement_paths.dart';

/// Persistencia clinica de suplementacao (profissional verificado).
class SupplementRepository {
  SupplementRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _labs =>
      _firestore.collection(SupplementPaths.labResults());

  CollectionReference<Map<String, dynamic>> get _rx =>
      _firestore.collection(SupplementPaths.prescriptions());

  CollectionReference<Map<String, dynamic>> get _timeline =>
      _firestore.collection(SupplementPaths.timeline());

  CollectionReference<Map<String, dynamic>> get _notes =>
      _firestore.collection(SupplementPaths.clinicalNotes());

  CollectionReference<Map<String, dynamic>> get _aiDrafts =>
      _firestore.collection(SupplementPaths.aiDrafts());

  CollectionReference<Map<String, dynamic>> get _audit =>
      _firestore.collection(SupplementPaths.auditLogs());

  Future<Result<PatientLabResult>> saveLabResult(PatientLabResult result) {
    return guard(() async {
      final String id = result.id.isEmpty ? _labs.doc().id : result.id;
      final PatientLabResult saved = PatientLabResult(
        id: id,
        childId: result.childId,
        examId: result.examId,
        examName: result.examName,
        recordedBy: result.recordedBy,
        recordedAt: result.recordedAt,
        valueText: result.valueText,
        unit: result.unit,
        labName: result.labName,
        referenceText: result.referenceText,
        notes: result.notes,
        flag: result.flag,
        professionalFlagNote: result.professionalFlagNote,
      );
      await _labs.doc(id).set(saved.toMap(), SetOptions(merge: true));
      await _appendTimeline(
        childId: saved.childId,
        kind: SupplementTimelineKind.labResult,
        title: '${saved.examName}: ${saved.valueText}'.trim(),
        createdBy: saved.recordedBy,
        relatedExamId: saved.examId,
        detail: saved.notes,
      );
      await _auditWrite(
        action: 'lab_result_saved',
        actorId: saved.recordedBy,
        childId: saved.childId,
        entityId: id,
      );
      return saved;
    });
  }

  Stream<List<PatientLabResult>> watchLabResults(String childId) {
    return _labs
        .where('childId', isEqualTo: childId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    PatientLabResult.fromMap(d.data(), id: d.id),
              )
              .toList(growable: false),
        );
  }

  Future<Result<List<PatientLabResult>>> listLabResultsByExam({
    required String childId,
    required String examId,
  }) {
    return guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snap = await _labs
          .where('childId', isEqualTo: childId)
          .where('examId', isEqualTo: examId)
          .orderBy('recordedAt', descending: true)
          .get();
      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                PatientLabResult.fromMap(d.data(), id: d.id),
          )
          .toList(growable: false);
    });
  }

  Future<Result<SupplementPrescription>> savePrescription(
    SupplementPrescription rx,
  ) {
    return guard(() async {
      final String id = rx.id.isEmpty ? _rx.doc().id : rx.id;
      final SupplementPrescription saved = SupplementPrescription(
        id: id,
        childId: rx.childId,
        professionalId: rx.professionalId,
        createdAt: rx.createdAt,
        updatedAt: DateTime.now(),
        micronutrientId: rx.micronutrientId,
        productName: rx.productName,
        activeIngredient: rx.activeIngredient,
        presentation: rx.presentation,
        concentration: rx.concentration,
        doseText: rx.doseText,
        unit: rx.unit,
        frequency: rx.frequency,
        route: rx.route,
        duration: rx.duration,
        quantity: rx.quantity,
        instructions: rx.instructions,
        status: rx.status,
        confirmedAt: rx.confirmedAt,
        confirmedBy: rx.confirmedBy,
        calculatorSuggestion: rx.calculatorSuggestion,
        clinicalNote: rx.clinicalNote,
      );
      await _rx.doc(id).set(saved.toMap(), SetOptions(merge: true));
      await _auditWrite(
        action: 'prescription_saved',
        actorId: saved.professionalId,
        childId: saved.childId,
        entityId: id,
        extra: <String, dynamic>{'status': saved.status.name},
      );
      return saved;
    });
  }

  Future<Result<SupplementPrescription>> confirmPrescription({
    required SupplementPrescription rx,
    required String confirmedBy,
  }) {
    return guard(() async {
      if (rx.status != SupplementRxStatus.draft) {
        throw StateError('Somente rascunhos podem ser confirmados.');
      }
      final SupplementPrescription confirmed = SupplementPrescription(
        id: rx.id,
        childId: rx.childId,
        professionalId: rx.professionalId,
        createdAt: rx.createdAt,
        updatedAt: DateTime.now(),
        micronutrientId: rx.micronutrientId,
        productName: rx.productName,
        activeIngredient: rx.activeIngredient,
        presentation: rx.presentation,
        concentration: rx.concentration,
        doseText: rx.doseText,
        unit: rx.unit,
        frequency: rx.frequency,
        route: rx.route,
        duration: rx.duration,
        quantity: rx.quantity,
        instructions: rx.instructions,
        status: SupplementRxStatus.confirmed,
        confirmedAt: DateTime.now(),
        confirmedBy: confirmedBy,
        calculatorSuggestion: rx.calculatorSuggestion,
        clinicalNote: rx.clinicalNote,
      );
      await _rx.doc(confirmed.id).set(confirmed.toMap(), SetOptions(merge: true));
      await _appendTimeline(
        childId: confirmed.childId,
        kind: SupplementTimelineKind.prescription,
        title: 'Prescricao confirmada: ${confirmed.productName}',
        createdBy: confirmedBy,
        relatedRxId: confirmed.id,
        detail: confirmed.doseText,
      );
      await _auditWrite(
        action: 'prescription_confirmed',
        actorId: confirmedBy,
        childId: confirmed.childId,
        entityId: confirmed.id,
      );
      return confirmed;
    });
  }

  Stream<List<SupplementPrescription>> watchPrescriptions(String childId) {
    return _rx
        .where('childId', isEqualTo: childId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    SupplementPrescription.fromMap(d.data(), id: d.id),
              )
              .toList(growable: false),
        );
  }

  Future<Result<SupplementTimelineEvent>> addTimelineEvent(
    SupplementTimelineEvent event,
  ) {
    return guard(() async {
      final String id = event.id.isEmpty ? _timeline.doc().id : event.id;
      final SupplementTimelineEvent saved = SupplementTimelineEvent(
        id: id,
        childId: event.childId,
        kind: event.kind,
        title: event.title,
        occurredAt: event.occurredAt,
        createdBy: event.createdBy,
        detail: event.detail,
        relatedExamId: event.relatedExamId,
        relatedRxId: event.relatedRxId,
        numericValue: event.numericValue,
      );
      await _timeline.doc(id).set(saved.toMap(), SetOptions(merge: true));
      return saved;
    });
  }

  Stream<List<SupplementTimelineEvent>> watchTimeline(String childId) {
    return _timeline
        .where('childId', isEqualTo: childId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    SupplementTimelineEvent.fromMap(d.data(), id: d.id),
              )
              .toList(growable: false),
        );
  }

  Future<Result<String>> saveClinicalNote({
    required String childId,
    required String professionalId,
    required String title,
    required String body,
  }) {
    return guard(() async {
      final String id = _notes.doc().id;
      await _notes.doc(id).set(<String, dynamic>{
        'id': id,
        'childId': childId,
        'professionalId': professionalId,
        'title': title,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _appendTimeline(
        childId: childId,
        kind: SupplementTimelineKind.clinicalNote,
        title: title,
        createdBy: professionalId,
        detail: body,
      );
      return id;
    });
  }

  Future<Result<String>> saveAiDraft({
    required String childId,
    required String professionalId,
    required String kind,
    required Map<String, dynamic> payload,
  }) {
    return guard(() async {
      final String id = _aiDrafts.doc().id;
      await _aiDrafts.doc(id).set(<String, dynamic>{
        'id': id,
        'childId': childId,
        'professionalId': professionalId,
        'kind': kind,
        'payload': payload,
        'status': 'draft',
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _auditWrite(
        action: 'ai_draft_saved',
        actorId: professionalId,
        childId: childId,
        entityId: id,
        extra: <String, dynamic>{'kind': kind},
      );
      return id;
    });
  }

  Future<Result<void>> toggleFavorite({
    required String professionalId,
    required String micronutrientId,
  }) {
    return guard(() async {
      final DocumentReference<Map<String, dynamic>> ref =
          _firestore.doc(SupplementPaths.favoritesDoc(professionalId));
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      final List<String> ids = List<String>.from(
        (snap.data()?['ids'] as List<dynamic>?) ?? <dynamic>[],
      );
      if (ids.contains(micronutrientId)) {
        ids.remove(micronutrientId);
      } else {
        ids.add(micronutrientId);
      }
      await ref.set(<String, dynamic>{
        'ids': ids,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    });
  }

  Stream<List<String>> watchFavorites(String professionalId) {
    return _firestore
        .doc(SupplementPaths.favoritesDoc(professionalId))
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final List<dynamic> raw =
          (snap.data()?['ids'] as List<dynamic>?) ?? <dynamic>[];
      return raw.map((dynamic e) => e.toString()).toList(growable: false);
    });
  }

  Future<Result<void>> trackRecent({
    required String professionalId,
    required String itemType,
    required String itemId,
    required String label,
  }) {
    return guard(() async {
      final DocumentReference<Map<String, dynamic>> ref =
          _firestore.doc(SupplementPaths.recentDoc(professionalId));
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        ((snap.data()?['items'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => Map<String, dynamic>.from(e as Map)),
      );
      items.removeWhere(
        (Map<String, dynamic> e) =>
            e['itemType'] == itemType && e['itemId'] == itemId,
      );
      items.insert(0, <String, dynamic>{
        'itemType': itemType,
        'itemId': itemId,
        'label': label,
        'at': DateTime.now().toIso8601String(),
      });
      if (items.length > 20) {
        items.removeRange(20, items.length);
      }
      await ref.set(<String, dynamic>{'items': items}, SetOptions(merge: true));
    });
  }

  Stream<List<Map<String, dynamic>>> watchRecent(String professionalId) {
    return _firestore
        .doc(SupplementPaths.recentDoc(professionalId))
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final List<dynamic> raw =
          (snap.data()?['items'] as List<dynamic>?) ?? <dynamic>[];
      return raw
          .map((dynamic e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    });
  }

  Future<void> _appendTimeline({
    required String childId,
    required SupplementTimelineKind kind,
    required String title,
    required String createdBy,
    String detail = '',
    String relatedExamId = '',
    String relatedRxId = '',
  }) async {
    final String id = _timeline.doc().id;
    await _timeline.doc(id).set(
          SupplementTimelineEvent(
            id: id,
            childId: childId,
            kind: kind,
            title: title,
            occurredAt: DateTime.now(),
            createdBy: createdBy,
            detail: detail,
            relatedExamId: relatedExamId,
            relatedRxId: relatedRxId,
          ).toMap(),
        );
  }

  Future<void> _auditWrite({
    required String action,
    required String actorId,
    required String childId,
    required String entityId,
    Map<String, dynamic>? extra,
  }) async {
    await _audit.add(<String, dynamic>{
      'action': action,
      'actorId': actorId,
      'childId': childId,
      'entityId': entityId,
      'at': DateTime.now().toIso8601String(),
      if (extra != null) 'extra': extra,
    });
  }
}
