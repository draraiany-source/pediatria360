import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/config/capi_pose.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/content.dart';
import '../providers/library_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Carrega a próxima página 400px antes do fim: o usuário não vê o vazio.
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      ref.read(libraryProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // 400ms: digitar "bronquiolite" dispararia 12 consultas sem isso.
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => setState(() => _query = value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LibraryState state = ref.watch(libraryProvider);
    final LibraryFilter filter = ref.watch(libraryFilterProvider);
    final bool searching = _query.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SearchBar(
              controller: _search,
              hintText: 'Buscar febre, sono, bronquiolite...',
              leading: const Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Icon(Icons.search_rounded, size: 20),
              ),
              trailing: <Widget>[
                if (_search.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Limpar',
                  ),
              ],
              onChanged: _onSearchChanged,
              elevation: const WidgetStatePropertyAll<double>(0),
              backgroundColor: WidgetStatePropertyAll<Color>(
                theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
      body: searching
          ? _SearchResults(query: _query)
          : RefreshIndicator(
              onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scroll,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _Filters(filter: filter),
                  ),
                  if (state.isLoading)
                    const SliverToBoxAdapter(
                      child: SkeletonList(itemCount: 5, itemHeight: 80),
                    )
                  else if (state.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: state.failure != null
                          ? ErrorState(
                              failure: state.failure!,
                              onRetry: () =>
                                  ref.read(libraryProvider.notifier).refresh(),
                            )
                          : EmptyState(
                              icon: Icons.menu_book_outlined,
                              illustration: AppAssets.capiForPose(CapiPose.boasVindas),
                              title: filter.category == null
                                  ? 'Biblioteca vazia'
                                  : 'Nada em '
                                      '${ContentCategory.labelOf(filter.category!)}',
                              message: 'O conteúdo é publicado pelo painel '
                                  'administrativo e aparece aqui assim que '
                                  'for cadastrado.',
                              actionLabel: filter.category == null
                                  ? null
                                  : 'Ver tudo',
                              onAction: filter.category == null
                                  ? null
                                  : () => ref
                                      .read(libraryFilterProvider.notifier)
                                      .clear(),
                            ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.xxxl,
                      ),
                      sliver: SliverList.separated(
                        itemCount: state.items.length +
                            (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (BuildContext context, int index) {
                          if (index >= state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          }
                          return ContentBounds(
                            child: ContentCard(content: state.items[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.filter});

  final LibraryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryFilterController controller =
        ref.read(libraryFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              FilterChip(
                label: const Text('Tudo'),
                selected: filter.type == null,
                onSelected: (_) => controller.setType(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                label: const Text('Protocolos'),
                selected: filter.type == ContentType.protocol,
                onSelected: (_) => controller.setType(ContentType.protocol),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                label: const Text('Artigos'),
                selected: filter.type == ContentType.article,
                onSelected: (_) => controller.setType(ContentType.article),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('Todas'),
                selected: filter.category == null,
                onSelected: (_) => controller.setCategory(null),
              ),
              for (final ContentCategory category in ContentCategory.all)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: filter.category == category.id,
                    onSelected: (_) => controller.setCategory(category.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Content>> results =
        ref.watch(librarySearchProvider(query));

    return results.when(
      loading: () => const SkeletonList(itemCount: 4, itemHeight: 80),
      error: (Object e, StackTrace s) => EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Busca indisponível',
        message: 'Não foi possível buscar agora. Verifique sua conexão.',
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(librarySearchProvider(query)),
      ),
      data: (List<Content> items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nada encontrado',
            message: 'Não achamos nada para "$query". Tente outra palavra — '
                'buscar por sintoma costuma funcionar melhor que por frase.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) =>
              ContentBounds(child: ContentCard(content: items[index])),
        );
      },
    );
  }
}

/// Cartão de um conteúdo na lista.
class ContentCard extends StatelessWidget {
  const ContentCard({required this.content, super.key});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SurfaceCard(
      onTap: () => context.push(Routes.article(content.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppTag(
                label: content.type.label,
                color: content.isProtocol
                    ? AppColors.moduleLibrary
                    : theme.colorScheme.primary,
                icon: content.isProtocol
                    ? Icons.assignment_outlined
                    : Icons.article_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ContentCategory.labelOf(content.category),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${content.readMinutes} min',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(content.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            content.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (content.redFlags.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.priority_high_rounded,
                  size: 14,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Inclui sinais de alarme',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
