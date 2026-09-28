import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/clinical/file_input.dart';
import '../../shared/clinical/lab_results.dart';
import '../../shared/routine/child_routine.dart';
import '../demo_data.dart';
import '../demo_routine.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/routine_widgets.dart';

/// Aviso no mensageiro da raiz: continua visível depois de trocar de tela.
void routineSnack(BuildContext context, String message) {
  final BuildContext root = Navigator.of(context, rootNavigator: true).context;
  showDemoSnack(root, message);
}

Widget _field(
  TextEditingController c,
  String label, {
  String? hint,
  TextInputType? keyboard,
  int lines = 1,
  ValueChanged<String>? onChanged,
  bool enabled = true,
}) {
  return Semantics(
    container: true,
    child: TextField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboard,
      minLines: lines,
      maxLines: lines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _label(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
  child: Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.navy,
      fontWeight: FontWeight.w800,
    ),
  ),
);

/// Erros logo acima dos botoes fixos, visiveis sem rolar no celular.
Widget _actionsWithErrors(
  BuildContext context,
  List<String> errors,
  Widget actions,
) {
  if (errors.isEmpty) return actions;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _errorBox(context, errors),
      ),
      actions,
    ],
  );
}

Widget _errorBox(BuildContext context, List<String> errors) {
  if (errors.isEmpty) return const SizedBox.shrink();
  return Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String e in errors)
            Text(
              e,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9E1026),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ),
  );
}

Future<List<int>?> pickReminders(BuildContext context, List<int> initial) {
  final Set<int> sel = initial.toSet();
  return showDialog<List<int>>(
    context: context,
    builder: (BuildContext d) => StatefulBuilder(
      builder: (BuildContext d, StateSetter set) => AlertDialog(
        title: const Text('Lembretes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Avisar:'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final int m in kReminderOptions)
                  FilterChip(
                    label: Text(reminderLabel(m)),
                    selected: sel.contains(m),
                    onSelected: (bool v) =>
                        set(() => v ? sel.add(m) : sel.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Na demonstração o aviso aparece dentro do app. No app real, '
              'como notificação do celular.',
              style: Theme.of(d).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(sel.toList()..sort()),
            child: const Text('Salvar lembretes'),
          ),
        ],
      ),
    ),
  );
}

