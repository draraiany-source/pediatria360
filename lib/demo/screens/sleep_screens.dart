import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/routine/child_routine.dart';
import '../../shared/routine/sleep_log.dart';
import '../demo_data.dart';
import '../demo_routine.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/routine_widgets.dart';
import 'routine_forms.dart';

const Color kNightColor = Color(0xFF3A2596);
const Color kNapColor = Color(0xFF9D8BF0);
const Color kWakingColor = Color(0xFFB45309);

String _capFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Sono" da rotina: sete dias terminando em [day], com linha do tempo de
/// 24 horas por dia, resumo do dia e da semana.
class DemoSleepView extends StatefulWidget {
  const DemoSleepView({
    required this.patient,
    required this.day,
    required this.canEdit,
    required this.onDay,
    super.key,
    this.consultationId,
  });

  final DemoPatient patient;

  /// Consulta de onde o profissional abriu o diário (para voltar a ela).
  final String? consultationId;

  /// Último dia do período.
  final DateTime day;
  final bool canEdit;
  final ValueChanged<DateTime> onDay;

  @override
  State<DemoSleepView> createState() => _DemoSleepViewState();
}

class _DemoSleepViewState extends State<DemoSleepView> {
  late DateTime _selected = widget.day;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DemoPatient p = widget.patient;
    final DateTime today = dayOf(demoSession.now);
    final DateTime last = widget.day;
    final DateTime first = addDays(last, -6);
    final SleepWeek week = demoSession.sleepWeek(p.id, last);
    final List<DiaryEntry> entries = demoSession.diaryFor(p.id);
    final DiaryEntry? sleeping = demoSession.openSleep(p.id);
    if (_selected.isBefore(first) || _selected.isAfter(last)) _selected = last;
    final SleepDay selectedDay = week.days.firstWhere(
      (SleepDay d) => sameDay(d.day, _selected),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RoutinePeriodBar(
          label: '${formatDm(first)} a ${formatDm(last)}',
          prevLabel: 'Semana anterior',
          nextLabel: 'Próxima semana',
          onPrev: () => widget.onDay(addDays(last, -7)),
          onNext: last.isBefore(today)
              ? () {
                  final DateTime n = addDays(last, 7);
                  widget.onDay(n.isAfter(today) ? today : n);
                }
              : null,
          onToday: sameDay(last, today) ? null : () => widget.onDay(today),
        ),
        if (sleeping != null) ...<Widget>[
          _SleepingBanner(entry: sleeping, canEdit: widget.canEdit),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (widget.canEdit) ...<Widget>[
          Text(
            'Registrar sono',
            style: t.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (sleeping == null)
                FilledButton.icon(
                  onPressed: () {
                    final DateTime n = demoSession.now;
                    // Despertares são digitados em HH:MM; sem segundos no
                    // início, um despertar no mesmo minuto não fica "antes".
                    demoSession.addDiaryEntry(
                      patientId: p.id,
                      kind: DiaryKind.sono,
                      values: DiaryValues(
                        at: DateTime(n.year, n.month, n.day, n.hour, n.minute),
                        option: kSleepNight,
                      ),
                    );
                    showDemoSnack(
                      context,
                      'Sono noturno iniciado às ${formatHm(demoSession.now)}.',
                    );
                  },
                  icon: const Icon(Icons.bedtime_rounded),
                  label: const Text('Dormiu agora (noite)'),
                ),
              OutlinedButton.icon(
                onPressed: () => showDiarySheet(
                  context,
                  p.id,
                  DiaryKind.sono,
                  day: _selected,
                  option: kSleepNap,
                ),
                icon: const Icon(Icons.airline_seat_flat_outlined),
                label: const Text('Cochilo'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDiarySheet(
                  context,
                  p.id,
                  DiaryKind.sono,
                  day: _selected,
                  option: kSleepNight,
                ),
                icon: const Icon(Icons.nights_stay_outlined),
                label: const Text('Noite com horários'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDiarySheet(
                  context,
                  p.id,
                  DiaryKind.observacao,
                  day: _selected,
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Observação'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Card(
          title: 'Resumo da semana',
          children: <Widget>[
            for (final String l in week.lines())
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: t.bodyMedium),
              ),
            const SizedBox(height: 4),
            Text(
              'Somente o que foi registrado; dias sem registro ficam fora '
              'das médias.',
              style: t.labelSmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DemoSectionTitle(
          'Linha do tempo',
          trailing: Text(
            'toque no dia',
            style: t.labelSmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        const _Legend(),
        const SizedBox(height: AppSpacing.xs),
        const _HourAxis(),
        for (final SleepDay d in week.days)
          _DayRow(
            day: d,
            entries: entries,
            selected: sameDay(d.day, _selected),
            onTap: () => setState(() => _selected = d.day),
          ),
        const SizedBox(height: AppSpacing.md),
        DemoSectionTitle(
          sameDay(_selected, today)
              ? 'Hoje, ${formatDayLong(_selected)}'
              : _capFirst(formatDayLong(_selected)),
        ),
        Text(selectedDay.describe(), style: t.bodyMedium),
        if (selectedDay.longestNightStretch != null)
          Text(
            'Maior trecho contínuo à noite: '
            '${formatMinutes(selectedDay.longestNightStretch!)}.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        const SizedBox(height: AppSpacing.xs),
        if (selectedDay.isEmpty)
          Text(
            widget.canEdit
                ? 'Nenhum sono registrado. Use os botões acima para incluir.'
                : 'Nenhum sono registrado pela família neste dia.',
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
                for (final SleepPeriod s in selectedDay.periods)
                  DiaryEntryTile(
                    entry: s.entry,
                    showDate: true,
                    onTap: () => context.go(
                      '/rotina/${p.id}/registro/${s.entry.id}?de=sono'
                      '${widget.consultationId == null ? '' : '&consulta=${widget.consultationId}'}',
                    ),
                  ),
              ],
            ),
          ),
        if (week.observations.isNotEmpty) ...<Widget>[
          const DemoSectionTitle('Observações da família sobre o sono'),
          for (final DiaryEntry e in week.observations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${formatDm(e.at)} ${formatHm(e.at)}: '
                '${e.kind == DiaryKind.sono ? e.values.note : e.values.text}',
                style: t.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (widget.canEdit)
          _FamilyGuidanceLink(patient: p)
        else if (demoSession.canSeeClinicalRecord)
          FilledButton.icon(
            onPressed: week.isEmpty
                ? null
                : () => showSleepAssessmentSheet(context, p, week),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Registrar avaliação do sono no prontuário'),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

class _SleepingBanner extends StatelessWidget {
  const _SleepingBanner({required this.entry, required this.canEdit});

  final DiaryEntry entry;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final int wakes = entry.values.wakings.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAFF),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: const Color(0xFF5B3FD6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.bedtime_rounded, color: Color(0xFF5B3FD6)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${sleepTypeOf(entry).label} desde ${formatHm(entry.at)}'
                  '${sameDay(entry.at, demoSession.now) ? '' : ' de ${formatDm(entry.at)}'}'
                  '${wakes == 0 ? '' : ' - $wakes ${wakes == 1 ? 'despertar' : 'despertares'}'}',
                  style: t.titleSmall?.copyWith(
                    color: const Color(0xFF3A2596),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (canEdit) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _WakingDialog(entry: entry, host: context),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Despertar'),
                ),
                FilledButton(
                  onPressed: () {
                    demoSession.replaceDiaryEntry(
                      entry.finishedSleep(
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
          ],
        ],
      ),
    );
  }
}

/// Despertar durante o sono em andamento: horário e tempo acordado.
class _WakingDialog extends StatefulWidget {
  const _WakingDialog({required this.entry, required this.host});

  final DiaryEntry entry;
  final BuildContext host;

  @override
  State<_WakingDialog> createState() => _WakingDialogState();
}

class _WakingDialogState extends State<_WakingDialog> {
  final TextEditingController _at = TextEditingController(
    text: formatHm(demoSession.now),
  );
  int? _minutes;
  String? _error;

  @override
  void dispose() {
    _at.dispose();
    super.dispose();
  }

  void _save() {
    final ({int hour, int minute})? hm = parseHm(_at.text);
    if (hm == null) {
      setState(() => _error = 'Informe o horário (HH:MM).');
      return;
    }
    final DateTime now = demoSession.now;
    DateTime at = DateTime(now.year, now.month, now.day, hm.hour, hm.minute);
    if (at.isAfter(now)) at = addDays(at, -1);
    final SleepWaking w = SleepWaking(at: at, minutesAwake: _minutes);
    final List<String> errors = widget.entry.values
        .copyWith(wakings: <SleepWaking>[...widget.entry.values.wakings, w])
        .validate(DiaryKind.sono, now: now);
    if (errors.isNotEmpty) {
      setState(() => _error = errors.first);
      return;
    }
    demoSession.addWaking(widget.entry.id, w);
    Navigator.of(context).pop();
    showDemoSnack(widget.host, 'Despertar das ${formatHm(at)} registrado.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Despertar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _at,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Horário (HH:MM)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Quanto tempo ficou acordado (opcional)'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int m in <int>[5, 10, 15, 30, 60])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _minutes == m,
                  onSelected: (bool s) =>
                      setState(() => _minutes = s ? m : null),
                ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar despertar')),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final TextStyle? s = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted);
    Widget item(Color c, String label, {bool tick = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: tick ? 3 : 14,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: s),
      ],
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      children: <Widget>[
        item(kNightColor, 'Sono noturno'),
        item(kNapColor, 'Cochilo'),
        item(kWakingColor, 'Despertar', tick: true),
      ],
    );
  }
}

const double _labelWidth = 64;

class _HourAxis extends StatelessWidget {
  const _HourAxis();

  @override
  Widget build(BuildContext context) {
    final TextStyle? s = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted);
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          const SizedBox(width: _labelWidth),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final String h in <String>[
                  '0h',
                  '6h',
                  '12h',
                  '18h',
                  '24h',
                ])
                  Text(h, style: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Um dia do calendário (0h a 24h): trechos de sono e despertares.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.entries,
    required this.selected,
    required this.onTap,
  });

  final SleepDay day;
  final List<DiaryEntry> entries;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final ({List<SleepSegment> segments, List<int> wakings}) s = sleepOnDay(
      entries,
      day.day,
      now: demoSession.now,
    );
    final String weekday = kWeekdayShort[day.day.weekday - 1];
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '$weekday ${formatDm(day.day)}: ${day.describe()}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1EDFF) : null,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _labelWidth,
                child: Text(
                  '$weekday ${formatDm(day.day)}',
                  style: t.labelMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final double w = c.maxWidth;
                    double x(int minute) => w * minute / 1440;
                    return SizedBox(
                      height: 22,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FA),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.line),
                              ),
                            ),
                          ),
                          for (final int h in <int>[6, 12, 18])
                            Positioned(
                              left: x(h * 60),
                              top: 0,
                              bottom: 0,
                              child: Container(width: 1, color: AppColors.line),
                            ),
                          for (final SleepSegment g in s.segments)
                            Positioned(
                              left: x(g.fromMinute),
                              width: (x(g.toMinute) - x(g.fromMinute)).clamp(
                                2.0,
                                w,
                              ),
                              top: 3,
                              bottom: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: g.type == SleepType.night
                                      ? kNightColor
                                      : kNapColor,
                                  borderRadius: BorderRadius.circular(3),
                                  border: g.open
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          for (final int m in s.wakings)
                            Positioned(
                              left: (x(m) - 1.5).clamp(0.0, w - 3),
                              top: 0,
                              bottom: 0,
                              child: Container(width: 3, color: kWakingColor),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Família: orientações emitidas pela clínica para esta criança.
class _FamilyGuidanceLink extends StatelessWidget {
  const _FamilyGuidanceLink({required this.patient});

  final DemoPatient patient;

  @override
  Widget build(BuildContext context) {
    final int n = demoSession.familyOrientations(patient.id).length;
    return OutlinedButton.icon(
      onPressed: () => context.go('/rotina/${patient.id}/orientacoes'),
      icon: const Icon(Icons.menu_book_outlined),
      label: Text(
        n == 0 ? 'Orientações da clínica' : 'Orientações da clínica ($n)',
      ),
    );
  }
}

/// Profissional: texto do diário, revisado e completado, vira uma evolução
/// "Avaliação do sono" no prontuário.
Future<void> showSleepAssessmentSheet(
  BuildContext context,
  DemoPatient patient,
  SleepWeek week,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _SleepAssessmentSheet(patient: patient, week: week, host: context),
    ),
  );
}

class _SleepAssessmentSheet extends StatefulWidget {
  const _SleepAssessmentSheet({
    required this.patient,
    required this.week,
    required this.host,
  });

  final DemoPatient patient;
  final SleepWeek week;
  final BuildContext host;

  @override
  State<_SleepAssessmentSheet> createState() => _SleepAssessmentSheetState();
}

class _SleepAssessmentSheetState extends State<_SleepAssessmentSheet> {
  late final TextEditingController _family = TextEditingController(
    text: widget.week.toClinicalText(),
  );
  final TextEditingController _assessment = TextEditingController();
  bool _reviewed = false;
  String? _error;

  @override
  void dispose() {
    _family.dispose();
    _assessment.dispose();
    super.dispose();
  }

  void _save() {
    if (_assessment.text.trim().isEmpty) {
      setState(() => _error = 'Escreva a sua avaliação.');
      return;
    }
    if (!_reviewed) {
      setState(
        () => _error = 'Confirme que revisou os dados informados pela família.',
      );
      return;
    }
    demoSession.addSleepAssessment(
      widget.patient.id,
      '${_family.text.trim()}\n\nAvaliação: ${_assessment.text.trim()}',
    );
    Navigator.of(context).pop();
    showDemoSnack(widget.host, 'Avaliação do sono registrada no prontuário.');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
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
          Text(
            'Avaliação do sono',
            style: t.titleLarge?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${widget.patient.name} - ${widget.week.periodLabel()}',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('sono-dados-familia'),
            controller: _family,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Dados da família (edite antes de salvar)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('sono-avaliacao'),
            controller: _assessment,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Sua avaliação',
              alignLabelWithHint: true,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _reviewed,
            onChanged: (bool? v) => setState(() => _reviewed = v ?? false),
            title: const Text('Revisei os dados informados pela família'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _error!,
                style: t.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          FilledButton(
            onPressed: _save,
            child: const Text('Salvar no prontuário'),
          ),
        ],
      ),
    );
  }
}
