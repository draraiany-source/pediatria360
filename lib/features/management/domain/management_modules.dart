import '../../../core/router/routes.dart';
import '../../../shared/domain/entities/clinic_organization.dart';

/// Os dez módulos da gestão integrada, na ordem do menu.
///
/// A visibilidade aqui só organiza a tela: cada Function e cada regra do
/// Firestore conferem o papel de novo. Esconder um item não é o controle de
/// acesso; mostrar um item também não libera nada.
enum ManagementModule {
  agenda,
  crm,
  anamnesis,
  care,
  finance,
  communication,
  automations,
  marketing,
  aiHub,
  settings;

  String get label => switch (this) {
        ManagementModule.agenda => 'Agenda',
        ManagementModule.crm => 'Pacientes e CRM',
        ManagementModule.anamnesis => 'Anamnese e pré-consulta',
        ManagementModule.care => 'Atendimento e prontuário',
        ManagementModule.finance => 'Financeiro',
        ManagementModule.communication => 'WhatsApp e comunicação',
        ManagementModule.automations => 'Automações',
        ManagementModule.marketing => 'Marketing',
        ManagementModule.aiHub => 'Central de IA',
        ManagementModule.settings => 'Configurações e permissões',
      };

  String get description => switch (this) {
        ManagementModule.agenda =>
          'Horários, encaixes, lista de espera e confirmações.',
        ManagementModule.crm =>
          'Contatos, retornos, faltas, tarefas e duplicidades (sem dados clínicos).',
        ManagementModule.anamnesis =>
          'Pré-consulta enviada pela família para revisar no atendimento.',
        ManagementModule.care =>
          'Atendimento, prontuário e transcrição com revisão.',
        ManagementModule.finance =>
          'Cobranças, pagamentos, caixa e indicadores.',
        ManagementModule.communication =>
          'Situação do WhatsApp, caixa de entrada e envios.',
        ManagementModule.automations =>
          'Lembretes, avisos de mudança, convites e pausas.',
        ManagementModule.marketing =>
          'Campanhas com consentimento, prévia e aprovação.',
        ManagementModule.aiHub =>
          'Indicadores agregados com período, filtros e fonte.',
        ManagementModule.settings =>
          'Uso, custos estimados, equipe e permissões.',
      };

  String get path => switch (this) {
        ManagementModule.agenda => Routes.agendaPath,
        ManagementModule.crm => Routes.managementCrmPath,
        ManagementModule.anamnesis => Routes.managementAnamnesisPath,
        ManagementModule.care => Routes.clinicPath,
        ManagementModule.finance => Routes.financePath,
        ManagementModule.communication => Routes.managementCommunicationPath,
        ManagementModule.automations => Routes.managementAutomationsPath,
        ManagementModule.marketing => Routes.managementMarketingPath,
        ManagementModule.aiHub => Routes.managementAiPath,
        ManagementModule.settings => Routes.managementSettingsPath,
      };
}

/// Quem vê cada módulo. `role == null` é conta sem vínculo ativo com
/// clínica: não vê nada da gestão.
bool managementModuleVisible(ManagementModule module, ClinicRole? role) {
  if (role == null || role == ClinicRole.patient) return false;
  return switch (module) {
    ManagementModule.agenda => role.canManageAgenda,
    ManagementModule.crm =>
      role == ClinicRole.clinicAdmin || role == ClinicRole.receptionist,
    ManagementModule.anamnesis => _clinical(role),
    ManagementModule.care => _clinical(role),
    ManagementModule.finance => role.canAccessFinance,
    ManagementModule.communication =>
      role == ClinicRole.clinicAdmin || role == ClinicRole.receptionist,
    ManagementModule.automations =>
      role == ClinicRole.clinicAdmin || role == ClinicRole.receptionist,
    ManagementModule.marketing => role == ClinicRole.clinicAdmin,
    ManagementModule.aiHub =>
      role == ClinicRole.clinicAdmin || role == ClinicRole.finance,
    ManagementModule.settings => role == ClinicRole.clinicAdmin,
  };
}

/// Ser gestão não dá acesso clínico: a gestão vê anamnese e atendimento só
/// se também atende (o servidor confere o profissional da consulta).
bool _clinical(ClinicRole role) =>
    role == ClinicRole.physician ||
    role == ClinicRole.healthProfessional ||
    role == ClinicRole.nursing ||
    role == ClinicRole.clinicAdmin;

List<ManagementModule> visibleManagementModules(ClinicRole? role) =>
    ManagementModule.values
        .where((ManagementModule m) => managementModuleVisible(m, role))
        .toList(growable: false);

/// Atalho "Transcrever consulta": só para quem atende.
bool canTranscribeConsultation(ClinicRole? role) =>
    role != null &&
    (role == ClinicRole.physician ||
        role == ClinicRole.healthProfessional ||
        role == ClinicRole.nursing);

/// Rotas `/gestao/...` liberadas por papel (usado pelo redirect do router).
bool managementRouteAllowed(String location, ClinicRole? role) {
  if (location == Routes.managementPath) {
    return visibleManagementModules(role).isNotEmpty;
  }
  for (final ManagementModule m in ManagementModule.values) {
    if (m.path.startsWith(Routes.managementPath) &&
        (location == m.path || location.startsWith('${m.path}/'))) {
      return managementModuleVisible(m, role);
    }
  }
  return false;
}
