import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/doc_templates.dart';
import '../../shared/clinical/orientation_templates.dart';
import '../../shared/clinical/rx_templates.dart';
import '../../shared/clinical/template_library.dart';
import '../../shared/wellchild/age_band.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_templates.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';
import 'documents_screens.dart';
import 'rx_template_screens.dart';

const String templatesPath = '/modelos';

/// Endereço do editor de documento já com o modelo aplicado.
String documentFromTemplatePath(
  String patientId,
  DocKind kind,
  String templateId, {
  String? consultationId,
}) =>
    '/pacientes/$patientId/documentos/novo?tipo=${kind.slug}&modelo=$templateId'
    '${consultationId == null ? '' : '&consulta=$consultationId'}';

Color _scopeColor(TemplateScope s) => switch (s) {
  TemplateScope.personal => AppColors.brand,
  TemplateScope.clinic => AppColors.teal,
  TemplateScope.example => AppColors.warning,
};

// ------------------------------------------------------------------ Lista

class DemoTemplateLibraryScreen extends StatefulWidget {
  const DemoTemplateLibraryScreen({
    super.key,
    this.patientId,
    this.consultationId,
    this.kind,
  });

  /// Com paciente, "Usar" cria o documento direto para ele.
  final String? patientId;
  final String? consultationId;
  final DocKind? kind;

  @override
  State<DemoTemplateLibraryScreen> createState() =>
      _DemoTemplateLibraryScreenState();
}

class _DemoTemplateLibraryScreenState extends State<DemoTemplateLibraryScreen> {
  final TextEditingController _q = TextEditingController();
  TemplateView _view = TemplateView.mine;
  late DocKind? _kind = widget.kind;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  DemoTemplates get _tp => demoSession.templates;

  DemoPatient? get _patient => widget.patientId == null
      ? null
      : demoSession.patientById(widget.patientId!);

