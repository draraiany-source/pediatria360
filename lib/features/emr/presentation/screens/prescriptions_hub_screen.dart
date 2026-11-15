import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../shell/presentation/providers/selected_patient_provider.dart';
import 'document_editor_screen.dart';
import 'patient_timeline_screen.dart'
    show patientDocumentsProvider, patientEncountersProvider;

/// Hub do modulo Prescricoes — seleciona atendimento assinado e abre o
/// Receituario Inteligente (DocumentEditorScreen).
class PrescriptionsHubScreen extends ConsumerWidget {
  const PrescriptionsHubScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SelectedPatient? focus = ref.watch(selectedPatientProvider);
    final AsyncValue<List<Encounter>> encountersAsync =
        ref.watch(patientEncountersProvider(childId));
    final AsyncValue<List<ClinicalDocument>> docsAsync =
        ref.watch(patientDocumentsProvider(childId));
    final ThemeData theme = Theme.of(context);
    final String patientName = focus?.childId == childId
        ? focus!.name
        : (focus?.name ?? 'Paciente');

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: ContentBounds(
        maxWidth: 1100,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: encountersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace s) => EmptyState(
            icon: Icons.error_outline,
            title: 'Nao foi possivel carregar',
            message: '$e',
          ),
          data: (List<Encounter> encounters) {
            final List<Encounter> signed = encounters
                .where((Encounter e) => e.status == EncounterStatus.signed)
                .toList()
              ..sort((Encounter a, Encounter b) =>
                  b.startedAt.compareTo(a.startedAt));
            final List<ClinicalDocument> prescriptions = docsAsync.maybeWhen(
              data: (List<ClinicalDocument> docs) => docs
                  .where(
                    (ClinicalDocument d) =>
                        d.type == ClinicalDocumentType.prescription &&
                        !d.cancelled,
                  )
                  .toList(),
              orElse: () => const <ClinicalDocument>[],
            );

            return ListView(
              children: <Widget>[
                Text(
                  'Receituario Inteligente',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modelos prontos e apoio da IA com autorizacao medica.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.person_outline_rounded,
                          color: AppColors.success),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Paciente',
                              style: TextStyle(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push(
                          Routes.patientModule(
                            'prescricoes',
                          ),
                        ),
                        child: const Text('Trocar paciente'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: () =>
                            context.push(Routes.clinicPatient360(childId)),
                        child: const Text('Paciente 360'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Emitir nova receita',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (signed.isEmpty)
                  const AppCard(
                    color: AppColors.softYellow,
                    child: Text(
                      'Nenhum atendimento assinado para este paciente. '
                      'Assine um atendimento no prontuario para emitir '
                      'receita vinculada. A IA nao emite nem assina.',
                    ),
                  )
                else
                  ...signed.take(8).map((Encounter e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DocumentEditorScreen(
                                encounter: e,
                                type: ClinicalDocumentType.prescription,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.medication_outlined,
                                color: AppColors.brand),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Atendimento ${DateFormat('dd/MM/yyyy HH:mm').format(e.startedAt)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    e.type.label,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Abrir receituario',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Receitas emitidas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (prescriptions.isEmpty)
                  const AppCard(
                    child: Text(
                      'Nenhuma receita emitida ainda. Nao exibimos '
                      'modelos ficticios do mockup.',
                    ),
                  )
                else
                  ...prescriptions.take(12).map((ClinicalDocument d) {
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(d.type.label),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(d.issuedAt),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          context.push(Routes.clinicPatient360(childId)),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
