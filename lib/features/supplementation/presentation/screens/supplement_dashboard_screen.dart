import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../providers/supplement_providers.dart';
import '../widgets/supplement_widgets.dart';

/// Hub premium — Suplementacao Pediatrica.
class SupplementDashboardScreen extends ConsumerStatefulWidget {
  const SupplementDashboardScreen({this.childId, super.key});

  final String? childId;

  @override
  ConsumerState<SupplementDashboardScreen> createState() =>
      _SupplementDashboardScreenState();
}

class _SupplementDashboardScreenState
    extends ConsumerState<SupplementDashboardScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _withChild(String path) {
    final String? id = widget.childId;
    if (id == null || id.isEmpty) return path;
    final String sep = path.contains('?') ? '&' : '?';
    return '$path${sep}childId=$id';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> recent =
        ref.watch(supplementRecentProvider);
    final AsyncValue<List<String>> favorites =
        ref.watch(supplementFavoritesProvider);

    final List<_DashItem> items = <_DashItem>[
      _DashItem('Micronutrientes', 'Perfis clinicos estruturados', Icons.science_outlined, AppColors.brand, Routes.supplementMicronutrientsPath),
      _DashItem('Exames laboratoriais', 'Registro e acompanhamento', Icons.biotech_outlined, AppColors.teal, Routes.supplementLabsPath),
      _DashItem('Calculadoras', 'Sugestao para conferencia', Icons.calculate_outlined, AppColors.navy, Routes.supplementCalculatorPath),
      _DashItem('Protocolos rapidos', 'Cenarios clinicos', Icons.playlist_add_check_rounded, AppColors.moduleLibrary, Routes.supplementProtocolsPath),
      _DashItem('Assistente IA', 'Organiza dados e atalhos', Icons.auto_awesome_outlined, AppColors.raspberry, Routes.supplementAiPath),
      _DashItem('Prescricoes', 'Rascunho com confirmacao', Icons.medication_outlined, AppColors.tealDeep, Routes.supplementPrescriptionPath),
      _DashItem('Orientacoes aos pais', 'Versao simplificada', Icons.family_restroom_outlined, AppColors.honey, Routes.supplementParentPath),
      _DashItem('Historico', 'Timeline do paciente', Icons.timeline_outlined, AppColors.vital, Routes.supplementHistoryPath),
      _DashItem('Alimentos', 'Fontes de micronutrientes', Icons.restaurant_outlined, AppColors.success, Routes.supplementFoodsPath),
      _DashItem('Favoritos', 'Acesso rapido', Icons.star_outline_rounded, AppColors.warning, Routes.supplementFavoritesPath),
      _DashItem('IA — Interpretar exames', 'Apoio a decisao', Icons.analytics_outlined, AppColors.brandSoft, Routes.supplementLabAiPath),
      _DashItem('Graficos', 'Evolucao laboratorial', Icons.show_chart_outlined, AppColors.navy, Routes.supplementChartsPath),
    ].where(( _DashItem i) {
      if (_query.isEmpty) return true;
      final String q = _query.toLowerCase();
      return i.label.toLowerCase().contains(q) ||
          i.subtitle.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Suplementacao Pediatrica'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            'Ferramenta clinica integrada',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Micronutrientes, exames, calculadoras e prescritor — com revisao medica obrigatoria.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          if (widget.childId != null && widget.childId!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Chip(
              avatar: const Icon(Icons.child_care, size: 18),
              label: Text('Paciente: ${widget.childId}'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _search,
            onChanged: (String v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Busca global no modulo...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const BrandSectionHeader(title: 'Modulos'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int cols = c.maxWidth > 720 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (BuildContext context, int i) {
                  final _DashItem item = items[i];
                  return SupplementModuleCard(
                    label: item.label,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    color: item.color,
                    onTap: () => context.push(_withChild(item.path)),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const BrandSectionHeader(title: 'Ultimos acessados'),
          const SizedBox(height: AppSpacing.sm),
          recent.when(
            loading: () => const SupplementSkeletonList(count: 2),
            error: (Object e, StackTrace _) => Text('$e'),
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) {
                return const SupplementEmptyState(
                  message: 'Nenhum acesso recente ainda.',
                  icon: Icons.history_outlined,
                );
              }
              return Column(
                children: list.take(5).map((Map<String, dynamic> e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () {
                        final String type = (e['itemType'] as String?) ?? '';
                        final String id = (e['itemId'] as String?) ?? '';
                        if (type == 'micronutrient' && id.isNotEmpty) {
                          context.push(Routes.supplementMicronutrient(id));
                        }
                      },
                      child: Text((e['label'] as String?) ?? 'Item'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const BrandSectionHeader(title: 'Favoritos'),
          const SizedBox(height: AppSpacing.sm),
          favorites.when(
            loading: () => const SupplementSkeletonList(count: 1),
            error: (Object e, StackTrace _) => Text('$e'),
            data: (List<String> ids) {
              if (ids.isEmpty) {
                return const SupplementEmptyState(
                  message: 'Salve micronutrientes nos favoritos para acesso rapido.',
                  icon: Icons.star_border_rounded,
                );
              }
              return Wrap(
                spacing: AppSpacing.sm,
                children: ids
                    .map(
                      (String id) => ActionChip(
                        label: Text(id),
                        onPressed: () =>
                            context.push(Routes.supplementMicronutrient(id)),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashItem {
  const _DashItem(this.label, this.subtitle, this.icon, this.color, this.path);
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String path;
}
