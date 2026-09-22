import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:equatable/equatable.dart';



enum CoverageType {

  private_,

  insurance,

  plan;



  static CoverageType fromName(String? value) {

    switch (value) {

      case 'private':

        return CoverageType.private_;

      case 'insurance':

        return CoverageType.insurance;

      case 'plan':

        return CoverageType.plan;

      default:

        return CoverageType.insurance;

    }

  }



  String get firestoreName => switch (this) {

        CoverageType.private_ => 'private',

        CoverageType.insurance => 'insurance',

        CoverageType.plan => 'plan',

      };



  String get label => switch (this) {

        CoverageType.private_ => 'Particular',

        CoverageType.insurance => 'Convenio',

        CoverageType.plan => 'Plano',

      };

}



enum AuthorizationStatus {

  pending,

  authorized,

  denied,

  expired,

  cancelled;



  static AuthorizationStatus fromName(String? value) =>

      AuthorizationStatus.values.firstWhere(

        (AuthorizationStatus s) => s.name == value,

        orElse: () => AuthorizationStatus.pending,

      );

}



enum BillingGuideType {

  consultation,

  procedure,

  exam,

  therapy,

  admission;



  static BillingGuideType fromName(String? value) =>

      BillingGuideType.values.firstWhere(

        (BillingGuideType t) => t.name == value,

        orElse: () => BillingGuideType.consultation,

      );

}



enum BillingGuideStatus {

  draft,

  ready,

  inBatch,

  sent,

  paid,

  glosed,

  cancelled;



  static BillingGuideStatus fromName(String? value) =>

      BillingGuideStatus.values.firstWhere(

        (BillingGuideStatus s) => s.name == value,

        orElse: () => BillingGuideStatus.draft,

      );

}



enum BillingBatchStatus {

  open,

  closed,

  sent,

  processing,

  paid,

  withGlosa,

  cancelled;



  static BillingBatchStatus fromName(String? value) =>

      BillingBatchStatus.values.firstWhere(

        (BillingBatchStatus s) => s.name == value,

        orElse: () => BillingBatchStatus.open,

      );

}



enum BillingGlosaStatus {

  new_,

  analyzing,

  appealPrep,

  appealSent,

  accepted,

  denied,

  resolved;



  static BillingGlosaStatus fromName(String? value) {

    if (value == 'new') return BillingGlosaStatus.new_;

    return BillingGlosaStatus.values.firstWhere(

      (BillingGlosaStatus s) => s.name == value,

      orElse: () => BillingGlosaStatus.new_,

    );

  }



  String get firestoreName => switch (this) {

        BillingGlosaStatus.new_ => 'new',

        BillingGlosaStatus.analyzing => 'analyzing',

        BillingGlosaStatus.appealPrep => 'appealPrep',

        BillingGlosaStatus.appealSent => 'appealSent',

        BillingGlosaStatus.accepted => 'accepted',

        BillingGlosaStatus.denied => 'denied',

        BillingGlosaStatus.resolved => 'resolved',

      };

}



enum BillingAuditAction {

  planCreated,

  guideCreated,

  batchClosed,

  batchSent,

  batchReturn,

  glosaCreated,

  appealUpdated,

  financeSync;



  String get label => switch (this) {

        BillingAuditAction.planCreated => 'Plano cadastrado',

        BillingAuditAction.guideCreated => 'Guia criada',

        BillingAuditAction.batchClosed => 'Lote fechado',

        BillingAuditAction.batchSent => 'Lote enviado',

        BillingAuditAction.batchReturn => 'Retorno do lote',

        BillingAuditAction.glosaCreated => 'Glosa registrada',

        BillingAuditAction.appealUpdated => 'Recurso atualizado',

        BillingAuditAction.financeSync => 'Sync financeiro',

      };

}



class InsurancePlan extends Equatable {

  const InsurancePlan({

    required this.id,

    required this.ownerId,

    required this.operatorName,

    required this.planName,

    this.code = '',

    this.registryNumber = '',

    this.feeTableJson,

    this.feeNotes = '',

    this.validFrom,

    this.validUntil,

    this.rules = '',

    this.notes = '',

    this.active = true,

  });



