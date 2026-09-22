import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/vaccine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../../inventory/domain/inventory_models.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../domain/pni_calendar.dart';

class VaccinesScreen extends ConsumerStatefulWidget {
  const VaccinesScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<VaccinesScreen> createState() => _VaccinesScreenState();
}

class _VaccinesScreenState extends ConsumerState<VaccinesScreen> {
  bool _showApplied = true;

  String _ageLabel(int months) {
    if (months < 24) return '$months ${months == 1 ? 'mês' : 'meses'}';
    final int years = months ~/ 12;
    return '$years ${years == 1 ? 'ano' : 'anos'}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Child? child = ref.watch(childProvider(widget.childId)).valueOrNull;
    final AsyncValue<List<VaccineDose>> doses =
        ref.watch(vaccineDosesProvider(widget.childId));
    final VaccineSummary summary =
        ref.watch(vaccineSummaryProvider(widget.childId));

    if (child == null) return const Scaffold(body: LoadingState());

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Vacinas',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Acompanhe o calendário vacinal do seu pequeno.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const AppIcon(
            asset: AppIcons.back,
            size: 22,
            fallback: Icons.arrow_back_rounded,
          ),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => setState(() => _showApplied = !_showApplied),
            icon: AppIcon(
              asset: AppIcons.filter,
              size: 22,
              fallback: _showApplied
                  ? Icons.filter_list_rounded
                  : Icons.filter_list_off_rounded,
              color: AppColors.brand,
            ),
            tooltip: _showApplied
                ? 'Ocultar aplicadas'
                : 'Mostrar aplicadas',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const DataWarningBanner(text: PniCalendar.warning),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: ContentBounds(
              child: SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        PersonAvatar(
                          name: child.name,
                          seed: child.id,
                          radius: 28,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                child.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${_ageLabel(child.ageInMonths)} • Nasc. ${Formatters.date(child.birthDate)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatusCount(
                            label: 'Aplicadas',
                            value: summary.applied,
                            color: AppColors.success,
                          ),
                        ),
                        Expanded(
                          child: _StatusCount(
                            label: 'Pendentes',
                            value: summary.overdue,
                            color: AppColors.warning,
                          ),
                        ),
                        Expanded(
                          child: _StatusCount(
                            label: 'Próximas',
                            value: summary.upcoming,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: doses.when(
        loading: () => const SkeletonList(itemCount: 6, itemHeight: 64),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.error_outline_rounded,
          asset: AppIcons.alert,
          title: 'Não conseguimos carregar essas informações',
          message: 'Tente novamente em alguns instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(vaccineDosesProvider(widget.childId)),
        ),
        data: (List<VaccineDose> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.vaccines_outlined,
              asset: AppIcons.vaccineCard,
              title: 'Calendário não gerado',
              message: 'Vamos montar o calendário do PNI a partir da data '
                  'de nascimento de ${child.firstName}.',
              actionLabel: 'Gerar calendário',
              onAction: () => ref
                  .read(childrenControllerProvider.notifier)
                  .ensureSchedule(child),
            );
          }

          final List<VaccineDose> visible = _showApplied
              ? list
              : list.where((VaccineDose d) => !d.isApplied).toList();

          // Agrupa por idade prevista — é assim que a caderneta é lida, e o
          // responsável costuma pensar "o que falta dos 4 meses?".
          final Map<int, List<VaccineDose>> byAge = <int, List<VaccineDose>>{};
          for (final VaccineDose dose in visible) {
            final VaccineDoseSchedule? schedule =
                PniCalendar.find(dose.vaccineId, dose.doseIndex);
            if (schedule == null) continue;
            byAge
                .putIfAbsent(schedule.ageMonths, () => <VaccineDose>[])
                .add(dose);
          }

          final List<int> ages = byAge.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: <Widget>[
              ContentBounds(child: _SummaryCard(summary: summary)),
              for (final int age in ages)
                ContentBounds(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SectionHeader(
                        title: PniCalendar.schedule
                            .firstWhere(
                              (VaccineDoseSchedule s) => s.ageMonths == age,
                            )
                            .ageLabel,
                      ),
                      for (final VaccineDose dose in byAge[age]!)
                        _DoseTile(
                          dose: dose,
                          schedule: PniCalendar.find(
                            dose.vaccineId,
                            dose.doseIndex,
                          )!,
                          onToggle: (bool applied) =>
                              _toggle(context, dose, applied),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              ContentBounds(
                child: Text(
                  'Calendário Nacional de Vacinação (PNI). Confirme sempre '
                  'na unidade de saúde: o esquema pode mudar e há situações '
                  'que exigem avaliação individual.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    VaccineDose dose,
    bool applied,
  ) async {
    if (!applied) {
      await ref.read(childrenControllerProvider.notifier).toggleDose(
            dose: dose,
            applied: false,
          );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ApplyDoseSheet(dose: dose),
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final VaccineSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Caderneta',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              DataValue(
                value: '${summary.applied}',
                unit: '/ ${summary.total}',
                size: 20,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 8,
              color: AppColors.success,
              backgroundColor: theme.colorScheme.outlineVariant,
            ),
          ),
          if (summary.overdue > 0 || summary.upcoming > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (summary.overdue > 0)
                  AppTag(
                    label: '${summary.overdue} em atraso',
                    color: AppColors.danger,
                    icon: Icons.priority_high_rounded,
                    asset: AppIcons.vaccineOverdue,
                  ),
                if (summary.upcoming > 0)
                  AppTag(
                    label: '${summary.upcoming} nos próximos 30 dias',
                    color: AppColors.warning,
                    icon: Icons.schedule_rounded,
                    asset: AppIcons.vaccineNext,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({
    required this.dose,
    required this.schedule,
    required this.onToggle,
  });

  final VaccineDose dose;
  final VaccineDoseSchedule schedule;
  final ValueChanged<bool> onToggle;

  DoseStatus get _status {
    if (dose.isApplied) return DoseStatus.applied;
    if (dose.isOverdue()) return DoseStatus.overdue;
    if (dose.isUpcoming()) return DoseStatus.upcoming;
    return DoseStatus.scheduled;
  }

  Color _color(ThemeData theme) => switch (_status) {
        DoseStatus.applied => AppColors.success,
        DoseStatus.overdue => AppColors.danger,
        DoseStatus.upcoming => AppColors.warning,
        DoseStatus.scheduled => theme.colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _color(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Checkbox(
              value: dose.isApplied,
              onChanged: (bool? v) => onToggle(v ?? false),
              shape: const CircleBorder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            schedule.vaccineName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              decoration: dose.isApplied
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: dose.isApplied
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          schedule.doseLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      schedule.protects,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (schedule.notes != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        schedule.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        AppIcon(
                          asset: dose.isApplied
                              ? AppIcons.vaccineApplied
                              : dose.isOverdue()
                                  ? AppIcons.vaccineOverdue
                                  : dose.isUpcoming()
                                      ? AppIcons.vaccineNext
                                      : AppIcons.vaccinePending,
                          size: 16,
                          fallback: dose.isApplied
                              ? Icons.check_circle_outline_rounded
                              : dose.isUpcoming()
                                  ? Icons.schedule_rounded
                                  : Icons.event_outlined,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          dose.isApplied
                              ? 'Aplicada em '
                                  '${Formatters.date(dose.appliedAt!)}'
                              : dose.dueAt == null
                                  ? _status.label
                                  : '${_status.label} · '
                                      '${Formatters.date(dose.dueAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dose.pendingSync) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          AppIcon(
                            asset: AppIcons.upload,
                            size: 12,
                            fallback: Icons.cloud_upload_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmação de aplicação, com data, lote e local.
class _ApplyDoseSheet extends ConsumerStatefulWidget {
  const _ApplyDoseSheet({required this.dose});

  final VaccineDose dose;

  @override
  ConsumerState<_ApplyDoseSheet> createState() => _ApplyDoseSheetState();
}

class _ApplyDoseSheetState extends ConsumerState<_ApplyDoseSheet> {
  final TextEditingController _lot = TextEditingController();
  final TextEditingController _clinic = TextEditingController();
  DateTime _appliedAt = DateTime.now();
  String? _selectedInventoryLotId;

  @override
  void dispose() {
    _lot.dispose();
    _clinic.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _appliedAt,
      firstDate: DateTime(DateTime.now().year - 25),
      lastDate: DateTime.now(),
      helpText: 'Data da aplicação',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _appliedAt = picked);
  }

  Future<void> _submit() async {
    final List<InventoryLot> allLots =
        ref.read(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
    InventoryLot? pickedLot;
    if (_selectedInventoryLotId != null) {
      for (final InventoryLot l in allLots) {
        if (l.id == _selectedInventoryLotId) {
          pickedLot = l;
          break;
        }
      }
    }
    final String? lotLabel = pickedLot?.lotCode ??
        (_lot.text.trim().isEmpty ? null : _lot.text.trim());

    final bool ok =
        await ref.read(childrenControllerProvider.notifier).toggleDose(
              dose: widget.dose,
              applied: true,
              appliedAt: _appliedAt,
              lot: lotLabel,
              clinic:
                  _clinic.text.trim().isEmpty ? null : _clinic.text.trim(),
            );
    if (ok && pickedLot != null) {
      final String? uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        await ref.read(inventoryRepositoryProvider).confirmClinicalUse(
              ownerId: uid,
              lotId: pickedLot.id,
              itemId: pickedLot.itemId,
              qty: 1,
              userId: uid,
              childId: widget.dose.childId,
              vaccineDoseId: widget.dose.id,
              reason: 'Vacina aplicada',
            );
        ref.invalidate(inventoryLotsProvider);
        ref.invalidate(inventoryMovementsProvider);
      }
    }
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildActionState action = ref.watch(childrenControllerProvider);
    final VaccineDoseSchedule? schedule = PniCalendar.find(
      widget.dose.vaccineId,
      widget.dose.doseIndex,
    );
    final List<InventoryLot> allLots =
        ref.watch(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
    final List<InventoryItem> invItems =
        ref.watch(inventoryItemsProvider).valueOrNull ?? const <InventoryItem>[];
    final Set<String> vaccineItemIds = invItems
        .where((InventoryItem i) => i.category == InventoryCategory.vaccines)
        .map((InventoryItem i) => i.id)
        .toSet();
    final List<InventoryLot> vaccineLots = allLots
        .where(
          (InventoryLot l) =>
              l.qty > 0 &&
              (vaccineItemIds.isEmpty || vaccineItemIds.contains(l.itemId)),
        )
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              schedule == null
                  ? 'Registrar aplicação'
                  : '${schedule.vaccineName} · ${schedule.doseLabel}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickDate,
              borderRadius: AppRadius.mdAll,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da aplicação',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: AppIcon(
                      asset: AppIcons.vaccineApplied,
                      size: 20,
                      fallback: Icons.event_available_outlined,
                    ),
                  ),
                ),
                child: Text(
                  Formatters.date(_appliedAt),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (vaccineLots.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedInventoryLotId,
                decoration: const InputDecoration(
                  labelText: 'Lote do estoque (opcional)',
                  prefixIcon: Icon(Icons.vaccines_outlined),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Texto livre abaixo'),
                  ),
                  ...vaccineLots.map(
                    (InventoryLot l) => DropdownMenuItem<String>(
                      value: l.id,
                      child: Text('${l.lotCode} (${l.qty} un.)'),
                    ),
                  ),
                ],
                onChanged: (String? v) => setState(() {
                  _selectedInventoryLotId = v;
                  if (v != null) {
                    for (final InventoryLot l in vaccineLots) {
                      if (l.id == v) _lot.text = l.lotCode;
                    }
                  }
                }),
              ),
            if (vaccineLots.isNotEmpty) const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Lote',
              controller: _lot,
              hint: 'Está no carimbo da caderneta',
              prefixIcon: Icons.qr_code_2_rounded,
              textCapitalization: TextCapitalization.characters,
              enabled: _selectedInventoryLotId == null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Local',
              controller: _clinic,
              hint: 'UBS Centro',
              prefixIcon: Icons.local_hospital_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Confirmar aplicação',
              isLoading: action.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
