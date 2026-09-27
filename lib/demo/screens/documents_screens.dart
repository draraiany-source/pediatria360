import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/clinical_pdf.dart';
import '../../shared/clinical/orientation_templates.dart';
import '../../shared/clinical/pdf_output.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'dose_screens.dart';

/// Contexto de preenchimento: dados atuais do paciente e da consulta ligada.
DocContext demoDocContext(
  DemoPatient p, {
  String? consultationId,
  DateTime? fallbackDate,
}) {
  final DemoConsultation? c = consultationId == null
      ? null
      : demoSession.consultationById(consultationId);
  final DateTime d = c?.startedAt ?? fallbackDate ?? DateTime.now();
  return DemoClinicalSeed.contextFor(
    p,
    date: DateTime(d.year, d.month, d.day),
    clinicalSummary: c == null || c.assessment.trim().isEmpty
        ? null
        : c.assessment.trim(),
  );
}

String _docsPath(String patientId) => '/pacientes/$patientId/documentos';

Widget _notFound(BuildContext context, String title) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: DemoEmpty(
    title: 'Registro não encontrado',
    message: 'Este registro não existe ou não pertence ao perfil atual.',
    actionLabel: 'Pacientes',
    onAction: () => context.go('/pacientes'),
  ),
);

Future<void> pickNewDocument(
  BuildContext context,
  String patientId, {
  String? consultationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Novo documento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final DocKind k in DocKind.values)
              ListTile(
                leading: Icon(docKindIcon(k), color: AppColors.brand),
                title: Text(k.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.go(
                    '${_docsPath(patientId)}/novo?tipo=${k.slug}'
                    '${consultationId == null ? '' : '&consulta=$consultationId'}',
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

IconData docKindIcon(DocKind k) => switch (k) {
  DocKind.atestado => Icons.assignment_turned_in_outlined,
  DocKind.comparecimento => Icons.how_to_reg_outlined,
  DocKind.encaminhamento => Icons.forward_to_inbox_outlined,
  DocKind.orientacoes => Icons.menu_book_outlined,
  DocKind.exames => Icons.biotech_outlined,
  DocKind.receituario => Icons.medication_outlined,
};

/// Cartão de documento para histórico e consulta.
class DemoDocTile extends StatelessWidget {
  const DemoDocTile({required this.doc, super.key});

  final ClinicalDocRecord doc;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DocVersion v = doc.current;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.go('${_docsPath(doc.patientId)}/${doc.id}'),
        child: Row(
          children: <Widget>[
            Icon(docKindIcon(doc.kind), color: AppColors.brand),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(doc.title, style: t.titleSmall),
                  Text(
                    'v${v.number} · ${v.author} · ${formatDocDateTime(v.updatedAt)}',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DocStatusChip(v.status),
                      SignatureChip(doc.signature),
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

// ------------------------------------------------------------------ Histórico

class DemoDocumentsScreen extends StatefulWidget {
  const DemoDocumentsScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<DemoDocumentsScreen> createState() => _DemoDocumentsScreenState();
}

class _DemoDocumentsScreenState extends State<DemoDocumentsScreen> {
  DocKind? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        if (p == null) return _notFound(context, 'Documentos');
        final List<ClinicalDocRecord> all = demoSession.documentsFor(p.id);
        final List<ClinicalDocRecord> list = _filter == null
            ? all
            : all.where((ClinicalDocRecord d) => d.kind == _filter).toList();
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: const Text('Documentos'),
            actions: <Widget>[DemoRecordShortcut(patientId: p.id)],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => pickNewDocument(context, p.id),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Novo documento'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            children: <Widget>[
              DemoContent(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DemoPatientStrip(patient: p),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        ChoiceChip(
                          label: Text('Todos (${all.length})'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                        for (final DocKind k in DocKind.values)
                          ChoiceChip(
                            label: Text(k.label),
                            selected: _filter == k,
                            onSelected: (_) => setState(() => _filter = k),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'Nenhum documento deste tipo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final ClinicalDocRecord d in list) DemoDocTile(doc: d),
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

// ------------------------------------------------------------------ Editor

class DemoDocumentEditorScreen extends StatefulWidget {
  const DemoDocumentEditorScreen({
    required this.patientId,
    super.key,
    this.docId,
    this.kind,
    this.consultationId,
  });

  final String patientId;
  final String? docId;
  final DocKind? kind;
  final String? consultationId;

  @override
  State<DemoDocumentEditorScreen> createState() =>
      _DemoDocumentEditorScreenState();
}

class _DemoDocumentEditorScreenState extends State<DemoDocumentEditorScreen> {
  ClinicalDocRecord? _record;
  late DocKind _kind;
  String? _consultationId;
  final Map<String, TextEditingController> _c =
      <String, TextEditingController>{};
  final Map<String, String> _options = <String, String>{};
  List<RxItem> _items = <RxItem>[];
  bool _dirty = false;
  bool _ready = false;

  DemoPatient? get _patient => demoSession.patientById(widget.patientId);

  @override
  void initState() {
    super.initState();
    final DemoPatient? p = _patient;
    if (p == null) return;
    _record = widget.docId == null
        ? null
        : demoSession.documentById(widget.docId!);
    if (widget.docId != null && _record == null) return;
    _kind = _record?.kind ?? widget.kind ?? DocKind.atestado;
    _consultationId = _record?.consultationId ?? widget.consultationId;
    final Map<String, String> values =
        _record?.current.fields ?? DocumentTemplates.prefill(_kind, _ctx(p));
    _items = List<RxItem>.of(_record?.current.items ?? const <RxItem>[]);
    for (final DocFieldSpec f in DocumentTemplates.fields(_kind)) {
      if (f.options != null) {
        _options[f.key] = values[f.key]?.isNotEmpty == true
            ? values[f.key]!
            : f.options!.first;
      } else {
        _c[f.key] = TextEditingController(text: values[f.key] ?? '')
          ..addListener(_markDirty);
      }
    }
    _ready = true;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  DocContext _ctx(DemoPatient p) => demoDocContext(
    p,
    consultationId: _consultationId,
    fallbackDate: _record?.versions.first.createdAt,
  );

  Map<String, String> get _fields => <String, String>{
    for (final MapEntry<String, TextEditingController> e in _c.entries)
      e.key: e.value.text,
    ..._options,
  };

  String get _backPath {
    if (_consultationId != null) {
      return '/pacientes/${widget.patientId}/consulta/$_consultationId?etapa=documentos';
    }
    if (_record != null) return '${_docsPath(widget.patientId)}/${_record!.id}';
    return _docsPath(widget.patientId);
  }

  Future<bool> _canLeave() async => !_dirty || await confirmDiscard(context);

  Future<void> _leave() async {
    if (await _canLeave() && mounted) context.go(_backPath);
  }

  ClinicalDocRecord _save(DemoPatient p) {
    final DateTime now = DateTime.now();
    final ClinicalDocRecord r = _record == null
        ? ClinicalDocRecord.createDraft(
            id: demoSession.newDocumentId(),
            kind: _kind,
            patientId: p.id,
            consultationId: _consultationId,
            author: demoSession.currentAuthor,
            context: _ctx(p),
            now: now,
            fields: _fields,
            items: _items,
          )
        : _record!.saveDraft(
            fields: _fields,
            items: _items,
            context: _ctx(p),
            author: demoSession.currentAuthor,
            now: now,
          );
    demoSession.saveDocument(r);
    setState(() {
      _record = r;
      _dirty = false;
    });
    return r;
  }

  void _saveDraft(DemoPatient p) {
    final ClinicalDocRecord r = _save(p);
    showDemoSnack(
      context,
      'Rascunho salvo (versão ${r.current.number}). Nada sai desta aba.',
    );
  }

  void _saveAndReview(DemoPatient p) {
    final ClinicalDocRecord r = _save(p);
    context.go('${_docsPath(p.id)}/${r.id}');
  }

  Future<void> _addFromCalculator(DemoPatient p) async {
    final RxItem? item = await openDoseCalculator(context, p);
    if (item == null || !mounted) return;
    setState(() {
      _items = <RxItem>[..._items, item];
      _dirty = true;
    });
    showDemoSnack(
      context,
      '${item.drug} inserido. Revise a receita antes de emitir.',
    );
  }

  Future<void> _editManual({RxItem? existing, int? index}) async {
    final RxItem? item = await showDialog<RxItem>(
      context: context,
      builder: (BuildContext c) => _ManualItemDialog(initial: existing),
    );
    if (item == null || !mounted) return;
    setState(() {
      _items = <RxItem>[
        for (int i = 0; i < _items.length; i++) i == index ? item : _items[i],
        if (index == null) item,
      ];
      _dirty = true;
    });
  }

  void _applyTemplate(OrientationTemplate t, DemoPatient p) {
    _c['titulo']!.text = t.title.replaceFirst('Modelo de exemplo: ', '');
    _c['texto']!.text = t.personalize(_ctx(p), DateTime.now());
    showDemoSnack(
      context,
      'Modelo aplicado com os dados de ${p.name}. Revise o texto.',
    );
  }

  Future<void> _saveAsTemplate(DemoPatient p) async {
    final String text = _c['texto']!.text.trim();
    if (text.isEmpty) {
      showDemoSnack(
        context,
        'Escreva as orientações antes de salvar como modelo.',
      );
      return;
    }
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext c) =>
          _TemplateNameDialog(initial: _c['titulo']!.text.trim()),
    );
    if (title == null || title.isEmpty || !mounted) return;
    demoSession.addOrientationTemplate(
      title,
      OrientationTemplate.generalize(text, _ctx(p)),
    );
    showDemoSnack(context, 'Modelo "$title" salvo nesta demonstração.');
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = _patient;
    if (p == null || !_ready) return _notFound(context, 'Documento');
    final TextTheme t = Theme.of(context).textTheme;
    final DocContext ctx = _ctx(p);
    final String preview = DocumentTemplates.render(
      _kind,
      _fields,
      ctx,
      _items,
    );
    final List<String> issues = DocumentTemplates.missing(
      _kind,
      _fields,
      _items,
      preview,
    );
    final bool newVersion = _record?.status == DocStatus.issued;

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
            _record == null ? 'Novo: ${_kind.label}' : 'Editar: ${_kind.label}',
          ),
          actions: <Widget>[
            DemoRecordShortcut(patientId: p.id, onLeave: _canLeave),
          ],
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _leave,
          onSaveDraft: () => _saveDraft(p),
          primaryLabel: 'Salvar e revisar',
          primaryIcon: Icons.fact_check_outlined,
          onPrimary: () => _saveAndReview(p),
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
                  DemoNotice(
                    text: newVersion
                        ? 'Este documento já foi emitido. Salvar cria a versão '
                              '${_record!.current.number + 1}; a versão emitida fica preservada.'
                        : 'Dados do paciente e do profissional preenchidos '
                              'automaticamente. Revise tudo: a emissão só é liberada '
                              'depois da revisão.',
                  ),
                  if (_kind == DocKind.orientacoes) ...<Widget>[
                    const DemoSectionTitle('Modelos de orientação'),
                    _TemplatePicker(
                      onApply: (OrientationTemplate tpl) =>
                          _applyTemplate(tpl, p),
                      onSaveAsTemplate: () => _saveAsTemplate(p),
                    ),
                  ],
                  const DemoSectionTitle('Campos'),
                  for (final DocFieldSpec f in DocumentTemplates.fields(_kind))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: f.options != null
                          ? DropdownButtonFormField<String>(
                              initialValue: _options[f.key],
                              decoration: InputDecoration(
                                labelText:
                                    '${f.label}${f.required ? ' *' : ''}',
                              ),
                              items: <DropdownMenuItem<String>>[
                                for (final String o in f.options!)
                                  DropdownMenuItem<String>(
                                    value: o,
                                    child: Text(o),
                                  ),
                              ],
                              onChanged: (String? v) => setState(() {
                                _options[f.key] = v ?? f.options!.first;
                                _dirty = true;
                              }),
                            )
                          : TextField(
                              key: ValueKey<String>('campo-${f.key}'),
                              controller: _c[f.key],
                              minLines: f.lines,
                              maxLines: f.lines == 1 ? 1 : f.lines + 4,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText:
                                    '${f.label}${f.required ? ' *' : ''}',
                                hintText: f.hint,
                                alignLabelWithHint: f.lines > 1,
                              ),
                            ),
                    ),
                  if (_kind == DocKind.receituario) ...<Widget>[
                    const DemoSectionTitle('Medicamentos'),
                    for (int i = 0; i < _items.length; i++)
                      _RxItemCard(
                        index: i,
                        item: _items[i],
                        onRemove: () => setState(() {
                          _items = List<RxItem>.of(_items)..removeAt(i);
                          _dirty = true;
                        }),
                        onEdit: () =>
                            _editManual(existing: _items[i], index: i),
                      ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => _addFromCalculator(p),
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Calcular dose e inserir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editManual(),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Adicionar item manualmente'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Itens manuais não passam pela calculadora: confira dose, '
                      'apresentação e intervalo. Medicamentos de controle especial '
                      'não são emitidos por este modelo.',
                      style: t.bodySmall,
                    ),
                  ],
                  if (issues.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    DemoNotice(
                      icon: Icons.rule_rounded,
                      color: AppColors.warning,
                      text: 'Pendências para revisar: ${issues.join('; ')}.',
                    ),
                  ],
                  const DemoSectionTitle('Pré-visualização'),
                  _Paper(text: preview),
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

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.initial});

  final String initial;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salvar como modelo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'O nome da criança e do responsável viram marcadores '
            '({{crianca}}, {{responsavel}}) para o modelo servir a outros pacientes.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome do modelo'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text.trim()),
          child: const Text('Salvar modelo'),
        ),
      ],
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.onApply,
    required this.onSaveAsTemplate,
  });

  final ValueChanged<OrientationTemplate> onApply;
  final VoidCallback onSaveAsTemplate;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final OrientationTemplate tpl
              in demoSession.orientationTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: PremiumCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tpl.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${tpl.isExample ? 'Exemplo a revisar · ' : ''}'
                            '${tpl.author} · ${formatDocDate(tpl.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onApply(tpl),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSaveAsTemplate,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Salvar texto atual como modelo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RxItemCard extends StatelessWidget {
  const _RxItemCard({
    required this.index,
    required this.item,
    required this.onRemove,
    required this.onEdit,
  });

  final int index;
  final RxItem item;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${index + 1}. ${item.drug} - ${item.presentation}',
                    style: t.titleSmall,
                  ),
                ),
                if (item.calculation != null)
                  const ClinicalBadge(
                    label: 'Calculado',
                    color: AppColors.success,
                  )
                else
                  const ClinicalBadge(
                    label: 'Manual',
                    color: AppColors.warning,
                  ),
                IconButton(
                  tooltip: 'Editar item',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Remover item',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            Text(item.posology),
            if (item.quantity.isNotEmpty)
              Text('Quantidade: ${item.quantity}', style: t.bodySmall),
            if (item.calculation != null)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Conta conferida', style: t.labelLarge),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.calculation!, style: t.bodySmall),
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

class _ManualItemDialog extends StatefulWidget {
  const _ManualItemDialog({this.initial});

  final RxItem? initial;

  @override
  State<_ManualItemDialog> createState() => _ManualItemDialogState();
}

class _ManualItemDialogState extends State<_ManualItemDialog> {
  late final Map<String, TextEditingController>
  _c = <String, TextEditingController>{
    'drug': TextEditingController(text: widget.initial?.drug),
    'presentation': TextEditingController(text: widget.initial?.presentation),
    'dose': TextEditingController(text: widget.initial?.dose),
    'route': TextEditingController(text: widget.initial?.route ?? 'via oral'),
    'frequency': TextEditingController(text: widget.initial?.frequency),
    'duration': TextEditingController(text: widget.initial?.duration),
    'quantity': TextEditingController(text: widget.initial?.quantity),
  };
  bool _tried = false;

  static const Map<String, String> _labels = <String, String>{
    'drug': 'Medicamento *',
    'presentation': 'Apresentação e concentração *',
    'dose': 'Dose por administração *',
    'route': 'Via',
    'frequency': 'Intervalo *',
    'duration': 'Duração *',
    'quantity': 'Quantidade',
  };

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  RxItem get _item => RxItem(
    drug: _c['drug']!.text.trim(),
    presentation: _c['presentation']!.text.trim(),
    dose: _c['dose']!.text.trim(),
    route: _c['route']!.text.trim(),
    frequency: _c['frequency']!.text.trim(),
    duration: _c['duration']!.text.trim(),
    quantity: _c['quantity']!.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Item manual' : 'Editar item'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String k in _labels.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(
                    controller: _c[k],
                    decoration: InputDecoration(
                      labelText: _labels[k],
                      errorText:
                          _tried &&
                              _labels[k]!.endsWith('*') &&
                              _c[k]!.text.trim().isEmpty
                          ? 'Obrigatório'
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_item.isComplete) {
              setState(() => _tried = true);
              return;
            }
            Navigator.of(context).pop(_item);
          },
          child: const Text('Salvar item'),
        ),
      ],
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.line),
      ),
      child: SelectableText(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

// ------------------------------------------------------------------ Visualização

class DemoDocumentViewerScreen extends StatefulWidget {
  const DemoDocumentViewerScreen({
    required this.patientId,
    required this.docId,
    super.key,
  });

  final String patientId;
  final String docId;

  @override
  State<DemoDocumentViewerScreen> createState() =>
      _DemoDocumentViewerScreenState();
}

class _DemoDocumentViewerScreenState extends State<DemoDocumentViewerScreen> {
  int? _versionIndex;
  bool _reviewChecked = false;
  bool _busy = false;

  Future<void> _pdf(
    DemoPatient p,
    ClinicalDocRecord shown,
    PdfDelivery delivery,
  ) async {
    setState(() => _busy = true);
    try {
      final DocContext ctx = demoDocContext(
        p,
        consultationId: shown.consultationId,
        fallbackDate: shown.versions.first.createdAt,
      );
      final Uint8List bytes = await ClinicalPdf.build(
        doc: shown,
        context: ctx,
        now: DateTime.now(),
        demo: true,
      );
      final String name = ClinicalPdf.fileName(shown, p.name);
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
      final String kb = (bytes.length / 1024).toStringAsFixed(0);
      showDemoSnack(context, switch (how) {
        'download' => 'PDF gerado ($kb KB): $name',
        'iframe' => 'Abrindo a impressão do PDF ($kb KB)...',
        'tab' => 'PDF aberto em outra aba para imprimir ou compartilhar.',
        _ => 'PDF gerado ($kb KB). Saída disponível na versão web.',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        final ClinicalDocRecord? doc = demoSession.documentById(widget.docId);
        if (p == null || doc == null || doc.patientId != p.id) {
          return _notFound(context, 'Documento');
        }
        final int idx = (_versionIndex ?? doc.versions.length - 1).clamp(
          0,
          doc.versions.length - 1,
        );
        final bool isCurrent = idx == doc.versions.length - 1;
        final ClinicalDocRecord shown = isCurrent
            ? doc
            : ClinicalDocRecord(
                id: doc.id,
                kind: doc.kind,
                patientId: doc.patientId,
                consultationId: doc.consultationId,
                versions: doc.versions.sublist(0, idx + 1),
                signature: doc.signature,
              );
        final DocVersion v = shown.current;
        final List<String> issues = isCurrent
            ? doc.pendingIssues
            : const <String>[];
        final TextTheme t = Theme.of(context).textTheme;
        final String back =
            doc.consultationId != null &&
                demoSession.consultationById(doc.consultationId!)?.isDraft ==
                    true
            ? '/pacientes/${p.id}/consulta/${doc.consultationId}?etapa=documentos'
            : _docsPath(p.id);

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(back),
            ),
            title: Text(doc.kind.label),
            actions: <Widget>[DemoRecordShortcut(patientId: p.id)],
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go(back),
            backLabel: back.contains('consulta')
                ? 'Voltar à consulta'
                : 'Voltar aos documentos',
            primaryLabel: isCurrent
                ? (doc.status == DocStatus.issued
                      ? 'Criar nova versão'
                      : 'Editar')
                : null,
            primaryIcon: Icons.edit_outlined,
            onPrimary: () => context.go('${_docsPath(p.id)}/${doc.id}/editar'),
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
                    Text(
                      doc.title,
                      style: t.headlineSmall?.copyWith(color: AppColors.navy),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        DocStatusChip(v.status),
                        SignatureChip(doc.signature),
                      ],
                    ),
                    if (doc.versions.length > 1) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: <Widget>[
                          for (int i = 0; i < doc.versions.length; i++)
                            ChoiceChip(
                              label: Text(
                                'v${doc.versions[i].number} · ${doc.versions[i].status.label}',
                              ),
                              selected: i == idx,
                              onSelected: (_) =>
                                  setState(() => _versionIndex = i),
                            ),
                        ],
                      ),
                    ],
                    if (!isCurrent)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: DemoNotice(
                          text:
                              'Versão anterior, somente leitura. A versão vigente é a última.',
                        ),
                      ),
                    const DemoSectionTitle('Registro'),
                    _MetaCard(version: v, doc: doc),
                    const DemoSectionTitle('Assinatura e emissão'),
                    _SignatureCard(doc: doc),
                    const DemoSectionTitle('Conteúdo'),
                    _Paper(text: v.body),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pdf(p, shown, PdfDelivery.download),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Gerar PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pdf(p, shown, PdfDelivery.print),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Imprimir'),
                        ),
                      ],
                    ),
                    if (v.status != DocStatus.issued)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'O PDF de rascunho sai com a marca "RASCUNHO - SEM VALIDADE".',
                          style: t.bodySmall,
                        ),
                      ),
                    if (isCurrent &&
                        doc.status != DocStatus.issued) ...<Widget>[
                      const DemoSectionTitle('Revisão e emissão'),
                      if (issues.isNotEmpty)
                        DemoNotice(
                          icon: Icons.rule_rounded,
                          color: AppColors.warning,
                          text:
                              'Resolva no editor antes de revisar: ${issues.join('; ')}.',
                        ),
                      if (doc.status == DocStatus.draft) ...<Widget>[
                        CheckboxListTile(
                          key: const ValueKey<String>('review-check'),
                          value: _reviewChecked,
                          onChanged: issues.isEmpty
                              ? (bool? x) =>
                                    setState(() => _reviewChecked = x ?? false)
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Revisei o conteúdo e os dados do paciente e '
                            'do profissional; o documento é de minha responsabilidade.',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: issues.isEmpty && _reviewChecked
                              ? () {
                                  demoSession.saveDocument(
                                    doc.markReviewed(
                                      reviewer: demoSession.currentAuthor,
                                      now: DateTime.now(),
                                    ),
                                  );
                                  setState(() => _reviewChecked = false);
                                  showDemoSnack(
                                    context,
                                    'Documento revisado e pronto para emissão.',
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Marcar como revisado'),
                        ),
                      ],
                      if (doc.status == DocStatus.reviewed) ...<Widget>[
                        Text(
                          'Revisado por ${v.reviewedBy} em ${formatDocDateTime(v.reviewedAt!)}.',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: () {
                            demoSession.saveDocument(
                              doc.issue(now: DateTime.now()),
                            );
                            showDemoSnack(
                              context,
                              'Documento emitido (versão ${v.number}). Continua NÃO assinado.',
                            );
                          },
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Emitir documento'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Emitir registra a versão final. Não aplica assinatura digital.',
                          style: t.bodySmall,
                        ),
                      ],
                    ],
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

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.version, required this.doc});

  final DocVersion version;
  final ClinicalDocRecord doc;

  @override
  Widget build(BuildContext context) {
    final DocVersion v = version;
    Widget row(String k, String val) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(k, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(val)),
        ],
      ),
    );
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          row('Versão', '${v.number} de ${doc.versions.length}'),
          row('Autor', v.author),
          row('Criado em', formatDocDateTime(v.createdAt)),
          row('Atualizado em', formatDocDateTime(v.updatedAt)),
          row(
            'Revisão',
            v.reviewedAt == null
                ? 'pendente'
                : '${v.reviewedBy} em ${formatDocDateTime(v.reviewedAt!)}',
          ),
          row(
            'Emissão',
            v.issuedAt == null ? 'não emitido' : formatDocDateTime(v.issuedAt!),
          ),
          if (v.changeNote != null) row('Alteração', v.changeNote!),
          if (doc.consultationId != null)
            row('Consulta', 'vinculada (${doc.consultationId})'),
        ],
      ),
    );
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.doc});

  final ClinicalDocRecord doc;

  @override
  Widget build(BuildContext context) {
    final SignatureRequirement r = doc.kind.signatureRequirement;
    final TextTheme t = Theme.of(context).textTheme;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SignatureChip(doc.signature),
          const SizedBox(height: AppSpacing.sm),
          Text('Impresso: ${r.printed}', style: t.bodyMedium),
          Text('Digital: ${r.digital}', style: t.bodyMedium),
          if (r.restrictions != null)
            Text('Restrições: ${r.restrictions}', style: t.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          if (!doc.signature.isSigned)
            Text(
              'Assinatura digital ICP-Brasil não configurada nesta versão. '
              'O documento não é exibido como assinado; para validade, imprima e '
              'assine conforme o requisito acima.',
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }
}
