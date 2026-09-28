import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/routine/child_routine.dart';
import '../demo_data.dart';
import '../demo_routine.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/routine_widgets.dart';
import 'routine_forms.dart';
import 'sleep_screens.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Rotina da criança": Calendário e Diário da mesma criança. O endereço
/// guarda a visualização, o modo e o dia (`/rotina/p1?vista=diario&dia=...`).
class DemoRoutineScreen extends StatefulWidget {
  const DemoRoutineScreen({
    super.key,
    this.patientId,
    this.view,
    this.mode,
    this.day,
    this.consultationId,
    this.from,
  });

  final String? patientId;
  final String? view;
  final String? mode;
  final String? day;

  /// Aberta de dentro de uma consulta: o voltar retorna a ela.
  final String? consultationId;

  /// `prontuario`: o voltar do profissional retorna ao prontuário.
  final String? from;

  @override
  State<DemoRoutineScreen> createState() => _DemoRoutineScreenState();
}

class _DemoRoutineScreenState extends State<DemoRoutineScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final List<DemoPatient> kids = demoSession.routinePatients;
        String? pid = widget.patientId;
        if (pid == null) {
          final String? last = demoSession.lastRoutinePatientId;
          pid = last != null && demoSession.routinePatient(last) != null
              ? last
              : (kids.isEmpty ? null : kids.first.id);
        }
        final DemoPatient? p = pid == null
            ? null
            : demoSession.routinePatient(pid);
        if (p == null) {
          return Scaffold(
            backgroundColor: AppColors.lightBackground,
            appBar: AppBar(title: const Text('Rotina da criança')),
            body: const DemoEmpty(
              title: 'Nenhuma criança vinculada',
              message:
                  'Cadastre uma criança em Pacientes para usar o calendário '
                  'e o diário.',
            ),
          );
        }
        if (demoSession.canEditRoutine) demoSession.lastRoutinePatientId = p.id;
        final String view =
            const <String>['diario', 'sono'].contains(widget.view)
            ? widget.view!
            : 'calendario';
        final String mode =
            const <String>['dia', 'semana', 'mes'].contains(widget.mode)
            ? widget.mode!
            : 'mes';
        final DateTime day =
            parseRoutineDateKey(widget.day) ?? dayOf(demoSession.now);
        final bool canEdit = demoSession.canEditRoutine;

        void go({String? v, String? m, DateTime? d}) => context.go(
          routineUrl(
            p.id,
            view: v ?? view,
            mode: m ?? mode,
            day: d ?? day,
            consultation: widget.consultationId,
            from: widget.from,
          ),
        );

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: canEdit
                ? null
                : BackButton(
                    onPressed: () => context.go(
                      widget.consultationId != null
                          ? '/pacientes/${p.id}/consulta/${widget.consultationId}'
                          : widget.from == 'prontuario'
                          ? '/pacientes/${p.id}/prontuario'
                          : '/pacientes/${p.id}',
                    ),
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Rotina da criança'),
                Text(
                  p.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
            actions: <Widget>[
              if (canEdit)
                IconButton(
                  tooltip: 'Resumo para o pediatra',
                  onPressed: () => context.go('/rotina/${p.id}/resumo'),
                  icon: const Icon(Icons.ios_share_rounded),
                )
              else
                IconButton(
                  tooltip: 'Resumos enviados pela família',
                  onPressed: () => context.go('/rotina/${p.id}/resumos'),
                  icon: const Icon(Icons.inbox_outlined),
                ),
            ],
          ),
          floatingActionButton: canEdit && view == 'calendario'
              ? FloatingActionButton.extended(
                  onPressed: () => context.go(
                    '/rotina/${p.id}/evento/novo?dia=${routineDateKey(day)}',
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo compromisso'),
                )
              : null,
          body: DemoContent(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      if (canEdit && kids.length > 1) ...<Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              for (final DemoPatient k in kids)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: CircleAvatar(
                                      backgroundColor: AppColors.teal,
                                      child: Text(
                                        k.name.characters.first,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    label: Text(k.name.split(' ').first),
                                    selected: k.id == p.id,
                                    onSelected: (_) => context.go(
                                      routineUrl(
                                        k.id,
                                        view: view,
                                        mode: mode,
                                        day: day,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          container: true,
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'calendario',
                                label: Text('Calendário'),
                                icon: Icon(Icons.calendar_month_outlined),
                              ),
                              ButtonSegment<String>(
                                value: 'diario',
                                label: Text('Diário'),
                                icon: Icon(Icons.menu_book_outlined),
                              ),
                              ButtonSegment<String>(
                                value: 'sono',
                                label: Text('Sono'),
                                icon: Icon(Icons.bedtime_outlined),
                              ),
                            ],
                            selected: <String>{view},
                            onSelectionChanged: (Set<String> s) =>
                                go(v: s.first),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      96,
                    ),
                    children: <Widget>[
                      if (!canEdit) ...<Widget>[
                        DemoNotice(
                          icon: Icons.family_restroom_rounded,
                          color: const Color(0xFF0B6B8A),
                          text:
                              'Informado pela família. Calendário e diário '
                              'registrados por ${p.guardianName} no app, com '
                              'autorização de compartilhamento. Somente leitura: '
                              'não entram no prontuário sem o seu registro.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (view == 'calendario')
                        _CalendarView(
                          patient: p,
                          mode: mode,
                          day: day,
                          canEdit: canEdit,
                          go: go,
                          onFilter: () => setState(() {}),
                        )
                      else if (view == 'sono')
                        DemoSleepView(
                          patient: p,
                          day: day,
                          canEdit: canEdit,
                          consultationId: widget.consultationId,
                          onDay: (DateTime d) => go(d: d),
                        )
                      else
                        _DiaryView(
                          patient: p,
                          day: day,
                          canEdit: canEdit,
                          go: go,
                          onFilter: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Profissional sem autorização da família, ou criança de outra família.
class DemoRoutineUnavailableScreen extends StatelessWidget {
  const DemoRoutineUnavailableScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.patientById(patientId);
    final bool professional = demoSession.profile == DemoProfile.profissional;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go(
            p != null && professional ? '/pacientes/${p.id}' : '/inicio',
          ),
        ),
        title: const Text('Rotina da criança'),
      ),
      body: DemoEmpty(
        title: p == null
            ? 'Criança não encontrada'
            : 'Rotina não compartilhada',
        message: p == null
            ? 'Esta criança não está vinculada ao seu perfil.'
            : 'A família de ${p.name} ainda não autorizou o compartilhamento '
                  'da rotina com a clínica.',
      ),
    );
  }
}

typedef _Go = void Function({String? v, String? m, DateTime? d});

// ---------------------------------------------------------------------------
// Calendário
// ---------------------------------------------------------------------------

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.patient,
    required this.mode,
    required this.day,
    required this.canEdit,
    required this.go,
    required this.onFilter,
  });

  final DemoPatient patient;
  final String mode;
  final DateTime day;
  final bool canEdit;
  final _Go go;
  final VoidCallback onFilter;

  bool _passes(CalendarItem i) =>
      demoSession.routineKindFilter.isEmpty ||
      demoSession.routineKindFilter.contains(i.kind);

  @override
  Widget build(BuildContext context) {
    final DateTime today = dayOf(demoSession.now);
    final String label;
    final DateTime prev;
    final DateTime next;
    switch (mode) {
      case 'dia':
        label =
            '${sameDay(day, today) ? 'Hoje, ' : ''}${_cap(formatDayLong(day))}';
        prev = addDays(day, -1);
        next = addDays(day, 1);
      case 'semana':
        final DateTime ws = weekStart(day);
        label = 'Semana de ${formatDm(ws)} a ${formatDm(addDays(ws, 6))}';
        prev = addDays(day, -7);
        next = addDays(day, 7);
      default:
        label = '${_cap(kMonthNames[day.month - 1])} de ${day.year}';
        prev = DateTime(day.year, day.month - 1);
        next = DateTime(day.year, day.month + 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          container: true,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'dia', label: Text('Dia')),
              ButtonSegment<String>(value: 'semana', label: Text('Semana')),
              ButtonSegment<String>(value: 'mes', label: Text('Mês')),
            ],
            selected: <String>{mode},
            onSelectionChanged: (Set<String> s) => go(m: s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        RoutinePeriodBar(
          label: label,
          onPrev: () => go(d: prev),
          onNext: () => go(d: next),
          onToday: () => go(d: today),
        ),
        _KindFilters(onChanged: onFilter),
        const SizedBox(height: AppSpacing.sm),
        const RoutineLegend(),
        const SizedBox(height: AppSpacing.md),
        switch (mode) {
          'dia' => _DayPanel(
            patient: patient,
            day: day,
            canEdit: canEdit,
            go: go,
            passes: _passes,
          ),
          'semana' => _WeekList(
            patient: patient,
            day: day,
            go: go,
            passes: _passes,
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _MonthGrid(
                patient: patient,
                selected: day,
                passes: _passes,
                onTap: (DateTime d) => go(d: d),
              ),
              _DayPanel(
                patient: patient,
                day: day,
                canEdit: canEdit,
                go: go,
                passes: _passes,
              ),
            ],
          ),
        },
        _ClinicLinks(patient: patient, canEdit: canEdit),
      ],
    );
  }
}

