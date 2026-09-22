import 'inventory_models.dart';

export 'inventory_models.dart' show InventoryDashboardKpis;

/// Alias para KPIs do dashboard (logica em [InventoryDashboardKpis.compute]).
class InventoryAggregators {
  InventoryAggregators._();

  static InventoryDashboardKpis dashboardKpis({
    required List<InventoryItem> items,
    required List<InventoryLot> lots,
    required List<InventoryMovement> movements,
    required List<PurchaseOrder> purchaseOrders,
    required DateTime now,
    InventoryExpiryConfig expiryConfig = const InventoryExpiryConfig(),
  }) =>
      InventoryDashboardKpis.compute(
        items: items,
        lots: lots,
        movements: movements,
        purchaseOrders: purchaseOrders,
        now: now,
        expiryConfig: expiryConfig,
      );

  static List<InventoryItem> itemsBelowMin({
    required List<InventoryItem> items,
    required List<InventoryLot> lots,
  }) {
    final List<InventoryItem> out = <InventoryItem>[];
    for (final InventoryItem item in items.where((InventoryItem i) => i.active)) {
      final int stock = stockQtyForItem(itemId: item.id, lots: lots);
      if (item.minQty > 0 && stock < item.minQty) out.add(item);
      if (item.minQty == 0 && stock == 0 && item.idealQty > 0) out.add(item);
    }
    return out;
  }

  static List<InventoryLot> lotsNearExpiry({
    required List<InventoryLot> lots,
    required DateTime now,
    InventoryExpiryConfig config = const InventoryExpiryConfig(),
  }) =>
      lots
          .where(
            (InventoryLot l) =>
                lotExpiryStatus(
                  expiresAt: l.expiresAt,
                  now: now,
                  config: config,
                ) ==
                LotExpiryStatus.nearExpiry,
          )
          .toList(growable: false);

  static List<InventoryLot> lotsExpired({
    required List<InventoryLot> lots,
    required DateTime now,
    InventoryExpiryConfig config = const InventoryExpiryConfig(),
  }) =>
      lots
          .where(
            (InventoryLot l) =>
                lotExpiryStatus(
                  expiresAt: l.expiresAt,
                  now: now,
                  config: config,
                ) ==
                LotExpiryStatus.expired,
          )
          .toList(growable: false);
}
