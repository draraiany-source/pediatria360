import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';

class DelinquencyScreen extends ConsumerWidget {
  const DelinquencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = DateTime.now();
    final DateFormat fmt = DateFormat('dd/MM/yyyy');
    final AsyncValue<List<FinanceReceivable>> async =
        ref.watch(financeReceivablesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inadimplencia')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<FinanceReceivable> list) {
          final List<FinanceReceivable> overdue = list
              .where(
                (FinanceReceivable r) =>
                    r.effectiveStatus(now) == ReceivableStatus.overdue,
              )
              .toList(growable: false)
            ..sort((FinanceReceivable a, FinanceReceivable b) =>
                a.dueAt.compareTo(b.dueAt));
          if (overdue.isEmpty) {
            return const Center(child: Text('Nenhum titulo em atraso.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: overdue.length,
            itemBuilder: (BuildContext context, int i) {
              final FinanceReceivable r = overdue[i];
              final int daysLate = now.difference(r.dueAt).inDays;
              return ListTile(
                title: Text(r.description),
                subtitle: Text(
                  'Venceu ${fmt.format(r.dueAt)} 뿯½ $daysLate dia(s) 뿯½ '
                  '${formatCents(r.openCents)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.payment),
                  onPressed: () => context.push(
                    '${Routes.financePath}/receber?receivableId=${Uri.encodeComponent(r.id)}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
