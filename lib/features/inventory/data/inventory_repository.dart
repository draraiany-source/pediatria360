import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../security/domain/tenant_scope.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/inventory_finance_integration.dart';
import '../domain/inventory_models.dart';

class InventoryRepository {
  InventoryRepository({
    required FirebaseFirestore firestore,
    FinanceRepository? financeRepository,
  })  : _firestore = firestore,
        _financeRepository = financeRepository;

  final FirebaseFirestore _firestore;
  final FinanceRepository? _financeRepository;

  Map<String, dynamic> _ledgerPayload(
    Map<String, dynamic> data, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      TenantScope.stampLedgerMap(
        Map<String, dynamic>.from(data),
        membership: membership,
        unitId: unitId,
      );

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('inventory_items');

  CollectionReference<Map<String, dynamic>> get _lots =>
      _firestore.collection('inventory_lots');

  CollectionReference<Map<String, dynamic>> get _movements =>
      _firestore.collection('inventory_movements');

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firestore.collection('inventory_suppliers');

  CollectionReference<Map<String, dynamic>> get _purchaseOrders =>
      _firestore.collection('inventory_purchase_orders');

  CollectionReference<Map<String, dynamic>> get _counts =>
      _firestore.collection('inventory_counts');

  CollectionReference<Map<String, dynamic>> get _audit =>
      _firestore.collection('inventory_audit_logs');

  Stream<List<InventoryItem>> watchItems(String ownerId) => _items
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(InventoryItem.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<InventoryLot>> watchLots(String ownerId) => _lots
      .where('ownerId', isEqualTo: ownerId)
      .limit(1000)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) =>
            snap.docs.map(InventoryLot.fromFirestore).toList(growable: false),
      );

  Stream<List<InventoryMovement>> watchMovements(String ownerId) => _movements
      .where('ownerId', isEqualTo: ownerId)
      .limit(500)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(InventoryMovement.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<InventorySupplier>> watchSuppliers(String ownerId) => _suppliers
      .where('ownerId', isEqualTo: ownerId)
      .limit(200)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(InventorySupplier.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<PurchaseOrder>> watchPurchaseOrders(String ownerId) =>
      _purchaseOrders
          .where('ownerId', isEqualTo: ownerId)
          .limit(200)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
                .map(PurchaseOrder.fromFirestore)
                .toList(growable: false),
          );

  Stream<List<InventoryCount>> watchCounts(String ownerId) => _counts
      .where('ownerId', isEqualTo: ownerId)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(InventoryCount.fromFirestore)
            .toList(growable: false),
      );

