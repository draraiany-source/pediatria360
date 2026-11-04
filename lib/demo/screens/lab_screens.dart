import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/file_input.dart';
import '../../shared/clinical/lab_results.dart';
import '../../shared/clinical/supplement_library.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';

const String _labRules =
    'Cada resultado guarda o intervalo de referência informado no próprio '
    'laudo: não há intervalo único por idade ou laboratório. O sistema não '
    'interpreta resultados nem gera diagnóstico ou prescrição. Laudos '
    'importados só entram no prontuário depois de conferidos.';

String _q(String? consultationId) =>
    consultationId == null ? '' : '?consulta=$consultationId';

String _labsPath(String patientId, String? consultationId) =>
    '/pacientes/$patientId/exames${_q(consultationId)}';

String _topicTitle(String id) => demoSession.sheetById(id)?.title ?? id;

Color _rangeColor(RangePosition p) => switch (p) {
  RangePosition.within => AppColors.success,
  _ => AppColors.warning,
};

/// Escolhe o arquivo do laudo e cria o resultado pendente de conferência.
Future<LabResult?> importLabReport(
  BuildContext context,
  DemoPatient p, {
  String? consultationId,
}) async {
  final PickedFile? f = await pickFile(accept: 'application/pdf,image/*');
  if (f == null || !context.mounted) return null;
  if (f.bytes.length > LabAttachment.maxBytes) {
    showDemoSnack(context, 'Arquivo acima de 10 MB. Envie um arquivo menor.');
    return null;
  }
  if (LabAttachment.sourceFor(f.mimeType) == null) {
    showDemoSnack(context, 'Envie o laudo em PDF ou imagem.');
    return null;
  }
  final LabResult r = LabResult.imported(
    id: demoSession.newId('l'),
    patientId: p.id,
    attachment: LabAttachment(
      name: f.name,
      mimeType: f.mimeType,
      bytes: f.bytes,
    ),
    author: demoSession.currentAuthor,
    now: DateTime.now(),
    consultationId: consultationId,
  );
  demoSession.saveLab(r);
  return r;
}

