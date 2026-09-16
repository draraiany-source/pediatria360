import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../error/failures.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Tela vazia. Um vazio e um convite para agir, nunca um beco sem saida:
/// sempre traz um proximo passo concreto.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.animation,
    super.key,
  });

  /// Animação Lottie no lugar do ícone.
  ///
  /// Usada nos vazios que o usuário vê com frequência — lista de crianças sem
  /// cadastro, biblioteca sem conteúdo. Um ícone estático nesses lugares faz a
  /// tela parecer quebrada; movimento sinaliza que está tudo certo, só não há
  /// nada ainda.
  ///
  /// Nos vazios de erro o ícone continua: animação alegre sobre falha é ruído.
  final String? animation;

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (animation != null)
                SizedBox(
                  height: 140,
                  child: Lottie.asset(
                    animation!,
                    repeat: true,
                    // Se o arquivo faltar, cai no ícone em vez de quebrar a tela.
                    errorBuilder: (BuildContext context, Object error, _) =>
                        Icon(icon, size: 40, color: theme.colorScheme.outline),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Icon(icon, size: 32, color: AppColors.brand),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de erro. Diz o que aconteceu e o que fazer — nunca pede desculpas
/// nem mostra codigo tecnico ao usuario.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.failure,
    this.onRetry,
    super.key,
  });

  final Failure failure;
  final VoidCallback? onRetry;

  IconData get _icon => switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        PermissionFailure() => Icons.lock_outline_rounded,
        NotFoundFailure() => Icons.search_off_rounded,
        QuotaFailure() => Icons.hourglass_empty_rounded,
        _ => Icons.error_outline_rounded,
      };

  String get _title => switch (failure) {
        NetworkFailure() => 'Sem conexão',
        PermissionFailure() => 'Acesso restrito',
        NotFoundFailure() => 'Nada por aqui',
        QuotaFailure() => 'Limite atingido',
        ValidationFailure() => 'Revise os dados',
        _ => 'Não conseguimos carregar essas informações',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(_icon, size: 32, color: AppColors.brand),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                failure.message.isNotEmpty
                    ? failure.message
                    : 'Tente novamente em alguns instantes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Recarregar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa fina exibida no topo quando o app esta offline.
/// Aviso de que o dado clínico exibido nesta tela é aproximado ou precisa
/// de conferência — curva de crescimento aproximada, calendário vacinal a
/// confirmar.
///
/// Fica logo abaixo da barra superior, acima do conteúdo — o primeiro lugar
/// que os olhos passam antes de ler qualquer número. Existe porque duas
/// telas diferentes (crescimento e vacinação) tinham o aviso só em
/// comentário de código, nunca visível para quem usa o app de verdade — o
/// tipo de lacuna que só aparece quando se verifica a tela, não o arquivo.
class DataWarningBanner extends StatelessWidget {
  const DataWarningBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.pendingCount = 0, super.key});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = pendingCount > 0
        ? 'Offline. $pendingCount ${pendingCount == 1 ? 'alteracao aguarda' : 'alteracoes aguardam'} envio.'
        : 'Offline. Mostrando os dados salvos no aparelho.';

    return Material(
      color: AppColors.warning.withValues(alpha: 0.16),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de carregamento centralizado.
class LoadingState extends StatelessWidget {
  const LoadingState({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.brand,
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
