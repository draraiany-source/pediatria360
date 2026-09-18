import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../domain/clinic_workflow.dart';
import '../providers/clinic_providers.dart';

/// Quadro de recepcao por status do fluxo.
class ClinicReceptionScreen extends ConsumerWidget {
  const ClinicReceptionScreen({super.key});

  static const List<ClinicWorkflowStatus> _columns = <ClinicWorkflowStatus>[
    ClinicWorkflowStatus.scheduled,
    ClinicWorkflowStatus.confirmed,
    ClinicWorkflowStatus.arrived,
    ClinicWorkflowStatus.triage,
    ClinicWorkflowStatus.waitingDoctor,
    ClinicWorkflowStatus.inService,
  ];

  ClinicWorkflowStatus _workflowOf(Appointment a) {
    // Preferencia: campo workflowStatus se existir no documento — o modelo
    // Appointment atual nao expoe; usamos o status legado.
    return ClinicWorkflowStatus.fromAppointmentStatus(a.status.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Appointment>> async =
        ref.watch(todayClinicAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Recepcao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando fila…'),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(todayClinicAppointmentsProvider),
        ),
        data: (List<Appointment> list) {
          if (list.isEmpty) {
            return EmptyState(
              title: 'Nenhuma consulta hoje',
              message: 'Quando houver agendamentos, a fila aparece aqui.',
              icon: Icons.event_available_outlined,
              actionLabel: 'Ver agenda',
              onAction: () => context.go(Routes.agendaPath),
            );
          }

          final DateFormat fmt = DateFormat('HH:mm');
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _columns.map((ClinicWorkflowStatus col) {
                    final List<Appointment> items = list
                        .where(
                          (Appointment a) => _workflowOf(a) == col,
                        )
                        .toList(growable: false);
                    return Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softBlue,
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: Text(
                              '${col.label} (${items.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...items.map(
                            (Appointment a) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: AppCard(
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      a.childName?.isNotEmpty == true
                                          ? a.childName!
                                          : 'Paciente',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      fmt.format(a.startsAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.inkMuted,
                                          ),
                                    ),
                                    if (a.reason != null &&
                                        a.reason!.isNotEmpty)
                                      Text(
                                        a.reason!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: <Widget>[
                                        if (col ==
                                                ClinicWorkflowStatus
                                                    .scheduled ||
                                            col ==
                                                ClinicWorkflowStatus.confirmed)
                                          TextButton(
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    clinicRepositoryProvider,
                                                  )
                                                  .checkIn(a.id);
                                              ref.invalidate(
                                                todayClinicAppointmentsProvider,
                                              );
                                            },
                                            child: const Text('Check-in'),
                                          ),
                                        TextButton(
                                          onPressed: () => context.push(
                                            Routes.clinicTriage(a.id),
                                          ),
                                          child: const Text('Triagem'),
                                        ),
                                        if (a.childId != null)
                                          TextButton(
                                            onPressed: () => context.push(
                                              Routes.clinicPatient360(
                                                a.childId!,
                                              ),
                                            ),
                                            child: const Text('360'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
