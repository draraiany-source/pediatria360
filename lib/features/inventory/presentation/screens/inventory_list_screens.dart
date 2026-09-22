import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/inventory_access.dart';
import '../../domain/inventory_models.dart';
import '../providers/inventory_providers.dart';

class InventoryItemsScreen extends ConsumerWidget {
  const InventoryItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InventoryScaffold<InventoryItem>(
      title: 'Itens de estoque',
      allowed: InventoryAccess.canView(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: ref.watch(inventoryItemsProvider),
      onRetry: () => ref.invalidate(inventoryItemsProvider),
      emptyLabel: 'Nenhum item cadastrado.',
      itemBuilder: (InventoryItem item) {
        final List<InventoryLot> lots =
            ref.watch(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
        final int stock = stockQtyForItem(itemId: item.id, lots: lots);
        return ListTile(
          title: Text(item.name),
          subtitle: Text(
            '${item.category.label} · ${item.unit.label} · Saldo $stock',
          ),
          trailing: item.active
              ? null
              : const Icon(Icons.pause_circle_outline),
        );
      },
    );
  }
}

class InventoryLotsScreen extends ConsumerWidget {
  const InventoryLotsScreen({super.key, this.itemId});

  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InventoryLot>> async = ref.watch(inventoryLotsProvider);
    final DateTime now = DateTime.now();
    return _InventoryScaffold<InventoryLot>(
      title: 'Lotes',
      allowed: InventoryAccess.canView(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: async,
      onRetry: () => ref.invalidate(inventoryLotsProvider),
      emptyLabel: 'Nenhum lote.',
      itemsFilter: (List<InventoryLot> list) {
        if (itemId == null || itemId!.isEmpty) return list;
        return list.where((InventoryLot l) => l.itemId == itemId).toList();
      },
      itemBuilder: (InventoryLot lot) {
        final LotExpiryStatus st = lotExpiryStatus(
          expiresAt: lot.expiresAt,
          now: now,
        );
        return ListTile(
          title: Text('Lote ${lot.lotCode}'),
          subtitle: Text('Validade ${lot.expiresAt.toIso8601String().substring(0, 10)}'),
          trailing: Text('${lot.qty} · ${st.label}'),
        );
      },
    );
  }
}

class InventoryMovementsScreen extends ConsumerWidget {
  const InventoryMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canRegister = InventoryAccess.canStockOps(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentacoes'),
        actions: <Widget>[
          if (canRegister)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showRegisterDialog(context, ref),
            ),
        ],
      ),
      body: _InventoryScaffold<InventoryMovement>(
        title: '',
        hideAppBar: true,
        allowed: InventoryAccess.canView(
          user: ref.watch(currentUserProvider),
          clinicMembership: ref.watch(activeClinicMembershipProvider),
        ),
        async: ref.watch(inventoryMovementsProvider),
        onRetry: () => ref.invalidate(inventoryMovementsProvider),
        emptyLabel: 'Nenhuma movimentacao.',
        itemBuilder: (InventoryMovement m) => ListTile(
          title: Text(m.type.label),
          subtitle: Text(m.reason),
          trailing: Text('${m.qty}'),
        ),
      ),
    );
  }

  Future<void> _showRegisterDialog(BuildContext context, WidgetRef ref) async {
    final List<InventoryLot> lots =
        ref.read(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
    if (lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um lote antes de movimentar.')),
      );
      return;
    }
    InventoryLot selected = lots.first;
    MovementType type = MovementType.entry;
    final TextEditingController qtyCtrl = TextEditingController(text: '1');
    final TextEditingController reasonCtrl =
        TextEditingController(text: 'Entrada manual');

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Registrar movimentacao'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<InventoryLot>(
                  value: selected,
                  items: lots
                      .map(
                        (InventoryLot l) => DropdownMenuItem<InventoryLot>(
                          value: l,
                          child: Text(l.lotCode),
                        ),
                      )
                      .toList(),
                  onChanged: (InventoryLot? v) {
                    if (v != null) setState(() => selected = v);
                  },
                  decoration: const InputDecoration(labelText: 'Lote'),
                ),
                DropdownButtonFormField<MovementType>(
                  value: type,
                  items: MovementType.values
                      .where(
                        (MovementType t) =>
                            t != MovementType.transfer &&
                            t != MovementType.clinicalUse,
                      )
                      .map(
                        (MovementType t) => DropdownMenuItem<MovementType>(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (MovementType? v) {
                    if (v != null) setState(() => type = v);
                  },
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final String? uid = ref.read(currentUserProvider)?.uid;
              if (uid == null) return;
              final int qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              final String id =
                  '${DateTime.now().millisecondsSinceEpoch}_${selected.id}';
              await ref.read(inventoryRepositoryProvider).recordMovement(
                    movement: InventoryMovement(
                      id: id,
                      itemId: selected.itemId,
                      lotId: selected.id,
                      qty: type == MovementType.adjustment ? qty : qty.abs(),
                      type: type,
                      reason: reasonCtrl.text.trim(),
                      at: DateTime.now(),
                      userId: uid,
                      ownerId: uid,
                    ),
                  );
              ref.invalidate(inventoryMovementsProvider);
              ref.invalidate(inventoryLotsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class InventorySuppliersScreen extends ConsumerWidget {
  const InventorySuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InventoryScaffold<InventorySupplier>(
      title: 'Fornecedores',
      allowed: InventoryAccess.canManagePurchases(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: ref.watch(inventorySuppliersProvider),
      onRetry: () => ref.invalidate(inventorySuppliersProvider),
      emptyLabel: 'Nenhum fornecedor.',
      itemBuilder: (InventorySupplier s) => ListTile(
        title: Text(s.name),
        subtitle: Text(s.documentId.isEmpty ? s.contact : s.documentId),
      ),
    );
  }
}

class InventoryPurchaseOrdersScreen extends ConsumerWidget {
  const InventoryPurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InventoryScaffold<PurchaseOrder>(
      title: 'Pedidos de compra',
      allowed: InventoryAccess.canManagePurchases(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: ref.watch(inventoryPurchaseOrdersProvider),
      onRetry: () => ref.invalidate(inventoryPurchaseOrdersProvider),
      emptyLabel: 'Nenhum pedido.',
      itemBuilder: (PurchaseOrder p) => ListTile(
        title: Text('Pedido ${p.id.substring(0, 8)}…'),
        subtitle: Text(p.status.label),
        trailing: Text('R\$ ${(p.totalCents / 100).toStringAsFixed(2)}'),
      ),
    );
  }
}

class InventoryCountScreen extends ConsumerWidget {
  const InventoryCountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = InventoryAccess.canStockOps(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventario fisico')),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao para inventario.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario fisico')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final String? uid = ref.read(currentUserProvider)?.uid;
          if (uid == null) return;
          final List<InventoryLot> lots =
              await ref.read(inventoryLotsProvider.future);
          await ref.read(inventoryRepositoryProvider).startInventoryCount(
                ownerId: uid,
                byUserId: uid,
                lots: lots,
              );
          ref.invalidate(inventoryCountsProvider);
        },
        label: const Text('Iniciar contagem'),
        icon: const Icon(Icons.playlist_add_check),
      ),
      body: _InventoryScaffold<InventoryCount>(
        title: '',
        hideAppBar: true,
        allowed: true,
        async: ref.watch(inventoryCountsProvider),
        onRetry: () => ref.invalidate(inventoryCountsProvider),
        emptyLabel: 'Nenhum inventario iniciado.',
        itemBuilder: (InventoryCount c) => ListTile(
          title: Text('Inventario ${c.id.substring(0, 8)}'),
          subtitle: Text('${c.lines.length} linhas · ${c.status}'),
        ),
      ),
    );
  }
}

