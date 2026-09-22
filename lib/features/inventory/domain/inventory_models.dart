import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../core/utils/result.dart';
import '../../../core/error/failures.dart';

enum InventoryCategory {
  vaccines,
  medicines,
  materials,
  supplies,
  disposables,
  equipment,
  other;

  static InventoryCategory fromName(String? value) =>
      InventoryCategory.values.firstWhere(
        (InventoryCategory c) => c.name == value,
        orElse: () => InventoryCategory.other,
      );

  String get label => switch (this) {
        InventoryCategory.vaccines => 'Vacinas',
        InventoryCategory.medicines => 'Medicamentos',
        InventoryCategory.materials => 'Materiais',
        InventoryCategory.supplies => 'Insumos',
        InventoryCategory.disposables => 'Descartaveis',
        InventoryCategory.equipment => 'Equipamentos',
        InventoryCategory.other => 'Outros',
      };
}

enum InventoryUnit {
  ml,
  ampule,
  vial,
  unit,
  box,
  kg,
  g,
  l,
  pack,
  other;

  static InventoryUnit fromName(String? value) => InventoryUnit.values.firstWhere(
        (InventoryUnit u) => u.name == value,
        orElse: () => InventoryUnit.unit,
      );

  String get label => switch (this) {
        InventoryUnit.ml => 'ml',
        InventoryUnit.ampule => 'Ampola',
        InventoryUnit.vial => 'Frasco',
        InventoryUnit.unit => 'Unidade',
        InventoryUnit.box => 'Caixa',
        InventoryUnit.kg => 'kg',
        InventoryUnit.g => 'g',
        InventoryUnit.l => 'L',
        InventoryUnit.pack => 'Pacote',
        InventoryUnit.other => 'Outro',
      };
}

enum LotExpiryStatus {
  valid,
  nearExpiry,
  expired;

  String get label => switch (this) {
        LotExpiryStatus.valid => 'Valido',
        LotExpiryStatus.nearExpiry => 'Vencimento proximo',
        LotExpiryStatus.expired => 'Vencido',
      };
}

class InventoryExpiryConfig extends Equatable {
  const InventoryExpiryConfig({
    this.nearExpiryDays = 90,
    this.warningDays = 60,
    this.criticalDays = 30,
  });

  final int nearExpiryDays;
  final int warningDays;
  final int criticalDays;

  @override
  List<Object?> get props =>
      <Object?>[nearExpiryDays, warningDays, criticalDays];
}

LotExpiryStatus lotExpiryStatus({
  required DateTime expiresAt,
  required DateTime now,
  InventoryExpiryConfig config = const InventoryExpiryConfig(),
}) {
  final DateTime day = DateTime(now.year, now.month, now.day);
  final DateTime exp =
      DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
  if (!exp.isAfter(day)) return LotExpiryStatus.expired;
  final int days = exp.difference(day).inDays;
  if (days <= config.criticalDays) return LotExpiryStatus.nearExpiry;
  if (days <= config.warningDays) return LotExpiryStatus.nearExpiry;
  if (days <= config.nearExpiryDays) return LotExpiryStatus.nearExpiry;
  return LotExpiryStatus.valid;
}

enum MovementType {
  entry,
  exit,
  adjustment,
  loss,
  expiry,
  clinicalUse,
  transfer,
  return_;

  static MovementType fromName(String? value) => MovementType.values.firstWhere(
        (MovementType t) => t.name == value,
        orElse: () => MovementType.exit,
      );

  String get label => switch (this) {
        MovementType.entry => 'Entrada',
        MovementType.exit => 'Saida',
        MovementType.adjustment => 'Ajuste',
        MovementType.loss => 'Perda',
        MovementType.expiry => 'Vencimento',
        MovementType.clinicalUse => 'Uso clinico',
        MovementType.transfer => 'Transferencia',
        MovementType.return_ => 'Devolucao',
      };

  bool get subtractsStock =>
      this == MovementType.exit ||
      this == MovementType.loss ||
      this == MovementType.expiry ||
      this == MovementType.clinicalUse;

  bool get addsStock => this == MovementType.entry || this == MovementType.return_;
}

enum PurchaseOrderStatus {
  requested,
  quotation,
  approved,
  ordered,
  received,
  cancelled;

  static PurchaseOrderStatus fromName(String? value) =>
      PurchaseOrderStatus.values.firstWhere(
        (PurchaseOrderStatus s) => s.name == value,
        orElse: () => PurchaseOrderStatus.requested,
      );