  Future<void> _use(TemplateEntry e) async {
    DemoPatient? p = _patient;
    String? consultation = widget.consultationId;
    if (p == null) {
      p = await showModalBottomSheet<DemoPatient>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext c) => const _PatientSheet(),
      );
      if (p == null || !mounted) return;
      consultation = demoSession.draftConsultationFor(p.id)?.id;
    }
    if (e.kind == DocKind.receituario) {
      final RxTemplate? t = demoSession.rxTemplateVisible(e.id);
      if (t == null) return;
      useRxTemplate(context, t, p, consultationId: consultation);
      return;
    }
    context.go(
      documentFromTemplatePath(p.id, e.kind, e.id, consultationId: consultation),
    );
  }

  void _edit(TemplateEntry e) => context.go(
    e.kind == DocKind.receituario
        ? '$rxTemplatesPath/${e.id}/editar'
        : '$templatesPath/${e.id}/editar',
  );

  void _duplicate(TemplateEntry e) {
    try {
      final String id = _tp.duplicate(e.id);
      showDemoSnack(
        context,
        _tp.managesClinic
            ? 'Cópia criada nos modelos da clínica. Edite a cópia.'
            : 'Cópia criada em Meus modelos. O original não muda.',
      );
      context.go(
        e.kind == DocKind.receituario
            ? '$rxTemplatesPath/$id/editar'
            : '$templatesPath/$id/editar',
      );
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
    }
  }

  Future<void> _archive(TemplateEntry e) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Arquivar modelo?'),
        content: Text(
          '"${e.name}" sai das listas de uso. Documentos já gerados com ele '
          'não mudam. Você pode restaurar em Arquivados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      _tp.archive(e.id);
      showDemoSnack(context, 'Modelo arquivado.');
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
    }
  }

  void _restore(TemplateEntry e) {
    try {
      _tp.restore(e.id);
      showDemoSnack(context, 'Modelo restaurado.');
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
    }
  }

  Future<void> _folder(TemplateEntry e) async {
    final String? f = await showDialog<String>(
      context: context,
      builder: (BuildContext c) =>
          _FolderDialog(initial: e.org.folder, existing: _tp.folders),
    );
    if (f == null || !mounted) return;
    try {
      _tp.moveTo(e.id, f);
      showDemoSnack(
        context,
        f.trim().isEmpty ? 'Modelo sem pasta.' : 'Modelo movido para "$f".',
      );
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
    }
  }

  Future<void> _new() async {
    final DocKind? k = await showModalBottomSheet<DocKind>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) => SafeArea(
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
                  'Novo modelo de',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final DocKind k in DocKind.values)
                ListTile(
                  leading: Icon(docKindIcon(k), color: AppColors.brand),
                  title: Text(k.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(c).pop(k),
                ),
            ],
          ),
        ),
      ),
    );
    if (k == null || !mounted) return;
    context.go(
      k == DocKind.receituario
          ? '$rxTemplatesPath/novo'
          : '$templatesPath/novo?tipo=${k.slug}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoTemplates tp = _tp;
        final DemoPatient? p = _patient;
        if (!tp.views.contains(_view)) _view = tp.views.first;
        final List<TemplateEntry> list = tp.entries(
          view: _view,
          kind: _kind,
          query: _q.text,
        );
        final String back = p == null
            ? '/inicio'
            : widget.consultationId != null
            ? '/pacientes/${p.id}/consulta/${widget.consultationId}?etapa=documentos'
            : '/pacientes/${p.id}/documentos';
        final TextTheme t = Theme.of(context).textTheme;
        String? lastFolder;
        final List<Widget> rows = <Widget>[];
        for (final TemplateEntry e in list) {
          final bool grouped =
              _view == TemplateView.mine || _view == TemplateView.archived;
          if (grouped && e.org.folder != lastFolder) {
            lastFolder = e.org.folder;
            rows.add(
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      e.org.folder.isEmpty
                          ? Icons.inbox_outlined
                          : Icons.folder_outlined,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      e.org.folder.isEmpty ? 'Sem pasta' : e.org.folder,
                      style: t.labelLarge,
                    ),
                  ],
                ),
              ),
            );
          }
          rows.add(
            _EntryCard(
              entry: e,
              patient: p,
              canManage: tp.canManage(e.id),
              canUse: demoSession.canUseClinicalTools,
              managesClinic: tp.managesClinic,
              onUse: () => _use(e),
              onEdit: () => _edit(e),
              onDuplicate: () => _duplicate(e),
              onArchive: () => _archive(e),
              onRestore: () => _restore(e),
              onFolder: () => _folder(e),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go(back),
            ),
            title: Text(
              tp.managesClinic ? 'Modelos da clínica' : 'Modelos de documentos',
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'novo-modelo',
            onPressed: _new,
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
                            'Escolha um modelo para criar um documento em '
                            'rascunho para ${p.name}. Só entram dados '
                            'confirmados; o que faltar fica marcado para '
                            'conferência.',
                      ),
                    ] else
                      DemoNotice(
                        text: tp.managesClinic
                            ? 'Modelos da clínica aparecem para todos os '
                                  'profissionais do Consultório Exemplo. Eles '
                                  'podem usar e duplicar, mas só a gestão '
                                  'altera ou arquiva. Cópias pessoais não mudam '
                                  'quando você edita aqui.'
                            : 'Seus modelos só aparecem para você. Os da '
                                  'clínica são compartilhados pela gestão: '
                                  'use ou duplique para adaptar. Modelos nunca '
                                  'guardam dados de uma criança.',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final TemplateView v in tp.views)
                          ChoiceChip(
                            key: ValueKey<String>('aba-${v.name}'),
                            label: Text('${tp.viewLabel(v)} (${tp.count(v)})'),
                            selected: _view == v,
                            onSelected: (_) => setState(() => _view = v),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Todos os tipos'),
                          selected: _kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                        for (final DocKind k in DocKind.values)
                          ChoiceChip(
                            label: Text(k.label),
                            selected: _kind == k,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      container: true,
                      child: TextField(
                        key: const ValueKey<String>('busca-modelos'),
                        controller: _q,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nome, texto ou pasta',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      list.length == 1 ? '1 modelo' : '${list.length} modelos',
                      style: t.bodySmall,
                    ),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'Nenhum modelo nesta lista.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...rows,
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.patient,
    required this.canManage,
    required this.canUse,
    required this.managesClinic,
    required this.onUse,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onRestore,
    required this.onFolder,
  });

  final TemplateEntry entry;
  final DemoPatient? patient;
  final bool canManage;
  final bool canUse;
  final bool managesClinic;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onFolder;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final TemplateEntry e = entry;
    final bool archived = e.org.isArchived;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(docKindIcon(e.kind), color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(e.name, style: t.titleSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: <Widget>[
                ClinicalBadge(
                  label: e.org.scope.label,
                  color: _scopeColor(e.org.scope),
                ),
                if (e.isExample && e.org.scope != TemplateScope.example)
                  const ClinicalBadge(
                    label: 'Texto fictício',
                    color: AppColors.warning,
                  ),
                if (archived)
                  const ClinicalBadge(
                    label: 'Arquivado',
                    color: AppColors.inkMuted,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${e.kind.label}'
              '${e.version == null ? '' : ' · v${e.version}'}'
              ' · ${e.author} · ${formatDocDate(e.updatedAt)}',
              style: t.bodySmall,
            ),
            if (e.org.copiedFrom != null)
              Text('Cópia de ${e.org.copiedFrom}', style: t.bodySmall),
            if (archived && e.org.archivedBy != null)
              Text(
                'Arquivado por ${e.org.archivedBy} em '
                '${formatDocDateTime(e.org.archivedAt!)}',
                style: t.bodySmall,
              ),
            if (e.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(e.summary, style: t.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (!archived && canUse)
                  FilledButton.tonalIcon(
                    key: ValueKey<String>('usar-modelo-${e.id}'),
                    onPressed: onUse,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(
                      patient == null ? 'Usar' : 'Usar para ${patient!.name}',
                    ),
                  ),
                if (!archived && canManage)
                  OutlinedButton.icon(
                    key: ValueKey<String>('editar-modelo-${e.id}'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                if (!archived)
                  OutlinedButton.icon(
                    key: ValueKey<String>('duplicar-modelo-${e.id}'),
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(
                      canManage || managesClinic
                          ? 'Duplicar'
                          : 'Duplicar para meus modelos',
                    ),
                  ),
                if (!archived && canManage)
                  TextButton.icon(
                    key: ValueKey<String>('pasta-modelo-${e.id}'),
                    onPressed: onFolder,
                    icon: const Icon(Icons.drive_file_move_outline),
                    label: const Text('Pasta'),
                  ),
                if (!archived && canManage)
                  TextButton.icon(
                    key: ValueKey<String>('arquivar-modelo-${e.id}'),
                    onPressed: onArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arquivar'),
                  ),
                if (archived && canManage)
                  FilledButton.tonalIcon(
                    key: ValueKey<String>('restaurar-modelo-${e.id}'),
                    onPressed: onRestore,
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Restaurar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientSheet extends StatelessWidget {
  const _PatientSheet();

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
                'Criar o documento para qual paciente?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final DemoPatient p in demoSession.visiblePatients)
              ListTile(
                title: Text(p.name),
                subtitle: Text('Responsável: ${p.guardianName}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({required this.initial, required this.existing});

  final String initial;
  final List<String> existing;

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mover para pasta'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('nome-pasta'),
              controller: _c,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pasta',
                helperText: 'Deixe vazio para tirar da pasta.',
              ),
            ),
            if (widget.existing.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final String f in widget.existing)
                    ActionChip(
                      label: Text(f),
                      onPressed: () => setState(() => _c.text = f),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: const Text('Mover'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Editor

/// Contexto fictício para a prévia do modelo: mostra o que entra
/// automaticamente e o que fica para conferir (peso não registrado).
DocContext _previewContext() {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  return DocContext(
    patientName: 'Nome da Criança',
    patientBirthDate: DateTime(today.year - 2, today.month, 1),
    guardianName: 'Nome do Responsável',
    professionalName: demoSession.account.name,
    professionalRegistry: demoSession.account.registry,
    professionalSpecialty: demoSession.account.specialty,
    clinicName: demoSession.account.clinic,
    clinicAddress: demoSession.account.address,
    city: demoSession.account.city,
    date: today,
    consultationDate: today,
  );
}

class DemoTemplateEditorScreen extends StatefulWidget {
  const DemoTemplateEditorScreen({super.key, this.templateId, this.kind});

  final String? templateId;
  final DocKind? kind;

  @override
  State<DemoTemplateEditorScreen> createState() =>
      _DemoTemplateEditorScreenState();
}

class _DemoTemplateEditorScreenState extends State<DemoTemplateEditorScreen> {
  DocTemplate? _doc;
  OrientationTemplate? _orientation;
  late DocKind _kind;
  bool _missing = false;
  bool _dirty = false;
  bool _tried = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _folder = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final Map<String, TextEditingController> _c =
      <String, TextEditingController>{};
  final Map<String, String> _options = <String, String>{};
  OrientationTopic _topic = OrientationTopic.geral;
  ChildAgeBand? _band;

  DemoTemplates get _tp => demoSession.templates;

  bool get _isNew => widget.templateId == null;

  /// Campos do tipo que um modelo guarda. Atestado sem CID.
  List<DocFieldSpec> get _specs => <DocFieldSpec>[
    for (final DocFieldSpec s in DocumentTemplates.fields(_kind))
      if (!(_kind == DocKind.atestado && (s.key == 'incluirCid' || s.key == 'cid')))
        s,
  ];

  @override
  void initState() {
    super.initState();
    Map<String, String> values = const <String, String>{};
    if (widget.templateId != null) {
      _doc = _tp.docTemplate(widget.templateId!);
      _orientation = _doc == null ? _tp.orientation(widget.templateId!) : null;
      if (_doc == null && _orientation == null) {
        _missing = true;
        _kind = DocKind.atestado;
        return;
      }
      if (_doc != null) {
        _kind = _doc!.kind;
        _name.text = _doc!.name;
        values = _doc!.fields;
      } else {
        _kind = DocKind.orientacoes;
        _name.text = _orientation!.title;
        values = <String, String>{'texto': _orientation!.body};
        _topic = _orientation!.topic;
        _band = _orientation!.band;
      }
    } else {
      _kind = widget.kind ?? DocKind.atestado;
      if (_kind == DocKind.receituario) _kind = DocKind.atestado;
    }
    if (_kind == DocKind.orientacoes) {
      _c['texto'] = TextEditingController(text: values['texto'] ?? '');
    } else {
      for (final DocFieldSpec s in _specs) {
        if (s.options != null) {
          _options[s.key] = (values[s.key] ?? '').isEmpty
              ? s.options!.first
              : values[s.key]!;
        } else {
          _c[s.key] = TextEditingController(text: values[s.key] ?? '');
        }
      }
      _c[DocumentTemplates.freeTextKey] = TextEditingController(
        text: values[DocumentTemplates.freeTextKey] ?? '',
      );
    }
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _folder,
      _note,
      ..._c.values,
    ]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _folder,
      _note,
      ..._c.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String get _id => widget.templateId ?? '';

  bool get _readOnly => !_isNew && !_tp.canManage(_id);

  Map<String, String> get _fields => <String, String>{
    for (final MapEntry<String, TextEditingController> e in _c.entries)
      e.key: e.value.text,
    ..._options,
  };

  Future<void> _leave() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (mounted) context.go(templatesPath);
  }

  /// Acrescenta o marcador ao texto livre (ou ao texto da orientação).
  void _insert(String token) {
    final TextEditingController c = _kind == DocKind.orientacoes
        ? _c['texto']!
        : _c[DocumentTemplates.freeTextKey]!;
    final String sep = c.text.isEmpty || c.text.endsWith(' ') ? '' : ' ';
    c.text = '${c.text}$sep$token';
    setState(() {});
  }

  void _save() {
    setState(() => _tried = true);
    final String name = _name.text.trim();
    if (name.isEmpty) {
      showDemoSnack(context, 'Dê um nome ao modelo.');
      return;
    }
    try {
      if (_kind == DocKind.orientacoes) {
        final String body = _c['texto']!.text.trim();
        if (body.isEmpty) {
          showDemoSnack(context, 'Escreva o texto da orientação.');
          return;
        }
        if (_isNew) {
          _tp.createOrientation(
            title: name,
            body: body,
            topic: _topic,
            band: _band,
            folder: _folder.text,
          );
        } else {
          _tp.reviseOrientation(
            _id,
            title: name,
            body: body,
            topic: _topic,
            band: _band,
          );
        }
      } else {
        final Map<String, String> f = _fields;
        if (f.values.every((String v) => v.trim().isEmpty || v == 'Eletivo')) {
          showDemoSnack(context, 'Preencha ao menos um campo ou o texto.');
          return;
        }
        if (_isNew) {
          _tp.createDocTemplate(
            kind: _kind,
            name: name,
            fields: f,
            folder: _folder.text,
          );
        } else {
          _tp.reviseDocTemplate(_id, name: name, fields: f, note: _note.text);
        }
      }
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
      return;
    }
    _dirty = false;
    showDemoSnack(
      context,
      _isNew
          ? 'Modelo "$name" salvo.'
          : _kind == DocKind.orientacoes
          ? 'Modelo "$name" atualizado. Documentos já gerados não mudam.'
          : 'Modelo "$name" salvo como versão ${_doc!.current.number + 1}. '
                'Documentos já gerados não mudam.',
    );
    context.go(templatesPath);
  }

  void _duplicate() {
    try {
      final String id = _tp.duplicate(_id);
      showDemoSnack(context, 'Cópia criada. Agora você pode editar.');
      context.go('$templatesPath/$id/editar');
    } on TemplateAccessException catch (x) {
      showDemoSnack(context, x.message);
    }
  }

  String _preview() {
    final DocContext ctx = _previewContext();
    if (_kind == DocKind.orientacoes) {
      final OrientationTemplate t = OrientationTemplate(
        id: 'previa',
        title: _name.text,
        body: _c['texto']!.text,
        author: '',
        updatedAt: DateTime.now(),
      );
      return t.personalize(ctx, DateTime.now());
    }
    final DocTemplate t = DocTemplate.create(
      id: 'previa',
      kind: _kind,
      name: _name.text.isEmpty ? 'prévia' : _name.text,
      fields: _fields,
      author: '',
      now: DateTime.now(),
    );
    final DocTemplateApplication a = DocTemplates.apply(t, ctx, DateTime.now());
    return DocumentTemplates.render(_kind, a.fields, ctx, const <RxItem>[]);
  }

  Widget _field(DocFieldSpec s) {
    if (s.options != null) {
      return Semantics(
        container: true,
        child: DropdownButtonFormField<String>(
          initialValue: _options[s.key],
          decoration: InputDecoration(labelText: s.label),
          items: <DropdownMenuItem<String>>[
            for (final String o in s.options!)
              DropdownMenuItem<String>(value: o, child: Text(o)),
          ],
          onChanged: _readOnly
              ? null
              : (String? v) => setState(() {
                  _options[s.key] = v ?? s.options!.first;
                  _dirty = true;
                }),
        ),
      );
    }
    return TextField(
      key: ValueKey<String>('modelo-campo-${s.key}'),
      controller: _c[s.key],
      readOnly: _readOnly,
      minLines: s.lines,
      maxLines: s.lines == 1 ? 1 : s.lines + 4,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: s.label,
        hintText: s.hint,
        alignLabelWithHint: s.lines > 1,
        helperText: s.required
            ? 'Vazio no modelo = preencher a cada documento.'
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modelo')),
        body: DemoEmpty(
          title: 'Modelo não encontrado',
          message: 'Este modelo não existe ou não está disponível nesta conta.',
          actionLabel: 'Modelos',
          onAction: () => context.go(templatesPath),
        ),
      );
    }
    final TextTheme t = Theme.of(context).textTheme;
    final bool orientation = _kind == DocKind.orientacoes;
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
            _isNew
                ? 'Novo modelo: ${_kind.label}'
                : _readOnly
                ? 'Modelo: ${_kind.label}'
                : 'Editar modelo: ${_kind.label}',
          ),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _readOnly ? null : _leave,
          primaryLabel: _readOnly ? 'Duplicar para editar' : 'Salvar modelo',
          primaryIcon: _readOnly ? Icons.copy_rounded : Icons.save_outlined,
          onPrimary: _readOnly ? _duplicate : _save,
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
                    color: _readOnly ? AppColors.warning : AppColors.brand,
                    text: _readOnly
                        ? 'Modelo ${_tp.library.orgOf(_id)?.scope.label.toLowerCase() ?? ''}: '
                              'você pode usar, mas não alterar. Duplique para '
                              'ter uma cópia sua.'
                        : _isNew
                        ? 'Use marcadores como {{crianca}} para dados que '
                              'entram sozinhos e [preencher: ...] para o que '
                              'deve ser escrito a cada documento. O modelo não '
                              'guarda dados de nenhuma criança.'
                        : orientation
                        ? 'Salvar atualiza o texto do modelo. Documentos já '
                              'gerados guardam cópia própria e não mudam.'
                        : 'Salvar cria a versão ${_doc!.current.number + 1}. '
                              'Documentos já gerados guardam cópia própria e '
                              'não mudam.',
                  ),
                  if (_kind == DocKind.atestado) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const DemoNotice(
                      icon: Icons.privacy_tip_outlined,
                      color: AppColors.warning,
                      text:
                          'Modelos de atestado não guardam CID nem '
                          'diagnóstico. A inclusão do CID é decidida no '
                          'documento, com autorização do responsável.',
                    ),
                  ],
                  const DemoSectionTitle('Identificação'),
                  TextField(
                    key: const ValueKey<String>('modelo-nome'),
                    controller: _name,
                    readOnly: _readOnly,
                    decoration: InputDecoration(
                      labelText: 'Nome do modelo *',
                      errorText: _tried && _name.text.trim().isEmpty
                          ? 'Dê um nome ao modelo'
                          : null,
                    ),
                  ),
                  if (_isNew) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const ValueKey<String>('modelo-pasta'),
                      controller: _folder,
                      decoration: InputDecoration(
                        labelText: 'Pasta (opcional)',
                        helperText: _tp.folders.isEmpty
                            ? null
                            : 'Pastas em uso: ${_tp.folders.join(', ')}',
                      ),
                    ),
                  ],
                  if (orientation) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text('Tema', style: t.labelLarge),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final OrientationTopic o in OrientationTopic.values)
                          ChoiceChip(
                            label: Text(o.label),
                            selected: _topic == o,
                            onSelected: _readOnly
                                ? null
                                : (_) => setState(() {
                                    _topic = o;
                                    _dirty = true;
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Faixa etária', style: t.labelLarge),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Qualquer idade'),
                          selected: _band == null,
                          onSelected: _readOnly
                              ? null
                              : (_) => setState(() {
                                  _band = null;
                                  _dirty = true;
                                }),
                        ),
                        for (final ChildAgeBand b in ChildAgeBand.values)
                          ChoiceChip(
                            label: Text(b.label),
                            selected: _band == b,
                            onSelected: _readOnly
                                ? null
                                : (_) => setState(() {
                                    _band = b;
                                    _dirty = true;
                                  }),
                          ),
                      ],
                    ),
                    const DemoSectionTitle('Texto'),
                    TextField(
                      key: const ValueKey<String>('modelo-campo-texto'),
                      controller: _c['texto'],
                      readOnly: _readOnly,
                      minLines: 8,
                      maxLines: 16,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Orientações *',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ] else ...<Widget>[
                    const DemoSectionTitle('Campos'),
                    for (final DocFieldSpec s in _specs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _field(s),
                      ),
                    const DemoSectionTitle('Texto do documento (opcional)'),
                    Text(
                      'Se preenchido, este texto substitui o texto gerado '
                      'pelos campos. O profissional ainda pode editá-lo em '
                      'cada documento.',
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      key: const ValueKey<String>('modelo-campo-textoEditado'),
                      controller: _c[DocumentTemplates.freeTextKey],
                      readOnly: _readOnly,
                      minLines: 5,
                      maxLines: 14,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Texto do documento',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  if (!_readOnly) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Inserir marcador no texto', style: t.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final DocMarker m in kDocMarkers)
                          ActionChip(
                            label: Text(m.label),
                            tooltip: m.token,
                            onPressed: () => _insert(m.token),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('campo a preencher'),
                          onPressed: () => _insert('[preencher: descreva]'),
                        ),
                      ],
                    ),
                  ],
                  if (!_isNew && _doc != null) ...<Widget>[
                    if (!_readOnly) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const ValueKey<String>('modelo-nota'),
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'O que mudou nesta versão (opcional)',
                        ),
                      ),
                    ],
                    const DemoSectionTitle('Versões'),
                    for (final DocTemplateVersion v in _doc!.versions.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'v${v.number} · ${v.name} · ${v.savedBy} · '
                          '${formatDocDateTime(v.savedAt)}'
                          '${v.note == null ? '' : ' · ${v.note}'}',
                          style: t.bodySmall,
                        ),
                      ),
                  ],
                  const DemoSectionTitle('Prévia com dados de exemplo'),
                  Text(
                    'Criança fictícia sem peso registrado, para mostrar como '
                    'os campos a conferir aparecem.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DocPaper(text: _preview()),
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

/// Usado pelo editor de documento: escolhe um modelo aplicável ao tipo.
Future<DocTemplate?> pickDocTemplate(
  BuildContext context,
  DocKind kind,
) => showModalBottomSheet<DocTemplate>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (BuildContext c) => _DocTemplatePickerSheet(kind: kind),
);

