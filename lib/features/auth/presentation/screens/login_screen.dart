import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
  }

  Future<void> _google() =>
      ref.read(authControllerProvider.notifier).signInWithGoogle();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthActionState state = ref.watch(authControllerProvider);

    ref.listen<AuthActionState>(authControllerProvider,
        (AuthActionState? previous, AuthActionState next) {
      if (next.failure != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(next.failure!.message)),
          );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -20,
            left: -10,
            child: Icon(
              Icons.favorite_rounded,
              size: 56,
              color: AppColors.brand.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 40,
            right: 24,
            child: Icon(
              Icons.add_box_outlined,
              size: 48,
              color: AppColors.teal.withValues(alpha: 0.12),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: ContentBounds(
                  maxWidth: 440,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            SvgPicture.asset(
                              AppAssets.iconLogo,
                              width: 48,
                              height: 48,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text.rich(
                                    TextSpan(
                                      children: <TextSpan>[
                                        TextSpan(
                                          text: 'Pediatria',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '360',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            color: AppColors.teal,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Cuidado integral, cada fase importa',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Bem-vinda!',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Faça login para acessar o cuidado completo '
                          'do seu pequeno.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
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
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.password,
                          ],
                          validator: (String? v) =>
                              (v == null || v.isEmpty)
                                  ? 'Informe sua senha.'
                                  : null,
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brand,
                            ),
                            onPressed: () =>
                                context.pushNamed(Routes.forgotPasswordName),
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Entrar',
                          isLoading: state.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: <Widget>[
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                'ou',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SecondaryButton(
                          label: 'Criar conta',
                          onPressed: state.isLoading
                              ? null
                              : () => context.pushNamed(Routes.registerName),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: BorderSide(
                              color: AppColors.line,
                            ),
                            minimumSize: const Size(64, 48),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.pillAll,
                            ),
                          ),
                          onPressed: state.isLoading ? null : _google,
                          icon: SvgPicture.asset(
                            AppAssets.iconGoogle,
                            width: 18,
                            height: 18,
                          ),
                          label: const Text('Continuar com Google'),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Center(
                          child: Image.asset(
                            AppAssets.illustLoginToys,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.toys_outlined,
                              size: 72,
                              color: AppColors.brand.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        Text(
                          'Cuidado pediátrico com carinho e precisão.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
