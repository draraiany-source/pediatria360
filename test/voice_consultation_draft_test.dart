import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/data/voice_consultation_repository.dart';
import 'package:pediatria360/features/clinic/domain/voice_consultation.dart';

void main() {
  group('VoiceStructuredDraft', () {
    test('disclaimer constante presente', () {
      const VoiceStructuredDraft draft = VoiceStructuredDraft();
      expect(draft.disclaimer, contains('RASCUNHO'));
      expect(VoiceConsultationSession.aiDisclaimer, isNotEmpty);
    });

    test('fromMap/toMap roundtrip basico', () {
      final VoiceStructuredDraft draft = VoiceStructuredDraft.fromMap(
        <String, dynamic>{
          'chiefComplaint': 'Febre',
          'assessment': 'IVAS',
          'plan': 'Hidratacao',
          'missingFields': <String>['exame fisico'],
          'hypotheses': <String>['resfriado'],
          'suggestedCids': <String>['J06.9'],
        },
      );

      expect(draft.chiefComplaint, 'Febre');
      expect(draft.missingFields, contains('exame fisico'));
      expect(draft.toMap()['assessment'], 'IVAS');
    });

    test('toEncounterDraftPatch nao inclui assinatura', () {
      const VoiceStructuredDraft draft = VoiceStructuredDraft(
        chiefComplaint: 'Tosse',
        assessment: 'Bronquite',
        plan: 'Observacao',
        examFindings: <String, String>{'respiratory': 'MV+'},
      );
      final Map<String, dynamic> patch = draft.toEncounterDraftPatch();
      expect(patch.containsKey('signedAt'), isFalse);
      expect(patch.containsKey('signatureHash'), isFalse);
      expect(patch['anamnesis'], isA<Map<String, dynamic>>());
      expect(patch['exam'], isA<Map<String, dynamic>>());
    });
  });

  group('mergeDraftIntoEncounterMap', () {
    test('preserva status draft e remove assinatura', () {
      final Map<String, dynamic> existing = <String, dynamic>{
        'status': 'draft',
        'assessment': 'Antigo',
        'signedAt': 'nao-deve-ficar',
        'signatureHash': 'hash',
        'anamnesis': <String, dynamic>{'chiefComplaint': 'Velha'},
      };
      const VoiceStructuredDraft draft = VoiceStructuredDraft(
        chiefComplaint: 'Nova',
        assessment: 'Nova avaliacao',
        plan: 'Plano',
      );

      final Map<String, dynamic> merged =
          VoiceConsultationRepository.mergeDraftIntoEncounterMap(
        existing,
        draft,
      );

      expect(merged['status'], 'draft');
      expect(merged.containsKey('signedAt'), isFalse);
      expect(merged.containsKey('signatureHash'), isFalse);
      expect(
        (merged['anamnesis'] as Map<String, dynamic>)['chiefComplaint'],
        'Nova',
      );
      expect(merged['assessment'], 'Nova avaliacao');
    });
  });

  group('VoiceSessionStatus', () {
    test('labels e fromName', () {
      expect(VoiceSessionStatus.draftReady.label, isNotEmpty);
      expect(
        VoiceSessionStatus.fromName('recording'),
        VoiceSessionStatus.recording,
      );
    });
  });
}