  factory InsurancePlan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return InsurancePlan(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      operatorName: (data['operatorName'] as String?) ?? '',

      planName: (data['planName'] as String?) ?? '',

      code: (data['code'] as String?) ?? '',

      registryNumber: (data['registryNumber'] as String?) ?? '',

      feeTableJson: data['feeTableJson'] as String?,

      feeNotes: (data['feeNotes'] as String?) ?? '',

      validFrom: _readDateOrNull(data['validFrom']),

      validUntil: _readDateOrNull(data['validUntil']),

      rules: (data['rules'] as String?) ?? '',

      notes: (data['notes'] as String?) ?? '',

      active: (data['active'] as bool?) ?? true,

    );

  }



  final String id;

  final String ownerId;

  final String operatorName;

  final String planName;

  final String code;

  final String registryNumber;

  final String? feeTableJson;

  final String feeNotes;

  final DateTime? validFrom;

  final DateTime? validUntil;

  final String rules;

  final String notes;

  final bool active;



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        'operatorName': operatorName,

        'planName': planName,

        'code': code,

        'registryNumber': registryNumber,

        if (feeTableJson != null) 'feeTableJson': feeTableJson,

        'feeNotes': feeNotes,

        if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),

        if (validUntil != null) 'validUntil': Timestamp.fromDate(validUntil!),

        'rules': rules,

        'notes': notes,

        'active': active,

      };



  @override

  List<Object?> get props => <Object?>[id, ownerId, operatorName, planName];

}



class PatientInsurance extends Equatable {

  const PatientInsurance({

    required this.id,

    required this.ownerId,

    required this.childId,

    required this.coverageType,

    this.patientId,

    this.planId,

    this.cardNumber = '',

    this.validUntil,

    this.holderName = '',

    this.isDependent = false,

    this.notes = '',

  });



  factory PatientInsurance.fromFirestore(

    DocumentSnapshot<Map<String, dynamic>> doc,

  ) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return PatientInsurance(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      childId: (data['childId'] as String?) ?? '',

      patientId: data['patientId'] as String?,

      coverageType: CoverageType.fromName(data['coverageType'] as String?),

      planId: data['planId'] as String?,

      cardNumber: (data['cardNumber'] as String?) ?? '',

      validUntil: _readDateOrNull(data['validUntil']),

      holderName: (data['holderName'] as String?) ?? '',

      isDependent: (data['isDependent'] as bool?) ?? false,

      notes: (data['notes'] as String?) ?? '',

    );

  }



  final String id;

  final String ownerId;

  final String childId;

  final String? patientId;

  final CoverageType coverageType;

  final String? planId;

  final String cardNumber;

  final DateTime? validUntil;

  final String holderName;

  final bool isDependent;

  final String notes;



  bool isCardValid(DateTime now) {

    if (coverageType == CoverageType.private_) return true;

    if (validUntil == null) return true;

    return !validUntil!.isBefore(DateTime(now.year, now.month, now.day));

  }



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        'childId': childId,

        if (patientId != null) 'patientId': patientId,

        'coverageType': coverageType.firestoreName,

        if (planId != null) 'planId': planId,

        'cardNumber': cardNumber,

        if (validUntil != null) 'validUntil': Timestamp.fromDate(validUntil!),

        'holderName': holderName,

        'isDependent': isDependent,

        'notes': notes,

      };



  @override

  List<Object?> get props => <Object?>[id, childId, planId, cardNumber];

}



class InsuranceAuthorization extends Equatable {

  const InsuranceAuthorization({

    required this.id,

    required this.ownerId,

    required this.childId,

    this.patientId,

    this.planId,

    this.procedureCode = '',

    this.procedureName = '',

    this.professionalId,

    required this.requestedAt,

    this.authNumber = '',

    this.validUntil,

    this.qtyAuthorized = 1,

    this.status = AuthorizationStatus.pending,

    this.notes = '',

  });



  factory InsuranceAuthorization.fromFirestore(

    DocumentSnapshot<Map<String, dynamic>> doc,

  ) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return InsuranceAuthorization(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      childId: (data['childId'] as String?) ?? '',

      patientId: data['patientId'] as String?,

      planId: data['planId'] as String?,

      procedureCode: (data['procedureCode'] as String?) ?? '',

      procedureName: (data['procedureName'] as String?) ?? '',

      professionalId: data['professionalId'] as String?,

      requestedAt: _readDate(data['requestedAt']),

      authNumber: (data['authNumber'] as String?) ?? '',

      validUntil: _readDateOrNull(data['validUntil']),

      qtyAuthorized: (data['qtyAuthorized'] as num?)?.toInt() ?? 1,

      status: AuthorizationStatus.fromName(data['status'] as String?),

      notes: (data['notes'] as String?) ?? '',

    );

  }



  final String id;

  final String ownerId;

  final String childId;

  final String? patientId;

  final String? planId;

  final String procedureCode;

  final String procedureName;

  final String? professionalId;

  final DateTime requestedAt;

  final String authNumber;

  final DateTime? validUntil;

  final int qtyAuthorized;

  final AuthorizationStatus status;

  final String notes;



  bool isActiveAuth(DateTime now) {

    if (status != AuthorizationStatus.authorized) return false;

    if (validUntil == null) return true;

    return !validUntil!.isBefore(now);

  }



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        'childId': childId,

        if (patientId != null) 'patientId': patientId,

        if (planId != null) 'planId': planId,

        'procedureCode': procedureCode,

        'procedureName': procedureName,

        if (professionalId != null) 'professionalId': professionalId,

        'requestedAt': Timestamp.fromDate(requestedAt),

        'authNumber': authNumber,

        if (validUntil != null) 'validUntil': Timestamp.fromDate(validUntil!),

        'qtyAuthorized': qtyAuthorized,

        'status': status.name,

        'notes': notes,

      };



  @override

  List<Object?> get props => <Object?>[id, childId, status, authNumber];

}



