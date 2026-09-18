import 'package:equatable/equatable.dart';

/// Estado de uma sessao de consulta por voz / IA.
enum VoiceSessionStatus {
  awaitingConsent,
  recording,
  paused,
  processing,
  draftReady,
  underReview,
  applied,
  discarded;

  String get label => switch (this) {
        VoiceSessionStatus.awaitingConsent => 'Aguardando consentimento',
        VoiceSessionStatus.recording => 'Gravando',
        VoiceSessionStatus.paused => 'Pausada',
        VoiceSessionStatus.processing => 'Processando',
        VoiceSessionStatus.draftReady => 'Rascunho pronto',
        VoiceSessionStatus.underReview => 'Em revisao',
        VoiceSessionStatus.applied => 'Aplicado',
        VoiceSessionStatus.discarded => 'Descartada',
      };

  static VoiceSessionStatus fromName(String? value) =>
      VoiceSessionStatus.values.firstWhere(
        (VoiceSessionStatus s) => s.name == value,
        orElse: () => VoiceSessionStatus.awaitingConsent,
      );
}

/// Quem falou no trecho da transcricao.
enum TranscriptSpeaker {
  doctor,
  guardian,
  patient,
  unknown;

  String get label => switch (this) {
        TranscriptSpeaker.doctor => 'Medico(a)',
        TranscriptSpeaker.guardian => 'Responsavel',
        TranscriptSpeaker.patient => 'Paciente',
        TranscriptSpeaker.unknown => 'Desconhecido',
      };

  static TranscriptSpeaker fromName(String? value) =>
      TranscriptSpeaker.values.firstWhere(
        (TranscriptSpeaker s) => s.name == value,
        orElse: () => TranscriptSpeaker.unknown,
      );
}

/// Politica de retencao do audio bruto.
enum AudioRetentionPolicy {
  deleteAfterValidation,
  retainDays,
  neverStore;

  String get label => switch (this) {
        AudioRetentionPolicy.deleteAfterValidation =>
          'Excluir apos validacao',
        AudioRetentionPolicy.retainDays => 'Reter por dias definidos',
        AudioRetentionPolicy.neverStore => 'Nunca armazenar audio',
      };

  static AudioRetentionPolicy fromName(String? value) =>
      AudioRetentionPolicy.values.firstWhere(
        (AudioRetentionPolicy p) => p.name == value,
        orElse: () => AudioRetentionPolicy.deleteAfterValidation,
      );
}

/// Segmento de transcricao ao vivo ou processada.
class TranscriptSegment extends Equatable {
  const TranscriptSegment({
    required this.id,
    required this.speaker,
    required this.text,
    required this.at,
    this.markedImportant = false,
  });

  factory TranscriptSegment.fromMap(Map<String, dynamic> map, {String? id}) {
    return TranscriptSegment(
      id: id ?? (map['id'] as String?) ?? '',
      speaker: TranscriptSpeaker.fromName(map['speaker'] as String?),
      text: (map['text'] as String?) ?? '',
      at: DateTime.tryParse((map['at'] as String?) ?? '') ?? DateTime.now(),
      markedImportant: (map['markedImportant'] as bool?) ?? false,
    );
  }

  final String id;
  final TranscriptSpeaker speaker;
  final String text;
  final DateTime at;
  final bool markedImportant;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'speaker': speaker.name,
        'text': text,
        'at': at.toIso8601String(),
        'markedImportant': markedImportant,
      };

  @override
  List<Object?> get props =>
      <Object?>[id, speaker, text, at, markedImportant];
}

/// Rascunho estruturado gerado pela IA — sempre DRAFT ate confirmacao medica.
///
/// Espelha campos de Anamnesis + secoes de exame + avaliacao + plano.
class VoiceStructuredDraft extends Equatable {
  const VoiceStructuredDraft({
    this.chiefComplaint = '',
    this.historyOfPresentIllness = '',
    this.pastMedicalHistory = '',
    this.gestationalHistory = '',
    this.birthHistory = '',
    this.developmentHistory = '',
    this.feedingHistory = '',
    this.sleepHistory = '',
    this.eliminationHistory = '',
    this.immunizationStatus = '',
    this.allergies = const <String>[],
    this.currentMedications = const <String>[],
    this.familyHistory = '',
    this.socialHistory = '',
    this.reviewOfSystems = const <String, String>{},
    this.examFindings = const <String, String>{},
    this.examNotes = '',
    this.assessment = '',
    this.plan = '',
    this.missingFields = const <String>[],
    this.evolutionText = '',
    this.hypotheses = const <String>[],
    this.suggestedCids = const <String>[],
    this.disclaimer = kAiDraftDisclaimer,
  });

