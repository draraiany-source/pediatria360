import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/audit_trail.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/patient_timeline.dart';
import '../../shared/wellchild/milestones.dart';
import '../../shared/wellchild/well_child_visit.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_workspace.dart';
import '../widgets/demo_widgets.dart';

/// Seções comparáveis de qualquer consulta (comum ou de puericultura).
List<(String, String)> consultationSections(DemoConsultation c) {
  final WellChildVisit? w = c.wellChild;
  if (w == null) {
    return <(String, String)>[
      ('Queixa', c.complaint),
      ('Anamnese', c.history),
      ('Exame físico', c.physicalExam),
      ('Avaliação', c.assessment),
      ('Conduta', c.plan),
      ('Plano de retorno', c.returnPlan),
    ];
  }
  return <(String, String)>[
    ('Queixa', 'Consulta de puericultura'),
    ('Anamnese', w.field(WellChildSection.historia)),
    ('Alimentação', w.field(WellChildSection.alimentacao)),
    ('Exame físico', w.field(WellChildSection.exameFisico)),
    ('Desenvolvimento', w.field(WellChildSection.desenvolvimento)),
    ('Avaliação', w.field(WellChildSection.avaliacao)),
    ('Conduta', w.field(WellChildSection.plano)),
    (
      'Plano de retorno',
      w.nextVisit == null
          ? ''
          : 'Próxima consulta sugerida: ${demoDate(w.nextVisit!)}',
    ),
  ];
}

GrowthMeasurement? visitMeasurement(DemoConsultation c) => measurementForVisit(
  demoSession.growthFor(c.patientId),
  consultationId: c.id,
  date: c.startedAt,
);

IconData _kindIcon(TimelineKind k) => switch (k) {
  TimelineKind.consulta => Icons.medical_services_outlined,
  TimelineKind.evolucao => Icons.edit_note_rounded,
  TimelineKind.receita => Icons.medication_outlined,
  TimelineKind.atestado => Icons.verified_outlined,
  TimelineKind.encaminhamento => Icons.forward_to_inbox_outlined,
  TimelineKind.exame => Icons.biotech_outlined,
  TimelineKind.orientacao => Icons.menu_book_outlined,
  TimelineKind.crescimento => Icons.show_chart_rounded,
  TimelineKind.preConsulta => Icons.assignment_outlined,
  TimelineKind.agenda => Icons.event_busy_outlined,
};

Widget _missing(BuildContext context, String title) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: DemoEmpty(
    title: 'Paciente não encontrado',
    message: 'Volte para a lista de pacientes.',
    actionLabel: 'Pacientes',
    onAction: () => context.go('/pacientes'),
  ),
);

/// Linha do tempo do paciente: consultas, evoluções, documentos, exames,
/// crescimento, pré-consultas, faltas e cancelamentos.
class DemoPatientHistoryScreen extends StatefulWidget {
  const DemoPatientHistoryScreen({
    required this.patientId,
    super.key,
    this.filter,
  });

  final String patientId;

  /// `tipo` da URL (nome de [TimelineKind]).
  final String? filter;

  @override
  State<DemoPatientHistoryScreen> createState() =>
      _DemoPatientHistoryScreenState();
}

