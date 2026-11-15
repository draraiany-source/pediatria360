import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/routine/child_routine.dart';
import '../demo_routine.dart';
import '../demo_session.dart';

Color routineKindColor(RoutineKind k) => switch (k) {
  RoutineKind.consulta => AppColors.brand,
  RoutineKind.retorno => const Color(0xFF5B3FD6),
  RoutineKind.vacina => const Color(0xFFB0185A),
  RoutineKind.medicamento => AppColors.warning,
  RoutineKind.atividade => AppColors.success,
  RoutineKind.lembrete => const Color(0xFF8A6100),
};

IconData routineKindIcon(RoutineKind k) => switch (k) {
  RoutineKind.consulta => Icons.medical_services_outlined,
  RoutineKind.retorno => Icons.event_repeat_rounded,
  RoutineKind.vacina => Icons.vaccines_outlined,
  RoutineKind.medicamento => Icons.medication_outlined,
  RoutineKind.atividade => Icons.directions_run_rounded,
  RoutineKind.lembrete => Icons.notifications_none_rounded,
};

Color diaryKindColor(DiaryKind k) => switch (k) {
  DiaryKind.mamada => const Color(0xFFB0185A),
  DiaryKind.alimentacao => AppColors.success,
  DiaryKind.fralda => const Color(0xFF0B6B8A),
  DiaryKind.sono => const Color(0xFF5B3FD6),
  DiaryKind.banho => AppColors.brand,
  DiaryKind.temperatura => AppColors.danger,
  DiaryKind.peso => AppColors.navy,
  DiaryKind.medicamento => AppColors.warning,
  DiaryKind.observacao => const Color(0xFF4A5B7A),
};

IconData diaryKindIcon(DiaryKind k) => switch (k) {
  DiaryKind.mamada => Icons.local_drink_outlined,
  DiaryKind.alimentacao => Icons.restaurant_outlined,
  DiaryKind.fralda => Icons.baby_changing_station_outlined,
  DiaryKind.sono => Icons.bedtime_outlined,
  DiaryKind.banho => Icons.bathtub_outlined,
  DiaryKind.temperatura => Icons.thermostat_outlined,
  DiaryKind.peso => Icons.monitor_weight_outlined,
  DiaryKind.medicamento => Icons.medication_outlined,
  DiaryKind.observacao => Icons.edit_note_rounded,
};

String routineUrl(
  String patientId, {
  String view = 'calendario',
  String mode = 'mes',
  DateTime? day,
  String? consultation,
  String? from,
}) {
  final String d = day == null ? '' : '&dia=${routineDateKey(day)}';
  final String c = consultation == null ? '' : '&consulta=$consultation';
  final String f = from == null ? '' : '&de=$from';
  return '/rotina/$patientId?vista=$view&modo=$mode$d$c$f';
}

