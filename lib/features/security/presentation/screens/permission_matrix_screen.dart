import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../domain/permission_matrix.dart';
import '../../domain/security_access.dart';
import '../widgets/unauthorized_access_view.dart';

/// Matriz read-only para administradores (FASE 8 — nice to have).
class PermissionMatrixScreen extends ConsumerWidget {
  const PermissionMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeClinicMembershipProvider);
    if (!SecurityAccess.canViewPermissionMatrix(
      user: user,
      clinicMembership: membership,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permissoes')),
        body: const UnauthorizedAccessView(module: PermissionModule.users),
      );
    }

    final ClinicRole previewRole = membership?.role ?? ClinicRole.physician;
    final AppUser previewUser = user ??
        AppUser(
          uid: 'preview',
          email: '',
          name: 'Preview',
          role: UserRole.professional,
          plan: UserPlan.pro,
          createdAt: DateTime.now(),
          professionalVerified: true,
        );

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Matriz de permissoes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            'Papel ativo: ${PlatformProfileLabel.displayForMembership(membership)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Modulo')),
                DataColumn(label: Text('Ver')),
                DataColumn(label: Text('Criar')),
                DataColumn(label: Text('Editar')),
                DataColumn(label: Text('Exportar')),
                DataColumn(label: Text('Admin')),
              ],
              rows: PermissionModule.values.map((PermissionModule module) {
                final ClinicMembership m = membership ??
                    ClinicMembership(
                      id: 'p',
                      clinicId: 'c',
                      userId: previewUser.uid,
                      role: previewRole,
                      createdAt: DateTime.now(),
                    );
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(module.name)),
                    DataCell(_cell(
                      PermissionMatrix.allows(
                        user: previewUser,
                        membership: m,
                        module: module,
                        action: PermissionAction.view,
                      ),
                    )),
                    DataCell(_cell(
                      PermissionMatrix.allows(
                        user: previewUser,
                        membership: m,
                        module: module,
                        action: PermissionAction.create,
                      ),
                    )),
                    DataCell(_cell(
                      PermissionMatrix.allows(
                        user: previewUser,
                        membership: m,
                        module: module,
                        action: PermissionAction.edit,
                      ),
                    )),
                    DataCell(_cell(
                      PermissionMatrix.allows(
                        user: previewUser,
                        membership: m,
                        module: module,
                        action: PermissionAction.export,
                      ),
                    )),
                    DataCell(_cell(
                      PermissionMatrix.allows(
                        user: previewUser,
                        membership: m,
                        module: module,
                        action: PermissionAction.administer,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Aliases de perfil: ${PlatformProfileLabel.aliases.entries.map((MapEntry<String, String> e) => '${e.key}→${e.value}').join('; ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Widget _cell(bool allowed) => Icon(
        allowed ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: allowed ? AppColors.teal : AppColors.error,
        size: 20,
      );
}