class DemoLabScreen extends StatefulWidget {
  const DemoLabScreen({
    required this.patientId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String? consultationId;

  @override
  State<DemoLabScreen> createState() => _DemoLabScreenState();
}

class _DemoLabScreenState extends State<DemoLabScreen> {
  String _search = '';
  String? _series;

  String get _back => widget.consultationId == null
      ? '/pacientes/${widget.patientId}'
      : '/pacientes/${widget.patientId}/consulta/${widget.consultationId}?etapa=avaliacao';

  Future<void> _import(DemoPatient p) async {
    final LabResult? r = await importLabReport(
      context,
      p,
      consultationId: widget.consultationId,
    );
    if (r == null || !mounted) return;
    showDemoSnack(
      context,
      'Laudo importado e pendente de conferência. Confira os campos com o arquivo.',
    );
    context.go(
      '/pacientes/${p.id}/exames/${r.id}/editar${_q(widget.consultationId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exames')),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message: 'Volte para a lista de pacientes.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final TextTheme t = Theme.of(context).textTheme;
        final List<LabResult> all = demoSession.labsFor(p.id);
        final List<LabResult> pending =
            all.where((LabResult r) => r.isPending).toList()..sort(
              (LabResult a, LabResult b) =>
                  b.recordedAt.compareTo(a.recordedAt),
            );
        final String q = LabSeries.normalize(_search);
        final List<LabResult> confirmed =
            all
                .where(
                  (LabResult r) =>
                      r.inRecord &&
                      (q.isEmpty ||
                          LabSeries.normalize(r.values.testName).contains(q)),
                )
                .toList()
              ..sort(
                (LabResult a, LabResult b) =>
                    b.values.collectedAt!.compareTo(a.values.collectedAt!),
              );
        final List<LabSeries> series = LabSeries.group(
          all,
        ).where((LabSeries s) => s.count >= 2).toList();
        final LabSeries? selected = series.isEmpty
            ? null
            : series.firstWhere(
                (LabSeries s) => s.testName == _series,
                orElse: () => series.first,
              );
        final Map<DateTime, List<LabResult>> byDate =
            <DateTime, List<LabResult>>{};
        for (final LabResult r in confirmed) {
          byDate.putIfAbsent(r.values.collectedAt!, () => <LabResult>[]).add(r);
        }

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(_back),
            ),
            title: const Text('Exames laboratoriais'),
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go(_back),
            backLabel: widget.consultationId == null
                ? 'Voltar ao paciente'
                : 'Voltar à consulta',
            primaryLabel: 'Novo resultado',
            primaryIcon: Icons.add_rounded,
            onPrimary: () => context.go(
              '/pacientes/${p.id}/exames/novo${_q(widget.consultationId)}',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 980,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DemoPatientStrip(patient: p),
                    const SizedBox(height: AppSpacing.md),
                    const DemoNotice(
                      icon: Icons.rule_rounded,
                      color: AppColors.warning,
                      text: _labRules,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _import(p),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Importar laudo (PDF ou imagem)'),
                        ),
                      ],
                    ),
                    if (pending.isNotEmpty) ...<Widget>[
                      DemoSectionTitle(
                        'Pendentes de conferência (${pending.length})',
                      ),
                      for (final LabResult r in pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PremiumCard(
                            borderColor: AppColors.warning,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.pending_actions_rounded,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        r.values.testName.isEmpty
                                            ? r.attachment?.name ??
                                                  'Laudo importado'
                                            : r.values.testName,
                                        style: t.titleSmall,
                                      ),
                                      Text(
                                        '${r.source.label} em ${formatDocDateTime(r.recordedAt)}. '
                                        'Fora do prontuário até a conferência.',
                                        style: t.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () => context.go(
                                    '/pacientes/${p.id}/exames/${r.id}/editar${_q(widget.consultationId)}',
                                  ),
                                  child: const Text('Conferir'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const DemoSectionTitle(
                      'Linha do tempo (resultados conferidos)',
                    ),
                    Semantics(
                      container: true,
                      child: TextField(
                        onChanged: (String v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          hintText: 'Buscar exame (ex.: ferritina)',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (confirmed.isEmpty)
                      SurfaceCard(
                        child: Text(
                          all.isEmpty
                              ? 'Nenhum exame registrado. Use "Novo resultado" ou importe um laudo.'
                              : 'Nenhum resultado conferido encontrado.',
                        ),
                      ),
                    for (final MapEntry<DateTime, List<LabResult>> e
                        in byDate.entries) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: 4,
                        ),
                        child: Text(
                          'Coleta em ${formatLabDate(e.key)}',
                          style: t.labelLarge?.copyWith(color: AppColors.navy),
                        ),
                      ),
                      for (final LabResult r in e.value)
                        _LabTile(
                          result: r,
                          onTap: () => context.go(
                            '/pacientes/${p.id}/exames/${r.id}${_q(widget.consultationId)}',
                          ),
                        ),
                    ],
                    const DemoSectionTitle('Comparar o mesmo exame no tempo'),
                    if (selected == null)
                      const SurfaceCard(
                        child: Text(
                          'A comparação aparece quando o mesmo exame tem dois ou mais resultados conferidos.',
                        ),
                      )
                    else ...<Widget>[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final LabSeries s in series)
                            ChoiceChip(
                              label: Text('${s.testName} (${s.count})'),
                              selected: s == selected,
                              onSelected: (_) =>
                                  setState(() => _series = s.testName),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SeriesView(series: selected),
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
          ),
        );
      },
    );
  }
}

class _LabTile extends StatelessWidget {
  const _LabTile({required this.result, required this.onTap});

