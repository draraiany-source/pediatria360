import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/lab_results.dart';
import '../../shared/clinical/rx_templates.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'documents_screens.dart';
import 'rx_template_screens.dart';

enum ConsultationStep {
  consulta('consulta', 'Consulta'),
  avaliacao('avaliacao', 'Avaliação'),
  conduta('conduta', 'Conduta'),
  documentos('documentos', 'Documentos');

  const ConsultationStep(this.slug, this.label);

  final String slug;
  final String label;

  static ConsultationStep fromSlug(String? s) =>
      ConsultationStep.values.firstWhere(
        (ConsultationStep e) => e.slug == s,
        orElse: () => ConsultationStep.consulta,
      );
}

class DemoConsultationScreen extends StatefulWidget {
  const DemoConsultationScreen({
    required this.patientId,
    required this.consultationId,
    super.key,
    this.initialStep,
  });

  final String patientId;
  final String consultationId;
  final String? initialStep;

  @override
  State<DemoConsultationScreen> createState() => _DemoConsultationScreenState();
}

class _DemoConsultationScreenState extends State<DemoConsultationScreen> {
  late ConsultationStep _step = ConsultationStep.fromSlug(widget.initialStep);
  final TextEditingController _complaint = TextEditingController();
  final TextEditingController _history = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _exam = TextEditingController();
  final TextEditingController _assessment = TextEditingController();
  final TextEditingController _plan = TextEditingController();
  bool _dirty = false;

  DemoConsultation? get _c =>
      demoSession.consultationById(widget.consultationId);
  DemoPatient? get _p => demoSession.patientById(widget.patientId);

