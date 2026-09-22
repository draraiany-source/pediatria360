import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';
import 'package:pediatria360/features/inventory/domain/inventory_finance_integration.dart';
import 'package:pediatria360/features/inventory/domain/inventory_models.dart';

void main() {
  final DateTime now = DateTime(2026, 3, 1);

  test('suggest payable on received PO', () {
    final PurchaseOrder order = PurchaseOrder(
      id: 'po1',
      supplierId: 's1',
      lines: const <PurchaseOrderLine>[
        PurchaseOrderLine(itemId: 'i1', qty: 2, unitCostCents: 500),
      ],
      status: PurchaseOrderStatus.received,
      ownerId: 'o1',
    );
    final FinancePayable? p =
        InventoryFinanceIntegration.suggestPayableOnPurchaseReceived(
      order: order,
      supplierName: 'Distribuidora',
      now: now,
    );
    expect(p, isNotNull);
    expect(p!.id, 'po_po1');
    expect(p.amountCents, 1000);
    expect(p.category, ExpenseCategory.materials);
  });

  test('skips duplicate when payableId set', () {
    final PurchaseOrder order = PurchaseOrder(
      id: 'po2',
      supplierId: 's1',
      lines: const <PurchaseOrderLine>[
        PurchaseOrderLine(itemId: 'i1', qty: 1, unitCostCents: 100),
      ],
      status: PurchaseOrderStatus.received,
      ownerId: 'o1',
      payableId: 'existing',
    );
    expect(
      InventoryFinanceIntegration.suggestPayableOnPurchaseReceived(
        order: order,
        supplierName: 'X',
        now: now,
      ),
      isNull,
    );
  });
}
