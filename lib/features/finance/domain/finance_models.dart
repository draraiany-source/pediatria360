import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ReceivableStatus {
  pending,
  paid,
  partial,
  overdue,
  cancelled,
  refunded;

  static ReceivableStatus fromName(String? value) =>
      ReceivableStatus.values.firstWhere(
        (ReceivableStatus s) => s.name == value,
        orElse: () => ReceivableStatus.pending,
      );

  String get label => switch (this) {
        ReceivableStatus.pending => 'Pendente',
        ReceivableStatus.paid => 'Pago',
        ReceivableStatus.partial => 'Parcial',
        ReceivableStatus.overdue => 'Em atraso',
        ReceivableStatus.cancelled => 'Cancelado',
        ReceivableStatus.refunded => 'Estornado',
      };

  bool get isOpen =>
      this == ReceivableStatus.pending ||
      this == ReceivableStatus.partial ||
      this == ReceivableStatus.overdue;
}

enum PayableStatus {
  pending,
  paid,
  partial,
  overdue,
  cancelled,
  negotiation;

  static PayableStatus fromName(String? value) => PayableStatus.values.firstWhere(
        (PayableStatus s) => s.name == value,
        orElse: () => PayableStatus.pending,
      );

  String get label => switch (this) {
        PayableStatus.pending => 'Pendente',
        PayableStatus.paid => 'Pago',
        PayableStatus.partial => 'Parcial',
        PayableStatus.overdue => 'Em atraso',
        PayableStatus.cancelled => 'Cancelado',
        PayableStatus.negotiation => 'Em negociacao',
      };
}

enum PaymentMethodKind {
  pix,
  card,
  cash,
  transfer,
  insurance,
  other;

  static PaymentMethodKind fromName(String? value) =>
      PaymentMethodKind.values.firstWhere(
        (PaymentMethodKind m) => m.name == value,
        orElse: () => PaymentMethodKind.other,
      );

  String get label => switch (this) {
        PaymentMethodKind.pix => 'PIX',
        PaymentMethodKind.card => 'Cartao',
        PaymentMethodKind.cash => 'Dinheiro',
        PaymentMethodKind.transfer => 'Transferencia',
        PaymentMethodKind.insurance => 'Convenio',
        PaymentMethodKind.other => 'Outro',
      };
}

enum RevenueOrigin {
  private_,
  insurance,
  package_,
  teleconsult,
  other;

  static RevenueOrigin fromName(String? value) {
    switch (value) {
      case 'private':
        return RevenueOrigin.private_;
      case 'insurance':
        return RevenueOrigin.insurance;
      case 'package':
        return RevenueOrigin.package_;
      case 'teleconsult':
        return RevenueOrigin.teleconsult;
      default:
        return RevenueOrigin.other;
    }
  }

  String get firestoreName => switch (this) {
        RevenueOrigin.private_ => 'private',
        RevenueOrigin.insurance => 'insurance',
        RevenueOrigin.package_ => 'package',
        RevenueOrigin.teleconsult => 'teleconsult',
        RevenueOrigin.other => 'other',
      };

  String get label => switch (this) {
        RevenueOrigin.private_ => 'Particular',
        RevenueOrigin.insurance => 'Convenio',
        RevenueOrigin.package_ => 'Pacote',
        RevenueOrigin.teleconsult => 'Teleconsulta',
        RevenueOrigin.other => 'Outro',
      };
}

enum ExpenseCategory {
  rent,
  staff,
  materials,
  medicines,
  technology,
  marketing,
  taxes,
  services,
  other;

  static ExpenseCategory fromName(String? value) =>
      ExpenseCategory.values.firstWhere(
        (ExpenseCategory c) => c.name == value,
        orElse: () => ExpenseCategory.other,
      );

  String get label => switch (this) {
        ExpenseCategory.rent => 'Aluguel',
        ExpenseCategory.staff => 'Pessoal',
        ExpenseCategory.materials => 'Materiais',
        ExpenseCategory.medicines => 'Medicamentos',
        ExpenseCategory.technology => 'Tecnologia',
        ExpenseCategory.marketing => 'Marketing',
        ExpenseCategory.taxes => 'Impostos',
        ExpenseCategory.services => 'Servicos',
        ExpenseCategory.other => 'Outros',
      };
}

enum FinancePeriodFilter {
  today,
  week,
  month,
  quarter,
  year,
  custom;

  String get label => switch (this) {
        FinancePeriodFilter.today => 'Hoje',
        FinancePeriodFilter.week => 'Semana',
        FinancePeriodFilter.month => 'Mes',
        FinancePeriodFilter.quarter => 'Trimestre',
        FinancePeriodFilter.year => 'Ano',
        FinancePeriodFilter.custom => 'Personalizado',
      };
}

enum FinanceAuditAction {
  receivableCreated,
  paymentRegistered,
  receivableCancelled,
  receivableRefunded,
  payableCreated,
  payablePaid,
  payableNegotiation,
  receiptIssued,
  syncFromAppointments;

