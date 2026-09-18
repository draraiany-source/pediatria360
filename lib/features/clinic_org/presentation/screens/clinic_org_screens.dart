import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/clinic_org_providers.dart';

/// Hub: listar memberships, selecionar clinica ativa ou criar nova.
class ClinicOrgHubScreen extends ConsumerWidget {
  const ClinicOrgHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ClinicMembership>> membershipsAsync =
        ref.watch(myClinicMembershipsProvider);
    final AsyncValue<String?> activeIdAsync = ref.watch(activeClinicIdProvider);
    final AsyncValue<ClinicOrganization?> activeClinicAsync =
        ref.watch(activeClinicProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Minha clinica'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.clinicOrgCreatePath),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Nova clinica'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            'Contexto da organizacao',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Selecione a clinica ativa. Dados legados continuam funcionando '
            'mesmo sem clinica vinculada.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          activeClinicAsync.when(
            loading: () => const LoadingState(label: 'Carregando clinica...'),
            error: (Object e, StackTrace _) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Nao conseguimos carregar a clinica ativa.'),
                  TextButton(
                    onPressed: () => ref.invalidate(activeClinicProvider),
                    child: const Text('Recarregar'),
                  ),
                ],
              ),
            ),
            data: (ClinicOrganization? clinic) {
              if (clinic == null) {
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Nenhuma clinica ativa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Crie sua clinica para habilitar isolamento '
                        'multitenant, unidades e equipe.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Criar clinica',
                        icon: Icons.add_business_rounded,
                        expanded: false,
                        onPressed: () =>
                            context.push(Routes.clinicOrgCreatePath),
                      ),
                    ],
                  ),
                );
              }
              return AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Clinica ativa',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.inkMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            clinic.tradeName.isNotEmpty
                                ? clinic.tradeName
                                : clinic.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (clinic.cnpj.isNotEmpty)
                            Text(
                              'CNPJ ${clinic.cnpj}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const BrandSectionHeader(title: 'Minhas clinicas'),
          const SizedBox(height: AppSpacing.sm),
          membershipsAsync.when(
            loading: () => const LoadingState(),
            error: (Object e, StackTrace _) => Text('$e'),
            data: (List<ClinicMembership> list) {
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'Sem clinicas ainda',
                  message:
                      'Crie a primeira clinica para organizar agenda, '
                      'equipe e financeiro por tenant.',
                  icon: Icons.apartment_outlined,
                );
              }
              final String? activeId = activeIdAsync.valueOrNull;
              return Column(
                children: list.map((ClinicMembership m) {
                  final bool selected = m.clinicId == activeId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () async {
                        await ref
                            .read(activeClinicIdProvider.notifier)
                            .select(m.clinicId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Clinica ativa atualizada.'),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: <Widget>[
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected
                                ? AppColors.tealDeep
                                : AppColors.inkMuted,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  m.clinicName.isNotEmpty
                                      ? m.clinicName
                                      : m.clinicId,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  m.role.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const StatusChip(
                              label: 'Ativa',
                              tone: StatusChipTone.confirmed,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CreateClinicScreen extends ConsumerStatefulWidget {
  const CreateClinicScreen({super.key});

  @override
  ConsumerState<CreateClinicScreen> createState() => _CreateClinicScreenState();
}

class _CreateClinicScreenState extends ConsumerState<CreateClinicScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _trade = TextEditingController();
  final TextEditingController _cnpj = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _address = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _trade.dispose();
    _cnpj.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final String name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da clinica.')),
      );
      return;
    }
    setState(() => _saving = true);
    final Result<ClinicOrganization> res =
        await ref.read(clinicOrganizationRepositoryProvider).createClinic(
              clinic: ClinicOrganization(
                id: '',
                name: name,
                tradeName: _trade.text.trim(),
                cnpj: _cnpj.text.trim(),
                phone: _phone.text.trim(),
                email: _email.text.trim(),
                address: _address.text.trim(),
                createdAt: DateTime.now(),
              ),
              ownerUserId: uid,
            );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.isSuccess || res.valueOrNull == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel criar a clinica.')),
      );
      return;
    }
    await ref
        .read(activeClinicIdProvider.notifier)
        .select(res.valueOrNull!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clinica criada e definida como ativa.')),
    );
    context.go(Routes.clinicOrgPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Nova clinica'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const Text(
            'Cadastro inicial da organizacao. Voce sera o administrador '
            'da clinica.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Razao social / nome *',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _trade,
            decoration: const InputDecoration(labelText: 'Nome fantasia'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _cnpj,
            decoration: const InputDecoration(labelText: 'CNPJ'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Telefone / WhatsApp'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Endereco'),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Criar clinica',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
