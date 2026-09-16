import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// Finalidade de tratamento consentida.
class ConsentPurpose {
  const ConsentPurpose({
    required this.key,
    required this.label,
    required this.description,
    required this.required,
    required this.granted,
  });

  final String key;
  final String label;
  final String description;
  final bool required;
  final bool granted;
}

final FutureProvider<Map<String, dynamic>> privacyManifestProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  final HttpsCallableResult<dynamic> response = await ref
      .watch(firebaseFunctionsProvider)
      .httpsCallable('dataProcessingManifest')
      .call();

  return Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);
});

/// Privacidade e dados pessoais.
///
/// ## Por que uma tela e não um link para a política
///
/// A LGPD dá direitos que só existem se houver caminho para exercê-los. Uma
/// política de privacidade em PDF informa; ela não permite exportar, revogar
/// nem excluir. Cada direito do Art. 18 aqui tem um botão.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _busy = false;

  Future<T?> _call<T>(
    String name, {
    Map<String, dynamic>? data,
  }) async {
    setState(() => _busy = true);

    final Result<T> result = await guard(() async {
      final HttpsCallableResult<dynamic> response = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(minutes: 5),
            ),
          )
          .call(data ?? <String, dynamic>{});
      return response.data as T;
    });

    if (!mounted) return null;
    setState(() => _busy = false);

    return result.fold(
      (T value) => value,
      (Failure failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.danger,
            ),
          );
        return null;
      },
    );
  }

  Future<void> _export() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reunindo seus dados. Isso pode levar um minuto.'),
      ),
    );

    final Map<dynamic, dynamic>? result =
        await _call<Map<dynamic, dynamic>>('exportUserData');

    if (result == null || !mounted) return;

    final String? url = result['url'] as String?;
    if (url == null) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seus dados estão prontos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Arquivo JSON com tudo o que a plataforma guarda sobre você e '
              'suas crianças: cadastro, crescimento, vacinas, atendimentos, '
              'exames, receitas, pedidos e conversas com a IA.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'O link vale por 7 dias.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Baixar'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final TextEditingController reason = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Excluir sua conta?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Serão apagados: seu cadastro, os dados das crianças, '
                'medições, vacinas, exames, receitas, pedidos e conversas '
                'com a IA.',
              ),
              const SizedBox(height: AppSpacing.md),
              // Dizer o limite antes, não depois. Prometer exclusão total e
              // não cumprir seria pior que explicar por que não é possível.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  'Atendimentos já assinados por um médico não são apagados. '
                  'Eles são anonimizados — o vínculo com você é removido — e '
                  'guardados por 20 anos, como exige a Resolução CFM '
                  '1.821/2007 para prontuários.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'A exclusão acontece em 15 dias. Nesse período você pode '
                'voltar atrás.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Solicitar exclusão'),
          ),
        ],
      ),
    );

    // O controller só existe para o campo dentro do diálogo. Uma vez
    // fechado, captura o texto e descarta — sem isso, cada vez que alguém
    // abre esta confirmação e não conclui, um TextEditingController fica
    // preso na memória.
    final String reasonText = reason.text.trim();
    reason.dispose();

    if (!(confirmed ?? false) || !mounted) return;

    final Map<dynamic, dynamic>? result =
        await _call<Map<dynamic, dynamic>>(
      'requestDataDeletion',
      data: <String, dynamic>{'reason': reasonText},
    );

    if (result == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exclusão agendada. Você tem '
          '${result['graceDays']} dias para cancelar.',
        ),
      ),
    );
  }

  Future<void> _cancelDeletion() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar a exclusão?'),
        content: const Text(
          'Sua conta e os dados voltam a ficar exatamente como estavam. '
          'Nada foi apagado ainda.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar exclusão'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) return;

    final Map<dynamic, dynamic>? result =
        await _call<Map<dynamic, dynamic>>('cancelDataDeletion');

    if (result == null || !mounted) return;

    // Não precisa invalidar nada manualmente: currentUserProvider já é um
    // listener ao vivo do documento do usuário — assim que a Function
    // apaga `deletionScheduledFor`, esta tela recebe o snapshot novo
    // sozinha e o card de exclusão pendente desaparece.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exclusão cancelada.')),
    );
  }

  Future<void> _revoke(String purpose, String label) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Revogar "$label"?'),
        content: const Text(
          'O tratamento com essa finalidade para imediatamente. Você pode '
          'autorizar de novo quando quiser.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    await _call<Map<dynamic, dynamic>>(
      'revokeConsent',
      data: <String, dynamic>{'purpose': purpose},
    );

    if (mounted) ref.invalidate(currentUserProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> manifest =
        ref.watch(privacyManifestProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidade e dados'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: manifest.when(
        loading: () => const LoadingState(),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.privacy_tip_outlined,
          title: 'Não foi possível carregar',
          message: 'Tente novamente em instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(privacyManifestProvider),
        ),
        data: (Map<String, dynamic> data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            ContentBounds(
              maxWidth: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Intro(),

                  const SectionHeader(
                    title: 'Seus direitos',
                    eyebrow: 'LGPD, Art. 18',
                  ),
                  Card(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: const Text('Baixar meus dados'),
                          subtitle: const Text(
                            'Arquivo estruturado com tudo o que guardamos',
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: _busy ? null : _export,
                        ),
                        const Divider(height: 1),
                        Builder(
                          builder: (BuildContext context) {
                            final DateTime? scheduledFor = ref
                                .watch(currentUserProvider)
                                ?.deletionScheduledFor;

                            if (scheduledFor == null) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                ),
                                title: const Text('Excluir minha conta'),
                                subtitle: const Text(
                                  'Com 15 dias para voltar atrás',
                                ),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: _busy ? null : _requestDeletion,
                              );
                            }

                            // Exclusão já agendada: o painel de "excluir"
                            // some — não faz sentido oferecer pedir de novo
                            // — e vira um aviso destacado com o único botão
                            // que importa agora.
                            return Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.08),
                                  borderRadius: AppRadius.lgAll,
                                  border: Border.all(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.event_busy_rounded,
                                          size: 20,
                                          color: AppColors.danger,
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                'Exclusão da conta agendada',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              Text(
                                                'Prevista para '
                                                '${Formatters.date(scheduledFor)}. '
                                                'Até lá, sua conta e seus '
                                                'dados continuam intactos e '
                                                'você pode desistir a '
                                                'qualquer momento.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    AppButton(
                                      label: 'Cancelar exclusão',
                                      variant: AppButtonVariant.outline,
                                      isLoading: _busy,
                                      onPressed:
                                          _busy ? null : _cancelDeletion,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader(
                    title: 'Autorizações',
                    eyebrow: 'O que você consentiu',
                  ),
                  _ConsentList(
                    manifest: data,
                    onRevoke: _revoke,
                  ),

                  const SectionHeader(
                    title: 'Com quem compartilhamos',
                    eyebrow: 'Transparência',
                  ),
                  _SharingList(manifest: data),

                  const SectionHeader(
                    title: 'Por quanto tempo guardamos',
                    eyebrow: 'Retenção',
                  ),
                  _RetentionCard(manifest: data),

                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Encarregado de dados: '
                    '${(data['controlador'] as Map<dynamic, dynamic>?)?['contatoEncarregado'] ?? '—'}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.petrol.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.child_care_rounded,
            size: 20,
            color: AppColors.petrol,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dados de criança têm proteção reforçada',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'O tratamento de dados de saúde de crianças exige '
                  'consentimento específico do responsável e só pode ocorrer '
                  'no melhor interesse da criança. Cada finalidade abaixo é '
                  'autorizada separadamente — e pode ser revogada.',
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

class _ConsentList extends ConsumerWidget {
  const _ConsentList({required this.manifest, required this.onRevoke});

  final Map<String, dynamic> manifest;
  final void Function(String purpose, String label) onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    final Map<dynamic, dynamic> purposes =
        (manifest['finalidades'] as Map<dynamic, dynamic>?) ??
            const <dynamic, dynamic>{};

    final Map<String, dynamic> granted =
        Map<String, dynamic>.from(
      (ref.watch(currentUserProvider)?.consentPurposes) ??
          const <String, dynamic>{},
    );

    return Card(
      child: Column(
        children: <Widget>[
          for (final MapEntry<dynamic, dynamic> entry in purposes.entries)
            Builder(
              builder: (BuildContext context) {
                final Map<dynamic, dynamic> config =
                    entry.value as Map<dynamic, dynamic>;
                final bool isRequired = config['required'] == true;
                final bool isGranted =
                    isRequired || granted[entry.key] == true;

                return ListTile(
                  title: Text(
                    config['label']?.toString() ?? '',
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          config['description']?.toString() ?? '',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppTag(
                          label: isRequired
                              ? 'Indispensável'
                              : isGranted
                                  ? 'Autorizado'
                                  : 'Não autorizado',
                          color: isRequired
                              ? AppColors.inkMuted
                              : isGranted
                                  ? AppColors.success
                                  : AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  trailing: isRequired || !isGranted
                      ? null
                      : TextButton(
                          onPressed: () => onRevoke(
                            entry.key.toString(),
                            config['label']?.toString() ?? '',
                          ),
                          child: const Text('Revogar'),
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SharingList extends StatelessWidget {
  const _SharingList({required this.manifest});

  final Map<String, dynamic> manifest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<dynamic> sharing =
        (manifest['compartilhamento'] as List<dynamic>?) ?? const <dynamic>[];

    return Card(
      child: Column(
        children: <Widget>[
          for (final dynamic item in sharing)
            Builder(
              builder: (BuildContext context) {
                final Map<dynamic, dynamic> s = item as Map<dynamic, dynamic>;
                return ListTile(
                  title: Text(
                    s['destinatario']?.toString() ?? '',
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s['finalidade']?.toString() ?? '',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (s['observacao'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              s['observacao'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: AppTag(label: s['pais']?.toString() ?? ''),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({required this.manifest});

  final Map<String, dynamic> manifest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<dynamic, dynamic> retention =
        (manifest['retencao'] as Map<dynamic, dynamic>?) ??
            const <dynamic, dynamic>{};

    const Map<String, String> labels = <String, String>{
      'contaAtiva': 'Enquanto a conta existir',
      'aposExclusao': 'Depois do pedido de exclusão',
      'prontuario': 'Prontuário médico',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final MapEntry<String, String> entry in labels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.value, style: theme.textTheme.labelMedium),
                    Text(
                      retention[entry.key]?.toString() ?? '—',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
