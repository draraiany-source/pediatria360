import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/branding/brand_logo.dart';
import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/dose_calculator.dart';
import '../shared/clinical/growth.dart';
import '../shared/clinical/lab_results.dart';
import '../shared/clinical/orientation_templates.dart';
import '../shared/clinical/rx_templates.dart';
import '../shared/clinical/supplement_library.dart';
import '../shared/routine/child_routine.dart';
import '../shared/wellchild/age_band.dart';
import '../shared/wellchild/well_child_templates.dart';
import '../shared/wellchild/well_child_visit.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_growth.dart';
import 'demo_routine.dart';

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
  rotina(
    '/rotina',
    'Rotina',
    Icons.event_note_outlined,
    Icons.event_note_rounded,
  ),
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
  late List<RxTemplate> rxTemplates;
  late Map<String, String> _rxTemplateOwner;
  late List<WellChildTemplate> wellChildTemplates;
  late Map<String, String> _wcTemplateOwner;
  late BrandLogoStore logos;
  late List<SupplementSheet> supplementSheets;
  late List<GrowthMeasurement> growth;
  late List<GestationalAgeChange> gestationalAgeChanges;
  late List<LabResult> labs;
  late List<SupplementDecision> supplementDecisions;
  late List<RoutineEvent> routineEvents;
  late List<MedicationPlan> medicationPlans;
  late List<DiaryEntry> diaryEntries;
  late List<SharedRoutineSummary> sharedSummaries;
  late Map<String, bool> routineSharing;
  late Map<String, List<int>> itemReminders;
  late Set<String> dismissedReminders;
  late Set<RoutineKind> routineKindFilter;
  late Set<DiaryKind> diaryKindFilter;
  String? lastRoutinePatientId;
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
    rxTemplates = DemoClinicalSeed.rxTemplates(now);
    _rxTemplateOwner = <String, String>{
      for (final RxTemplate t in rxTemplates) t.id: DemoProfessional.id,
    };
    wellChildTemplates = DemoClinicalSeed.wellChildTemplates(
      author: DemoProfessional.name,
      now: now,
    );
    _wcTemplateOwner = <String, String>{
      for (final WellChildTemplate t in wellChildTemplates)
        t.id: DemoProfessional.id,
    };
    logos = BrandLogoStore();
    _account = DemoProfessional.account;
    supplementSheets = List<SupplementSheet>.of(kSupplementSheets);
    for (final DemoPatient p in patients) {
      p.gestationalAgeDays = DemoGrowthSeed.gestationalAgeDays[p.id];
    }
    growth = DemoGrowthSeed.measurements(patients, now);
    gestationalAgeChanges = <GestationalAgeChange>[];
    labs = DemoGrowthSeed.labResults(now);
    supplementDecisions = DemoGrowthSeed.decisions(now);
    clock = DateTime.now;
    final DemoRoutineSeed routine = DemoRoutineSeed(now, documents);
    routineEvents = routine.events();
    medicationPlans = routine.plans();
    diaryEntries = routine.diary();
    routineSharing = <String, bool>{'p1': true, 'p5': false};
    itemReminders = <String, List<int>>{
      'appt:a6': const <int>[1440, 60],
    };
    dismissedReminders = <String>{};
    routineKindFilter = <RoutineKind>{};
    diaryKindFilter = <DiaryKind>{};
    lastRoutinePatientId = null;
    sharedSummaries = routine.sharedSummaries(this);
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
          DemoModule.rotina,
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

  String get currentAuthor => _account.name;

  // ------------------------------------------------ Conta e logomarca

  DemoAccount _account = DemoProfessional.account;

  /// Conta do profissional ou clínica em uso (a demonstração tem duas).
  DemoAccount get account => _account;

  void switchAccount(String accountId) {
    final DemoAccount next = DemoProfessional.byId(accountId);
    if (next.id == _account.id) return;
    _account = next;
    notifyListeners();
  }

  /// Só profissional e clínica têm logomarca própria.
  bool get canBrand => _profile == DemoProfile.profissional;

  /// Logomarca vigente da conta em uso; `null` usa a identidade padrão.
  BrandLogo? get myLogo => canBrand
      ? logos.currentFor(ownerId: _account.id, viewerId: _account.id)
      : null;

  /// Envia ou troca a logomarca da conta em uso.
  BrandLogo uploadLogo({required Uint8List bytes, required String fileName}) {
    if (!canBrand) {
      throw const BrandingException(
        'Logomarca disponível só para profissional ou clínica.',
      );
    }
    final BrandLogo logo = logos.upload(
      actorId: _account.id,
      ownerId: _account.id,
      logoId: 'logo${_nextId++}',
      bytes: bytes,
      fileName: fileName,
      uploadedBy: _account.name,
      now: DateTime.now(),
    );
    notifyListeners();
    return logo;
  }

  void removeLogo() {
    if (!canBrand) return;
    logos.remove(actorId: _account.id, ownerId: _account.id);
    notifyListeners();
  }

  /// Logomarca do cabeçalho de uma versão de documento.
  BrandLogo? logoForDocument(ClinicalDocRecord doc, DocVersion version) =>
      logos.forDocument(
        ownerId: _ownerOf(doc),
        viewerId: _account.id,
        issued: version.status == DocStatus.issued,
        issuedLogoId: version.logoId,
      );

  /// Emite gravando a logomarca vigente de quem emite.
  ClinicalDocRecord issueDocument(ClinicalDocRecord doc) =>
      doc.issue(now: DateTime.now(), logoId: myLogo?.id);

  String _ownerOf(ClinicalDocRecord d) => d.ownerId ?? DemoProfessional.id;

  bool _mine(ClinicalDocRecord d) => _ownerOf(d) == _account.id;

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
        type: c.isWellChild
            ? 'Consulta de puericultura (demonstração)'
            : 'Consulta (demonstração)',
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

  /// Documentos do paciente criados pela conta em uso.
  List<ClinicalDocRecord> documentsFor(String patientId) =>
      documents
          .where((ClinicalDocRecord d) => d.patientId == patientId && _mine(d))
          .toList()
        ..sort(
          (ClinicalDocRecord a, ClinicalDocRecord b) =>
              b.current.updatedAt.compareTo(a.current.updatedAt),
        );

  ClinicalDocRecord? documentById(String id) {
    for (final ClinicalDocRecord d in documents) {
      if (d.id == id) return _mine(d) ? d : null;
    }
    return null;
  }

  String newDocumentId() => 'd${_nextId++}';

  void saveDocument(ClinicalDocRecord input) {
    final ClinicalDocRecord doc = input.ownerId != null
        ? input
        : ClinicalDocRecord(
            id: input.id,
            kind: input.kind,
            patientId: input.patientId,
            consultationId: input.consultationId,
            ownerId: _account.id,
            versions: input.versions,
            signature: input.signature,
          );
    final int i = documents.indexWhere((ClinicalDocRecord d) => d.id == doc.id);
    if (i >= 0 && !_mine(documents[i])) return;
    documents = <ClinicalDocRecord>[
      if (i < 0) doc,
      for (final ClinicalDocRecord d in documents) d.id == doc.id ? doc : d,
    ];
    notifyListeners();
  }

  OrientationTemplate addOrientationTemplate(
    String title,
    String body, {
    OrientationTopic topic = OrientationTopic.geral,
    ChildAgeBand? band,
  }) {
    final OrientationTemplate t = OrientationTemplate(
      id: 't${_nextId++}',
      title: title,
      body: body,
      author: currentAuthor,
      updatedAt: DateTime.now(),
      topic: topic,
      band: band,
      ownerId: _account.id,
    );
    orientationTemplates = <OrientationTemplate>[t, ...orientationTemplates];
    notifyListeners();
    return t;
  }

  /// Exemplos (de todas as contas) e os modelos criados pela conta em uso.
  List<OrientationTemplate> get myOrientationTemplates => orientationTemplates
      .where(
        (OrientationTemplate t) =>
            t.ownerId == null || t.ownerId == _account.id,
      )
      .toList(growable: false);

  OrientationTemplate? orientationTemplateById(String id) {
    for (final OrientationTemplate t in myOrientationTemplates) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ------------------------------------------------ Puericultura

  bool get canUseWellChild => canUseClinicalTools;

  DemoConsultation startWellChildVisit(String patientId) {
    final DateTime now = DateTime.now();
    final DemoConsultation c = DemoConsultation(
      id: 'c${_nextId++}',
      patientId: patientId,
      startedAt: now,
      author: currentAuthor,
      complaint: 'Consulta de puericultura',
      ownerId: _account.id,
      wellChild: WellChildVisit(
        history: <VisitRevision>[
          VisitRevision(at: now, author: currentAuthor, action: 'Criada'),
        ],
      ),
    );
    consultations = <DemoConsultation>[c, ...consultations];
    notifyListeners();
    return c;
  }

  /// Grava a consulta com uma linha no histórico. Devolve `false` se nada
  /// mudou.
  bool saveWellChild(
    DemoConsultation c,
    WellChildVisit next, {
    String action = 'Editado',
    String reason = '',
  }) {
    final WellChildVisit? cur = c.wellChild;
    if (cur == null) return false;
    final WellChildVisit v = cur.revised(
      next,
      author: currentAuthor,
      at: DateTime.now(),
      action: action,
      reason: reason,
    );
    if (identical(v, cur)) return false;
    c
      ..wellChild = v
      ..assessment = v.field(WellChildSection.avaliacao)
      ..plan = v.field(WellChildSection.plano)
      ..updatedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  /// Finaliza gravando a logomarca vigente; o resumo em PDF não muda se a
  /// logomarca for trocada depois.
  List<String> finishWellChild(DemoConsultation c) {
    final WellChildVisit? v = c.wellChild;
    if (v == null) return <String>['Consulta não é de puericultura.'];
    final List<String> problems = <String>[
      ...v.missingToFinish.map((String s) => 'Preencha: $s'),
      ...v.placeholders.map((String s) => 'Complete os colchetes em: $s'),
    ];
    if (problems.isNotEmpty) return problems;
    c.wellChild = v
        .copyWith(logoId: () => myLogo?.id)
        .logged('Finalizada', author: currentAuthor, at: DateTime.now());
    finishConsultation(c);
    return const <String>[];
  }

  BrandLogo? logoForVisit(DemoConsultation c) => logos.forDocument(
    ownerId: c.ownerId ?? DemoProfessional.id,
    viewerId: _account.id,
    issued: !c.isDraft,
    issuedLogoId: c.wellChild?.logoId,
  );

  VisitAge visitAge(DemoPatient p, DateTime at) => VisitAge.of(
    birthDate: p.birthDate,
    at: at,
    gestationalAgeDays: p.gestationalAgeDays,
  );

  String newWellChildTemplateId() => 'wt${_nextId++}';

  bool _myWcTemplate(WellChildTemplate t) =>
      (_wcTemplateOwner[t.id] ?? DemoProfessional.id) == _account.id;

  List<WellChildTemplate> get myWellChildTemplates =>
      wellChildTemplates.where(_myWcTemplate).toList()..sort(
        (WellChildTemplate a, WellChildTemplate b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );

  WellChildTemplate? wellChildTemplateById(String id) {
    for (final WellChildTemplate t in wellChildTemplates) {
      if (t.id == id) return _myWcTemplate(t) ? t : null;
    }
    return null;
  }

  void saveWellChildTemplate(WellChildTemplate t) {
    final bool exists = wellChildTemplates.any(
      (WellChildTemplate x) => x.id == t.id,
    );
    if (exists && !_myWcTemplate(t)) return;
    _wcTemplateOwner.putIfAbsent(t.id, () => _account.id);
    wellChildTemplates = <WellChildTemplate>[
      if (!exists) t,
      for (final WellChildTemplate x in wellChildTemplates)
        x.id == t.id ? t : x,
    ];
    notifyListeners();
  }

  // ------------------------------------------------ Área da família

  /// Orientações emitidas para as crianças do responsável (a última versão
  /// emitida; rascunhos posteriores não aparecem).
  List<ClinicalDocRecord> familyOrientations(String patientId) {
    if (_profile != DemoProfile.responsavel || patientById(patientId) == null) {
      return const <ClinicalDocRecord>[];
    }
    final List<ClinicalDocRecord> out = <ClinicalDocRecord>[];
    for (final ClinicalDocRecord d in documents) {
      if (d.patientId != patientId || d.kind != DocKind.orientacoes) continue;
      final int i = d.versions.lastIndexWhere(
        (DocVersion v) => v.status == DocStatus.issued,
      );
      if (i >= 0) out.add(d.upTo(i));
    }
    out.sort(
      (ClinicalDocRecord a, ClinicalDocRecord b) =>
          b.current.issuedAt!.compareTo(a.current.issuedAt!),
    );
    return out;
  }

  ClinicalDocRecord? familyOrientationById(String patientId, String docId) {
    for (final ClinicalDocRecord d in familyOrientations(patientId)) {
      if (d.id == docId) return d;
    }
    return null;
  }

  /// Profissional ou clínica que emitiu o documento.
  DemoAccount documentAccount(ClinicalDocRecord d) =>
      DemoProfessional.byId(_ownerOf(d));

  /// Logomarca gravada no documento emitido, para o PDF da família.
  BrandLogo? familyDocumentLogo(ClinicalDocRecord d) {
    final String? id = d.current.logoId;
    if (id == null) return null;
    final String owner = _ownerOf(d);
    return logos.forDocument(
      ownerId: owner,
      viewerId: owner,
      issued: true,
      issuedLogoId: id,
    );
  }

  // ------------------------------------------------ Modelos de receita

  String newRxTemplateId() => 'm${_nextId++}';

  bool _myTemplate(RxTemplate t) =>
      (_rxTemplateOwner[t.id] ?? DemoProfessional.id) == _account.id;

  /// Modelos da conta em uso.
  List<RxTemplate> get myRxTemplates =>
      rxTemplates.where(_myTemplate).toList(growable: false);

  RxTemplate? rxTemplateById(String id) {
    for (final RxTemplate t in rxTemplates) {
      if (t.id == id) return _myTemplate(t) ? t : null;
    }
    return null;
  }

  /// Modelos que casam com a busca, do mais recente ao mais antigo.
  List<RxTemplate> searchRxTemplates(String query) =>
      myRxTemplates.where((RxTemplate t) => t.matches(query)).toList()..sort(
        (RxTemplate a, RxTemplate b) => b.updatedAt.compareTo(a.updatedAt),
      );

  void saveRxTemplate(RxTemplate t) {
    final bool exists = rxTemplates.any((RxTemplate x) => x.id == t.id);
    if (exists && !_myTemplate(t)) return;
    _rxTemplateOwner.putIfAbsent(t.id, () => _account.id);
    rxTemplates = <RxTemplate>[
      if (!exists) t,
      for (final RxTemplate x in rxTemplates) x.id == t.id ? t : x,
    ];
    notifyListeners();
  }

  /// Consulta em andamento do paciente, se houver.
  DemoConsultation? draftConsultationFor(String patientId) {
    for (final DemoConsultation c in consultations) {
      if (c.patientId == patientId && c.isDraft) return c;
    }
    return null;
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
  // ------------------------------------------------ Rotina e diário

  /// Relógio da rotina (lembretes, "agora" dos formulários). Os testes
  /// adiantam o relógio para ver um lembrete disparar.
  DateTime Function() clock = DateTime.now;

  DateTime get now => clock();

  /// Responsável: as próprias crianças. Profissional: só as crianças cuja
  /// família autorizou o compartilhamento, e só para leitura.
  bool get canUseRoutine =>
      _profile == DemoProfile.responsavel ||
      _profile == DemoProfile.profissional;

  bool get canEditRoutine => _profile == DemoProfile.responsavel;

  bool routineSharedWith(String patientId) =>
      routineSharing[patientId] ?? false;

  DemoPatient? routinePatient(String patientId) {
    if (_profile == DemoProfile.responsavel) return patientById(patientId);
    if (_profile == DemoProfile.profissional && routineSharedWith(patientId)) {
      return patientById(patientId);
    }
    return null;
  }

  List<DemoPatient> get routinePatients => <DemoPatient>[
    for (final DemoPatient p in visiblePatients)
      if (routinePatient(p.id) != null) p,
  ];

  String get routineAuthor =>
      _profile == DemoProfile.responsavel ? guardianOfDemo : currentAuthor;

  DiaryRole get routineRole => _profile == DemoProfile.responsavel
      ? DiaryRole.familia
      : DiaryRole.profissional;

  void setRoutineSharing(String patientId, bool shared) {
    if (!canEditRoutine || patientById(patientId) == null) return;
    routineSharing = <String, bool>{...routineSharing, patientId: shared};
    notifyListeners();
  }

  RoutineEvent? routineEventById(String id) {
    for (final RoutineEvent e in routineEvents) {
      if (e.id == id) return e;
    }
    return null;
  }

  void saveRoutineEvent(RoutineEvent event) {
    if (!canEditRoutine || routinePatient(event.patientId) == null) return;
    final bool exists = routineEvents.any((RoutineEvent e) => e.id == event.id);
    routineEvents = <RoutineEvent>[
      for (final RoutineEvent e in routineEvents) e.id == event.id ? event : e,
      if (!exists) event,
    ];
    notifyListeners();
  }

  void setOccurrenceStatus(
    String eventId,
    String key,
    RoutineStatus status, {
    String note = '',
  }) {
    final RoutineEvent? e = routineEventById(eventId);
    if (e == null) return;
    saveRoutineEvent(
      e.withStatus(key, status, author: routineAuthor, at: now, note: note),
    );
  }

  MedicationPlan? planById(String id) {
    for (final MedicationPlan p in medicationPlans) {
      if (p.id == id) return p;
    }
    return null;
  }

  MedicationPlan? planFor(String docId, int itemIndex) {
    for (final MedicationPlan p in medicationPlans) {
      if (p.docId == docId && p.itemIndex == itemIndex) return p;
    }
    return null;
  }

  void savePlan(MedicationPlan plan) {
    if (!canEditRoutine || routinePatient(plan.patientId) == null) return;
    final bool exists = medicationPlans.any(
      (MedicationPlan p) => p.id == plan.id,
    );
    medicationPlans = <MedicationPlan>[
      for (final MedicationPlan p in medicationPlans)
        p.id == plan.id ? plan : p,
      if (!exists) plan,
    ];
    notifyListeners();
  }

  void setDoseStatus(
    String planId,
    String doseKey,
    RoutineStatus status, {
    String note = '',
    String? diaryEntryId,
  }) {
    final MedicationPlan? p = planById(planId);
    if (p == null) return;
    savePlan(
      p.withDose(
        doseKey,
        status,
        author: routineAuthor,
        at: now,
        note: note,
        diaryEntryId: diaryEntryId,
      ),
    );
  }

  /// Antecedências escolhidas pela família para itens da clínica
  /// (consultas agendadas), guardadas à parte do cadastro da clínica.
  void setItemReminders(String itemId, List<int> reminders) {
    if (!canEditRoutine) return;
    itemReminders = <String, List<int>>{...itemReminders, itemId: reminders};
    notifyListeners();
  }

  void dismissReminder(String key) {
    dismissedReminders = <String>{...dismissedReminders, key};
    notifyListeners();
  }

  DiaryEntry? diaryEntryById(String id) {
    for (final DiaryEntry e in diaryEntries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Novo registro. Se confirma uma dose programada, a dose fica como
  /// realizada no calendário.
  DiaryEntry addDiaryEntry({
    required String patientId,
    required DiaryKind kind,
    required DiaryValues values,
    LabAttachment? attachment,
    String? planId,
    String? doseKey,
  }) {
    if (!canEditRoutine || routinePatient(patientId) == null) {
      throw StateError('Só o responsável registra no diário da criança.');
    }
    final DiaryEntry entry = DiaryEntry(
      id: newId('r'),
      patientId: patientId,
      kind: kind,
      values: values,
      author: routineAuthor,
      role: routineRole,
      recordedAt: now,
      attachment: attachment,
      planId: planId,
      doseKey: doseKey,
    );
    diaryEntries = <DiaryEntry>[...diaryEntries, entry];
    if (planId != null && doseKey != null) {
      setDoseStatus(
        planId,
        doseKey,
        RoutineStatus.done,
        diaryEntryId: entry.id,
      );
    }
    notifyListeners();
    return entry;
  }

  void replaceDiaryEntry(DiaryEntry entry) {
    if (!canEditRoutine || routinePatient(entry.patientId) == null) return;
    diaryEntries = <DiaryEntry>[
      for (final DiaryEntry e in diaryEntries) e.id == entry.id ? entry : e,
    ];
    if (entry.voided && entry.planId != null && entry.doseKey != null) {
      final MedicationPlan? p = planById(entry.planId!);
      if (p?.doses[entry.doseKey!]?.diaryEntryId == entry.id) {
        setDoseStatus(entry.planId!, entry.doseKey!, RoutineStatus.planned);
      }
    }
    notifyListeners();
  }

  /// Despertar anotado no sono em andamento (ou numa noite já registrada).
  void addWaking(String entryId, SleepWaking waking) {
    final DiaryEntry? e = diaryEntryById(entryId);
    if (e == null || e.kind != DiaryKind.sono) return;
    replaceDiaryEntry(e.withWaking(waking, author: routineAuthor, at: now));
  }

  /// Avaliação do sono escrita pelo profissional a partir do diário da
  /// família; entra no prontuário como evolução.
  void addSleepAssessment(String patientId, String text) {
    if (!canSeeClinicalRecord || routinePatient(patientId) == null) {
      throw StateError('Só o profissional, com a rotina compartilhada.');
    }
    addEncounter(
      DemoEncounter(
        patientId: patientId,
        date: DateTime.now(),
        type: 'Avaliação do sono',
        summary: text.trim(),
      ),
    );
  }

  SharedRoutineSummary shareSummary({
    required String patientId,
    required RoutineSummary summary,
    required String text,
    String message = '',
  }) {
    if (!canEditRoutine || !routineSharedWith(patientId)) {
      throw StateError(
        'Envio exige o responsável e o compartilhamento ligado.',
      );
    }
    final SharedRoutineSummary s = SharedRoutineSummary(
      id: newId('s'),
      patientId: patientId,
      from: summary.from,
      to: summary.to,
      kinds: summary.kinds,
      text: text,
      entryCount: summary.entries.length,
      author: routineAuthor,
      sentAt: now,
      message: message.trim(),
    );
    sharedSummaries = <SharedRoutineSummary>[s, ...sharedSummaries];
    notifyListeners();
    return s;
  }

  List<SharedRoutineSummary> sharedSummariesFor(String patientId) =>
      sharedSummaries
          .where((SharedRoutineSummary s) => s.patientId == patientId)
          .toList();

  SharedRoutineSummary? sharedSummaryById(String id) {
    for (final SharedRoutineSummary s in sharedSummaries) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Altera��o da idade gestacional ao nascer (fica no hist�rico).
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
