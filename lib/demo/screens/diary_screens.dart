import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_tasks.dart';
import '../../shared/clinical/visit_diary.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_workspace.dart';
import '../widgets/demo_widgets.dart';

Color outcomeColor(VisitOutcome o) => switch (o) {
  VisitOutcome.realizada => AppColors.success,
  VisitOutcome.pendente => AppColors.warning,
  VisitOutcome.falta => AppColors.danger,
  VisitOutcome.agendada => AppColors.brand,
  VisitOutcome.cancelada => AppColors.inkMuted,
};

String _weekday(DateTime d) => const <String>[
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
][d.weekday - 1];

String taskDueText(ClinicalTask t, DateTime now) {
  final TaskDue d = taskDue(t, now);
  return switch (d) {
    TaskDue.atrasada => 'Atrasada (${demoDate(t.due!)})',
    TaskDue.hoje => 'Para hoje',
    TaskDue.proxima => 'Até ${demoDate(t.due!)}',
    TaskDue.semData => 'Sem data',
    TaskDue.concluida =>
      'Concluída em ${demoDate(t.doneAt!)} por ${t.doneBy ?? '-'}',
  };
}

/// Nova tarefa ou lembrete de acompanhamento. Devolve `true` se salvou.
Future<bool> showTaskDialog(
  BuildContext context, {
  String? patientId,
  String? consultationId,
  TaskKind kind = TaskKind.tarefa,
  String title = '',
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _TaskDialog(
      patientId: patientId,
      consultationId: consultationId,
      kind: kind,
      title: title,
    ),
  );
  return saved ?? false;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({
    required this.patientId,
    required this.consultationId,
    required this.kind,
    required this.title,
  });

  final String? patientId;
  final String? consultationId;
  final TaskKind kind;
  final String title;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  late TaskKind _kind = widget.kind;
  late String? _patient = widget.patientId;
  int? _days = 0;
  String? _error;

  static const List<(String, int?)> _dueOptions = <(String, int?)>[
    ('Hoje', 0),
    ('Amanhã', 1),
    ('Em 7 dias', 7),
    ('Em 30 dias', 30),
    ('Sem data', null),
  ];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final DateTime now = demoSession.now;
    try {
      demoSession.workspace.addTask(
        title: _title.text,
        kind: _kind,
        due: _days == null
            ? null
            : DateTime(now.year, now.month, now.day + _days!),
        patientId: _patient,
        consultationId: _patient == widget.patientId
            ? widget.consultationId
            : null,
      );
      Navigator.of(context).pop(true);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DemoPatient> patients = demoSession.patients;
    return AlertDialog(
      title: const Text('Nova tarefa'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Descrição da tarefa',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final TaskKind k in TaskKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Prazo', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final (String label, int? days) in _dueOptions)
                    ChoiceChip(
                      label: Text(label),
                      selected: _days == days,
                      onSelected: (_) => setState(() => _days = days),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Paciente', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Sem paciente'),
                    selected: _patient == null,
                    onSelected: (_) => setState(() => _patient = null),
                  ),
                  for (final DemoPatient p in patients)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _patient == p.id,
                      onSelected: (_) => setState(() => _patient = p.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar tarefa')),
      ],
    );
  }
}

/// Lista das tarefas abertas e concluídas (opcionalmente de um paciente).
class DemoTaskList extends StatelessWidget {
  const DemoTaskList({super.key, this.patientId});

  final String? patientId;

