import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/child_avatar.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/patient_notes.dart';
import '../../shared/scheduling/agenda_conflicts.dart';
import '../../shared/scheduling/agenda_range.dart';
import '../../shared/scheduling/slots.dart' show WorkingHours;
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_scheduling.dart';
import '../demo_session.dart';
import '../demo_workspace.dart';
import '../widgets/demo_widgets.dart';
import 'booking_assistant_screens.dart' show bookingPath;
import 'followup_screens.dart';
import 'home_screen.dart' show DemoStatusChip;
import 'pre_visit_screens.dart';
import 'restricted_screen.dart';

DemoPatient? _patient(String id) =>
    demoSession.patients.where((DemoPatient p) => p.id == id).firstOrNull;

bool _isReturn(DemoAppointment a) =>
    (a.typeLabel ?? '').toLowerCase().startsWith('retorno') ||
    a.reason.toLowerCase().startsWith('retorno');

String agendaUrl({AgendaView view = AgendaView.dia, DateTime? day}) {
  final List<String> q = <String>[
    if (view != AgendaView.dia) 'vista=${view.name}',
    if (day != null)
      'dia=${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
  ];
  return q.isEmpty ? '/agenda' : '/agenda?${q.join('&')}';
}

DateTime? _parseDay(String? s) {
  if (s == null) return null;
  final DateTime? d = DateTime.tryParse(s);
  return d == null ? null : dateOnly(d);
}

/// Agenda por dia, semana ou mês, com horários livres, bloqueios, retornos,
/// cancelamentos e pedidos de reagendamento.
class DemoAgendaScreen extends StatefulWidget {
  const DemoAgendaScreen({super.key, this.view, this.day});

  /// `vista` e `dia` da URL.
  final String? view;
  final String? day;

  @override
  State<DemoAgendaScreen> createState() => _DemoAgendaScreenState();
}

class _DemoAgendaScreenState extends State<DemoAgendaScreen> {
  late AgendaView _view = AgendaView.fromSlug(widget.view);
  late DateTime _anchor = _parseDay(widget.day) ?? dateOnly(demoSession.now);
  bool _showFree = true;
  bool _showCancelled = true;

  /// Recepção escolhe o profissional; `null` = todos.
  String? _professional;

