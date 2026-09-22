import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dev_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_access.dart';
import '../../domain/inventory_aggregators.dart';
import '../../domain/inventory_models.dart';

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>(
  (Ref ref) => InventoryRepository(
    firestore: ref.watch(firestoreProvider),
    financeRepository: ref.watch(financeRepositoryProvider),
  ),
);

final Provider<bool> inventoryModuleAllowedProvider = Provider<bool>((Ref ref) {
  return InventoryAccess.canAccessModule(
    user: ref.watch(currentUserProvider),
    clinicMembership: ref.watch(activeClinicMembershipProvider),
  );
});

final StreamProvider<List<InventoryItem>> inventoryItemsProvider =
    StreamProvider<List<InventoryItem>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<InventoryItem>>.value(const <InventoryItem>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<InventoryItem>>.value(const <InventoryItem>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchItems(uid);
});

final StreamProvider<List<InventoryLot>> inventoryLotsProvider =
    StreamProvider<List<InventoryLot>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<InventoryLot>>.value(const <InventoryLot>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<InventoryLot>>.value(const <InventoryLot>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchLots(uid);
});

final StreamProvider<List<InventoryMovement>> inventoryMovementsProvider =
    StreamProvider<List<InventoryMovement>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<InventoryMovement>>.value(const <InventoryMovement>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<InventoryMovement>>.value(const <InventoryMovement>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchMovements(uid);
});

final StreamProvider<List<InventorySupplier>> inventorySuppliersProvider =
    StreamProvider<List<InventorySupplier>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<InventorySupplier>>.value(const <InventorySupplier>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<InventorySupplier>>.value(const <InventorySupplier>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchSuppliers(uid);
});

final StreamProvider<List<PurchaseOrder>> inventoryPurchaseOrdersProvider =
    StreamProvider<List<PurchaseOrder>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<PurchaseOrder>>.value(const <PurchaseOrder>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<PurchaseOrder>>.value(const <PurchaseOrder>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchPurchaseOrders(uid);
});

final StreamProvider<List<InventoryCount>> inventoryCountsProvider =
    StreamProvider<List<InventoryCount>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<InventoryCount>>.value(const <InventoryCount>[]);
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<InventoryCount>>.value(const <InventoryCount>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchCounts(uid);
});

final Provider<InventoryDashboardKpis> inventoryDashboardKpisProvider =
    Provider<InventoryDashboardKpis>((Ref ref) {
  final List<InventoryItem> items =
      ref.watch(inventoryItemsProvider).valueOrNull ?? const <InventoryItem>[];
  final List<InventoryLot> lots =
      ref.watch(inventoryLotsProvider).valueOrNull ?? const <InventoryLot>[];
  final List<InventoryMovement> movements =
      ref.watch(inventoryMovementsProvider).valueOrNull ??
          const <InventoryMovement>[];
  final List<PurchaseOrder> orders =
      ref.watch(inventoryPurchaseOrdersProvider).valueOrNull ??
          const <PurchaseOrder>[];
  return InventoryAggregators.dashboardKpis(
    items: items,
    lots: lots,
    movements: movements,
    purchaseOrders: orders,
    now: DateTime.now(),
  );
});