  String get label => switch (this) {
        PurchaseOrderStatus.requested => 'Solicitado',
        PurchaseOrderStatus.quotation => 'Cotacao',
        PurchaseOrderStatus.approved => 'Aprovado',
        PurchaseOrderStatus.ordered => 'Pedido',
        PurchaseOrderStatus.received => 'Recebido',
        PurchaseOrderStatus.cancelled => 'Cancelado',
      };
}

enum InventoryItemStatus {
  active,
  inactive;

  static InventoryItemStatus fromName(String? value) =>
      InventoryItemStatus.values.firstWhere(
        (InventoryItemStatus s) => s.name == value,
        orElse: () => InventoryItemStatus.active,
      );
}

enum InventoryAuditAction {
  itemCreated,
  itemUpdated,
  lotCreated,
  lotUpdated,
  movementRecorded,
  purchaseOrderCreated,
  purchaseReceived,
  countStarted,
  countFinalized,
  transfer;

  String get label => switch (this) {
        InventoryAuditAction.itemCreated => 'Item criado',
        InventoryAuditAction.itemUpdated => 'Item atualizado',
        InventoryAuditAction.lotCreated => 'Lote criado',
        InventoryAuditAction.lotUpdated => 'Lote atualizado',
        InventoryAuditAction.movementRecorded => 'Movimentacao',
        InventoryAuditAction.purchaseOrderCreated => 'Pedido de compra',
        InventoryAuditAction.purchaseReceived => 'Compra recebida',
        InventoryAuditAction.countStarted => 'Inventario iniciado',
        InventoryAuditAction.countFinalized => 'Inventario finalizado',
        InventoryAuditAction.transfer => 'Transferencia',
      };
}

/// Regras puras de quantidade (testadas sem Firestore).
class InventoryQtyRules {
  InventoryQtyRules._();

  static Result<int> lotQtyAfterMovement({
    required int currentQty,
    required MovementType type,
    required int qty,
  }) {
    if (type != MovementType.adjustment && qty < 0) {
      return const Result.failure(
        ValidationFailure('Quantidade deve ser positiva.'),
      );
    }
    final int next = switch (type) {
      MovementType.entry || MovementType.return_ => currentQty + qty,
      MovementType.exit ||
      MovementType.loss ||
      MovementType.expiry ||
      MovementType.clinicalUse =>
        currentQty - qty,
      MovementType.adjustment => currentQty + qty,
      MovementType.transfer => currentQty - qty,
    };
    if (next < 0) {
      return const Result.failure(
        ValidationFailure('Saldo do lote ficaria negativo.'),
      );
    }
    return Result.success(next);
  }
}

int stockQtyForItem({
  required String itemId,
  required Iterable<InventoryLot> lots,
}) {
  int sum = 0;
  for (final InventoryLot lot in lots) {
    if (lot.itemId == itemId) sum += lot.qty;
  }
  return sum;
}