class BillingGuide extends Equatable {

  const BillingGuide({

    required this.id,

    required this.ownerId,

    required this.type,

    required this.childId,

    this.patientId,

    this.beneficiaryName = '',

    this.planId,

    this.professionalId,

    this.procedureCode = '',

    this.procedureName = '',

    this.cid = '',

    required this.serviceDate,

    required this.amountCents,

    this.authorizationId,

    this.appointmentId,

    this.status = BillingGuideStatus.draft,

    this.batchId,

  });



  factory BillingGuide.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return BillingGuide(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      type: BillingGuideType.fromName(data['type'] as String?),

      childId: (data['childId'] as String?) ?? '',

      patientId: data['patientId'] as String?,

      beneficiaryName: (data['beneficiaryName'] as String?) ?? '',

      planId: data['planId'] as String?,

      professionalId: data['professionalId'] as String?,

      procedureCode: (data['procedureCode'] as String?) ?? '',

      procedureName: (data['procedureName'] as String?) ?? '',

      cid: (data['cid'] as String?) ?? '',

      serviceDate: _readDate(data['serviceDate']),

      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,

      authorizationId: data['authorizationId'] as String?,

      appointmentId: data['appointmentId'] as String?,

      status: BillingGuideStatus.fromName(data['status'] as String?),

      batchId: data['batchId'] as String?,

    );

  }



  final String id;

  final String ownerId;

  final BillingGuideType type;

  final String childId;

  final String? patientId;

  final String beneficiaryName;

  final String? planId;

  final String? professionalId;

  final String procedureCode;

  final String procedureName;

  final String cid;

  final DateTime serviceDate;

  final int amountCents;

  final String? authorizationId;

  final String? appointmentId;

  final BillingGuideStatus status;

  final String? batchId;



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        'type': type.name,

        'childId': childId,

        if (patientId != null) 'patientId': patientId,

        'beneficiaryName': beneficiaryName,

        if (planId != null) 'planId': planId,

        if (professionalId != null) 'professionalId': professionalId,

        'procedureCode': procedureCode,

        'procedureName': procedureName,

        'cid': cid,

        'serviceDate': Timestamp.fromDate(serviceDate),

        'amountCents': amountCents,

        if (authorizationId != null) 'authorizationId': authorizationId,

        if (appointmentId != null) 'appointmentId': appointmentId,

        'status': status.name,

        if (batchId != null) 'batchId': batchId,

      };



  BillingGuide copyWith({

    BillingGuideStatus? status,

    String? batchId,

  }) =>

      BillingGuide(

        id: id,

        ownerId: ownerId,

        type: type,

        childId: childId,

        patientId: patientId,

        beneficiaryName: beneficiaryName,

        planId: planId,

        professionalId: professionalId,

        procedureCode: procedureCode,

        procedureName: procedureName,

        cid: cid,

        serviceDate: serviceDate,

        amountCents: amountCents,

        authorizationId: authorizationId,

        appointmentId: appointmentId,

        status: status ?? this.status,

        batchId: batchId ?? this.batchId,

      );



  @override

  List<Object?> get props => <Object?>[id, childId, amountCents, status];

}



class BillingBatch extends Equatable {

  const BillingBatch({

    required this.id,

    required this.ownerId,

    this.planId,

    required this.periodStart,

    required this.periodEnd,

    this.guideIds = const <String>[],

    this.guideCount = 0,

    this.totalCents = 0,

    this.status = BillingBatchStatus.open,

    this.protocol = '',

    this.sentAt,

    this.returnAt,

    this.returnNotes = '',

  });



