import '../../finance/domain/finance_models.dart';
import 'inventory_models.dart';

/// Sugestao pura de conta a pagar ao receber compra de estoque.
class InventoryFinanceIntegration {
  InventoryFinanceIntegration._();

  static String payableIdForPurchaseOrder(String purchaseOrderId) =>
      'po_$purchaseOrderId';

  static FinancePayable? suggestPayableOnPurchaseReceived({
    required PurchaseOrder order,
    required String supplierName,
    required DateTime now,
  }) {
    if (order.payableId != null && order.payableId!.isNotEmpty) {
      return null;
    }
    if (order.status != PurchaseOrderStatus.received) {
      return null;
    }
    if (order.totalCents <= 0) {
      return null;
    }

    ExpenseCategory category = ExpenseCategory.materials;
    for (final PurchaseOrderLine line in order.lines) {
      // Heuristica: se alguma linha for medicamento, categoriza como medicines.
      if (line.itemName.toLowerCase().contains('med')) {
        category = ExpenseCategory.medicines;
        break;
      }
    }

    return FinancePayable(
      id: payableIdForPurchaseOrder(order.id),
      ownerId: order.ownerId,
      description: 'Compra estoque — $supplierName (PO ${order.id})',
      category: category,
      amountCents: order.totalCents,
      paidCents: 0,
      status: PayableStatus.pending,
      dueAt: order.expectedAt ?? now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
    );
  }
}
