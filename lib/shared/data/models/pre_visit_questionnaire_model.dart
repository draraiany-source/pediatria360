import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/pre_visit_questionnaire.dart';

/// Mapeamento Firestore de [PreVisitQuestionnaire] — mesmo padrão de
/// `child_model.dart`: leitura defensiva (nunca lança se um campo faltar),
/// escrita explícita campo a campo.
class PreVisitQuestionnaireMapper {
  const PreVisitQuestionnaireMapper._();

  static PreVisitQuestionnaire fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return PreVisitQuestionnaire(
      appointmentId: doc.id,
      patientId: (data['patientId'] as String?) ?? '',
      childId: (data['childId'] as String?) ?? '',
      professionalId: (data['professionalId'] as String?) ?? '',
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: (data['reason'] as String?) ?? '',
      symptoms: _stringList(data['symptoms']),
      symptomsStartedAt: (data['symptomsStartedAt'] as Timestamp?)?.toDate(),
      hasFever: (data['hasFever'] as bool?) ?? false,
      feverTemperatureC: (data['feverTemperatureC'] as num?)?.toDouble(),
      feedingNotes: (data['feedingNotes'] as String?) ?? '',
      sleepNotes: (data['sleepNotes'] as String?) ?? '',
      eliminationNotes: data['eliminationNotes'] as String?,
      currentMedications: _stringList(data['currentMedications']),
      allergies: _stringList(data['allergies']),
      additionalNotes: (data['additionalNotes'] as String?) ?? '',
      attachmentUrls: _stringList(data['attachmentUrls']),
    );
  }

  static Map<String, dynamic> toFirestore(PreVisitQuestionnaire q) =>
      <String, dynamic>{
        'patientId': q.patientId,
        'childId': q.childId,
        'professionalId': q.professionalId,
        'submittedAt': Timestamp.fromDate(q.submittedAt),
        'reason': q.reason,
        'symptoms': q.symptoms,
        'symptomsStartedAt': q.symptomsStartedAt == null
            ? null
            : Timestamp.fromDate(q.symptomsStartedAt!),
        'hasFever': q.hasFever,
        'feverTemperatureC': q.feverTemperatureC,
        'feedingNotes': q.feedingNotes,
        'sleepNotes': q.sleepNotes,
        'eliminationNotes': q.eliminationNotes,
        'currentMedications': q.currentMedications,
        'allergies': q.allergies,
        'additionalNotes': q.additionalNotes,
        'attachmentUrls': q.attachmentUrls,
      };

  static List<String> _stringList(Object? value) => value == null
      ? const <String>[]
      : List<String>.from(value as List<dynamic>);
}