class _KindFilters extends StatelessWidget {
  const _KindFilters({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Set<RoutineKind> f = demoSession.routineKindFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Todos'),
              selected: f.isEmpty,
              onSelected: (_) {
                f.clear();
                onChanged();
              },
            ),
          ),
          for (final RoutineKind k in RoutineKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(
                  routineKindIcon(k),
                  size: 16,
                  color: routineKindColor(k),
                ),
                label: Text(k.label),
                selected: f.contains(k),
                onSelected: (bool v) {
                  v ? f.add(k) : f.remove(k);
                  onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.patient,
    required this.selected,
    required this.passes,
    required this.onTap,
  });

  final DemoPatient patient;
  final DateTime selected;
  final bool Function(CalendarItem) passes;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime first = monthStart(selected);
    final DateTime gridStart = weekStart(first);
    final DateTime gridEnd = addDays(gridStart, 42);
    final DateTime today = dayOf(demoSession.now);
    final Map<String, List<CalendarItem>> items =
        <String, List<CalendarItem>>{};
    for (final CalendarItem i in demoSession.routineItems(
      patient.id,
      gridStart,
      gridEnd,
    )) {
      if (!passes(i)) continue;
      (items[routineDateKey(i.start)] ??= <CalendarItem>[]).add(i);
    }
    final Map<String, int> diary = <String, int>{};
    for (final DiaryEntry e in demoSession.diaryFor(patient.id)) {
      final String k = routineDateKey(e.at);
      diary[k] = (diary[k] ?? 0) + 1;
    }
    final TextTheme t = Theme.of(context).textTheme;

