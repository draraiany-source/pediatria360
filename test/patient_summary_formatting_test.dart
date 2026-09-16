import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/emr/presentation/screens/patient_summary_formatting.dart';
import 'package:pediatria360/shared/domain/entities/clinical_record.dart';
import 'package:pediatria360/shared/domain/entities/encounter.dart';
import 'package:pediatria360/shared/domain/entities/growth_record.dart';

/// Testa a formatação do Resumo 360° — a parte que a Fase 1 mais insiste em
/// não deixar acontecer por acidente: nenhum número fictício preenchendo
/// card, "Sem registro" sempre que não há dado real.
void main() {
  GrowthRecord growth({
    double? weightKg,
    double? heightCm,
    double? headCircumferenceCm,
    DateTime? measuredAt,
  }) =>
      GrowthRecord(
        id: 'g1',
        childId: 'crianca-1',
        measuredAt: measuredAt ?? DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        weightKg: weightKg,
        heightCm: heightCm,
        headCircumferenceCm: headCircumferenceCm,
      );

  Encounter encounter({required DateTime startedAt}) => Encounter(
        id: 'e-${startedAt.toIso8601String()}',
        patientId: 'crianca-1',
        professionalId: 'dra',
        professionalName: 'Dra. Teste',
        type: EncounterType.routine,
        status: EncounterStatus.signed,
        startedAt: startedAt,
      );

  group('formatGrowthSummary — paciente SEM dado', () {
    test('nenhuma medição → "Sem registro", não número inventado', () {
      expect(formatGrowthSummary(null), 'Sem registro');
    });

    test('medição existe mas sem nenhum valor → mensagem própria, não vazio silencioso', () {
      expect(formatGrowthSummary(growth()), 'Registro sem valores');
    });
  });

  group('formatGrowthSummary — paciente COM dado', () {
    test('só peso: mostra só peso, não inventa altura', () {
      final String result = formatGrowthSummary(growth(weightKg: 12.5));
      expect(result, contains('12,5 kg'));
      expect(result, isNot(contains('IMC')));
      expect(result, isNot(contains('cm')));
    });

    test('peso e altura: calcula IMC — não aparece com só um dos dois', () {
      final String result =
          formatGrowthSummary(growth(weightKg: 12.5, heightCm: 90));
      expect(result, contains('12,5 kg'));
      expect(result, contains('90,0 cm'));
      expect(result, contains('IMC'));
    });

    test('perímetro cefálico aparece quando presente', () {
      final String result = formatGrowthSummary(
        growth(weightKg: 4, heightCm: 52, headCircumferenceCm: 35),
      );
      expect(result, contains('PC 35,0 cm'));
    });

    test('inclui a data da medição', () {
      final String result = formatGrowthSummary(
        growth(weightKg: 10, measuredAt: DateTime(2026, 3, 15)),
      );
      expect(result, contains('15/03/2026'));
    });
  });

  group('formatConsultationsSummary — paciente SEM dado', () {
    test('nenhum atendimento → "Sem registro", não consulta inventada', () {
      expect(formatConsultationsSummary(const <Encounter>[]), 'Sem registro');
    });
  });

  group('formatConsultationsSummary — paciente COM dado', () {
    test('um atendimento: singular correto', () {
      final String result = formatConsultationsSummary(
        <Encounter>[encounter(startedAt: DateTime(2026, 1, 10))],
      );
      expect(result, contains('1 atendimento'));
      expect(result, isNot(contains('1 atendimentos')));
    });

    test('vários atendimentos: plural, e mostra o mais recente como "última"', () {
      final String result = formatConsultationsSummary(<Encounter>[
        encounter(startedAt: DateTime(2026, 1, 10)),
        encounter(startedAt: DateTime(2026, 5, 20)), // mais recente
        encounter(startedAt: DateTime(2026, 3, 1)),
      ]);
      expect(result, contains('3 atendimentos'));
      expect(result, contains('20/05/2026')); // a última, não a primeira da lista
    });

    test('não menciona "próxima consulta" — não existe fonte de dado aqui', () {
      // formatConsultationsSummary só recebe Encounter, nunca Appointment —
      // não deveria inventar uma "próxima consulta" que não tem de onde vir.
      final String result = formatConsultationsSummary(
        <Encounter>[encounter(startedAt: DateTime(2026, 1, 10))],
      );
      expect(result.toLowerCase(), isNot(contains('próxima')));
    });
  });

  LabResult lab({required String analyte, required DateTime collectedAt}) =>
      LabResult(
        id: 'lab-${collectedAt.toIso8601String()}',
        patientId: 'crianca-1',
        analyte: analyte,
        collectedAt: collectedAt,
      );

  ClinicalDocument document({
    required DateTime issuedAt,
    bool cancelled = false,
  }) =>
      ClinicalDocument(
        id: 'doc-${issuedAt.toIso8601String()}',
        encounterId: 'e1',
        patientId: 'crianca-1',
        professionalId: 'dra',
        type: ClinicalDocumentType.prescription,
        issuedAt: issuedAt,
        content: 'conteúdo de teste',
        cancelled: cancelled,
      );

  group('formatLabsSummary — paciente SEM dado', () {
    test('nenhum exame → "Sem registro", não exame inventado', () {
      expect(formatLabsSummary(const <LabResult>[]), 'Sem registro');
    });
  });

  group('formatLabsSummary — paciente COM dado', () {
    test('um exame: singular correto, mostra o analito e a data', () {
      final String result = formatLabsSummary(
        <LabResult>[lab(analyte: 'Hemoglobina', collectedAt: DateTime(2026, 2, 1))],
      );
      expect(result, contains('Hemoglobina'));
      expect(result, contains('01/02/2026'));
      expect(result, contains('1 exame'));
      expect(result, isNot(contains('1 exames')));
    });

    test('vários exames: plural, mostra o mais recente', () {
      final String result = formatLabsSummary(<LabResult>[
        lab(analyte: 'Hemoglobina', collectedAt: DateTime(2026, 1, 1)),
        lab(analyte: 'Glicemia', collectedAt: DateTime(2026, 4, 1)), // mais recente
      ]);
      expect(result, contains('Glicemia'));
      expect(result, contains('2 exames'));
    });
  });

  group('formatDocumentsSummary — paciente SEM dado', () {
    test('nenhum documento → "Sem registro"', () {
      expect(formatDocumentsSummary(const <ClinicalDocument>[]), 'Sem registro');
    });

    test('só documento cancelado → "Sem registro", não conta como ativo', () {
      final String result = formatDocumentsSummary(
        <ClinicalDocument>[document(issuedAt: DateTime(2026, 1, 1), cancelled: true)],
      );
      expect(result, 'Sem registro');
    });
  });

  group('formatDocumentsSummary — paciente COM dado', () {
    test('um documento ativo: singular correto', () {
      final String result = formatDocumentsSummary(
        <ClinicalDocument>[document(issuedAt: DateTime(2026, 3, 10))],
      );
      expect(result, contains('10/03/2026'));
      expect(result, contains('1 documento'));
      expect(result, isNot(contains('1 documentos')));
    });

    test('documento cancelado não entra na contagem, mesmo com ativos presentes', () {
      final String result = formatDocumentsSummary(<ClinicalDocument>[
        document(issuedAt: DateTime(2026, 1, 1)),
        document(issuedAt: DateTime(2026, 2, 1), cancelled: true),
        document(issuedAt: DateTime(2026, 3, 1)),
      ]);
      // 3 documentos no total, mas só 2 ativos — a contagem tem que
      // refletir isso, não o tamanho bruto da lista.
      expect(result, contains('2 documentos'));
    });
  });
}