  @override
  void initState() {
    super.initState();
    _load();
    for (final TextEditingController c in _all) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  List<TextEditingController> get _all => <TextEditingController>[
    _complaint,
    _history,
    _weight,
    _exam,
    _assessment,
    _plan,
  ];

  void _load() {
    final DemoConsultation? c = _c;
    if (c == null) return;
    _complaint.text = c.complaint;
    _history.text = c.history;
    _exam.text = c.physicalExam;
    _assessment.text = c.assessment;
    _plan.text = c.plan;
    _weight.text = '';
    _dirty = false;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String get _recordPath => '/pacientes/${widget.patientId}/prontuario';

  String? get _weightError {
    final String t = _weight.text.trim();
    if (t.isEmpty) return null;
    final double? v = double.tryParse(t.replaceAll(',', '.'));
    if (v == null) return 'Use número em kg (ex.: 10,4).';
    if (v < 0.3 || v > 150) {
      return 'Peso fora do plausível. Confira se está em kg.';
    }
    return null;
  }

  bool _save({bool silent = false}) {
    final DemoConsultation? c = _c;
    final DemoPatient? p = _p;
    if (c == null || p == null || !c.isDraft) return false;
    if (_weightError != null) {
      setState(() => _step = ConsultationStep.avaliacao);
      showDemoSnack(context, 'Corrija o peso antes de salvar.');
      return false;
    }
    c
      ..complaint = _complaint.text.trim()
      ..history = _history.text.trim()
      ..physicalExam = _exam.text.trim()
      ..assessment = _assessment.text.trim()
      ..plan = _plan.text.trim();
    final String w = _weight.text.trim();
    if (w.isNotEmpty) {
      final DateTime now = DateTime.now();
      demoSession.updateWeight(
        p,
        double.parse(w.replaceAll(',', '.')),
        DateTime(now.year, now.month, now.day),
        consultationId: c.id,
      );
      _weight.clear();
    }
    demoSession.saveConsultation(c);
    setState(() => _dirty = false);
    if (!silent) {
      showDemoSnack(context, 'Rascunho da consulta salvo nesta aba.');
    }
    return true;
  }

  Future<bool> _canLeave() async => !_dirty || await confirmDiscard(context);

  /// Abre crescimento/exames vinculados; salva o rascunho antes de sair.
  void _openLinked(String path) {
    final DemoConsultation? c = _c;
    if (c != null && c.isDraft && !_save(silent: true)) return;
    context.go(path);
  }

  Future<void> _back() async {
    if (_step.index > 0) {
      setState(() => _step = ConsultationStep.values[_step.index - 1]);
      return;
    }
    if (await _canLeave() && mounted) context.go(_recordPath);
  }

  Future<void> _cancel() async {
    if (_dirty &&
        !await confirmDiscard(
          context,
          title: 'Cancelar alterações?',
          message: 'Volta ao último rascunho salvo e retorna ao prontuário.',
        )) {
      return;
    }
    _load();
    if (mounted) context.go(_recordPath);
  }

  Future<void> _finish() async {
    if (!_save(silent: true)) return;
    final DemoConsultation c = _c!;
    final List<String> missing = c.missingToFinish;
    if (missing.isNotEmpty) {
      showDemoSnack(
        context,
        'Para finalizar, preencha: ${missing.join(', ')}.',
      );
      setState(
        () => _step = c.complaint.isEmpty
            ? ConsultationStep.consulta
            : c.assessment.isEmpty
            ? ConsultationStep.avaliacao
            : ConsultationStep.conduta,
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Finalizar consulta?'),
        content: const Text(
          'A consulta entra no prontuário e deixa de ser editável. '
          'Documentos ainda podem ser criados depois.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    demoSession.finishConsultation(c);
    showDemoSnack(context, 'Consulta finalizada (demonstração).');
    context.go(_recordPath);
  }

  Future<void> _fromRxTemplate(DemoPatient p) async {
    final DemoConsultation c = _c!;
    if (c.isDraft && !_save(silent: true)) return;
    final RxTemplate? t = await pickRxTemplate(
      context,
      subtitle:
          'Gera uma receita nova, em rascunho, com os dados atuais de ${p.name}.',
    );
    if (t == null || !mounted) return;
    useRxTemplate(context, t, p, consultationId: c.id);
  }

  void _newDoc(DocKind kind) {
    final DemoConsultation c = _c!;
    if (c.isDraft && !_save(silent: true)) return;
    context.go(
      '/pacientes/${widget.patientId}/documentos/novo?tipo=${kind.slug}&consulta=${c.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final DemoConsultation? c = _c;
    final DemoPatient? p = _p;
    if (c == null || p == null || c.patientId != p.id) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consulta')),
        body: DemoEmpty(
          title: 'Consulta não encontrada',
          message: 'Volte ao prontuário para abrir ou iniciar uma consulta.',
          actionLabel: 'Pacientes',
          onAction: () => context.go('/pacientes'),
        ),
      );
    }
    final bool editable = c.isDraft;
    final bool last = _step == ConsultationStep.documentos;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: Text('Consulta · ${c.status.label}'),
          actions: <Widget>[
            DemoRecordShortcut(patientId: p.id, onLeave: _canLeave),
          ],
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _back,
          onCancel: editable ? _cancel : null,
          onSaveDraft: editable ? () => _save() : null,
          primaryLabel: last
              ? (editable ? 'Finalizar consulta' : null)
              : 'Próximo',
          primaryIcon: last
              ? Icons.task_alt_rounded
              : Icons.arrow_forward_rounded,
          onPrimary: last
              ? _finish
              : () => setState(
                  () => _step = ConsultationStep.values[_step.index + 1],
                ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DemoPatientStrip(patient: p),
                  const SizedBox(height: AppSpacing.md),
                  _StepBar(
                    current: _step,
                    onTap: (ConsultationStep s) => setState(() => _step = s),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!editable)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: DemoNotice(
                        text:
                            'Consulta finalizada: somente leitura. Documentos ainda '
                            'podem ser criados na etapa Documentos.',
                      ),
                    ),
                  ...switch (_step) {
                    ConsultationStep.consulta => <Widget>[
                      _field(
                        _complaint,
                        'Motivo da consulta *',
                        editable,
                        lines: 2,
                      ),
                      _field(
                        _history,
                        'História / anamnese',
                        editable,
                        lines: 5,
                      ),
                    ],
                    ConsultationStep.avaliacao => <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: TextField(
                          key: const ValueKey<String>('peso'),
                          controller: _weight,
                          enabled: editable,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Peso de hoje (kg)',
                            suffixText: 'kg',
                            helperText: p.weightKg == null
                                ? 'Sem peso registrado: a calculadora fica bloqueada.'
                                : 'Último: ${formatDoseNumber(p.weightKg!)} kg em '
                                      '${formatDocDate(p.weighedAt!)}. Deixe vazio para manter.',
                            errorText: _weightError,
                          ),
                        ),
                      ),
                      _field(_exam, 'Exame físico', editable, lines: 4),
                      _field(_assessment, 'Avaliação *', editable, lines: 4),
                      const DemoSectionTitle('Crescimento e exames'),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => _openLinked(
                              '/pacientes/${p.id}/crescimento/nova?consulta=${c.id}',
                            ),
                            icon: const Icon(Icons.straighten_rounded),
                            label: const Text('Registrar medidas'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openLinked(
                              '/pacientes/${p.id}/crescimento?consulta=${c.id}',
                            ),
                            icon: const Icon(Icons.show_chart_rounded),
                            label: const Text('Curva de crescimento'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openLinked(
                              '/pacientes/${p.id}/exames?consulta=${c.id}',
                            ),
                            icon: const Icon(Icons.biotech_outlined),
                            label: const Text('Exames do paciente'),
                          ),
                        ],
                      ),
                      _LinkedSummary(patientId: p.id, consultationId: c.id),
                    ],
                    ConsultationStep.conduta => <Widget>[
                      _field(_plan, 'Conduta *', editable, lines: 5),
                      const DemoSectionTitle('Apoio à conduta'),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: () => _newDoc(DocKind.receituario),
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('Receituário com calculadora'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _fromRxTemplate(p),
                            icon: const Icon(Icons.bookmarks_outlined),
                            label: const Text('Receita de modelo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _newDoc(DocKind.exames),
                            icon: const Icon(Icons.biotech_outlined),
                            label: const Text('Solicitar exames'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              if (c.isDraft && !_save(silent: true)) return;
                              context.go(
                                '/pacientes/${p.id}/suplementacao?consulta=${c.id}',
                              );
                            },
                            icon: const Icon(Icons.medication_liquid_outlined),
                            label: const Text('Suplementação do paciente'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Nenhuma conduta é gerada automaticamente: a calculadora '
                        'confere doses e as fichas de suplementação estão em rascunho.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    ConsultationStep.documentos => _docs(c, p),
                  },
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _docs(DemoConsultation c, DemoPatient p) {
    final List<ClinicalDocRecord> docs = demoSession
        .documentsFor(p.id)
        .where((ClinicalDocRecord d) => d.consultationId == c.id)
        .toList();
    return <Widget>[
      Text(
        'Documentos desta consulta',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      if (docs.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: Text('Nenhum documento criado nesta consulta.'),
        ),
      for (final ClinicalDocRecord d in docs) DemoDocTile(doc: d),
      const DemoSectionTitle('Criar documento'),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final int cols = box.maxWidth >= 640 ? 3 : 2;
          final double w = (box.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final DocKind k in DocKind.values)
                SizedBox(
                  width: w,
                  child: PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () => _newDoc(k),
                    child: Row(
                      children: <Widget>[
                        Icon(docKindIcon(k), color: AppColors.brand),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            k.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const DemoSectionTitle('Meus modelos de receita'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: () => _fromRxTemplate(p),
            icon: const Icon(Icons.bookmarks_outlined),
            label: const Text('Receita a partir de modelo'),
          ),
          TextButton.icon(
            onPressed: () {
              if (c.isDraft && !_save(silent: true)) return;
              context.go('$rxTemplatesPath?paciente=${p.id}&consulta=${c.id}');
            },
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('Ver e buscar modelos'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'A receita nasce em rascunho com o peso atual do paciente; doses pelo '
        'peso são refeitas e cada item precisa ser conferido antes da emissão.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Widget _field(
    TextEditingController c,
    String label,
    bool enabled, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: c,
      enabled: enabled,
      minLines: lines,
      maxLines: lines + 6,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
    ),
  );
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.current, required this.onTap});

  final ConsultationStep current;
  final ValueChanged<ConsultationStep> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final ConsultationStep s in ConsultationStep.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: s == ConsultationStep.documentos ? 0 : AppSpacing.xs,
              ),
              child: Semantics(
                button: true,
                selected: s == current,
                child: InkWell(
                  onTap: () => onTap(s),
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: s == current
                          ? AppColors.navy
                          : s.index < current.index
                          ? AppColors.brandIndicator
                          : Colors.white,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: s == current ? AppColors.navy : AppColors.line,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${s.index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: s == current ? Colors.white : AppColors.navy,
                          ),
                        ),
                        Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: s == current
                                    ? Colors.white
                                    : AppColors.navy,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Medidas e exames já vinculados a esta consulta.
class _LinkedSummary extends StatelessWidget {
  const _LinkedSummary({required this.patientId, required this.consultationId});

  final String patientId;
  final String consultationId;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<GrowthMeasurement> growth = demoSession
        .growthFor(patientId)
        .where(
          (GrowthMeasurement m) =>
              m.consultationId == consultationId && !m.voided,
        )
        .toList();
    final List<LabResult> labs = demoSession
        .labsFor(patientId)
        .where((LabResult r) => r.consultationId == consultationId)
        .toList();
    if (growth.isEmpty && labs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          'Nenhuma medida ou exame vinculado a esta consulta.',
          style: t.bodySmall,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final GrowthMeasurement m in growth)
              Text('Medida: ${m.values.summary()}', style: t.bodySmall),
            for (final LabResult r in labs)
              Text(
                r.isPending
                    ? 'Exame: ${r.attachment?.name ?? 'laudo'} (pendente de conferência)'
                    : 'Exame: ${r.values.testName} ${r.values.value} ${r.values.unit} '
                          '(${formatLabDate(r.values.collectedAt!)})',
                style: t.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
