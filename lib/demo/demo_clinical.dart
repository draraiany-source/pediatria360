import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/dose_calculator.dart';
import '../shared/clinical/orientation_templates.dart';
import '../shared/clinical/rx_templates.dart';
import '../shared/wellchild/guidance_examples.dart';
import '../shared/wellchild/milestones.dart';
import '../shared/wellchild/well_child_templates.dart';
import '../shared/wellchild/well_child_visit.dart';
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

class ConsultationAddendum {
  const ConsultationAddendum({
    required this.at,
    required this.author,
    required this.text,
  });

  final DateTime at;
  final String author;
  final String text;
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
    this.ownerId,
    this.wellChild,
    this.appointmentId,
    this.returnPlan = '',
    this.returnInDays,
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

  /// Conta que iniciou a consulta; `null` = conta principal.
  final String? ownerId;

  /// Preenchido nas consultas de puericultura.
  WellChildVisit? wellChild;

  /// Horário da agenda que originou a consulta.
  String? appointmentId;

  /// Plano de retorno (texto) e prazo em dias; `null` = sem retorno marcado.
  String returnPlan;
  int? returnInDays;

  /// Complementos após finalizar: o texto original não muda.
  final List<ConsultationAddendum> addenda = <ConsultationAddendum>[];

  bool get isDraft => status == DemoConsultationStatus.draft;
  bool get isWellChild => wellChild != null;

  List<String> get missingToFinish => wellChild != null
      ? wellChild!.missingToFinish
      : <String>[
          if (complaint.trim().isEmpty) 'Motivo da consulta',
          if (assessment.trim().isEmpty) 'Avaliação',
          if (plan.trim().isEmpty) 'Conduta',
        ];

  String get summary => wellChild != null
      ? <String>[
          'Consulta de puericultura',
          if (wellChild!.summary.isNotEmpty) wellChild!.summary,
        ].join('\n')
      : <String>[
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
        ...guidanceExamples(author: DemoProfessional.name, now: now),
      ];