DateTime _readDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _readDateOrNull(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.unit,
    required this.ownerId,
    this.manufacturer = '',
    this.supplierId,
    this.minQty = 0,
    this.idealQty = 0,
    this.location = '',
    this.notes = '',
    this.active = true,
    this.clinicId,
    this.defaultUnitId,
    this.presentation,
    this.concentration,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return InventoryItem(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      code: (data['code'] as String?) ?? '',
      category: InventoryCategory.fromName(data['category'] as String?),
      unit: InventoryUnit.fromName(data['unit'] as String?),
      manufacturer: (data['manufacturer'] as String?) ?? '',
      supplierId: data['supplierId'] as String?,
      minQty: (data['minQty'] as num?)?.toInt() ?? 0,
      idealQty: (data['idealQty'] as num?)?.toInt() ?? 0,
      location: (data['location'] as String?) ?? '',
      notes: (data['notes'] as String?) ?? '',
      active: (data['active'] as bool?) ?? true,
      ownerId: (data['ownerId'] as String?) ?? '',
      clinicId: data['clinicId'] as String?,
      defaultUnitId: data['defaultUnitId'] as String?,
      presentation: data['presentation'] as String?,
      concentration: data['concentration'] as String?,
      createdAt: _readDateOrNull(data['createdAt']),
      updatedAt: _readDateOrNull(data['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String code;
  final InventoryCategory category;
  final InventoryUnit unit;
  final String manufacturer;
  final String? supplierId;
  final int minQty;
  final int idealQty;
  final String location;
  final String notes;
  final bool active;
  final String ownerId;
  final String? clinicId;
  final String? defaultUnitId;
  final String? presentation;
  final String? concentration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InventoryItemStatus get status =>
      active ? InventoryItemStatus.active : InventoryItemStatus.inactive;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'code': code,
        'category': category.name,
        'unit': unit.name,
        'manufacturer': manufacturer,
        if (supplierId != null) 'supplierId': supplierId,
        'minQty': minQty,
        'idealQty': idealQty,
        'location': location,
        'notes': notes,
        'active': active,
        'ownerId': ownerId,
        if (clinicId != null) 'clinicId': clinicId,
        if (defaultUnitId != null) 'defaultUnitId': defaultUnitId,
        if (presentation != null) 'presentation': presentation,
        if (concentration != null) 'concentration': concentration,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  InventoryItem copyWith({
    String? name,
    String? code,
    InventoryCategory? category,
    InventoryUnit? unit,
    String? manufacturer,
    String? supplierId,
    int? minQty,
    int? idealQty,
    String? location,
    String? notes,
    bool? active,
    String? defaultUnitId,
    String? presentation,
    String? concentration,
    DateTime? updatedAt,
  }) =>
      InventoryItem(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        manufacturer: manufacturer ?? this.manufacturer,
        supplierId: supplierId ?? this.supplierId,
        minQty: minQty ?? this.minQty,
        idealQty: idealQty ?? this.idealQty,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        active: active ?? this.active,
        ownerId: ownerId,
        clinicId: clinicId,
        defaultUnitId: defaultUnitId ?? this.defaultUnitId,
        presentation: presentation ?? this.presentation,
        concentration: concentration ?? this.concentration,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => <Object?>[id, ownerId, name, category, active];
}

class InventoryLot extends Equatable {
  const InventoryLot({
    required this.id,
    required this.itemId,
    required this.lotCode,
    required this.expiresAt,
    required this.qty,
    required this.unitCostCents,
    required this.receivedAt,
    required this.ownerId,
    this.manufacturer = '',
    this.manufacturedAt,
    this.totalCostCents = 0,
    this.supplierId,
    this.documentRef,
    this.unitId,
    this.location,
  });

  factory InventoryLot.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    final int qty = (data['qty'] as num?)?.toInt() ?? 0;
    final int unitCost = (data['unitCostCents'] as num?)?.toInt() ?? 0;
    return InventoryLot(
      id: doc.id,
      itemId: (data['itemId'] as String?) ?? '',
      lotCode: (data['lotCode'] as String?) ?? '',
      manufacturer: (data['manufacturer'] as String?) ?? '',
      manufacturedAt: _readDateOrNull(data['manufacturedAt']),
      expiresAt: _readDate(data['expiresAt']),
      qty: qty,
      unitCostCents: unitCost,
      totalCostCents: (data['totalCostCents'] as num?)?.toInt() ?? qty * unitCost,
      supplierId: data['supplierId'] as String?,
      documentRef: data['documentRef'] as String?,
      receivedAt: _readDate(data['receivedAt']),
      ownerId: (data['ownerId'] as String?) ?? '',
      unitId: data['unitId'] as String?,
      location: data['location'] as String?,
    );
  }

  final String id;
  final String itemId;
  final String lotCode;
  final String manufacturer;
  final DateTime? manufacturedAt;
  final DateTime expiresAt;
  final int qty;
  final int unitCostCents;
  final int totalCostCents;
  final String? supplierId;
  final String? documentRef;
  final DateTime receivedAt;
  final String ownerId;
  final String? unitId;
  final String? location;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'itemId': itemId,
        'lotCode': lotCode,
        'manufacturer': manufacturer,
        if (manufacturedAt != null)
          'manufacturedAt': Timestamp.fromDate(manufacturedAt!),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'qty': qty,
        'unitCostCents': unitCostCents,
        'totalCostCents': totalCostCents,
        if (supplierId != null) 'supplierId': supplierId,
        if (documentRef != null) 'documentRef': documentRef,
        'receivedAt': Timestamp.fromDate(receivedAt),
        'ownerId': ownerId,
        if (unitId != null) 'unitId': unitId,
        if (location != null) 'location': location,
      };

  InventoryLot copyWith({int? qty, int? totalCostCents, String? unitId}) =>
      InventoryLot(
        id: id,
        itemId: itemId,
        lotCode: lotCode,
        manufacturer: manufacturer,
        manufacturedAt: manufacturedAt,
        expiresAt: expiresAt,
        qty: qty ?? this.qty,
        unitCostCents: unitCostCents,
        totalCostCents: totalCostCents ?? this.totalCostCents,
        supplierId: supplierId,
        documentRef: documentRef,
        receivedAt: receivedAt,
        ownerId: ownerId,
        unitId: unitId ?? this.unitId,
        location: location,
      );

  @override
  List<Object?> get props => <Object?>[id, itemId, lotCode, qty, expiresAt];
}

class InventoryMovement extends Equatable {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.type,
    required this.reason,
    required this.at,
    required this.userId,
    required this.ownerId,
    this.lotId,
    this.patientId,
    this.childId,
    this.appointmentId,
    this.encounterId,
    this.vaccineDoseId,
    this.fromUnitId,
    this.toUnitId,
    this.notes,
  });

  factory InventoryMovement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return InventoryMovement(
      id: doc.id,
      itemId: (data['itemId'] as String?) ?? '',
      lotId: data['lotId'] as String?,
      qty: (data['qty'] as num?)?.toInt() ?? 0,
      type: MovementType.fromName(data['type'] as String?),
      reason: (data['reason'] as String?) ?? '',
      at: _readDate(data['at']),
      userId: (data['userId'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      patientId: data['patientId'] as String?,
      childId: data['childId'] as String?,
      appointmentId: data['appointmentId'] as String?,
      encounterId: data['encounterId'] as String?,
      vaccineDoseId: data['vaccineDoseId'] as String?,
      fromUnitId: data['fromUnitId'] as String?,
      toUnitId: data['toUnitId'] as String?,
      notes: data['notes'] as String?,
    );
  }

  final String id;
  final String itemId;
  final String? lotId;
  final int qty;
  final MovementType type;
  final String reason;
  final DateTime at;
  final String userId;
  final String ownerId;
  final String? patientId;
  final String? childId;
  final String? appointmentId;
  final String? encounterId;
  final String? vaccineDoseId;
  final String? fromUnitId;
  final String? toUnitId;
  final String? notes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'itemId': itemId,
        if (lotId != null) 'lotId': lotId,
        'qty': qty,
        'type': type.name,
        'reason': reason,
        'at': Timestamp.fromDate(at),
        'userId': userId,
        'ownerId': ownerId,
        if (patientId != null) 'patientId': patientId,
        if (childId != null) 'childId': childId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (encounterId != null) 'encounterId': encounterId,
        if (vaccineDoseId != null) 'vaccineDoseId': vaccineDoseId,
        if (fromUnitId != null) 'fromUnitId': fromUnitId,
        if (toUnitId != null) 'toUnitId': toUnitId,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => <Object?>[id, itemId, lotId, type, qty, at];
}

class InventorySupplier extends Equatable {
  const InventorySupplier({
    required this.id,
    required this.name,
    required this.ownerId,
    this.documentId = '',
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.productNotes = '',
    this.active = true,
  });

  factory InventorySupplier.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return InventorySupplier(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      documentId: (data['documentId'] as String?) ?? '',
      contact: (data['contact'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      productNotes: (data['productNotes'] as String?) ?? '',
      active: (data['active'] as bool?) ?? true,
      ownerId: (data['ownerId'] as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String documentId;
  final String contact;
  final String phone;
  final String email;
  final String address;
  final String productNotes;
  final bool active;
  final String ownerId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'documentId': documentId,
        'contact': contact,
        'phone': phone,
        'email': email,
        'address': address,
        'productNotes': productNotes,
        'active': active,
        'ownerId': ownerId,
      };

  @override
  List<Object?> get props => <Object?>[id, name, ownerId, active];
}

class PurchaseOrderLine extends Equatable {
  const PurchaseOrderLine({
    required this.itemId,
    required this.qty,
    required this.unitCostCents,
    this.itemName = '',
  });

  factory PurchaseOrderLine.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderLine(
        itemId: (map['itemId'] as String?) ?? '',
        qty: (map['qty'] as num?)?.toInt() ?? 0,
        unitCostCents: (map['unitCostCents'] as num?)?.toInt() ?? 0,
        itemName: (map['itemName'] as String?) ?? '',
      );

  final String itemId;
  final int qty;
  final int unitCostCents;
  final String itemName;

  int get lineTotalCents => qty * unitCostCents;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'itemId': itemId,
        'qty': qty,
        'unitCostCents': unitCostCents,
        if (itemName.isNotEmpty) 'itemName': itemName,
      };

  @override
  List<Object?> get props => <Object?>[itemId, qty, unitCostCents];
}

class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.lines,
    required this.status,
    required this.ownerId,
    this.expectedAt,
    this.receivedAt,
    this.payableId,
    this.documentRef = '',
    this.createdAt,
  });

  factory PurchaseOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    final List<PurchaseOrderLine> lines = (data['lines'] as List<dynamic>?)
            ?.map(
              (dynamic e) =>
                  PurchaseOrderLine.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList(growable: false) ??
        const <PurchaseOrderLine>[];
    return PurchaseOrder(
      id: doc.id,
      supplierId: (data['supplierId'] as String?) ?? '',
      lines: lines,
      status: PurchaseOrderStatus.fromName(data['status'] as String?),
      expectedAt: _readDateOrNull(data['expectedAt']),
      receivedAt: _readDateOrNull(data['receivedAt']),
      payableId: data['payableId'] as String?,
      documentRef: (data['documentRef'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      createdAt: _readDateOrNull(data['createdAt']),
    );
  }

  final String id;
  final String supplierId;
  final List<PurchaseOrderLine> lines;
  final PurchaseOrderStatus status;
  final DateTime? expectedAt;
  final DateTime? receivedAt;
  final String? payableId;
  final String documentRef;
  final String ownerId;
  final DateTime? createdAt;

  int get totalCents =>
      lines.fold(0, (int s, PurchaseOrderLine l) => s + l.lineTotalCents);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'supplierId': supplierId,
        'lines': lines.map((PurchaseOrderLine l) => l.toMap()).toList(),
        'status': status.name,
        if (expectedAt != null) 'expectedAt': Timestamp.fromDate(expectedAt!),
        if (receivedAt != null) 'receivedAt': Timestamp.fromDate(receivedAt!),
        if (payableId != null) 'payableId': payableId,
        'documentRef': documentRef,
        'ownerId': ownerId,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  PurchaseOrder copyWith({
    PurchaseOrderStatus? status,
    DateTime? receivedAt,
    String? payableId,
  }) =>
      PurchaseOrder(
        id: id,
        supplierId: supplierId,
        lines: lines,
        status: status ?? this.status,
        expectedAt: expectedAt,
        receivedAt: receivedAt ?? this.receivedAt,
        payableId: payableId ?? this.payableId,
        documentRef: documentRef,
        ownerId: ownerId,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => <Object?>[id, supplierId, status, ownerId];
}

class InventoryCountLine extends Equatable {
  const InventoryCountLine({
    required this.itemId,
    required this.lotId,
    required this.systemQty,
    required this.physicalQty,
    this.adjustmentMovementId,
  });

  factory InventoryCountLine.fromMap(Map<String, dynamic> map) =>
      InventoryCountLine(
        itemId: (map['itemId'] as String?) ?? '',
        lotId: (map['lotId'] as String?) ?? '',
        systemQty: (map['systemQty'] as num?)?.toInt() ?? 0,
        physicalQty: (map['physicalQty'] as num?)?.toInt() ?? 0,
        adjustmentMovementId: map['adjustmentMovementId'] as String?,
      );

  final String itemId;
  final String lotId;
  final int systemQty;
  final int physicalQty;
  final String? adjustmentMovementId;

  int get divergence => physicalQty - systemQty;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'itemId': itemId,
        'lotId': lotId,
        'systemQty': systemQty,
        'physicalQty': physicalQty,
        if (adjustmentMovementId != null)
          'adjustmentMovementId': adjustmentMovementId,
      };

  @override
  List<Object?> get props => <Object?>[itemId, lotId, systemQty, physicalQty];
}

class InventoryCount extends Equatable {
  const InventoryCount({
    required this.id,
    required this.ownerId,
    required this.lines,
    required this.startedAt,
    required this.byUserId,
    this.finalizedAt,
    this.status = 'open',
  });

  factory InventoryCount.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    final List<InventoryCountLine> lines = (data['lines'] as List<dynamic>?)
            ?.map(
              (dynamic e) => InventoryCountLine.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false) ??
        const <InventoryCountLine>[];
    return InventoryCount(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      lines: lines,
      startedAt: _readDate(data['startedAt']),
      finalizedAt: _readDateOrNull(data['finalizedAt']),
      byUserId: (data['byUserId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'open',
    );
  }

  final String id;
  final String ownerId;
  final List<InventoryCountLine> lines;
  final DateTime startedAt;
  final DateTime? finalizedAt;
  final String byUserId;
  final String status;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'lines': lines.map((InventoryCountLine l) => l.toMap()).toList(),
        'startedAt': Timestamp.fromDate(startedAt),
        if (finalizedAt != null) 'finalizedAt': Timestamp.fromDate(finalizedAt!),
        'byUserId': byUserId,
        'status': status,
      };

  @override
  List<Object?> get props => <Object?>[id, ownerId, status];
}

class InventoryAuditEntry extends Equatable {
  const InventoryAuditEntry({
    required this.id,
    required this.ownerId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.at,
    required this.byUserId,
    this.metadata = const <String, dynamic>{},
  });

  factory InventoryAuditEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return InventoryAuditEntry(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      action: InventoryAuditAction.values.firstWhere(
        (InventoryAuditAction a) => a.name == data['action'],
        orElse: () => InventoryAuditAction.movementRecorded,
      ),
      entityType: (data['entityType'] as String?) ?? '',
      entityId: (data['entityId'] as String?) ?? '',
      at: _readDate(data['at']),
      byUserId: (data['byUserId'] as String?) ?? '',
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String ownerId;
  final InventoryAuditAction action;
  final String entityType;
  final String entityId;
  final DateTime at;
  final String byUserId;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'action': action.name,
        'entityType': entityType,
        'entityId': entityId,
        'at': Timestamp.fromDate(at),
        'byUserId': byUserId,
        'metadata': metadata,
      };

  @override
  List<Object?> get props => <Object?>[id, action, entityId, at];
}

class InventoryDashboardKpis extends Equatable {
  const InventoryDashboardKpis({
    required this.totalItems,
    required this.belowMin,
    required this.nearExpiryLots,
    required this.expiredLots,
    required this.stockValueCents,
    required this.monthConsumption,
    required this.losses,
    required this.pendingPurchases,
  });

  final int totalItems;
  final int belowMin;
  final int nearExpiryLots;
  final int expiredLots;
  final int stockValueCents;
  final int monthConsumption;
  final int losses;
  final int pendingPurchases;

  static InventoryDashboardKpis compute({
    required List<InventoryItem> items,
    required List<InventoryLot> lots,
    required List<InventoryMovement> movements,
    required List<PurchaseOrder> purchaseOrders,
    required DateTime now,
    InventoryExpiryConfig expiryConfig = const InventoryExpiryConfig(),
  }) {
    final Map<String, int> stockByItem = <String, int>{};
    for (final InventoryLot lot in lots) {
      stockByItem[lot.itemId] = (stockByItem[lot.itemId] ?? 0) + lot.qty;
    }

    int belowMin = 0;
    for (final InventoryItem item in items.where((InventoryItem i) => i.active)) {
      final int stock = stockByItem[item.id] ?? 0;
      if (item.minQty > 0 && stock < item.minQty) belowMin += 1;
    }

    int nearExpiry = 0;
    int expired = 0;
    int stockValue = 0;
    for (final InventoryLot lot in lots) {
      stockValue += lot.qty * lot.unitCostCents;
      final LotExpiryStatus st = lotExpiryStatus(
        expiresAt: lot.expiresAt,
        now: now,
        config: expiryConfig,
      );
      if (st == LotExpiryStatus.expired) expired += 1;
      if (st == LotExpiryStatus.nearExpiry) nearExpiry += 1;
    }

    final DateTime monthStart = DateTime(now.year, now.month);
    int consumption = 0;
    int losses = 0;
    for (final InventoryMovement m in movements) {
      if (m.at.isBefore(monthStart)) continue;
      if (m.type == MovementType.clinicalUse || m.type == MovementType.exit) {
        consumption += m.qty;
      }
      if (m.type == MovementType.loss || m.type == MovementType.expiry) {
        losses += m.qty;
      }
    }

    final int pendingPurchases = purchaseOrders
        .where(
          (PurchaseOrder p) =>
              p.status != PurchaseOrderStatus.received &&
              p.status != PurchaseOrderStatus.cancelled,
        )
        .length;

    return InventoryDashboardKpis(
      totalItems: items.where((InventoryItem i) => i.active).length,
      belowMin: belowMin,
      nearExpiryLots: nearExpiry,
      expiredLots: expired,
      stockValueCents: stockValue,
      monthConsumption: consumption,
      losses: losses,
      pendingPurchases: pendingPurchases,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[totalItems, belowMin, nearExpiryLots, expiredLots];
}
