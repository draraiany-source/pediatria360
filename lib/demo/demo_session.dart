import 'package:flutter/material.dart';

import 'demo_data.dart';

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
          'Agenda, pacientes, prontuário, vacinação e biblioteca.',
        DemoProfile.recepcao =>
          'Agenda do dia, chegada e cadastro básico. Sem prontuário.',
        DemoProfile.financeiro =>
          'Recebimentos e relatórios. Sem dados clínicos.',
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
  pacientes('/pacientes', 'Pacientes', Icons.people_outline,
      Icons.people_rounded),
  agenda('/agenda', 'Agenda', Icons.calendar_month_outlined,
      Icons.calendar_month_rounded),
  vacinacao('/vacinacao', 'Vacinação', Icons.vaccines_outlined,
      Icons.vaccines_rounded),
  telemedicina('/telemedicina', 'Telemedicina', Icons.videocam_outlined,
      Icons.videocam_rounded),
  biblioteca('/biblioteca', 'Biblioteca', Icons.menu_book_outlined,
      Icons.menu_book_rounded),
  relatorios('/relatorios', 'Relatórios', Icons.insights_outlined,
      Icons.insights_rounded),
  financeiro('/financeiro', 'Financeiro', Icons.payments_outlined,
      Icons.payments_rounded),
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
  final List<DemoArticle> articles = DemoSeed.articles;

  int _nextId = 100;

  void reset() {
    patients = DemoSeed.patients();
    encounters = DemoSeed.encounters();
    appointments = DemoSeed.appointments();
    vaccines = DemoSeed.vaccines();
    invoices = DemoSeed.invoices();
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
}

/// Instancia unica da aba. Recarregar a pagina volta ao estado inicial.
final DemoSession demoSession = DemoSession();
