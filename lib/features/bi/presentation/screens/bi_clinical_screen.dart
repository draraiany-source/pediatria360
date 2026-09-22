import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic/presentation/providers/clinic_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/bi_access.dart';
import '../../domain/bi_models.dart';
import '../providers/bi_providers.dart';
import '../widgets/bi_empty_state.dart';
import '../widgets/bi_kpi_tile.dart';

class BiClinicalScreen extends ConsumerWidget {
  const BiClinicalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = BiAccess.canSeeClinical(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('BI Clinico')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para indicadores clinicos.'),
        ),
      );
    }

    final snapshot = ref.watch(executiveSnapshotProvider);
    final int today =
        ref.watch(clinicDashboardStatsProvider).valueOrNull?.todayAppointments ??
            snapshot.todayAppointments ??
            0;
    final BiClinicalLite clinical = snapshot.clinical;

    final List<BiKpiCardData> cards = <BiKpiCardData>[
      BiKpiCardData(
        id: 'today_appts',
        title: 'Consultas hoje',
        valueLabel: '$today',
        rawValue: today,
        category: BiKpiCategory.clinical,
        drillRoute: Routes.agendaPath,
      ),
      BiKpiCardData(
        id: 'drafts',
        title: 'Rascunhos',
        valueLabel: '${clinical.openDrafts}',
        rawValue: clinical.openDrafts,
        category: BiKpiCategory.clinical,
        drillRoute: Routes.clinicPendingPath,
      ),
      BiKpiCardData(
        id: 'exams',
        title: 'Exames pendentes',
        valueLabel: '${clinical.pendingExams}',
        rawValue: clinical.pendingExams,
        category: BiKpiCategory.clinical,
        drillRoute: Routes.clinicPendingPath,
      ),
      BiKpiCardData(
        id: 'vaccines',
        title: 'Vacinas em atraso',
        valueLabel: '${clinical.vaccinesOverdue}',
        rawValue: clinical.vaccinesOverdue,
        category: BiKpiCategory.clinical,
        drillRoute: Routes.clinicPendingPath,
        drillQuery: const <String, String>{'focus': 'vaccines'},
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('BI Clinico'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            BiClinicalLite.disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.35,
            children: cards.map(BiKpiTile.new).toList(growable: false),
          ),
          if (snapshot.development.recordCount == 0 &&
              snapshot.growth.assessmentCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: BiEmptyState(
                title: 'Cohortes de crescimento/desenvolvimento vazias',
                subtitle:
                    'Agregacao clinic-wide depende de listas fornecidas; '
                    'sem dados cruzados no provider.',
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          QuickAccessCard(
            label: 'Pacientes',
            subtitle: 'Carteira clinica',
            icon: Icons.groups_outlined,
            color: AppColors.brand,
            wide: true,
            onTap: () => context.go(Routes.patientsPath),
          ),
          const SizedBox(height: AppSpacing.sm),
          QuickAccessCard(
            label: 'Central de pendencias',
            subtitle: 'Retornos, vacinas e exames',
            icon: Icons.inbox_outlined,
            color: AppColors.warning,
            wide: true,
            onTap: () => context.push(Routes.clinicPendingPath),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(BiNeuropedStub.message),
            ),
          ),
        ],
      ),
    );
  }
}
