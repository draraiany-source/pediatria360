import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/config/firestore_paths.dart';
import '../../../core/utils/result.dart';
import '../domain/voice_consultation.dart';

/// Repositorio de sessoes de consulta por voz (callables + stream Firestore).
///
/// O cliente nunca assina o prontuario: so aplica rascunho via Function.
class VoiceConsultationRepository {
  const VoiceConsultationRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(FirestorePaths.voiceSessions);

  Future<Result<VoiceConsultationSession>> startSession({
    required String childId,
    required String childName,
    required String professionalName,
    String? appointmentId,
    String? encounterId,
    AudioRetentionPolicy retention =
        AudioRetentionPolicy.deleteAfterValidation,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> result =
            await _functions.httpsCallable('startVoiceConsultation').call(
          <String, dynamic>{
            'childId': childId,
            'childName': childName,
            'professionalName': professionalName,
            'appointmentId': appointmentId,
            'encounterId': encounterId,
            'audioRetentionPolicy': retention.name,
          },
        );
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(result.data as Map);
        return VoiceConsultationSession.fromMap(data, id: data['id'] as String?);
      });

  Future<Result<void>> pauseSession(String sessionId) => guard(() async {
        await _functions.httpsCallable('updateVoiceSession').call(
          <String, dynamic>{
            'sessionId': sessionId,
            'action': 'pause',
          },
        );
      });

  Future<Result<void>> resumeSession(String sessionId) => guard(() async {
        await _functions.httpsCallable('updateVoiceSession').call(
          <String, dynamic>{
            'sessionId': sessionId,
            'action': 'resume',
          },
        );
      });

  Future<Result<void>> finalizeRecording(
    String sessionId, {
    List<Map<String, dynamic>>? transcript,
    String? evolutionTemplate,
  }) =>
      guard(() async {
        await _functions.httpsCallable('finalizeVoiceRecording').call(
          <String, dynamic>{
            'sessionId': sessionId,
            if (transcript != null) 'transcript': transcript,
            if (evolutionTemplate != null)
              'evolutionTemplate': evolutionTemplate,
          },
        );
      });

  Future<Result<VoiceStructuredDraft>> structureDraft(
    String sessionId, {
    String evolutionTemplate = 'SOAP',
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> result =
            await _functions.httpsCallable('structureVoiceDraft').call(
          <String, dynamic>{
            'sessionId': sessionId,
            'evolutionTemplate': evolutionTemplate,
          },
        );
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(result.data as Map);
        final Object? draft = data['draft'] ?? data;
        return VoiceStructuredDraft.fromMap(
          Map<String, dynamic>.from(draft as Map),
        );
      });

  /// Grava o rascunho como atendimento em rascunho, sem os campos recusados.
  ///
  /// `keptFields`: campos em que o texto ja escrito no atendimento foi
  /// mantido no lugar da sugestao da IA.
  Future<Result<({String? encounterId, List<String> keptFields})>>
      applyDraftToEncounter(
    String sessionId, {
    Iterable<String> ignoredFields = const <String>[],
  }) =>
          guard(() async {
            final HttpsCallableResult<dynamic> result = await _functions
                .httpsCallable('applyVoiceDraftToEncounter')
                .call(<String, dynamic>{
              'sessionId': sessionId,
              'ignoredFields': ignoredFields.toList(),
            });
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(result.data as Map);
            return (
              encounterId: data['encounterId'] as String?,
              keptFields: ((data['keptFields'] as List<dynamic>?) ??
                      const <dynamic>[])
                  .whereType<String>()
                  .toList(),
            );
          });

  Future<Result<void>> discardSession(String sessionId) => guard(() async {
        await _functions.httpsCallable('discardVoiceSession').call(
          <String, dynamic>{'sessionId': sessionId},
        );
      });

  Stream<VoiceConsultationSession?> watchSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> doc) {
        if (!doc.exists) return null;
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(doc.data()!);
        _normalizeTimestamps(data);
        return VoiceConsultationSession.fromMap(data, id: doc.id);
      },
    );
  }

  /// Mescla o rascunho da IA em um mapa de atualizacao de encounter.
  ///
  /// Uso local / preview — a gravacao oficial passa por
  /// [applyDraftToEncounter]. O cliente nunca define signedAt/signatureHash.
  static Map<String, dynamic> mergeDraftIntoEncounterMap(
    Map<String, dynamic> existing,
    VoiceStructuredDraft draft,
  ) {
    final Map<String, dynamic> patch = draft.toEncounterDraftPatch();
    final Map<String, dynamic> merged =
        Map<String, dynamic>.from(existing);
    merged['anamnesis'] = <String, dynamic>{
      ...((existing['anamnesis'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
      ...(patch['anamnesis'] as Map<String, dynamic>),
    };
    merged['exam'] = <String, dynamic>{
      ...((existing['exam'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
      ...(patch['exam'] as Map<String, dynamic>),
    };
    if ((patch['assessment'] as String?)?.isNotEmpty == true) {
      merged['assessment'] = patch['assessment'];
    }
    if ((patch['plan'] as String?)?.isNotEmpty == true) {
      merged['plan'] = patch['plan'];
    }
    // Nunca tocar em assinatura.
    merged.remove('signedAt');
    merged.remove('signatureHash');
    merged.remove('signedBy');
    merged['status'] = 'draft';
    merged['aiDraftAppliedAt'] = DateTime.now().toIso8601String();
    return merged;
  }

  static void _normalizeTimestamps(Map<String, dynamic> data) {
    for (final String key in <String>[
      'consentAt',
      'startedAt',
      'endedAt',
    ]) {
      final Object? v = data[key];
      if (v is Timestamp) {
        data[key] = v.toDate().toIso8601String();
      }
    }
    final Object? segments = data['segments'];
    if (segments is List) {
      for (final Object? item in segments) {
        if (item is Map) {
          final Object? at = item['at'];
          if (at is Timestamp) {
            item['at'] = at.toDate().toIso8601String();
          }
        }
      }
    }
  }
}
