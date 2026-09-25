import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../data/clinic_schedule_repository.dart';
import '../../domain/agenda_scheduling.dart';
import '../providers/clinic_schedule_providers.dart';

/// Salas e bloqueios da clinica ativa (admin).
class ClinicScheduleConfigScreen extends ConsumerWidget {
  const ClinicScheduleConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? membership =
        ref.watch(activeClinicMembershipProvider);
    final String? clinicId =
        ref.watch(activeClinicIdProvider).valueOrNull;
    final AsyncValue<List<ClinicRoom>> rooms = ref.watch(clinicRoomsProvider);
    final AsyncValue<List<ScheduleBlock>> blocks =
        ref.watch(clinicScheduleBlocksProvider);

    if (clinicId == null || clinicId.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          title: 'Selecione uma clinica',
          message: 'Ative uma clinica em Minha clinica antes de configurar salas.',
        ),
      );
    }

    final bool canEdit = membership?.role == ClinicRole.clinicAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Salas e bloqueios')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addRoom(context, ref, clinicId, membership),
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Nova sala'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            canEdit
                ? 'Configure salas fisicas e bloqueios de horario.'
                : 'Somente o administrador da clinica altera salas e bloqueios.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Salas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          rooms.when(
            loading: () => const LoadingState(label: 'Carregando salas...'),
            error: (Object e, _) => ErrorState(
              failure: e is Failure ? e : ServerFailure(e.toString()),
            ),
            data: (List<ClinicRoom> list) {
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'Nenhuma sala',
                  message: 'Cadastre salas para evitar conflito de horario.',
                );
              }
              return Column(
                children: list
                    .map(
                      (ClinicRoom r) => ListTile(
                        title: Text(r.name),
                        subtitle: Text(
                          r.active ? 'Ativa' : 'Inativa'
                          '${r.unitId.isEmpty ? '' : ' · unidade ${r.unitId}'}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Bloqueios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: () =>
                      _addBlock(context, ref, clinicId, membership),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Bloquear horario'),
                ),
            ],
          ),
          blocks.when(
            loading: () => const LoadingState(label: 'Carregando bloqueios...'),
            error: (Object e, _) => ErrorState(
              failure: e is Failure ? e : ServerFailure(e.toString()),
            ),
            data: (List<ScheduleBlock> list) {
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'Sem bloqueios',
                  message: 'Feriados e intervalos aparecem aqui.',
                );
              }
              return Column(
                children: list
                    .map(
                      (ScheduleBlock b) => ListTile(
                        title: Text(
                          b.reason.isEmpty ? 'Horario bloqueado' : b.reason,
                        ),
                        subtitle: Text(
                          '${b.startsAt} → ${b.endsAt}'
                          '${b.roomId.isEmpty ? '' : ' · sala ${b.roomId}'}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addRoom(
    BuildContext context,
    WidgetRef ref,
    String clinicId,
    ClinicMembership? membership,
  ) async {
    final TextEditingController name = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Nova sala'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nome da sala'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final Result<void> result =
        await ref.read(clinicScheduleRepositoryProvider).upsertRoom(
              clinicId: clinicId,
              room: ClinicRoom(id: id, name: name.text.trim()),
              membership: membership,
            );
    if (!context.mounted) return;
    result.fold(
      (_) {},
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _addBlock(
    BuildContext context,
    WidgetRef ref,
    String clinicId,
    ClinicMembership? membership,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !context.mounted) return;
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (start == null || !context.mounted) return;
    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 13, minute: 0),
    );
    if (end == null || !context.mounted) return;
    final DateTime startsAt =
        DateTime(day.year, day.month, day.day, start.hour, start.minute);
    final DateTime endsAt =
        DateTime(day.year, day.month, day.day, end.hour, end.minute);
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final Result<void> result =
        await ref.read(clinicScheduleRepositoryProvider).upsertBlock(
              clinicId: clinicId,
              block: ScheduleBlock(
                id: id,
                startsAt: startsAt,
                endsAt: endsAt,
                reason: 'Bloqueio manual',
              ),
              membership: membership,
            );
    if (!context.mounted) return;
    result.fold(
      (_) {},
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }
}
