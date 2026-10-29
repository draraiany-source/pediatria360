import 'package:fl_chart/fl_chart.dart';
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
import '../widgets/bi_chart_card.dart';
import '../widgets/bi_empty_state.dart';
import '../widgets/bi_kpi_tile.dart';

class BiOpsScreen extends ConsumerWidget {
  const BiOpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = BiAccess.canSeeOps(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('BI Operacional')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para indicadores operacionais.'),
        ),
      );
    }

    final BiAgendaStats agenda = ref.watch(executiveSnapshotProvider).agenda;
    final Map<int, int> peaks = agenda.peakHoursHistogram;

    final List<BiKpiCardData> cards = <BiKpiCardData>[
      BiKpiCardData(
        id: 'occupancy',
        title: 'Ocupacao',
        valueLabel: '${(agenda.occupancyRate * 100).toStringAsFixed(0)}%',
        rawValue: agenda.occupancyRate,
        category: BiKpiCategory.ops,
        drillRoute: Routes.agendaPath,
      ),
      BiKpiCardData(
        id: 'cancelled',
        title: 'Cancelamentos',
        valueLabel: '${agenda.cancelled}',
        rawValue: agenda.cancelled,
        category: BiKpiCategory.ops,
        drillRoute: Routes.agendaPath,
      ),
      BiKpiCardData(
        id: 'rescheduled',
        title: 'Remarcacoes',
        valueLabel: '${agenda.rescheduled}',
        rawValue: agenda.rescheduled,
        category: BiKpiCategory.ops,
        drillRoute: Routes.agendaPath,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('BI Operacional'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.2,
            children: cards
                .map((BiKpiCardData d) => BiKpiTile(data: d))
                .toList(growable: false),
          ),
          if (agenda.rescheduleNote != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                agenda.rescheduleNote!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (peaks.isEmpty)
            const BiEmptyState(
              title: 'Sem dados de horario no periodo',
              subtitle: 'Agende consultas para ver o histograma de picos.',
            )
          else
            BiChartCard(
              title: 'Picos por hora',
              subtitle: 'Consultas no periodo selecionado',
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: peaks.values.reduce((int a, int b) => a > b ? a : b).toDouble() + 1,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int h = value.toInt();
                          if (!peaks.containsKey(h)) return const SizedBox.shrink();
                          return Text('${h}h', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: peaks.entries
                      .map(
                        (MapEntry<int, int> e) => BarChartGroupData(
                          x: e.key,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: e.value.toDouble(),
                              color: AppColors.brand,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          QuickAccessCard(
            label: 'Agenda',
            subtitle: 'Calendario completo',
            icon: Icons.calendar_month,
            color: AppColors.brand,
            wide: true,
            onTap: () => context.go(Routes.agendaPath),
          ),
        ],
      ),
    );
  }
}
