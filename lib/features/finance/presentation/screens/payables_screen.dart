import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/state_views.dart';
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
            tooltip: 'Nova despesa',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => ErrorState(
          failure: ErrorMapper.map(e),
          onRetry: () => ref.invalidate(financePayablesProvider),
        ),
        data: (List<FinancePayable> list) {
          if (list.isEmpty) {
            return const Center(child: Text('Nenhuma despesa cadastrada.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) {
              final FinancePayable p = list[i];
              final bool open = p.openCents > 0 &&
                  p.status != PayableStatus.paid;
              return ListTile(
                title: Text(p.description),
                subtitle: Text(
                  '${p.category.label} • ${p.status.label} • '
                  'vence ${_date(p.dueAt)}',
                ),
                trailing: Text(formatCents(p.openCents)),
                onTap: open ? () => _markPaid(context, ref, p) : null,
              );
            },
          );
        },
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final TextEditingController desc = TextEditingController();
    final TextEditingController cents = TextEditingController();
    ExpenseCategory cat = ExpenseCategory.other;
    DateTime dueAt = DateTime.now().add(const Duration(days: 30));
    String? error;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: const Text('Nova despesa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: cents,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration:
                    const InputDecoration(labelText: 'Valor (centavos)'),
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
                  if (v != null) setLocal(() => cat = v);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vencimento'),
                subtitle: Text(_date(dueAt)),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueAt,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) setLocal(() => dueAt = picked);
                },
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final int amount = int.tryParse(cents.text) ?? 0;
                if (desc.text.trim().isEmpty || amount <= 0) {
                  setLocal(() => error = 'Informe descrição e valor maior que zero.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    final String description = desc.text.trim();
    final int amount = int.tryParse(cents.text) ?? 0;
    desc.dispose();
    cents.dispose();
    if (ok != true) return;
    final FinancePayable p = FinancePayable(
      id: const Uuid().v4(),
      ownerId: uid,
      description: description,
      category: cat,
      amountCents: amount,
      paidCents: 0,
      status: PayableStatus.pending,
      dueAt: dueAt,
      createdAt: DateTime.now(),
    );
    final Result<void> result =
        await ref.read(financeRepositoryProvider).createPayable(
              p,
              membership: ref.read(activeClinicMembershipProvider),
            );
    ref.invalidate(financePayablesProvider);
    if (!context.mounted) return;
    _feedback(context, result, 'Despesa cadastrada.');
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    FinancePayable p,
  ) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Registrar pagamento?'),
        content: Text(
          '${p.description}\nValor em aberto: ${formatCents(p.openCents)}.\n'
          'O pagamento fica registrado no histórico financeiro.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar como paga'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final Result<void> result =
        await ref.read(financeRepositoryProvider).markPayablePaid(
              payable: p,
              amountCents: p.openCents,
              byUserId: uid,
            );
    ref.invalidate(financePayablesProvider);
    if (!context.mounted) return;
    _feedback(context, result, 'Pagamento registrado.');
  }

  void _feedback(BuildContext context, Result<void> result, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? success
              : 'Não foi possível salvar: ${result.failureOrNull?.message ?? 'erro desconhecido'}',
        ),
      ),
    );
  }
}
