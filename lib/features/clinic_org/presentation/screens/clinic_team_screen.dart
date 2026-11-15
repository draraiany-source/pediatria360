import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_intake/presentation/clinic_intake_providers.dart';
import '../../data/clinic_team_repository.dart';
import '../providers/clinic_org_providers.dart';

/// Equipe da clínica: a gestão inclui contas existentes por e-mail, troca
/// papel e desativa. Recepção e financeiro entram sem registro profissional.
/// O papel de gestor não abre prontuário: o acesso clínico continua
/// dependendo da autorização do responsável, criança por criança.
class ClinicTeamScreen extends ConsumerWidget {
  const ClinicTeamScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, String clinicId) async {
    final TextEditingController email = TextEditingController();
    ClinicRole role = ClinicRole.receptionist;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter set) => AlertDialog(
          title: const Text('Incluir na equipe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const Key('team-email'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail da conta no app',
                  helperText: 'A pessoa precisa ter criado a conta antes.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ClinicRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Papel'),
                items: <DropdownMenuItem<ClinicRole>>[
                  for (final ClinicRole r in kAssignableClinicRoles)
                    DropdownMenuItem<ClinicRole>(value: r, child: Text(r.label)),
                ],
                onChanged: (ClinicRole? r) => set(() => role = r ?? role),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Incluir'),
            ),
          ],
        ),
      ),
    );
    final String typed = email.text;
    email.dispose();
    if (ok != true) return;
    final Result<void> r = await ref
        .read(clinicTeamRepositoryProvider)
        .addMember(clinicId: clinicId, email: typed, role: role);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.fold((_) => 'Equipe atualizada.', (Failure f) => f.message))),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String clinicId,
    ClinicTeamMember m,
  ) async {
    final Result<void> r = await ref.read(clinicTeamRepositoryProvider).setStatus(
          clinicId: clinicId,
          membershipId: m.membershipId,
          active: !m.active,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.fold((_) => m.active ? 'Acesso desativado.' : 'Acesso reativado.',
              (Failure f) => f.message),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? me = ref.watch(activeClinicMembershipProvider);
    final String? uid = ref.watch(currentUserProvider)?.uid;
    if (me == null || me.role != ClinicRole.clinicAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equipe')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Só a gestão da clínica',
          message: 'Peça ao gestor da clínica para alterar a equipe.',
        ),
      );
    }
    final AsyncValue<List<ClinicTeamMember>> async =
        ref.watch(clinicTeamProvider(me.clinicId));

    return Scaffold(
      appBar: AppBar(title: Text('Equipe · ${me.clinicName}')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('team-add'),
        onPressed: () => _add(context, ref, me.clinicId),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Incluir'),
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando equipe...'),
        error: (Object e, StackTrace st) => ErrorState(
          failure: e is Failure ? e : ServerFailure(e.toString()),
        ),
        data: (List<ClinicTeamMember> members) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
          children: <Widget>[
            const InfoBanner(
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.violet,
              text: 'Recepção: agenda, solicitações e check-in, sem prontuário. '
                  'Financeiro: cobranças e pagamentos, sem prontuário. Papéis '
                  'clínicos atendem só crianças cujo responsável autorizou. '
                  'Gestão organiza a equipe e não lê prontuários.',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final ClinicTeamMember m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SurfaceCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.userId == uid
                                  ? 'Você'
                                  : (m.name.isEmpty ? 'Membro da equipe' : m.name),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              <String>[m.role.label, if (m.specialty.isNotEmpty) m.specialty]
                                  .join(' · '),
                            ),
                          ],
                        ),
                      ),
                      AppTag(
                        label: m.active ? 'Ativo' : 'Inativo',
                        color: m.active ? AppColors.success : AppColors.inkMuted,
                      ),
                      if (m.userId != uid)
                        IconButton(
                          tooltip: m.active ? 'Desativar' : 'Reativar',
                          onPressed: () => _toggle(context, ref, me.clinicId, m),
                          icon: Icon(m.active ? Icons.person_off_outlined : Icons.person_outline),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
