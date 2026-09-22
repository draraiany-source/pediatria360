import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../domain/clinic_workflow.dart';
import '../providers/clinic_providers.dart';

/// Quadro de recepção, fila operacional e check-in do dia.
///
/// Amplia o módulo Consultório já existente — não duplica Agenda/Prontuário.
class ClinicReceptionScreen extends ConsumerStatefulWidget {
  const ClinicReceptionScreen({super.key});

  @override
  ConsumerState<ClinicReceptionScreen> createState() =>
      _ClinicReceptionScreenState();
}

class _ClinicReceptionScreenState extends ConsumerState<ClinicReceptionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const List<ClinicWorkflowStatus> _boardColumns =
      <ClinicWorkflowStatus>[
    ClinicWorkflowStatus.scheduled,
    ClinicWorkflowStatus.confirmed,
    ClinicWorkflowStatus.arrived,
    ClinicWorkflowStatus.triage,
    ClinicWorkflowStatus.waitingDoctor,
    ClinicWorkflowStatus.called,
    ClinicWorkflowStatus.inService,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ClinicWorkflowStatus _workflowOf(Appointment a) => ClinicWorkflowStatus.resolve(
        workflowStatus: a.workflowStatus,
        appointmentStatus: a.status.name,
      );

  Future<void> _setStatus(Appointment a, ClinicWorkflowStatus status) async {
    final result = await ref
        .read(clinicRepositoryProvider)
        .updateWorkflowStatus(a.id, status);
    if (!mounted) return;
    result.fold(
      (_) => ref.invalidate(todayClinicAppointmentsProvider),
      (Failure f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
    );
  }

  Future<void> _checkIn(Appointment a) async {
    final TextEditingController notes = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Confirmar chegada'),
        content: TextField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'Observação administrativa (opcional)',
            hintText: 'Ex.: chegou com responsável, prioridade…',
          ),
          maxLines: 2,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check-in'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ref.read(clinicRepositoryProvider).checkIn(
          a.id,
          notes: notes.text,
        );
    notes.dispose();
    if (!mounted) return;
    result.fold(
      (_) => ref.invalidate(todayClinicAppointmentsProvider),
      (Failure f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
    );
  }

  String _waitLabel(Appointment a) {
    final DateTime? arrived = a.arrivedAt;
    if (arrived == null) {
      final int delayMin = DateTime.now().difference(a.startsAt).inMinutes;
      if (delayMin > 5) return 'Atraso ${delayMin} min';
      if (delayMin < -5) return 'Em ${-delayMin} min';
      return 'No horário';
    }
    final int wait = DateTime.now().difference(arrived).inMinutes;
    return 'Espera ${wait < 0 ? 0 : wait} min';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Appointment>> async =
        ref.watch(todayClinicAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Recepção'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.inkMuted,
          tabs: const <Widget>[
            Tab(text: 'Quadro'),
            Tab(text: 'Fila'),
            Tab(text: 'Check-in'),
          ],
        ),
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
              asset: AppIcons.waitingQueue,
              actionLabel: 'Ver agenda',
              onAction: () => context.go(Routes.agendaPath),
            );
          }
          return TabBarView(
            controller: _tabs,
            children: <Widget>[
              _BoardTab(
                list: list,
                columns: _boardColumns,
                workflowOf: _workflowOf,
                waitLabel: _waitLabel,
                onCheckIn: _checkIn,
                onStatus: _setStatus,
              ),
              _QueueTab(
                list: list,
                workflowOf: _workflowOf,
                waitLabel: _waitLabel,
                onStatus: _setStatus,
                onCheckIn: _checkIn,
              ),
              _CheckInTab(
                list: list,
                workflowOf: _workflowOf,
                onCheckIn: _checkIn,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardTab extends StatelessWidget {
  const _BoardTab({
    required this.list,
    required this.columns,
    required this.workflowOf,
    required this.waitLabel,
    required this.onCheckIn,
    required this.onStatus,
  });

  final List<Appointment> list;
  final List<ClinicWorkflowStatus> columns;
  final ClinicWorkflowStatus Function(Appointment) workflowOf;
  final String Function(Appointment) waitLabel;
  final Future<void> Function(Appointment) onCheckIn;
  final Future<void> Function(Appointment, ClinicWorkflowStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('HH:mm');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.map((ClinicWorkflowStatus col) {
              final List<Appointment> items = list
                  .where((Appointment a) => workflowOf(a) == col)
                  .toList(growable: false);
              return Container(
                width: 280,
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...items.map(
                      (Appointment a) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ReceptionCard(
                          appointment: a,
                          workflow: col,
                          timeLabel: fmt.format(a.startsAt),
                          waitLabel: waitLabel(a),
                          onCheckIn: () => onCheckIn(a),
                          onStatus: (ClinicWorkflowStatus s) => onStatus(a, s),
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
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({
    required this.list,
    required this.workflowOf,
    required this.waitLabel,
    required this.onStatus,
    required this.onCheckIn,
  });

  final List<Appointment> list;
  final ClinicWorkflowStatus Function(Appointment) workflowOf;
  final String Function(Appointment) waitLabel;
  final Future<void> Function(Appointment, ClinicWorkflowStatus) onStatus;
  final Future<void> Function(Appointment) onCheckIn;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('HH:mm');
    final List<Appointment> queue = list.where((Appointment a) {
      final ClinicWorkflowStatus w = workflowOf(a);
      return w == ClinicWorkflowStatus.arrived ||
          w == ClinicWorkflowStatus.triage ||
          w == ClinicWorkflowStatus.waitingDoctor ||
          w == ClinicWorkflowStatus.called ||
          w == ClinicWorkflowStatus.inService;
    }).toList()
      ..sort((Appointment a, Appointment b) {
        final int oa = workflowOf(a).queueOrder;
        final int ob = workflowOf(b).queueOrder;
        if (oa != ob) return oa.compareTo(ob);
        final DateTime aa = a.arrivedAt ?? a.startsAt;
        final DateTime bb = b.arrivedAt ?? b.startsAt;
        return aa.compareTo(bb);
      });

    if (queue.isEmpty) {
      return const EmptyState(
        title: 'Fila vazia',
        message: 'Pacientes em espera aparecem aqui após o check-in.',
        icon: Icons.groups_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int i) {
        final Appointment a = queue[i];
        final ClinicWorkflowStatus w = workflowOf(a);
        return AppCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: AppColors.softTeal,
                    foregroundColor: AppColors.tealDeep,
                    child: Text('${i + 1}'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          a.childName?.isNotEmpty == true
                              ? a.childName!
                              : 'Paciente',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                        ),
                        Text(
                          '${fmt.format(a.startsAt)} · ${a.professionalName} · ${w.label}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    waitLabel(a),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.raspberry,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              if (a.roomLabel != null && a.roomLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text('Sala: ${a.roomLabel}'),
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  if (w == ClinicWorkflowStatus.arrived)
                    TextButton(
                      onPressed: () =>
                          onStatus(a, ClinicWorkflowStatus.triage),
                      child: const Text('Triagem'),
                    ),
                  if (w == ClinicWorkflowStatus.waitingDoctor ||
                      w == ClinicWorkflowStatus.arrived ||
                      w == ClinicWorkflowStatus.triage)
                    TextButton(
                      onPressed: () =>
                          onStatus(a, ClinicWorkflowStatus.called),
                      child: const Text('Chamar'),
                    ),
                  if (w == ClinicWorkflowStatus.called ||
                      w == ClinicWorkflowStatus.waitingDoctor)
                    TextButton(
                      onPressed: () =>
                          onStatus(a, ClinicWorkflowStatus.inService),
                      child: const Text('Iniciar'),
                    ),
                  TextButton(
                    onPressed: () => onCheckIn(a),
                    child: const Text('Notas'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckInTab extends StatelessWidget {
  const _CheckInTab({
    required this.list,
    required this.workflowOf,
    required this.onCheckIn,
  });

  final List<Appointment> list;
  final ClinicWorkflowStatus Function(Appointment) workflowOf;
  final Future<void> Function(Appointment) onCheckIn;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('HH:mm');
    final List<Appointment> pending = list.where((Appointment a) {
      final ClinicWorkflowStatus w = workflowOf(a);
      return w == ClinicWorkflowStatus.scheduled ||
          w == ClinicWorkflowStatus.confirmed;
    }).toList()
      ..sort((Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        AppCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Check-in digital',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Confirme a presença pela recepção. O link abaixo identifica '
                'o agendamento (QR/portal da família entram nas próximas fases '
                'com autenticação). Não envia mensagem automática.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (pending.isEmpty)
          const EmptyState(
            title: 'Ninguém aguardando check-in',
            message: 'Consultas confirmadas ou agendadas do dia aparecem aqui.',
            icon: Icons.how_to_reg_outlined,
          )
        else
          ...pending.map((Appointment a) {
            final String deepLink =
                'pediatria360://checkin/${a.id}';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      a.childName?.isNotEmpty == true
                          ? a.childName!
                          : 'Paciente',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    Text(
                      '${fmt.format(a.startsAt)} · ${a.type.label} · '
                      '${a.professionalName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            deepLink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar identificador',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: deepLink),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Identificador copiado'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => onCheckIn(a),
                      icon: const AppIcon(
                        asset: AppIcons.waitingQueue,
                        size: 18,
                        fallback: Icons.how_to_reg_rounded,
                      ),
                      label: const Text('Confirmar chegada'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ReceptionCard extends StatelessWidget {
  const _ReceptionCard({
    required this.appointment,
    required this.workflow,
    required this.timeLabel,
    required this.waitLabel,
    required this.onCheckIn,
    required this.onStatus,
  });

  final Appointment appointment;
  final ClinicWorkflowStatus workflow;
  final String timeLabel;
  final String waitLabel;
  final VoidCallback onCheckIn;
  final void Function(ClinicWorkflowStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            appointment.childName?.isNotEmpty == true
                ? appointment.childName!
                : 'Paciente',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            '$timeLabel · ${appointment.type.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          Text(
            appointment.professionalName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            waitLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.raspberry,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (appointment.checkInNotes != null &&
              appointment.checkInNotes!.isNotEmpty)
            Text(
              appointment.checkInNotes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (appointment.reason != null && appointment.reason!.isNotEmpty)
            Text(
              appointment.reason!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (workflow == ClinicWorkflowStatus.scheduled ||
                  workflow == ClinicWorkflowStatus.confirmed)
                TextButton(
                  onPressed: onCheckIn,
                  child: const Text('Check-in'),
                ),
              TextButton(
                onPressed: () => context.push(
                  Routes.clinicTriage(appointment.id),
                ),
                child: const Text('Triagem'),
              ),
              if (workflow == ClinicWorkflowStatus.arrived ||
                  workflow == ClinicWorkflowStatus.triage ||
                  workflow == ClinicWorkflowStatus.waitingDoctor)
                TextButton(
                  onPressed: () => onStatus(ClinicWorkflowStatus.called),
                  child: const Text('Chamar'),
                ),
              if (workflow == ClinicWorkflowStatus.called ||
                  workflow == ClinicWorkflowStatus.waitingDoctor)
                TextButton(
                  onPressed: () => onStatus(ClinicWorkflowStatus.inService),
                  child: const Text('Iniciar'),
                ),
              TextButton(
                onPressed: () => onStatus(ClinicWorkflowStatus.noShow),
                child: const Text('Falta'),
              ),
              TextButton(
                onPressed: () => onStatus(ClinicWorkflowStatus.cancelled),
                child: const Text('Cancelar'),
              ),
              if (appointment.childId != null)
                TextButton(
                  onPressed: () => context.push(
                    Routes.clinicPatient360(appointment.childId!),
                  ),
                  child: const Text('360'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