/// `null` se desistiu; texto (pode ser vazio se [required] for falso).
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String confirm,
  bool required = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext d) =>
        _ReasonDialog(title: title, confirm: confirm, required: required),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.confirm,
    required this.required,
  });

  final String title;
  final String confirm;
  final bool required;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: _field(
        _c,
        widget.required ? 'Motivo' : 'Motivo (opcional)',
        lines: 2,
        onChanged: (_) => setState(() {}),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: widget.required && _c.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_c.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item do calendário
// ---------------------------------------------------------------------------

Future<void> showRoutineItemSheet(BuildContext context, CalendarItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheet) => _ItemSheet(item: item, host: context),
  );
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.item, required this.host});

  final CalendarItem item;
  final BuildContext host;

  String get _origin => switch (item.source) {
    RoutineSource.familia => 'Cadastrado pela família no app',
    RoutineSource.clinica =>
      item.appointmentId != null
          ? 'Agendado pela clínica'
          : 'Registro da clínica',
    RoutineSource.receita => 'Horário programado a partir da receita',
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final bool canEdit = demoSession.canEditRoutine;
    final RoutineEvent? event = item.eventId == null
        ? null
        : demoSession.routineEventById(item.eventId!);
    final MedicationPlan? plan = item.planId == null
        ? null
        : demoSession.planById(item.planId!);
    final OccurrenceState? occ = event != null
        ? event.occurrences[item.occurrenceKey]
        : plan?.doses[item.doseKey];
    final String pid = item.patientId;
    final NavigatorState nav = Navigator.of(context);

    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
        style: t.bodyMedium?.copyWith(color: AppColors.navy),
      ),
    );

    final List<Widget> actions = <Widget>[];
    if (canEdit && event != null) {
      final String key = item.occurrenceKey!;
      if (item.isPlanned) {
        actions
          ..add(
            FilledButton.icon(
              onPressed: () {
                demoSession.setOccurrenceStatus(
                  event.id,
                  key,
                  RoutineStatus.done,
                );
                nav.pop();
                showDemoSnack(host, 'Marcado como realizado.');
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Concluir'),
            ),
          )
          ..add(
            OutlinedButton.icon(
              onPressed: () async {
                final String? why = await askReason(
                  context,
                  title: 'Cancelar compromisso',
                  confirm: 'Cancelar compromisso',
                );
                if (why == null) return;
                demoSession.setOccurrenceStatus(
                  event.id,
                  key,
                  RoutineStatus.cancelled,
                  note: why,
                );
                nav.pop();
                if (host.mounted) showDemoSnack(host, 'Compromisso cancelado.');
              },
              icon: const Icon(Icons.block_rounded),
              label: const Text('Cancelar compromisso'),
            ),
          );
      } else {
        actions.add(
          OutlinedButton.icon(
            onPressed: () {
              demoSession.setOccurrenceStatus(
                event.id,
                key,
                RoutineStatus.planned,
              );
              nav.pop();
              showDemoSnack(host, 'Compromisso reaberto.');
            },
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Reabrir'),
          ),
        );
      }
      actions
        ..add(
          OutlinedButton.icon(
            onPressed: () {
              nav.pop();
              host.go('/rotina/$pid/evento/${event.id}/editar');
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        )
        ..add(
          OutlinedButton.icon(
            onPressed: () async {
              final List<int>? r = await pickReminders(
                context,
                event.reminders,
              );
              if (r == null) return;
              demoSession.saveRoutineEvent(
                event.edited(
                  event.copyWith(reminders: r),
                  author: demoSession.routineAuthor,
                  at: demoSession.now,
                ),
              );
              nav.pop();
              if (host.mounted) showDemoSnack(host, 'Lembretes atualizados.');
            },
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Lembretes'),
          ),
        );
    }
    if (canEdit && plan != null) {
      final String key = item.doseKey!;
      if (item.isPlanned) {
        actions
          ..add(
            FilledButton.icon(
              onPressed: () {
                nav.pop();
                showDiarySheet(
                  host,
                  pid,
                  DiaryKind.medicamento,
                  day: dayOf(demoSession.now),
                  dose: DoseSlot(plan, item.start),
                );
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Registrar dose dada'),
            ),
          )
          ..add(
            OutlinedButton.icon(
              onPressed: () async {
                final String? why = await askReason(
                  context,
                  title: 'Dose não administrada',
                  confirm: 'Confirmar',
                );
                if (why == null) return;
                demoSession.setDoseStatus(
                  plan.id,
                  key,
                  RoutineStatus.cancelled,
                  note: why,
                );
                nav.pop();
                if (host.mounted) {
                  showDemoSnack(host, 'Dose marcada como não administrada.');
                }
              },
              icon: const Icon(Icons.block_rounded),
              label: const Text('Não foi dada'),
            ),
          );
      } else if (occ?.diaryEntryId != null) {
        actions.add(
          OutlinedButton.icon(
            onPressed: () {
              nav.pop();
              host.go('/rotina/$pid/registro/${occ!.diaryEntryId}');
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver registro no diário'),
          ),
        );
      } else {
        actions.add(
          OutlinedButton.icon(
            onPressed: () {
              demoSession.setDoseStatus(plan.id, key, RoutineStatus.planned);
              nav.pop();
              showDemoSnack(host, 'Dose reaberta.');
            },
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Reabrir dose'),
          ),
        );
      }
      actions.add(
        OutlinedButton.icon(
          onPressed: () async {
            final List<int>? r = await pickReminders(context, plan.reminders);
            if (r == null) return;
            demoSession.savePlan(
              plan.copyWith(
                reminders: r,
                history: <RoutineChange>[
                  ...plan.history,
                  RoutineChange(
                    at: demoSession.now,
                    author: demoSession.routineAuthor,
                    action: 'Lembretes alterados',
                    detail: r.isEmpty
                        ? 'nenhum'
                        : r.map(reminderLabel).join(', '),
                  ),
                ],
              ),
            );
            nav.pop();
            if (host.mounted) showDemoSnack(host, 'Lembretes atualizados.');
          },
          icon: const Icon(Icons.notifications_outlined),
          label: const Text('Lembretes'),
        ),
      );
    }
    if (canEdit && item.appointmentId != null && item.isPlanned) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () async {
            final List<int>? r = await pickReminders(context, item.reminders);
            if (r == null) return;
            demoSession.setItemReminders(item.id, r);
            nav.pop();
            if (host.mounted) showDemoSnack(host, 'Lembretes atualizados.');
          },
          icon: const Icon(Icons.notifications_outlined),
          label: const Text('Lembretes'),
        ),
      );
    }
    if (plan != null) {
      actions.add(
        TextButton(
          onPressed: () {
            nav.pop();
            host.go('/rotina/$pid/medicamento/${plan.docId}/${plan.itemIndex}');
          },
          child: const Text('Ver todos os horários'),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                RoutineStatusMarker(
                  icon: routineKindIcon(item.kind),
                  color: routineKindColor(item.kind),
                  status: item.status,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: t.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(item.kind.label, style: t.bodySmall),
                    ],
                  ),
                ),
                RoutineStatusChip(
                  item.status,
                  overdue: item.isOverdue(demoSession.now),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            info(
              'Quando',
              '${formatDayLong(item.start)}, '
                  '${item.allDay ? 'dia inteiro' : formatHm(item.start)}'
                  '${item.durationMinutes == null ? '' : ' (${formatMinutes(item.durationMinutes!)})'}',
            ),
            info('Origem', _origin),
            if (event != null && event.repeats)
              info('Repetição', event.repeat.label),
            if (item.detail.trim().isNotEmpty) info('Detalhes', item.detail),
            info(
              'Lembretes',
              item.reminders.isEmpty
                  ? 'nenhum'
                  : item.reminders.map(reminderLabel).join(', '),
            ),
            if (occ != null)
              info(
                item.status == RoutineStatus.done ? 'Realizado' : 'Situação',
                '${occ.status.label} por ${occ.author} em '
                '${formatDm(occ.at)} às ${formatHm(occ.at)}'
                '${occ.note.isEmpty ? '' : ' - ${occ.note}'}',
              ),
            if (item.appointmentId != null)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: DemoNotice(
                  text:
                      'Para remarcar ou cancelar a consulta, fale com a '
                      'clínica. Os lembretes são só seus.',
                ),
              ),
            if (item.id.startsWith('rx:'))
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: DemoNotice(
                  text:
                      'Receita emitida pela clínica. Programe os horários em '
                      '"Medicamentos prescritos", abaixo do calendário.',
                ),
              ),
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: DemoNotice(
                  icon: Icons.visibility_outlined,
                  text: 'Somente leitura. Cadastrado pela família.',
                ),
              ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
            if (event != null && event.history.isNotEmpty)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Histórico (${event.history.length})'),
                  children: <Widget>[
                    for (final RoutineChange c in event.history.reversed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${c.action} por ${c.author}'),
                        subtitle: Text(
                          '${formatDmy(c.at)} ${formatHm(c.at)}'
                          '${c.detail.isEmpty ? '' : '\n${c.detail}'}',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registro rápido do diário
// ---------------------------------------------------------------------------

Future<void> showDiarySheet(
  BuildContext context,
  String patientId,
  DiaryKind kind, {
  DateTime? day,
  DiaryEntry? editing,
  DoseSlot? dose,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _DiarySheet(
        patientId: patientId,
        kind: kind,
        day: day,
        editing: editing,
        dose: dose,
        host: context,
      ),
    ),
  );
}

class _DiarySheet extends StatefulWidget {
  const _DiarySheet({
    required this.patientId,
    required this.kind,
    required this.host,
    this.day,
    this.editing,
    this.dose,
  });

  final String patientId;
  final DiaryKind kind;
  final BuildContext host;
  final DateTime? day;
  final DiaryEntry? editing;
  final DoseSlot? dose;

  @override
  State<_DiarySheet> createState() => _DiarySheetState();
}

class _DiarySheetState extends State<_DiarySheet> {
  final TextEditingController _date = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _end = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _text = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _option;
  String _unit = '';
  LabAttachment? _attachment;
  DoseSlot? _dose;
  List<DoseSlot> _candidates = const <DoseSlot>[];
  List<String> _errors = const <String>[];

  DiaryKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final DateTime now = demoSession.now;
    final DiaryEntry? e = widget.editing;
    _unit = kind.units.isEmpty ? '' : kind.units.first;
    if (e != null) {
      final DiaryValues v = e.values;
      _date.text = formatDmy(v.at);
      _time.text = formatHm(v.at);
      _end.text = v.endAt == null ? '' : formatHm(v.endAt!);
      _duration.text = v.durationMinutes?.toString() ?? '';
      _qty.text = v.quantity == null
          ? ''
          : formatDecimal(v.quantity!, digits: 2);
      if (v.unit.isNotEmpty) _unit = v.unit;
      _option = v.option.isEmpty ? null : v.option;
      _text.text = v.text;
      _note.text = v.note;
      _attachment = e.attachment;
    } else {
      final DateTime d = widget.day ?? now;
      final bool today = sameDay(d, now);
      _date.text = formatDmy(today ? now : d);
      _time.text = today ? formatHm(now) : '12:00';
      if (kind == DiaryKind.temperatura) _option = 'Axilar';
      _candidates = kind == DiaryKind.medicamento
          ? demoSession.dosesNear(widget.patientId, now)
          : const <DoseSlot>[];
      if (widget.dose != null) _useDose(widget.dose!);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _date,
      _time,
      _end,
      _duration,
      _qty,
      _text,
      _note,
      _reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _useDose(DoseSlot d) {
    _dose = d;
    _text.text = d.plan.drug;
    final RegExpMatch? m = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?)\s*([^\s,]+)',
    ).firstMatch(d.plan.posology);
    if (m != null) {
      _qty.text = m.group(1)!;
      _unit = m.group(2)!;
    }
  }

  void _now() {
    final DateTime now = demoSession.now;
    setState(() {
      _date.text = formatDmy(now);
      _time.text = formatHm(now);
    });
  }

  DiaryValues? _build(List<String> errors) {
    final DateTime? date = parseDmy(_date.text);
    final ({int hour, int minute})? hm = parseHm(_time.text);
    if (date == null) errors.add('Informe a data (dd/mm/aaaa).');
    if (hm == null) errors.add('Informe o horário (HH:MM).');
    if (date == null || hm == null) return null;
    final DateTime at = DateTime(
      date.year,
      date.month,
      date.day,
      hm.hour,
      hm.minute,
    );
    DateTime? endAt;
    if (kind == DiaryKind.sono && _end.text.trim().isNotEmpty) {
      final ({int hour, int minute})? e = parseHm(_end.text);
      if (e == null) {
        errors.add('Informe o fim do sono (HH:MM) ou deixe vazio.');
        return null;
      }
      endAt = DateTime(date.year, date.month, date.day, e.hour, e.minute);
      if (!endAt.isAfter(at)) endAt = addDays(endAt, 1);
    }
    int? duration;
    if (kind.hasDuration &&
        kind != DiaryKind.sono &&
        _duration.text.trim().isNotEmpty) {
      duration = int.tryParse(_duration.text.trim());
      if (duration == null) {
        errors.add('Informe a duração em minutos.');
        return null;
      }
    }
    double? qty;
    if (_qty.text.trim().isNotEmpty) {
      qty = parseDecimal(_qty.text);
      if (qty == null) {
        errors.add('Quantidade inválida.');
        return null;
      }
    }
    final String unit = switch (kind) {
      DiaryKind.temperatura => '°C',
      DiaryKind.peso => 'kg',
      DiaryKind.mamada => 'mL',
      _ => _unit,
    };
    return DiaryValues(
      at: at,
      endAt: endAt,
      durationMinutes: duration,
      quantity: qty,
      unit: qty == null ? '' : unit,
      option: _option ?? '',
      text: _text.text.trim(),
      note: _note.text.trim(),
    );
  }

  Future<void> _attach() async {
    final PickedFile? f = await pickFile(accept: 'image/*,application/pdf');
    if (f == null || !mounted) return;
    if (LabAttachment.sourceFor(f.mimeType) == null) {
      setState(() => _errors = <String>['Anexe uma imagem ou um PDF.']);
      return;
    }
    if (f.bytes.length > LabAttachment.maxBytes) {
      setState(() => _errors = <String>['O arquivo passa de 10 MB.']);
      return;
    }
    setState(() {
      _errors = const <String>[];
      _attachment = LabAttachment(
        name: f.name,
        mimeType: f.mimeType,
        bytes: f.bytes,
      );
    });
  }

  void _save() {
    final List<String> errors = <String>[];
    final DiaryValues? v = _build(errors);
    if (v != null) errors.addAll(v.validate(kind, now: demoSession.now));
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final NavigatorState nav = Navigator.of(context);
    final DiaryEntry? e = widget.editing;
    if (e != null) {
      final DiaryEntry next = e.corrected(
        values: v!,
        author: demoSession.routineAuthor,
        at: demoSession.now,
        reason: _reason.text,
        attachment: identical(_attachment, e.attachment)
            ? null
            : () => _attachment,
      );
      if (identical(next, e)) {
        setState(() => _errors = <String>['Nada foi alterado.']);
        return;
      }
      demoSession.replaceDiaryEntry(next);
      nav.pop();
      showDemoSnack(
        widget.host,
        'Registro corrigido. A versão anterior ficou no histórico.',
      );
      return;
    }
    demoSession.addDiaryEntry(
      patientId: widget.patientId,
      kind: kind,
      values: v!,
      attachment: _attachment,
      planId: _dose?.plan.id,
      doseKey: _dose?.key,
    );
    nav.pop();
    showDemoSnack(
      widget.host,
      'Registro salvo: ${kind.label} às ${formatHm(v.at)}.',
    );
  }

  List<Widget> _chipsFor(List<int> values, TextEditingController c, String u) =>
      <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final int n in values)
              ChoiceChip(
                label: Text('$n $u'),
                selected: c.text.trim() == '$n',
                onSelected: (bool s) => setState(() => c.text = s ? '$n' : ''),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ];

  List<Widget> _specific(BuildContext context) {
    switch (kind) {
      case DiaryKind.mamada:
        return <Widget>[
          _label(context, 'Como foi'),
          ChoiceRow<String>(
            options: kFeedOptions,
            selected: _option,
            label: (String s) => s,
            onSelected: (String? s) => setState(() => _option = s),
          ),
          _label(context, 'Duração (opcional)'),
          ..._chipsFor(<int>[5, 10, 15, 20, 30], _duration, 'min'),
          _field(_duration, 'Duração (min)', keyboard: TextInputType.number),
          if (_option == 'Mamadeira') ...<Widget>[
            _label(context, 'Quantidade'),
            ..._chipsFor(<int>[60, 90, 120, 150, 180], _qty, 'mL'),
            _field(_qty, 'Quantidade (mL)', keyboard: TextInputType.number),
          ],
        ];
      case DiaryKind.alimentacao:
        return <Widget>[
          const SizedBox(height: AppSpacing.md),
          _field(_text, 'O que comeu', hint: 'Ex.: papinha de legumes'),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _qty,
            'Quantidade (opcional)',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          ChoiceRow<String>(
            options: kFoodUnits,
            selected: _unit,
            label: (String s) => s,
            onSelected: (String? s) =>
                setState(() => _unit = s ?? kFoodUnits.first),
          ),
          _label(context, 'Aceitação (opcional)'),
          ChoiceRow<String>(
            options: kFoodAcceptance,
            selected: _option,
            label: (String s) => s,
            onSelected: (String? s) => setState(() => _option = s),
          ),
        ];
      case DiaryKind.fralda:
        return <Widget>[
          _label(context, 'Tipo'),
          ChoiceRow<String>(
            options: kDiaperOptions,
            selected: _option,
            label: (String s) => s,
            onSelected: (String? s) => setState(() => _option = s),
          ),
        ];
      case DiaryKind.sono:
        return <Widget>[
          const SizedBox(height: AppSpacing.sm),
          _field(
            _end,
            'Fim (HH:MM) - vazio se ainda dorme',
            keyboard: TextInputType.datetime,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.bedtime_outlined, size: 18),
                label: const Text('Dormiu agora'),
                onPressed: () {
                  _now();
                  setState(() => _end.clear());
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                label: const Text('Acordou agora'),
                onPressed: () =>
                    setState(() => _end.text = formatHm(demoSession.now)),
              ),
            ],
          ),
        ];
      case DiaryKind.banho:
        return <Widget>[
          _label(context, 'Duração (opcional)'),
          ..._chipsFor(<int>[5, 10, 15, 20], _duration, 'min'),
          _field(_duration, 'Duração (min)', keyboard: TextInputType.number),
        ];
      case DiaryKind.temperatura:
        return <Widget>[
          const SizedBox(height: AppSpacing.md),
          _field(
            _qty,
            'Temperatura (°C)',
            hint: 'Ex.: 37,5',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _label(context, 'Onde mediu'),
          ChoiceRow<String>(
            options: kTemperatureMethods,
            selected: _option,
            label: (String s) => s,
            onSelected: (String? s) => setState(() => _option = s),
          ),
        ];
      case DiaryKind.peso:
        return <Widget>[
          const SizedBox(height: AppSpacing.md),
          _field(
            _qty,
            'Peso (kg)',
            hint: 'Ex.: 10,4',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Peso informado pela família. A curva de crescimento usa as '
            'medidas feitas na consulta.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case DiaryKind.medicamento:
        return <Widget>[
          if (_candidates.isNotEmpty || _dose != null) ...<Widget>[
            _label(context, 'Dose programada da receita'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final DoseSlot d in <DoseSlot>[
                  if (_dose != null) _dose!,
                  ..._candidates.where(
                    (DoseSlot c) =>
                        c.plan.id != _dose?.plan.id || c.key != _dose?.key,
                  ),
                ])
                  ChoiceChip(
                    label: Text(
                      '${d.plan.drug} - ${formatHm(d.time)}'
                      '${sameDay(d.time, demoSession.now) ? '' : ' de ${formatDm(d.time)}'}',
                    ),
                    selected:
                        _dose?.key == d.key && _dose?.plan.id == d.plan.id,
                    onSelected: (bool s) => setState(() {
                      if (s) {
                        _useDose(d);
                      } else {
                        _dose = null;
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _field(_text, 'Medicamento'),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _qty,
            'Quantidade dada',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          ChoiceRow<String>(
            options: <String>{...kMedicationUnits, _unit}.toList(),
            selected: _unit,
            label: (String s) => s,
            onSelected: (String? s) =>
                setState(() => _unit = s ?? kMedicationUnits.first),
          ),
        ];
      case DiaryKind.observacao:
        return <Widget>[
          const SizedBox(height: AppSpacing.md),
          _field(_text, 'Observação', lines: 4),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Color c = diaryKindColor(kind);
    final bool editing = widget.editing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(diaryKindIcon(kind), color: c),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  editing ? 'Corrigir: ${kind.label}' : kind.label,
                  style: t.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _field(_date, 'Data', keyboard: TextInputType.datetime),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: _field(
                  _time,
                  kind == DiaryKind.sono ? 'Início' : 'Horário',
                  keyboard: TextInputType.datetime,
                ),
              ),
              TextButton(onPressed: _now, child: const Text('Agora')),
            ],
          ),
          ..._specific(context),
          if (kind != DiaryKind.observacao) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _field(_note, 'Observação (opcional)'),
          ],
          if (kind.allowsAttachment) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            if (_attachment == null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _attach,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Anexar foto ou arquivo'),
                ),
              )
            else
              Row(
                children: <Widget>[
                  Icon(
                    _attachment!.isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${_attachment!.name} (${_attachment!.sizeLabel})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _attachment = null),
                    child: const Text('Remover anexo'),
                  ),
                ],
              ),
          ],
          if (editing) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _field(_reason, 'Motivo da correção (opcional)'),
          ],
          _errorBox(context, _errors),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Registrado por ${demoSession.routineAuthor} '
            '(${demoSession.routineRole.label.toLowerCase()})',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(editing ? 'Salvar correção' : 'Salvar'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalhe de um registro do diário
// ---------------------------------------------------------------------------

class DemoDiaryEntryScreen extends StatelessWidget {
  const DemoDiaryEntryScreen({
    required this.patientId,
    required this.entryId,
    super.key,
  });

  final String patientId;
  final String entryId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DiaryEntry? e = demoSession.diaryEntryById(entryId);
        final TextTheme t = Theme.of(context).textTheme;
        void back() => context.go(
          routineUrl(patientId, view: 'diario', day: e?.at ?? demoSession.now),
        );
        if (e == null || e.patientId != patientId) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: back),
              title: const Text('Registro do diário'),
            ),
            body: const DemoEmpty(
              title: 'Registro não encontrado',
              message: 'Este registro não existe ou não é desta criança.',
            ),
          );
        }
        final bool canEdit = demoSession.canEditRoutine && !e.voided;
        final DiaryValues v = e.values;
        final Color c = diaryKindColor(e.kind);

        Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: t.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: t.bodyMedium?.copyWith(color: AppColors.navy),
                ),
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: back),
            title: const Text('Registro do diário'),
          ),
          body: DemoContent(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(diaryKindIcon(e.kind), color: c),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  e.kind.label,
                                  style: t.titleLarge?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                    decoration: e.voided
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (e.describe.isNotEmpty)
                                  Text(e.describe, style: t.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      row(
                        'Data e horário',
                        '${formatDmy(v.at)} às ${formatHm(v.at)}',
                      ),
                      if (v.endAt != null)
                        row(
                          'Fim',
                          '${formatDmy(v.endAt!)} às ${formatHm(v.endAt!)}',
                        ),
                      if (v.minutes != null)
                        row('Duração', formatMinutes(v.minutes!)),
                      if (v.quantity != null)
                        row('Quantidade', v.quantityLabel()),
                      if (v.option.isNotEmpty) row('Detalhe', v.option),
                      if (v.note.trim().isNotEmpty)
                        row('Observação', v.note.trim()),
                      row(
                        'Lançado em',
                        '${formatDmy(e.recordedAt)} às ${formatHm(e.recordedAt)}',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 118,
                              child: Text(
                                'Autor',
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Text(e.author),
                                  AuthorBadge(role: e.role),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (e.planId != null && e.doseKey != null)
                        row(
                          'Receita',
                          'Confirma a dose prevista para '
                              '${e.doseKey!.replaceFirst('T', ' às ')}',
                        ),
                    ],
                  ),
                ),
                if (e.voided) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const DemoNotice(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    text:
                        'Lançamento excluído. Ele não entra no resumo, mas '
                        'continua no histórico.',
                  ),
                ],
                if (e.attachment != null) ...<Widget>[
                  const DemoSectionTitle('Anexo'),
                  _AttachmentCard(attachment: e.attachment!),
                ],
                if (canEdit) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => showDiarySheet(
                          context,
                          patientId,
                          e.kind,
                          editing: e,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Corrigir'),
                      ),
                      if (e.isOpenSleep)
                        FilledButton.tonalIcon(
                          onPressed: () {
                            demoSession.replaceDiaryEntry(
                              e.finishedSleep(
                                end: demoSession.now,
                                author: demoSession.routineAuthor,
                                at: demoSession.now,
                              ),
                            );
                            showDemoSnack(context, 'Fim do sono registrado.');
                          },
                          icon: const Icon(Icons.wb_sunny_outlined),
                          label: const Text('Acordou agora'),
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () async {
                          final String? why = await askReason(
                            context,
                            title: 'Excluir lançamento',
                            confirm: 'Excluir',
                            required: true,
                          );
                          if (why == null) return;
                          demoSession.replaceDiaryEntry(
                            e.voidedBy(
                              author: demoSession.routineAuthor,
                              at: demoSession.now,
                              reason: why,
                            ),
                          );
                          if (context.mounted) {
                            showDemoSnack(
                              context,
                              'Lançamento excluído. Ele continua no histórico.',
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Excluir lançamento'),
                      ),
                    ],
                  ),
                ],
                const DemoSectionTitle('Histórico'),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final DiaryRevision r in e.revisions.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${r.action} por ${r.author} em '
                                '${formatDmy(r.at)} às ${formatHm(r.at)}',
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (r.reason.isNotEmpty)
                                Text('Motivo: ${r.reason}', style: t.bodySmall),
                              if (r.before != null)
                                Text(
                                  'Antes: ${formatHm(r.before!.at)} - '
                                  '${r.before!.describe(e.kind)}',
                                  style: t.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Text(
                        'Criado por ${e.author} em ${formatDmy(e.recordedAt)} '
                        'às ${formatHm(e.recordedAt)}',
                        style: t.bodyMedium?.copyWith(color: AppColors.navy),
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

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final LabAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          if (attachment.isImage)
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: Image.memory(
                attachment.bytes,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                semanticLabel: 'Imagem anexada',
              ),
            )
          else
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: AppColors.danger,
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  attachment.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(attachment.sizeLabel),
                TextButton(
                  onPressed: () {
                    if (!openFileInNewTab(
                      attachment.bytes,
                      attachment.mimeType,
                    )) {
                      showDemoSnack(
                        context,
                        'Não foi possível abrir o arquivo aqui.',
                      );
                    }
                  },
                  child: const Text('Abrir arquivo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compromisso da família
// ---------------------------------------------------------------------------

class DemoRoutineEventFormScreen extends StatefulWidget {
  const DemoRoutineEventFormScreen({
    required this.patientId,
    super.key,
    this.eventId,
    this.day,
    this.vaccineName,
    this.vaccineDose,
  });

  final String patientId;
  final String? eventId;
  final String? day;
  final String? vaccineName;
  final String? vaccineDose;

  @override
  State<DemoRoutineEventFormScreen> createState() =>
      _DemoRoutineEventFormScreenState();
}

class _DemoRoutineEventFormScreenState
    extends State<DemoRoutineEventFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _until = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  RoutineKind _kind = RoutineKind.atividade;
  bool _allDay = false;
  RoutineRepeat _repeat = RoutineRepeat.none;
  Set<int> _reminders = <int>{30};
  List<String> _errors = const <String>[];
  RoutineEvent? _existing;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = demoSession.now;
    final RoutineEvent? e = widget.eventId == null
        ? null
        : demoSession.routineEventById(widget.eventId!);
    _existing = e?.patientId == widget.patientId ? e : null;
    if (_existing != null) {
      final RoutineEvent x = _existing!;
      _kind = x.kind;
      _title.text = x.title;
      _date.text = formatDmy(x.start);
      _allDay = x.allDay;
      _time.text = x.allDay ? '09:00' : formatHm(x.start);
      _duration.text = x.durationMinutes?.toString() ?? '';
      _repeat = x.repeat;
      _until.text = x.until == null ? '' : formatDmy(x.until!);
      _reminders = x.reminders.toSet();
      _notes.text = x.notes;
      return;
    }
    final DateTime d = parseRoutineDateKey(widget.day) ?? dayOf(now);
    _date.text = formatDmy(d);
    _time.text = sameDay(d, now) && now.hour < 23
        ? '${(now.hour + 1).toString().padLeft(2, '0')}:00'
        : '09:00';
    if (widget.vaccineName != null) {
      _kind = RoutineKind.vacina;
      _title.text = '${widget.vaccineName} - ${widget.vaccineDose ?? ''}'
          .trim();
      _reminders = <int>{1440, 60};
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _date,
      _time,
      _duration,
      _until,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (!mounted) return;
    context.go(
      routineUrl(
        widget.patientId,
        mode: 'dia',
        day: parseDmy(_date.text) ?? demoSession.now,
      ),
    );
  }

  void _save() {
    final List<String> errors = <String>[];
    final DateTime? date = parseDmy(_date.text);
    if (date == null) errors.add('Informe a data (dd/mm/aaaa).');
    final ({int hour, int minute})? hm = _allDay ? null : parseHm(_time.text);
    if (!_allDay && hm == null) errors.add('Informe o horário (HH:MM).');
    int? duration;
    if (!_allDay && _duration.text.trim().isNotEmpty) {
      duration = int.tryParse(_duration.text.trim());
      if (duration == null) errors.add('Informe a duração em minutos.');
    }
    DateTime? until;
    if (_repeat != RoutineRepeat.none && _until.text.trim().isNotEmpty) {
      until = parseDmy(_until.text);
      if (until == null) errors.add('Informe o fim da repetição (dd/mm/aaaa).');
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final DateTime start = _allDay
        ? date!
        : DateTime(date!.year, date.month, date.day, hm!.hour, hm.minute);
    final DateTime now = demoSession.now;
    final String author = demoSession.routineAuthor;
    final RoutineEvent? x = _existing;
    final RoutineEvent draft = RoutineEvent(
      id: x?.id ?? demoSession.newId('e'),
      patientId: widget.patientId,
      kind: _kind,
      title: _title.text.trim(),
      start: start,
      allDay: _allDay,
      durationMinutes: _allDay ? null : duration,
      notes: _notes.text.trim(),
      repeat: _repeat,
      until: _repeat == RoutineRepeat.none ? null : until,
      reminders: _reminders.toList()..sort(),
      occurrences: x?.occurrences ?? const <String, OccurrenceState>{},
      author: x?.author ?? author,
      createdAt: x?.createdAt ?? now,
      history:
          x?.history ??
          <RoutineChange>[
            RoutineChange(at: now, author: author, action: 'Criado'),
          ],
      vaccineName: x?.vaccineName ?? widget.vaccineName,
      vaccineDose: x?.vaccineDose ?? widget.vaccineDose,
    );
    final List<String> invalid = draft.validate();
    if (invalid.isNotEmpty) {
      setState(() => _errors = invalid);
      return;
    }
    final RoutineEvent saved = x == null
        ? draft
        : x.edited(draft, author: author, at: now);
    if (x != null && identical(saved, x)) {
      setState(() => _errors = <String>['Nada foi alterado.']);
      return;
    }
    demoSession.saveRoutineEvent(saved);
    context.go(routineUrl(widget.patientId, mode: 'dia', day: start));
    routineSnack(
      context,
      x == null ? 'Compromisso criado.' : 'Compromisso atualizado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.routinePatient(widget.patientId);
    if (widget.eventId != null && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compromisso')),
        body: const DemoEmpty(
          title: 'Compromisso não encontrado',
          message: 'Este compromisso não existe ou não é desta criança.',
        ),
      );
    }
    void touch() {
      if (!_dirty) setState(() => _dirty = true);
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(
          _existing == null ? 'Novo compromisso' : 'Editar compromisso',
        ),
      ),
      bottomNavigationBar: _actionsWithErrors(
        context,
        _errors,
        DemoFlowActions(
          onBack: _leave,
          primaryLabel: 'Salvar',
          primaryIcon: Icons.check_rounded,
          onPrimary: _save,
        ),
      ),
      body: DemoContent(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            if (p != null)
              Text(
                p.name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.inkMuted),
              ),
            if (widget.vaccineName != null ||
                _existing?.vaccineName != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const DemoNotice(
                icon: Icons.link_rounded,
                text:
                    'Ligado à vacina pendente da carteira. A carteira continua '
                    'sendo atualizada pelo registro da unidade de saúde.',
              ),
            ],
            _label(context, 'Tipo'),
            ChoiceRow<RoutineKind>(
              options: RoutineKind.familyCreatable,
              selected: _kind,
              label: (RoutineKind k) => k.label,
              onSelected: (RoutineKind? k) => setState(() {
                _kind = k ?? _kind;
                _dirty = true;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              _title,
              'Título',
              hint: 'Ex.: Natação, levar exames',
              onChanged: (_) => touch(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _field(
                    _date,
                    'Data (dd/mm/aaaa)',
                    keyboard: TextInputType.datetime,
                    onChanged: (_) => touch(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: _field(
                    _time,
                    'Horário',
                    keyboard: TextInputType.datetime,
                    enabled: !_allDay,
                    onChanged: (_) => touch(),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dia inteiro'),
              value: _allDay,
              onChanged: (bool v) => setState(() {
                _allDay = v;
                _dirty = true;
              }),
            ),
            if (!_allDay)
              _field(
                _duration,
                'Duração em minutos (opcional)',
                keyboard: TextInputType.number,
                onChanged: (_) => touch(),
              ),
            _label(context, 'Repetir'),
            ChoiceRow<RoutineRepeat>(
              options: RoutineRepeat.values,
              selected: _repeat,
              label: (RoutineRepeat r) => r.label,
              onSelected: (RoutineRepeat? r) => setState(() {
                _repeat = r ?? RoutineRepeat.none;
                _dirty = true;
              }),
            ),
            if (_repeat != RoutineRepeat.none) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _field(
                _until,
                'Repetir até (dd/mm/aaaa, opcional)',
                keyboard: TextInputType.datetime,
                onChanged: (_) => touch(),
              ),
            ],
            _label(context, 'Lembretes'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final int m in kReminderOptions)
                  FilterChip(
                    label: Text(reminderLabel(m)),
                    selected: _reminders.contains(m),
                    onSelected: (bool v) => setState(() {
                      v ? _reminders.add(m) : _reminders.remove(m);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              _notes,
              'Observações (opcional)',
              lines: 3,
              onChanged: (_) => touch(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horários de um medicamento prescrito
// ---------------------------------------------------------------------------

class DemoMedicationPlanScreen extends StatefulWidget {
  const DemoMedicationPlanScreen({
    required this.patientId,
    required this.docId,
    required this.index,
    super.key,
  });

  final String patientId;
  final String docId;
  final int index;

  @override
  State<DemoMedicationPlanScreen> createState() =>
      _DemoMedicationPlanScreenState();
}

class _DemoMedicationPlanScreenState extends State<DemoMedicationPlanScreen> {
  final TextEditingController _date = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _interval = TextEditingController();
  final TextEditingController _days = TextEditingController();
  Set<int> _reminders = <int>{0};
  List<String> _errors = const <String>[];
  int? _rxInterval;
  int? _rxDays;

  PrescribedItem? get _rx =>
      demoSession.prescribedItem(widget.patientId, widget.docId, widget.index);

  @override
  void initState() {
    super.initState();
    final PrescribedItem? rx = _rx;
    if (rx == null) return;
    _rxInterval = parseIntervalHours(rx.item.frequency);
    _rxDays = parseDurationDays(rx.item.duration);
    final MedicationPlan? plan = rx.plan;
    final DateTime now = demoSession.now;
    final DateTime first =
        plan?.firstDose ?? DateTime(now.year, now.month, now.day, now.hour + 1);
    _date.text = formatDmy(first);
    _time.text = formatHm(first);
    _interval.text = '${plan?.intervalHours ?? _rxInterval ?? ''}';
    _days.text = '${plan?.days ?? _rxDays ?? ''}';
    _reminders = (plan?.reminders ?? const <int>[0]).toSet();
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _interval.dispose();
    _days.dispose();
    super.dispose();
  }

  bool get _scheduleLocked {
    final MedicationPlan? plan = _rx?.plan;
    return plan != null && plan.doses.isNotEmpty;
  }

  MedicationPlan? _draft(List<String> errors, {bool preview = false}) {
    final PrescribedItem rx = _rx!;
    final DateTime? d = parseDmy(_date.text);
    final ({int hour, int minute})? hm = parseHm(_time.text);
    final int? interval = int.tryParse(_interval.text.trim());
    final int? days = int.tryParse(_days.text.trim());
    if (d == null) errors.add('Informe a data da primeira dose.');
    if (hm == null) errors.add('Informe o horário da primeira dose (HH:MM).');
    if (interval == null) errors.add('Informe o intervalo em horas.');
    if (days == null) errors.add('Informe por quantos dias.');
    if (errors.isNotEmpty) return null;
    final DateTime first = DateTime(
      d!.year,
      d.month,
      d.day,
      hm!.hour,
      hm.minute,
    );
    final DateTime now = demoSession.now;
    final MedicationPlan? existing = rx.plan;
    final MedicationPlan plan = existing == null
        ? MedicationPlan(
            id: preview ? 'previa' : demoSession.newId('m'),
            patientId: widget.patientId,
            docId: rx.doc.id,
            itemIndex: rx.index,
            drug: rx.item.drug,
            posology: rx.item.posology,
            firstDose: first,
            intervalHours: interval!,
            days: days!,
            reminders: _reminders.toList()..sort(),
            author: demoSession.routineAuthor,
            createdAt: now,
            history: <RoutineChange>[
              RoutineChange(
                at: now,
                author: demoSession.routineAuthor,
                action: 'Horários programados',
                detail: 'a partir de ${formatDmy(first)} às ${formatHm(first)}',
              ),
            ],
          )
        : existing.copyWith(
            firstDose: _scheduleLocked ? null : first,
            intervalHours: _scheduleLocked ? null : interval,
            days: _scheduleLocked ? null : days,
            reminders: _reminders.toList()..sort(),
            history: <RoutineChange>[
              ...existing.history,
              RoutineChange(
                at: now,
                author: demoSession.routineAuthor,
                action: 'Horários alterados',
              ),
            ],
          );
    errors.addAll(plan.validate());
    return errors.isEmpty ? plan : null;
  }

  void _save() {
    final List<String> errors = <String>[];
    final MedicationPlan? plan = _draft(errors);
    if (plan == null) {
      setState(() => _errors = errors);
      return;
    }
    demoSession.savePlan(plan);
    context.go(routineUrl(widget.patientId, mode: 'dia', day: plan.firstDose));
    routineSnack(context, 'Horários salvos: ${plan.doseCount} doses.');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    void back() => context.go(routineUrl(widget.patientId));
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final PrescribedItem? rx = _rx;
        if (rx == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: back),
              title: const Text('Horários do medicamento'),
            ),
            body: const DemoEmpty(
              title: 'Item de receita não encontrado',
              message: 'Só itens de receitas emitidas podem ser programados.',
            ),
          );
        }
        final bool canEdit = demoSession.canEditRoutine;
        final MedicationPlan? plan = rx.plan;
        final List<String> previewErrors = <String>[];
        final MedicationPlan? preview = canEdit
            ? _draft(previewErrors, preview: true)
            : plan;
        final DateTime now = demoSession.now;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: back),
            title: const Text('Horários do medicamento'),
          ),
          bottomNavigationBar: canEdit
              ? _actionsWithErrors(
                  context,
                  _errors,
                  DemoFlowActions(
                    onBack: back,
                    primaryLabel: plan == null
                        ? 'Programar horários'
                        : 'Salvar alterações',
                    primaryIcon: Icons.check_rounded,
                    onPrimary: _save,
                  ),
                )
              : null,
          body: DemoContent(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        rx.item.drug,
                        style: t.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(rx.item.presentation, style: t.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        rx.item.posology,
                        style: t.bodyLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Receita emitida em ${formatDmy(rx.issuedAt)} por '
                        '${rx.doc.current.author}',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const DemoNotice(
                  text:
                      'Os horários seguem a receita. Dúvidas sobre a dose, '
                      'fale com o pediatra antes de mudar.',
                ),
                if (canEdit) ...<Widget>[
                  _label(context, 'Primeira dose'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: _field(
                          _date,
                          'Data',
                          keyboard: TextInputType.datetime,
                          enabled: !_scheduleLocked,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: _field(
                          _time,
                          'Horário',
                          keyboard: TextInputType.datetime,
                          enabled: !_scheduleLocked,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _field(
                          _interval,
                          'A cada (horas)',
                          keyboard: TextInputType.number,
                          enabled: _rxInterval == null && !_scheduleLocked,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _field(
                          _days,
                          'Por (dias)',
                          keyboard: TextInputType.number,
                          enabled: _rxDays == null && !_scheduleLocked,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_rxInterval != null && _rxDays != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Intervalo e duração lidos da receita.',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                  if (_scheduleLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Já há doses registradas: só os lembretes podem mudar.',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                  _label(context, 'Lembretes'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final int m in kReminderOptions)
                        FilterChip(
                          label: Text(reminderLabel(m)),
                          selected: _reminders.contains(m),
                          onSelected: (bool v) => setState(
                            () => v ? _reminders.add(m) : _reminders.remove(m),
                          ),
                        ),
                    ],
                  ),
                ],
                if (preview != null) ...<Widget>[
                  DemoSectionTitle(
                    plan == null ? 'Prévia' : 'Doses',
                    trailing: Text(
                      plan == null
                          ? '${preview.doseCount} doses'
                          : '${plan.givenCount} de ${plan.doseCount} registradas',
                      style: t.labelMedium?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                  Text(
                    'De ${formatDm(preview.firstDose)} às '
                    '${formatHm(preview.firstDose)} até '
                    '${formatDm(preview.lastDose)} às '
                    '${formatHm(preview.lastDose)}',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final DateTime d in _window(preview, now))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: <Widget>[
                          RoutineStatusMarker(
                            icon: Icons.medication_outlined,
                            color: AppColors.warning,
                            status: preview.statusOf(MedicationPlan.doseKey(d)),
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${formatDm(d)} às ${formatHm(d)}',
                              style: t.bodyMedium?.copyWith(
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          RoutineStatusChip(
                            preview.statusOf(MedicationPlan.doseKey(d)),
                            overdue:
                                preview.statusOf(MedicationPlan.doseKey(d)) ==
                                    RoutineStatus.planned &&
                                d.isBefore(now),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Últimas 3 doses e as próximas 5, para não listar 30 dias.
  List<DateTime> _window(MedicationPlan p, DateTime now) {
    final List<DateTime> all = p.doseTimes();
    final int next = all.indexWhere((DateTime d) => !d.isBefore(now));
    final int pivot = next < 0 ? all.length : next;
    final int from = (pivot - 3).clamp(0, all.length);
    final int to = (pivot + 5).clamp(0, all.length);
    return all.sublist(from, to);
  }
}
