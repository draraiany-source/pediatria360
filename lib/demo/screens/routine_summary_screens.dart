import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/clinical/pdf_output.dart';
import '../../shared/routine/child_routine.dart';
import '../../shared/routine/routine_pdf.dart';
import '../demo_data.dart';
import '../demo_routine.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/routine_widgets.dart';
import 'routine_screens.dart';

Future<void> _downloadPdf(
  BuildContext context,
  DemoPatient p,
  String text,
  String guardian,
) async {
  final Uint8List bytes = await RoutinePdf.build(
    text: text,
    patientName: p.name,
    guardianName: guardian,
    demo: true,
  );
  final String name = RoutinePdf.fileName(p.name, demoSession.now);
  final String? how = await deliverPdf(
    bytes,
    fileName: name,
    delivery: PdfDelivery.download,
  );
  demoSession.recordPdf(name, bytes, 'download');
  if (!context.mounted) return;
  showDemoSnack(
    context,
    how == null
        ? 'PDF gerado ($name). Este navegador não permitiu baixar.'
        : 'PDF baixado: $name',
  );
}

Future<void> _copy(BuildContext context, String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showDemoSnack(
        context,
        'Texto copiado. Cole no aplicativo de mensagens, se preferir.',
      );
    }
  } on Object {
    if (context.mounted) {
      showDemoSnack(context, 'Não foi possível copiar neste navegador.');
    }
  }
}

Widget _textBox(BuildContext context, String text) => Semantics(
  container: true,
  label: 'Texto do resumo',
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.line),
    ),
    child: SelectableText(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.navy, height: 1.45),
    ),
  ),
);

enum _Period { hoje, semana, consulta, personalizado }

/// Resumo que a família monta e envia ao pediatra antes da consulta.
class DemoRoutineSummaryScreen extends StatefulWidget {
  const DemoRoutineSummaryScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<DemoRoutineSummaryScreen> createState() =>
      _DemoRoutineSummaryScreenState();
}