    Widget cell(DateTime d) {
      final String key = routineDateKey(d);
      final List<CalendarItem> list = items[key] ?? const <CalendarItem>[];
      final int n = diary[key] ?? 0;
      final bool inMonth = d.month == first.month;
      final bool isSel = sameDay(d, selected);
      final bool isToday = sameDay(d, today);
      final Color fg = isSel
          ? Colors.white
          : inMonth
          ? AppColors.navy
          : const Color(0xFF7B8798);
      return Expanded(
        child: Semantics(
          button: true,
          selected: isSel,
          excludeSemantics: true,
          label:
              '${d.day} de ${kMonthNames[d.month - 1]}'
              '${isToday ? ', hoje' : ''}: ${list.length} compromisso(s), '
              '$n registro(s) no diário',
          onTap: () => onTap(d),
          child: InkWell(
            onTap: () => onTap(d),
            borderRadius: AppRadius.smAll,
            child: Container(
              height: 54,
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: isSel ? AppColors.brand : Colors.white,
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: isToday && !isSel ? AppColors.brand : AppColors.line,
                  width: isToday && !isSel ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${d.day}',
                    style: t.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: isToday || isSel
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (final CalendarItem i in list.take(3))
                        _Dot(item: i, onBrand: isSel),
                      if (list.length > 3)
                        Text(
                          '+',
                          style: t.labelSmall?.copyWith(color: fg, height: 1),
                        ),
                    ],
                  ),
                  if (n > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : AppColors.tealDeep,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String w in kWeekdayShort)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: t.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (int r = 0; r < 6; r++)
          Row(
            children: <Widget>[
              for (int c = 0; c < 7; c++) cell(addDays(gridStart, r * 7 + c)),
            ],
          ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Container(
              width: 16,
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.tealDeep,
                borderRadius: AppRadius.pillAll,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'dia com registros no diário',
                style: t.labelSmall?.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.item, required this.onBrand});

  final CalendarItem item;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final Color c = onBrand ? Colors.white : routineKindColor(item.kind);
    final bool done = item.status == RoutineStatus.done;
    final bool cancelled = item.status == RoutineStatus.cancelled;
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? c
            : cancelled
            ? const Color(0xFFB8C0CC)
            : Colors.transparent,
        border: Border.all(
          color: cancelled ? const Color(0xFFB8C0CC) : c,
          width: 1.6,
        ),
      ),
    );
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({
    required this.patient,
    required this.day,
    required this.go,
    required this.passes,
  });

  final DemoPatient patient;
  final DateTime day;
  final _Go go;
  final bool Function(CalendarItem) passes;

  @override
  Widget build(BuildContext context) {
    final DateTime ws = weekStart(day);
    final DateTime today = dayOf(demoSession.now);
    final List<CalendarItem> all = demoSession
        .routineItems(patient.id, ws, addDays(ws, 7))
        .where(passes)
        .toList();
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Builder(
            builder: (BuildContext context) {
              final DateTime d = addDays(ws, i);
              final List<CalendarItem> list = all
                  .where((CalendarItem x) => sameDay(x.start, d))
                  .toList();
              final int n = demoSession.diaryFor(patient.id, day: d).length;
              final bool isToday = sameDay(d, today);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    InkWell(
                      onTap: () => go(m: 'dia', d: d),
                      borderRadius: AppRadius.smAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${_cap(kWeekdayShort[d.weekday - 1])}, '
                                '${formatDm(d)}${isToday ? ' (hoje)' : ''}',
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSmall?.copyWith(
                                  color: isToday
                                      ? AppColors.brand
                                      : AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              n == 0 ? 'sem diário' : '$n no diário',
                              style: t.labelSmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Nada planejado',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      )
                    else
                      for (final CalendarItem x in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RoutineItemTile(
                            item: x,
                            onTap: () => showRoutineItemSheet(context, x),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Compromissos e linha do tempo do diário de um dia.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.patient,
    required this.day,
    required this.canEdit,
    required this.go,
    required this.passes,
  });

  final DemoPatient patient;
  final DateTime day;
  final bool canEdit;
  final _Go go;
  final bool Function(CalendarItem) passes;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<CalendarItem> items = demoSession
        .routineItemsOn(patient.id, day)
        .where(passes)
        .toList();
    final List<DiaryEntry> diary = demoSession.diaryFor(patient.id, day: day);
    final bool future = day.isAfter(dayOf(demoSession.now));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DemoSectionTitle('Compromissos - ${formatDm(day)}'),
        if (items.isEmpty)
          Text(
            'Nenhum compromisso neste dia.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          )
        else
          for (final CalendarItem i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RoutineItemTile(
                item: i,
                onTap: () => showRoutineItemSheet(context, i),
              ),
            ),
        DemoSectionTitle(
          'Diário do dia',
          trailing: TextButton.icon(
            onPressed: () => go(v: 'diario', d: day),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Abrir no diário'),
          ),
        ),
        if (diary.isEmpty)
          Text(
            future
                ? 'O diário recebe registros até hoje.'
                : 'Nada registrado no diário neste dia.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: <Widget>[
                for (final DiaryEntry e in diary)
                  DiaryEntryTile(
                    entry: e,
                    onTap: () =>
                        context.go('/rotina/${patient.id}/registro/${e.id}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vacinas pendentes da carteira e itens de receitas emitidas: vêm dos
/// cadastros da clínica, sem cópia.
class _ClinicLinks extends StatelessWidget {
  const _ClinicLinks({required this.patient, required this.canEdit});

  final DemoPatient patient;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<PendingVaccine> vaccines = demoSession.pendingVaccines(
      patient.id,
    );
    final List<PrescribedItem> meds = demoSession.prescribedItems(patient.id);
    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (vaccines.isNotEmpty) ...<Widget>[
          const DemoSectionTitle('Vacinas pendentes na carteira'),
          card(<Widget>[
            for (final PendingVaccine v in vaccines)
              _LinkRow(
                icon: routineKindIcon(RoutineKind.vacina),
                color: routineKindColor(RoutineKind.vacina),
                title: '${v.record.name} - ${v.record.dose}',
                subtitle: v.scheduled == null
                    ? 'Sem data definida'
                    : 'Agendada pela família: ${v.scheduled!.whenLabel}',
                action: v.scheduled == null
                    ? (canEdit
                          ? FilledButton.tonal(
                              onPressed: () => context.go(
                                '/rotina/${patient.id}/evento/novo'
                                '?vacina=${Uri.encodeComponent(v.record.name)}'
                                '&dose=${Uri.encodeComponent(v.record.dose)}',
                              ),
                              child: const Text('Agendar'),
                            )
                          : null)
                    : TextButton(
                        onPressed: () => context.go(
                          routineUrl(
                            patient.id,
                            mode: 'dia',
                            day: v.scheduled!.start,
                          ),
                        ),
                        child: const Text('Ver'),
                      ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'A carteira continua sendo atualizada pelo registro da unidade '
              'de saúde ou da clínica.',
              style: t.labelSmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
        if (meds.isNotEmpty) ...<Widget>[
          const DemoSectionTitle('Medicamentos prescritos'),
          card(<Widget>[
            for (final PrescribedItem m in meds)
              _LinkRow(
                icon: routineKindIcon(RoutineKind.medicamento),
                color: routineKindColor(RoutineKind.medicamento),
                title: m.item.drug,
                subtitle:
                    '${m.item.posology}\nReceita de ${formatDm(m.issuedAt)}'
                    '${m.plan == null ? ' - horários não programados' : ' - ${m.plan!.givenCount} de ${m.plan!.doseCount} doses registradas'}',
                action: m.plan == null && canEdit
                    ? FilledButton.tonal(
                        onPressed: () => context.go(
                          '/rotina/${patient.id}/medicamento/${m.doc.id}/${m.index}',
                        ),
                        child: const Text('Programar'),
                      )
                    : TextButton(
                        onPressed: () => context.go(
                          '/rotina/${patient.id}/medicamento/${m.doc.id}/${m.index}',
                        ),
                        child: const Text('Horários'),
                      ),
              ),
          ]),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: t.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diário
// ---------------------------------------------------------------------------

class _DiaryView extends StatelessWidget {
  const _DiaryView({
    required this.patient,
    required this.day,
    required this.canEdit,
    required this.go,
    required this.onFilter,
  });

  final DemoPatient patient;
  final DateTime day;
  final bool canEdit;
  final _Go go;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DateTime today = dayOf(demoSession.now);
    final bool isToday = sameDay(day, today);
    final bool future = day.isAfter(today);
    final DiaryEntry? sleeping = demoSession.openSleep(patient.id);
    final Set<DiaryKind> filter = demoSession.diaryKindFilter;
    final List<DiaryEntry> dayAll = demoSession.diaryFor(patient.id, day: day);
    final List<DiaryEntry> entries = demoSession.diaryFor(
      patient.id,
      day: day,
      kinds: filter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RoutinePeriodBar(
          label: '${isToday ? 'Hoje, ' : ''}${_cap(formatDayLong(day))}',
          prevLabel: 'Dia anterior',
          nextLabel: 'Próximo dia',
          onPrev: () => go(d: addDays(day, -1)),
          onNext: day.isBefore(today) ? () => go(d: addDays(day, 1)) : null,
          onToday: isToday ? null : () => go(d: today),
        ),
        if (sleeping != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAFF),
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: const Color(0xFF5B3FD6)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.bedtime_rounded, color: Color(0xFF5B3FD6)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Dormindo desde ${formatHm(sleeping.at)}'
                    '${sameDay(sleeping.at, demoSession.now) ? '' : ' de ${formatDm(sleeping.at)}'}',
                    style: t.titleSmall?.copyWith(
                      color: const Color(0xFF3A2596),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canEdit)
                  FilledButton(
                    onPressed: () {
                      demoSession.replaceDiaryEntry(
                        sleeping.finishedSleep(
                          end: demoSession.now,
                          author: demoSession.routineAuthor,
                          at: demoSession.now,
                        ),
                      );
                      showDemoSnack(
                        context,
                        'Sono registrado até ${formatHm(demoSession.now)}.',
                      );
                    },
                    child: const Text('Acordou'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (canEdit && !future) ...<Widget>[
          Text(
            isToday ? 'Registrar agora' : 'Registrar em ${formatDm(day)}',
            style: t.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int cols = c.maxWidth >= 600 ? 5 : 3;
              final double w = (c.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final DiaryKind k in DiaryKind.values)
                    SizedBox(
                      width: w,
                      child: _QuickButton(
                        kind: k,
                        onTap: () =>
                            showDiarySheet(context, patient.id, k, day: day),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        if (future)
          Text(
            'O diário recebe registros até hoje. Use o calendário para '
            'planejar.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('Todos (${dayAll.length})'),
                  selected: filter.isEmpty,
                  onSelected: (_) {
                    filter.clear();
                    onFilter();
                  },
                ),
              ),
              for (final DiaryKind k in DiaryKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      diaryKindIcon(k),
                      size: 16,
                      color: diaryKindColor(k),
                    ),
                    label: Text(
                      '${k.label} (${dayAll.where((DiaryEntry e) => e.kind == k).length})',
                    ),
                    selected: filter.contains(k),
                    onSelected: (bool v) {
                      v ? filter.add(k) : filter.remove(k);
                      onFilter();
                    },
                  ),
                ),
            ],
          ),
        ),
        DemoSectionTitle(
          'Linha do tempo',
          trailing: Text(
            '${entries.length} registro(s)',
            style: t.labelMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        if (entries.isEmpty)
          Text(
            dayAll.isEmpty
                ? 'Nada registrado neste dia.'
                : 'Nenhum registro deste tipo neste dia.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: <Widget>[
                for (final DiaryEntry e in entries)
                  DiaryEntryTile(
                    entry: e,
                    onTap: () =>
                        context.go('/rotina/${patient.id}/registro/${e.id}'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => go(v: 'calendario', m: 'dia', d: day),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Ver compromissos deste dia'),
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.kind, required this.onTap});

  final DiaryKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color c = diaryKindColor(kind);
    return Semantics(
      button: true,
      label: 'Registrar ${kind.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: c.withValues(alpha: 0.45)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(diaryKindIcon(kind), color: c, size: 28),
                const SizedBox(height: 4),
                Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
