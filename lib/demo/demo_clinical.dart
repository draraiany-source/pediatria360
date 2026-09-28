import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/dose_calculator.dart';
import '../shared/clinical/orientation_templates.dart';
import '../shared/clinical/rx_templates.dart';
import 'demo_data.dart';

/// Dados clínicos fictícios da demonstração: profissional, referências de
/// dose de teste, consultas, modelos de orientação e documentos.
///
/// As referências de dose usam medicamentos inexistentes ("Exemplo A/B/C")
/// e números escolhidos só para exercitar as contas e os alertas.
class DemoProfessional {
  const DemoProfessional._();

  static const String id = 'prof-a';
  static const String name = 'Dra. Exemplo Demonstração';
  static const String registry = 'CRM 00000-UF (fictício)';
  static const String specialty = 'Pediatria';
  static const String clinic = 'Consultório Exemplo (fictício)';
  static const String address = 'Rua Exemplo, 100 - Centro - Cidade Exemplo';
  static const String city = 'Cidade Exemplo';

  static const DemoAccount account = DemoAccount(
    id: id,
    name: name,
    registry: registry,
    specialty: specialty,
    clinic: clinic,
    address: address,
    city: city,
    email: 'dra.exemplo@exemplo.invalid',
  );

  /// Segunda conta fictícia, para conferir que a logomarca de uma conta não
  /// aparece para outra.
  static const DemoAccount colleague = DemoAccount(
    id: 'prof-b',
    name: 'Dr. Exemplo Colega',
    registry: 'CRM 11111-UF (fictício)',
    specialty: 'Pediatria',
    clinic: 'Clínica Exemplo Dois (fictícia)',
    address: 'Avenida Exemplo, 200 - Bairro Exemplo - Cidade Exemplo',
    city: 'Cidade Exemplo',
    email: 'dr.colega@exemplo.invalid',
  );

  static const List<DemoAccount> accounts = <DemoAccount>[account, colleague];

  static DemoAccount byId(String? id) =>
      accounts.firstWhere((DemoAccount a) => a.id == id, orElse: () => account);
}

/// Conta de profissional ou clínica na demonstração.
class DemoAccount {
  const DemoAccount({
    required this.id,
    required this.name,
    required this.registry,
    required this.specialty,
    required this.clinic,
    required this.address,
    required this.city,
    required this.email,
  });

  final String id;
  final String name;
  final String registry;
  final String specialty;
  final String clinic;
  final String address;
  final String city;
  final String email;
}

enum DemoConsultationStatus {
  draft('Rascunho'),
  finished('Finalizada');

  const DemoConsultationStatus(this.label);

  final String label;
}