class _DocTemplatePickerSheet extends StatelessWidget {
  const _DocTemplatePickerSheet({required this.kind});

  final DocKind kind;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<DocTemplate> list = demoSession.templates.usableFor(kind);
    return SafeArea(
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
            Text('Modelos de ${kind.label.toLowerCase()}', style: t.titleMedium),
            Text(
              'Só entram dados confirmados do cadastro, do profissional e da '
              'consulta. O resto fica marcado para conferência.',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Nenhum modelo deste tipo. Crie em Modelos de documentos.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final DocTemplate m in list)
              ListTile(
                key: ValueKey<String>('aplicar-modelo-${m.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(docKindIcon(kind), color: AppColors.brand),
                title: Text(m.name),
                subtitle: Text(
                  '${demoSession.templateLibrary.orgOf(m.id)?.scope.label ?? ''}'
                  ' · v${m.current.number}\n${m.summary}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(m),
              ),
            const Divider(),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('$templatesPath?tipo=${kind.slug}');
              },
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Gerenciar modelos'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Salva os campos do documento como modelo, sem dados da criança.
Future<void> saveDocAsTemplate(
  BuildContext context, {
  required DocKind kind,
  required Map<String, String> fields,
  required DocContext docContext,
}) async {
  final (String, String)? meta = await showDialog<(String, String)>(
    context: context,
    builder: (BuildContext c) =>
        _SaveTemplateDialog(kind: kind, folders: demoSession.templates.folders),
  );
  if (meta == null || meta.$1.isEmpty || !context.mounted) return;
  final DocTemplate t = demoSession.templates.createDocTemplate(
    kind: kind,
    name: meta.$1,
    fields: DocTemplates.generalize(kind, fields, docContext),
    folder: meta.$2,
    note: 'Criado a partir de um documento; dados da criança removidos',
  );
  if (!context.mounted) return;
  showDemoSnack(
    context,
    'Modelo "${t.name}" salvo. Nome, datas e dados da criança viraram '
    'marcadores${kind == DocKind.atestado ? '; CID não foi copiado' : ''}.',
  );
}

class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({required this.kind, required this.folders});

  final DocKind kind;
  final List<String> folders;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _folder = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop((_name.text.trim(), _folder.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Salvar ${widget.kind.label.toLowerCase()} como modelo'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Nome da criança, do responsável, datas e peso viram '
              'marcadores. Resumo clínico, exames e tratamentos desta criança '
              'não vão para o modelo'
              '${widget.kind == DocKind.atestado ? ', nem o CID' : ''}.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('salvar-modelo-nome'),
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
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey<String>('salvar-modelo-pasta'),
              controller: _folder,
              decoration: InputDecoration(
                labelText: 'Pasta (opcional)',
                helperText: widget.folders.isEmpty
                    ? null
                    : 'Pastas em uso: ${widget.folders.join(', ')}',
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