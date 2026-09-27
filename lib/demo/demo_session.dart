import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/dose_calculator.dart';
import '../shared/clinical/growth.dart';
import '../shared/clinical/lab_results.dart';
import '../shared/clinical/orientation_templates.dart';
import '../shared/clinical/supplement_library.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_growth.dart';

/// Perfis da demonstracao — espelham as areas de trabalho do app real.
enum DemoProfile {
  profissional,
  recepcao,
  financeiro,
  administrador,
  responsavel;

  String get label => switch (this) {
    DemoProfile.profissional => 'Profissional de saúde',
    DemoProfile.recepcao => 'Recepção',
    DemoProfile.financeiro => 'Financeiro',
    DemoProfile.administrador => 'Administrador',
    DemoProfile.responsavel => 'Paciente / responsável',
  };

  String get description => switch (this) {
    DemoProfile.profissional =>
      'Consultas, prontuário, documentos, calculadora de doses e '
          'suplementação.',
    DemoProfile.recepcao =>
      'Agenda do dia, chegada e cadastro básico. Sem prontuário.',
    DemoProfile.financeiro => 'Recebimentos e relatórios. Sem dados clínicos.',
    DemoProfile.administrador =>
      'Indicadores gerais, conteúdos da biblioteca e equipe.',
    DemoProfile.responsavel =>
      'Crianças sob seus cuidados, vacinas e conteúdos.',
  };

  IconData get icon => switch (this) {
    DemoProfile.profissional => Icons.medical_services_outlined,
    DemoProfile.recepcao => Icons.event_available_outlined,
    DemoProfile.financeiro => Icons.account_balance_wallet_outlined,
    DemoProfile.administrador => Icons.admin_panel_settings_outlined,
    DemoProfile.responsavel => Icons.family_restroom_outlined,
  };

  static DemoProfile? fromSlug(String? slug) {
    for (final DemoProfile p in DemoProfile.values) {
      if (p.name == slug) return p;
    }
    return null;
  }
}

