import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_providers.dart';

/// Edição de perfil.
///
/// ## O que é editável e o que não é — e por quê
///
/// Nome, telefone e especialidade são preferência do usuário: ele erra ao
/// digitar, muda de área de atuação, quer trocar o telefone — nada disso
/// exige verificação de ninguém.
///
/// Papel, CRM e status de verificação **não têm campo aqui**, nem
/// desabilitado — simplesmente não existe caminho na tela para editá-los.
/// CRM é o dado que a equipe conferiu manualmente para liberar prescrição;
/// se o próprio usuário pudesse reescrevê-lo, a verificação não significaria
/// nada. Esconder um botão não é segurança — por isso a proteção real está
/// em `updateProfile` (camada de dados) e nas regras do Firestore, não
/// apenas nesta tela. Aqui, a ausência do campo é só a primeira camada.
///
/// ## Sem foto
///
/// `image_picker` foi removido do projeto por não ter consumidor real.
/// Oferecer um botão de "trocar foto" sem upload funcional seria
/// exatamente a interface falsa que o produto decidiu evitar.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  String? _specialty;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _hydrate(AppUser user) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = user.name;
    _phone.text = user.phone ?? '';
    if (user.role == UserRole.professional) {
      _specialty = professionalSpecialties.contains(user.specialty)
          ? user.specialty
          : null;
    }
  }

  Future<void> _save(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final Result<AppUser> result =
        await ref.read(updateProfileProvider).call(
              UpdateProfileParams(
                name: _name.text,
                // Campo vazio precisa **limpar** o telefone, não deixar
                // como estava — por isso manda string vazia, não null,
                // quando o usuário apaga tudo.
                phone: _phone.text.trim(),
                specialty:
                    user.role == UserRole.professional ? _specialty : null,
              ),
            );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Perfil atualizado.')),
          );
        Navigator.of(context).pop();
      },
      (Failure failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.danger,
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _hydrate(user);
    final bool isProfessional = user.role == UserRole.professional;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
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
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.avatarFor(user.uid),
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              user.initials,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Nome',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.name,
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Telefone',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: Masks.phone,
                    prefixIcon: Icons.phone_outlined,
                    helper: 'Opcional',
                  ),
                  if (isProfessional) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      value: _specialty,
                      decoration: const InputDecoration(
                        labelText: 'Área de atuação',
                        prefixIcon:
                            Icon(Icons.local_hospital_outlined, size: 20),
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
                          setState(() => _specialty = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ReadOnlyField(
                      label: 'Registro profissional (CRM/COREN)',
                      value: user.crm ?? '—',
                      trailing: AppTag(
                        label: user.professionalVerified
                            ? 'Verificado'
                            : 'Em análise',
                        color: user.professionalVerified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      note: 'Conferido manualmente pela equipe. Para '
                          'corrigir, fale com o suporte — não é editável '
                          'aqui.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Salvar alterações',
                    isLoading: _saving,
                    onPressed: () => _save(user),
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

/// Campo mostrado, não editável — para que a informação apareça sem
/// oferecer um caminho de edição que não deveria existir.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.note,
    this.trailing,
  });

  final String label;
  final String value;
  final String note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
