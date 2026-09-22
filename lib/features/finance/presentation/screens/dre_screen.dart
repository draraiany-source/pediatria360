import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../domain/finance_aggregators.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';

class DreScreen extends ConsumerWidget {
  const DreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<FinanceReceivable> recv =
        ref.watch(financeReceivablesProvider).valueOrNull ??
            const <FinanceReceivable>[];
    final List<FinancePayable> pay =
        ref.watch(financePayablesProvider).valueOrNull ?? const <FinancePayable>[];
    final FinancePeriod period = ref.watch(financePeriodProvider);
    final DreReport dre = DreReport.build(
      receivables: recv,
      payables: pay,
      period: period,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('DRE')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          _row('Receita bruta', dre.grossRevenue),
          _row('Deducoes', dre.deductions),
          _row('Receita liquida', dre.netRevenue),
          _row('Custos', dre.costs),
          _row('Despesas', dre.expenses),
          const Divider(),
          _row('Resultado', dre.result, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, int cents, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : null)),
          Text(formatCents(cents), style: TextStyle(fontWeight: bold ? FontWeight.w800 : null)),
        ],
      ),
    );
  }
}