/// Modulos navegaveis da demonstracao.
enum DemoModule {
  inicio('/inicio', 'Início', Icons.home_outlined, Icons.home_rounded),
  pacientes(
    '/pacientes',
    'Pacientes',
    Icons.people_outline,
    Icons.people_rounded,
  ),
  agenda(
    '/agenda',
    'Agenda',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  calculadora(
    '/calculadora',
    'Calculadora',
    Icons.calculate_outlined,
    Icons.calculate_rounded,
  ),
  suplementacao(
    '/suplementacao',
    'Suplementação',
    Icons.medication_liquid_outlined,
    Icons.medication_liquid_rounded,
  ),
  vacinacao(
    '/vacinacao',
    'Vacinação',
    Icons.vaccines_outlined,
    Icons.vaccines_rounded,
  ),
  telemedicina(
    '/telemedicina',
    'Telemedicina',
    Icons.videocam_outlined,
    Icons.videocam_rounded,
  ),
  biblioteca(
    '/biblioteca',
    'Biblioteca',
    Icons.menu_book_outlined,
    Icons.menu_book_rounded,
  ),
  relatorios(
    '/relatorios',
    'Relatórios',
    Icons.insights_outlined,
    Icons.insights_rounded,
  ),
  financeiro(
    '/financeiro',
    'Financeiro',
    Icons.payments_outlined,
    Icons.payments_rounded,
  ),
  perfil('/perfil', 'Perfil', Icons.person_outline, Icons.person_rounded);

  const DemoModule(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static DemoModule? fromLocation(String location) {
    for (final DemoModule m in DemoModule.values) {
      if (location == m.path || location.startsWith('${m.path}/')) return m;
    }
    return null;
  }
}

/// Estado da sessao de demonstracao. Vive so na memoria da aba do navegador.
class DemoSession extends ChangeNotifier {
  DemoSession() {
    reset();
  }

  DemoProfile? _profile;
  DemoProfile? get profile => _profile;

  /// Liga a "falha de conexao" simulada para ver os estados de erro.
  bool _simulateOffline = false;
  bool get simulateOffline => _simulateOffline;

  late List<DemoPatient> patients;
  late List<DemoEncounter> encounters;
  late List<DemoAppointment> appointments;
  late List<DemoVaccineRecord> vaccines;
  late List<DemoInvoice> invoices;
  late List<DemoConsultation> consultations;
  late List<ClinicalDocRecord> documents;
  late List<OrientationTemplate> orientationTemplates;
  late List<SupplementSheet> supplementSheets;
  late List<GrowthMeasurement> growth;
  late List<GestationalAgeChange> gestationalAgeChanges;
  late List<LabResult> labs;
  late List<SupplementDecision> supplementDecisions;
  final List<DemoArticle> articles = DemoSeed.articles;
  final List<DoseReference> doseReferences = DemoClinicalSeed.doseReferences;

  int _nextId = 100;

  void reset() {
    final DateTime now = DateTime.now();
    patients = DemoSeed.patients();
    encounters = DemoSeed.encounters();
    appointments = DemoSeed.appointments();
    vaccines = DemoSeed.vaccines();
    invoices = DemoSeed.invoices();
    consultations = DemoClinicalSeed.consultations(now);
    documents = DemoClinicalSeed.documents(patients, now);
    orientationTemplates = DemoClinicalSeed.orientationTemplates(now);
    supplementSheets = List<SupplementSheet>.of(kSupplementSheets);
    for (final DemoPatient p in patients) {
      p.gestationalAgeDays = DemoGrowthSeed.gestationalAgeDays[p.id];
    }
    growth = DemoGrowthSeed.measurements(patients, now);
    gestationalAgeChanges = <GestationalAgeChange>[];
    labs = DemoGrowthSeed.labResults(now);
    supplementDecisions = DemoGrowthSeed.decisions(now);
  }

  void enter(DemoProfile profile) {
    if (_profile == profile) return;
    _profile = profile;
    notifyListeners();
  }

  /// Usado pelo redirect do roteador (link com `?perfil=`): notificar ali
  /// dispararia outra avaliacao de rota no meio da atual.
  void enterSilently(DemoProfile profile) => _profile = profile;

  void leave() {
    _profile = null;
    _simulateOffline = false;
    reset();
    notifyListeners();
  }

  void setSimulateOffline(bool value) {
    _simulateOffline = value;
    notifyListeners();
  }

  /// Matriz de acesso ilustrativa. No app real a mesma regra e aplicada no
  /// roteador E nas regras do Firebase; aqui ela so decide o que aparece.
  static const Map<DemoProfile, List<DemoModule>> access =
      <DemoProfile, List<DemoModule>>{
        DemoProfile.profissional: <DemoModule>[
          DemoModule.inicio,
          DemoModule.pacientes,
          DemoModule.agenda,
          DemoModule.calculadora,
          DemoModule.suplementacao,
          DemoModule.vacinacao,
          DemoModule.telemedicina,
          DemoModule.biblioteca,
          DemoModule.perfil,
        ],
        DemoProfile.recepcao: <DemoModule>[
          DemoModule.inicio,
          DemoModule.agenda,
          DemoModule.pacientes,
          DemoModule.perfil,
        ],
        DemoProfile.financeiro: <DemoModule>[
          DemoModule.inicio,
          DemoModule.financeiro,
          DemoModule.relatorios,
          DemoModule.perfil,
        ],
        DemoProfile.administrador: <DemoModule>[
          DemoModule.inicio,
          DemoModule.relatorios,
          DemoModule.biblioteca,
          DemoModule.perfil,
        ],
        DemoProfile.responsavel: <DemoModule>[
          DemoModule.inicio,
          DemoModule.pacientes,
          DemoModule.vacinacao,
          DemoModule.telemedicina,
          DemoModule.biblioteca,
          DemoModule.perfil,
        ],
      };

  List<DemoModule> get modules =>
      _profile == null ? const <DemoModule>[] : access[_profile]!;

  bool canOpen(DemoModule module) => modules.contains(module);

  /// Prontuario e so do profissional; a recepcao ve cadastro, nao clinica.
  bool get canSeeClinicalRecord => _profile == DemoProfile.profissional;

  /// O responsavel ve apenas as criancas vinculadas a ele (ficticio: A).
  List<DemoPatient> get visiblePatients {
    if (_profile == DemoProfile.responsavel) {
      return patients
          .where((DemoPatient p) => p.guardianName == guardianOfDemo)
          .toList(growable: false);
    }
    return List<DemoPatient>.unmodifiable(patients);
  }

  static const String guardianOfDemo = 'Responsável Exemplo A';

  DemoPatient? patientById(String id) {
    for (final DemoPatient p in visiblePatients) {
      if (p.id == id) return p;
    }
    return null;
  }

  DemoPatient addPatient({
    required String name,
    required DateTime birthDate,
    required String sexLabel,
    required String guardianName,
    String? avatarAsset,
  }) {
    final DemoPatient patient = DemoPatient(
      id: 'n${_nextId++}',
      name: name,
      birthDate: birthDate,
      sexLabel: sexLabel,
      guardianName: _profile == DemoProfile.responsavel
          ? guardianOfDemo
          : guardianName,
      avatarAsset: avatarAsset,
    );
    patients = <DemoPatient>[patient, ...patients];
    notifyListeners();
    return patient;
  }

  void setAvatar(DemoPatient patient, String? asset) {
    patient.avatarAsset = asset;
    notifyListeners();
  }

  void addEncounter(DemoEncounter encounter) {
    encounters = <DemoEncounter>[encounter, ...encounters];
    notifyListeners();
  }

  void setAppointmentStatus(DemoAppointment a, DemoAppointmentStatus status) {
    a.status = status;
    notifyListeners();
  }

  // ------------------------------------------------ Área clínica

  /// Consultas, documentos, calculadora e suplementação: só o profissional.
  bool get canUseClinicalTools => _profile == DemoProfile.profissional;

  String get currentAuthor => DemoProfessional.name;

  DemoConsultation? consultationById(String id) {
    for (final DemoConsultation c in consultations) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<DemoConsultation> consultationsFor(String patientId) =>
      consultations
          .where((DemoConsultation c) => c.patientId == patientId)
          .toList()
        ..sort(
          (DemoConsultation a, DemoConsultation b) =>
              b.startedAt.compareTo(a.startedAt),
        );

  DemoConsultation startConsultation(String patientId) {
    final DemoConsultation c = DemoConsultation(
      id: 'c${_nextId++}',
      patientId: patientId,
      startedAt: DateTime.now(),
      author: currentAuthor,
    );
    consultations = <DemoConsultation>[c, ...consultations];
    notifyListeners();
    return c;
  }

  void saveConsultation(DemoConsultation c) {
    c.updatedAt = DateTime.now();
    notifyListeners();
  }

  void finishConsultation(DemoConsultation c) {
    c
      ..status = DemoConsultationStatus.finished
      ..updatedAt = DateTime.now();
    encounters = <DemoEncounter>[
      DemoEncounter(
        patientId: c.patientId,
        date: c.updatedAt,
        type: 'Consulta (demonstração)',
        summary: c.summary,
      ),
      ...encounters,
    ];
    notifyListeners();
  }

  /// Peso lançado na consulta: vira também uma medida da curva.
  void updateWeight(
    DemoPatient p,
    double kg,
    DateTime weighedAt, {
    String? consultationId,
  }) {
    addMeasurement(
      p,
      GrowthMeasurement(
        id: 'g${_nextId++}',
        patientId: p.id,
        values: GrowthValues(date: weighedAt, weightKg: kg),
        author: currentAuthor,
        recordedAt: DateTime.now(),
        consultationId: consultationId,
      ),
    );
  }

  List<ClinicalDocRecord> documentsFor(String patientId) =>
      documents
          .where((ClinicalDocRecord d) => d.patientId == patientId)
          .toList()
        ..sort(
          (ClinicalDocRecord a, ClinicalDocRecord b) =>
              b.current.updatedAt.compareTo(a.current.updatedAt),
        );

  ClinicalDocRecord? documentById(String id) {
    for (final ClinicalDocRecord d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  String newDocumentId() => 'd${_nextId++}';

  void saveDocument(ClinicalDocRecord doc) {
    final int i = documents.indexWhere((ClinicalDocRecord d) => d.id == doc.id);
    documents = <ClinicalDocRecord>[
      if (i < 0) doc,
      for (final ClinicalDocRecord d in documents) d.id == doc.id ? doc : d,
    ];
    notifyListeners();
  }

  OrientationTemplate addOrientationTemplate(String title, String body) {
    final OrientationTemplate t = OrientationTemplate(
      id: 't${_nextId++}',
      title: title,
      body: body,
      author: currentAuthor,
      updatedAt: DateTime.now(),
    );
    orientationTemplates = <OrientationTemplate>[t, ...orientationTemplates];
    notifyListeners();
    return t;
  }

  SupplementSheet? sheetById(String id) {
    for (final SupplementSheet s in supplementSheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Último PDF gerado nesta aba (nome, conteúdo e saída pedida).
  (String name, Uint8List bytes, String delivery)? lastPdf;

  void recordPdf(String name, Uint8List bytes, String delivery) =>
      lastPdf = (name, bytes, delivery);

  void saveSheet(SupplementSheet sheet) {
    supplementSheets = <SupplementSheet>[
      for (final SupplementSheet s in supplementSheets)
        s.id == sheet.id ? sheet : s,
    ];
    notifyListeners();
  }

  // ------------------------------------------------ Crescimento

  /// Curvas: o profissional vê o detalhe; o responsável, a visão simples
  /// das crianças vinculadas a ele. Os demais perfis não veem.
  bool get canSeeGrowth =>
      _profile == DemoProfile.profissional ||
      _profile == DemoProfile.responsavel;

  bool get canEditGrowth => canUseClinicalTools;

  String newId(String prefix) => '$prefix${_nextId++}';

  List<GrowthMeasurement> growthFor(String patientId) =>
      growth.where((GrowthMeasurement m) => m.patientId == patientId).toList()
        ..sort(
          (GrowthMeasurement a, GrowthMeasurement b) =>
              a.values.date.compareTo(b.values.date),
        );

  GrowthMeasurement? measurementById(String id) {
    for (final GrowthMeasurement m in growth) {
      if (m.id == id) return m;
    }
    return null;
  }

  void addMeasurement(DemoPatient p, GrowthMeasurement m) {
    growth = <GrowthMeasurement>[...growth, m];
    _syncWeight(p);
    notifyListeners();
  }

  /// Correção ou anulação: a medida nova substitui a anterior na lista, e
  /// o valor antigo segue no histórico da própria medida.
  void replaceMeasurement(DemoPatient p, GrowthMeasurement m) {
    growth = <GrowthMeasurement>[
      for (final GrowthMeasurement g in growth) g.id == m.id ? m : g,
    ];
    _syncWeight(p);
    notifyListeners();
  }

  /// O peso usado pela calculadora é o da medida válida mais recente.
  void _syncWeight(DemoPatient p) {
    GrowthMeasurement? latest;
    for (final GrowthMeasurement m in growthFor(p.id)) {
      if (m.voided || m.values.weightKg == null) continue;
      if (latest == null || !m.values.date.isBefore(latest.values.date)) {
        latest = m;
      }
    }
    p
      ..weightKg = latest?.values.weightKg
      ..weighedAt = latest?.values.date;
  }

  void setGestationalAge(DemoPatient p, int? days, String reason) {
    if (p.gestationalAgeDays == days) return;
    gestationalAgeChanges = <GestationalAgeChange>[
      ...gestationalAgeChanges,
      GestationalAgeChange(
        patientId: p.id,
        before: p.gestationalAgeDays,
        after: days,
        reason: reason,
        author: currentAuthor,
        at: DateTime.now(),
      ),
    ];
    p.gestationalAgeDays = days;
    notifyListeners();
  }

  // ------------------------------------------------ Exames

  List<LabResult> labsFor(String patientId) =>
      labs.where((LabResult r) => r.patientId == patientId).toList();

  LabResult? labById(String id) {
    for (final LabResult r in labs) {
      if (r.id == id) return r;
    }
    return null;
  }

  void saveLab(LabResult r) {
    final bool exists = labs.any((LabResult x) => x.id == r.id);
    labs = <LabResult>[
      if (!exists) r,
      for (final LabResult x in labs) x.id == r.id ? r : x,
    ];
    notifyListeners();
  }

  // ------------------------------------------------ Suplementação do paciente

  SupplementDecision? decisionFor(String patientId, String topicId) {
    for (final SupplementDecision d in supplementDecisions) {
      if (d.patientId == patientId && d.topicId == topicId) return d;
    }
    return null;
  }

  void saveDecision(SupplementDecision d) {
    final bool exists = supplementDecisions.any(
      (SupplementDecision x) => x.id == d.id,
    );
    supplementDecisions = <SupplementDecision>[
      if (!exists) d,
      for (final SupplementDecision x in supplementDecisions)
        x.id == d.id ? d : x,
    ];
    notifyListeners();
  }
}

/// Alteração da idade gestacional ao nascer (fica no histórico).
class GestationalAgeChange {
  const GestationalAgeChange({
    required this.patientId,
    required this.before,
    required this.after,
    required this.reason,
    required this.author,
    required this.at,
  });

  final String patientId;
  final int? before;
  final int? after;
  final String reason;
  final String author;
  final DateTime at;
}

/// Instancia unica da aba. Recarregar a pagina volta ao estado inicial.
final DemoSession demoSession = DemoSession();