/// Planejado: contorno. Realizado: preenchido com check. Cancelado: cinza
/// com traço.
class RoutineStatusMarker extends StatelessWidget {
  const RoutineStatusMarker({
    required this.icon,
    required this.color,
    required this.status,
    super.key,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final RoutineStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool done = status == RoutineStatus.done;
    final bool cancelled = status == RoutineStatus.cancelled;
    final Color c = cancelled ? const Color(0xFF7B8798) : color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? c
                  : cancelled
                  ? const Color(0xFFE8ECF2)
                  : Colors.white,
              border: Border.all(
                color: c,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Icon(icon, size: size * 0.5, color: done ? Colors.white : c),
          ),
          if (done || cancelled)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: size * 0.38,
                  color: done ? AppColors.success : const Color(0xFF7B8798),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoutineStatusChip extends StatelessWidget {
  const RoutineStatusChip(this.status, {super.key, this.overdue = false});

  final RoutineStatus status;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final (String label, Color fg, Color bg, bool outline) = switch (status) {
      RoutineStatus.planned when overdue => (
        'Atrasado',
        const Color(0xFF9A3D00),
        Colors.white,
        true,
      ),
      RoutineStatus.planned => (
        'Planejado',
        AppColors.navy,
        Colors.white,
        true,
      ),
      RoutineStatus.done => (
        'Realizado',
        Colors.white,
        AppColors.success,
        false,
      ),
      RoutineStatus.cancelled => (
        'Cancelado',
        const Color(0xFF3F4A5A),
        const Color(0xFFE3E7EE),
        false,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillAll,
        border: outline ? Border.all(color: fg, width: 1.2) : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RoutineLegend extends StatelessWidget {
  const RoutineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(RoutineStatus s, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RoutineStatusMarker(
          icon: Icons.circle_outlined,
          color: AppColors.brand,
          status: s,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
    return Semantics(
      container: true,
      label:
          'Legenda: contorno é planejado, preenchido com marca é realizado, '
          'cinza é cancelado',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          item(RoutineStatus.planned, 'Planejado'),
          item(RoutineStatus.done, 'Realizado'),
          item(RoutineStatus.cancelled, 'Cancelado'),
        ],
      ),
    );
  }
}

/// Linha de compromisso do calendário.
class RoutineItemTile extends StatelessWidget {
  const RoutineItemTile({
    required this.item,
    required this.onTap,
    super.key,
    this.showDate = false,
  });

  final CalendarItem item;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final bool cancelled = item.status == RoutineStatus.cancelled;
    final bool overdue = item.isOverdue(demoSession.now);
    final String when = showDate
        ? '${formatDm(item.start)} ${item.timeLabel}'
        : item.timeLabel;
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: item.isPlanned
                  ? routineKindColor(item.kind).withValues(alpha: 0.55)
                  : AppColors.line,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: <Widget>[
              RoutineStatusMarker(
                icon: routineKindIcon(item.kind),
                color: routineKindColor(item.kind),
                status: item.status,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: t.titleSmall?.copyWith(
                        color: cancelled ? AppColors.inkMuted : AppColors.navy,
                        fontWeight: FontWeight.w800,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$when - ${item.kind.label} - ${item.source.label}',
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  RoutineStatusChip(item.status, overdue: overdue),
                  if (item.reminders.isNotEmpty && item.isPlanned)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: AppColors.inkMuted,
                        semanticLabel: 'Com lembrete',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha da linha do tempo do diário.
class DiaryEntryTile extends StatelessWidget {
  const DiaryEntryTile({
    required this.entry,
    required this.onTap,
    super.key,
    this.showDate = false,
  });

  final DiaryEntry entry;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Color c = diaryKindColor(entry.kind);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: showDate ? 78 : 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  showDate
                      ? '${formatDm(entry.at)} ${formatHm(entry.at)}'
                      : formatHm(entry.at),
                  style: t.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(diaryKindIcon(entry.kind), color: c, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: entry.kind.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (entry.describe.isNotEmpty)
                          TextSpan(text: ': ${entry.describe}'),
                      ],
                    ),
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.navy,
                      decoration: entry.voided
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (entry.values.note.trim().isNotEmpty)
                    Text(
                      entry.values.note.trim(),
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      AuthorBadge(role: entry.role),
                      Text(
                        entry.author,
                        style: t.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      if (entry.wasCorrected)
                        const _MiniTag('corrigido', AppColors.warning),
                      if (entry.voided)
                        const _MiniTag('excluído', AppColors.danger),
                      if (entry.attachment != null)
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 15,
                          color: AppColors.inkMuted,
                          semanticLabel: 'Com anexo',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Deixa claro para o profissional quem informou o dado.
class AuthorBadge extends StatelessWidget {
  const AuthorBadge({required this.role, super.key});

  final DiaryRole role;

  @override
  Widget build(BuildContext context) {
    final bool family = role == DiaryRole.familia;
    return _MiniTag(
      family ? 'Informado pela família' : 'Profissional',
      family ? const Color(0xFF0B6B8A) : AppColors.brand,
      icon: family ? Icons.family_restroom_rounded : Icons.badge_outlined,
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label, this.color, {this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de lembrete dentro do app (a demonstração não envia notificação
/// do sistema). Confere o relógio a cada 20 segundos.
class DemoReminderBar extends StatefulWidget {
  const DemoReminderBar({super.key});

  @override
  State<DemoReminderBar> createState() => _DemoReminderBarState();
}

class _DemoReminderBarState extends State<DemoReminderBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demoSession,
    builder: (BuildContext context, _) => _bar(context),
  );

  Widget _bar(BuildContext context) {
    final List<ReminderAlert> alerts = demoSession.activeReminders();
    if (alerts.isEmpty) return const SizedBox.shrink();
    final ReminderAlert a = alerts.first;
    final CalendarItem item = a.reminder.item;
    final TextTheme t = Theme.of(context).textTheme;
    final String when = item.allDay
        ? '${formatDm(item.start)} (dia inteiro)'
        : '${sameDay(item.start, demoSession.now) ? 'hoje' : formatDm(item.start)} às ${formatHm(item.start)}';
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: const Color(0xFFFFF4D6),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2B84D))),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF8A6100),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Lembrete: ${item.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelLarge?.copyWith(
                        color: const Color(0xFF4D3600),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${a.patient.name.split(' ').first} - $when'
                      '${alerts.length > 1 ? ' - mais ${alerts.length - 1}' : ''}',
                      style: t.bodySmall?.copyWith(
                        color: const Color(0xFF4D3600),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  context.go(
                    routineUrl(a.patient.id, mode: 'dia', day: item.start),
                  );
                },
                child: const Text('Ver'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => demoSession.dismissReminder(a.reminder.key),
                child: const Text('Dispensar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grupo de opções de toque único (Semantics próprio para o leitor de
/// tela e para os testes no navegador).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final T o in options)
          ChoiceChip(
            label: Text(label(o)),
            selected: o == selected,
            onSelected: (bool v) => onSelected(v ? o : null),
          ),
      ],
    );
  }
}

/// Barra de período com anterior, próximo e hoje.
class RoutinePeriodBar extends StatelessWidget {
  const RoutinePeriodBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    super.key,
    this.prevLabel = 'Anterior',
    this.nextLabel = 'Próximo',
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToday;
  final String prevLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: prevLabel,
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: nextLabel,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(onPressed: onToday, child: const Text('Hoje')),
      ],
    );
  }
}