  /// Modelos de evolução de puericultura de exemplo (a revisar).
  static List<WellChildTemplate> wellChildTemplates({
    required String author,
    required DateTime now,
  }) => wellChildTemplateExamples(author: author, now: now);

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
          appointmentId: 'a8',
          returnPlan: 'Retorno em 30 dias para reavaliação (exemplo).',
          returnInDays: 30,
        ),
        DemoConsultation(
          id: 'c2',
          patientId: 'p5',
          startedAt: now.subtract(const Duration(hours: 2)),
          author: DemoProfessional.name,
          complaint: 'Motivo fictício em andamento.',
        ),
        _wellChildSeed(now),
      ];

  /// Puericultura finalizada de Luna, com próxima consulta e itens de
  /// acompanhamento que aparecem no calendário da família.
  static DemoConsultation _wellChildSeed(DateTime now) {
    final DateTime d = now.subtract(const Duration(days: 40));
    final DateTime at = DateTime(d.year, d.month, d.day, 9);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final WellChildVisit v = WellChildVisit(
      fields: const <WellChildSection, String>{
        WellChildSection.historia:
            'Sem intercorrências desde a última consulta (texto fictício).',
        WellChildSection.alimentacao:
            'Aleitamento e alimentação da família conforme combinado '
            '(exemplo).',
        WellChildSection.sono:
            'Família relata despertares noturnos; combinado registrar no '
            'diário do app (exemplo).',
        WellChildSection.eliminacoes: 'Sem queixas (exemplo).',
        WellChildSection.vacinacao: 'Carteira conferida na consulta (exemplo).',
        WellChildSection.exameFisico:
            'Exame de exemplo para demonstração, sem alterações descritas.',
        WellChildSection.crescimento:
            'Medidas registradas na curva (comentário fictício).',
        WellChildSection.desenvolvimento:
            'Marcos observados registrados abaixo (exemplo).',
        WellChildSection.avaliacao:
            'Avaliação fictícia de puericultura para testar o fluxo.',
        WellChildSection.plano:
            'Retorno na data sugerida; trazer o diário do sono (exemplo).',
      },
      milestones: const <MilestoneObservation>[
        MilestoneObservation(
          code: 'b2-anda',
          title: 'Anda sem apoio',
          area: MilestoneArea.motorGrosso,
          state: MilestoneState.emAquisicao,
        ),
        MilestoneObservation(
          code: 'b2-palavras',
          title: 'Fala palavras com significado',
          area: MilestoneArea.linguagem,
          state: MilestoneState.adquirido,
        ),
        MilestoneObservation(
          code: 'b2-aponta',
          title: 'Aponta para mostrar o que quer',
          area: MilestoneArea.social,
          state: MilestoneState.adquirido,
        ),
      ],
      questions: const <GuardianQuestion>[
        GuardianQuestion(
          question: 'Como organizar a rotina da noite? (exemplo)',
          answer:
              'Conversado sobre horário regular e ritual curto '
              '(exemplo).',
        ),
      ],
      guidance:
          'Rotina e sono conversados; orientação por escrito emitida '
          '(exemplo).',
      nextVisit: today.add(const Duration(days: 20)),
      followUps: <FollowUpItem>[
        FollowUpItem(
          id: 'fu1',
          title: 'Trazer o diário do sono da última semana (exemplo)',
          due: today.add(const Duration(days: 18)),
        ),
        FollowUpItem(
          id: 'fu2',
          title: 'Retomar a conversa sobre a alimentação (exemplo)',
          due: today.add(const Duration(days: 20)),
        ),
      ],
      history: <VisitRevision>[
        VisitRevision(at: at, author: DemoProfessional.name, action: 'Criada'),
        VisitRevision(
          at: at.add(const Duration(minutes: 40)),
          author: DemoProfessional.name,
          action: 'Finalizada',
        ),
      ],
    );
    return DemoConsultation(
      id: 'c3',
      patientId: 'p1',
      startedAt: at,
      author: DemoProfessional.name,
      complaint: 'Consulta de puericultura',
      assessment: v.field(WellChildSection.avaliacao),
      plan: v.field(WellChildSection.plano),
      status: DemoConsultationStatus.finished,
      ownerId: DemoProfessional.id,
      wellChild: v,
      appointmentId: 'a11',
      updatedAt: at.add(const Duration(minutes: 40)),
    );
  }

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

    final DateTime wcDay = now.subtract(const Duration(days: 40));
    final DateTime wcAt = DateTime(wcDay.year, wcDay.month, wcDay.day, 9, 30);
    final DocContext wcCtx = contextFor(
      luna,
      date: DateTime(wcDay.year, wcDay.month, wcDay.day),
    );
    final ClinicalDocRecord sleepGuide = ClinicalDocRecord.createDraft(
      id: 'd4',
      kind: DocKind.orientacoes,
      patientId: 'p1',
      consultationId: 'c3',
      ownerId: DemoProfessional.id,
      author: DemoProfessional.name,
      context: wcCtx,
      now: wcAt,
      fields: <String, String>{
        'titulo': 'Rotina e sono',
        'texto':
            'Rotina de Luna Exemplo Souza, combinada com Responsável '
            'Exemplo A (texto de exemplo, revisado pela profissional '
            'fictícia).\n\n'
            '1. Mantenha horário regular para dormir, também nos fins de '
            'semana.\n'
            '2. Ritual curto antes de dormir, com luz baixa e sem telas.\n'
            '3. Registre no diário do app o sono da noite, os cochilos e os '
            'despertares até a próxima consulta.\n'
            '4. Ruído branco, aplicativos ou aparelhos para ninar não '
            'substituem as orientações de sono seguro.',
      },
    ).markReviewed(reviewer: DemoProfessional.name, now: wcAt).issue(now: wcAt);
    return <ClinicalDocRecord>[atestado, encaminhamento, receita, sleepGuide];
  }
}
