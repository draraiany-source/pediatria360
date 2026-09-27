import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/growth_pdf.dart';
import '../../shared/clinical/pdf_output.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_growth.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/growth_chart.dart';

String _growthPath(String patientId, String? consultationId) =>
    '/pacientes/$patientId/crescimento'
    '${consultationId == null ? '' : '?consulta=$consultationId'}';

String _patientBack(String patientId, String? consultationId) =>
    consultationId == null
    ? '/pacientes/$patientId'
    : '/pacientes/$patientId/consulta/$consultationId?etapa=avaliacao';

GrowthSex _sexOf(DemoPatient p) =>
    GrowthSex.fromLabel(p.sexLabel) ?? GrowthSex.female;

String _referenceShort(WhoLookup l) =>
    '${l.referenceId == 'who2006' ? 'OMS 2006 (Padrões 0 a 5 anos)' : 'OMS 2007 (Referência 5 a 19 anos)'}'
    '${l.measure == null ? '' : (l.measure == 'length' ? ' - comprimento' : ' - altura')}';

Widget _loading() => const Center(
  child: Padding(
    padding: EdgeInsets.all(AppSpacing.xl),
    child: CircularProgressIndicator(semanticsLabel: 'Carregando curvas'),
  ),
);

class DemoGrowthScreen extends StatefulWidget {
  const DemoGrowthScreen({
    required this.patientId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String? consultationId;

  @override
  State<DemoGrowthScreen> createState() => _DemoGrowthScreenState();
}

class _DemoGrowthScreenState extends State<DemoGrowthScreen> {
  final Future<WhoGrowthTables> _tables = loadWhoTables();
  GrowthIndicator _indicator = GrowthIndicator.weightForAge;
  GrowthWindow? _window;
  bool _exporting = false;

  String get _back => _patientBack(widget.patientId, widget.consultationId);

  Future<void> _export(
    DemoPatient p,
    WhoGrowthTables tables,
    PdfDelivery delivery,
  ) async {
    setState(() => _exporting = true);
    try {
      final DateTime now = DateTime.now();
      final Uint8List bytes = await GrowthPdf.build(
        tables: tables,
        measurements: demoSession.growthFor(p.id),
        sex: _sexOf(p),
        patientName: p.name,
        birthDate: p.birthDate,
        gestationalAgeDays: p.gestationalAgeDays,
        guardianName: p.guardianName,
        professionalName: DemoProfessional.name,
        professionalRegistry: DemoProfessional.registry,
        clinicName: DemoProfessional.clinic,
        now: now,
        demo: true,
      );
      final String name = GrowthPdf.fileName(p.name, now);
      final String? how = await deliverPdf(
        bytes,
        fileName: name,
        delivery: delivery,
      );
      demoSession.recordPdf(
        name,
        bytes,
        delivery == PdfDelivery.print ? 'print' : 'download',
      );
      if (!mounted) return;
      showDemoSnack(
        context,
        how == null
            ? 'PDF gerado, mas este navegador não permitiu a saída.'
            : delivery == PdfDelivery.print
            ? 'PDF das curvas aberto para impressão.'
            : 'PDF das curvas gerado ($name).',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Crescimento')),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message:
                  'Este registro não existe ou não pertence ao perfil atual.',
              actionLabel: 'Voltar para a lista',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final bool pro = demoSession.canEditGrowth;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(_back),
            ),
            title: Text(pro ? 'Curva de crescimento' : 'Crescimento'),
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go(_back),
            backLabel: widget.consultationId == null
                ? 'Voltar ao paciente'
                : 'Voltar à consulta',
            primaryLabel: pro ? 'Nova medida' : null,
            primaryIcon: Icons.add_rounded,
            onPrimary: pro
                ? () => context.go(
                    '/pacientes/${p.id}/crescimento/nova'
                    '${widget.consultationId == null ? '' : '?consulta=${widget.consultationId}'}',
                  )
                : null,
          ),
          body: FutureBuilder<WhoGrowthTables>(
            future: _tables,
            initialData: loadedWhoTables,
            builder: (BuildContext context, AsyncSnapshot<WhoGrowthTables> s) {
              if (s.hasError) {
                return const DemoEmpty(
                  title: 'Não foi possível abrir as tabelas da OMS',
                  message: 'Recarregue a página para tentar de novo.',
                );
              }
              if (!s.hasData) return _loading();
              return _body(context, p, s.data!, pro);
            },
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    DemoPatient p,
    WhoGrowthTables tables,
    bool pro,
  ) {
    final GrowthCalculator calc = GrowthCalculator(tables);
    final GrowthSex sex = _sexOf(p);
    final List<GrowthMeasurement> all = demoSession.growthFor(p.id);
    final Map<GrowthIndicator, List<GrowthPoint>> series =
        <GrowthIndicator, List<GrowthPoint>>{
          for (final GrowthIndicator g in GrowthIndicator.values)
            g: calc.series(
              measurements: all,
              indicator: g,
              sex: sex,
              birthDate: p.birthDate,
              gestationalAgeDays: p.gestationalAgeDays,
            ),
        };
    final List<GrowthIndicator> indicators = <GrowthIndicator>[
      for (final GrowthIndicator g in GrowthIndicator.values)
        if (pro || series[g]!.isNotEmpty) g,
    ];
    if (!indicators.contains(_indicator) && indicators.isNotEmpty) {
      _indicator = indicators.first;
    }
    final List<GrowthPoint> points = series[_indicator] ?? <GrowthPoint>[];
    final List<GrowthWindow> windows = GrowthWindow.availableFor(
      _indicator,
      tables,
    );
    final GrowthAge today = GrowthAge.of(
      birthDate: p.birthDate,
      at: DateTime.now(),
      gestationalAgeDays: p.gestationalAgeDays,
    );
    final int lastDays = points.isEmpty
        ? today.referenceDays
        : points.last.age.referenceDays;
    GrowthWindow window =
        _window ?? GrowthWindow.forAge(lastDays < 0 ? 0 : lastDays);
    if (!windows.contains(window)) window = windows.last;
    final TextTheme t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        DemoContent(
          maxWidth: 980,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DemoPatientStrip(patient: p),
              const SizedBox(height: AppSpacing.md),
              if (!pro)
                const DemoNotice(
                  icon: Icons.family_restroom_outlined,
                  text:
                      'Visão para a família: os pontos são as medidas registradas '
                      'pelo pediatra sobre a faixa de referência da OMS. A '
                      'interpretação da curva é feita pelo pediatra na consulta.',
                ),
              if (!pro) const SizedBox(height: AppSpacing.md),
              _AgeCard(patient: p, today: today, tables: tables, pro: pro),
              const DemoSectionTitle('Indicador'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final GrowthIndicator g in indicators)
                    ChoiceChip(
                      label: Text(
                        pro
                            ? g.short
                            : (g == GrowthIndicator.lengthHeightForAge
                                  ? 'Altura'
                                  : g.short),
                      ),
                      selected: g == _indicator,
                      onSelected: (_) => setState(() {
                        _indicator = g;
                        _window = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final GrowthWindow w in windows)
                    ChoiceChip(
                      label: Text(w.label),
                      selected: w == window,
                      onSelected: (_) => setState(() => _window = w),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        Text(
                          '${_indicator.title} (${_indicator.unit})',
                          style: t.titleMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (pro)
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: _exporting || all.isEmpty
                                    ? null
                                    : () => _export(
                                        p,
                                        tables,
                                        PdfDelivery.download,
                                      ),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Exportar PDF'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _exporting || all.isEmpty
                                    ? null
                                    : () =>
                                          _export(p, tables, PdfDelivery.print),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Imprimir'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GrowthChart(
                      calc: calc,
                      indicator: _indicator,
                      sex: sex,
                      window: window,
                      points: points,
                      simple: !pro,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GrowthChartLegend(simple: !pro),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Referência: ${tables.references['who2006']} até 5 anos; '
                      '${tables.references['who2007']} depois. Tabelas LMS '
                      'oficiais da OMS.'
                      '${(p.gestationalAgeDays ?? 280) < GrowthAge.pretermBelowDays ? ' Prematuro: eixo pela idade corrigida até 24 meses.' : ''}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              DemoSectionTitle(pro ? 'Medidas e escores' : 'Últimas medidas'),
              if (points.isEmpty)
                SurfaceCard(
                  child: Text(
                    pro
                        ? 'Sem medidas deste indicador. Registre a primeira em "Nova medida".'
                        : 'Sem medidas deste indicador. O pediatra registra as medidas nas consultas.',
                  ),
                )
              else if (pro)
                for (final GrowthPoint pt in points.reversed)
                  _PointTile(
                    point: pt,
                    patientId: p.id,
                    consultationId: widget.consultationId,
                  )
              else
                for (final GrowthPoint pt in points.reversed.take(4))
                  _SimplePointTile(point: pt),
              if (pro) ...<Widget>[
                const DemoSectionTitle('Histórico de alterações'),
                _History(patient: p, measurements: all),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/pacientes/${p.id}'),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Retornar ao paciente'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgeCard extends StatelessWidget {
  const _AgeCard({
    required this.patient,
    required this.today,
    required this.tables,
    required this.pro,
  });

  final DemoPatient patient;
  final GrowthAge today;
  final WhoGrowthTables tables;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final int? ga = patient.gestationalAgeDays;
    final bool preterm = ga != null && ga < GrowthAge.pretermBelowDays;
    final WhoLookup? ref = today.referenceDays < 0
        ? null
        : tables.lookup(
            GrowthIndicator.lengthHeightForAge,
            _sexOf(patient),
            today.referenceDays,
          );
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v),
          ],
        ),
        style: t.bodyMedium,
      ),
    );
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          row(
            'Idade gestacional ao nascer',
            ga == null
                ? 'não informada'
                : '${formatGestationalAge(ga)}${preterm ? ' (prematuro)' : ''}',
          ),
          row('Idade cronológica hoje', formatAgeDays(today.chronologicalDays)),
          if (today.usesCorrected)
            row('Idade corrigida hoje', formatAgeDays(today.correctedDays!)),
          if (preterm && !today.usesCorrected)
            row(
              'Idade corrigida',
              'não se aplica após 24 meses de idade cronológica',
            ),
          row(
            'Referência usada hoje',
            ref == null
                ? 'antes do termo corrigido: referência neonatal (não incluída)'
                : _referenceShort(ref),
          ),
          if (pro)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _editGa(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Alterar idade gestacional'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editGa(BuildContext context) async {
    final TextEditingController weeks = TextEditingController(
      text: patient.gestationalAgeDays == null
          ? ''
          : '${patient.gestationalAgeDays! ~/ 7}',
    );
    final TextEditingController days = TextEditingController(
      text: patient.gestationalAgeDays == null
          ? ''
          : '${patient.gestationalAgeDays! % 7}',
    );
    final TextEditingController reason = TextEditingController();
    String? error;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => StatefulBuilder(
        builder: (BuildContext c, StateSetter set) => AlertDialog(
          title: const Text('Idade gestacional ao nascer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _GaFields(weeks: weeks, days: days),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da alteração *',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final (int?, String?) ga = _parseGa(weeks.text, days.text);
                if (ga.$2 != null) {
                  set(() => error = ga.$2);
                  return;
                }
                if (reason.text.trim().isEmpty) {
                  set(() => error = 'Informe o motivo da alteração.');
                  return;
                }
                demoSession.setGestationalAge(
                  patient,
                  ga.$1,
                  reason.text.trim(),
                );
                Navigator.of(c).pop(true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    weeks.dispose();
    days.dispose();
    reason.dispose();
    if (ok == true && context.mounted) {
      showDemoSnack(
        context,
        'Idade gestacional atualizada. A alteração ficou no histórico.',
      );
    }
  }
}

/// (dias, erro). Semanas vazias = não informada.
(int?, String?) _parseGa(String weeks, String days) {
  if (weeks.trim().isEmpty) return (null, null);
  final int? w = int.tryParse(weeks.trim());
  final int d = days.trim().isEmpty ? 0 : int.tryParse(days.trim()) ?? -1;
  if (w == null || w < 22 || w > 44) {
    return (null, 'Semanas de gestação entre 22 e 44.');
  }
  if (d < 0 || d > 6) return (null, 'Dias entre 0 e 6.');
  return (w * 7 + d, null);
}

class _GaFields extends StatelessWidget {
  const _GaFields({required this.weeks, required this.days});

  final TextEditingController weeks;
  final TextEditingController days;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: TextField(
          controller: weeks,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'IG ao nascer (semanas)',
            hintText: 'ex.: 39',
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: TextField(
          controller: days,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Dias (0 a 6)'),
        ),
      ),
    ],
  );
}

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.point,
    required this.patientId,
    this.consultationId,
  });

  final GrowthPoint point;
  final String patientId;
  final String? consultationId;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final GrowthPoint p = point;
    final GrowthMeasurement m = p.measurement;
    final int decimals = p.indicator == GrowthIndicator.weightForAge ? 3 : 1;
    final String value =
        '${formatGrowthNumber(p.measured, decimals)} ${p.indicator.unit}';
    final String age =
        'Idade ${formatAgeDays(p.age.chronologicalDays)}'
        '${p.age.usesCorrected ? ' - corrigida ${formatAgeDays(p.age.correctedDays!)}' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        formatGrowthDate(m.values.date),
                        style: t.titleSmall?.copyWith(color: AppColors.navy),
                      ),
                      Text(value, style: t.titleSmall),
                      if (m.wasCorrected)
                        const ClinicalBadge(
                          label: 'Corrigida',
                          color: AppColors.warning,
                        ),
                      if (m.consultationId != null)
                        const ClinicalBadge(
                          label: 'Consulta',
                          color: AppColors.brand,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(age, style: t.bodySmall),
                  if (p.z != null) ...<Widget>[
                    Text(
                      'Escore Z ${formatZ(p.z!)} - percentil ${formatPercentile(p.z!)}',
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Referência: ${_referenceShort(p.lookup!)}',
                      style: t.bodySmall,
                    ),
                  ] else
                    Text(
                      p.unavailable ?? 'Sem escore.',
                      style: t.bodySmall?.copyWith(color: AppColors.warning),
                    ),
                  if (p.adjustment != null)
                    Text(p.adjustment!, style: t.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Corrigir medida de ${formatGrowthDate(m.values.date)}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(
                '/pacientes/$patientId/crescimento/${m.id}/corrigir'
                '${consultationId == null ? '' : '?consulta=$consultationId'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimplePointTile extends StatelessWidget {
  const _SimplePointTile({required this.point});

  final GrowthPoint point;

  @override
  Widget build(BuildContext context) {
    final GrowthValues v = point.measurement.values;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.straighten_rounded, color: AppColors.brand),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatGrowthDate(v.date),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    <String>[
                      if (v.weightKg != null)
                        'Peso ${formatGrowthNumber(v.weightKg!, 3)} kg',
                      if (v.lengthCm != null)
                        '${v.position == MeasurePosition.lying ? 'Comprimento' : 'Altura'} '
                            '${formatGrowthNumber(v.lengthCm!, 1)} cm',
                      if (v.headCm != null)
                        'Perímetro cefálico ${formatGrowthNumber(v.headCm!, 1)} cm',
                    ].join(' - '),
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

class _History extends StatelessWidget {
  const _History({required this.patient, required this.measurements});

  final DemoPatient patient;
  final List<GrowthMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<(DateTime, String, String)> items =
        <(DateTime, String, String)>[
          for (final GrowthMeasurement m in measurements)
            for (final GrowthRevision r in m.revisions)
              (
                r.at,
                '${r.voided ? 'Lançamento anulado' : 'Medida corrigida'} - ${r.author}',
                'Motivo: ${r.reason}\nAntes: ${r.before.summary()}'
                    '${r.voided ? '' : '\nDepois: ${r.after.summary()}'}',
              ),
          for (final GestationalAgeChange c
              in demoSession.gestationalAgeChanges)
            if (c.patientId == patient.id)
              (
                c.at,
                'Idade gestacional alterada - ${c.author}',
                'Motivo: ${c.reason}\nAntes: '
                    '${c.before == null ? 'não informada' : formatGestationalAge(c.before!)}'
                    '\nDepois: ${c.after == null ? 'não informada' : formatGestationalAge(c.after!)}',
              ),
        ]..sort(
          ((DateTime, String, String) a, (DateTime, String, String) b) =>
              b.$1.compareTo(a.$1),
        );
    if (items.isEmpty) {
      return Text(
        'Nenhuma correção registrada. Correções mantêm o valor anterior aqui.',
        style: t.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (DateTime, String, String) i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${formatDocDateTime(i.$1)} - ${i.$2}',
                    style: t.titleSmall?.copyWith(color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(i.$3, style: t.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------ Nova medida / correção

class DemoGrowthEntryScreen extends StatefulWidget {
  const DemoGrowthEntryScreen({
    required this.patientId,
    super.key,
    this.measurementId,
    this.consultationId,
  });

  final String patientId;

  /// Presente = correção de uma medida existente.
  final String? measurementId;
  final String? consultationId;

  @override
  State<DemoGrowthEntryScreen> createState() => _DemoGrowthEntryScreenState();
}

class _DemoGrowthEntryScreenState extends State<DemoGrowthEntryScreen> {
  final Future<WhoGrowthTables> _tables = loadWhoTables();
  late final DemoPatient? _p = demoSession.patientById(widget.patientId);
  late final GrowthMeasurement? _m = widget.measurementId == null
      ? null
      : demoSession.measurementById(widget.measurementId!);
  final TextEditingController _date = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _length = TextEditingController();
  final TextEditingController _head = TextEditingController();
  final TextEditingController _gaWeeks = TextEditingController();
  final TextEditingController _gaDays = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  MeasurePosition? _position;
  bool _dirty = false;
  List<String> _errors = const <String>[];

  bool get _correcting => widget.measurementId != null;

  String get _back => _growthPath(widget.patientId, widget.consultationId);

  @override
  void initState() {
    super.initState();
    final DemoPatient? p = _p;
    if (p == null) return;
    final GrowthValues? v = _m?.values;
    final DateTime now = DateTime.now();
    _date.text = formatDocDate(
      v?.date ?? DateTime(now.year, now.month, now.day),
    );
    _weight.text = v?.weightKg == null
        ? ''
        : formatGrowthNumber(v!.weightKg!, 3);
    _length.text = v?.lengthCm == null
        ? ''
        : formatGrowthNumber(v!.lengthCm!, 1);
    _head.text = v?.headCm == null ? '' : formatGrowthNumber(v!.headCm!, 1);
    _position = v?.position;
    final int? ga = p.gestationalAgeDays;
    _gaWeeks.text = ga == null ? '' : '${ga ~/ 7}';
    _gaDays.text = ga == null ? '' : '${ga % 7}';
    for (final TextEditingController c in <TextEditingController>[
      _date,
      _weight,
      _length,
      _head,
      _gaWeeks,
      _gaDays,
      _reason,
    ]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _date,
      _weight,
      _length,
      _head,
      _gaWeeks,
      _gaDays,
      _reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final String t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  bool _badNumber(TextEditingController c) =>
      c.text.trim().isNotEmpty && _num(c) == null;

  MeasurePosition _positionFor(DateTime? date) {
    if (_position != null) return _position!;
    final DemoPatient p = _p!;
    final GrowthAge a = GrowthAge.of(
      birthDate: p.birthDate,
      at: date ?? DateTime.now(),
      gestationalAgeDays: p.gestationalAgeDays,
    );
    return a.referenceDays > 730
        ? MeasurePosition.standing
        : MeasurePosition.lying;
  }

  /// Valores do formulário ou `null` com a lista de erros preenchida.
  GrowthValues? _values({bool report = false}) {
    final DemoPatient p = _p!;
    final DateTime? date = parseDocDate(_date.text.trim());
    final List<String> errors = <String>[
      if (date == null) 'Data inválida (use dd/mm/aaaa).',
      if (_badNumber(_weight)) 'Peso: use só números (ex.: 9,85).',
      if (_badNumber(_length)) 'Comprimento/altura: use só números.',
      if (_badNumber(_head)) 'Perímetro cefálico: use só números.',
    ];
    final (int?, String?) ga = _parseGa(_gaWeeks.text, _gaDays.text);
    if (ga.$2 != null) errors.add(ga.$2!);
    GrowthValues? v;
    if (date != null) {
      v = GrowthValues(
        date: date,
        weightKg: _num(_weight),
        lengthCm: _num(_length),
        headCm: _num(_head),
        position: _positionFor(date),
      );
      errors.addAll(
        GrowthValues.validate(v, birthDate: p.birthDate, now: DateTime.now()),
      );
    }
    if (report) setState(() => _errors = errors);
    return errors.isEmpty ? v : null;
  }

  void _save() {
    final DemoPatient p = _p!;
    final GrowthValues? v = _values(report: true);
    if (v == null) return;
    final (int?, String?) ga = _parseGa(_gaWeeks.text, _gaDays.text);
    final DateTime now = DateTime.now();
    if (_correcting) {
      if (_reason.text.trim().isEmpty) {
        setState(() => _errors = <String>['Informe o motivo da correção.']);
        return;
      }
      try {
        demoSession.replaceMeasurement(
          p,
          _m!.correct(
            values: v,
            reason: _reason.text.trim(),
            author: demoSession.currentAuthor,
            at: now,
          ),
        );
      } on StateError catch (e) {
        if (ga.$1 == p.gestationalAgeDays) {
          setState(() => _errors = <String>[e.message]);
          return;
        }
      }
    } else {
      demoSession.addMeasurement(
        p,
        GrowthMeasurement(
          id: demoSession.newId('g'),
          patientId: p.id,
          values: v,
          author: demoSession.currentAuthor,
          recordedAt: now,
          consultationId: widget.consultationId,
        ),
      );
    }
    demoSession.setGestationalAge(
      p,
      ga.$1,
      _reason.text.trim().isEmpty
          ? 'Informada no registro de medidas'
          : _reason.text.trim(),
    );
    _dirty = false;
    showDemoSnack(
      context,
      _correcting
          ? 'Correção salva. O valor anterior ficou no histórico.'
          : 'Medida salva na curva de ${p.name.split(' ').first}.',
    );
    context.go(_back);
  }

  Future<void> _void() async {
    final DemoPatient p = _p!;
    final TextEditingController reason = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Anular lançamento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'A medida sai das curvas, mas continua no histórico com o motivo.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              container: true,
              child: TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Motivo *'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isNotEmpty) Navigator.of(c).pop(true);
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    final String why = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;
    demoSession.replaceMeasurement(
      p,
      _m!.voidEntry(
        reason: why,
        author: demoSession.currentAuthor,
        at: DateTime.now(),
      ),
    );
    _dirty = false;
    showDemoSnack(context, 'Lançamento anulado. Ele continua no histórico.');
    context.go(_back);
  }

  Future<void> _leave() async {
    if (!_dirty || await confirmDiscard(context)) {
      if (mounted) context.go(_back);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = _p;
    if (p == null || (_correcting && _m == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crescimento')),
        body: DemoEmpty(
          title: 'Registro não encontrado',
          message: 'Volte para a curva do paciente.',
          actionLabel: 'Pacientes',
          onAction: () => context.go('/pacientes'),
        ),
      );
    }
    final TextTheme t = Theme.of(context).textTheme;
    final DateTime? date = parseDocDate(_date.text.trim());
    final MeasurePosition position = _positionFor(date);
    Widget numField(
      TextEditingController c,
      String label,
      String suffix, {
      String? helper,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          errorText: _badNumber(c) ? 'Use só números.' : null,
        ),
      ),
    );
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          title: Text(_correcting ? 'Corrigir medida' : 'Nova medida'),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _leave,
          primaryLabel: _correcting ? 'Salvar correção' : 'Salvar medida',
          primaryIcon: Icons.save_outlined,
          onPrimary: _save,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DemoPatientStrip(patient: p),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.consultationId != null)
                    const DemoNotice(
                      icon: Icons.link_rounded,
                      text:
                          'Medida vinculada à consulta em andamento. Ao salvar, '
                          'volte à consulta pelo botão "Voltar à consulta".',
                    ),
                  if (_correcting) ...<Widget>[
                    DemoNotice(
                      icon: Icons.history_rounded,
                      color: AppColors.warning,
                      text:
                          'Correção: o valor atual (${_m!.values.summary()}) '
                          'fica no histórico com o motivo, o autor e a data.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _date,
                    decoration: const InputDecoration(
                      labelText: 'Data da medida *',
                      hintText: 'dd/mm/aaaa',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  numField(_weight, 'Peso', 'kg'),
                  numField(
                    _length,
                    position == MeasurePosition.lying
                        ? 'Comprimento'
                        : 'Altura',
                    'cm',
                  ),
                  Semantics(
                    container: true,
                    child: SegmentedButton<MeasurePosition>(
                      segments: <ButtonSegment<MeasurePosition>>[
                        for (final MeasurePosition m in MeasurePosition.values)
                          ButtonSegment<MeasurePosition>(
                            value: m,
                            label: Text(m.label),
                          ),
                      ],
                      selected: <MeasurePosition>{position},
                      onSelectionChanged: (Set<MeasurePosition> s) =>
                          setState(() {
                            _position = s.first;
                            _dirty = true;
                          }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: AppSpacing.md,
                    ),
                    child: Text(
                      'Até 24 meses a OMS usa comprimento (deitado); depois, altura '
                      '(em pé). Se a posição for outra, o cálculo ajusta 0,7 cm.',
                      style: t.bodySmall,
                    ),
                  ),
                  numField(_head, 'Perímetro cefálico', 'cm'),
                  _GaFields(weeks: _gaWeeks, days: _gaDays),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: AppSpacing.md,
                    ),
                    child: Text(
                      'Abaixo de 37 semanas, as curvas usam a idade corrigida até '
                      '24 meses de idade cronológica.',
                      style: t.bodySmall,
                    ),
                  ),
                  if (_correcting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Motivo da correção *',
                        ),
                      ),
                    ),
                  if (_errors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: DemoNotice(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        text: _errors.join('\n'),
                      ),
                    ),
                  const DemoSectionTitle('Prévia do cálculo'),
                  FutureBuilder<WhoGrowthTables>(
                    future: _tables,
                    initialData: loadedWhoTables,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<WhoGrowthTables> s,
                        ) {
                          if (!s.hasData) return _loading();
                          return _Preview(
                            patient: p,
                            calc: GrowthCalculator(s.data!),
                            values: _values(),
                            gaDays: _parseGa(_gaWeeks.text, _gaDays.text).$1,
                          );
                        },
                  ),
                  if (_correcting) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _void,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Anular lançamento'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.patient,
    required this.calc,
    required this.values,
    required this.gaDays,
  });

  final DemoPatient patient;
  final GrowthCalculator calc;
  final GrowthValues? values;
  final int? gaDays;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final GrowthValues? v = values;
    if (v == null || v.isEmpty) {
      return Text(
        'Preencha a data e ao menos uma medida para ver escore Z e percentil.',
        style: t.bodySmall,
      );
    }
    final GrowthMeasurement m = GrowthMeasurement(
      id: 'previa',
      patientId: patient.id,
      values: v,
      author: '',
      recordedAt: DateTime.now(),
    );
    final List<GrowthPoint> points = <GrowthPoint>[
      for (final GrowthIndicator g in GrowthIndicator.values)
        if (calc.assess(
              measurement: m,
              indicator: g,
              sex: _sexOf(patient),
              birthDate: patient.birthDate,
              gestationalAgeDays: gaDays,
            )
            case final GrowthPoint p)
          p,
    ];
    final GrowthAge age = GrowthAge.of(
      birthDate: patient.birthDate,
      at: v.date,
      gestationalAgeDays: gaDays,
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Idade na data: ${formatAgeDays(age.chronologicalDays)}'
            '${age.usesCorrected ? ' - corrigida ${formatAgeDays(age.correctedDays!)}' : ''}',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final GrowthPoint p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                p.z == null
                    ? '${p.indicator.short}: ${p.unavailable}'
                    : '${p.indicator.short}: escore Z ${formatZ(p.z!)}, '
                          'percentil ${formatPercentile(p.z!)} - ${_referenceShort(p.lookup!)}',
                style: t.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