  String get label => switch (this) {
        FinanceAuditAction.receivableCreated => 'Conta a receber criada',
        FinanceAuditAction.paymentRegistered => 'Pagamento registrado',
        FinanceAuditAction.receivableCancelled => 'Conta cancelada',
        FinanceAuditAction.receivableRefunded => 'Estorno',
        FinanceAuditAction.payableCreated => 'Conta a pagar criada',
        FinanceAuditAction.payablePaid => 'Conta paga',
        FinanceAuditAction.payableNegotiation => 'Negociacao',
        FinanceAuditAction.receiptIssued => 'Recibo emitido',
        FinanceAuditAction.syncFromAppointments => 'Sync agenda',
      };
}

/// Intervalo de datas para filtros e agregadores.
class FinancePeriod extends Equatable {
  const FinancePeriod({
    required this.start,
    required this.end,
    required this.filter,
  });

  final DateTime start;
  final DateTime end;
  final FinancePeriodFilter filter;

  static FinancePeriod resolve({
    required FinancePeriodFilter filter,
    required DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case FinancePeriodFilter.today:
        return FinancePeriod(
          start: dayStart,
          end: dayStart.add(const Duration(days: 1)),
          filter: filter,
        );
      case FinancePeriodFilter.week:
        final int weekday = now.weekday;
        final DateTime weekStart =
            dayStart.subtract(Duration(days: weekday - 1));
        return FinancePeriod(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)),
          filter: filter,
        );
      case FinancePeriodFilter.month:
        return FinancePeriod(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
          filter: filter,
        );
      case FinancePeriodFilter.quarter:
        final int q = ((now.month - 1) ~/ 3) + 1;
        final int startMonth = (q - 1) * 3 + 1;
        return FinancePeriod(
          start: DateTime(now.year, startMonth),
          end: DateTime(now.year, startMonth + 3),
          filter: filter,
        );
      case FinancePeriodFilter.year:
        return FinancePeriod(
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
          filter: filter,
        );
      case FinancePeriodFilter.custom:
        final DateTime s = customStart ?? dayStart;
        final DateTime e = customEnd ?? now.add(const Duration(days: 1));
        return FinancePeriod(start: s, end: e, filter: filter);
    }
  }

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  @override
  List<Object?> get props => <Object?>[start, end, filter];
}

class FinanceReceivable extends Equatable {
  const FinanceReceivable({
    required this.id,
    required this.ownerId,
    required this.totalCents,
    required this.paidCents,
    required this.status,
    required this.dueAt,
    required this.createdAt,
    this.patientId,
    this.childId,
    this.appointmentId,
    this.description = '',
    this.origin = RevenueOrigin.private_,
    this.professionalId,
    this.professionalName,
    this.refundedCents = 0,
    this.cancelledAt,
    this.updatedAt,
    this.batchId,
    this.guideId,
    this.planId,
  });

  factory FinanceReceivable.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return FinanceReceivable(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
      paidCents: (data['paidCents'] as num?)?.toInt() ?? 0,
      status: ReceivableStatus.fromName(data['status'] as String?),
      dueAt: _readDate(data['dueAt']),
      createdAt: _readDate(data['createdAt']),
      patientId: data['patientId'] as String?,
      childId: data['childId'] as String?,
      appointmentId: data['appointmentId'] as String?,
      description: (data['description'] as String?) ?? '',
      origin: RevenueOrigin.fromName(data['origin'] as String?),
      professionalId: data['professionalId'] as String?,
      professionalName: data['professionalName'] as String?,
      refundedCents: (data['refundedCents'] as num?)?.toInt() ?? 0,
      cancelledAt: _readDateOrNull(data['cancelledAt']),
      updatedAt: _readDateOrNull(data['updatedAt']),
      batchId: data['batchId'] as String?,
      guideId: data['guideId'] as String?,
      planId: data['planId'] as String?,
    );
  }

  final String id;
  final String ownerId;
  final int totalCents;
  final int paidCents;
  final ReceivableStatus status;
  final DateTime dueAt;
  final DateTime createdAt;
  final String? patientId;
  final String? childId;
  final String? appointmentId;
  final String description;
  final RevenueOrigin origin;
  final String? professionalId;
  final String? professionalName;
  final int refundedCents;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;
  final String? batchId;
  final String? guideId;
  final String? planId;

  int get openCents {
    if (status == ReceivableStatus.cancelled) return 0;
    final int open = totalCents - paidCents - refundedCents;
    return open < 0 ? 0 : open;
  }

  ReceivableStatus effectiveStatus(DateTime now) {
    if (status == ReceivableStatus.cancelled ||
        status == ReceivableStatus.refunded) {
      return status;
    }
    if (openCents <= 0) return ReceivableStatus.paid;
    if (paidCents > 0) {
      if (dueAt.isBefore(now)) return ReceivableStatus.overdue;
      return ReceivableStatus.partial;
    }
    if (dueAt.isBefore(now)) return ReceivableStatus.overdue;
    return ReceivableStatus.pending;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'totalCents': totalCents,
        'paidCents': paidCents,
        'status': status.name,
        'dueAt': Timestamp.fromDate(dueAt),
        'createdAt': Timestamp.fromDate(createdAt),
        if (patientId != null) 'patientId': patientId,
        if (childId != null) 'childId': childId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        'description': description,
        'origin': origin.firestoreName,
        if (professionalId != null) 'professionalId': professionalId,
        if (professionalName != null) 'professionalName': professionalName,
        'refundedCents': refundedCents,
        if (cancelledAt != null)
          'cancelledAt': Timestamp.fromDate(cancelledAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (batchId != null) 'batchId': batchId,
        if (guideId != null) 'guideId': guideId,
        if (planId != null) 'planId': planId,
      };

  FinanceReceivable copyWith({
    int? totalCents,
    int? paidCents,
    ReceivableStatus? status,
    int? refundedCents,
    DateTime? cancelledAt,
    DateTime? updatedAt,
    String? batchId,
    String? guideId,
    String? planId,
  }) =>
      FinanceReceivable(
        id: id,
        ownerId: ownerId,
        totalCents: totalCents ?? this.totalCents,
        paidCents: paidCents ?? this.paidCents,
        status: status ?? this.status,
        dueAt: dueAt,
        createdAt: createdAt,
        patientId: patientId,
        childId: childId,
        appointmentId: appointmentId,
        description: description,
        origin: origin,
        professionalId: professionalId,
        professionalName: professionalName,
        refundedCents: refundedCents ?? this.refundedCents,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        updatedAt: updatedAt ?? this.updatedAt,
        batchId: batchId ?? this.batchId,
        guideId: guideId ?? this.guideId,
        planId: planId ?? this.planId,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, ownerId, totalCents, paidCents, status, appointmentId];
}

