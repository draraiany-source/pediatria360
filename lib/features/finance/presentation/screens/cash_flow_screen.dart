import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../domain/finance_aggregators.dart';
import '../providers/finance_providers.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CashFlowSeries series = ref.watch(financeCashFlowProvider);
    final List<CashFlowBucket> buckets = series.buckets;

    return Scaffold(
      appBar: AppBar(title: const Text('Fluxo de caixa')),
      body: buckets.isEmpty
          ? const Center(child: Text('Sem movimentacao no periodo.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: <LineChartBarData>[
                        LineChartBarData(
                          spots: <FlSpot>[
                            for (int i = 0; i < buckets.length; i++)
                              FlSpot(i.toDouble(), buckets[i].cumulative / 100.0),
                          ],
                          isCurved: true,
                          color: AppColors.brand,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...buckets.map(
                  (CashFlowBucket b) => ListTile(
                    title: Text(b.label),
                    subtitle: Text(
                      'Entrada ${formatCents(b.inflows)} 뿯½ '
                      'Saida ${formatCents(b.outflows)}',
                    ),
                    trailing: Text(formatCents(b.periodBalance)),
                  ),
                ),
              ],
            ),
    );
  }
}
