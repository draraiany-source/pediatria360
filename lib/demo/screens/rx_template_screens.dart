import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../../shared/clinical/rx_templates.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'documents_screens.dart';

const String rxTemplatesPath = '/modelos-receita';

/// Gera uma receita nova, em rascunho, a partir do modelo e com os dados
/// atuais do paciente, e abre o editor.
void useRxTemplate(
  BuildContext context,
  RxTemplate template,
  DemoPatient patient, {
  String? consultationId,
}) {
  final DateTime now = DateTime.now();
  final DocContext ctx = demoDocContext(
    patient,
    consultationId: consultationId,
  );
  final RxTemplateDraft d = RxTemplates.instantiate(
    template,
    context: ctx,
    references: demoSession.doseReferences,
    now: now,
  );
  final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
    id: demoSession.newDocumentId(),
    kind: DocKind.receituario,
    patientId: patient.id,
    consultationId: consultationId,
    author: demoSession.currentAuthor,
    context: ctx,
    now: now,
    fields: <String, String>{'orientacoes': d.orientations},
    items: d.items,
  );
  demoSession.saveDocument(doc);
  showDemoSnack(
    context,
    'Receita em rascunho gerada de "${template.name}" para ${patient.name}. '
    'Confira cada item antes de emitir.',
  );
  context.go('/pacientes/${patient.id}/documentos/${doc.id}/editar');
}

/// Escolha rápida de modelo (durante a consulta ou no receituário).
Future<RxTemplate?> pickRxTemplate(BuildContext context, {String? subtitle}) =>
    showModalBottomSheet<RxTemplate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext c) => _RxTemplatePickerSheet(subtitle: subtitle),
    );

/// Salva a receita como modelo. A dose calculada desta criança não vai
/// para o modelo.
Future<void> saveRxAsTemplate(
  BuildContext context, {
  required List<RxItem> items,
  required String orientations,
  required DocContext docContext,
}) async {
  if (items.isEmpty) {
    showDemoSnack(
      context,
      'Inclua ao menos um medicamento antes de salvar como modelo.',
    );
    return;
  }
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext c) => const _RxTemplateNameDialog(),
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  final RxTemplate t = RxTemplates.fromPrescription(
    id: demoSession.newRxTemplateId(),
    name: name,
    items: items,
    orientations: orientations,
    author: demoSession.currentAuthor,
    now: DateTime.now(),
    context: docContext,
    references: demoSession.doseReferences,
  );
  demoSession.saveRxTemplate(t);
  showDemoSnack(
    context,
    'Modelo "$name" salvo em Meus modelos de receita. As doses desta '
    'criança não foram copiadas.',
  );
}

String _itemsLabel(int n) => n == 1 ? '1 item' : '$n itens';

// ------------------------------------------------------------------ Lista

class DemoRxTemplatesScreen extends StatefulWidget {
  const DemoRxTemplatesScreen({super.key, this.patientId, this.consultationId});

  /// Com paciente, "Usar" gera a receita direto para ele.
  final String? patientId;
  final String? consultationId;

  @override
  State<DemoRxTemplatesScreen> createState() => _DemoRxTemplatesScreenState();
}