  @override
  void didUpdateWidget(DemoAgendaScreen old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view || old.day != widget.day) {
      _view = AgendaView.fromSlug(widget.view);
      _anchor = _parseDay(widget.day) ?? dateOnly(demoSession.now);
    }
  }

  /// Visão e data ficam na URL: voltar de um horário mantém a visão.
  void _show(AgendaView view, DateTime anchor) {
    setState(() {
      _view = view;
      _anchor = dateOnly(anchor);
    });
    final bool today = DateUtils.isSameDay(anchor, demoSession.now);
    context.go(agendaUrl(view: view, day: today ? null : anchor));
  }

  bool get _own => demoSession.profile == DemoProfile.profissional;

  /// Profissional vê a própria agenda; recepção, a escolhida.
  String? get _scope => _own ? demoSession.account.id : _professional;

  void _openDay(DateTime d) => _show(AgendaView.dia, d);

  List<DemoAppointment> _appointmentsOn(DateTime day) =>
      demoSession.appointments
          .where(
            (DemoAppointment a) =>
                DateUtils.isSameDay(a.start, day) &&
                (_scope == null || a.professionalId == _scope) &&
                (_showCancelled || a.status != DemoAppointmentStatus.cancelado),
          )
          .toList()
        ..sort(
          (DemoAppointment a, DemoAppointment b) => a.start.compareTo(b.start),
        );

  List<ScheduleBlock> _blocksOn(DateTime day) {
    if (_scope == null) return const <ScheduleBlock>[];
    return demoSession.scheduling.blocks
        .where(
          (ScheduleBlock b) =>
              b.professionalId == _scope &&
              DateUtils.isSameDay(b.startsAt, day),
        )
        .toList();
  }

  List<TimeSpan> _freeOn(DateTime day) {
    final String? id = _scope;
    if (id == null || !_showFree) return const <TimeSpan>[];
    final DemoScheduling sched = demoSession.scheduling;
    final WorkingHours? hours = sched.hours[id];
    if (hours == null) return const <TimeSpan>[];
    final List<TimeSpan> busy = <TimeSpan>[
      for (final DemoAppointment a in demoSession.appointments)
        if (a.professionalId == id &&
            a.status.holdsSlot &&
            DateUtils.isSameDay(a.start, day))
          TimeSpan(a.start, a.end),
      for (final ScheduleBlock b in sched.blocks)
        if (b.professionalId == id && DateUtils.isSameDay(b.startsAt, day))
          TimeSpan(b.startsAt, b.endsAt),
    ];
    return freeSpans(
      day: day,
      ranges: hours.on(day),
      busy: busy,
      notBefore: demoSession.now.add(
        Duration(hours: sched.policy.minLeadHours),
      ),
      minMinutes: sched.policy.slotStepMinutes,
    );
  }

  int _freeCount(DateTime day) => freeSlotCount(
    _freeOn(day),
    demoSession.scheduling.policy.slotStepMinutes,
  );

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Agenda'),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          if (demoSession.workspace.canUseDiary)
            TextButton.icon(
              onPressed: () => context.go('/diario'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Diário'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => demoSession.scheduling.canManageAgenda
            ? context.go(bookingPath)
            : showDemoSnack(
                context,
                'Novos agendamentos são feitos pela recepção ou pela família.',
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agendar'),
      ),
      body: DemoLoader(
        label: 'Carregando agenda...',
        builder: (BuildContext context) => ListenableBuilder(
          listenable: demoSession,
          builder: (BuildContext context, _) {
            final bool isToday =
                DateUtils.isSameDay(_anchor, demoSession.now) &&
                _view == AgendaView.dia;
            return DemoContent(
              maxWidth: _view == AgendaView.dia ? 760 : 1200,
              child: ListView(
                key: const ValueKey<String>('agenda-lista'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  96,
                ),
                children: <Widget>[
                  Center(
                    child: SegmentedButton<AgendaView>(
                      segments: <ButtonSegment<AgendaView>>[
                        for (final AgendaView v in AgendaView.values)
                          ButtonSegment<AgendaView>(
                            value: v,
                            label: Text(v.label),
                          ),
                      ],
                      selected: <AgendaView>{_view},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<AgendaView> s) =>
                          _show(s.first, _anchor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: _view.previousLabel,
                        onPressed: () =>
                            _show(_view, shiftAnchor(_view, _anchor, -1)),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          isToday
                              ? 'Hoje, ${demoDate(_anchor)}'
                              : agendaTitle(_view, _anchor),
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _view.nextLabel,
                        onPressed: () =>
                            _show(_view, shiftAnchor(_view, _anchor, 1)),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  if (!DateUtils.isSameDay(_anchor, demoSession.now) ||
                      _view != AgendaView.dia)
                    Center(
                      child: TextButton(
                        onPressed: () => _show(AgendaView.dia, demoSession.now),
                        child: const Text('Voltar para hoje'),
                      ),
                    ),
                  _filters(),
                  const SizedBox(height: AppSpacing.sm),
                  const _Legend(),
                  const SizedBox(height: AppSpacing.md),
                  ...switch (_view) {
                    AgendaView.dia => _dayView(context),
                    AgendaView.semana => <Widget>[_weekView(context)],
                    AgendaView.mes => <Widget>[_monthView(context)],
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filters() => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      if (!_own) ...<Widget>[
        ChoiceChip(
          label: const Text('Todos os profissionais'),
          selected: _professional == null,
          onSelected: (_) => setState(() => _professional = null),
        ),
        for (final DemoAccount acc in DemoProfessional.accounts)
          ChoiceChip(
            label: Text(acc.name),
            selected: _professional == acc.id,
            onSelected: (_) => setState(() => _professional = acc.id),
          ),
      ],
      FilterChip(
        label: const Text('Horários livres'),
        selected: _showFree,
        onSelected: (bool v) => setState(() => _showFree = v),
      ),
      FilterChip(
        label: const Text('Cancelados'),
        selected: _showCancelled,
        onSelected: (bool v) => setState(() => _showCancelled = v),
      ),
      if (_scope == null)
        const Text(
          'Escolha um profissional para ver horários livres e bloqueios.',
        ),
    ],
  );

  List<Widget> _dayView(BuildContext context) {
    final List<DemoAppointment> list = _appointmentsOn(_anchor);
    final List<ScheduleBlock> blocks = _blocksOn(_anchor);
    final List<TimeSpan> free = _freeOn(_anchor);
    final List<(DateTime, Widget)> items =
        <(DateTime, Widget)>[
          for (final DemoAppointment a in list)
            (a.start, _AppointmentTile(appointment: a)),
          for (final ScheduleBlock b in blocks)
            (b.startsAt, _BlockTile(block: b)),
          for (final TimeSpan s in free) (s.start, _FreeTile(span: s)),
        ]..sort(
          ((DateTime, Widget) a, (DateTime, Widget) b) => a.$1.compareTo(b.$1),
        );
    if (items.isEmpty) {
      return const <Widget>[
        DemoEmpty(
          title: 'Dia livre',
          message: 'Nenhum atendimento neste dia.',
          pose: CapiPose.celebracao,
        ),
      ];
    }
    return <Widget>[
      for (final (DateTime, Widget) i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: i.$2,
        ),
    ];
  }

  Widget _weekView(BuildContext context) {
    final DateTime start = startOfWeek(_anchor);
    final List<DateTime> days = <DateTime>[
      for (int i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    Widget column(DateTime d) {
      final List<DemoAppointment> list = _appointmentsOn(d);
      final int free = _freeCount(d);
      final bool blocked = _blocksOn(d).isNotEmpty;
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: () => _openDay(d),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              button: true,
              label:
                  'Abrir ${weekdayShort[d.weekday - 1]}, ${demoDate(d)}: '
                  '${list.length} consulta(s)',
              child: ExcludeSemantics(
                child: Text(
                  '${weekdayShort[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: DateUtils.isSameDay(d, demoSession.now)
                        ? AppColors.brand
                        : AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final DemoAppointment a in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _MiniAppointment(appointment: a),
              ),
            if (list.isEmpty)
              Text(
                'Sem consultas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (blocked)
              Text(
                'Bloqueio na agenda',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            if (_showFree && _scope != null && free > 0)
              Text(
                '$free horário(s) livre(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) => c.maxWidth >= 960
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final DateTime d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: column(d),
                    ),
                  ),
              ],
            )
          : Column(
              children: <Widget>[
                for (final DateTime d in days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: column(d),
                  ),
              ],
            ),
    );
  }

  Widget _monthView(BuildContext context) {
    final List<DateTime> grid = monthGrid(_anchor);
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String w in weekdayShort)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: t.labelMedium?.copyWith(color: AppColors.inkMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (int row = 0; row < 6; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < 7; col++)
                Expanded(child: _monthCell(context, grid[row * 7 + col])),
            ],
          ),
      ],
    );
  }

  Widget _monthCell(BuildContext context, DateTime d) {
    final bool inMonth = d.month == _anchor.month;
    final List<DemoAppointment> list = _appointmentsOn(d);
    final int active = list
        .where(
          (DemoAppointment a) => a.status != DemoAppointmentStatus.cancelado,
        )
        .length;
    final int cancelled = list.length - active;
    final bool reschedule = list.any(
      (DemoAppointment a) => a.status == DemoAppointmentStatus.reagendar,
    );
    final int free = inMonth ? _freeCount(d) : 0;
    final bool today = DateUtils.isSameDay(d, demoSession.now);
    final TextTheme t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          '${demoDate(d)}: $active consulta(s)'
          '${cancelled > 0 ? ', $cancelled cancelada(s)' : ''}'
          '${reschedule ? ', pedido de reagendamento' : ''}'
          '${free > 0 ? ', $free livre(s)' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _openDay(d),
          child: Container(
            height: 76,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: inMonth ? Colors.white : AppColors.lightBackground,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: today ? AppColors.brand : AppColors.line,
                width: today ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${d.day}',
                  style: t.labelLarge?.copyWith(
                    color: inMonth ? AppColors.navy : AppColors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (active > 0)
                  Text(
                    '$active consulta${active == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall?.copyWith(color: AppColors.brand),
                  ),
                Row(
                  children: <Widget>[
                    if (cancelled > 0) const _Dot(AppColors.danger),
                    if (reschedule) const _Dot(AppColors.raspberry),
                    if (free > 0) const _Dot(AppColors.success),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    margin: const EdgeInsets.only(right: 3, top: 2),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Dot(c),
        const SizedBox(width: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      children: <Widget>[
        item(AppColors.brand, 'Confirmada'),
        item(AppColors.inkMuted, 'Agendada'),
        item(AppColors.tealDeep, 'Retorno'),
        item(AppColors.raspberry, 'Pede reagendamento'),
        item(AppColors.danger, 'Cancelada'),
        item(AppColors.badgeBronze, 'Falta'),
        item(AppColors.success, 'Horário livre'),
      ],
    );
  }
}

class _MiniAppointment extends StatelessWidget {
  const _MiniAppointment({required this.appointment});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final DemoAppointment a = appointment;
    final String name =
        _patient(a.patientId)?.name.split(' ').first ?? 'Paciente';
    final String status = DemoWorkspace.statusLabel(a.status);
    final bool cancelled = a.status == DemoAppointmentStatus.cancelado;
    return InkWell(
      onTap: () => context.go('/agenda/${a.id}'),
      child: Semantics(
        button: true,
        label:
            '${demoTime(a.start)} $name - $status'
            '${_isReturn(a) ? ' - retorno' : ''}',
        child: ExcludeSemantics(
          child: Text(
            '${demoTime(a.start)} $name${_isReturn(a) ? ' (retorno)' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cancelled ? AppColors.danger : AppColors.navy,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final DemoAppointment a = appointment;
    final DemoPatient? p = _patient(a.patientId);
    final TextTheme t = Theme.of(context).textTheme;
    final bool cancelled = a.status == DemoAppointmentStatus.cancelado;
    return Opacity(
      opacity: cancelled ? 0.7 : 1,
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.go('/agenda/${a.id}'),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    demoTime(a.start),
                    style: t.titleMedium?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('${a.durationMinutes} min', style: t.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p?.name ?? 'Paciente',
                    style: t.titleSmall?.copyWith(
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Icon(
                        a.kind == DemoAppointmentKind.teleconsulta
                            ? Icons.videocam_outlined
                            : Icons.place_outlined,
                        size: 14,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          a.reason,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (_isReturn(a))
                    Text(
                      'Retorno',
                      style: t.labelSmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            DemoStatusChip(status: a.status),
          ],
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block});

  final ScheduleBlock block;

  @override
  Widget build(BuildContext context) => DemoNotice(
    icon: Icons.block_rounded,
    color: AppColors.inkMuted,
    text:
        'Bloqueio ${demoTime(block.startsAt)} às ${demoTime(block.endsAt)}: '
        '${block.reason}',
  );
}

class _FreeTile extends StatelessWidget {
  const _FreeTile({required this.span});

  final TimeSpan span;

  @override
  Widget build(BuildContext context) {
    final int step = demoSession.scheduling.policy.slotStepMinutes;
    final int n = span.minutes ~/ step;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.softMint,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.event_available_rounded, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Horário livre ${demoTime(span.start)} às ${demoTime(span.end)} '
              '($n horário${n == 1 ? '' : 's'} de $step min)',
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalhe do agendamento: dados essenciais, pré-consulta, consulta
/// vinculada e status (só em memória).
class DemoAppointmentDetailScreen extends StatelessWidget {
  const DemoAppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoAppointment? a = demoSession.appointments
            .where((DemoAppointment x) => x.id == appointmentId)
            .firstOrNull;
        if (a == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agendamento')),
            body: DemoEmpty(
              title: 'Agendamento não encontrado',
              message: 'Volte para a agenda.',
              actionLabel: 'Agenda',
              onAction: () => context.go('/agenda'),
            ),
          );
        }
        final DemoWorkspace ws = demoSession.workspace;
        if (!ws.canOpenAppointment(a)) {
          return const DemoRestrictedScreen(
            module: DemoModule.agenda,
            title: 'Agendamento',
            reason:
                'Este horário é de outro profissional. Cada profissional vê '
                'só a própria agenda.',
          );
        }
        final DemoPatient? p = _patient(a.patientId);
        final bool isReception = demoSession.profile == DemoProfile.recepcao;
        final bool clinical = !isReception && demoSession.canSeeClinicalRecord;
        final bool past = !a.start.isAfter(demoSession.now);
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/agenda')),
            title: const Text('Agendamento'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (p != null)
                                ChildAvatarImage(
                                  name: p.name,
                                  seed: p.id,
                                  photoUrl: p.avatarAsset == null
                                      ? null
                                      : ChildAvatarRef.encode(p.avatarAsset!),
                                ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  p?.name ?? 'Paciente',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              DemoStatusChip(status: a.status),
                            ],
                          ),
                          const Divider(height: AppSpacing.xl),
                          _Info(
                            Icons.event_outlined,
                            '${demoDate(a.start)} às ${demoTime(a.start)}',
                          ),
                          _Info(
                            a.kind == DemoAppointmentKind.teleconsulta
                                ? Icons.videocam_outlined
                                : Icons.place_outlined,
                            a.kind == DemoAppointmentKind.teleconsulta
                                ? 'Teleconsulta (protótipo, vídeo indisponível)'
                                : 'Presencial',
                          ),
                          _Info(
                            Icons.notes_rounded,
                            _isReturn(a) ? '${a.reason} - retorno' : a.reason,
                          ),
                          _Info(
                            Icons.person_outline,
                            '${DemoScheduling.professionalName(a.professionalId)} '
                            '- ${a.durationMinutes} min',
                          ),
                        ],
                      ),
                    ),
                    if (a.status == DemoAppointmentStatus.reagendar)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: DemoNotice(
                          icon: Icons.event_repeat_rounded,
                          color: AppColors.raspberry,
                          text:
                              'A família pediu outro horário. O horário '
                              'atual continua reservado até a remarcação.',
                        ),
                      ),
                    if (clinical && p != null) ...<Widget>[
                      _EssentialData(patient: p),
                      _VisitActions(appointment: a, patient: p),
                    ],
                    if (a.status.holdsSlot &&
                        ws.canSetAppointmentStatus) ...<Widget>[
                      const DemoSectionTitle('Atualizar status'),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final DemoAppointmentStatus s
                              in DemoAppointmentStatus.manual)
                            if (s != DemoAppointmentStatus.falta || past)
                              ChoiceChip(
                                label: Text(DemoWorkspace.statusLabel(s)),
                                selected: a.status == s,
                                onSelected: (_) {
                                  demoSession.setAppointmentStatus(a, s);
                                  showDemoSnack(
                                    context,
                                    'Status alterado só nesta demonstração.',
                                  );
                                },
                              ),
                        ],
                      ),
                    ],
                    DemoAppointmentActions(appointment: a),
                    const SizedBox(height: AppSpacing.lg),
                    DemoPreVisitAppointmentInfo(appointment: a),
                    if (isReception)
                      const DemoNotice(
                        icon: Icons.shield_outlined,
                        text:
                            'A recepção registra chegada, mas não abre o '
                            'prontuario.',
                      ),
                    DemoAppointmentReminders(appointment: a),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// O que o profissional precisa ver ao abrir o horário.
class _EssentialData extends StatelessWidget {
  const _EssentialData({required this.patient});

  final DemoPatient patient;

  @override
  Widget build(BuildContext context) {
    final DemoPatient p = patient;
    final DemoConsultation? last = demoSession
        .consultationsFor(p.id)
        .where((DemoConsultation c) => !c.isDraft)
        .firstOrNull;
    final (DateTime, String)? ret =
        demoSession.scheduling.recommendedReturns[p.id];
    final List<PatientNote> internal = demoSession.workspace
        .notesFor(p.id)
        .where((PatientNote n) => n.visibility == NoteVisibility.interna)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dados essenciais',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Info(Icons.cake_outlined, '${p.ageLabel} - ${p.sexLabel}'),
            _Info(
              Icons.family_restroom_outlined,
              'Responsável: ${p.guardianName}',
            ),
            _Info(
              Icons.warning_amber_rounded,
              p.allergies.isEmpty
                  ? 'Nenhuma alergia registrada'
                  : 'Alergias: ${p.allergies.join(', ')}',
            ),
            _Info(
              Icons.monitor_weight_outlined,
              p.weightKg == null
                  ? 'Sem peso registrado'
                  : 'Último peso: ${p.weightKg!.toStringAsFixed(1).replaceAll('.', ',')} kg'
                        '${p.weighedAt == null ? '' : ' em ${demoDate(p.weighedAt!)}'}',
            ),
            _Info(
              Icons.history_rounded,
              last == null
                  ? 'Sem consulta finalizada'
                  : 'Última consulta: ${demoDate(last.startedAt)}',
            ),
            if (ret != null)
              _Info(
                Icons.event_repeat_outlined,
                'Retorno recomendado: ${demoDate(ret.$1)}',
              ),
            if (internal.isNotEmpty)
              _Info(
                Icons.lock_outline_rounded,
                'Observação interna: ${internal.first.text}',
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitActions extends StatelessWidget {
  const _VisitActions({required this.appointment, required this.patient});

  final DemoAppointment appointment;
  final DemoPatient patient;

  @override
  Widget build(BuildContext context) {
    final DemoAppointment a = appointment;
    final DemoWorkspace ws = demoSession.workspace;
    final DemoConsultation? c = ws.consultationForAppointment(a.id);
    final bool startable =
        a.status.holdsSlot &&
        a.status != DemoAppointmentStatus.falta &&
        demoSession.canUseClinicalTools;
    final String base = '/pacientes/${patient.id}';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          if (c == null && startable)
            FilledButton.icon(
              onPressed: () {
                final DemoConsultation started = ws.startVisit(a);
                context.go('$base/consulta/${started.id}');
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar consulta'),
            ),
          if (c != null && c.isDraft)
            FilledButton.icon(
              onPressed: () => context.go('$base/consulta/${c.id}'),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Continuar consulta'),
            ),
          if (c != null)
            OutlinedButton.icon(
              onPressed: () => context.go('$base/consulta/${c.id}/resumo'),
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Resumo da consulta'),
            ),
          OutlinedButton.icon(
            onPressed: () => context.go(base),
            icon: const Icon(Icons.child_care_rounded),
            label: const Text('Ficha do paciente'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('$base/historico'),
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Histórico'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('$base/observacoes'),
            icon: const Icon(Icons.sticky_note_2_outlined),
            label: const Text('Observações'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('$base/prontuario'),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Abrir prontuário'),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