  final LabResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final LabValues v = result.values;
    final RangePosition? pos = result.rangePosition;
    final DemoConsultation? c = result.consultationId == null
        ? null
        : demoSession.consultationById(result.consultationId!);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${v.testName}: ${v.value} ${v.unit}',
                    style: t.titleSmall?.copyWith(color: AppColors.navy),
                  ),
                  Text(
                    '${v.laboratory} - intervalo do laudo: '
                    '${v.range.isEmpty ? 'não informado' : v.range.label}',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      if (pos != null)
                        ClinicalBadge(
                          label: pos.label,
                          color: _rangeColor(pos),
                        ),
                      if (c != null)
                        ClinicalBadge(
                          label: 'Consulta ${formatLabDate(c.startedAt)}',
                          color: AppColors.brand,
                        ),
                      for (final String id in result.topicIds)
                        ClinicalBadge(
                          label: _topicTitle(id),
                          color: AppColors.tealDeep,
                        ),
                      if (result.attachment != null)
                        const ClinicalBadge(
                          label: 'Arquivo anexado',
                          color: AppColors.inkMuted,
                        ),
                      if (result.revisions.any(
                        (LabRevision r) => r.action == 'Corrigido',
                      ))
                        const ClinicalBadge(
                          label: 'Corrigido',
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SeriesView extends StatelessWidget {
  const _SeriesView({required this.series});

  final LabSeries series;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (series.hasMixedUnits)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: DemoNotice(
              icon: Icons.straighten_rounded,
              color: AppColors.warning,
              text:
                  'Há resultados em unidades diferentes. Eles aparecem separados '
                  'e não são convertidos nem comparados entre si.',
            ),
          ),
        for (final MapEntry<String, List<LabResult>> e in series.byUnit.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '${series.testName} (${e.key.isEmpty ? 'sem unidade' : e.key})',
                    style: t.titleSmall?.copyWith(color: AppColors.navy),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (e.value
                          .where((LabResult r) => r.values.numeric != null)
                          .length >=
                      2)
                    Semantics(
                      container: true,
                      label:
                          'Gráfico de ${series.testName}: '
                          '${e.value.map((LabResult r) => '${r.values.value} em ${formatLabDate(r.values.collectedAt!)}').join('; ')}.',
                      child: ExcludeSemantics(
                        child: SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _SeriesPainter(e.value, t.labelSmall!),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final LabResult r in e.value.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${formatLabDate(r.values.collectedAt!)}: ${r.values.value} ${r.values.unit} - '
                        '${r.values.laboratory} - intervalo do laudo: '
                        '${r.values.range.isEmpty ? 'não informado' : r.values.range.label}',
                        style: t.bodySmall,
                      ),
                    ),
                  Text(
                    'Cada ponto usa o intervalo do seu próprio laudo; laboratórios e '
                    'idades diferentes podem ter intervalos diferentes.',
                    style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter(this.results, this.style);

  final List<LabResult> results;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final List<LabResult> r = results
        .where((LabResult x) => x.values.numeric != null)
        .toList();
    if (r.length < 2) return;
    const double left = 44;
    const double bottom = 22;
    final Rect plot = Rect.fromLTRB(
      left,
      8,
      size.width - 12,
      size.height - bottom,
    );
    final double t0 = r.first.values.collectedAt!.millisecondsSinceEpoch
        .toDouble();
    final double t1 = math.max(
      t0 + 1,
      r.last.values.collectedAt!.millisecondsSinceEpoch.toDouble(),
    );
    double lo = r.map((LabResult x) => x.values.numeric!).reduce(math.min);
    double hi = r.map((LabResult x) => x.values.numeric!).reduce(math.max);
    final double pad = math.max((hi - lo) * 0.2, hi.abs() * 0.05 + 0.01);
    lo -= pad;
    hi += pad;
    Offset at(LabResult x) => Offset(
      plot.left +
          (x.values.collectedAt!.millisecondsSinceEpoch - t0) /
              (t1 - t0) *
              plot.width,
      plot.bottom - (x.values.numeric! - lo) / (hi - lo) * plot.height,
    );
    final TextStyle muted = style.copyWith(color: AppColors.inkMuted);
    void text(String s, Offset o, {bool right = false}) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: s, style: muted),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          right ? o.dx - tp.width : o.dx - tp.width / 2,
          o.dy - tp.height / 2,
        ),
      );
    }

    canvas.drawRect(
      plot,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.line,
    );
    text(formatLabNumber(hi), Offset(plot.left - 4, plot.top + 6), right: true);
    text(
      formatLabNumber(lo),
      Offset(plot.left - 4, plot.bottom - 6),
      right: true,
    );
    final Path path = Path();
    for (int i = 0; i < r.length; i++) {
      final Offset o = at(r[i]);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = AppColors.navy,
    );
    for (final LabResult x in r) {
      final Offset o = at(x);
      canvas.drawCircle(o, 4.5, Paint()..color = AppColors.brand);
      text(x.values.value, Offset(o.dx, o.dy - 12));
      text(
        formatLabDate(x.values.collectedAt!),
        Offset(o.dx, plot.bottom + 11),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) => old.results != results;
}

// ------------------------------------------------ Detalhe