class InventoryReportsScreen extends ConsumerWidget {
  const InventoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatorios de estoque')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar itens (CSV)'),
            subtitle: const Text('Copia para area de transferencia'),
            onTap: () => _exportItems(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined),
            title: const Text('Exportar lotes (CSV)'),
            onTap: () => _exportLots(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportItems(BuildContext context, WidgetRef ref) async {
    final List<InventoryItem> list =
        ref.read(inventoryItemsProvider).valueOrNull ?? const <InventoryItem>[];
    final StringBuffer sb = StringBuffer()
      ..writeln('id,nome,codigo,categoria,min,ideal,ativo');
    for (final InventoryItem i in list) {
      sb.writeln(
        '${i.id},${i.name.replaceAll(',', ';')},${i.code},'
        '${i.category.name},${i.minQty},${i.idealQty},${i.active}',
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copiado (text/csv).')),
      );
    }
  }

  Future<void> _exportLots(BuildContext context, WidgetRef ref) async {
    final List<InventoryLot> list =
        ref.read(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
    final StringBuffer sb = StringBuffer()
      ..writeln('id,itemId,lote,qty,validade,custo_centavos');
    for (final InventoryLot l in list) {
      sb.writeln(
        '${l.id},${l.itemId},${l.lotCode},${l.qty},'
        '${l.expiresAt.toIso8601String()},${l.unitCostCents}',
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copiado (text/csv).')),
      );
    }
  }
}

class _InventoryScaffold<T> extends StatelessWidget {
  const _InventoryScaffold({
    required this.title,
    required this.allowed,
    required this.async,
    required this.onRetry,
    required this.emptyLabel,
    required this.itemBuilder,
    this.itemsFilter,
    this.hideAppBar = false,
  });

  final String title;
  final bool allowed;
  final AsyncValue<List<T>> async;
  final VoidCallback onRetry;
  final String emptyLabel;
  final Widget Function(T item) itemBuilder;
  final List<T> Function(List<T> items)? itemsFilter;
  final bool hideAppBar;

  @override
  Widget build(BuildContext context) {
    if (!allowed) {
      return Scaffold(
        appBar: hideAppBar ? null : AppBar(title: Text(title)),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao.'),
        ),
      );
    }

    final Widget body = async.when(
      loading: () => LoadingState(label: title.isEmpty ? 'Carregando…' : title),
      error: (Object e, StackTrace _) => ErrorState(
        failure: ServerFailure(e.toString()),
        onRetry: onRetry,
      ),
      data: (List<T> data) {
        final List<T> items = itemsFilter?.call(data) ?? data;
        if (items.isEmpty) {
          return EmptyState(title: emptyLabel, message: '');
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) =>
              itemBuilder(items[index]),
        );
      },
    );

    if (hideAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
