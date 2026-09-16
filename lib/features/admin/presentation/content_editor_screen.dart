import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/content.dart';
import '../data/admin_content_repository.dart';

final Provider<AdminContentRepository> adminContentRepositoryProvider =
    Provider<AdminContentRepository>(
  (Ref ref) => AdminContentRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final StreamProvider<List<Content>> allContentProvider =
    StreamProvider<List<Content>>(
  (Ref ref) => ref.watch(adminContentRepositoryProvider).watchAll(),
);

final StreamProviderFamily<List<ContentVersion>, String> contentVersionsProvider =
    StreamProvider.family<List<ContentVersion>, String>(
  (Ref ref, String contentId) =>
      ref.watch(adminContentRepositoryProvider).watchVersions(contentId),
);

// ------------------------------------------------------------------ Lista

class AdminContentListScreen extends ConsumerWidget {
  const AdminContentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Content>> content = ref.watch(allContentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conteúdo'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ContentEditorScreen(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo'),
      ),
      body: content.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 72),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.article_outlined,
          title: 'Não foi possível carregar',
          message: 'Verifique se você tem papel de admin.',
        ),
        data: (List<Content> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.article_outlined,
              title: 'Nenhum conteúdo',
              message: 'Crie o primeiro artigo ou protocolo.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final Content c = list[index];

              return ContentBounds(
                maxWidth: 720,
                child: Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ContentEditorScreen(content: c),
                      ),
                    ),
                    title: Text(
                      c.title.isEmpty ? '(sem título)' : c.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          AppTag(
                            label: c.published ? 'No ar' : 'Rascunho',
                            color: c.published
                                ? AppColors.success
                                : AppColors.inkMuted,
                          ),
                          AppTag(label: c.type.label),
                          AppTag(label: ContentCategory.labelOf(c.category)),
                          if (c.audience == ContentAudience.professionals)
                            const AppTag(
                              label: 'Profissional',
                              color: AppColors.raspberry,
                            ),
                          if (c.reviewedBy == null)
                            const AppTag(
                              label: 'Sem revisor',
                              color: AppColors.warning,
                              icon: Icons.gpp_maybe_outlined,
                            ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VersionHistoryScreen(content: c),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'Histórico',
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------- Editor

class ContentEditorScreen extends ConsumerStatefulWidget {
  const ContentEditorScreen({this.content, super.key});

  final Content? content;

  @override
  ConsumerState<ContentEditorScreen> createState() =>
      _ContentEditorScreenState();
}

class _ContentEditorScreenState extends ConsumerState<ContentEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _tags;
  late final TextEditingController _author;
  late final TextEditingController _reviewedBy;

  late ContentType _type;
  late ContentAudience _audience;
  late String _category;
  late int _readMinutes;
  late List<_SectionDraft> _sections;

  bool _saving = false;

  bool get _isNew => widget.content == null;

  @override
  void initState() {
    super.initState();
    final Content? c = widget.content;

    _title = TextEditingController(text: c?.title ?? '');
    _summary = TextEditingController(text: c?.summary ?? '');
    _tags = TextEditingController(text: c?.tags.join(', ') ?? '');
    _author = TextEditingController(text: c?.author ?? '');
    _reviewedBy = TextEditingController(text: c?.reviewedBy ?? '');

    _type = c?.type ?? ContentType.article;
    _audience = c?.audience ?? ContentAudience.everyone;
    _category = c?.category ?? ContentCategory.all.first.id;
    _readMinutes = c?.readMinutes ?? 3;
    _sections = (c?.sections ?? const <ContentSection>[])
        .map(_SectionDraft.from)
        .toList();

    if (_sections.isEmpty) _sections = <_SectionDraft>[_SectionDraft.empty()];
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _tags.dispose();
    _author.dispose();
    _reviewedBy.dispose();
    for (final _SectionDraft s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  /// Avisos que a tela mostra antes de o servidor recusar.
  ///
  /// A validação real está na Function — esta aqui existe para o autor não
  /// escrever um protocolo inteiro e só descobrir o problema ao publicar.
  List<String> get _warnings {
    final List<String> issues = <String>[];

    if (_type == ContentType.protocol &&
        !_sections.any((_SectionDraft s) => s.kind == SectionKind.redFlag)) {
      issues.add(
        'Protocolo sem seção de sinais de alarme. Todo documento de conduta '
        'precisa dizer quando procurar atendimento.',
      );
    }

    if (_sections.any((_SectionDraft s) => s.kind == SectionKind.dosage) &&
        _audience != ContentAudience.professionals) {
      issues.add(
        'Há seção de posologia, mas o público não é "profissionais". Dose '
        'lida por um responsável é risco de automedicação.',
      );
    }

    if (_reviewedBy.text.trim().isEmpty) {
      issues.add('Sem revisor clínico identificado.');
    }

    return issues;
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    final String? note = await _askNote(publish: publish);
    if (note == null) return;

    setState(() => _saving = true);

    final Map<String, dynamic> data = <String, dynamic>{
      'title': _title.text.trim(),
      'summary': _summary.text.trim(),
      'type': _type.name,
      'audience': _audience.name,
      'category': _category,
      'readMinutes': _readMinutes,
      'author': _author.text.trim().isEmpty ? null : _author.text.trim(),
      'reviewedBy':
          _reviewedBy.text.trim().isEmpty ? null : _reviewedBy.text.trim(),
      'tags': _tags.text
          .split(',')
          .map((String t) => t.trim())
          .where((String t) => t.isNotEmpty)
          .toList(),
      'sections': _sections
          .where((_SectionDraft s) => s.hasContent)
          .map((_SectionDraft s) => s.toMap())
          .toList(),
    };

    final Result<String> result =
        await ref.read(adminContentRepositoryProvider).save(
              contentId: widget.content?.id,
              data: data,
              note: note,
              publish: publish,
            );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Publicado.' : 'Rascunho salvo.'),
          ),
        );
        Navigator.of(context).pop();
      },
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      ),
    );
  }

  /// Toda gravação exige uma nota. Sem isso, o histórico vira uma lista de
  /// datas sem sentido seis meses depois.
  Future<String?> _askNote({required bool publish}) {
    final TextEditingController controller = TextEditingController();

    // `_askNote` devolve o Future direto, sem `await` — não há um ponto
    // síncrono "depois que o diálogo fecha" dentro deste método para
    // descartar o controller. `whenComplete` resolve isso: dispara assim
    // que o diálogo fecha, independente do resultado.
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(publish ? 'Publicar' : 'Salvar rascunho'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'O que mudou nesta versão?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex.: corrigida a faixa etária dos sinais de alarme',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final String text = controller.text.trim();
              if (text.length < 3) return;
              Navigator.of(context).pop(text);
            },
            child: Text(publish ? 'Publicar' : 'Salvar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> warnings = _warnings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Novo conteúdo' : 'Editar'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fechar',
        ),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VersionHistoryScreen(content: widget.content!),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Histórico',
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Salvar rascunho',
                  variant: AppButtonVariant.outline,
                  isLoading: _saving,
                  onPressed: () => _save(publish: false),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Publicar',
                  isLoading: _saving,
                  onPressed: () => _save(publish: true),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ContentBounds(
          maxWidth: 720,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (warnings.isNotEmpty) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.gpp_maybe_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Impede a publicação',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final String w in warnings)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Text('• $w',
                                style: theme.textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppTextField(
                  label: 'Título',
                  controller: _title,
                  validator: (String? v) =>
                      Validators.required(v, field: 'O título'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Resumo',
                  controller: _summary,
                  helper: 'Aparece na lista e na busca.',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<ContentType>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: ContentType.values
                            .map(
                              (ContentType t) => DropdownMenuItem<ContentType>(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                        onChanged: (ContentType? v) =>
                            setState(() => _type = v ?? _type),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<ContentAudience>(
                        value: _audience,
                        decoration: const InputDecoration(labelText: 'Público'),
                        items: ContentAudience.values
                            .map(
                              (ContentAudience a) =>
                                  DropdownMenuItem<ContentAudience>(
                                value: a,
                                child: Text(a.label),
                              ),
                            )
                            .toList(),
                        onChanged: (ContentAudience? v) =>
                            setState(() => _audience = v ?? _audience),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: ContentCategory.all
                      .map(
                        (ContentCategory c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.label),
                        ),
                      )
                      .toList(),
                  onChanged: (String? v) =>
                      setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Autor',
                        controller: _author,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Revisor clínico',
                        controller: _reviewedBy,
                        helper: 'Obrigatório para publicar.',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Tags',
                  controller: _tags,
                  helper: 'Separadas por vírgula. Alimentam a busca.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Text('Tempo de leitura', style: theme.textTheme.bodyMedium),
                    Expanded(
                      child: Slider(
                        value: _readMinutes.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '$_readMinutes min',
                        onChanged: (double v) =>
                            setState(() => _readMinutes = v.round()),
                      ),
                    ),
                    Text('$_readMinutes min',
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                SectionHeader(
                  title: 'Seções',
                  eyebrow: 'Corpo',
                  actionLabel: 'Adicionar',
                  onAction: () => setState(
                    () => _sections.add(_SectionDraft.empty()),
                  ),
                ),
                for (int i = 0; i < _sections.length; i++)
                  _SectionEditor(
                    key: ValueKey<_SectionDraft>(_sections[i]),
                    draft: _sections[i],
                    index: i + 1,
                    onChanged: () => setState(() {}),
                    onRemove: _sections.length == 1
                        ? null
                        : () => setState(() {
                              _sections.removeAt(i).dispose();
                            }),
                    onMoveUp: i == 0
                        ? null
                        : () => setState(() {
                              final _SectionDraft s = _sections.removeAt(i);
                              _sections.insert(i - 1, s);
                            }),
                  ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rascunho editável de uma seção.
class _SectionDraft {
  _SectionDraft({
    required this.title,
    required this.body,
    required this.kind,
  });

  factory _SectionDraft.from(ContentSection section) => _SectionDraft(
        title: TextEditingController(text: section.title),
        body: TextEditingController(text: section.body),
        kind: section.kind,
      );

  factory _SectionDraft.empty() => _SectionDraft(
        title: TextEditingController(),
        body: TextEditingController(),
        kind: SectionKind.text,
      );

  final TextEditingController title;
  final TextEditingController body;
  SectionKind kind;

  bool get hasContent =>
      title.text.trim().isNotEmpty || body.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title.text.trim(),
        'body': body.text.trim(),
        'kind': kind.name,
      };

  void dispose() {
    title.dispose();
    body.dispose();
  }
}

class _SectionEditor extends StatelessWidget {
  const _SectionEditor({
    required this.draft,
    required this.index,
    required this.onChanged,
    this.onRemove,
    this.onMoveUp,
    super.key,
  });

  final _SectionDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;

  String _kindLabel(SectionKind kind) => switch (kind) {
        SectionKind.text => 'Texto',
        SectionKind.redFlag => 'Sinais de alarme',
        SectionKind.steps => 'Passo a passo',
        SectionKind.dosage => 'Posologia',
        SectionKind.reference => 'Referência',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color accent = switch (draft.kind) {
      SectionKind.redFlag => AppColors.emergency,
      SectionKind.dosage => AppColors.vital,
      _ => theme.colorScheme.outline,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: accent.withValues(alpha: 0.5),
            width: draft.kind == SectionKind.text ? 1 : 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Seção $index', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  if (onMoveUp != null)
                    IconButton(
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Mover para cima',
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onRemove != null)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: 'Remover',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<SectionKind>(
                value: draft.kind,
                decoration: const InputDecoration(labelText: 'Tipo de seção'),
                items: SectionKind.values
                    .map(
                      (SectionKind k) => DropdownMenuItem<SectionKind>(
                        value: k,
                        child: Text(_kindLabel(k)),
                      ),
                    )
                    .toList(),
                onChanged: (SectionKind? v) {
                  draft.kind = v ?? draft.kind;
                  onChanged();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Título da seção', controller: draft.title),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Conteúdo',
                controller: draft.body,
                maxLines: 8,
                helper: draft.kind == SectionKind.steps
                    ? 'Uma linha por passo.'
                    : null,
              ),
              if (draft.kind == SectionKind.dosage) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Seções de posologia só aparecem para profissionais com '
                  'registro verificado, e exigem público "profissionais".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.vital,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Histórico

class VersionHistoryScreen extends ConsumerWidget {
  const VersionHistoryScreen({required this.content, super.key});

  final Content content;

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    ContentVersion version,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Voltar para a versão ${version.version}?'),
        content: Text(
          'O conteúdo publicado será substituído por "${version.title}". '
          'O histórico não é apagado: a restauração vira uma versão nova.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !context.mounted) return;

    final Result<void> result =
        await ref.read(adminContentRepositoryProvider).restore(
              contentId: content.id,
              versionId: version.id,
              note: 'Restauração pelo painel',
            );

    if (!context.mounted) return;

    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Versão ${version.version} restaurada.')),
      ),
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ContentVersion>> versions =
        ref.watch(contentVersionsProvider(content.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: versions.when(
        loading: () => const SkeletonList(itemCount: 4, itemHeight: 88),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.history_rounded,
          title: 'Histórico indisponível',
          message: 'Tente novamente em instantes.',
        ),
        data: (List<ContentVersion> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'Sem versões ainda',
              message: 'O histórico começa na primeira gravação.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final ContentVersion v = list[index];
              final bool isCurrent = index == 0;

              // Compara com a versão anterior para mostrar o que mudou.
              final VersionDiff? diff = index + 1 < list.length
                  ? VersionDiff.between(list[index + 1].snapshot, v.snapshot)
                  : null;

              return ContentBounds(
                maxWidth: 720,
                child: Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            AppTag(
                              label: 'v${v.version}',
                              color: isCurrent
                                  ? AppColors.success
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (isCurrent)
                              const AppTag(
                                label: 'No ar',
                                color: AppColors.success,
                              )
                            else if (v.published)
                              const AppTag(label: 'Foi publicada'),
                            const Spacer(),
                            Text(
                              Formatters.relative(v.createdAt),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          v.note ?? '(sem descrição)',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${v.authorName ?? 'Equipe'} · '
                          '${Formatters.dateTime(v.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (diff != null && !diff.isEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${diff.totalChanges} '
                                  '${diff.totalChanges == 1 ? 'alteração' : 'alterações'}',
                                  style: theme.textTheme.labelMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                if (diff.changedFields.isNotEmpty)
                                  Text(
                                    'Campos: ${diff.changedFields.join(', ')}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                for (final String s in diff.sectionsAdded)
                                  Text('+ seção "$s"',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: AppColors.success)),
                                for (final String s in diff.sectionsRemoved)
                                  Text('− seção "$s"',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: AppColors.danger)),
                                for (final String s in diff.sectionsChanged)
                                  Text('~ seção "$s" alterada',
                                      style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                        if (!isCurrent) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Restaurar esta versão',
                            variant: AppButtonVariant.outline,
                            icon: Icons.restore_rounded,
                            onPressed: () => _restore(context, ref, v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
