import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/content.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/library_providers.dart';

class ContentDetailScreen extends ConsumerWidget {
  const ContentDetailScreen({required this.contentId, super.key});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Content> content = ref.watch(contentProvider(contentId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        title: content.maybeWhen(
          data: (Content c) => Text(
            c.type.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: content.when(
        loading: () => const LoadingState(),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.article_outlined,
          title: 'Conteúdo indisponível',
          message: 'Não foi possível abrir agora. Se você já leu este '
              'conteúdo antes, ele fica disponível offline.',
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(contentProvider(contentId)),
        ),
        data: (Content c) => _Body(content: c),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool canSeeDosage =
        ref.watch(currentUserProvider)?.canPrescribe ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: <Widget>[
        ContentBounds(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  AppTag(
                    label: ContentCategory.labelOf(content.category),
                    color: AppColors.moduleLibrary,
                  ),
                  AppTag(label: content.audience.label),
                  AppTag(
                    label: '${content.readMinutes} min de leitura',
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(content.title, style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                content.summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Attribution(content: content),

              // Sinais de alarme sobem para o topo. Quem abre um protocolo de
              // febre com a criança no colo precisa ver "quando correr" antes
              // de qualquer fisiopatologia.
              if (content.redFlags.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                for (final ContentSection section in content.redFlags)
                  _RedFlagBox(section: section),
              ],

              const SizedBox(height: AppSpacing.lg),

              for (final ContentSection section in content.sections)
                if (section.kind != SectionKind.redFlag)
                  _Section(
                    section: section,
                    canSeeDosage: canSeeDosage,
                  ),

              const SizedBox(height: AppSpacing.xxl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Este conteúdo é informativo e não substitui a avaliação de '
                'um pediatra. Em caso de dúvida sobre a saúde da sua criança, '
                'procure atendimento.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Autoria e revisão. Conteúdo médico sem revisor identificado é sinalizado —
/// o leitor merece saber quem responde pelo que está lendo.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool reviewed = content.reviewedBy != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            reviewed
                ? Icons.verified_outlined
                : Icons.info_outline_rounded,
            size: 18,
            color: reviewed
                ? AppColors.success
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reviewed
                      ? 'Revisado por ${content.reviewedBy}'
                      : 'Revisão clínica pendente',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  <String>[
                    if (content.author != null) content.author!,
                    'Atualizado em ${Formatters.date(content.updatedAt)}',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedFlagBox extends StatelessWidget {
  const _RedFlagBox({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.emergency.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.emergency.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  section.title.isEmpty
                      ? 'Procure atendimento se...'
                      : section.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.emergency,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(section.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.canSeeDosage});

  final ContentSection section;
  final bool canSeeDosage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Posologia só para profissional verificado. Para os demais, mostramos que
    // a seção existe e por que está fechada — esconder sem explicar parece bug.
    if (section.kind == SectionKind.dosage && !canSeeDosage) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    section.title.isEmpty ? 'Posologia' : section.title,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Disponível para profissionais de saúde com registro '
                    'verificado. Sobre medicamentos e doses, converse com o '
                    'pediatra ou o farmacêutico.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (section.kind == SectionKind.reference) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (section.title.isNotEmpty)
              Text(section.title, style: theme.textTheme.labelMedium),
            Text(
              section.body,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final bool isDosage = section.kind == SectionKind.dosage;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (section.title.isNotEmpty) ...<Widget>[
            Text(section.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isDosage)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.vital.withValues(alpha: 0.07),
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: AppColors.vital.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(section.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Confira sempre o peso atual e a apresentação disponível '
                    'antes de prescrever.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.vital,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (section.kind == SectionKind.steps)
            _Steps(body: section.body)
          else
            Text(
              section.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
            ),
        ],
      ),
    );
  }
}

/// Passo a passo: cada linha do corpo vira um item numerado.
class _Steps extends StatelessWidget {
  const _Steps({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> steps = body
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    // Ajuste óptico: alinha a linha de base do texto do passo com o
                    // número ao lado, não um espaçamento de layout.
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      steps[i],
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
