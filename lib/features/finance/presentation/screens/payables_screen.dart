import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'
    show activeClinicMembershipProvider;
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';

class PayablesScreen extends ConsumerWidget {
  const PayablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancePayable>> async =
        ref.watch(financePayablesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a pagar'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<FinancePayable> list) {
          if (list.isEmpty) {
            return const Center(child: Text('Nenhuma despesa cadastrada.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) {
              final FinancePayable p = list[i];
              return ListTile(
                title: Text(p.description),
                subtitle: Text('${p.category.label} 뿯½ ${p.status.label}'),
                trailing: Text(formatCents(p.openCents)),
                onTap: () => _markPaid(context, ref, p),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final TextEditingController desc = TextEditingController();
    final TextEditingController cents = TextEditingController();
    ExpenseCategory cat = ExpenseCategory.other;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Nova despesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descricao')),
            TextField(
              controller: cents,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Valor (centavos)'),
            ),
            DropdownButton<ExpenseCategory>(
              value: cat,
              isExpanded: true,
              items: ExpenseCategory.values
                  .map(
                    (ExpenseCategory c) => DropdownMenuItem<ExpenseCategory>(
                      value: c,
                      child: Text(c.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ExpenseCategory? v) {
                if (v != null) cat = v;
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    final int amount = int.tryParse(cents.text) ?? 0;
    if (amount <= 0) return;
    final FinancePayable p = FinancePayable(
      id: const Uuid().v4(),
      ownerId: uid,
      description: desc.text,
      category: cat,
      amountCents: amount,
      paidCents: 0,
      status: PayableStatus.pending,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );
    await ref.read(financeRepositoryProvider).createPayable(
          p,
          membership: ref.read(activeClinicMembershipProvider),
        );
    ref.invalidate(financePayablesProvider);
    desc.dispose();
    cents.dispose();
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    FinancePayable p,
  ) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await ref.read(financeRepositoryProvider).markPayablePaid(
          payable: p,
          amountCents: p.openCents,
          byUserId: uid,
        );
    ref.invalidate(financePayablesProvider);
  }
}
