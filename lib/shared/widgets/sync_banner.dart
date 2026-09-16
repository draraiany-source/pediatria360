import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/services/local_database.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';

/// Itens travados na fila de envio.
///
/// Um item chega a "envenenado" após 5 tentativas. Nesse ponto o problema não
/// é rede: é payload inválido, permissão negada ou documento que sumiu do
/// servidor. Continuar tentando eternamente consome bateria e esconde o
/// problema.
final FutureProvider<List<OutboxEntry>> stuckEntriesProvider =
    FutureProvider<List<OutboxEntry>>((Ref ref) async {
  final LocalDatabase? db = ref.watch(localDatabaseProvider);
  if (db == null) return const <OutboxEntry>[];

  final List<OutboxEntry> all = await db.pendingOutbox(limit: 100);
  return all.where((OutboxEntry e) => e.isPoisoned).toList(growable: false);
});

/// Faixa de status da sincronização.
///
/// ## Por que isso não é enfeite
///
/// O app grava local primeiro e envia depois. Isso é o que permite registrar
/// uma vacina no posto sem sinal — mas cria uma pergunta que o usuário não
/// consegue responder sozinho: *"isso salvou?"*.
///
/// Para dado de saúde, "achei que tinha salvado" é um resultado ruim. A faixa
/// aparece quando há algo pendente ou algo deu errado, e some quando está tudo
/// enviado. Silêncio significa sucesso.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({this.compact = false, super.key});

  /// Versão reduzida, para barras de aplicativo.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncStatus> async = ref.watch(syncStatusProvider);
    final SyncStatus? status = async.valueOrNull;

    if (status == null) return const SizedBox.shrink();

    // Tudo enviado e sem erro: nada a dizer.
    if (!status.hasPending && status.lastError == null && !status.isSyncing) {
      return const SizedBox.shrink();
    }

    return compact
        ? _CompactIndicator(status: status)
        : _FullBanner(status: status);
  }
}

class _CompactIndicator extends StatelessWidget {
  const _CompactIndicator({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (status.isSyncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final bool failed = status.lastError != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Tooltip(
          message: failed
              ? 'Falha ao enviar. Toque para ver.'
              : '${status.pending} alteração(ões) aguardando envio',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                failed
                    ? Icons.sync_problem_rounded
                    : Icons.cloud_upload_outlined,
                size: 16,
                color: failed ? AppColors.danger : AppColors.warning,
              ),
              if (status.pending > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${status.pending}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: failed ? AppColors.danger : AppColors.warning,
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

class _FullBanner extends ConsumerWidget {
  const _FullBanner({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool failed = status.lastError != null;

    final Color color = failed
        ? AppColors.danger
        : status.isSyncing
            ? AppColors.vital
            : AppColors.warning;

    return Material(
      color: color.withValues(alpha: 0.10),
      child: InkWell(
        onTap: failed
            ? () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (BuildContext context) => const SyncRecoverySheet(),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              if (status.isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  failed
                      ? Icons.sync_problem_rounded
                      : Icons.cloud_upload_outlined,
                  size: 18,
                  color: color,
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      status.isSyncing
                          ? 'Enviando alterações...'
                          : failed
                              ? 'Algumas alterações não foram enviadas'
                              : '${status.pending} '
                                  '${status.pending == 1 ? 'alteração aguarda' : 'alterações aguardam'} envio',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      failed
                          ? 'Toque para ver o que travou.'
                          : 'Seus dados estão salvos no aparelho e serão '
                              'enviados assim que houver conexão.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!status.isSyncing && !failed)
                TextButton(
                  onPressed: () => ref.read(syncServiceProvider).sync(),
                  child: const Text('Enviar agora'),
                ),
              if (failed) const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuperação de itens travados.
///
/// ## Por que o usuário decide
///
/// Um item envenenado não volta a funcionar sozinho. As opções reais são
/// tentar de novo — útil quando a causa era permissão que já foi corrigida —
/// ou descartar.
///
/// Descartar perde o dado, e por isso a tela mostra **o que** vai ser perdido,
/// não apenas "1 item com erro". Descartar uma vacina registrada às cegas é
/// diferente de descartar uma medição duplicada.
class SyncRecoverySheet extends ConsumerWidget {
  const SyncRecoverySheet({super.key});

  static String _entityLabel(String entity) => switch (entity) {
        SyncEntity.children => 'Cadastro de criança',
        SyncEntity.growth => 'Medição de crescimento',
        SyncEntity.vaccineDoses => 'Registro de vacina',
        _ => entity,
      };

  static String _describe(OutboxEntry entry) {
    final Map<String, dynamic> p = entry.payload;

    return switch (entry.entity) {
      SyncEntity.children => p['name']?.toString() ?? 'Sem nome',
      SyncEntity.growth => <String>[
          if (p['weightKg'] != null) '${p['weightKg']} kg',
          if (p['heightCm'] != null) '${p['heightCm']} cm',
        ].join(', '),
      SyncEntity.vaccineDoses =>
        '${p['vaccineId'] ?? ''} · dose ${p['doseIndex'] ?? ''}',
      _ => entry.entityId,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<OutboxEntry>> async =
        ref.watch(stuckEntriesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Alterações travadas', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Estas alterações foram tentadas várias vezes e não passaram. '
            'Costuma ser permissão negada ou dado que mudou no servidor.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, StackTrace s) => Text(
              'Não foi possível ler a fila.',
              style: theme.textTheme.bodySmall,
            ),
            data: (List<OutboxEntry> entries) {
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: 32,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nenhuma alteração travada.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) =>
                      _StuckTile(entry: entries[index]),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Tentar todas de novo',
                  variant: AppButtonVariant.outline,
                  onPressed: () async {
                    final LocalDatabase? db =
                        ref.read(localDatabaseProvider);
                    if (db == null) return;

                    // Zera o contador para os itens saírem do estado
                    // envenenado e voltarem à fila normal.
                    await db.resetOutboxAttempts();
                    await ref.read(syncServiceProvider).sync();
                    ref.invalidate(stuckEntriesProvider);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StuckTile extends ConsumerWidget {
  const _StuckTile({required this.entry});

  final OutboxEntry entry;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Descartar esta alteração?'),
        content: Text(
          'Você vai perder: ${SyncRecoverySheet._describe(entry)}.\n\n'
          'Isso não pode ser desfeito. Se o dado for importante, registre-o '
          'de novo depois.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    final LocalDatabase? db = ref.read(localDatabaseProvider);
    if (db == null) return;

    await db.removeOutboxEntry(entry.id);
    ref.invalidate(stuckEntriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    SyncRecoverySheet._entityLabel(entry.entity),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                AppTag(
                  label: '${entry.attempts} tentativas',
                  color: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Mostra o que é, não só o id. Descartar às cegas é pior que o
            // erro que travou o item.
            Text(
              SyncRecoverySheet._describe(entry),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Criada em ${Formatters.dateTime(entry.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (entry.lastError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.07),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  entry.lastError!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _discard(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Descartar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