  factory VoiceStructuredDraft.fromMap(Map<String, dynamic> map) {
    return VoiceStructuredDraft(
      chiefComplaint: (map['chiefComplaint'] as String?) ?? '',
      historyOfPresentIllness:
          (map['historyOfPresentIllness'] as String?) ?? '',
      pastMedicalHistory: (map['pastMedicalHistory'] as String?) ?? '',
      gestationalHistory: (map['gestationalHistory'] as String?) ?? '',
      birthHistory: (map['birthHistory'] as String?) ?? '',
      developmentHistory: (map['developmentHistory'] as String?) ?? '',
      feedingHistory: (map['feedingHistory'] as String?) ?? '',
      sleepHistory: (map['sleepHistory'] as String?) ?? '',
      eliminationHistory: (map['eliminationHistory'] as String?) ?? '',
      immunizationStatus: (map['immunizationStatus'] as String?) ?? '',
      allergies: _strings(map['allergies']),
      currentMedications: _strings(map['currentMedications']),
      familyHistory: (map['familyHistory'] as String?) ?? '',
      socialHistory: (map['socialHistory'] as String?) ?? '',
      reviewOfSystems: _stringMap(map['reviewOfSystems']),
      examFindings: _stringMap(map['examFindings'] ?? map['findings']),
      examNotes: (map['examNotes'] as String?) ??
          (map['notes'] as String?) ??
          '',
      assessment: (map['assessment'] as String?) ?? '',
      plan: (map['plan'] as String?) ?? '',
      missingFields: _strings(map['missingFields']),
      evolutionText: (map['evolutionText'] as String?) ?? '',
      hypotheses: _strings(map['hypotheses']),
      suggestedCids: _strings(map['suggestedCids']),
      disclaimer: (map['disclaimer'] as String?) ?? kAiDraftDisclaimer,
    );
  }

  /// Texto fixo de aviso — a IA nunca assina nem substitui o profissional.
  static const String kAiDraftDisclaimer =
      'Conteudo gerado por IA em modo RASCUNHO. Revise, edite e confirme '
      'antes de gravar no prontuario. A IA nao diagnostica nem assina.';

  final String chiefComplaint;
  final String historyOfPresentIllness;
  final String pastMedicalHistory;
  final String gestationalHistory;
  final String birthHistory;
  final String developmentHistory;
  final String feedingHistory;
  final String sleepHistory;
  final String eliminationHistory;
  final String immunizationStatus;
  final List<String> allergies;
  final List<String> currentMedications;
  final String familyHistory;
  final String socialHistory;
  final Map<String, String> reviewOfSystems;

  /// Achados por aparelho (espelha PhysicalExam.findings).
  final Map<String, String> examFindings;
  final String examNotes;
  final String assessment;
  final String plan;

  /// Campos clinicos ainda nao preenchidos na conversa.
  final List<String> missingFields;
  final String evolutionText;
  final List<String> hypotheses;
  final List<String> suggestedCids;
  final String disclaimer;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'chiefComplaint': chiefComplaint,
        'historyOfPresentIllness': historyOfPresentIllness,
        'pastMedicalHistory': pastMedicalHistory,
        'gestationalHistory': gestationalHistory,
        'birthHistory': birthHistory,
        'developmentHistory': developmentHistory,
        'feedingHistory': feedingHistory,
        'sleepHistory': sleepHistory,
        'eliminationHistory': eliminationHistory,
        'immunizationStatus': immunizationStatus,
        'allergies': allergies,
        'currentMedications': currentMedications,
        'familyHistory': familyHistory,
        'socialHistory': socialHistory,
        'reviewOfSystems': reviewOfSystems,
        'examFindings': examFindings,
        'examNotes': examNotes,
        'assessment': assessment,
        'plan': plan,
        'missingFields': missingFields,
        'evolutionText': evolutionText,
        'hypotheses': hypotheses,
        'suggestedCids': suggestedCids,
        'disclaimer': disclaimer,
      };

  /// Mapa no formato de atualizacao de Encounter (rascunho).
  Map<String, dynamic> toEncounterDraftPatch() => <String, dynamic>{
        'anamnesis': <String, dynamic>{
          'chiefComplaint': chiefComplaint,
          'historyOfPresentIllness': historyOfPresentIllness,
          'pastMedicalHistory': pastMedicalHistory,
          'gestationalHistory': gestationalHistory,
          'birthHistory': birthHistory,
          'developmentHistory': developmentHistory,
          'feedingHistory': feedingHistory,
          'sleepHistory': sleepHistory,
          'eliminationHistory': eliminationHistory,
          'immunizationStatus': immunizationStatus,
          'allergies': allergies,
          'currentMedications': currentMedications,
          'familyHistory': familyHistory,
          'socialHistory': socialHistory,
          'reviewOfSystems': reviewOfSystems,
        },
        'exam': <String, dynamic>{
          'findings': examFindings,
          'systemsExamined': examFindings.keys.toList(growable: false),
          'notes': examNotes,
        },
        'assessment': assessment,
        'plan': plan,
      };

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>?)?.whereType<String>().toList(growable: false) ??
      const <String>[];

  static Map<String, String> _stringMap(Object? value) {
    final Map<dynamic, dynamic> raw =
        (value as Map<dynamic, dynamic>?) ?? const <dynamic, dynamic>{};
    return raw.map(
      (dynamic k, dynamic v) =>
          MapEntry<String, String>(k.toString(), v.toString()),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        chiefComplaint,
        historyOfPresentIllness,
        assessment,
        plan,
        missingFields,
        evolutionText,
        hypotheses,
        suggestedCids,
      ];
}