class _DemoRoutineSummaryScreenState extends State<DemoRoutineSummaryScreen> {
  _Period _period = _Period.semana;
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final Set<DiaryKind> _kinds = DiaryKind.values.toSet();
  bool _upcoming = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final DateTime today = dayOf(demoSession.now);
    _from.text = formatDmy(addDays(today, -6));
    _to.text = formatDmy(today);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _message.dispose();
    super.dispose();
  }

  (DateTime, DateTime)? _range(DateTime today) {
    switch (_period) {
      case _Period.hoje:
        return (today, today);
      case _Period.semana:
        return (addDays(today, -6), today);
      case _Period.consulta:
        final DateTime? last = demoSession.lastConsultationDay(
          widget.patientId,
        );
        return last == null ? null : (last, today);
      case _Period.personalizado:
        final DateTime? a = parseDmy(_from.text);
        final DateTime? b = parseDmy(_to.text);
        if (a == null || b == null || b.isBefore(a)) return null;
        return (a, b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(widget.patientId);
        if (p == null || !demoSession.canEditRoutine) {
          return DemoRoutineUnavailableScreen(patientId: widget.patientId);
        }
        final TextTheme t = Theme.of(context).textTheme;
        final DateTime now = demoSession.now;
        final DateTime today = dayOf(now);
        final DateTime? last = demoSession.lastConsultationDay(p.id);
        final (DateTime, DateTime)? range = _range(today);
        final RoutineSummary? summary = range == null
            ? null
            : RoutineSummary.build(
                entries: demoSession.diaryFor(p.id),
                from: range.$1,
                to: range.$2,
                kinds: _kinds,
                upcoming: _upcoming
                    ? demoSession
                          .routineItems(p.id, now, addDays(today, 15))
                          .where((CalendarItem i) => i.isPlanned)
                          .take(8)
                    : const <CalendarItem>[],
              );
        final String guardian = demoSession.routineAuthor;
        final String? text = summary?.toText(
          patientName: p.name,
          guardianName: guardian,
          generatedAt: now,
        );
        final bool shared = demoSession.routineSharedWith(p.id);
        final List<SharedRoutineSummary> sent = demoSession.sharedSummariesFor(
          p.id,
        );
        void back() => context.go(routineUrl(p.id));

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: back),
            title: const Text('Resumo para o pediatra'),
          ),
          body: DemoContent(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Text(
                  p.name,
                  style: t.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Escolha o período e os tipos de registro. O pediatra vê o '
                  'resumo marcado como "Informado pela família".',
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Período',
                  style: t.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ChoiceRow<_Period>(
                  options: <_Period>[
                    _Period.hoje,
                    _Period.semana,
                    if (last != null) _Period.consulta,
                    _Period.personalizado,
                  ],
                  selected: _period,
                  label: (_Period x) => switch (x) {
                    _Period.hoje => 'Hoje',
                    _Period.semana => 'Últimos 7 dias',
                    _Period.consulta =>
                      'Desde a última consulta (${formatDm(last!)})',
                    _Period.personalizado => 'Outro período',
                  },
                  onSelected: (_Period? x) =>
                      setState(() => _period = x ?? _period),
                ),
                if (_period == _Period.personalizado) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          container: true,
                          child: TextField(
                            controller: _from,
                            keyboardType: TextInputType.datetime,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'De (dd/mm/aaaa)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Semantics(
                          container: true,
                          child: TextField(
                            controller: _to,
                            keyboardType: TextInputType.datetime,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Até (dd/mm/aaaa)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Tipos de registro',
                        style: t.labelLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _kinds.length == DiaryKind.values.length
                            ? _kinds.clear()
                            : _kinds.addAll(DiaryKind.values);
                      }),
                      child: Text(
                        _kinds.length == DiaryKind.values.length
                            ? 'Limpar'
                            : 'Marcar todos',
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final DiaryKind k in DiaryKind.values)
                      FilterChip(
                        avatar: Icon(
                          diaryKindIcon(k),
                          size: 16,
                          color: diaryKindColor(k),
                        ),
                        label: Text(k.label),
                        selected: _kinds.contains(k),
                        onSelected: (bool v) => setState(
                          () => v ? _kinds.add(k) : _kinds.remove(k),
                        ),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir próximos compromissos'),
                  subtitle: const Text('Até 15 dias à frente'),
                  value: _upcoming,
                  onChanged: (bool v) => setState(() => _upcoming = v),
                ),
                DemoSectionTitle(
                  'Prévia',
                  trailing: summary == null
                      ? null
                      : Text(
                          '${summary.entries.length} registro(s)',
                          style: t.labelMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                ),
                if (text == null)
                  const DemoNotice(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.danger,
                    text:
                        'Confira as datas: use dd/mm/aaaa e o fim depois '
                        'do início.',
                  )
                else
                  _textBox(context, text),
                const DemoSectionTitle('Compartilhamento'),
                Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: BorderSide(color: AppColors.line),
                  ),
                  child: SwitchListTile(
                    title: const Text('Compartilhar a rotina com a clínica'),
                    subtitle: const Text(
                      'Ligado: o pediatra vê o calendário, o diário e os '
                      'resumos enviados, só para leitura. Você pode desligar '
                      'quando quiser.',
                    ),
                    value: shared,
                    onChanged: (bool v) {
                      demoSession.setRoutineSharing(p.id, v);
                      showDemoSnack(
                        context,
                        v
                            ? 'Rotina compartilhada com a clínica.'
                            : 'Compartilhamento desligado. A clínica deixa de '
                                  'ver a rotina.',
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  container: true,
                  child: TextField(
                    controller: _message,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mensagem para o pediatra (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!shared)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Ligue o compartilhamento para enviar pelo app. Você '
                      'ainda pode baixar o PDF ou copiar o texto.',
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed:
                          shared &&
                              summary != null &&
                              !summary.isEmpty &&
                              !_busy
                          ? () {
                              demoSession.shareSummary(
                                patientId: p.id,
                                summary: summary,
                                text: text!,
                                message: _message.text,
                              );
                              _message.clear();
                              showDemoSnack(
                                context,
                                'Resumo enviado ao pediatra. Ele aparece na '
                                'ficha da criança como informado pela família.',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Enviar ao pediatra'),
                    ),
                    OutlinedButton.icon(
                      onPressed: text == null || _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await _downloadPdf(context, p, text, guardian);
                              if (mounted) setState(() => _busy = false);
                            },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Baixar PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: text == null
                          ? null
                          : () => _copy(context, text),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar texto'),
                    ),
                  ],
                ),
                DemoSectionTitle('Resumos enviados (${sent.length})'),
                if (sent.isEmpty)
                  Text(
                    'Nenhum resumo enviado ainda.',
                    style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                  )
                else
                  for (final SharedRoutineSummary s in sent)
                    _SentTile(summary: s),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SentTile extends StatelessWidget {
  const _SentTile({required this.summary});

  final SharedRoutineSummary summary;

  @override
  Widget build(BuildContext context) {
    final SharedRoutineSummary s = summary;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: () => context.go('/rotina/${s.patientId}/resumos/${s.id}'),
        leading: const Icon(Icons.summarize_outlined, color: AppColors.brand),
        title: Text(
          sameDay(s.from, s.to)
              ? 'Resumo de ${formatDm(s.from)}'
              : 'Resumo de ${formatDm(s.from)} a ${formatDm(s.to)}',
        ),
        subtitle: Text(
          'Enviado por ${s.author} em ${formatDm(s.sentAt)} às '
          '${formatHm(s.sentAt)} - ${s.entryCount} registro(s)',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

/// Resumos que a família enviou (profissional e família veem).
class DemoSharedSummariesScreen extends StatelessWidget {
  const DemoSharedSummariesScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(patientId);
        if (p == null) {
          return DemoRoutineUnavailableScreen(patientId: patientId);
        }
        final List<SharedRoutineSummary> sent = demoSession.sharedSummariesFor(
          p.id,
        );
        final bool family = demoSession.canEditRoutine;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.go(
                family ? '/rotina/${p.id}/resumo' : '/pacientes/${p.id}',
              ),
            ),
            title: const Text('Resumos enviados pela família'),
          ),
          body: DemoContent(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Text(
                  p.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const DemoNotice(
                  icon: Icons.family_restroom_rounded,
                  color: Color(0xFF0B6B8A),
                  text:
                      'Informado pela família. Confira na consulta antes de '
                      'registrar no prontuário.',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!family)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go(routineUrl(p.id)),
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('Ver calendário e diário'),
                    ),
                  ),
                if (sent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: Text('Nenhum resumo enviado ainda.'),
                  )
                else
                  for (final SharedRoutineSummary s in sent)
                    _SentTile(summary: s),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DemoSharedSummaryScreen extends StatelessWidget {
  const DemoSharedSummaryScreen({
    required this.patientId,
    required this.summaryId,
    super.key,
  });

  final String patientId;
  final String summaryId;

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.routinePatient(patientId);
    if (p == null) {
      return DemoRoutineUnavailableScreen(patientId: patientId);
    }
    final SharedRoutineSummary? s = demoSession.sharedSummaryById(summaryId);
    final TextTheme t = Theme.of(context).textTheme;
    void back() => context.go('/rotina/${p.id}/resumos');
    if (s == null || s.patientId != p.id) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: back),
          title: const Text('Resumo enviado'),
        ),
        body: const DemoEmpty(
          title: 'Resumo não encontrado',
          message: 'Este resumo não existe ou não é desta criança.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: BackButton(onPressed: back),
        title: const Text('Resumo enviado'),
      ),
      body: DemoContent(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            const Align(
              alignment: Alignment.centerLeft,
              child: AuthorBadge(role: DiaryRole.familia),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enviado por ${s.author} em ${formatDmy(s.sentAt)} às '
              '${formatHm(s.sentAt)}',
              style: t.bodyMedium?.copyWith(color: AppColors.navy),
            ),
            Text(
              'Período: ${sameDay(s.from, s.to) ? formatDmy(s.from) : '${formatDmy(s.from)} a ${formatDmy(s.to)}'}'
              ' - ${s.entryCount} registro(s)',
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            if (s.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DemoNotice(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF0B6B8A),
                text: 'Mensagem da família: ${s.message}',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _textBox(context, s.text),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _downloadPdf(context, p, s.text, s.author),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Baixar PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copy(context, s.text),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar texto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