/// Consulta: Paciente → Consulta → Avaliação → Conduta → Documentos.
class DemoConsultation {
  DemoConsultation({
    required this.id,
    required this.patientId,
    required this.startedAt,
    required this.author,
    this.complaint = '',
    this.history = '',
    this.physicalExam = '',
    this.assessment = '',
    this.plan = '',
    this.status = DemoConsultationStatus.draft,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? startedAt;

  final String id;
  final String patientId;
  final DateTime startedAt;
  final String author;
  String complaint;
  String history;
  String physicalExam;
  String assessment;
  String plan;
  DemoConsultationStatus status;
  DateTime updatedAt;

  bool get isDraft => status == DemoConsultationStatus.draft;

  List<String> get missingToFinish => <String>[
    if (complaint.trim().isEmpty) 'Motivo da consulta',
    if (assessment.trim().isEmpty) 'Avaliação',
    if (plan.trim().isEmpty) 'Conduta',
  ];

  String get summary => <String>[
    if (complaint.trim().isNotEmpty) 'Motivo: ${complaint.trim()}',
    if (assessment.trim().isNotEmpty) 'Avaliação: ${assessment.trim()}',
    if (plan.trim().isNotEmpty) 'Conduta: ${plan.trim()}',
  ].join('\n');
}

class DemoClinicalSeed {
  const DemoClinicalSeed._();

  static const String testSource =
      'Referência fictícia criada para testar o cálculo. Não corresponde a '
      'nenhum medicamento e não deve ser usada em pacientes.';

  static final List<DoseReference> doseReferences = <DoseReference>[
    DoseReference(
      id: 'ref-a',
      drugName: 'Medicamento Exemplo A',
      indication: 'Indicação fictícia A (teste de mg/kg/dose)',
      basis: DoseBasis.perDose,
      mgPerKg: 15,
      minMgPerKg: 10,
      maxMgPerKg: 15,
      dosesPerDay: 4,
      maxSingleDoseMg: 500,
      maxDailyDoseMg: 2000,
      source: testSource,
      reviewedAt: DateTime(2026, 9, 1),
      reviewedBy: 'Equipe de homologação (fictícia)',
      validated: true,
      presentations: const <DrugPresentation>[
        DrugPresentation(
          id: 'a-susp',
          label: 'Suspensão 100 mg/5 mL',
          form: PresentationForm.liquid,
          amount: 100,
          perVolumeMl: 5,
          maxVolumePerDoseMl: 20,
        ),
        DrugPresentation(
          id: 'a-gotas',
          label: 'Gotas 200 mg/mL',
          form: PresentationForm.liquid,
          amount: 200,
          perVolumeMl: 1,
        ),
        DrugPresentation(
          id: 'a-comp',
          label: 'Comprimido 500 mg',
          form: PresentationForm.solid,
          amount: 500,
          splittable: true,
          minAgeMonths: 72,
        ),
      ],
    ),
    DoseReference(
      id: 'ref-b',
      drugName: 'Medicamento Exemplo B',
      indication: 'Indicação fictícia B (teste de mg/kg/dia)',
      basis: DoseBasis.perDay,
      mgPerKg: 40,
      minMgPerKg: 30,
      maxMgPerKg: 45,
      dosesPerDay: 2,
      maxDailyDoseMg: 1500,
      minAgeMonths: 24,
      allergyKeywords: const <String>['Exemplo B'],
      source: testSource,
      reviewedAt: DateTime(2026, 9, 1),
      reviewedBy: 'Equipe de homologação (fictícia)',
      validated: true,
      presentations: const <DrugPresentation>[
        DrugPresentation(
          id: 'b-susp',
          label: 'Suspensão 250 mg/5 mL',
          form: PresentationForm.liquid,
          amount: 250,
          perVolumeMl: 5,
        ),
        DrugPresentation(
          id: 'b-sache',
          label: 'Sachê 1 g',
          form: PresentationForm.solid,
          amount: 1,
          amountUnit: MassUnit.g,
          unitName: 'sachê',
        ),
      ],
    ),
    DoseReference(
      id: 'ref-d',
      drugName: 'Suplemento Exemplo D (fictício)',
      indication:
          'Indicação fictícia D (teste do fluxo decisão de suplementação -> '
          'calculadora -> receituário)',
      basis: DoseBasis.perDay,
      mgPerKg: 2,
      minMgPerKg: 1,
      maxMgPerKg: 3,
      dosesPerDay: 1,
      maxDailyDoseMg: 60,
      source: testSource,
      reviewedAt: DateTime(2026, 9, 1),
      reviewedBy: 'Equipe de homologação (fictícia)',
      validated: true,
      presentations: const <DrugPresentation>[
        DrugPresentation(
          id: 'd-gotas',
          label: 'Gotas 10 mg/mL',
          form: PresentationForm.liquid,
          amount: 10,
          perVolumeMl: 1,
        ),
      ],
    ),
    const DoseReference(
      id: 'ref-c',
      drugName: 'Medicamento Exemplo C',
      indication: 'Referência em elaboração (não validada)',
      basis: DoseBasis.perDose,
      mgPerKg: 10,
      dosesPerDay: 3,
      source: '',
      presentations: <DrugPresentation>[
        DrugPresentation(
          id: 'c-susp',
          label: 'Suspensão 50 mg/5 mL',
          form: PresentationForm.liquid,
          amount: 50,
          perVolumeMl: 5,
        ),
      ],
    ),
  ];

  static List<OrientationTemplate> orientationTemplates(DateTime now) =>
      <OrientationTemplate>[
        OrientationTemplate(
          id: 't1',
          title: 'Modelo de exemplo: retorno e sinais de alerta',
          body:
              'Orientações para {{responsavel}} sobre {{crianca}} '
              '({{idade}}), consulta de {{data}}.\n\n'
              '1. [a definir: escreva aqui as orientações próprias do seu '
              'serviço]\n'
              '2. Retornar na data combinada ou antes, se houver piora.\n'
              '3. Levar este documento na próxima consulta.',
          author: DemoProfessional.name,
          updatedAt: now.subtract(const Duration(days: 20)),
          isExample: true,
        ),
        OrientationTemplate(
          id: 't2',
          title: 'Modelo de exemplo: uso da medicação prescrita',
          body:
              '{{responsavel}}, siga a receita de {{crianca}} exatamente '
              'como está escrita. Peso usado no cálculo: {{peso}}.\n\n'
              'Use sempre o dosador que acompanha o medicamento. Em caso de '
              'dúvida, entre em contato com o consultório antes de alterar a '
              'dose.',
          author: DemoProfessional.name,
          updatedAt: now.subtract(const Duration(days: 5)),
          isExample: true,
        ),
      ];

  /// Modelos de receita de exemplo, só com medicamentos fictícios.
  static List<RxTemplate> rxTemplates(DateTime now) => <RxTemplate>[
    RxTemplate.create(
      id: 'm1',
      name: 'Febre - Medicamento Exemplo A',
      author: DemoProfessional.name,
      now: now.subtract(const Duration(days: 12)),
      isExample: true,
      orientations:
          'Oferecer líquidos a {{crianca}} e retornar se a febre durar mais '
          'de 48 horas ou se houver piora. (Texto de exemplo.)',
      items: const <RxTemplateItem>[
        RxTemplateItem(
          drug: 'Medicamento Exemplo A',
          presentation: 'Suspensão 100 mg/5 mL',
          concentration: '100 mg/5 mL',
          mode: RxDoseMode.weight,
          referenceId: 'ref-a',
          presentationId: 'a-susp',
          mgPerKg: 15,
          frequency: 'de 6/6h',
          duration: 'até 3 dias, se febre',
          quantity: '1 frasco',
          notes: 'Agitar antes de usar.',
        ),
      ],
    ),
    RxTemplate.create(
      id: 'm2',
      name: 'Suplemento D + lavagem nasal',
      author: DemoProfessional.name,
      now: now.subtract(const Duration(days: 4)),
      isExample: true,
      orientations:
          'Usar o dosador que acompanha o frasco. Guardar fora do alcance '
          'de {{crianca}}. (Texto de exemplo.)',
      items: const <RxTemplateItem>[
        RxTemplateItem(
          drug: 'Suplemento Exemplo D (fictício)',
          presentation: 'Gotas 10 mg/mL',
          concentration: '10 mg/1 mL',
          mode: RxDoseMode.weight,
          referenceId: 'ref-d',
          presentationId: 'd-gotas',
          mgPerKg: 2,
          frequency: '1 vez ao dia (24/24h)',
          duration: '30 dias',
          quantity: '1 frasco',
        ),
        RxTemplateItem(
          drug: 'Solução Exemplo E (fictícia)',
          presentation: 'Solução nasal',
          concentration: '0,9%',
          mode: RxDoseMode.fixed,
          fixedDose: '2 jatos em cada narina',
          fixedVolume: 'não se aplica (jato)',
          route: 'via nasal',
          frequency: 'até 4 vezes ao dia',
          duration: '5 dias',
          quantity: '1 frasco',
        ),
      ],
    ),
  ];

  static DocContext contextFor(
    DemoPatient p, {
    required DateTime date,
    String? clinicalSummary,
    DemoAccount account = DemoProfessional.account,
  }) => DocContext(
    patientName: p.name,
    patientBirthDate: p.birthDate,
    guardianName: p.guardianName,
    allergies: p.allergies,
    weightKg: p.weightKg,
    weighedAt: p.weighedAt,
    professionalName: account.name,
    professionalRegistry: account.registry,
    professionalSpecialty: account.specialty,
    clinicName: account.clinic,
    clinicAddress: account.address,
    city: account.city,
    date: date,
    clinicalSummary: clinicalSummary,
  );

  static List<DemoConsultation> consultations(DateTime now) =>
      <DemoConsultation>[
        DemoConsultation(
          id: 'c1',
          patientId: 'p1',
          startedAt: now.subtract(const Duration(days: 10)),
          author: DemoProfessional.name,
          complaint: 'Consulta de rotina (texto fictício).',
          history: 'Sem intercorrências relatadas (exemplo).',
          physicalExam: 'Exame de exemplo para demonstração.',
          assessment: 'Avaliação fictícia para testar o fluxo.',
          plan: 'Conduta fictícia: retorno programado.',
          status: DemoConsultationStatus.finished,
        ),
        DemoConsultation(
          id: 'c2',
          patientId: 'p5',
          startedAt: now.subtract(const Duration(hours: 2)),
          author: DemoProfessional.name,
          complaint: 'Motivo fictício em andamento.',
        ),
      ];

  /// Um documento emitido e editado (v2 em rascunho) e um rascunho simples,
  /// para o histórico já mostrar versões e estados.
  static List<ClinicalDocRecord> documents(
    List<DemoPatient> patients,
    DateTime now,
  ) {
    final DemoPatient luna = patients.firstWhere(
      (DemoPatient p) => p.id == 'p1',
    );
    final DateTime visit = now.subtract(const Duration(days: 10));
    final DocContext ctx = contextFor(
      luna,
      date: DateTime(visit.year, visit.month, visit.day),
      clinicalSummary: 'Avaliação fictícia para testar o fluxo.',
    );

    ClinicalDocRecord atestado = ClinicalDocRecord.createDraft(
      id: 'd1',
      kind: DocKind.atestado,
      patientId: 'p1',
      consultationId: 'c1',
      ownerId: DemoProfessional.id,
      author: DemoProfessional.name,
      context: ctx,
      now: visit,
    );
    atestado = atestado
        .markReviewed(reviewer: DemoProfessional.name, now: visit)
        .issue(now: visit);
    atestado = atestado.saveDraft(
      fields: <String, String>{...atestado.current.fields, 'dias': '2'},
      items: const <RxItem>[],
      context: ctx,
      author: DemoProfessional.name,
      now: visit.add(const Duration(hours: 1)),
      changeNote: 'Correção do número de dias (exemplo)',
    );
    atestado = atestado
        .markReviewed(
          reviewer: DemoProfessional.name,
          now: visit.add(const Duration(hours: 1)),
        )
        .issue(now: visit.add(const Duration(hours: 1)));

    final ClinicalDocRecord encaminhamento = ClinicalDocRecord.createDraft(
      id: 'd2',
      kind: DocKind.encaminhamento,
      patientId: 'p1',
      consultationId: 'c1',
      ownerId: DemoProfessional.id,
      author: DemoProfessional.name,
      context: ctx,
      now: visit,
      fields: <String, String>{
        ...DocumentTemplates.prefill(DocKind.encaminhamento, ctx),
        'especialidade': 'Especialidade Exemplo',
        'motivo': 'Motivo fictício do encaminhamento.',
      },
    );
    final DateTime rxAt = visit.add(const Duration(minutes: 40));
    final ClinicalDocRecord receita = ClinicalDocRecord.createDraft(
      id: 'd3',
      kind: DocKind.receituario,
      patientId: 'p1',
      consultationId: 'c1',
      ownerId: DemoProfessional.id,
      author: DemoProfessional.name,
      context: ctx,
      now: rxAt,
      items: const <RxItem>[
        RxItem(
          drug: 'Medicamento Exemplo A',
          presentation: 'Suspensão oral (exemplo)',
          dose: '5 mL',
          route: 'via oral',
          frequency: 'de 8/8h',
          duration: '5 dias',
          quantity: '1 frasco',
        ),
        RxItem(
          drug: 'Suplemento Exemplo D',
          presentation: 'Gotas (exemplo)',
          dose: '2 gotas',
          route: 'via oral',
          frequency: '1 vez ao dia (24/24h)',
          duration: '30 dias',
          quantity: '1 frasco',
        ),
      ],
    ).markReviewed(reviewer: DemoProfessional.name, now: rxAt).issue(now: rxAt);
    return <ClinicalDocRecord>[atestado, encaminhamento, receita];
  }
}