class _DemoRxTemplatesScreenState extends State<DemoRxTemplatesScreen> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _use(RxTemplate t) async {
    final DemoPatient? fixed = widget.patientId == null
        ? null
        : demoSession.patientById(widget.patientId!);
    if (fixed != null) {
      useRxTemplate(context, t, fixed, consultationId: widget.consultationId);
      return;
    }
    final DemoPatient? p = await showModalBottomSheet<DemoPatient>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) => const _PatientPickerSheet(),
    );
    if (p == null || !mounted) return;
    useRxTemplate(
      context,
      t,
      p,
      consultationId: demoSession.draftConsultationFor(p.id)?.id,
    );
  }

  void _duplicate(RxTemplate t) {
    final RxTemplate copy = t.duplicate(
      id: demoSession.newRxTemplateId(),
      author: demoSession.currentAuthor,
      now: DateTime.now(),
    );
    demoSession.saveRxTemplate(copy);
    showDemoSnack(context, 'Modelo duplicado: "${copy.name}". Edite a cópia.');
    context.go('$rxTemplatesPath/${copy.id}/editar');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = widget.patientId == null
            ? null
            : demoSession.patientById(widget.patientId!);
        final List<RxTemplate> list = demoSession.searchRxTemplates(_q.text);
        final String? back = p == null
            ? null
            : widget.consultationId != null
            ? '/pacientes/${p.id}/consulta/${widget.consultationId}?etapa=documentos'
            : '/pacientes/${p.id}/documentos';
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: back == null
                ? null
                : IconButton(
                    tooltip: 'Voltar',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go(back),
                  ),
            title: const Text('Meus modelos de receita'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('$rxTemplatesPath/novo'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo modelo'),
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
                    if (p != null) ...<Widget>[
                      DemoPatientStrip(patient: p),
                      const SizedBox(height: AppSpacing.sm),
                      DemoNotice(
                        text:
                            'Escolha um modelo para gerar uma receita nova, em '
                            'rascunho, para ${p.name}.',
                      ),
                    ] else
                      const DemoNotice(
                        text:
                            'Modelos guardam o esquema da receita, nunca a dose de '
                            'uma criança: doses pelo peso são refeitas com o peso '
                            'de cada paciente ao usar o modelo.',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      child: TextField(
                        key: const ValueKey<String>('busca-modelo'),
                        controller: _q,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Buscar modelo (nome ou medicamento)',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _q.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(_q.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${list.length} de ${demoSession.rxTemplates.length} modelos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'Nenhum modelo encontrado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final RxTemplate t in list)
                      _TemplateCard(
                        template: t,
                        useLabel: p == null ? 'Usar' : 'Usar para ${p.name}',
                        onUse: () => _use(t),
                        onEdit: () =>
                            context.go('$rxTemplatesPath/${t.id}/editar'),
                        onDuplicate: () => _duplicate(t),
                      ),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.useLabel,
    required this.onUse,
    required this.onEdit,
    required this.onDuplicate,
  });

  final RxTemplate template;
  final String useLabel;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final RxTemplate m = template;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.bookmark_outline_rounded,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(m.name, style: t.titleSmall)),
                if (m.isExample)
                  const ClinicalBadge(
                    label: 'Exemplo fictício',
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'v${m.current.number} · ${_itemsLabel(m.items.length)} · '
              'atualizado em ${formatDocDate(m.updatedAt)}',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final RxTemplateItem it in m.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${it.drug}: ${it.doseSummary(demoSession.doseReferences)}',
                  style: t.bodyMedium,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: ValueKey<String>('usar-${m.id}'),
                  onPressed: onUse,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(useLabel),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('editar-${m.id}'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('duplicar-${m.id}'),
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Duplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientPickerSheet extends StatelessWidget {
  const _PatientPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Gerar a receita para qual paciente?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final DemoPatient p in demoSession.patients)
              ListTile(
                title: Text(p.name),
                subtitle: Text(
                  p.weightKg == null
                      ? 'Sem peso registrado'
                      : 'Peso atual: ${formatDoseNumber(p.weightKg!)} kg em '
                            '${formatDocDate(p.weighedAt!)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _RxTemplatePickerSheet extends StatefulWidget {
  const _RxTemplatePickerSheet({this.subtitle});

  final String? subtitle;

  @override
  State<_RxTemplatePickerSheet> createState() => _RxTemplatePickerSheetState();
}

class _RxTemplatePickerSheetState extends State<_RxTemplatePickerSheet> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<RxTemplate> list = demoSession.searchRxTemplates(_q.text);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: <Widget>[
              Text('Escolher modelo de receita', style: t.titleMedium),
              if (widget.subtitle != null)
                Text(widget.subtitle!, style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                child: TextField(
                  key: const ValueKey<String>('busca-modelo-sheet'),
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Buscar modelo',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Nenhum modelo encontrado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final RxTemplate m in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.bookmark_outline_rounded,
                    color: AppColors.brand,
                  ),
                  title: Text(m.name),
                  subtitle: Text(
                    'v${m.current.number} · ${_itemsLabel(m.items.length)}: '
                    '${m.items.map((RxTemplateItem i) => i.drug).join(', ')}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(m),
                ),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(rxTemplatesPath);
                },
                icon: const Icon(Icons.bookmarks_outlined),
                label: const Text('Gerenciar meus modelos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RxTemplateNameDialog extends StatefulWidget {
  const _RxTemplateNameDialog();

  @override
  State<_RxTemplateNameDialog> createState() => _RxTemplateNameDialogState();
}

class _RxTemplateNameDialogState extends State<_RxTemplateNameDialog> {
  final TextEditingController _name = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salvar receita como modelo'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'O modelo guarda medicamento, apresentação, via, intervalo, '
              'duração, quantidade e orientações. Doses calculadas pelo peso '
              'viram mg/kg e serão refeitas para cada paciente; doses escritas '
              'à mão ficam "a definir na consulta". O nome da criança vira '
              'marcador.',
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              container: true,
              child: TextField(
                key: const ValueKey<String>('nome-modelo-receita'),
                controller: _name,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Nome do modelo *',
                  errorText: _tried && _name.text.trim().isEmpty
                      ? 'Dê um nome ao modelo'
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar modelo')),
      ],
    );
  }
}

// ------------------------------------------------------------------ Editor

class DemoRxTemplateEditorScreen extends StatefulWidget {
  const DemoRxTemplateEditorScreen({super.key, this.templateId});

  final String? templateId;

  @override
  State<DemoRxTemplateEditorScreen> createState() =>
      _DemoRxTemplateEditorScreenState();
}

class _DemoRxTemplateEditorScreenState
    extends State<DemoRxTemplateEditorScreen> {
  RxTemplate? _template;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _orientations = TextEditingController();
  final TextEditingController _note = TextEditingController();
  List<RxTemplateItem> _items = <RxTemplateItem>[];
  bool _dirty = false;
  bool _tried = false;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    if (widget.templateId != null) {
      _template = demoSession.rxTemplateById(widget.templateId!);
      _missing = _template == null;
    }
    final RxTemplate? t = _template;
    if (t != null) {
      _name.text = t.name;
      _orientations.text = t.orientations;
      _items = List<RxTemplateItem>.of(t.items);
    }
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _orientations,
      _note,
    ]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _orientations.dispose();
    _note.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  RxTemplate get _draft => RxTemplate.create(
    id: _template?.id ?? '-',
    name: _name.text,
    items: _items,
    orientations: _orientations.text,
    author: demoSession.currentAuthor,
    now: DateTime.now(),
  );

  Future<bool> _canLeave() async => !_dirty || await confirmDiscard(context);

  Future<void> _leave() async {
    if (await _canLeave() && mounted) context.go(rxTemplatesPath);
  }

  Future<void> _editItem({int? index}) async {
    final RxTemplateItem? item = await showDialog<RxTemplateItem>(
      context: context,
      builder: (BuildContext c) =>
          _TemplateItemDialog(initial: index == null ? null : _items[index]),
    );
    if (item == null || !mounted) return;
    setState(() {
      _items = <RxTemplateItem>[
        for (int i = 0; i < _items.length; i++) i == index ? item : _items[i],
        if (index == null) item,
      ];
      _dirty = true;
    });
  }

  void _save() {
    final List<String> problems = _draft.problems(demoSession.doseReferences);
    if (problems.isNotEmpty) {
      setState(() => _tried = true);
      showDemoSnack(context, 'Corrija antes de salvar: ${problems.first}.');
      return;
    }
    final DateTime now = DateTime.now();
    final RxTemplate saved = _template == null
        ? RxTemplate.create(
            id: demoSession.newRxTemplateId(),
            name: _name.text,
            items: _items,
            orientations: _orientations.text,
            author: demoSession.currentAuthor,
            now: now,
          )
        : _template!.edit(
            name: _name.text,
            items: _items,
            orientations: _orientations.text,
            author: demoSession.currentAuthor,
            now: now,
            note: _note.text,
          );
    demoSession.saveRxTemplate(saved);
    _dirty = false;
    showDemoSnack(
      context,
      _template == null
          ? 'Modelo "${saved.name}" criado.'
          : 'Modelo salvo na versão ${saved.current.number}. Receitas já '
                'emitidas não mudam.',
    );
    context.go(rxTemplatesPath);
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modelo de receita')),
        body: DemoEmpty(
          title: 'Modelo não encontrado',
          message: 'Este modelo não existe nesta demonstração.',
          actionLabel: 'Meus modelos',
          onAction: () => context.go(rxTemplatesPath),
        ),
      );
    }
    final TextTheme t = Theme.of(context).textTheme;
    final List<String> problems = _draft.problems(demoSession.doseReferences);
    final RxTemplate? m = _template;
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
            m == null ? 'Novo modelo de receita' : 'Editar modelo de receita',
          ),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _leave,
          primaryLabel: 'Salvar modelo',
          primaryIcon: Icons.bookmark_added_outlined,
          onPrimary: _save,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DemoNotice(
                    text: m == null
                        ? 'O modelo guarda o esquema da receita. Doses pelo '
                              'peso ficam em mg/kg e são refeitas com o peso de '
                              'cada paciente; nenhuma dose de outra criança é '
                              'copiada.'
                        : 'Salvar cria a versão ${m.current.number + 1}. '
                              'Receitas já geradas ou emitidas com este modelo '
                              'não mudam.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    container: true,
                    child: TextField(
                      key: const ValueKey<String>('modelo-nome'),
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'Nome do modelo *',
                        errorText: _tried && _name.text.trim().isEmpty
                            ? 'Dê um nome ao modelo'
                            : null,
                      ),
                    ),
                  ),
                  const DemoSectionTitle('Itens'),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('Nenhum item ainda.'),
                    ),
                  for (int i = 0; i < _items.length; i++)
                    _TemplateItemCard(
                      index: i,
                      item: _items[i],
                      onEdit: () => _editItem(index: i),
                      onRemove: () => setState(() {
                        _items = List<RxTemplateItem>.of(_items)..removeAt(i);
                        _dirty = true;
                      }),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _editItem(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar item'),
                    ),
                  ),
                  const DemoSectionTitle('Orientações'),
                  Semantics(
                    container: true,
                    child: TextField(
                      key: const ValueKey<String>('modelo-orientacoes'),
                      controller: _orientations,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Orientações gerais',
                        alignLabelWithHint: true,
                        helperText:
                            '{{crianca}} e {{responsavel}} viram os nomes do '
                            'paciente ao usar o modelo.',
                      ),
                    ),
                  ),
                  if (m != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      child: TextField(
                        key: const ValueKey<String>('modelo-nota'),
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'O que mudou nesta versão (opcional)',
                        ),
                      ),
                    ),
                  ],
                  if (_tried && problems.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    DemoNotice(
                      icon: Icons.rule_rounded,
                      color: AppColors.warning,
                      text: 'Pendências: ${problems.join('; ')}.',
                    ),
                  ],
                  if (m != null) ...<Widget>[
                    const DemoSectionTitle('Histórico de versões'),
                    for (final RxTemplateVersion v in m.versions.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          'v${v.number} · ${formatDocDateTime(v.savedAt)} · '
                          '${v.savedBy}${v.note == null ? '' : ' · ${v.note}'}',
                          style: t.bodySmall,
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

class _TemplateItemCard extends StatelessWidget {
  const _TemplateItemCard({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final RxTemplateItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final RxTemplateItem it = item;
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
                  Text(
                    '${index + 1}. ${it.drug} - ${it.presentation}'
                    '${it.concentration.isEmpty || it.presentation.contains(it.concentration) ? '' : ' (${it.concentration})'}',
                    style: t.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  ClinicalBadge(
                    label: it.mode.label,
                    color: it.mode == RxDoseMode.weight
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(height: 4),
                  Text(it.doseSummary(demoSession.doseReferences)),
                  Text(
                    <String>[
                      it.route,
                      it.frequency,
                      if (it.duration.isNotEmpty) 'por ${it.duration}',
                      if (it.quantity.isNotEmpty) 'quantidade: ${it.quantity}',
                    ].where((String s) => s.trim().isNotEmpty).join(' · '),
                    style: t.bodySmall,
                  ),
                  if (it.notes.isNotEmpty) Text(it.notes, style: t.bodySmall),
                ],
              ),
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
      ),
    );
  }
}

class _TemplateItemDialog extends StatefulWidget {
  const _TemplateItemDialog({this.initial});

  final RxTemplateItem? initial;

  @override
  State<_TemplateItemDialog> createState() => _TemplateItemDialogState();
}

class _TemplateItemDialogState extends State<_TemplateItemDialog> {
  late RxDoseMode _mode = widget.initial?.mode ?? RxDoseMode.weight;
  late String? _refId = widget.initial?.referenceId;
  late String? _presId = widget.initial?.presentationId;
  late final Map<String, TextEditingController>
  _c = <String, TextEditingController>{
    'drug': TextEditingController(text: widget.initial?.drug),
    'presentation': TextEditingController(text: widget.initial?.presentation),
    'concentration': TextEditingController(text: widget.initial?.concentration),
    'mgkg': TextEditingController(
      text: widget.initial?.mgPerKg == null
          ? ''
          : formatDoseNumber(widget.initial!.mgPerKg!),
    ),
    'dose': TextEditingController(text: widget.initial?.fixedDose),
    'volume': TextEditingController(text: widget.initial?.fixedVolume),
    'route': TextEditingController(text: widget.initial?.route ?? 'via oral'),
    'frequency': TextEditingController(text: widget.initial?.frequency),
    'duration': TextEditingController(text: widget.initial?.duration),
    'quantity': TextEditingController(text: widget.initial?.quantity),
    'notes': TextEditingController(text: widget.initial?.notes),
  };
  bool _tried = false;

  List<DoseReference> get _refs => demoSession.doseReferences
      .where((DoseReference r) => r.isUsable)
      .toList();

  DoseReference? get _ref {
    for (final DoseReference r in _refs) {
      if (r.id == _refId) return r;
    }
    return null;
  }

  DrugPresentation? get _pres {
    for (final DrugPresentation p
        in _ref?.presentations ?? const <DrugPresentation>[]) {
      if (p.id == _presId) return p;
    }
    return null;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _c[k]!.text.trim();

  RxTemplateItem get _item {
    final DoseReference? ref = _ref;
    final DrugPresentation? pres = _pres;
    final bool w = _mode == RxDoseMode.weight;
    return RxTemplateItem(
      drug: w ? ref?.drugName ?? '' : _v('drug'),
      presentation: w ? pres?.label ?? '' : _v('presentation'),
      concentration: w ? pres?.concentrationLabel ?? '' : _v('concentration'),
      mode: _mode,
      referenceId: w ? ref?.id : null,
      presentationId: w ? pres?.id : null,
      mgPerKg: w ? double.tryParse(_v('mgkg').replaceAll(',', '.')) : null,
      fixedDose: _mode == RxDoseMode.fixed ? _v('dose') : '',
      fixedVolume: _mode == RxDoseMode.fixed ? _v('volume') : '',
      route: _v('route'),
      frequency: w ? ref?.intervalLabel ?? '' : _v('frequency'),
      duration: _v('duration'),
      quantity: _v('quantity'),
      notes: _v('notes'),
    );
  }

  Widget _field(String k, String label, {String? helper, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Semantics(
          container: true,
          child: TextField(
            key: ValueKey<String>('item-$k'),
            controller: _c[k],
            minLines: lines,
            maxLines: lines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: label, helperText: helper),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DoseReference? ref = _ref;
    final List<String> problems = _item.problems(demoSession.doseReferences);
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Novo item do modelo' : 'Editar item',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Como a dose é definida', style: t.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                container: true,
                child: SegmentedButton<RxDoseMode>(
                  key: const ValueKey<String>('modo-dose'),
                  showSelectedIcon: false,
                  segments: <ButtonSegment<RxDoseMode>>[
                    for (final RxDoseMode m in RxDoseMode.values)
                      ButtonSegment<RxDoseMode>(
                        value: m,
                        label: Text(switch (m) {
                          RxDoseMode.weight => 'Pelo peso',
                          RxDoseMode.fixed => 'Fixa',
                          RxDoseMode.atConsultation => 'Na consulta',
                        }),
                      ),
                  ],
                  selected: <RxDoseMode>{_mode},
                  onSelectionChanged: (Set<RxDoseMode> s) =>
                      setState(() => _mode = s.first),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(switch (_mode) {
                RxDoseMode.weight =>
                  'O modelo guarda só o mg/kg; a dose é refeita com o peso de '
                      'cada paciente e a conta aparece na receita.',
                RxDoseMode.fixed =>
                  'Use só para doses que não dependem do peso.',
                RxDoseMode.atConsultation =>
                  'A dose fica em branco e é escrita e conferida na consulta.',
              }, style: t.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (_mode == RxDoseMode.weight) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    container: true,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey<String>('item-ref'),
                      initialValue: ref?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Referência de dose *',
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final DoseReference r in _refs)
                          DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(
                              '${r.drugName} (${r.basis.label})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (String? v) => setState(() {
                        _refId = v;
                        _presId = null;
                        final DoseReference? r = _ref;
                        if (r != null) {
                          _c['mgkg']!.text = formatDoseNumber(r.mgPerKg);
                        }
                      }),
                    ),
                  ),
                ),
                if (ref != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Semantics(
                      container: true,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>('item-pres-${ref.id}'),
                        initialValue: _pres?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Apresentação *',
                        ),
                        items: <DropdownMenuItem<String>>[
                          for (final DrugPresentation p in ref.presentations)
                            DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                p.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (String? v) => setState(() => _presId = v),
                      ),
                    ),
                  ),
                if (ref != null) ...<Widget>[
                  _field(
                    'mgkg',
                    'Dose (${ref.basis.label}) *',
                    helper: ref.minMgPerKg == null || ref.maxMgPerKg == null
                        ? null
                        : 'Faixa configurada: ${formatDoseNumber(ref.minMgPerKg!)} '
                              'a ${formatDoseNumber(ref.maxMgPerKg!)} ${ref.basis.label}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Frequência da referência: ${ref.intervalLabel}',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ] else ...<Widget>[
                _field('drug', 'Medicamento *'),
                _field('presentation', 'Apresentação *'),
                _field('concentration', 'Concentração'),
                if (_mode == RxDoseMode.fixed) ...<Widget>[
                  _field('dose', 'Dose fixa *'),
                  _field('volume', 'Volume por dose'),
                ],
                _field('frequency', 'Frequência *'),
              ],
              _field('route', 'Via'),
              _field('duration', 'Duração *'),
              _field('quantity', 'Quantidade'),
              _field('notes', 'Observações do item', lines: 2),
              if (_tried && problems.isNotEmpty)
                DemoNotice(
                  icon: Icons.rule_rounded,
                  color: AppColors.warning,
                  text: 'Falta: ${problems.join(', ')}.',
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
            if (problems.isNotEmpty) {
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
