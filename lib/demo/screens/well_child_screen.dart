import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/pdf_output.dart';
import '../../shared/routine/child_routine.dart';
import '../../shared/routine/sleep_log.dart';
import '../../shared/wellchild/age_band.dart';
import '../../shared/wellchild/milestones.dart';
import '../../shared/wellchild/well_child_pdf.dart';
import '../../shared/wellchild/well_child_templates.dart';
import '../../shared/wellchild/well_child_visit.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_routine.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'documents_screens.dart';

enum WellChildStep {
  consulta(
    'consulta',
    'Consulta',
    'História, alimentação, sono, eliminações e vacinação',
  ),
  exame('exame', 'Exame', 'Exame físico e crescimento'),
  marcos('desenvolvimento', 'Marcos', 'Desenvolvimento'),
  conduta('conduta', 'Conduta', 'Avaliação, plano, dúvidas e orientações'),
  resumo('resumo', 'Resumo', 'Resumo, histórico e PDF');

  const WellChildStep(this.slug, this.label, this.title);

  final String slug;
  final String label;
  final String title;

  /// Telas ligadas (crescimento, exames, documentos) voltam com as etapas
  /// da consulta comum; aqui elas caem na etapa equivalente.
  static WellChildStep fromSlug(String? s) => switch (s) {
    'avaliacao' => WellChildStep.exame,
    'documentos' => WellChildStep.conduta,
    _ => WellChildStep.values.firstWhere(
      (WellChildStep e) => e.slug == s,
      orElse: () => WellChildStep.consulta,
    ),
  };
}

/// Abre a puericultura em rascunho do paciente ou inicia uma nova.
void openWellChildFor(BuildContext context, String patientId) {
  final DemoConsultation c =
      demoSession
          .consultationsFor(patientId)
          .where(
            (DemoConsultation c) =>
                c.isDraft &&
                c.isWellChild &&
                (c.ownerId ?? DemoProfessional.id) == demoSession.account.id,
          )
          .firstOrNull ??
      demoSession.startWellChildVisit(patientId);
  context.go('/pacientes/$patientId/consulta/${c.id}');
}

const List<WellChildSection> _consultaSections = <WellChildSection>[
  WellChildSection.historia,
  WellChildSection.alimentacao,
  WellChildSection.sono,
  WellChildSection.eliminacoes,
  WellChildSection.vacinacao,
];

class DemoWellChildScreen extends StatefulWidget {
  const DemoWellChildScreen({
    required this.patientId,
    required this.consultationId,
    super.key,
    this.initialStep,
  });

  final String patientId;
  final String consultationId;
  final String? initialStep;

  @override
  State<DemoWellChildScreen> createState() => _DemoWellChildScreenState();
}

class _DemoWellChildScreenState extends State<DemoWellChildScreen> {
  late WellChildStep _step = WellChildStep.fromSlug(widget.initialStep);
  final Map<WellChildSection, TextEditingController> _f =
      <WellChildSection, TextEditingController>{
        for (final WellChildSection s in WellChildSection.values)
          s: TextEditingController(),
      };
  final TextEditingController _guidance = TextEditingController();
  final TextEditingController _next = TextEditingController();
  WellChildVisit _v = const WellChildVisit();
  ChildAgeBand? _band;
  bool _dirty = false;
  bool _correcting = false;
  bool _busy = false;

  DemoConsultation? get _c =>
      demoSession.consultationById(widget.consultationId);
  DemoPatient? get _p => demoSession.patientById(widget.patientId);

  bool get _editable => (_c?.isDraft ?? false) || _correcting;

  @override
  void initState() {
    super.initState();
    _load();
    for (final TextEditingController c in <TextEditingController>[
      ..._f.values,
      _guidance,
      _next,
    ]) {
      c.addListener(_touch);
    }
  }

  void _touch() {
    if (!_dirty && _editable) setState(() => _dirty = true);
  }