  factory BillingBatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return BillingBatch(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      planId: data['planId'] as String?,

      periodStart: _readDate(data['periodStart']),

      periodEnd: _readDate(data['periodEnd']),

      guideIds: List<String>.from(

        (data['guideIds'] as List<dynamic>?) ?? const <dynamic>[],

      ),

      guideCount: (data['guideCount'] as num?)?.toInt() ?? 0,

      totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,

      status: BillingBatchStatus.fromName(data['status'] as String?),

      protocol: (data['protocol'] as String?) ?? '',

      sentAt: _readDateOrNull(data['sentAt']),

      returnAt: _readDateOrNull(data['returnAt']),

      returnNotes: (data['returnNotes'] as String?) ?? '',

    );

  }



  final String id;

  final String ownerId;

  final String? planId;

  final DateTime periodStart;

  final DateTime periodEnd;

  final List<String> guideIds;

  final int guideCount;

  final int totalCents;

  final BillingBatchStatus status;

  final String protocol;

  final DateTime? sentAt;

  final DateTime? returnAt;

  final String returnNotes;



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        if (planId != null) 'planId': planId,

        'periodStart': Timestamp.fromDate(periodStart),

        'periodEnd': Timestamp.fromDate(periodEnd),

        'guideIds': guideIds,

        'guideCount': guideCount,

        'totalCents': totalCents,

        'status': status.name,

        'protocol': protocol,

        if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),

        if (returnAt != null) 'returnAt': Timestamp.fromDate(returnAt!),

        'returnNotes': returnNotes,

      };



  BillingBatch copyWith({

    List<String>? guideIds,

    int? guideCount,

    int? totalCents,

    BillingBatchStatus? status,

    String? protocol,

    DateTime? sentAt,

    DateTime? returnAt,

    String? returnNotes,

  }) =>

      BillingBatch(

        id: id,

        ownerId: ownerId,

        planId: planId,

        periodStart: periodStart,

        periodEnd: periodEnd,

        guideIds: guideIds ?? this.guideIds,

        guideCount: guideCount ?? this.guideCount,

        totalCents: totalCents ?? this.totalCents,

        status: status ?? this.status,

        protocol: protocol ?? this.protocol,

        sentAt: sentAt ?? this.sentAt,

        returnAt: returnAt ?? this.returnAt,

        returnNotes: returnNotes ?? this.returnNotes,

      );



  @override

  List<Object?> get props => <Object?>[id, status, guideCount, totalCents];

}



class BillingGlosa extends Equatable {

  const BillingGlosa({

    required this.id,

    required this.ownerId,

    required this.childId,

    this.appointmentId,

    this.planId,

    this.guideId,

    this.batchId,

    required this.billedCents,

    required this.glosedCents,

    this.reason = '',

    required this.glosaDate,

    this.status = BillingGlosaStatus.new_,

    this.notes = '',

    this.appealDeadline,

    this.appealJustification = '',

    this.appealDocsUrls = const <String>[],

    this.assigneeId,

    this.responseNotes = '',

  });



  factory BillingGlosa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return BillingGlosa(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      childId: (data['childId'] as String?) ?? '',

      appointmentId: data['appointmentId'] as String?,

      planId: data['planId'] as String?,

      guideId: data['guideId'] as String?,

      batchId: data['batchId'] as String?,

      billedCents: (data['billedCents'] as num?)?.toInt() ?? 0,

      glosedCents: (data['glosedCents'] as num?)?.toInt() ?? 0,

      reason: (data['reason'] as String?) ?? '',

      glosaDate: _readDate(data['glosaDate']),

      status: BillingGlosaStatus.fromName(data['status'] as String?),

      notes: (data['notes'] as String?) ?? '',

      appealDeadline: _readDateOrNull(data['appealDeadline']),

      appealJustification: (data['appealJustification'] as String?) ?? '',

      appealDocsUrls: List<String>.from(

        (data['appealDocsUrls'] as List<dynamic>?) ?? const <dynamic>[],

      ),

      assigneeId: data['assigneeId'] as String?,

      responseNotes: (data['responseNotes'] as String?) ?? '',

    );

  }



  final String id;

  final String ownerId;

  final String childId;

  final String? appointmentId;

  final String? planId;

  final String? guideId;

  final String? batchId;

  final int billedCents;

  final int glosedCents;

  final String reason;

  final DateTime glosaDate;

  final BillingGlosaStatus status;

  final String notes;

  final DateTime? appealDeadline;

  final String appealJustification;

  final List<String> appealDocsUrls;

  final String? assigneeId;

  final String responseNotes;



  Map<String, dynamic> toMap() => <String, dynamic>{

        'ownerId': ownerId,

        'childId': childId,

        if (appointmentId != null) 'appointmentId': appointmentId,

        if (planId != null) 'planId': planId,

        if (guideId != null) 'guideId': guideId,

        if (batchId != null) 'batchId': batchId,

        'billedCents': billedCents,

        'glosedCents': glosedCents,

        'reason': reason,

        'glosaDate': Timestamp.fromDate(glosaDate),

        'status': status.firestoreName,

        'notes': notes,

        if (appealDeadline != null)

          'appealDeadline': Timestamp.fromDate(appealDeadline!),

        'appealJustification': appealJustification,

        'appealDocsUrls': appealDocsUrls,

        if (assigneeId != null) 'assigneeId': assigneeId,

        'responseNotes': responseNotes,

      };



  BillingGlosa copyWith({

    BillingGlosaStatus? status,

    String? appealJustification,

    List<String>? appealDocsUrls,

    String? responseNotes,

  }) =>

      BillingGlosa(

        id: id,

        ownerId: ownerId,

        childId: childId,

        appointmentId: appointmentId,

        planId: planId,

        guideId: guideId,

        batchId: batchId,

        billedCents: billedCents,

        glosedCents: glosedCents,

        reason: reason,

        glosaDate: glosaDate,

        status: status ?? this.status,

        notes: notes,

        appealDeadline: appealDeadline,

        appealJustification: appealJustification ?? this.appealJustification,

        appealDocsUrls: appealDocsUrls ?? this.appealDocsUrls,

        assigneeId: assigneeId,

        responseNotes: responseNotes ?? this.responseNotes,

      );



  @override

  List<Object?> get props => <Object?>[id, guideId, glosedCents, status];

}



