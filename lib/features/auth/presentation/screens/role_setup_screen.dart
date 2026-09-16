import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../providers/auth_providers.dart';
import '../widgets/consent_sheet.dart';

/// Perfil inicial. Define o que o usuario vera no app inteiro — por isso vem
/// antes de qualquer outra tela autenticada e nao pode ser pulado.
class RoleSetupScreen extends ConsumerStatefulWidget {
  const RoleSetupScreen({super.key});

  @override
  ConsumerState<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends ConsumerState<RoleSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _crm = TextEditingController();

  UserRole _role = UserRole.parent;
  String _specialty = professionalSpecialties.first;

  bool get _isProfessional => _role == UserRole.professional;

  @override
  void dispose() {
    _crm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isProfessional && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // O consentimento é exigido aqui, não na tela de cadastro de e-mail:
    // é só neste ponto que existe uma conta autenticada de verdade — e
    // `recordConsent` precisa de um uid para gravar a quem pertence o
    // aceite. "Conclusão do cadastro" é exatamente este passo seguinte,
    // `completeOnboarding`, e é isso que fica bloqueado sem o aceite.
    final bool consented = await showConsentSheet(context, ref);
    if (!consented || !mounted) return;

    await ref.read(authControllerProvider.notifier).completeOnboarding(
          role: _role,
          crm: _isProfessional ? _crm.text : null,
          specialty: _isProfessional ? _specialty : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthActionState state = ref.watch(authControllerProvider);
    final AppUser? user = ref.watch(currentUserProvider);

    ref.listen<AuthActionState>(authControllerProvider,
        (AuthActionState? previous, AuthActionState next) {
      if (next.failure != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ContentBounds(
            maxWidth: 520,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    user == null
                        ? 'Como voce usa o app?'
                        : 'Ola, ${user.firstName}. Como voce usa o app?',
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Isso define o conteudo que aparece para voce. Da para '
                    'mudar depois nos ajustes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _RoleOption(
                    icon: Icons.family_restroom_rounded,
                    title: 'Sou pai, mae ou responsavel',
                    body: 'Acompanhamento de crescimento, vacinas, sono, '
                        'amamentacao e a IA para tirar duvidas do dia a dia.',
                    color: AppColors.petrol,
                    selected: _role == UserRole.parent,
                    onTap: () => setState(() => _role = UserRole.parent),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RoleOption(
                    icon: Icons.medical_services_outlined,
                    title: 'Sou profissional de saude',
                    body: 'Protocolos clinicos, calculadoras de dose, '
                        'interpretacao de exames e telemedicina.',
                    color: AppColors.raspberry,
                    selected: _isProfessional,
                    onTap: () =>
                        setState(() => _role = UserRole.professional),
                  ),
                  if (_isProfessional) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: 'Registro profissional (CRM ou COREN)',
                      controller: _crm,
                      hint: '123456/SP',
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.characters,
                      validator: Validators.crm,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      value: _specialty,
                      decoration: const InputDecoration(
                        labelText: 'Area de atuacao',
                        prefixIcon: Icon(Icons.local_hospital_outlined, size: 20),
                      ),
                      items: professionalSpecialties
                          .map(
                            (String s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) =>
                          setState(() => _specialty = value ?? _specialty),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Conferimos o registro em ate 2 dias uteis. '
                              'Ate la, o conteudo de prescricao fica '
                              'bloqueado — o resto do app ja libera.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Continuar',
                    isLoading: state.isLoading,
                    onPressed: _submit,
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

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: selected ? color : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
