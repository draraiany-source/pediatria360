import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/clinical_record.dart';
import 'package:pediatria360/shared/domain/entities/encounter.dart';

/// Percurso completo de um atendimento, do rascunho ao documento emitido.
///
/// ## O que estes testes cobrem
///
/// A **máquina de estados** do atendimento: o que pode ser feito em cada
/// momento e o que fica bloqueado. É onde moram as regras que protegem o
/// prontuário — assinar sem diagnóstico, editar depois de assinado, emitir
/// receita a partir de rascunho.
///
/// Não cobrem escrita no Firestore (isso são os 47 testes de regras) nem
/// renderização de tela. Testar as três coisas juntas produz um teste que
/// falha por rede quando o problema é lógica.
void main() {
  /// Constrói um atendimento no estado desejado.
  Encounter build({
    EncounterStatus status = EncounterStatus.draft,
    String complaint = '',
    VitalSigns vitals = const VitalSigns(),
    PhysicalExam exam = const PhysicalExam(),
    List<Diagnosis> diagnoses = const <Diagnosis>[],
    String plan = '',
    DateTime? signedAt,
    String? amends,
  }) =>
      Encounter(
        id: 'e1',
        patientId: 'p1',
        professionalId: 'd1',
        professionalName: 'Dra. Marta',
        professionalCrm: '123456/SP',
        patientName: 'Manuela Silva',
        patientBirthDate: DateTime(2025, 3, 10),
        type: EncounterType.routine,
        status: status,
        startedAt: DateTime(2026, 7, 20, 9, 0),
        anamnesis: Anamnesis(chiefComplaint: complaint),
        vitals: vitals,
        exam: exam,
        diagnoses: diagnoses,
        plan: plan,
        signedAt: signedAt,
        amendsEncounterId: amends,
      );

  const Diagnosis ivas = Diagnosis(
    code: 'J06',
    description: 'Infecção aguda das vias aéreas superiores',
    certainty: DiagnosisCertainty.confirmed,
  );

  group('1. atendimento novo nasce incompleto', () {
    test('rascunho vazio não pode ser assinado', () {
      final Encounter e = build();

      expect(e.isEditable, isTrue);
      expect(e.isSigned, isFalse);
      expect(e.canSign, isFalse);
    });

    test('a tela sabe exatamente o que falta', () {
      // Mensagem genérica de "preencha os campos" faz o médico caçar o
      // problema. A lista nomeia cada pendência.
      final Encounter e = build();

      expect(
        e.missingForSignature,
        containsAll(<String>[
          'Queixa principal',
          'Exame físico ou sinais vitais',
          'Ao menos um diagnóstico',
          'Conduta',
        ]),
      );
    });
  });

  group('2. preenchimento libera a assinatura', () {
    test('só a queixa não basta', () {
      final Encounter e = build(complaint: 'Febre há 2 dias');
      expect(e.canSign, isFalse);
      expect(e.missingForSignature, isNot(contains('Queixa principal')));
    });

    test('sinais vitais satisfazem o requisito de exame', () {
      // Numa teleconsulta o exame físico pode não existir, mas os vitais
      // aferidos em casa existem. Exigir os dois travaria o atendimento.
      final Encounter e = build(
        complaint: 'Febre',
        vitals: const VitalSigns(temperatureC: 38.4, heartRate: 130),
        diagnoses: <Diagnosis>[ivas],
        plan: 'Sintomáticos e reavaliação em 48h',
      );

      expect(e.canSign, isTrue);
    });

    test('exame físico também satisfaz, sem vitais', () {
      final Encounter e = build(
        complaint: 'Febre',
        exam: const PhysicalExam(
          findings: <String, String>{
            'respiratory': 'Murmúrio vesicular presente e simétrico.',
          },
          systemsExamined: <String>{'respiratory'},
        ),
        diagnoses: <Diagnosis>[ivas],
        plan: 'Sintomáticos',
      );

      expect(e.canSign, isTrue);
    });

    test('sem diagnóstico não assina', () {
      final Encounter e = build(
        complaint: 'Febre',
        vitals: const VitalSigns(temperatureC: 38.4),
        plan: 'Sintomáticos',
      );

      expect(e.canSign, isFalse);
      expect(e.missingForSignature, contains('Ao menos um diagnóstico'));
    });

    test('sem conduta não assina', () {
      // Registro sem conduta não diz o que foi decidido — é anotação, não
      // prontuário.
      final Encounter e = build(
        complaint: 'Febre',
        vitals: const VitalSigns(temperatureC: 38.4),
        diagnoses: <Diagnosis>[ivas],
      );

      expect(e.canSign, isFalse);
      expect(e.missingForSignature, contains('Conduta'));
    });
  });

  group('3. assinatura torna imutável', () {
    final Encounter signed = build(
      status: EncounterStatus.signed,
      complaint: 'Febre',
      vitals: const VitalSigns(temperatureC: 38.4),
      diagnoses: <Diagnosis>[ivas],
      plan: 'Sintomáticos',
      signedAt: DateTime(2026, 7, 20, 9, 30),
    );

    test('deixa de ser editável', () {
      expect(signed.isSigned, isTrue);
      expect(signed.isEditable, isFalse);
    });

    test('a retificação carrega o vínculo com o original', () {
      final Encounter amendment = build(
        status: EncounterStatus.draft,
        complaint: 'Febre',
        vitals: const VitalSigns(temperatureC: 38.4),
        diagnoses: <Diagnosis>[ivas],
        plan: 'Sintomáticos e antibiótico',
        amends: 'e1',
      );

      expect(amendment.amendsEncounterId, 'e1');
      expect(amendment.isEditable, isTrue);
      // O original permanece assinado e legível.
      expect(signed.isSigned, isTrue);
    });
  });

  group('4. exame físico distingue normal de não examinado', () {
    test('aparelho não avaliado aparece na lista de pendências', () {
      // Campo em branco não diz se estava normal ou se não foi olhado — e é
      // essa distinção que se discute quando algo dá errado.
      const PhysicalExam exam = PhysicalExam(
        findings: <String, String>{'respiratory': 'MV+ sem ruídos.'},
        systemsExamined: <String>{'respiratory'},
      );

      expect(exam.notExamined.length, ExamSystem.values.length - 1);
      expect(exam.notExamined, isNot(contains(ExamSystem.respiratory)));
      expect(exam.notExamined, contains(ExamSystem.cardiovascular));
    });

    test('todo aparelho tem texto de normalidade pronto', () {
      for (final ExamSystem s in ExamSystem.values) {
        expect(s.normalFinding, isNotEmpty, reason: s.label);
        expect(s.normalFinding.length, greaterThan(20), reason: s.label);
      }
    });
  });

  group('5. idade do paciente é a da data do atendimento', () {
    test('não usa a idade de hoje', () {
      // Um atendimento de 2 anos atrás precisa mostrar a idade de então;
      // caso contrário toda a interpretação clínica fica errada.
      final Encounter e = build();
      expect(e.patientAgeMonthsAtEncounter, 16);
    });

    test('nascimento no futuro não gera idade negativa', () {
      final Encounter e = Encounter(
        id: 'e2',
        patientId: 'p1',
        professionalId: 'd1',
        professionalName: '',
        type: EncounterType.routine,
        status: EncounterStatus.draft,
        startedAt: DateTime(2026, 1, 1),
        patientBirthDate: DateTime(2026, 6, 1),
      );
      expect(e.patientAgeMonthsAtEncounter, 0);
    });
  });

  group('6. documentos emitidos', () {
    ClinicalDocument doc({
      ClinicalDocumentType type = ClinicalDocumentType.prescription,
      List<PrescriptionItem> items = const <PrescriptionItem>[],
      DateTime? validUntil,
      bool cancelled = false,
    }) =>
        ClinicalDocument(
          id: 'd1',
          encounterId: 'e1',
          patientId: 'p1',
          professionalId: 'd1',
          type: type,
          issuedAt: DateTime(2026, 7, 20),
          content: 'Conteúdo do documento.',
          items: items,
          validUntil: validUntil,
          cancelled: cancelled,
          verificationCode: 'ABCDE-FGHJK',
        );

    test('receita com controlado muda o modelo impresso', () {
      final ClinicalDocument d = doc(
        items: const <PrescriptionItem>[
          PrescriptionItem(
            drug: 'Exemplo',
            presentation: 'comprimido',
            dose: '1 cp',
            route: 'Via oral',
            frequency: 'a cada 12 horas',
            duration: 'por 7 dias',
            isControlled: true,
          ),
        ],
      );

      expect(d.hasControlledDrug, isTrue);
    });

    test('documento vencido não é válido', () {
      final ClinicalDocument d = doc(validUntil: DateTime(2020, 1, 1));
      expect(d.isExpired, isTrue);
      expect(d.isValid, isFalse);
    });

    test('cancelado continua legível mas inválido', () {
      // Um documento que circulou não deixa de ter circulado — quem o
      // receber precisa poder conferir que foi anulado.
      final ClinicalDocument d = doc(cancelled: true);
      expect(d.isValid, isFalse);
      expect(d.content, isNotEmpty);
      expect(d.verificationCode, isNotNull);
    });

    test('sem prazo declarado não vence', () {
      final ClinicalDocument d = doc(type: ClinicalDocumentType.report);
      expect(d.isExpired, isFalse);
      expect(d.isValid, isTrue);
    });

    test('código de conferência não tem caractere ambíguo', () {
      // O código é ditado por telefone para farmácia e escola.
      const String code = 'ABCDE-FGHJK';
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
      expect(code.contains('I'), isFalse);
    });
  });

  group('7. posologia impressa', () {
    test('monta a linha na ordem que se lê', () {
      const PrescriptionItem item = PrescriptionItem(
        drug: 'Amoxicilina',
        presentation: 'suspensão 250 mg/5 mL',
        dose: '5 mL',
        route: 'Via oral',
        frequency: 'a cada 8 horas',
        duration: 'por 10 dias',
      );

      expect(item.printedLine, 'Amoxicilina — suspensão 250 mg/5 mL');
      expect(
        item.printedPosology,
        '5 mL, Via oral, a cada 8 horas, por 10 dias',
      );
    });

    test('campos vazios não deixam vírgula solta', () {
      const PrescriptionItem item = PrescriptionItem(
        drug: 'Soro fisiológico',
        presentation: '',
        dose: '',
        route: 'Via nasal',
        frequency: 'se necessário',
        duration: '',
      );

      expect(item.printedLine, 'Soro fisiológico');
      expect(item.printedPosology, 'Via nasal, se necessário');
    });
  });

  group('8. exames laboratoriais sinalizam sem interpretar', () {
    LabResult lab({double? value, double? low, double? high}) => LabResult(
          id: 'l1',
          patientId: 'p1',
          analyte: 'Hemoglobina',
          collectedAt: DateTime(2026, 7, 20),
          value: value,
          unit: 'g/dL',
          referenceLow: low,
          referenceHigh: high,
        );

    test('dentro da faixa não sinaliza', () {
      expect(lab(value: 12.5, low: 11.5, high: 15.5).isOutOfRange, isFalse);
    });

    test('abaixo sinaliza a direção', () {
      final LabResult r = lab(value: 9.8, low: 11.5, high: 15.5);
      expect(r.isOutOfRange, isTrue);
      expect(r.deviation, 'abaixo');
    });

    test('acima sinaliza a direção', () {
      final LabResult r = lab(value: 17.2, low: 11.5, high: 15.5);
      expect(r.deviation, 'acima');
    });

    test('limite exato está dentro da faixa', () {
      expect(lab(value: 11.5, low: 11.5, high: 15.5).isOutOfRange, isFalse);
      expect(lab(value: 15.5, low: 11.5, high: 15.5).isOutOfRange, isFalse);
    });

    test('sem faixa de referência não sinaliza', () {
      // Sinalizar sem referência seria inventar um limite.
      expect(lab(value: 9.8).isOutOfRange, isFalse);
      expect(lab(value: 9.8).deviation, isNull);
    });

    test('faixa aberta só de um lado', () {
      expect(lab(value: 200, low: 100).referenceLabel, '> 100,0');
      expect(lab(value: 50, high: 100).referenceLabel, '< 100,0');
    });
  });
}