/// Esqueleto TISS — integracao real com operadora pendente (nao envia XML).

class TissExportStub extends Equatable {

  const TissExportStub({

    required this.batchId,

    required this.protocol,

    required this.guideCount,

    required this.totalCents,

  });



  final String batchId;

  final String protocol;

  final int guideCount;

  final int totalCents;



  /// Template XML sem transmissao — substituir quando houver conector TISS.

  String toTissXmlSkeleton() {

    return '''<?xml version="1.0" encoding="UTF-8"?>

<!-- PENDENTE: integracao operadora TISS — export local apenas -->

<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">

  <ans:cabecalho>

    <ans:identificacaoTransacao>

      <ans:lote>${batchId.replaceAll('&', '&amp;')}</ans:lote>

      <ans:protocolo>${protocol.replaceAll('&', '&amp;')}</ans:protocolo>

    </ans:identificacaoTransacao>

  </ans:cabecalho>

  <ans:prestadorParaOperadora>

    <ans:loteGuias>

      <ans:numeroLote>$guideCount</ans:numeroLote>

      <ans:valorTotal>$totalCents</ans:valorTotal>

    </ans:loteGuias>

  </ans:prestadorParaOperadora>

</ans:mensagemTISS>''';

  }



  @override

  List<Object?> get props => <Object?>[batchId, protocol, guideCount];

}



class BillingAuditEntry extends Equatable {

  const BillingAuditEntry({

    required this.id,

    required this.ownerId,

    required this.action,

    required this.entityType,

    required this.entityId,

    required this.at,

    required this.byUserId,

    this.metadata = const <String, dynamic>{},

  });



  factory BillingAuditEntry.fromFirestore(

    DocumentSnapshot<Map<String, dynamic>> doc,

  ) {

    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    return BillingAuditEntry(

      id: doc.id,

      ownerId: (data['ownerId'] as String?) ?? '',

      action: BillingAuditAction.values.firstWhere(

        (BillingAuditAction a) => a.name == data['action'],

        orElse: () => BillingAuditAction.guideCreated,

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

  final BillingAuditAction action;

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

  List<Object?> get props => <Object?>[id, action, entityId];

}



class BillingDashboardKpis extends Equatable {

  const BillingDashboardKpis({

    required this.billedMonth,

    required this.received,

    required this.pending,

    required this.glosed,

    required this.glosaRate,

    required this.avgDaysToReceive,

    this.topRevenuePlan,

    this.topGlosaPlan,

  });



  final int billedMonth;

  final int received;

  final int pending;

  final int glosed;

  final double glosaRate;

  final double avgDaysToReceive;

  final String? topRevenuePlan;

  final String? topGlosaPlan;



  @override

  List<Object?> get props =>

      <Object?>[billedMonth, received, pending, glosed, glosaRate];

}



DateTime _readDate(Object? value) {

  if (value is Timestamp) return value.toDate();

  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();

  return DateTime.now();

}



DateTime? _readDateOrNull(Object? value) {

  if (value == null) return null;

  if (value is Timestamp) return value.toDate();

  if (value is String) return DateTime.tryParse(value);

  return null;

}

