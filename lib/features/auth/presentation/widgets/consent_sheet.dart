import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Uma finalidade de tratamento opcional, apresentada com destaque próprio.
///
/// Estático aqui em vez de buscado do servidor: o texto precisa aparecer
/// **antes** de qualquer chamada de rede, no momento em que o cadastro ainda
/// está sendo concluído. `dataProcessingManifest` (já existente para a tela
/// de privacidade) faria uma viagem de rede extra só para mostrar o mesmo
/// texto que já está aqui — sincronizado manualmente com
/// `CONSENT_PURPOSES` do lado do servidor, que é quem de fato valida.
class _OptionalPurpose {
  const _OptionalPurpose({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;
}

const List<_OptionalPurpose> _optionalPurposes = <_OptionalPurpose>[
  _OptionalPurpose(
    key: 'aiAssistance',
    label: 'Assistente com inteligência artificial',
    description: 'Enviar o conteúdo das perguntas e do prontuário a um '
        'provedor de IA para gerar respostas e resumos.',
  ),
  _OptionalPurpose(
    key: 'professionalSharing',
    label: 'Compartilhamento com profissional de saúde',
    description: 'Permitir que o pediatra que atende a criança acesse o '
        'prontuário dela.',
  ),
  _OptionalPurpose(
    key: 'marketing',
    label: 'Comunicações sobre novidades',
    description: 'Receber e-mails sobre conteúdos e recursos da plataforma.',
  ),
];

/// Resultado do painel: `true` se o consentimento foi registrado no
/// servidor, `false`/`null` se o usuário fechou sem concluir.
///
/// ## Por que isto é modal e não uma etapa que se pula
///
/// "Bloqueio da conclusão do cadastro sem aceite obrigatório" só é real se
/// não existir caminho para contornar — por isso o painel não tem botão de
/// "Agora não" para os itens obrigatórios, só para fechar o painel inteiro
/// (o que deixa o cadastro incompleto, não avança).
///
/// ## Por que chama o servidor aqui, não guarda local e envia depois
///
/// Um booleano local que "parece" aceite e nunca chega ao servidor é
/// exatamente o problema que esta tela resolve — a versão anterior fazia
/// isso. O aceite só conta quando `recordConsent` responde com sucesso.
Future<bool> showConsentSheet(BuildContext context, WidgetRef ref) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: false,
    useSafeArea: true,
    builder: (BuildContext context) => const _ConsentSheet(),
  );
  return result ?? false;
}

class _ConsentSheet extends ConsumerStatefulWidget {
  const _ConsentSheet();

  @override
  ConsumerState<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends ConsumerState<_ConsentSheet> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  final Map<String, bool> _optional = <String, bool>{
    for (final _OptionalPurpose p in _optionalPurposes) p.key: false,
  };

  bool _submitting = false;
  String? _error;

  bool get _canContinue => _acceptedTerms && _acceptedPrivacy && !_submitting;

  Future<void> _openDocument(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirm() async {
    if (!_canContinue) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final Result<void> result = await guard(() async {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('recordConsent')
          .call(<String, dynamic>{
        'purposes': <String, dynamic>{
          // Obrigatória: o app não funciona sem registrar dado de saúde.
          // Não é uma escolha oferecida, por isso não tem toggle acima —
          // mas o servidor a exige explicitamente mesmo assim.
          'healthRecord': true,
          ..._optional,
        },
        'termsAccepted': _acceptedTerms,
        'privacyPolicyAccepted': _acceptedPrivacy,
      });
    });

    if (!mounted) return;

    result.fold(
      (_) => Navigator.of(context).pop(true),
      (Failure failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scroll) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Antes de continuar', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'O Pediatria 360 trata dado de saúde de crianças. A lei '
                  'exige que você saiba exatamente o que autoriza, e possa '
                  'escolher o que é opcional.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: <Widget>[
                Text(
                  'OBRIGATÓRIO',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.danger,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DocumentTile(
                  title: 'Termos de Uso',
                  article: 'os',
                  value: _acceptedTerms,
                  onChanged: (bool v) => setState(() => _acceptedTerms = v),
                  onOpen: () => _openDocument(AppConfig.termsOfServiceUrl),
                ),
                _DocumentTile(
                  title: 'Política de Privacidade',
                  article: 'a',
                  value: _acceptedPrivacy,
                  onChanged: (bool v) => setState(() => _acceptedPrivacy = v),
                  onOpen: () => _openDocument(AppConfig.privacyPolicyUrl),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Registrar medições, vacinas e atendimentos é a '
                          'razão do app existir — por isso não é opcional, '
                          'diferente dos itens abaixo.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'OPCIONAL — VOCÊ ESCOLHE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final _OptionalPurpose purpose in _optionalPurposes)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _optional[purpose.key] ?? false,
                    onChanged: (bool v) =>
                        setState(() => _optional[purpose.key] = v),
                    title: Text(purpose.label, style: theme.textTheme.titleSmall),
                    subtitle: Text(
                      purpose.description,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Text(_error!, style: theme.textTheme.bodySmall),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: AppButton(
              label: 'Aceitar e continuar',
              isLoading: _submitting,
              onPressed: _canContinue ? _confirm : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.article,
    required this.value,
    required this.onChanged,
    required this.onOpen,
  });

  final String title;

  /// "os" para Termos de Uso (masculino plural), "a" para Política de
  /// Privacidade (feminino singular) — um artigo fixo só acertaria um
  /// dos dois.
  final String article;

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: (bool? v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Li e aceito $article $title',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            tooltip: 'Abrir $title',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
