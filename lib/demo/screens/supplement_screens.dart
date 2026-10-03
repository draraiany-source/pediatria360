import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/lab_results.dart';
import '../../shared/clinical/supplement_library.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';

const String _draftWarning =
    'Fichas em elaboração. Nenhuma contém dose ou conduta: o conteúdo depende '
    'de validação clínica e da confirmação da licença do material de '
    'referência. Não use como base de prescrição.';

class DemoSupplementsScreen extends StatefulWidget {
  const DemoSupplementsScreen({super.key});

  @override
  State<DemoSupplementsScreen> createState() => _DemoSupplementsScreenState();
}

class _DemoSupplementsScreenState extends State<DemoSupplementsScreen> {
  String _q = '';
  String? _group;
  SheetStatus? _status;

  /// Busca por título, conteúdo ou nome de exame relacionado.
  bool _matches(SupplementSheet s, String q) {
    if (q.isEmpty) return true;
    if (s.searchText.contains(q)) return true;
    return kLabTestSuggestions.any(
      (LabTestSuggestion t) =>
          t.topicIds.contains(s.id) && t.name.toLowerCase().contains(q),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Suplementação'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: demoSession,
        builder: (BuildContext context, _) {
          final String q = _q.trim().toLowerCase();
          final List<SupplementSheet> list = demoSession.supplementSheets
              .where(
                (SupplementSheet s) =>
                    _matches(s, q) &&
                    (_group == null || s.group == _group) &&
                    (_status == null || s.status == _status),
              )
              .toList();
          final int validated = demoSession.supplementSheets
              .where((SupplementSheet s) => !s.isDraft)
              .length;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoNotice(
                      icon: Icons.edit_note_rounded,
                      color: AppColors.warning,
                      text: _draftWarning,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${demoSession.supplementSheets.length} temas · $validated validados · '
                      '${demoSession.supplementSheets.length - validated} em rascunho',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      container: true,
                      child: TextField(
                        onChanged: (String v) => setState(() => _q = v),
                        decoration: const InputDecoration(
                          hintText:
                              'Buscar tema ou exame (ex.: ferro, ferritina)',
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
                          label: const Text('Todos os grupos'),
                          selected: _group == null,
                          onSelected: (_) => setState(() => _group = null),
                        ),
                        for (final String g in kSheetGroups)
                          ChoiceChip(
                            label: Text(g),
                            selected: _group == g,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Qualquer situação'),
                          selected: _status == null,
                          onSelected: (_) => setState(() => _status = null),
                        ),
                        ChoiceChip(
                          label: const Text('Rascunho'),
                          selected: _status == SheetStatus.draft,
                          onSelected: (_) =>
                              setState(() => _status = SheetStatus.draft),
                        ),
                        ChoiceChip(
                          label: const Text('Validado'),
                          selected: _status == SheetStatus.validated,
                          onSelected: (_) =>
                              setState(() => _status = SheetStatus.validated),
                        ),
                      ],
                    ),
                    for (final String group in kSheetGroups) ...<Widget>[
                      if (list.any((SupplementSheet s) => s.group == group))
                        DemoSectionTitle(group),
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints box) {
                          final int cols = box.maxWidth >= 640 ? 2 : 1;
                          final double w =
                              (box.maxWidth - AppSpacing.sm * (cols - 1)) /
                              cols;
                          return Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              for (final SupplementSheet s in list.where(
                                (SupplementSheet s) => s.group == group,
                              ))
                                SizedBox(
                                  width: w,
                                  child: _SheetTile(sheet: s),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'Nenhum tema encontrado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.sheet});

  final SupplementSheet sheet;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/suplementacao/${sheet.id}'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sheet.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${sheet.filledFields}/${kSheetFields.length} blocos · '
                  'fonte: ${sheet.source.trim().isEmpty ? 'não informada' : 'informada'} · '
                  'revisão: ${sheet.reviewedAt == null ? '-' : formatDocDate(sheet.reviewedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ClinicalBadge(
            label: sheet.isDraft ? 'Rascunho' : 'Validado',
            color: sheet.isDraft ? AppColors.warning : AppColors.success,
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class DemoSupplementDetailScreen extends StatelessWidget {
  const DemoSupplementDetailScreen({required this.sheetId, super.key});

  final String sheetId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final SupplementSheet? s = demoSession.sheetById(sheetId);
        if (s == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Suplementação')),
            body: DemoEmpty(
              title: 'Tema não encontrado',
              message: 'Volte para a lista de temas.',
              actionLabel: 'Suplementação',
              onAction: () => context.go('/suplementacao'),
            ),
          );
        }
        final TextTheme t = Theme.of(context).textTheme;
        Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: t.labelLarge?.copyWith(color: AppColors.navy)),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Não preenchido' : value,
                style: value.isEmpty
                    ? t.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        fontStyle: FontStyle.italic,
                      )
                    : t.bodyMedium,
              ),
            ],
          ),
        );
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/suplementacao'),
            ),
            title: Text(s.title),
          ),
          bottomNavigationBar: DemoFlowActions(
            onBack: () => context.go('/suplementacao'),
            primaryLabel: 'Editar ficha',
            primaryIcon: Icons.edit_outlined,
            onPrimary: () => context.go('/suplementacao/${s.id}/editar'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (s.isDraft)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBD6),
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Text(
                          'RASCUNHO - não usar como conduta. $_draftWarning',
                          style: t.bodyMedium?.copyWith(
                            color: const Color(0xFF6B2D00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const DemoNotice(
                        icon: Icons.verified_outlined,
                        color: AppColors.success,
                        text:
                            'Ficha validada nesta demonstração (conteúdo digitado pelo avaliador).',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final SheetField f in kSheetFields)
                            field(f.label, s.valueOf(f.key)),
                          const Divider(),
                          const SizedBox(height: AppSpacing.sm),
                          field('Fonte', s.source.trim()),
                          field('Revisado por', s.reviewedBy.trim()),
                          field(
                            'Data da última revisão',
                            s.reviewedAt == null
                                ? ''
                                : formatDocDate(s.reviewedAt!),
                          ),
                          field('Situação', s.status.label),
                          field(
                            'Exames que costumam se relacionar (sugestão de vínculo, sem valores)',
                            kLabTestSuggestions
                                .where(
                                  (LabTestSuggestion t) =>
                                      t.topicIds.contains(s.id),
                                )
                                .map((LabTestSuggestion t) => t.name)
                                .join(', '),
                          ),
                        ],
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

class DemoSupplementEditScreen extends StatefulWidget {
  const DemoSupplementEditScreen({required this.sheetId, super.key});

  final String sheetId;

  @override
  State<DemoSupplementEditScreen> createState() =>
      _DemoSupplementEditScreenState();
}

class _DemoSupplementEditScreenState extends State<DemoSupplementEditScreen> {
  late final SupplementSheet? _sheet = demoSession.sheetById(widget.sheetId);
  final Map<String, TextEditingController> _c =
      <String, TextEditingController>{};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final SupplementSheet? s = _sheet;
    if (s == null) return;
    for (final SheetField f in kSheetFields) {
      _c[f.key] = TextEditingController(text: s.valueOf(f.key));
    }
    _c['source'] = TextEditingController(text: s.source);
    _c['reviewedBy'] = TextEditingController(text: s.reviewedBy);
    _c['reviewedAt'] = TextEditingController(
      text: s.reviewedAt == null ? '' : formatDocDate(s.reviewedAt!),
    );
    for (final TextEditingController c in _c.values) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _detail => '/suplementacao/${widget.sheetId}';

  SupplementSheet? _build() {
    final String date = _c['reviewedAt']!.text.trim();
    final DateTime? reviewedAt = date.isEmpty ? null : parseDocDate(date);
    if (date.isNotEmpty && reviewedAt == null) {
      showDemoSnack(context, 'Data de revisão inválida (use dd/mm/aaaa).');
      return null;
    }
    return _sheet!.edit(
      content: <String, String>{
        for (final SheetField f in kSheetFields) f.key: _c[f.key]!.text.trim(),
      },
      source: _c['source']!.text.trim(),
      reviewedBy: _c['reviewedBy']!.text.trim(),
      reviewedAt: reviewedAt,
    );
  }

  void _saveDraft() {
    final SupplementSheet? s = _build();
    if (s == null) return;
    demoSession.saveSheet(s);
    setState(() => _dirty = false);
    showDemoSnack(context, 'Ficha salva como rascunho nesta aba.');
  }

  void _validate() {
    final SupplementSheet? s = _build();
    if (s == null) return;
    final List<String> missing = s.missingForValidation;
    if (missing.isNotEmpty) {
      demoSession.saveSheet(s);
      setState(() => _dirty = false);
      showDemoSnack(
        context,
        'Salvo como rascunho. Para validar, faltam: ${missing.join(', ')}.',
      );
      return;
    }
    demoSession.saveSheet(s.validate());
    showDemoSnack(context, 'Ficha validada nesta demonstração.');
    context.go(_detail);
  }

  Future<void> _leave() async {
    if (!_dirty || await confirmDiscard(context)) {
      if (mounted) context.go(_detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupplementSheet? s = _sheet;
    if (s == null) return DemoSupplementDetailScreen(sheetId: widget.sheetId);
    Widget field(String key, String label, {int lines = 1, String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            controller: _c[key],
            minLines: lines,
            maxLines: lines + 4,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              alignLabelWithHint: lines > 1,
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
          title: Text('Editar: ${s.title}'),
        ),
        bottomNavigationBar: DemoFlowActions(
          onBack: _leave,
          onCancel: _leave,
          onSaveDraft: _saveDraft,
          primaryLabel: 'Validar ficha',
          primaryIcon: Icons.verified_outlined,
          onPrimary: _validate,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoNotice(
                    icon: Icons.copyright_outlined,
                    color: AppColors.warning,
                    text:
                        'Escreva texto próprio. Não copie páginas, tabelas ou '
                        'imagens de material de terceiros sem licença. Validar exige '
                        'todos os campos, fonte, revisor e data de revisão.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final SheetField f in kSheetFields)
                    field(f.key, f.label, lines: 2),
                  field(
                    'source',
                    'Fonte (referência bibliográfica e licença)',
                    lines: 2,
                  ),
                  field('reviewedBy', 'Revisado por'),
                  field('reviewedAt', 'Data de revisão', hint: 'dd/mm/aaaa'),
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
