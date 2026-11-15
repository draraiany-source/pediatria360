import 'package:flutter/material.dart';

import '../../../core/router/routes.dart';

/// Os 15 módulos do menu principal, na ordem das telas de referência.
///
/// O menu só organiza a navegação: a rota de cada item passa pelo mesmo
/// `redirect` do router e as regras do Firestore conferem o papel de novo.
/// Esconder um item não é controle de acesso.
enum MainMenuModule {
  dashboard,
  agenda,
  patients,
  consultations,
  chart,
  prescriptions,
  exams,
  vaccines,
  growth,
  wellChild,
  multidisciplinary,
  finance,
  reports,
  receptionistAi,
  settings;

  String get label => switch (this) {
        MainMenuModule.dashboard => 'Dashboard',
        MainMenuModule.agenda => 'Agenda',
        MainMenuModule.patients => 'Pacientes',
        MainMenuModule.consultations => 'Consultas',
        MainMenuModule.chart => 'Prontuário',
        MainMenuModule.prescriptions => 'Prescrições e documentos',
        MainMenuModule.exams => 'Exames',
        MainMenuModule.vaccines => 'Vacinação',
        MainMenuModule.growth => 'Crescimento',
        MainMenuModule.wellChild => 'Puericultura',
        MainMenuModule.multidisciplinary => 'Multidisciplinar',
        MainMenuModule.finance => 'Financeiro',
        MainMenuModule.reports => 'Relatórios',
        MainMenuModule.receptionistAi => 'Tia Cris — Recepcionista IA',
        MainMenuModule.settings => 'Configurações',
      };

  IconData get icon => switch (this) {
        MainMenuModule.dashboard => Icons.space_dashboard_outlined,
        MainMenuModule.agenda => Icons.calendar_month_outlined,
        MainMenuModule.patients => Icons.groups_outlined,
        MainMenuModule.consultations => Icons.medical_services_outlined,
        MainMenuModule.chart => Icons.folder_shared_outlined,
        MainMenuModule.prescriptions => Icons.description_outlined,
        MainMenuModule.exams => Icons.biotech_outlined,
        MainMenuModule.vaccines => Icons.vaccines_outlined,
        MainMenuModule.growth => Icons.show_chart_rounded,
        MainMenuModule.wellChild => Icons.child_care_outlined,
        MainMenuModule.multidisciplinary => Icons.diversity_3_outlined,
        MainMenuModule.finance => Icons.account_balance_wallet_outlined,
        MainMenuModule.reports => Icons.bar_chart_rounded,
        MainMenuModule.receptionistAi => Icons.support_agent_outlined,
        MainMenuModule.settings => Icons.settings_outlined,
      };

  /// Módulo que depende de um paciente selecionado.
  bool get patientScoped => patientModuleSlug != null;

  /// Trecho da rota `/consultorio/modulo/:modulo` (seleção do paciente).
  String? get patientModuleSlug => switch (this) {
        MainMenuModule.chart => 'prontuario',
        MainMenuModule.prescriptions => 'prescricoes',
        MainMenuModule.exams => 'exames',
        MainMenuModule.vaccines => 'vacinacao',
        MainMenuModule.growth => 'crescimento',
        MainMenuModule.wellChild => 'puericultura',
        MainMenuModule.multidisciplinary => 'multidisciplinar',
        _ => null,
      };

  static MainMenuModule? fromSlug(String slug) {
    for (final MainMenuModule m in MainMenuModule.values) {
      if (m.patientModuleSlug == slug) return m;
    }
    return null;
  }

  /// Rotas candidatas, em ordem de preferência. O item abre a primeira que
  /// o perfil pode acessar; sem nenhuma, o item não aparece.
  List<String> get candidateRoutes => switch (this) {
        MainMenuModule.dashboard => const <String>[Routes.homePath],
        MainMenuModule.agenda => const <String>[Routes.agendaPath],
        MainMenuModule.patients => const <String>[Routes.patientsPath],
        MainMenuModule.consultations => const <String>[
            Routes.clinicPath,
            Routes.clinicReceptionPath,
          ],
        MainMenuModule.finance => const <String>[Routes.financePath],
        MainMenuModule.reports => const <String>[
            Routes.biPath,
            Routes.financeReportsPath,
          ],
        MainMenuModule.receptionistAi => const <String>[
            Routes.receptionistAiPath,
          ],
        MainMenuModule.prescriptions => const <String>[
            Routes.clinicPrescriptionsPath,
            '/consultorio/paciente/',
          ],
        MainMenuModule.growth => const <String>[
            Routes.clinicGrowthPath,
            '/consultorio/paciente/',
          ],
        MainMenuModule.settings => const <String>[
            Routes.managementSettingsPath,
            Routes.settingsPath,
          ],
        _ => <String>[Routes.patientModule(patientModuleSlug!)],
      };

