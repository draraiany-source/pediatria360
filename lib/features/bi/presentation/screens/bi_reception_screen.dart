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
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/bi_access.dart';
import '../../domain/bi_models.dart';
import '../providers/bi_providers.dart';
import '../widgets/bi_kpi_tile.dart';

class BiReceptionScreen extends ConsumerWidget {
  const BiReceptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = BiAccess.canSeeOps(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('BI Recepcao')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para indicadores de recepcao.'),
        ),
      );
    }

    final BiReceptionStats reception =
        ref.watch(executiveSnapshotProvider).reception;

    final List<BiKpiCardData> cards = <BiKpiCardData>[
      BiKpiCardData(
        id: 'waiting',
        title: 'Aguardando',
        valueLabel: '${reception.waitingNow}',
        rawValue: reception.waitingNow,
        category: BiKpiCategory.reception,
        drillRoute: Routes.clinicReceptionPath,
      ),
      BiKpiCardData(
        id: 'triage',
        title: 'Em triagem',
        valueLabel: '${reception.inTriage}',
        rawValue: reception.inTriage,
        category: BiKpiCategory.reception,
        drillRoute: Routes.clinicReceptionPath,
      ),
      BiKpiCardData(
        id: 'avg_wait',
        title: 'Espera media (min)',
        valueLabel: reception.avgWaitMinutes.toStringAsFixed(0),
        rawValue: reception.avgWaitMinutes,
        category: BiKpiCategory.reception,
        drillRoute: Routes.clinicReceptionPath,
      ),
      BiKpiCardData(
        id: 'delays',
        title: 'Atrasos (+15 min)',
        valueLabel: '${reception.delayedArrivals}',
        rawValue: reception.delayedArrivals,
        category: BiKpiCategory.reception,
        drillRoute: Routes.clinicReceptionPath,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('BI Recepcao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            'Chegadas hoje: ${reception.arrivedToday}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.35,
            children: cards
                .map((BiKpiCardData d) => BiKpiTile(data: d))
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.xl),
          QuickAccessCard(
            label: 'Recepcao ao vivo',
            subtitle: 'Fila e check-in',
            icon: Icons.how_to_reg_rounded,
            color: AppColors.teal,
            wide: true,
            onTap: () => context.push(Routes.clinicReceptionPath),
          ),
        ],
      ),
    );
  }
}
