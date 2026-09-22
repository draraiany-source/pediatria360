import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/inventory/domain/inventory_aggregators.dart';
import 'package:pediatria360/features/inventory/domain/inventory_models.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 1);

  InventoryItem item({
    required String id,
    int minQty = 5,
    int idealQty = 10,
  }) =>
      InventoryItem(
        id: id,
        name: 'Item $id',
        code: id,
        category: InventoryCategory.vaccines,
        unit: InventoryUnit.vial,
        ownerId: 'o1',
        minQty: minQty,
        idealQty: idealQty,
      );

  test('dashboard KPIs count below min and expiry', () {
    final InventoryDashboardKpis kpis = InventoryAggregators.dashboardKpis(
      items: <InventoryItem>[item(id: 'i1', minQty: 10)],
      lots: <InventoryLot>[
        InventoryLot(
          id: 'l1',
          itemId: 'i1',
          lotCode: 'A',
          expiresAt: now.add(const Duration(days: 10)),
          qty: 2,
          unitCostCents: 100,
          receivedAt: now,
          ownerId: 'o1',
        ),
        InventoryLot(
          id: 'l2',
          itemId: 'i1',
          lotCode: 'B',
          expiresAt: now.subtract(const Duration(days: 1)),
          qty: 1,
          unitCostCents: 50,
          receivedAt: now,
          ownerId: 'o1',
        ),
      ],
      movements: const <InventoryMovement>[],
      purchaseOrders: const <PurchaseOrder>[],
      now: now,
    );
    expect(kpis.belowMin, 1);
    expect(kpis.expiredLots, greaterThanOrEqualTo(1));
    expect(kpis.stockValueCents, 250);
  });
}