class FinancePayable extends Equatable {
  const FinancePayable({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.category,
    required this.amountCents,
    required this.paidCents,
    required this.status,
    required this.dueAt,
    required this.createdAt,
    this.negotiationNotes,
    this.updatedAt,
  });

  factory FinancePayable.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return FinancePayable(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      category: ExpenseCategory.fromName(data['category'] as String?),
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      paidCents: (data['paidCents'] as num?)?.toInt() ?? 0,
      status: PayableStatus.fromName(data['status'] as String?),
      dueAt: _readDate(data['dueAt']),
      createdAt: _readDate(data['createdAt']),
      negotiationNotes: data['negotiationNotes'] as String?,
      updatedAt: _readDateOrNull(data['updatedAt']),
    );
  }

  final String id;
  final String ownerId;
  final String description;
  final ExpenseCategory category;
  final int amountCents;
  final int paidCents;
  final PayableStatus status;
  final DateTime dueAt;
  final DateTime createdAt;
  final String? negotiationNotes;
  final DateTime? updatedAt;

  int get openCents {
    if (status == PayableStatus.cancelled) return 0;
    final int open = amountCents - paidCents;
    return open < 0 ? 0 : open;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'description': description,
        'category': category.name,
        'amountCents': amountCents,
        'paidCents': paidCents,
        'status': status.name,
        'dueAt': Timestamp.fromDate(dueAt),
        'createdAt': Timestamp.fromDate(createdAt),
        if (negotiationNotes != null) 'negotiationNotes': negotiationNotes,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  @override
  List<Object?> get props => <Object?>[id, ownerId, amountCents, status];
}

class FinanceReceipt extends Equatable {
  const FinanceReceipt({
    required this.id,
    required this.ownerId,
    required this.receivableId,
    required this.amountCents,
    required this.method,
    required this.issuedAt,
    this.patientId,
    this.receiptNumber,
    this.notes,
  });

  factory FinanceReceipt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return FinanceReceipt(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      receivableId: (data['receivableId'] as String?) ?? '',
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      method: PaymentMethodKind.fromName(data['method'] as String?),
      issuedAt: _readDate(data['issuedAt']),
      patientId: data['patientId'] as String?,
      receiptNumber: data['receiptNumber'] as String?,
      notes: data['notes'] as String?,
    );
  }

  final String id;
  final String ownerId;
  final String receivableId;
  final int amountCents;
  final PaymentMethodKind method;
  final DateTime issuedAt;
  final String? patientId;
  final String? receiptNumber;
  final String? notes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'receivableId': receivableId,
        'amountCents': amountCents,
        'method': method.name,
        'issuedAt': Timestamp.fromDate(issuedAt),
        if (patientId != null) 'patientId': patientId,
        if (receiptNumber != null) 'receiptNumber': receiptNumber,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => <Object?>[id, receivableId, amountCents];
}

class FinanceAuditEntry extends Equatable {
  const FinanceAuditEntry({
    required this.id,
    required this.ownerId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.at,
    required this.byUserId,
    this.metadata = const <String, dynamic>{},
  });

  factory FinanceAuditEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return FinanceAuditEntry(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      action: FinanceAuditAction.values.firstWhere(
        (FinanceAuditAction a) => a.name == data['action'],
        orElse: () => FinanceAuditAction.receivableCreated,
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
  final FinanceAuditAction action;
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

DateTime _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

DateTime? _readDateOrNull(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