  void _load() {
    final WellChildVisit? v = _c?.wellChild;
    if (v == null) return;
    _v = v;
    for (final WellChildSection s in WellChildSection.values) {
      _f[s]!.text = v.field(s);
    }
    _guidance.text = v.guidance;
    _next.text = v.nextVisit == null ? '' : formatDmy(v.nextVisit!);
    _dirty = false;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _f.values) {
      c.dispose();
    }
    _guidance.dispose();
    _next.dispose();
    super.dispose();
  }

  String get _recordPath => '/pacientes/${widget.patientId}/prontuario';

  /// Conteúdo atual da tela (campos de texto + listas editadas).
  WellChildVisit? _compose({bool report = true}) {
    final String n = _next.text.trim();
    final DateTime? next = n.isEmpty ? null : parseDmy(n);
    if (n.isNotEmpty && next == null) {
      if (report) {
        setState(() => _step = WellChildStep.conduta);
        showDemoSnack(context, 'Próxima consulta: use dd/mm/aaaa.');
      }
      return null;
    }
    return _v.copyWith(
      fields: <WellChildSection, String>{
        for (final WellChildSection s in WellChildSection.values)
          if (_f[s]!.text.trim().isNotEmpty) s: _f[s]!.text.trim(),
      },
      guidance: _guidance.text.trim(),
      nextVisit: () => next,
    );
  }

  Future<bool> _save({bool silent = false}) async {
    final DemoConsultation? c = _c;
    if (c == null || !_editable) return false;
    final WellChildVisit? next = _compose();
    if (next == null) return false;
    String reason = '';
    if (!c.isDraft) {
      if (c.wellChild!.changesTo(next).isEmpty) {
        showDemoSnack(context, 'Nada foi alterado.');
        return false;
      }
      final String? r = await _askReason();
      if (r == null || !mounted) return false;
      reason = r;
    }
    final bool changed = demoSession.saveWellChild(
      c,
      next,
      action: c.isDraft ? 'Editado' : 'Corrigido após finalizar',
      reason: reason,
    );
    setState(() {
      _v = c.wellChild!;
      _dirty = false;
      if (!c.isDraft) _correcting = false;
    });
    if (!silent && mounted) {
      showDemoSnack(
        context,
        !changed
            ? 'Nada foi alterado.'
            : c.isDraft
            ? 'Rascunho da puericultura salvo.'
            : 'Correção salva. A versão anterior ficou no histórico.',
      );
    }
    return true;
  }

  Future<String?> _askReason() {
    final TextEditingController r = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext d, StateSetter set) => AlertDialog(
          title: const Text('Motivo da correção'),
          content: TextField(
            key: const ValueKey<String>('wc-motivo'),
            controller: r,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => set(() {}),
            decoration: const InputDecoration(
              labelText: 'Motivo (fica no histórico)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: r.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(d).pop(r.text.trim()),
              child: const Text('Salvar correção'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _canLeave() async => !_dirty || await confirmDiscard(context);

  Future<void> _openLinked(String path) async {
    final DemoConsultation? c = _c;
    if (_dirty && c != null && c.isDraft && !await _save(silent: true)) {
      return;
    }
    if (_dirty && !await _canLeave()) return;
    if (mounted) context.go(path);
  }

  Future<void> _back() async {
    if (_step.index > 0) {
      setState(() => _step = WellChildStep.values[_step.index - 1]);
      return;
    }
    if (await _canLeave() && mounted) context.go(_recordPath);
  }

  Future<void> _cancel() async {
    if (_dirty &&
        !await confirmDiscard(
          context,
          title: 'Cancelar alterações?',
          message: 'Volta ao último conteúdo salvo.',
        )) {
      return;
    }
    setState(() {
      _load();
      _correcting = false;
    });
  }

  Future<void> _finish() async {
    if (!await _save(silent: true) || !mounted) return;
    final DemoConsultation c = _c!;
    final WellChildVisit v = c.wellChild!;
    final List<String> pending = <String>[
      ...v.missingToFinish.map((String s) => 'Preencha: $s'),
      ...v.placeholders.map((String s) => 'Complete os colchetes em: $s'),
    ];
    if (pending.isNotEmpty) {
      showDemoSnack(context, 'Para finalizar: ${pending.join('; ')}.');
      setState(() => _step = WellChildStep.conduta);
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Finalizar puericultura?'),
        content: const Text(
          'A consulta entra no prontuário. Depois disso, alterações ficam '
          'registradas como correção, com motivo e versão anterior.',
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
    final List<String> problems = demoSession.finishWellChild(c);
    if (problems.isNotEmpty) {
      showDemoSnack(context, problems.join('; '));
      return;
    }
    setState(_load);
    showDemoSnack(context, 'Puericultura finalizada (demonstração).');
  }

  // --------------------------------------------------------------- Modelos

  Future<void> _applyTemplate(DemoPatient p, VisitAge age) async {
    final WellChildTemplate? t = await showModalBottomSheet<WellChildTemplate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext s) => _TemplatePicker(band: age.band),
    );
    if (t == null || !mounted) return;
    final WellChildVisit? cur = _compose();
    if (cur == null) return;
    final ({WellChildVisit visit, List<String> filled, List<String> kept}) r = t
        .applyTo(
          cur,
          patientName: p.name,
          guardianName: p.guardianName,
          ageLabel: age.shortLabel,
        );
    setState(() {
      _v = r.visit;
      for (final WellChildSection s in WellChildSection.values) {
        _f[s]!.text = r.visit.field(s);
      }
      _guidance.text = r.visit.guidance;
      _dirty = true;
    });
    showDemoSnack(
      context,
      'Modelo aplicado: ${r.filled.isEmpty ? 'nenhum campo vazio' : r.filled.join(', ')}.'
      '${r.kept.isEmpty ? '' : ' Mantidos (já escritos): ${r.kept.join(', ')}.'}'
      ' Revise e complete os colchetes.',
    );
  }

  Future<void> _saveAsTemplate(DemoPatient p, VisitAge age) async {
    final WellChildVisit? cur = _compose();
    if (cur == null) return;
    final TextEditingController name = TextEditingController(
      text: 'Puericultura ${age.band.label}',
    );
    final String? n = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Salvar como modelo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('wc-nome-modelo'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome do modelo'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'O nome da criança e do responsável viram marcadores. Dados '
              'incorporados da família não entram no modelo.',
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
            onPressed: () => Navigator.of(d).pop(name.text),
            child: const Text('Salvar modelo'),
          ),
        ],
      ),
    );
    if (n == null || !mounted) return;
    final WellChildTemplate t = WellChildTemplate.fromVisit(
      cur,
      id: demoSession.newWellChildTemplateId(),
      name: n,
      author: demoSession.currentAuthor,
      now: DateTime.now(),
      patientName: p.name,
      guardianName: p.guardianName,
      band: age.band,
    );
    final List<String> errors = t.validate();
    if (errors.isNotEmpty) {
      showDemoSnack(context, errors.join(' '));
      return;
    }
    demoSession.saveWellChildTemplate(t);
    showDemoSnack(context, 'Modelo "${t.name}" salvo em Meus modelos.');
  }

  // ------------------------------------------------- Dados da família

  Future<void> _importSleep(DemoPatient p) async {
    final SleepWeek week = demoSession.sleepWeek(p.id, demoSession.now);
    final TextEditingController text = TextEditingController(
      text: week.toClinicalText(),
    );
    bool reviewed = false;
    final String? out = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext d, StateSetter set) => AlertDialog(
          title: const Text('Incorporar diário do sono'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Informado pela família (${week.periodLabel()}). Edite o '
                  'texto antes de incorporar ao campo Sono.',
                  style: Theme.of(d).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey<String>('wc-incorporar-texto'),
                  controller: text,
                  minLines: 5,
                  maxLines: 12,
                  onChanged: (_) => set(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Texto a incorporar',
                    alignLabelWithHint: true,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: reviewed,
                  onChanged: (bool? v) => set(() => reviewed = v ?? false),
                  title: const Text('Revisei os dados informados pela família'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: reviewed && text.text.trim().isNotEmpty
                  ? () => Navigator.of(d).pop(text.text.trim())
                  : null,
              child: const Text('Incorporar'),
            ),
          ],
        ),
      ),
    );
    if (out == null || !mounted) return;
    final WellChildVisit? cur = _compose();
    if (cur == null) return;
    final WellChildVisit next = cur.incorporate(
      FamilyImport(
        section: WellChildSection.sono,
        source: 'Diário do sono',
        period: week.periodLabel(),
        text: out,
        reviewedBy: demoSession.currentAuthor,
        at: DateTime.now(),
      ),
    );
    setState(() {
      _v = next;
      _f[WellChildSection.sono]!.text = next.field(WellChildSection.sono);
      _dirty = true;
    });
    showDemoSnack(context, 'Diário do sono incorporado ao campo Sono.');
  }

  // ------------------------------------------------------------------ PDF

  Future<void> _pdf(
    DemoPatient p,
    DemoConsultation c,
    PdfDelivery delivery,
  ) async {
    if (_dirty && c.isDraft && !await _save(silent: true)) return;
    setState(() => _busy = true);
    try {
      final DateTime now = DateTime.now();
      final List<GrowthMeasurement> ms =
          demoSession
              .growthFor(p.id)
              .where((GrowthMeasurement m) => !m.voided)
              .toList()
            ..sort(
              (GrowthMeasurement a, GrowthMeasurement b) =>
                  b.values.date.compareTo(a.values.date),
            );
      final DateTime d = c.startedAt;
      final Uint8List bytes = await WellChildPdf.build(
        visit: c.wellChild!,
        context: DemoClinicalSeed.contextFor(
          p,
          date: DateTime(d.year, d.month, d.day),
          account: DemoProfessional.byId(c.ownerId ?? DemoProfessional.id),
        ),
        age: demoSession.visitAge(p, d),
        finished: !c.isDraft,
        author: c.author,
        now: now,
        measures: <ReportMeasure>[
          for (final GrowthMeasurement m in ms.take(8))
            ReportMeasure(m.values, current: m.consultationId == c.id),
        ],
        logo: demoSession.logoForVisit(c)?.bytes,
        demo: true,
      );
      final String name = WellChildPdf.fileName(p.name, d);
      final String? how = await deliverPdf(
        bytes,
        fileName: name,
        delivery: delivery,
      );
      demoSession.recordPdf(name, bytes, delivery.name);
      if (!mounted) return;
      showDemoSnack(
        context,
        how == null
            ? 'PDF gerado ($name). Saída disponível na versão web.'
            : 'Resumo da puericultura em PDF: $name',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------------- Tela

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoConsultation? c = _c;
        final DemoPatient? p = _p;
        if (c == null ||
            p == null ||
            c.patientId != p.id ||
            c.wellChild == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Puericultura')),
            body: DemoEmpty(
              title: 'Consulta não encontrada',
              message: 'Volte ao prontuário para abrir ou iniciar a consulta.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final VisitAge age = demoSession.visitAge(p, c.startedAt);
        final bool last = _step == WellChildStep.resumo;
        final bool editable = _editable;
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
              title: Text('Puericultura · ${c.status.label}'),
              actions: <Widget>[
                DemoRecordShortcut(patientId: p.id, onLeave: _canLeave),
              ],
            ),
            bottomNavigationBar: DemoFlowActions(
              onBack: _back,
              onCancel: editable ? _cancel : null,
              onSaveDraft: editable ? () => _save() : null,
              saveLabel: c.isDraft ? 'Salvar rascunho' : 'Salvar correção',
              primaryLabel: last
                  ? (c.isDraft ? 'Finalizar puericultura' : null)
                  : 'Próximo',
              primaryIcon: last
                  ? Icons.task_alt_rounded
                  : Icons.arrow_forward_rounded,
              onPrimary: last
                  ? _finish
                  : () => setState(
                      () => _step = WellChildStep.values[_step.index + 1],
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
                      DemoPatientStrip(patient: p, now: c.startedAt),
                      const SizedBox(height: AppSpacing.sm),
                      _AgeBox(age: age),
                      const SizedBox(height: AppSpacing.sm),
                      if (!c.isDraft && !_correcting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const DemoNotice(
                                text:
                                    'Puericultura finalizada: somente leitura. '
                                    'Para alterar, use "Corrigir" (fica no '
                                    'histórico, com motivo).',
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _correcting = true),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Corrigir'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_correcting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: DemoNotice(
                            icon: Icons.edit_note_rounded,
                            color: AppColors.warning,
                            text:
                                'Corrigindo consulta finalizada. Ao salvar, '
                                'informe o motivo; a versão anterior fica no '
                                'histórico.',
                          ),
                        ),
                      if (editable)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () => _applyTemplate(p, age),
                              icon: const Icon(Icons.bookmarks_outlined),
                              label: const Text('Aplicar modelo'),
                            ),
                            TextButton.icon(
                              onPressed: () => _saveAsTemplate(p, age),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Salvar como modelo'),
                            ),
                          ],
                        ),
                      if (_v.templateName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Modelo usado: ${_v.templateName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      _Steps(
                        current: _step,
                        onTap: (WellChildStep s) => setState(() => _step = s),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _step.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...switch (_step) {
                        WellChildStep.consulta => _consulta(p, c, editable),
                        WellChildStep.exame => _exame(p, c, age, editable),
                        WellChildStep.marcos => _marcos(age, editable),
                        WellChildStep.conduta => _conduta(p, c, editable),
                        WellChildStep.resumo => _resumo(p, c),
                      },
                      const SizedBox(height: AppSpacing.xl),
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

  Widget _field(WellChildSection s, bool enabled, {int lines = 3}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      key: ValueKey<String>('wc-${s.slug}'),
      controller: _f[s],
      enabled: enabled,
      minLines: lines,
      maxLines: lines + 8,
      decoration: InputDecoration(
        labelText: '${s.label}${s.required ? ' *' : ''}',
        hintText: s.hint,
        alignLabelWithHint: true,
      ),
    ),
  );

  List<Widget> _consulta(DemoPatient p, DemoConsultation c, bool editable) {
    final bool shared = demoSession.routineSharedWith(p.id);
    return <Widget>[
      for (final WellChildSection s in _consultaSections) ...<Widget>[
        _field(s, editable),
        if (s == WellChildSection.sono)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (shared) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _openLinked(
                      '/rotina/${p.id}?vista=sono&consulta=${c.id}',
                    ),
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('Ver diário do sono'),
                  ),
                  if (editable)
                    FilledButton.tonalIcon(
                      onPressed: () => _importSleep(p),
                      icon: const Icon(Icons.download_done_rounded),
                      label: const Text('Incorporar diário do sono'),
                    ),
                ] else
                  Text(
                    'A família não compartilhou a rotina: o diário do sono '
                    'não está disponível.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        if (s == WellChildSection.vacinacao)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openLinked('/vacinacao?paciente=${p.id}'),
                icon: const Icon(Icons.vaccines_outlined),
                label: const Text('Abrir carteira de vacinação'),
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _exame(
    DemoPatient p,
    DemoConsultation c,
    VisitAge age,
    bool editable,
  ) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<GrowthMeasurement> ms =
        demoSession
            .growthFor(p.id)
            .where((GrowthMeasurement m) => !m.voided)
            .toList()
          ..sort(
            (GrowthMeasurement a, GrowthMeasurement b) =>
                b.values.date.compareTo(a.values.date),
          );
    String num(double? v, String u) =>
        v == null ? '-' : '${formatDecimal(v, digits: u == 'kg' ? 3 : 1)} $u';
    return <Widget>[
      _field(WellChildSection.exameFisico, editable, lines: 4),
      const DemoSectionTitle('Medidas e curvas'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          if (c.isDraft)
            FilledButton.icon(
              onPressed: () => _openLinked(
                '/pacientes/${p.id}/crescimento/nova?consulta=${c.id}',
              ),
              icon: const Icon(Icons.straighten_rounded),
              label: const Text('Registrar peso, comprimento e PC'),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                _openLinked('/pacientes/${p.id}/crescimento?consulta=${c.id}'),
            icon: const Icon(Icons.show_chart_rounded),
            label: const Text('Curvas de crescimento'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (age.usesCorrected)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            'As curvas usam a idade corrigida (identificada em cada ponto).',
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      if (ms.isEmpty)
        Text('Nenhuma medida registrada.', style: t.bodySmall)
      else
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: <Widget>[
              for (final GrowthMeasurement m in ms.take(8))
                ListTile(
                  dense: true,
                  title: Text(
                    '${formatDmy(m.values.date)} - '
                    '${demoSession.visitAge(p, m.values.date).shortLabel}',
                  ),
                  subtitle: Text(
                    'Peso ${num(m.values.weightKg, 'kg')} · '
                    '${m.values.position == MeasurePosition.lying ? 'Comprimento' : 'Altura'} '
                    '${num(m.values.lengthCm, 'cm')} · '
                    'PC ${num(m.values.headCm, 'cm')}',
                  ),
                  trailing: m.consultationId == c.id
                      ? const Chip(
                          label: Text('nesta consulta'),
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      _field(WellChildSection.crescimento, editable),
    ];
  }

  MilestoneObservation? _obs(String code) {
    for (final MilestoneObservation m in _v.milestones) {
      if (m.code == code) return m;
    }
    return null;
  }

  void _setMilestone(MilestoneSuggestion s, MilestoneState? state) {
    setState(() {
      final MilestoneObservation? old = _obs(s.code);
      final List<MilestoneObservation> l = _v.milestones
          .where((MilestoneObservation m) => m.code != s.code)
          .toList();
      if (state != null) {
        l.add(
          old == null
              ? MilestoneObservation.from(s, state)
              : old.copyWith(state: state),
        );
      }
      _v = _v.copyWith(milestones: l);
      _dirty = true;
    });
  }

  Future<void> _addCustomMilestone() async {
    final TextEditingController title = TextEditingController();
    MilestoneArea area = MilestoneArea.motorGrosso;
    MilestoneState state = MilestoneState.adquirido;
    final MilestoneObservation? m = await showDialog<MilestoneObservation>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext d, StateSetter set) => AlertDialog(
          title: const Text('Outro marco'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: const ValueKey<String>('wc-marco-titulo'),
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Marco'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<MilestoneArea>(
                  initialValue: area,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Área'),
                  items: <DropdownMenuItem<MilestoneArea>>[
                    for (final MilestoneArea a in MilestoneArea.values)
                      DropdownMenuItem<MilestoneArea>(
                        value: a,
                        child: Text(a.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (MilestoneArea? a) => set(() => area = a ?? area),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final MilestoneState s in MilestoneState.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: state == s,
                        onSelected: (_) => set(() => state = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.of(d).pop(
                  MilestoneObservation(
                    code: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                    title: title.text.trim(),
                    area: area,
                    state: state,
                    custom: true,
                  ),
                );
              },
              child: const Text('Incluir marco'),
            ),
          ],
        ),
      ),
    );
    if (m == null || !mounted) return;
    setState(() {
      _v = _v.copyWith(milestones: <MilestoneObservation>[..._v.milestones, m]);
      _dirty = true;
    });
  }

  List<Widget> _marcos(VisitAge age, bool editable) {
    final TextTheme t = Theme.of(context).textTheme;
    final ChildAgeBand band = _band ?? age.band;
    final List<MilestoneSuggestion> list = milestoneSuggestions(band);
    final Set<String> shown = list
        .map((MilestoneSuggestion s) => s.code)
        .toSet();
    final List<MilestoneObservation> others = _v.milestones
        .where((MilestoneObservation m) => !shown.contains(m.code))
        .toList();
    return <Widget>[
      const DemoNotice(
        icon: Icons.info_outline_rounded,
        color: AppColors.warning,
        text: kMilestoneListNotice,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Faixa: ${band.label}'
        '${band == age.band ? (age.usesCorrected ? ' (pela idade corrigida)' : ' (pela idade)') : ' (escolhida)'}',
        style: t.titleSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final ChildAgeBand b in ChildAgeBand.values)
            ChoiceChip(
              label: Text(b.label),
              selected: b == band,
              onSelected: (_) => setState(() => _band = b),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      for (final MilestoneArea area in MilestoneArea.values)
        if (list.any((MilestoneSuggestion s) => s.area == area)) ...<Widget>[
          Text(
            area.label,
            style: t.labelLarge?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final MilestoneSuggestion s in list.where(
            (MilestoneSuggestion s) => s.area == area,
          ))
            _MilestoneRow(
              title: s.title,
              state: _obs(s.code)?.state,
              enabled: editable,
              onChanged: (MilestoneState? st) => _setMilestone(s, st),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      if (others.isNotEmpty) ...<Widget>[
        Text(
          'Outros marcos registrados',
          style: t.labelLarge?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (final MilestoneObservation m in others)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(m.describe()),
            trailing: editable
                ? IconButton(
                    tooltip: 'Remover ${m.title}',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _v = _v.copyWith(
                        milestones: _v.milestones
                            .where((MilestoneObservation x) => x.code != m.code)
                            .toList(),
                      );
                      _dirty = true;
                    }),
                  )
                : null,
          ),
      ],
      if (editable)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addCustomMilestone,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Outro marco'),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      _field(WellChildSection.desenvolvimento, editable),
    ];
  }

  Future<void> _editQuestion({int? index}) async {
    final GuardianQuestion? cur = index == null ? null : _v.questions[index];
    final TextEditingController q = TextEditingController(
      text: cur?.question ?? '',
    );
    final TextEditingController a = TextEditingController(
      text: cur?.answer ?? '',
    );
    final GuardianQuestion? out = await showDialog<GuardianQuestion>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          index == null ? 'Dúvida dos responsáveis' : 'Editar dúvida',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('wc-duvida'),
              controller: q,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Dúvida'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey<String>('wc-duvida-resposta'),
              controller: a,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Orientação dada'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (q.text.trim().isEmpty) return;
              Navigator.of(d).pop(
                GuardianQuestion(
                  question: q.text.trim(),
                  answer: a.text.trim(),
                ),
              );
            },
            child: const Text('Salvar dúvida'),
          ),
        ],
      ),
    );
    if (out == null || !mounted) return;
    setState(() {
      final List<GuardianQuestion> l = List<GuardianQuestion>.of(_v.questions);
      if (index == null) {
        l.add(out);
      } else {
        l[index] = out;
      }
      _v = _v.copyWith(questions: l);
      _dirty = true;
    });
  }

  Future<void> _addFollowUp() async {
    final TextEditingController title = TextEditingController();
    final TextEditingController due = TextEditingController(
      text: formatDmy(addDays(dayOf(demoSession.now), 30)),
    );
    String? error;
    final FollowUpItem? out = await showDialog<FollowUpItem>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext d, StateSetter set) => AlertDialog(
          title: const Text('Item de acompanhamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('wc-item-titulo'),
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'O que acompanhar',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey<String>('wc-item-data'),
                controller: due,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: 'Data (dd/mm/aaaa)',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final DateTime? when = parseDmy(due.text);
                if (title.text.trim().isEmpty || when == null) {
                  set(() => error = 'Informe o item e a data.');
                  return;
                }
                Navigator.of(d).pop(
                  FollowUpItem(
                    id: 'fu${DateTime.now().microsecondsSinceEpoch}',
                    title: title.text.trim(),
                    due: when,
                  ),
                );
              },
              child: const Text('Incluir item'),
            ),
          ],
        ),
      ),
    );
    if (out == null || !mounted) return;
    setState(() {
      _v = _v.copyWith(followUps: <FollowUpItem>[..._v.followUps, out]);
      _dirty = true;
    });
  }

  List<Widget> _conduta(DemoPatient p, DemoConsultation c, bool editable) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<ClinicalDocRecord> docs = demoSession
        .documentsFor(p.id)
        .where(
          (ClinicalDocRecord d) =>
              d.consultationId == c.id && d.kind == DocKind.orientacoes,
        )
        .toList();
    final DateTime today = dayOf(demoSession.now);
    return <Widget>[
      _field(WellChildSection.avaliacao, editable, lines: 4),
      _field(WellChildSection.plano, editable, lines: 4),
      DemoSectionTitle(
        'Dúvidas dos responsáveis',
        trailing: editable
            ? TextButton.icon(
                onPressed: () => _editQuestion(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Dúvida'),
              )
            : null,
      ),
      if (_v.questions.isEmpty)
        Text('Nenhuma dúvida registrada.', style: t.bodySmall),
      for (int i = 0; i < _v.questions.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_v.questions[i].question),
          subtitle: Text(
            _v.questions[i].answer.isEmpty
                ? 'Sem orientação registrada'
                : 'Orientação: ${_v.questions[i].answer}',
          ),
          onTap: editable ? () => _editQuestion(index: i) : null,
          trailing: editable
              ? IconButton(
                  tooltip: 'Remover dúvida',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _v = _v.copyWith(
                      questions: List<GuardianQuestion>.of(_v.questions)
                        ..removeAt(i),
                    );
                    _dirty = true;
                  }),
                )
              : null,
        ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        key: const ValueKey<String>('wc-orientacoes'),
        controller: _guidance,
        enabled: editable,
        minLines: 3,
        maxLines: 10,
        decoration: const InputDecoration(
          labelText: 'Orientações dadas nesta consulta',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const DemoSectionTitle('Orientação por escrito para a família'),
      Text(
        'Use um modelo por faixa etária, revise e emita. A família só vê a '
        'orientação depois de emitida.',
        style: t.bodySmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      for (final ClinicalDocRecord d in docs) DemoDocTile(doc: d),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _openLinked(
            '/pacientes/${p.id}/documentos/novo?tipo=${DocKind.orientacoes.slug}&consulta=${c.id}',
          ),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Preparar orientação'),
        ),
      ),
      const DemoSectionTitle('Próxima consulta'),
      TextField(
        key: const ValueKey<String>('wc-proxima'),
        controller: _next,
        enabled: editable,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Data sugerida (dd/mm/aaaa)',
          helperText: 'Aparece no calendário da criança, para a família.',
        ),
      ),
      if (editable)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: 6,
            children: <Widget>[
              for (final int m in <int>[1, 2, 3, 6])
                ActionChip(
                  label: Text('em $m ${m == 1 ? 'mês' : 'meses'}'),
                  onPressed: () => _next.text = formatDmy(
                    DateTime(today.year, today.month + m, today.day),
                  ),
                ),
            ],
          ),
        ),
      DemoSectionTitle(
        'Itens de acompanhamento',
        trailing: editable
            ? TextButton.icon(
                onPressed: _addFollowUp,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Item'),
              )
            : null,
      ),
      if (_v.followUps.isEmpty)
        Text('Nenhum item de acompanhamento.', style: t.bodySmall),
      for (final FollowUpItem f in _v.sortedFollowUps)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: Text(f.title),
          subtitle: Text(formatDmy(f.due)),
          trailing: editable
              ? IconButton(
                  tooltip: 'Remover item',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _v = _v.copyWith(
                      followUps: _v.followUps
                          .where((FollowUpItem x) => x.id != f.id)
                          .toList(),
                    );
                    _dirty = true;
                  }),
                )
              : null,
        ),
      Text(
        'Próxima consulta e itens entram no calendário da família quando a '
        'consulta é finalizada.',
        style: t.bodySmall,
      ),
    ];
  }

  List<Widget> _resumo(DemoPatient p, DemoConsultation c) {
    final TextTheme t = Theme.of(context).textTheme;
    final WellChildVisit v = _compose(report: false) ?? _v;
    Widget block(String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: t.labelLarge?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(text.trim().isEmpty ? '-' : text.trim()),
        ],
      ),
    );
    return <Widget>[
      if (_dirty)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: DemoNotice(
            icon: Icons.save_outlined,
            color: AppColors.warning,
            text: 'Há alterações não salvas. O PDF usa o conteúdo salvo.',
          ),
        ),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final WellChildSection s in WellChildSection.values)
              block(s.label, v.field(s)),
            block(
              'Marcos do desenvolvimento',
              v.milestones
                  .map((MilestoneObservation m) => m.describe())
                  .join('\n'),
            ),
            block(
              'Dúvidas dos responsáveis',
              v.questions
                  .map(
                    (GuardianQuestion q) =>
                        '${q.question}${q.answer.isEmpty ? '' : ' - ${q.answer}'}',
                  )
                  .join('\n'),
            ),
            block('Orientações dadas', v.guidance),
            block(
              'Acompanhamento',
              <String>[
                if (v.nextVisit != null)
                  'Próxima consulta: ${formatDmy(v.nextVisit!)}',
                for (final FollowUpItem f in v.sortedFollowUps)
                  '${formatDmy(f.due)} - ${f.title}',
              ].join('\n'),
            ),
            if (v.imports.isNotEmpty)
              block(
                'Dados da família incorporados (revisados)',
                v.imports
                    .map(
                      (FamilyImport i) =>
                          '${i.source} (${i.period}) - revisado por '
                          '${i.reviewedBy} em ${formatDmy(i.at)}',
                    )
                    .join('\n'),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          FilledButton.icon(
            onPressed: _busy ? null : () => _pdf(p, c, PdfDelivery.download),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Resumo em PDF'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pdf(p, c, PdfDelivery.print),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        c.isDraft
            ? 'Enquanto for rascunho, o PDF sai com a marca RASCUNHO.'
            : 'PDF com a logomarca gravada ao finalizar.',
        style: t.bodySmall,
      ),
      const DemoSectionTitle('Histórico'),
      for (final VisitRevision r in c.wellChild!.history.reversed)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded, size: 20),
          title: Text(WellChildVisit.historyLine(r)),
          trailing: r.before == null
              ? null
              : TextButton(
                  onPressed: () => _showBefore(r),
                  child: const Text('Versão anterior'),
                ),
        ),
    ];
  }

  void _showBefore(VisitRevision r) {
    final WellChildVisit b = r.before!;
    showDialog<void>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text('Antes de: ${r.action}'),
        content: SingleChildScrollView(
          child: Text(
            <String>[
              for (final WellChildSection s in WellChildSection.values)
                if (r.changes.contains(s.label))
                  '${s.label}: ${b.field(s).isEmpty ? '-' : b.field(s)}',
              if (r.changes.contains('Orientações dadas'))
                'Orientações dadas: ${b.guidance.isEmpty ? '-' : b.guidance}',
              if (r.changes.contains('Próxima consulta'))
                'Próxima consulta: ${b.nextVisit == null ? '-' : formatDmy(b.nextVisit!)}',
              if (r.changes.contains('Marcos do desenvolvimento'))
                'Marcos: ${b.milestones.map((MilestoneObservation m) => m.describe()).join('; ')}',
            ].join('\n\n'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _AgeBox extends StatelessWidget {
  const _AgeBox({required this.age});

  final VisitAge age;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: age.usesCorrected ? const Color(0xFFFFF4E0) : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: age.usesCorrected ? AppColors.warning : AppColors.line,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              age.usesCorrected
                  ? Icons.info_outline_rounded
                  : Icons.cake_outlined,
              color: age.usesCorrected ? AppColors.warning : AppColors.navy,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(age.label)),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.title,
    required this.state,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final MilestoneState? state;
  final bool enabled;
  final ValueChanged<MilestoneState?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final MilestoneState s in MilestoneState.values)
                ChoiceChip(
                  label: Text(s.label),
                  visualDensity: VisualDensity.compact,
                  selected: state == s,
                  tooltip: '$title: ${s.label}',
                  onSelected: enabled
                      ? (bool v) => onChanged(v ? s : null)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current, required this.onTap});

  final WellChildStep current;
  final ValueChanged<WellChildStep> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final WellChildStep s in WellChildStep.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: s == WellChildStep.resumo ? 0 : AppSpacing.xs,
              ),
              child: Semantics(
                button: true,
                selected: s == current,
                label: 'Etapa ${s.index + 1}: ${s.title}',
                excludeSemantics: true,
                onTap: () => onTap(s),
                child: InkWell(
                  onTap: () => onTap(s),
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 2,
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

/// Meus modelos de evolução, com os da faixa etária da criança primeiro.
class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.band});

  final ChildAgeBand band;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<WellChildTemplate> all =
        List<WellChildTemplate>.of(demoSession.myWellChildTemplates)..sort(
          (WellChildTemplate a, WellChildTemplate b) =>
              (a.band == band ? 0 : 1).compareTo(b.band == band ? 0 : 1),
        );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: <Widget>[
          Text('Meus modelos de puericultura', style: t.titleLarge),
          Text(
            'Campos já escritos são mantidos. Tudo continua editável.',
            style: t.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (all.isEmpty)
            const Text('Nenhum modelo salvo nesta conta.')
          else
            for (final WellChildTemplate m in all)
              Card(
                child: ListTile(
                  title: Text(m.name),
                  subtitle: Text(
                    '${m.band?.label ?? 'Qualquer idade'} · v${m.version}'
                    '${m.isExample ? ' · exemplo a revisar' : ''}'
                    '${m.band == band ? ' · faixa da criança' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(m),
                ),
              ),
        ],
      ),
    );
  }
}