class DemoLabDetailScreen extends StatelessWidget {
  const DemoLabDetailScreen({
    required this.patientId,
    required this.labId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String labId;
  final String? consultationId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        final LabResult? r = demoSession.labById(labId);
        final String back = _labsPath(patientId, consultationId);
        if (p == null || r == null || r.patientId != p.id) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exame')),
            body: DemoEmpty(
              title: 'Resultado não encontrado',
              message: 'Volte para os exames do paciente.',
              actionLabel: 'Exames',
              onAction: () => context.go(back),
            ),
          );
        }
        final TextTheme t = Theme.of(context).textTheme;
        final LabValues v = r.values;
        final DemoConsultation? c = r.consultationId == null
            ? null
            : demoSession.consultationById(r.consultationId!);
        Widget kv(String k, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$k: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
            style: t.bodyMedium,
          ),
        );
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(back),
            ),
            title: Text(v.testName.isEmpty ? 'Laudo importado' : v.testName),
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go(back),
            backLabel: 'Voltar aos exames',
            primaryLabel: r.isPending ? 'Conferir' : 'Corrigir',
            primaryIcon: r.isPending
                ? Icons.fact_check_outlined
                : Icons.edit_outlined,
            onPrimary: () => context.go(
              '/pacientes/${p.id}/exames/${r.id}/editar${_q(consultationId)}',
            ),
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
                    if (r.isPending)
                      const DemoNotice(
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                        text:
                            'Pendente de conferência: este resultado ainda não está '
                            'no prontuário nem nas comparações.',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 6,
                            children: <Widget>[
                              ClinicalBadge(
                                label: r.status.label,
                                color: r.isPending
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                              ClinicalBadge(
                                label: r.source.label,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          kv('Exame', v.testName.isEmpty ? '-' : v.testName),
                          kv(
                            'Resultado',
                            v.value.isEmpty ? '-' : '${v.value} ${v.unit}',
                          ),
                          kv(
                            'Data da coleta',
                            v.collectedAt == null
                                ? '-'
                                : formatLabDate(v.collectedAt!),
                          ),
                          kv(
                            'Laboratório',
                            v.laboratory.isEmpty ? '-' : v.laboratory,
                          ),
                          kv(
                            'Intervalo de referência do laudo',
                            v.range.isEmpty ? 'não informado' : v.range.label,
                          ),
                          if (r.rangePosition != null)
                            kv(
                              'Posição no intervalo do laudo',
                              r.rangePosition!.label,
                            ),
                          kv(
                            'Consulta',
                            c == null
                                ? 'sem vínculo'
                                : '${formatLabDate(c.startedAt)} (${c.status.label})',
                          ),
                          kv(
                            'Temas de suplementação',
                            r.topicIds.isEmpty
                                ? 'nenhum'
                                : r.topicIds.map(_topicTitle).join(', '),
                          ),
                        ],
                      ),
                    ),
                    const DemoSectionTitle('Arquivo original'),
                    _AttachmentCard(attachment: r.attachment),
                    const DemoSectionTitle('Histórico'),
                    for (final LabRevision h in r.revisions.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${formatDocDateTime(h.at)} - ${h.action} - ${h.author}',
                                style: t.titleSmall?.copyWith(
                                  color: AppColors.navy,
                                ),
                              ),
                              if (h.reason.isNotEmpty)
                                Text('Motivo: ${h.reason}', style: t.bodySmall),
                              if (h.before != null && h.action == 'Corrigido')
                                Text(
                                  'Antes: ${h.before!.summary()}',
                                  style: t.bodySmall,
                                ),
                              if (h.after != null)
                                Text(
                                  'Registro: ${h.after!.summary()}',
                                  style: t.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
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
          ),
        );
      },
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final LabAttachment? attachment;

  @override
  Widget build(BuildContext context) {
    final LabAttachment? a = attachment;
    if (a == null) {
      return const SurfaceCard(child: Text('Nenhum arquivo anexado.'));
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                a.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('${a.name} (${a.sizeLabel})')),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (!openFileInNewTab(a.bytes, a.mimeType)) {
                  showDemoSnack(context, 'O navegador bloqueou a nova aba.');
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir arquivo original'),
            ),
          ),
          if (a.isImage)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: Image.memory(
                  a.bytes,
                  height: 240,
                  fit: BoxFit.contain,
                  semanticLabel: 'Imagem do laudo ${a.name}',
                  errorBuilder: (_, _, _) =>
                      const Text('Não foi possível mostrar a imagem.'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------ Lançar / conferir / corrigir

class DemoLabEntryScreen extends StatefulWidget {
  const DemoLabEntryScreen({
    required this.patientId,
    super.key,
    this.labId,
    this.consultationId,
  });

  final String patientId;
  final String? labId;
  final String? consultationId;

  @override
  State<DemoLabEntryScreen> createState() => _DemoLabEntryScreenState();
}

class _DemoLabEntryScreenState extends State<DemoLabEntryScreen> {
  late final DemoPatient? _p = demoSession.patientById(widget.patientId);
  late LabResult? _r = widget.labId == null
      ? null
      : demoSession.labById(widget.labId!);
  final TextEditingController _test = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _lab = TextEditingController();
  final TextEditingController _rangeText = TextEditingController();
  final TextEditingController _low = TextEditingController();
  final TextEditingController _high = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _consultationId;
  Set<String> _topics = <String>{};
  bool _topicsTouched = false;
  LabAttachment? _attachment;
  bool _checked = false;
  bool _dirty = false;
  List<String> _errors = const <String>[];

  bool get _reviewing => _r?.isPending ?? false;
  bool get _correcting => _r != null && !_r!.isPending;

  String get _back => _r == null
      ? _labsPath(widget.patientId, widget.consultationId)
      : '/pacientes/${widget.patientId}/exames/${_r!.id}${_q(widget.consultationId)}';

  List<TextEditingController> get _all => <TextEditingController>[
    _test,
    _value,
    _unit,
    _date,
    _lab,
    _rangeText,
    _low,
    _high,
    _reason,
  ];

  @override
  void initState() {
    super.initState();
    final LabResult? r = _r;
    if (r != null) {
      final LabValues v = r.values;
      _test.text = v.testName;
      _value.text = v.value;
      _unit.text = v.unit;
      _date.text = v.collectedAt == null ? '' : formatLabDate(v.collectedAt!);
      _lab.text = v.laboratory;
      _rangeText.text = v.range.text;
      _low.text = v.range.low == null ? '' : formatLabNumber(v.range.low!);
      _high.text = v.range.high == null ? '' : formatLabNumber(v.range.high!);
      _consultationId = r.consultationId;
      _topics = Set<String>.of(r.topicIds);
      _topicsTouched = r.topicIds.isNotEmpty;
      _attachment = r.attachment;
    } else {
      _consultationId = widget.consultationId;
    }
    _test.addListener(() {
      if (!_topicsTouched) {
        _topics = Set<String>.of(suggestedTopicsFor(_test.text));
      }
    });
    for (final TextEditingController c in _all) {
      c.addListener(() {
        if (mounted) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  bool _bad(TextEditingController c) =>
      c.text.trim().isNotEmpty && parseLabNumber(c.text) == null;

  LabValues? _values() {
    final String d = _date.text.trim();
    final DateTime? date = d.isEmpty ? null : parseDocDate(d);
    final List<String> errors = <String>[
      if (d.isNotEmpty && date == null)
        'Data da coleta inválida (use dd/mm/aaaa).',
      if (date != null && date.isAfter(DateTime.now()))
        'A data da coleta está no futuro.',
      if (date != null && date.isBefore(_p!.birthDate))
        'A data da coleta é anterior ao nascimento.',
      if (_bad(_low)) 'Limite inferior: use só números.',
      if (_bad(_high)) 'Limite superior: use só números.',
    ];
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return null;
    }
    return LabValues(
      testName: _test.text.trim(),
      value: _value.text.trim(),
      unit: _unit.text.trim(),
      collectedAt: date,
      laboratory: _lab.text.trim(),
      range: ReportedRange(
        text: _rangeText.text.trim(),
        low: parseLabNumber(_low.text),
        high: parseLabNumber(_high.text),
      ),
    );
  }

  LabResult _withLinks(LabResult r) => r.copyWith(
    consultationId: _consultationId,
    clearConsultation: _consultationId == null,
    topicIds: _topics,
    attachment: _attachment,
  );

  void _done(String message, LabResult r) {
    demoSession.saveLab(r);
    _dirty = false;
    showDemoSnack(context, message);
    context.go(
      '/pacientes/${widget.patientId}/exames/${r.id}${_q(widget.consultationId)}',
    );
  }

  void _primary() {
    final LabValues? v = _values();
    if (v == null) return;
    final DateTime now = DateTime.now();
    final String me = demoSession.currentAuthor;
    try {
      if (_r == null) {
        _done(
          'Resultado registrado no prontuário.',
          LabResult.manual(
            id: demoSession.newId('l'),
            patientId: widget.patientId,
            values: v,
            author: me,
            now: now,
            attachment: _attachment,
            consultationId: _consultationId,
            topicIds: _topics,
          ),
        );
      } else if (_reviewing) {
        if (!_checked) {
          setState(
            () => _errors = <String>[
              'Marque que conferiu os valores com o arquivo original.',
            ],
          );
          return;
        }
        _done(
          'Resultado conferido e liberado para o prontuário.',
          _withLinks(_r!).confirm(values: v, reviewer: me, at: now),
        );
      } else {
        final LabResult base = _withLinks(_r!);
        LabResult next;
        try {
          next = base.correct(
            values: v,
            reason: _reason.text,
            author: me,
            at: now,
          );
        } on StateError catch (e) {
          // Só vínculos mudaram: registra sem exigir motivo de correção.
          if (e.message == 'Nenhum valor foi alterado.' &&
              (base.consultationId != _r!.consultationId ||
                  base.topicIds.length != _r!.topicIds.length ||
                  !base.topicIds.containsAll(_r!.topicIds) ||
                  base.attachment != _r!.attachment)) {
            next = base.copyWith(
              addRevision: LabRevision(
                at: now,
                author: me,
                action: 'Vínculos atualizados',
              ),
            );
          } else {
            rethrow;
          }
        }
        _done('Alteração salva. O valor anterior ficou no histórico.', next);
      }
    } on StateError catch (e) {
      setState(() => _errors = <String>[e.message]);
    }
  }

  void _saveReview() {
    final LabValues? v = _values();
    if (v == null) return;
    final LabResult r = _withLinks(_r!).saveReview(
      values: v,
      author: demoSession.currentAuthor,
      at: DateTime.now(),
    );
    demoSession.saveLab(r);
    setState(() {
      _r = r;
      _dirty = false;
      _errors = const <String>[];
    });
    showDemoSnack(context, 'Conferência salva. O resultado segue pendente.');
  }

  Future<void> _attach() async {
    final PickedFile? f = await pickFile(accept: 'application/pdf,image/*');
    if (f == null || !mounted) return;
    if (f.bytes.length > LabAttachment.maxBytes ||
        LabAttachment.sourceFor(f.mimeType) == null) {
      showDemoSnack(context, 'Envie um PDF ou uma imagem de até 10 MB.');
      return;
    }
    setState(() {
      _attachment = LabAttachment(
        name: f.name,
        mimeType: f.mimeType,
        bytes: f.bytes,
      );
      _dirty = true;
    });
  }

  Future<void> _leave() async {
    if (!_dirty || await confirmDiscard(context)) {
      if (mounted) context.go(_back);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = _p;
    if (p == null ||
        (widget.labId != null && (_r == null || _r!.patientId != p.id))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exame')),
        body: DemoEmpty(
          title: 'Resultado não encontrado',
          message: 'Volte para os exames do paciente.',
          actionLabel: 'Pacientes',
          onAction: () => context.go('/pacientes'),
        ),
      );
    }
    final TextTheme t = Theme.of(context).textTheme;
    final String q = LabSeries.normalize(_test.text);
    final List<LabTestSuggestion> suggestions = q.isEmpty
        ? const <LabTestSuggestion>[]
        : kLabTestSuggestions
              .where(
                (LabTestSuggestion s) =>
                    LabSeries.normalize(s.name).contains(q) &&
                    LabSeries.normalize(s.name) != q,
              )
              .take(6)
              .toList();
    final List<DemoConsultation> consultations = demoSession.consultationsFor(
      p.id,
    );
    final List<SupplementSheet> topics = demoSession.supplementSheets
        .where((SupplementSheet s) => s.group != 'Exames')
        .toList();
    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      String? helper,
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          errorText: number && _bad(c) ? 'Use só números.' : null,
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
          title: Text(
            _reviewing
                ? 'Conferir laudo importado'
                : _correcting
                ? 'Editar resultado'
                : 'Novo resultado',
          ),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _leave,
          onSaveDraft: _reviewing ? _saveReview : null,
          primaryLabel: _reviewing
              ? 'Confirmar e liberar'
              : _correcting
              ? 'Salvar alteração'
              : 'Salvar resultado',
          primaryIcon: _reviewing
              ? Icons.fact_check_outlined
              : Icons.save_outlined,
          onPrimary: _primary,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DemoPatientStrip(patient: p),
                  const SizedBox(height: AppSpacing.md),
                  if (_reviewing)
                    DemoNotice(
                      icon: Icons.fact_check_outlined,
                      color: AppColors.warning,
                      text:
                          '${_r!.source.label}: confira cada campo com o arquivo '
                          'original. Nada foi lido automaticamente do arquivo. O '
                          'resultado só entra no prontuário depois de confirmado.',
                    ),
                  if (_correcting)
                    const DemoNotice(
                      icon: Icons.history_rounded,
                      color: AppColors.warning,
                      text:
                          'Mudança de valores exige motivo; o valor anterior fica no '
                          'histórico. Vínculos (consulta, temas, anexo) podem ser '
                          'atualizados sem motivo.',
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const DemoSectionTitle('Arquivo original'),
                  _AttachmentCard(attachment: _attachment),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _attach,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        _attachment == null
                            ? 'Anexar arquivo original'
                            : 'Trocar arquivo',
                      ),
                    ),
                  ),
                  const DemoSectionTitle('Resultado'),
                  field(_test, 'Exame *', hint: 'ex.: Ferritina'),
                  if (suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final LabTestSuggestion s in suggestions)
                            Semantics(
                              button: true,
                              label: 'Usar ${s.name}',
                              excludeSemantics: true,
                              onTap: () => _test.text = s.name,
                              child: ActionChip(
                                label: Text(s.name),
                                onPressed: () => _test.text = s.name,
                              ),
                            ),
                        ],
                      ),
                    ),
                  field(
                    _value,
                    'Resultado *',
                    hint: 'como no laudo (ex.: 12,4)',
                  ),
                  field(_unit, 'Unidade *', hint: 'como no laudo (ex.: ng/mL)'),
                  field(_date, 'Data da coleta *', hint: 'dd/mm/aaaa'),
                  field(_lab, 'Laboratório *'),
                  const DemoSectionTitle(
                    'Intervalo de referência informado no laudo',
                  ),
                  Text(
                    'Copie o intervalo impresso neste laudo. Ele vale só para este '
                    'resultado; o sistema não usa intervalo padrão.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  field(
                    _rangeText,
                    'Intervalo como no laudo',
                    hint: 'ex.: 12 a 150 ng/mL',
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: field(_low, 'Limite inferior', number: true),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: field(_high, 'Limite superior', number: true),
                      ),
                    ],
                  ),
                  const DemoSectionTitle('Relacionar'),
                  Semantics(
                    container: true,
                    child: DropdownButtonFormField<String>(
                      initialValue: _consultationId ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Consulta'),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Sem vínculo'),
                        ),
                        for (final DemoConsultation c in consultations)
                          DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              'Consulta de ${formatLabDate(c.startedAt)} (${c.status.label})',
                            ),
                          ),
                      ],
                      onChanged: (String? id) => setState(() {
                        _consultationId = id == null || id.isEmpty ? null : id;
                        _dirty = true;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Temas de suplementação relacionados',
                    style: t.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final SupplementSheet s in topics)
                        FilterChip(
                          label: Text(s.title),
                          selected: _topics.contains(s.id),
                          onSelected: (bool on) => setState(() {
                            _topicsTouched = true;
                            _dirty = true;
                            _topics = <String>{..._topics};
                            on ? _topics.add(s.id) : _topics.remove(s.id);
                          }),
                        ),
                    ],
                  ),
                  if (_correcting) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    field(
                      _reason,
                      'Motivo da correção (obrigatório se mudar valores)',
                    ),
                  ],
                  if (_reviewing)
                    CheckboxListTile(
                      value: _checked,
                      onChanged: (bool? v) =>
                          setState(() => _checked = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Conferi os valores com o arquivo original',
                      ),
                    ),
                  if (_errors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: DemoNotice(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        text: _errors.join('\n'),
                      ),
                    ),
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
