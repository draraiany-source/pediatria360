import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Forca da senha (0..1). Serve so de retorno visual — a regra que barra o
  /// envio continua sendo a do `Validators.password`.
  double get _strength {
    final String value = _password.text;
    if (value.isEmpty) return 0;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^\w\s]').hasMatch(value)) score++;
    return score / 5;
  }

  Color get _strengthColor => switch (_strength) {
        < 0.4 => AppColors.danger,
        < 0.7 => AppColors.warning,
        _ => AppColors.success,
      };

  String get _strengthLabel => switch (_strength) {
        0 => '',
        < 0.4 => 'Senha fraca',
        < 0.7 => 'Senha razoavel',
        _ => 'Senha forte',
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref.read(authControllerProvider.notifier).signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthActionState state = ref.watch(authControllerProvider);

    ref.listen<AuthActionState>(authControllerProvider,
        (AuthActionState? previous, AuthActionState next) {
      if (next.failure != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    final bool isDark = theme.brightness == Brightness.dark;
    final Color scaffoldBg = isDark
        ? AppColors.darkBackground
        : theme.colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.violetSoft : null,
          ),
          tooltip: 'Voltar',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentBounds(
            maxWidth: 440,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Criar conta',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: isDark ? AppColors.darkInk : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Leva menos de um minuto.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkInkMuted
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Nome completo',
                    controller: _name,
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    validator: Validators.name,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'E-mail',
                    controller: _email,
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Senha',
                    controller: _password,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscure: true,
                    helper: 'Pelo menos 8 caracteres, com letras e numeros.',
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    validator: Validators.password,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_password.text.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillAll,
                            child: LinearProgressIndicator(
                              value: _strength,
                              minHeight: 4,
                              color: _strengthColor,
                              backgroundColor: isDark
                                  ? AppColors.darkLine
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          _strengthLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _strengthColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Confirmar senha',
                    controller: _confirm,
                    prefixIcon: Icons.lock_reset_rounded,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    validator: (String? v) =>
                        Validators.confirmPassword(v, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // O aceite de verdade — registrado, com data e versão —
                  // acontece na próxima tela, onde já existe conta
                  // autenticada. Aqui era só um booleano local que nunca
                  // chegava a lugar nenhum.
                  Text(
                    'No próximo passo você vai revisar e aceitar os Termos '
                    'de Uso e a Política de Privacidade.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkInkMuted
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Criar conta',
                    isLoading: state.isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'O Pediatria 360 e uma ferramenta de apoio e educacao. '
                    'Ele nao faz diagnostico nem substitui a consulta com um '
                    'pediatra.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkInkMuted : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
