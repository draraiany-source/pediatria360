import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../domain/management_modules.dart';
import 'management_common.dart';

/// Menu da gestão integrada: só os módulos que o papel na clínica permite.
class ManagementHubScreen extends ConsumerWidget {
  const ManagementHubScreen({super.key});

  static IconData iconFor(ManagementModule m) => switch (m) {
        ManagementModule.agenda => Icons.calendar_month_outlined,
        ManagementModule.crm => Icons.people_alt_outlined,
        ManagementModule.anamnesis => Icons.assignment_outlined,
        ManagementModule.care => Icons.medical_services_outlined,
        ManagementModule.finance => Icons.payments_outlined,
        ManagementModule.communication => Icons.chat_outlined,
        ManagementModule.automations => Icons.schedule_send_outlined,
        ManagementModule.marketing => Icons.campaign_outlined,
        ManagementModule.aiHub => Icons.insights_outlined,
        ManagementModule.settings => Icons.settings_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? m = activeMembership(ref);
    final List<ManagementModule> modules = visibleManagementModules(m?.role);
    final bool transcribe =
        AppConfig.voiceConsultationEnabled && canTranscribeConsultation(m?.role);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          m == null || m.clinicName.isEmpty ? 'Gestão' : m.clinicName,
        ),
      ),
      body: modules.isEmpty
          ? const EmptyState(
              title: 'Sem módulos de gestão',
              message: 'Seu acesso depende do vínculo ativo com uma clínica.',
            )
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final int columns = c.maxWidth >= 1000
                    ? 3
                    : c.maxWidth >= 640
                        ? 2
                        : 1;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (transcribe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.mic_none_outlined),
                          label: const Text('Transcrever consulta'),
                          onPressed: () =>
                              context.push(Routes.clinicVoiceConsentPath),
                        ),
                      ),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 4.2 : 2.6,
                      children: <Widget>[
                        for (final ManagementModule mod in modules)
                          _ModuleTile(module: mod),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final ManagementModule module;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(module.path),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(ManagementHubScreen.iconFor(module), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        module.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
