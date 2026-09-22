import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/error/failures.dart';
import 'package:pediatria360/core/utils/result.dart';
import 'package:pediatria360/features/inventory/domain/inventory_models.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 1);

  test('lot expiry status thresholds', () {
    expect(
      lotExpiryStatus(
        expiresAt: now.add(const Duration(days: 120)),
        now: now,
      ),
      LotExpiryStatus.valid,
    );
    expect(
      lotExpiryStatus(
        expiresAt: now.add(const Duration(days: 20)),
        now: now,
      ),
      LotExpiryStatus.nearExpiry,
    );
    expect(
      lotExpiryStatus(
        expiresAt: now.subtract(const Duration(days: 1)),
        now: now,
      ),
      LotExpiryStatus.expired,
    );
  });

  test('exit rejects negative balance', () {
    final Result<int> r = InventoryQtyRules.lotQtyAfterMovement(
      currentQty: 2,
      type: MovementType.exit,
      qty: 5,
    );
    expect(r.isFailure, isTrue);
    expect(r.failureOrNull, isA<ValidationFailure>());
  });

  test('entry adds quantity', () {
    final Result<int> r = InventoryQtyRules.lotQtyAfterMovement(
      currentQty: 2,
      type: MovementType.entry,
      qty: 3,
    );
    expect(r.valueOrNull, 5);
  });

  test('stockQtyForItem sums lots', () {
    expect(
      stockQtyForItem(
        itemId: 'i1',
        lots: <InventoryLot>[
          InventoryLot(
            id: 'l1',
            itemId: 'i1',
            lotCode: 'A',
            expiresAt: now,
            qty: 2,
            unitCostCents: 0,
            receivedAt: now,
            ownerId: 'o',
          ),
          InventoryLot(
            id: 'l2',
            itemId: 'i2',
            lotCode: 'B',
            expiresAt: now,
            qty: 9,
            unitCostCents: 0,
            receivedAt: now,
            ownerId: 'o',
          ),
        ],
      ),
      2,
    );
  });
}