/// Sessao completa de consulta assistida por voz.
class VoiceConsultationSession extends Equatable {
  const VoiceConsultationSession({
    required this.id,
    required this.childId,
    required this.childName,
    required this.professionalId,
    required this.professionalName,
    required this.status,
    required this.consentAt,
    required this.consentByUid,
    required this.startedAt,
    required this.durationSeconds,
    this.encounterId,
    this.appointmentId,
    this.endedAt,
    this.segments = const <TranscriptSegment>[],
    this.draft,
    this.audioRetentionPolicy = AudioRetentionPolicy.deleteAfterValidation,
    this.audioStored = false,
  });

  factory VoiceConsultationSession.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final List<dynamic> rawSegments =
        (map['segments'] as List<dynamic>?) ?? const <dynamic>[];
    return VoiceConsultationSession(
      id: id ?? (map['id'] as String?) ?? '',
      encounterId: map['encounterId'] as String?,
      appointmentId: map['appointmentId'] as String?,
      childId: (map['childId'] as String?) ?? '',
      childName: (map['childName'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      professionalName: (map['professionalName'] as String?) ?? '',
      status: VoiceSessionStatus.fromName(map['status'] as String?),
      consentAt: DateTime.tryParse((map['consentAt'] as String?) ?? '') ??
          DateTime.now(),
      consentByUid: (map['consentByUid'] as String?) ?? '',
      startedAt: DateTime.tryParse((map['startedAt'] as String?) ?? '') ??
          DateTime.now(),
      endedAt: map['endedAt'] != null
          ? DateTime.tryParse(map['endedAt'] as String)
          : null,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      segments: rawSegments
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                TranscriptSegment.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      draft: map['draft'] is Map
          ? VoiceStructuredDraft.fromMap(
              Map<String, dynamic>.from(map['draft'] as Map),
            )
          : null,
      audioRetentionPolicy: AudioRetentionPolicy.fromName(
        map['audioRetentionPolicy'] as String?,
      ),
      audioStored: (map['audioStored'] as bool?) ?? false,
    );
  }

  static const String aiDisclaimer = VoiceStructuredDraft.kAiDraftDisclaimer;

  final String id;
  final String? encounterId;
  final String? appointmentId;
  final String childId;
  final String childName;
  final String professionalId;
  final String professionalName;
  final VoiceSessionStatus status;
  final DateTime consentAt;
  final String consentByUid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final List<TranscriptSegment> segments;
  final VoiceStructuredDraft? draft;
  final AudioRetentionPolicy audioRetentionPolicy;
  final bool audioStored;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'encounterId': encounterId,
        'appointmentId': appointmentId,
        'childId': childId,
        'childName': childName,
        'professionalId': professionalId,
        'professionalName': professionalName,
        'status': status.name,
        'consentAt': consentAt.toIso8601String(),
        'consentByUid': consentByUid,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'durationSeconds': durationSeconds,
        'segments':
            segments.map((TranscriptSegment s) => s.toMap()).toList(),
        'draft': draft?.toMap(),
        'audioRetentionPolicy': audioRetentionPolicy.name,
        'audioStored': audioStored,
        'aiDisclaimer': aiDisclaimer,
      };

  @override
  List<Object?> get props => <Object?>[
        id,
        encounterId,
        appointmentId,
        childId,
        status,
        durationSeconds,
        segments,
        draft,
        audioRetentionPolicy,
        audioStored,
      ];
}