  @override
  Widget build(BuildContext context) {
    final DemoWorkspace ws = demoSession.workspace;
    final List<ClinicalTask> all = ws.tasksFor(patientId: patientId);
    final List<ClinicalTask> open = all
        .where((ClinicalTask t) => !t.done)
        .toList();
    final List<ClinicalTask> done = all
        .where((ClinicalTask t) => t.done)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DemoSectionTitle(
          'Tarefas e lembretes de acompanhamento',
          trailing: FilledButton.tonalIcon(
            onPressed: () async {
              final bool saved = await showTaskDialog(
                context,
                patientId: patientId,
              );
              if (saved && context.mounted) {
                showDemoSnack(context, 'Tarefa salva.');
              }
            },
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Nova tarefa'),
          ),
        ),
        if (open.isEmpty)
          const DemoNotice(
            icon: Icons.task_alt_rounded,
            color: AppColors.success,
            text: 'Nenhuma tarefa em aberto.',
          ),
        for (final ClinicalTask t in open) _TaskTile(task: t),
        if (done.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Concluídas (${done.length})'),
            children: <Widget>[
              for (final ClinicalTask t in done) _TaskTile(task: t),
            ],
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final ClinicalTask task;

  @override
  Widget build(BuildContext context) {
    final ClinicalTask t = task;
    final DateTime now = demoSession.now;
    final TaskDue due = taskDue(t, now);
    final DemoPatient? p = t.patientId == null
        ? null
        : demoSession.patientById(t.patientId!);
    final Color color = switch (due) {
      TaskDue.atrasada => AppColors.danger,
      TaskDue.hoje => AppColors.warning,
      TaskDue.concluida => AppColors.success,
      _ => AppColors.inkMuted,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CheckboxListTile(
        value: t.done,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (bool? v) {
          demoSession.workspace.setTaskDone(t.id, v ?? false);
          showDemoSnack(
            context,
            (v ?? false) ? 'Tarefa concluída.' : 'Tarefa reaberta.',
          );
        },
        title: Text(
          t.title,
          style: t.done
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(
          <String>[
            t.kind.label,
            taskDueText(t, now),
            if (p != null) p.name,
          ].join(' - '),
          style: TextStyle(color: color),
        ),
        secondary: p == null
            ? null
            : IconButton(
                tooltip: 'Abrir ficha de ${p.name}',
                icon: const Icon(Icons.child_care_rounded),
                onPressed: () => context.go('/pacientes/${p.id}'),
              ),
      ),
    );
  }
}

/// Diário de atendimentos: consultas realizadas, pendentes e faltas, com
/// filtros por período, situação e paciente, e as tarefas do profissional.
class DemoDiaryScreen extends StatefulWidget {
  const DemoDiaryScreen({super.key, this.patientId});

  final String? patientId;

  @override
  State<DemoDiaryScreen> createState() => _DemoDiaryScreenState();
}

class _DemoDiaryScreenState extends State<DemoDiaryScreen> {
  late String? _patient = widget.patientId;
  DiaryPeriod _period = DiaryPeriod.mes;
  VisitOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) _period = DiaryPeriod.tudo;
  }

  List<DemoPatient> _patientsInDiary() {
    final Set<String> ids = demoSession.workspace
        .diary(period: DiaryPeriod.tudo)
        .map((DemoDiaryEntry e) => e.patient.id)
        .toSet();
    return demoSession.patients
        .where((DemoPatient p) => ids.contains(p.id) || p.id == _patient)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoWorkspace ws = demoSession.workspace;
        final List<DemoDiaryEntry> entries = ws.diary(
          period: _period,
          patientId: _patient,
          outcome: _outcome,
        );
        final Map<VisitOutcome, int> counts = ws.diaryCounts(
          period: _period,
          patientId: _patient,
        );
        final Map<DateTime, List<DemoDiaryEntry>> byDay =
            <DateTime, List<DemoDiaryEntry>>{};
        for (final DemoDiaryEntry e in entries) {
          final DateTime d = DateUtils.dateOnly(e.appointment.start);
          byDay.putIfAbsent(d, () => <DemoDiaryEntry>[]).add(e);
        }
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/inicio')),
            title: const Text('Diário de atendimentos'),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () => context.go('/agenda'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Agenda'),
              ),
            ],
          ),
          body: ListView(
            key: const ValueKey<String>('diario-lista'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoNotice(
                      icon: Icons.menu_book_outlined,
                      text:
                          'Consultas da sua agenda em ordem cronológica, da '
                          'mais recente para a mais antiga. Realizada = '
                          'registro finalizado no prontuário.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Período',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final DiaryPeriod p in DiaryPeriod.values)
                          ChoiceChip(
                            label: Text(p.label),
                            selected: _period == p,
                            onSelected: (_) => setState(() => _period = p),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Situação',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _outcome == null,
                          onSelected: (_) => setState(() => _outcome = null),
                        ),
                        for (final VisitOutcome o in VisitOutcome.values)
                          ChoiceChip(
                            label: Text('${o.label} (${counts[o]})'),
                            selected: _outcome == o,
                            onSelected: (_) => setState(() => _outcome = o),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Paciente',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Todos os pacientes'),
                          selected: _patient == null,
                          onSelected: (_) => setState(() => _patient = null),
                        ),
                        for (final DemoPatient p in _patientsInDiary())
                          ChoiceChip(
                            label: Text(p.name),
                            selected: _patient == p.id,
                            onSelected: (_) => setState(() => _patient = p.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      child: Text(
                        'Realizadas: ${counts[VisitOutcome.realizada]} - '
                        'Pendentes: ${counts[VisitOutcome.pendente]} - '
                        'Faltas: ${counts[VisitOutcome.falta]}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: DemoNotice(
                          text: 'Nenhum atendimento com esses filtros.',
                        ),
                      ),
                    for (final MapEntry<DateTime, List<DemoDiaryEntry>> day
                        in byDay.entries) ...<Widget>[
                      DemoSectionTitle(
                        '${_weekday(day.key)}, ${demoDate(day.key)}',
                      ),
                      for (final DemoDiaryEntry e in day.value)
                        _DiaryTile(entry: e),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    DemoTaskList(patientId: _patient),
                    const SizedBox(height: AppSpacing.xxl),
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

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({required this.entry});

  final DemoDiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final DemoAppointment a = entry.appointment;
    final DemoPatient p = entry.patient;
    final DemoConsultation? c = entry.consultation;
    final VisitOutcome o = entry.classification.outcome;
    final String base = '/pacientes/${p.id}';
    final bool past = !a.start.isAfter(demoSession.now);
    final bool startable =
        a.status.holdsSlot && a.status != DemoAppointmentStatus.falta;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        onTap: () => context.go('/agenda/${a.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  demoTime(a.start),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${p.name} - ${a.reason}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                DemoTag(o.label, color: outcomeColor(o)),
              ],
            ),
            if (entry.classification.pendingReason != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  entry.classification.pendingReason!,
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (c != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go('$base/consulta/${c.id}/resumo'),
                    icon: const Icon(Icons.summarize_outlined),
                    label: Text('Resumo de ${p.name}'),
                  ),
                if (c != null && c.isDraft)
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('$base/consulta/${c.id}'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Continuar registro'),
                  ),
                if (c == null && startable && o != VisitOutcome.agendada)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final DemoConsultation started = demoSession.workspace
                          .startVisit(a);
                      context.go('$base/consulta/${started.id}');
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Registrar atendimento'),
                  ),
                if (c == null && startable && past)
                  TextButton.icon(
                    onPressed: () {
                      demoSession.setAppointmentStatus(
                        a,
                        DemoAppointmentStatus.falta,
                      );
                      showDemoSnack(context, 'Falta registrada.');
                    },
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('Registrar falta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
