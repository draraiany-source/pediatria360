import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/visit_summary.dart';
import '../../../emr/presentation/screens/patient_timeline_screen.dart'
    show encounterRepositoryProvider;

/// Lista de resumos de consulta liberados para a família — linguagem
/// simples, nunca o prontuário técnico. Rascunho nunca aparece aqui: a
/// regra do servidor já filtra isso antes mesmo do app pedir.
final StreamProviderFamily<List<VisitSummary>, String>
    releasedVisitSummariesProvider =
    StreamProvider.family<List<VisitSummary>, String>(
  (Ref ref, String childId) => ref
      .watch(encounterRepositoryProvider)
      .watchReleasedVisitSummaries(childId),
);

class VisitSummariesScreen extends ConsumerWidget {
  const VisitSummariesScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VisitSummary>> summaries =
        ref.watch(releasedVisitSummariesProvider(childId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumos de consulta'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: summaries.when(
        loading: () => const SkeletonList(itemCount: 3, itemHeight: 96),
        error: (Object error, StackTrace stack) => ErrorState(
          failure: ErrorMapper.map(error, stack),
          onRetry: () => ref.invalidate(releasedVisitSummariesProvider(childId)),
        ),
        data: (List<VisitSummary> list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.summarize_outlined,
                title: 'Nenhum resumo ainda',
                message: 'Depois de uma consulta, o resumo aparece aqui '
                    'assim que o profissional liberar.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) =>
                    _SummaryCard(summary: list[index]),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final VisitSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _SummaryDetailSheet(summary: summary),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.summarize_outlined,
                        size: 18, color: AppColors.petrol),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        Formatters.date(
                          summary.releasedAt ?? summary.createdAt,
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
                if (summary.guidance.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    summary.guidance,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (summary.warningSigns.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  AppTag(
                    label: '${summary.warningSigns.length} '
                        '${summary.warningSigns.length == 1 ? 'sinal de alerta' : 'sinais de alerta'}',
                    color: AppColors.warning,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryDetailSheet extends StatelessWidget {
  const _SummaryDetailSheet({required this.summary});

  final VisitSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget section(String label, String? value, {IconData? icon}) {
      if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Resumo da consulta de '
                '${Formatters.date(summary.releasedAt ?? summary.createdAt)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              section('Orientação', summary.guidance),
              section('Cuidados', summary.careInstructions),
              if (summary.warningSigns.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Procure ajuda se notar',
                          style: theme.textTheme.labelSmall),
                      const SizedBox(height: AppSpacing.xs),
                      for (final String sign in summary.warningSigns)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(sign, style: theme.textTheme.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              section('Retorno', summary.followUpNotes),
              if (summary.followUpDate != null)
                section('Data de retorno', Formatters.date(summary.followUpDate!)),
              if (summary.releasedDocumentIds.isNotEmpty)
                Text(
                  '${summary.releasedDocumentIds.length} documento(s) desta '
                  'consulta — veja em Documentos.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
