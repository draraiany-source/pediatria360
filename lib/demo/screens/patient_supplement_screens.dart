import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/lab_results.dart';
import '../../shared/clinical/supplement_library.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'dose_screens.dart';

String _q(String? consultationId) =>
    consultationId == null ? '' : '?consulta=$consultationId';

/// Resultados conferidos relacionados ao tema (vínculo feito pelo
/// profissional ou sugerido pelo nome do exame).
List<LabResult> _relatedConfirmed(String patientId, String topicId) =>
    demoSession.labsFor(patientId).where((LabResult r) {
      if (!r.inRecord) return false;
      return r.topicIds.contains(topicId) ||
          suggestedTopicsFor(r.values.testName).contains(topicId);
    }).toList()..sort(
      (LabResult a, LabResult b) =>
          b.values.collectedAt!.compareTo(a.values.collectedAt!),
    );

class DemoPatientSupplementScreen extends StatefulWidget {
  const DemoPatientSupplementScreen({
    required this.patientId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String? consultationId;

  @override
  State<DemoPatientSupplementScreen> createState() =>
      _DemoPatientSupplementScreenState();
}

class _DemoPatientSupplementScreenState
    extends State<DemoPatientSupplementScreen> {
  String _search = '';
  String? _group;

  String get _back => widget.consultationId == null
      ? '/pacientes/${widget.patientId}'
      : '/pacientes/${widget.patientId}/consulta/${widget.consultationId}?etapa=conduta';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Suplementação')),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message: 'Volte para a lista de pacientes.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final String q = _search.trim().toLowerCase();
        final List<SupplementSheet> sheets = demoSession.supplementSheets
            .where(
              (SupplementSheet s) =>
                  s.group != 'Exames' &&
                  (_group == null || s.group == _group) &&
                  (q.isEmpty || s.title.toLowerCase().contains(q)),
            )
            .toList();
        final int pending = demoSession
            .labsFor(p.id)
            .where((LabResult r) => r.isPending)
            .length;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(_back),
            ),
            title: const Text('Suplementação do paciente'),
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go(_back),
            backLabel: widget.consultationId == null
                ? 'Voltar ao paciente'
                : 'Voltar à consulta',
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DemoPatientStrip(patient: p),
                    const SizedBox(height: AppSpacing.md),
                    const DemoNotice(
                      icon: Icons.medication_liquid_outlined,
                      color: AppColors.warning,
                      text:
                          'Registre aqui a decisão do profissional por tema. Fichas '
                          'sem validação aparecem como rascunho. Exames pendentes de '
                          'conferência não entram na avaliação. Nenhuma conduta é '
                          'sugerida automaticamente.',
                    ),
                    if (pending > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      DemoNotice(
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                        text:
                            '$pending ${pending == 1 ? 'laudo importado aguarda' : 'laudos importados aguardam'} '
                            'conferência em Exames.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      child: TextField(
                        onChanged: (String v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          hintText: 'Buscar nutriente',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _group == null,
                          onSelected: (_) => setState(() => _group = null),
                        ),
                        for (final String g in kSheetGroups.where(
                          (String g) => g != 'Exames',
                        ))
                          ChoiceChip(
                            label: Text(g),
                            selected: _group == g,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final SupplementSheet s in sheets)
                      _TopicTile(
                        patientId: p.id,
                        sheet: s,
                        consultationId: widget.consultationId,
                      ),
                    if (sheets.isEmpty)
                      const SurfaceCard(child: Text('Nenhum tema encontrado.')),
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

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.patientId,
    required this.sheet,
    this.consultationId,
  });

  final String patientId;
  final SupplementSheet sheet;
  final String? consultationId;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final SupplementDecision? d = demoSession.decisionFor(patientId, sheet.id);
    final int results = _relatedConfirmed(patientId, sheet.id).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.go(
          '/pacientes/$patientId/suplementacao/${sheet.id}${_q(consultationId)}',
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sheet.title,
                    style: t.titleSmall?.copyWith(color: AppColors.navy),
                  ),
                  Text(
                    '${d == null ? 'Sem decisão registrada' : 'Decisão: ${d.current.kind.label} (${formatDocDate(d.current.at)})'}'
                    ' · $results ${results == 1 ? 'exame conferido' : 'exames conferidos'}',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            ClinicalBadge(
              label: sheet.isDraft ? 'Ficha em rascunho' : 'Ficha validada',
              color: sheet.isDraft ? AppColors.warning : AppColors.success,
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------ Decisão por tema

class DemoSupplementDecisionScreen extends StatefulWidget {
  const DemoSupplementDecisionScreen({
    required this.patientId,
    required this.topicId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String topicId;
  final String? consultationId;

  @override
  State<DemoSupplementDecisionScreen> createState() =>
      _DemoSupplementDecisionScreenState();
}

class _DemoSupplementDecisionScreenState
    extends State<DemoSupplementDecisionScreen> {
  late final DemoPatient? _p = demoSession.patientById(widget.patientId);
  late final SupplementSheet? _sheet = demoSession.sheetById(widget.topicId);
  final TextEditingController _note = TextEditingController();
  SupplementDecisionKind? _kind;
  Set<String> _labs = <String>{};
  bool _dirty = false;
  String? _error;

  SupplementDecision? get _decision =>
      demoSession.decisionFor(widget.patientId, widget.topicId);

  String get _back =>
      '/pacientes/${widget.patientId}/suplementacao${_q(widget.consultationId)}';

  @override
  void initState() {
    super.initState();
    final SupplementDecision? d = _decision;
    if (d != null) {
      _kind = d.current.kind;
      _note.text = d.current.note;
      _labs = Set<String>.of(d.current.labResultIds);
    }
    _note.addListener(() {
      if (mounted) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final DemoPatient p = _p!;
    if (_kind == null) {
      setState(() => _error = 'Escolha a decisão.');
      return;
    }
    if (_note.text.trim().isEmpty) {
      setState(() => _error = 'Registre a justificativa da decisão.');
      return;
    }
    final SupplementDecision? d = _decision;
    if (d != null &&
        d.current.kind == _kind &&
        d.current.note == _note.text.trim() &&
        d.current.labResultIds.toSet().containsAll(_labs) &&
        _labs.containsAll(d.current.labResultIds)) {
      setState(() {
        _dirty = false;
        _error = null;
      });
      showDemoSnack(context, 'Nada mudou desde a última versão.');
      return;
    }
    final SupplementDecisionVersion v = SupplementDecisionVersion(
      kind: _kind!,
      note: _note.text.trim(),
      author: demoSession.currentAuthor,
      at: DateTime.now(),
      sheetStatus: _sheet!.status,
      labResultIds: _labs.toList(),
      consultationId: widget.consultationId,
    );
    demoSession.saveDecision(
      d == null
          ? SupplementDecision.create(
              id: demoSession.newId('s'),
              patientId: p.id,
              topicId: widget.topicId,
              first: v,
            )
          : d.revise(v),
    );
    setState(() {
      _dirty = false;
      _error = null;
    });
    showDemoSnack(
      context,
      _kind!.goesToPrescription
          ? 'Decisão salva. Leve o item à calculadora e ao receituário para revisar.'
          : 'Decisão salva (versão ${_decision!.versions.length}).',
    );
  }

  Future<void> _toPrescription() async {
    final DemoPatient p = _p!;
    final SupplementDecision d = _decision!;
    final RxItem? item = await openDoseCalculator(
      context,
      p,
      contextNote:
          'Origem: decisão de suplementação - ${_sheet!.title} '
          '(${formatDocDate(d.current.at)}). A calculadora confere a conta; a '
          'prescrição continua em rascunho para revisão no receituário.',
    );
    if (item == null || !mounted) return;
    final DateTime now = DateTime.now();
    final String? consultationId =
        widget.consultationId ?? d.current.consultationId;
    final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
      id: demoSession.newDocumentId(),
      kind: DocKind.receituario,
      patientId: p.id,
      consultationId: consultationId,
      author: demoSession.currentAuthor,
      context: DemoClinicalSeed.contextFor(
        p,
        date: DateTime(now.year, now.month, now.day),
      ),
      now: now,
      items: <RxItem>[item],
    );
    demoSession.saveDocument(doc);
    demoSession.saveDecision(d.withPrescription(doc.id));
    showDemoSnack(
      context,
      'Item levado a um receituário em rascunho. Revise antes de emitir.',
    );
    context.go('/pacientes/${p.id}/documentos/${doc.id}/editar');
  }

  Future<void> _leave() async {
    if (!_dirty || await confirmDiscard(context)) {
      if (mounted) context.go(_back);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = _p;
    final SupplementSheet? s = _sheet;
    if (p == null || s == null || s.group == 'Exames') {
      return Scaffold(
        appBar: AppBar(title: const Text('Suplementação')),
        body: DemoEmpty(
          title: 'Tema não encontrado',
          message: 'Volte para a suplementação do paciente.',
          actionLabel: 'Pacientes',
          onAction: () => context.go('/pacientes'),
        ),
      );
    }
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) => _build(context, p, s),
    );
  }

  Widget _build(BuildContext context, DemoPatient p, SupplementSheet s) {
    final TextTheme t = Theme.of(context).textTheme;
    final SupplementDecision? d = _decision;
    final List<LabResult> related = _relatedConfirmed(p.id, s.id);
    final List<LabResult> pending = demoSession
        .labsFor(p.id)
        .where((LabResult r) => r.isPending)
        .toList();
    final bool canPrescribe =
        d != null && d.current.kind.goesToPrescription && !_dirty;

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
          title: Text('${s.title} - decisão'),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          primaryLabel: d == null ? 'Salvar decisão' : 'Salvar nova versão',
          primaryIcon: Icons.save_outlined,
          onPrimary: _save,
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
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Ficha: ${s.title}',
                                style: t.titleMedium?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            ClinicalBadge(
                              label: s.isDraft ? 'Rascunho' : 'Validado',
                              color: s.isDraft
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fonte: ${s.source.trim().isEmpty ? 'não informada' : s.source.trim()}',
                          style: t.bodySmall,
                        ),
                        Text(
                          'Última revisão: ${s.reviewedAt == null ? 'não revisada' : formatDocDate(s.reviewedAt!)}',
                          style: t.bodySmall,
                        ),
                        if (s.isDraft)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: DemoNotice(
                              icon: Icons.edit_note_rounded,
                              color: AppColors.warning,
                              text:
                                  'Ficha em rascunho: conteúdo não validado. A decisão '
                                  'é do profissional e registra que a ficha estava em '
                                  'rascunho.',
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () => context.go('/suplementacao/${s.id}'),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Abrir ficha do tema'),
                        ),
                      ],
                    ),
                  ),
                  const DemoSectionTitle('Exames conferidos relacionados'),
                  if (related.isEmpty)
                    const SurfaceCard(
                      child: Text(
                        'Nenhum resultado conferido relacionado a este tema.',
                      ),
                    ),
                  for (final LabResult r in related)
                    CheckboxListTile(
                      value: _labs.contains(r.id),
                      onChanged: (bool? on) => setState(() {
                        _dirty = true;
                        _labs = <String>{..._labs};
                        on == true ? _labs.add(r.id) : _labs.remove(r.id);
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r.values.testName}: ${r.values.value} ${r.values.unit}',
                      ),
                      subtitle: Text(
                        '${formatLabDate(r.values.collectedAt!)} - ${r.values.laboratory} - '
                        'intervalo do laudo: ${r.values.range.isEmpty ? 'não informado' : r.values.range.label}',
                      ),
                    ),
                  if (pending.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '${pending.length} ${pending.length == 1 ? 'laudo importado está pendente' : 'laudos importados estão pendentes'} '
                        'de conferência e não pode ser usado aqui até ser conferido.',
                        style: t.bodySmall?.copyWith(color: AppColors.warning),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go(
                        '/pacientes/${p.id}/exames${_q(widget.consultationId)}',
                      ),
                      icon: const Icon(Icons.biotech_outlined),
                      label: const Text('Abrir exames do paciente'),
                    ),
                  ),
                  const DemoSectionTitle('Decisão do profissional'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final SupplementDecisionKind k
                          in SupplementDecisionKind.values)
                        ChoiceChip(
                          label: Text(k.label),
                          selected: _kind == k,
                          onSelected: (_) => setState(() {
                            _kind = k;
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    container: true,
                    child: TextField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Justificativa e registro da decisão *',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: DemoNotice(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        text: _error!,
                      ),
                    ),
                  if (d != null &&
                      d.current.kind.goesToPrescription) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    PremiumCard(
                      borderColor: AppColors.brand,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Suplementação indicada',
                            style: t.titleSmall?.copyWith(
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            canPrescribe
                                ? 'Leve o item à calculadora; ele entra num '
                                      'receituário em rascunho para revisão.'
                                : 'Salve a decisão antes de levar o item à calculadora.',
                            style: t.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: canPrescribe ? _toPrescription : null,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text(
                                'Levar à calculadora e ao receituário',
                              ),
                            ),
                          ),
                          for (final String id in d.prescriptionDocIds)
                            if (demoSession.documentById(id)
                                case final ClinicalDocRecord doc)
                              TextButton.icon(
                                onPressed: () => context.go(
                                  '/pacientes/${p.id}/documentos/${doc.id}',
                                ),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: Text(
                                  'Receituário de ${formatDocDate(doc.current.updatedAt)} '
                                  '(${doc.current.status.label})',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                  const DemoSectionTitle('Histórico da decisão'),
                  if (d == null)
                    const SurfaceCard(
                      child: Text('Nenhuma decisão registrada para este tema.'),
                    )
                  else
                    for (int i = d.versions.length - 1; i >= 0; i--)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Versão ${i + 1} - ${formatDocDateTime(d.versions[i].at)} - '
                                '${d.versions[i].author}',
                                style: t.titleSmall?.copyWith(
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                d.versions[i].kind.label,
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(d.versions[i].note, style: t.bodySmall),
                              Text(
                                'Ficha no momento: ${d.versions[i].sheetStatus.label}. '
                                'Exames considerados: '
                                '${d.versions[i].labResultIds.isEmpty ? 'nenhum' : d.versions[i].labResultIds.map((String id) => demoSession.labById(id)).whereType<LabResult>().map((LabResult r) => '${r.values.testName} ${r.values.value} ${r.values.unit} (${formatLabDate(r.values.collectedAt!)})').join('; ')}.',
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
                      onPressed: () async {
                        if (!_dirty || await confirmDiscard(context)) {
                          if (context.mounted) context.go('/pacientes/${p.id}');
                        }
                      },
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
      ),
    );
  }
}