class _DemoPatientHistoryScreenState extends State<DemoPatientHistoryScreen> {
  late final Set<TimelineKind> _only = <TimelineKind>{
    for (final TimelineKind k in TimelineKind.values)
      if (k.name == widget.filter) k,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        if (p == null) return _missing(context, 'Histórico de consultas');
        final DemoWorkspace ws = demoSession.workspace;
        final List<TimelineEvent> all = ws.timelineFor(p.id);
        final List<TimelineEvent> events = buildTimeline(all, only: _only);
        final Set<TimelineKind> present = all
            .map((TimelineEvent e) => e.kind)
            .toSet();
        final int visits = all
            .where((TimelineEvent e) => e.kind == TimelineKind.consulta)
            .length;
        final String base = '/pacientes/${p.id}';
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(base)),
            title: Text('Histórico - ${p.name}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '$visits consulta(s) - ${all.length} registro(s) '
                            'na linha do tempo',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: visits < 2
                                    ? null
                                    : () => context.go(
                                        '$base/historico/comparar',
                                      ),
                                icon: const Icon(Icons.compare_arrows_rounded),
                                label: const Text('Comparar consultas'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go('$base/crescimento'),
                                icon: const Icon(Icons.show_chart_rounded),
                                label: const Text('Curvas de crescimento'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go('$base/observacoes'),
                                icon: const Icon(Icons.sticky_note_2_outlined),
                                label: const Text('Observações'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go('$base/historico/alteracoes'),
                                icon: const Icon(Icons.manage_history_rounded),
                                label: const Text('Registro de alterações'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        FilterChip(
                          label: const Text('Tudo'),
                          selected: _only.isEmpty,
                          onSelected: (_) => setState(_only.clear),
                        ),
                        for (final TimelineKind k in TimelineKind.values)
                          if (present.contains(k))
                            FilterChip(
                              label: Text(k.label),
                              selected: _only.contains(k),
                              onSelected: (bool on) => setState(() {
                                if (on) {
                                  _only.add(k);
                                } else {
                                  _only.remove(k);
                                }
                              }),
                            ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (events.isEmpty)
                      const DemoNotice(
                        text: 'Nada registrado com esse filtro.',
                      ),
                    for (final TimelineEvent e in events) _EventTile(event: e),
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

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final TimelineEvent e = event;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 76,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  demoDate(e.at),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Column(
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.softBlue,
                  child: Icon(
                    _kindIcon(e.kind),
                    size: 16,
                    color: AppColors.brand,
                  ),
                ),
                const Expanded(
                  child: VerticalDivider(width: 28, color: AppColors.line),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: e.route == null ? null : () => context.go(e.route!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            e.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (e.draft) const DemoTag('Rascunho'),
                      ],
                    ),
                    if (e.detail != null && e.detail!.isNotEmpty)
                      Text(
                        e.detail!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      <String>[
                        e.kind.label,
                        if (e.author != null) e.author!,
                      ].join(' - '),
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
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

/// Duas consultas lado a lado, com medidas, velocidade de crescimento e
/// marcos do desenvolvimento ao longo do tempo.
class DemoCompareVisitsScreen extends StatelessWidget {
  const DemoCompareVisitsScreen({
    required this.patientId,
    super.key,
    this.first,
    this.second,
  });

  final String patientId;
  final String? first;
  final String? second;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        if (p == null) return _missing(context, 'Comparar consultas');
        final List<DemoConsultation> visits =
            demoSession.consultationsFor(p.id).toList()..sort(
              (DemoConsultation a, DemoConsultation b) =>
                  a.startedAt.compareTo(b.startedAt),
            );
        final String base = '/pacientes/${p.id}/historico';
        DemoConsultation? pick(String? id) =>
            visits.where((DemoConsultation c) => c.id == id).firstOrNull;
        final List<DemoConsultation> finished = visits
            .where((DemoConsultation c) => !c.isDraft)
            .toList();
        final List<DemoConsultation> pool = finished.length >= 2
            ? finished
            : visits;
        final DemoConsultation? a =
            pick(first) ??
            (pool.length >= 2 ? pool[pool.length - 2] : pool.firstOrNull);
        final DemoConsultation? b = pick(second) ?? pool.lastOrNull;
        String go(String? x, String? y) =>
            '$base/comparar?a=${x ?? ''}&b=${y ?? ''}';
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(base)),
            title: Text('Comparar consultas - ${p.name}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (visits.length < 2)
                      const DemoNotice(
                        text:
                            'É preciso ao menos duas consultas para comparar.',
                      ),
                    _Picker(
                      label: 'Consulta A',
                      visits: visits,
                      selected: a,
                      onPick: (DemoConsultation c) =>
                          context.go(go(c.id, b?.id)),
                    ),
                    _Picker(
                      label: 'Consulta B',
                      visits: visits,
                      selected: b,
                      onPick: (DemoConsultation c) =>
                          context.go(go(a?.id, c.id)),
                    ),
                    if (a != null && b != null) ...<Widget>[
                      const DemoSectionTitle('Registro'),
                      _CompareTable(a: a, b: b),
                      const DemoSectionTitle('Crescimento entre as consultas'),
                      _GrowthCompare(a: a, b: b),
                    ],
                    const DemoSectionTitle('Medidas ao longo do tempo'),
                    _GrowthHistory(patientId: p.id),
                    const DemoSectionTitle('Desenvolvimento ao longo do tempo'),
                    _MilestoneHistory(visits: visits, a: a, b: b),
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

String _visitLabel(DemoConsultation c) =>
    '${demoDate(c.startedAt)} - '
    '${c.isWellChild ? 'Puericultura' : 'Consulta'}'
    '${c.isDraft ? ' (rascunho)' : ''}';

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.visits,
    required this.selected,
    required this.onPick,
  });

  final String label;
  final List<DemoConsultation> visits;
  final DemoConsultation? selected;
  final ValueChanged<DemoConsultation> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final DemoConsultation c in visits)
                ChoiceChip(
                  label: Text(_visitLabel(c)),
                  tooltip: '$label: ${_visitLabel(c)}',
                  selected: selected?.id == c.id,
                  onSelected: (_) => onPick(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.a, required this.b});

  final DemoConsultation a;
  final DemoConsultation b;

  @override
  Widget build(BuildContext context) {
    final Map<String, String> left = <String, String>{
      for (final (String k, String v) in consultationSections(a)) k: v,
    };
    final Map<String, String> right = <String, String>{
      for (final (String k, String v) in consultationSections(b)) k: v,
    };
    final List<String> keys = <String>[
      ...left.keys,
      for (final String k in right.keys)
        if (!left.containsKey(k)) k,
    ];
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    Widget cell(String text, {bool head = false}) => Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        text.trim().isEmpty ? '-' : text.trim(),
        style: head ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
    final List<(String, String, String)> rows = <(String, String, String)>[
      ('Data', _visitLabel(a), _visitLabel(b)),
      ('Profissional', a.author, b.author),
      for (final String k in keys) (k, left[k] ?? '', right[k] ?? ''),
    ];
    if (!wide) {
      return Column(
        children: <Widget>[
          for (final (String k, String l, String r) in rows)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(k, style: Theme.of(context).textTheme.titleSmall),
                    Text('A: ${l.trim().isEmpty ? '-' : l.trim()}'),
                    Text('B: ${r.trim().isEmpty ? '-' : r.trim()}'),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Card(
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(150),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.line),
        ),
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              cell('', head: true),
              cell('Consulta A', head: true),
              cell('Consulta B', head: true),
            ],
          ),
          for (final (String k, String l, String r) in rows)
            TableRow(children: <Widget>[cell(k, head: true), cell(l), cell(r)]),
        ],
      ),
    );
  }
}

String _signed(double v, int digits) =>
    '${v >= 0 ? '+' : '-'}${formatGrowthNumber(v.abs(), digits)}';

class _GrowthCompare extends StatelessWidget {
  const _GrowthCompare({required this.a, required this.b});

  final DemoConsultation a;
  final DemoConsultation b;

  @override
  Widget build(BuildContext context) {
    final GrowthMeasurement? ma = visitMeasurement(a);
    final GrowthMeasurement? mb = visitMeasurement(b);
    if (ma == null || mb == null) {
      return DemoNotice(
        text:
            'Sem medida registrada perto de '
            '${ma == null ? demoDate(a.startedAt) : demoDate(b.startedAt)}: '
            'não há como comparar o crescimento.',
      );
    }
    final (
      GrowthValues older,
      GrowthValues newer,
    ) = ma.values.date.isAfter(mb.values.date)
        ? (mb.values, ma.values)
        : (ma.values, mb.values);
    final GrowthDelta d = compareGrowth(older, newer);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('A: ${ma.values.summary()}'),
          Text('B: ${mb.values.summary()}'),
          const Divider(height: AppSpacing.lg),
          Text(
            'Intervalo: ${d.days} dia(s)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (d.weightKg != null)
            Text(
              'Peso: ${_signed(d.weightKg!, 3)} kg'
              '${d.gramsPerDay == null ? '' : ' (${_signed(d.gramsPerDay!, 0)} g/dia)'}',
            ),
          if (d.lengthCm != null)
            Text(
              'Comprimento/altura: ${_signed(d.lengthCm!, 1)} cm'
              '${d.cmPerMonth == null ? '' : ' (${formatGrowthNumber(d.cmPerMonth!, 1)} cm/mês)'}',
            ),
          if (d.headCm != null)
            Text('Perímetro cefálico: ${_signed(d.headCm!, 1)} cm'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Diferença simples entre as medidas. Interprete com as curvas da '
            'OMS e o contexto clínico.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GrowthHistory extends StatelessWidget {
  const _GrowthHistory({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final List<GrowthMeasurement> all =
        demoSession
            .growthFor(patientId)
            .where((GrowthMeasurement m) => !m.voided)
            .toList()
          ..sort(
            (GrowthMeasurement a, GrowthMeasurement b) =>
                a.values.date.compareTo(b.values.date),
          );
    if (all.isEmpty) {
      return const DemoNotice(text: 'Nenhuma medida registrada.');
    }
    return Card(
      child: Column(
        children: <Widget>[
          for (final (int i, GrowthMeasurement m) in all.indexed)
            ListTile(
              dense: true,
              title: Text(m.values.summary()),
              subtitle: i == 0
                  ? const Text('Primeira medida')
                  : Text(_deltaText(all[i - 1].values, m.values)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/pacientes/$patientId/crescimento'),
              icon: const Icon(Icons.show_chart_rounded),
              label: const Text('Ver curvas de crescimento'),
            ),
          ),
        ],
      ),
    );
  }

  static String _deltaText(GrowthValues older, GrowthValues newer) {
    final GrowthDelta d = compareGrowth(older, newer);
    return <String>[
      'Desde a anterior (${d.days} dias)',
      if (d.gramsPerDay != null) '${_signed(d.gramsPerDay!, 0)} g/dia',
      if (d.cmPerMonth != null)
        '${formatGrowthNumber(d.cmPerMonth!, 1)} cm/mês',
    ].join(' - ');
  }
}

class _MilestoneHistory extends StatelessWidget {
  const _MilestoneHistory({required this.visits, this.a, this.b});

  final List<DemoConsultation> visits;
  final DemoConsultation? a;
  final DemoConsultation? b;

  @override
  Widget build(BuildContext context) {
    final List<DemoConsultation> wc = visits
        .where(
          (DemoConsultation c) =>
              c.isWellChild && c.wellChild!.milestones.isNotEmpty,
        )
        .toList();
    if (wc.isEmpty) {
      return const DemoNotice(
        text: 'Nenhum marco registrado em consultas de puericultura.',
      );
    }
    final DemoConsultation? left = a;
    final DemoConsultation? right = b;
    if (left != null &&
        right != null &&
        left.isWellChild &&
        right.isWellChild &&
        left.id != right.id) {
      final Map<String, MilestoneObservation> l =
          <String, MilestoneObservation>{
            for (final MilestoneObservation m in left.wellChild!.milestones)
              m.code: m,
          };
      final Map<String, MilestoneObservation> r =
          <String, MilestoneObservation>{
            for (final MilestoneObservation m in right.wellChild!.milestones)
              m.code: m,
          };
      final List<String> codes = <String>[
        ...l.keys,
        for (final String c in r.keys)
          if (!l.containsKey(c)) c,
      ];
      return Card(
        child: Column(
          children: <Widget>[
            for (final String code in codes)
              ListTile(
                dense: true,
                title: Text((l[code] ?? r[code])!.title),
                subtitle: Text(
                  'A: ${l[code]?.state.label ?? 'não avaliado'} - '
                  'B: ${r[code]?.state.label ?? 'não avaliado'}',
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final DemoConsultation c in wc)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ExpansionTile(
              title: Text('Puericultura de ${demoDate(c.startedAt)}'),
              subtitle: Text(_counts(c.wellChild!.milestones)),
              children: <Widget>[
                for (final MilestoneObservation m in c.wellChild!.milestones)
                  ListTile(
                    dense: true,
                    title: Text(m.title),
                    subtitle: Text('${m.area.label} - ${m.state.label}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _counts(List<MilestoneObservation> ms) => <String>[
    for (final MilestoneState s in MilestoneState.values)
      if (ms.any((MilestoneObservation m) => m.state == s))
        '${s.label}: ${ms.where((MilestoneObservation m) => m.state == s).length}',
  ].join(' - ');
}

/// Quem fez o quê, quando, nos registros do paciente.
class DemoAuditScreen extends StatelessWidget {
  const DemoAuditScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        if (p == null) return _missing(context, 'Registro de alterações');
        final List<AuditEntry> entries = demoSession.workspace.auditFor(p.id);
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.go('/pacientes/${p.id}/historico'),
            ),
            title: Text('Registro de alterações - ${p.name}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoNotice(
                      icon: Icons.manage_history_rounded,
                      text:
                          'Nesta demonstração o registro fica só nesta aba. '
                          'No aplicativo real, ele é gravado no servidor e '
                          'não pode ser editado.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (entries.isEmpty)
                      const DemoNotice(text: 'Nenhuma alteração registrada.'),
                    for (final AuditEntry e in entries) AuditTile(entry: e),
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

class AuditTile extends StatelessWidget {
  const AuditTile({required this.entry, super.key});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final AuditEntry e = entry;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.history_edu_rounded, color: AppColors.brand),
        title: Text('${e.entity.label}: ${e.action}'),
        subtitle: Text(
          <String>[
            '${demoDate(e.at)} às ${demoTime(e.at)} - ${e.actor}',
            if (e.detail != null && e.detail!.isNotEmpty) e.detail!,
          ].join('\n'),
        ),
      ),
    );
  }
}