  /// Rotas extras que o perfil precisa abrir para o módulo funcionar.
  List<String> get requiredRoutes => switch (this) {
        MainMenuModule.exams => const <String>[Routes.supplementLabsPath],
        _ => const <String>[],
      };

  /// Destino do módulo para um paciente já selecionado.
  ///
  /// Exames e Prescrições têm tela própria; os demais abrem o Paciente 360
  /// até ganharem a sua (ver [provisionalNotice]).
  String patientRoute(String childId) => switch (this) {
        MainMenuModule.exams =>
          Routes.supplementWithChild(Routes.supplementLabsPath, childId),
        MainMenuModule.prescriptions => Routes.clinicPrescriptions(childId),
        MainMenuModule.growth => Routes.clinicGrowth(childId),
        _ => Routes.clinicPatient360(childId),
      };

  /// Aviso para módulos que ainda abrem o Paciente 360, ou nulo.
  String? get provisionalNotice => switch (this) {
        MainMenuModule.vaccines =>
          '$label ainda não tem tela clínica: a tela atual é da área da '
              'família e não abre pelo cadastro da clínica. Por enquanto, '
              'abre o Paciente 360 do paciente selecionado.',
        MainMenuModule.wellChild ||
        MainMenuModule.multidisciplinary =>
          '$label ainda não tem tela própria: abre o Paciente 360 '
              '(documentos e linha do tempo) do paciente selecionado.',
        _ => null,
      };

  /// Prefixos de rota que marcam o item como ativo.
  List<String> get activePrefixes => switch (this) {
        MainMenuModule.dashboard => const <String>[Routes.homePath],
        MainMenuModule.agenda => const <String>[Routes.agendaPath],
        MainMenuModule.patients => const <String>[Routes.patientsPath],
        MainMenuModule.consultations => const <String>[Routes.clinicPath],
        MainMenuModule.finance => const <String>[
            Routes.financePath,
            Routes.billingPath,
          ],
        MainMenuModule.reports => const <String>[
            Routes.biPath,
            Routes.financeReportsPath,
          ],
        MainMenuModule.receptionistAi => const <String>[
            Routes.receptionistAiPath,
          ],
        MainMenuModule.settings => const <String>[
            Routes.managementSettingsPath,
            Routes.settingsPath,
          ],
        MainMenuModule.exams => <String>[
            Routes.patientModule(patientModuleSlug!),
            Routes.supplementLabsPath,
          ],
        _ => <String>[Routes.patientModule(patientModuleSlug!)],
      };
}

/// Item visível do menu, já com a rota que o perfil pode abrir.
@immutable
class MainMenuEntry {
  const MainMenuEntry({required this.module, required this.route});

  final MainMenuModule module;

  /// Rota do item (para módulos do paciente, a tela de seleção).
  final String route;

  String get label => module.label;
  IconData get icon => module.icon;
}

/// Monta o menu do perfil atual. [canOpen] é a mesma decisão do router.
List<MainMenuEntry> buildMainMenu(bool Function(String route) canOpen) {
  final List<MainMenuEntry> entries = <MainMenuEntry>[];
  for (final MainMenuModule module in MainMenuModule.values) {
    if (!module.requiredRoutes.every(canOpen)) continue;
    for (final String route in module.candidateRoutes) {
      if (canOpen(route)) {
        entries.add(MainMenuEntry(module: module, route: route));
        break;
      }
    }
  }
  return entries;
}

/// Índice do item ativo para [location] (prefixo mais longo vence), ou -1.
int activeMainMenuIndex(List<MainMenuEntry> entries, String location) {
  int best = -1;
  int bestLength = -1;
  for (int i = 0; i < entries.length; i++) {
    for (final String prefix in entries[i].module.activePrefixes) {
      final bool matches =
          location == prefix || location.startsWith('$prefix/');
      if (matches && prefix.length > bestLength) {
        best = i;
        bestLength = prefix.length;
      }
    }
  }
  return best;
}