  Future<Result<void>> upsertItem(
    InventoryItem item, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        final DateTime now = DateTime.now();
        final Map<String, dynamic> data = item.toMap()
          ..putIfAbsent(
            'createdAt',
            () => Timestamp.fromDate(item.createdAt ?? now),
          )
          ..['updatedAt'] = Timestamp.fromDate(now);
        await _items.doc(item.id).set(
              _ledgerPayload(data, membership: membership, unitId: unitId),
              SetOptions(merge: true),
            );
        await _writeAudit(
          ownerId: item.ownerId,
          action: InventoryAuditAction.itemUpdated,
          entityType: 'item',
          entityId: item.id,
          byUserId: item.ownerId,
        );
      });

  Future<Result<void>> upsertLot(
    InventoryLot lot, {
    ClinicMembership? membership,
    String? unitId,
  }) =>
      guard(() async {
        await _lots.doc(lot.id).set(
              _ledgerPayload(
                lot.toMap(),
                membership: membership,
                unitId: unitId ?? lot.unitId,
              ),
              SetOptions(merge: true),
            );
        await _writeAudit(
          ownerId: lot.ownerId,
          action: InventoryAuditAction.lotUpdated,
          entityType: 'lot',
          entityId: lot.id,
          byUserId: lot.ownerId,
        );
      });

  Future<Result<void>> upsertSupplier(InventorySupplier supplier) =>
      guard(() async {
        await _suppliers.doc(supplier.id).set(supplier.toMap());
      });

  Future<Result<InventoryMovement>> recordMovement({
    required InventoryMovement movement,
    ClinicMembership? membership,
    String? ledgerUnitId,
  }) =>
      guard(() async {
        if (movement.lotId == null || movement.lotId!.isEmpty) {
          throw const ValidationFailure('Movimentacao exige lote.');
        }
        final DocumentReference<Map<String, dynamic>> lotRef =
            _lots.doc(movement.lotId);
        final DocumentReference<Map<String, dynamic>> movRef =
            _movements.doc(movement.id);

        await _firestore.runTransaction((Transaction tx) async {
          final DocumentSnapshot<Map<String, dynamic>> lotSnap =
              await tx.get(lotRef);
          if (!lotSnap.exists) {
            throw const NotFoundFailure('Lote nao encontrado.');
          }
          final InventoryLot lot = InventoryLot.fromFirestore(lotSnap);
          final Result<int> nextResult = InventoryQtyRules.lotQtyAfterMovement(
            currentQty: lot.qty,
            type: movement.type,
            qty: movement.qty,
          );
          if (nextResult.isFailure) {
            throw nextResult.failureOrNull!;
          }
          final int nextQty = nextResult.valueOrNull!;
          tx.update(lotRef, <String, dynamic>{'qty': nextQty});
          tx.set(
            movRef,
            _ledgerPayload(
              movement.toMap(),
              membership: membership,
              unitId: ledgerUnitId ??
                  movement.toUnitId ??
                  movement.fromUnitId,
            ),
          );
        });

        await _writeAudit(
          ownerId: movement.ownerId,
          action: InventoryAuditAction.movementRecorded,
          entityType: 'movement',
          entityId: movement.id,
          byUserId: movement.userId,
          metadata: <String, dynamic>{
            'type': movement.type.name,
            'qty': movement.qty,
            'lotId': movement.lotId,
          },
        );
        return movement;
      });

  Future<Result<InventoryMovement>> confirmClinicalUse({
    required String ownerId,
    required String lotId,
    required String itemId,
    required int qty,
    required String userId,
    String? patientId,
    String? childId,
    String? appointmentId,
    String? encounterId,
    String? vaccineDoseId,
    String reason = 'Uso clinico confirmado',
  }) async {
    final String movId = _movements.doc().id;
    final InventoryMovement movement = InventoryMovement(
      id: movId,
      itemId: itemId,
      lotId: lotId,
      qty: qty,
      type: MovementType.clinicalUse,
      reason: reason,
      at: DateTime.now(),
      userId: userId,
      ownerId: ownerId,
      patientId: patientId,
      childId: childId,
      appointmentId: appointmentId,
      encounterId: encounterId,
      vaccineDoseId: vaccineDoseId,
    );
    return recordMovement(movement: movement);
  }

  Future<Result<PurchaseOrder>> createPurchaseOrder({
    required PurchaseOrder order,
  }) =>
      guard(() async {
        final DateTime now = DateTime.now();
        final Map<String, dynamic> data = order.toMap()
          ..putIfAbsent(
            'createdAt',
            () => Timestamp.fromDate(order.createdAt ?? now),
          );
        await _purchaseOrders.doc(order.id).set(data);
        await _writeAudit(
          ownerId: order.ownerId,
          action: InventoryAuditAction.purchaseOrderCreated,
          entityType: 'purchase_order',
          entityId: order.id,
          byUserId: order.ownerId,
        );
        return order;
      });

  Future<Result<PurchaseOrder>> markPurchaseReceived({
    required PurchaseOrder order,
    required String supplierName,
    required String byUserId,
    required Map<String, InventoryItem> itemsById,
    DateTime? defaultExpiresAt,
    bool createPayable = true,
  }) =>
      guard(() async {
        if (order.status == PurchaseOrderStatus.received) {
          return order;
        }
        final DateTime now = DateTime.now();
        final DateTime expires =
            defaultExpiresAt ?? now.add(const Duration(days: 365));

        for (final PurchaseOrderLine line in order.lines) {
          final InventoryItem? item = itemsById[line.itemId];
          final String lotId = _lots.doc().id;
          final InventoryLot lot = InventoryLot(
            id: lotId,
            itemId: line.itemId,
            lotCode: 'PO-${order.id}-${line.itemId}',
            expiresAt: expires,
            qty: 0,
            unitCostCents: line.unitCostCents,
            totalCostCents: line.lineTotalCents,
            receivedAt: now,
            ownerId: order.ownerId,
            supplierId: order.supplierId,
            documentRef: order.documentRef,
            manufacturer: item?.manufacturer ?? '',
          );
          await _lots.doc(lotId).set(lot.toMap());

          final String movId = _movements.doc().id;
          await recordMovement(
            movement: InventoryMovement(
              id: movId,
              itemId: line.itemId,
              lotId: lotId,
              qty: line.qty,
              type: MovementType.entry,
              reason: 'Recebimento PO ${order.id}',
              at: now,
              userId: byUserId,
              ownerId: order.ownerId,
            ),
          );
        }

        String? payableId = order.payableId;
        if (createPayable &&
            _financeRepository != null &&
            (payableId == null || payableId.isEmpty)) {
          final PurchaseOrder receivedOrder = order.copyWith(
            status: PurchaseOrderStatus.received,
            receivedAt: now,
          );
          final FinancePayable? payable =
              InventoryFinanceIntegration.suggestPayableOnPurchaseReceived(
            order: receivedOrder,
            supplierName: supplierName,
            now: now,
          );
          if (payable != null) {
            await _financeRepository.createPayable(payable);
            payableId = payable.id;
          }
        }

        final PurchaseOrder updated = order.copyWith(
          status: PurchaseOrderStatus.received,
          receivedAt: now,
          payableId: payableId,
        );
        await _purchaseOrders.doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
        await _writeAudit(
          ownerId: order.ownerId,
          action: InventoryAuditAction.purchaseReceived,
          entityType: 'purchase_order',
          entityId: order.id,
          byUserId: byUserId,
        );
        return updated;
      });

  Future<Result<InventoryCount>> startInventoryCount({
    required String ownerId,
    required String byUserId,
    required List<InventoryLot> lots,
  }) =>
      guard(() async {
        final String id = _counts.doc().id;
        final List<InventoryCountLine> lines = lots
            .map(
              (InventoryLot l) => InventoryCountLine(
                itemId: l.itemId,
                lotId: l.id,
                systemQty: l.qty,
                physicalQty: l.qty,
              ),
            )
            .toList(growable: false);
        final InventoryCount count = InventoryCount(
          id: id,
          ownerId: ownerId,
          lines: lines,
          startedAt: DateTime.now(),
          byUserId: byUserId,
        );
        await _counts.doc(id).set(count.toMap());
        await _writeAudit(
          ownerId: ownerId,
          action: InventoryAuditAction.countStarted,
          entityType: 'count',
          entityId: id,
          byUserId: byUserId,
        );
        return count;
      });

  Future<Result<InventoryCount>> finalizeCount({
    required InventoryCount count,
    required String byUserId,
  }) =>
      guard(() async {
        final DateTime now = DateTime.now();
        final List<InventoryCountLine> updatedLines =
            <InventoryCountLine>[];

        for (final InventoryCountLine line in count.lines) {
          final int delta = line.divergence;
          String? movId;
          if (delta != 0) {
            movId = _movements.doc().id;
            await recordMovement(
              movement: InventoryMovement(
                id: movId,
                itemId: line.itemId,
                lotId: line.lotId,
                qty: delta,
                type: MovementType.adjustment,
                reason: 'Inventario fisico',
                at: now,
                userId: byUserId,
                ownerId: count.ownerId,
              ),
            );
          }
          updatedLines.add(
            InventoryCountLine(
              itemId: line.itemId,
              lotId: line.lotId,
              systemQty: line.systemQty,
              physicalQty: line.physicalQty,
              adjustmentMovementId: movId,
            ),
          );
        }

        final InventoryCount finalized = InventoryCount(
          id: count.id,
          ownerId: count.ownerId,
          lines: updatedLines,
          startedAt: count.startedAt,
          finalizedAt: now,
          byUserId: count.byUserId,
          status: 'finalized',
        );
        await _counts.doc(count.id).set(finalized.toMap());
        await _writeAudit(
          ownerId: count.ownerId,
          action: InventoryAuditAction.countFinalized,
          entityType: 'count',
          entityId: count.id,
          byUserId: byUserId,
        );
        return finalized;
      });

  Future<Result<void>> transferLots({
    required InventoryLot lot,
    required String toUnitId,
    required int qty,
    required String byUserId,
    ClinicMembership? membership,
  }) =>
      guard(() async {
        if (qty <= 0) {
          throw const ValidationFailure('Quantidade invalida.');
        }
        TenantScope.requireTransferUnits(
          membership,
          fromUnitId: lot.unitId,
          toUnitId: toUnitId,
        );
        final String exitMovId = _movements.doc().id;
        await recordMovement(
          membership: membership,
          ledgerUnitId: lot.unitId,
          movement: InventoryMovement(
            id: exitMovId,
            itemId: lot.itemId,
            lotId: lot.id,
            qty: qty,
            type: MovementType.transfer,
            reason: 'Transferencia para unidade $toUnitId',
            at: DateTime.now(),
            userId: byUserId,
            ownerId: lot.ownerId,
            fromUnitId: lot.unitId,
            toUnitId: toUnitId,
          ),
        );

        final String newLotId = _lots.doc().id;
        final InventoryLot dest = InventoryLot(
          id: newLotId,
          itemId: lot.itemId,
          lotCode: lot.lotCode,
          manufacturer: lot.manufacturer,
          manufacturedAt: lot.manufacturedAt,
          expiresAt: lot.expiresAt,
          qty: 0,
          unitCostCents: lot.unitCostCents,
          totalCostCents: qty * lot.unitCostCents,
          supplierId: lot.supplierId,
          documentRef: lot.documentRef,
          receivedAt: DateTime.now(),
          ownerId: lot.ownerId,
          unitId: toUnitId,
          location: lot.location,
        );
        await _lots.doc(newLotId).set(
              _ledgerPayload(
                dest.toMap(),
                membership: membership,
                unitId: toUnitId,
              ),
            );

        final String entryMovId = _movements.doc().id;
        await recordMovement(
          membership: membership,
          ledgerUnitId: toUnitId,
          movement: InventoryMovement(
            id: entryMovId,
            itemId: lot.itemId,
            lotId: newLotId,
            qty: qty,
            type: MovementType.entry,
            reason: 'Transferencia recebida de ${lot.unitId ?? "estoque"}',
            at: DateTime.now(),
            userId: byUserId,
            ownerId: lot.ownerId,
            fromUnitId: lot.unitId,
            toUnitId: toUnitId,
          ),
        );

        await _writeAudit(
          ownerId: lot.ownerId,
          action: InventoryAuditAction.transfer,
          entityType: 'lot',
          entityId: lot.id,
          byUserId: byUserId,
          metadata: <String, dynamic>{
            'toUnitId': toUnitId,
            'qty': qty,
            'newLotId': newLotId,
          },
        );
      });

  Future<Result<void>> _writeAudit({
    required String ownerId,
    required InventoryAuditAction action,
    required String entityType,
    required String entityId,
    required String byUserId,
    Map<String, dynamic>? metadata,
  }) =>
      guard(() async {
        final String id = _audit.doc().id;
        final InventoryAuditEntry entry = InventoryAuditEntry(
          id: id,
          ownerId: ownerId,
          action: action,
          entityType: entityType,
          entityId: entityId,
          at: DateTime.now(),
          byUserId: byUserId,
          metadata: metadata ?? const <String, dynamic>{},
        );
        await _audit.doc(id).set(entry.toMap());
      });
}
