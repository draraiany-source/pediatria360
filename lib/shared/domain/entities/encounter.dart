import 'package:equatable/equatable.dart';

import 'clinical_record.dart';

/// Um atendimento completo — a unidade do prontuário.
///
/// ## Imutabilidade após a assinatura
///
/// Depois de assinado, o atendimento **não é editado**. Uma correção gera um
/// registro de retificação vinculado, preservando o original. É o mesmo
/// princípio do prontuário em papel: rasura invalida. Aqui, o histórico
/// completo é o que protege tanto o paciente quanto o profissional.
class Encounter extends Equatable {
  const Encounter({
    required this.id,
    required this.patientId,
    required this.professionalId,
    required this.professionalName,
    required this.type,
    required this.status,
    required this.startedAt,
    this.professionalCrm,
    this.patientName,
    this.patientBirthDate,
    this.anamnesis = const Anamnesis(),
    this.vitals = const VitalSigns(),
    this.exam = const PhysicalExam(),
    this.diagnoses = const <Diagnosis>[],
    this.assessment = '',
    this.plan = '',
    this.procedures = const <ProcedureRecord>[],
    this.signedAt,
    this.signatureHash,
    this.amendsEncounterId,
    this.amendmentReason,
    this.appointmentId,
    this.attachmentIds = const <String>[],
  });

  final String id;

  /// Uid do responsável dono do cadastro da criança.
  final String patientId;

  final String professionalId;
  final String professionalName;
  final String? professionalCrm;

  final String? patientName;
  final DateTime? patientBirthDate;

  final EncounterType type;
  final EncounterStatus status;
  final DateTime startedAt;

  final Anamnesis anamnesis;
  final VitalSigns vitals;
  final PhysicalExam exam;
  final List<Diagnosis> diagnoses;

  /// Avaliação — o raciocínio clínico que liga achados a hipóteses.
  final String assessment;

  /// Conduta.
  final String plan;

  final List<ProcedureRecord> procedures;

  final DateTime? signedAt;

  /// Hash do conteúdo no momento da assinatura. Permite detectar alteração
  /// posterior no banco sem depender de confiar na infraestrutura.
  final String? signatureHash;

  /// Preenchido quando este atendimento retifica outro.
  final String? amendsEncounterId;
  final String? amendmentReason;

  final String? appointmentId;
  final List<String> attachmentIds;

  bool get isSigned => status != EncounterStatus.draft && signedAt != null;
  bool get isEditable => status == EncounterStatus.draft;

  Diagnosis? get primaryDiagnosis {
    for (final Diagnosis d in diagnoses) {
      if (d.type == DiagnosisType.primary) return d;
    }
    return diagnoses.isEmpty ? null : diagnoses.first;
  }

  /// Idade do paciente na data do atendimento — o que vale no registro é a
  /// idade de então, não a de hoje.
  int? get patientAgeMonthsAtEncounter {
    if (patientBirthDate == null) return null;
    int months = (startedAt.year - patientBirthDate!.year) * 12 +
        (startedAt.month - patientBirthDate!.month);
    if (startedAt.day < patientBirthDate!.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// Campos obrigatórios ausentes. A tela usa isto para bloquear a assinatura.
  List<String> get missingForSignature {
    final List<String> missing = <String>[];
    if (anamnesis.chiefComplaint.trim().isEmpty) {
      missing.add('Queixa principal');
    }
    if (exam.isEmpty && vitals.isEmpty) {
      missing.add('Exame físico ou sinais vitais');
    }
    if (diagnoses.isEmpty) missing.add('Ao menos um diagnóstico');
    if (plan.trim().isEmpty) missing.add('Conduta');
    return missing;
  }

  bool get canSign => missingForSignature.isEmpty;

  @override
  List<Object?> get props => <Object?>[id, status, signedAt, signatureHash];
}

/// Procedimento realizado no atendimento.
class ProcedureRecord extends Equatable {
  const ProcedureRecord({
    required this.name,
    this.code,
    this.description,
    this.performedAt,
    this.complications,
  });

  factory ProcedureRecord.fromMap(Map<String, dynamic> map) => ProcedureRecord(
        name: (map['name'] as String?) ?? '',
        code: map['code'] as String?,
        description: map['description'] as String?,
        performedAt: map['performedAt'] == null
            ? null
            : DateTime.tryParse(map['performedAt'] as String),
        complications: map['complications'] as String?,
      );

  final String name;

  /// Código do procedimento (TUSS ou SIGTAP).
  final String? code;

  final String? description;
  final DateTime? performedAt;

  /// Intercorrências. Campo separado e sempre visível: complicação registrada
  /// em nota de rodapé é complicação que ninguém lê.
  final String? complications;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'code': code,
        'description': description,
        'performedAt': performedAt?.toIso8601String(),
        'complications': complications,
      };

  @override
  List<Object?> get props => <Object?>[name, code, performedAt];
}

/// Um item prescrito.
///
/// ## Sobre a dose
///
/// O app **não sugere** dose. Os campos abaixo são preenchidos pelo prescritor.
/// O que a plataforma faz é aritmética de conferência: dado um mg/kg informado
/// por quem prescreve, calcula o total para o peso registrado e sinaliza se
/// ultrapassa o teto que o próprio prescritor definiu. Conferência, não
/// recomendação.
class PrescriptionItem extends Equatable {
  const PrescriptionItem({
    required this.drug,
    required this.presentation,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.duration,
    this.instructions,
    this.mgPerKg,
    this.calculatedDoseMg,
    this.isControlled = false,
    this.quantity,
  });

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) =>
      PrescriptionItem(
        drug: (map['drug'] as String?) ?? '',
        presentation: (map['presentation'] as String?) ?? '',
        dose: (map['dose'] as String?) ?? '',
        route: (map['route'] as String?) ?? 'Via oral',
        frequency: (map['frequency'] as String?) ?? '',
        duration: (map['duration'] as String?) ?? '',
        instructions: map['instructions'] as String?,
        mgPerKg: (map['mgPerKg'] as num?)?.toDouble(),
        calculatedDoseMg: (map['calculatedDoseMg'] as num?)?.toDouble(),
        isControlled: (map['isControlled'] as bool?) ?? false,
        quantity: map['quantity'] as String?,
      );

  final String drug;

  /// Apresentação: "suspensão 100 mg/mL", "comprimido 500 mg".
  final String presentation;

  /// Dose por administração, como será lida pelo responsável.
  final String dose;

  final String route;
  final String frequency;
  final String duration;
  final String? instructions;

  /// Informado pelo prescritor, quando quer a conferência por peso.
  final double? mgPerKg;

  /// Resultado da conta. Exibido ao lado da dose para conferência visual.
  final double? calculatedDoseMg;

  /// Medicamento sujeito a controle especial — muda o modelo do receituário.
  final bool isControlled;

  final String? quantity;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'drug': drug,
        'presentation': presentation,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
        'mgPerKg': mgPerKg,
        'calculatedDoseMg': calculatedDoseMg,
        'isControlled': isControlled,
        'quantity': quantity,
      };

  /// Linha como aparece na receita impressa.
  String get printedLine {
    final StringBuffer buffer = StringBuffer()
      ..write(drug);
    if (presentation.isNotEmpty) buffer.write(' — $presentation');
    return buffer.toString();
  }

  String get printedPosology {
    final List<String> parts = <String>[
      if (dose.isNotEmpty) dose,
      route,
      if (frequency.isNotEmpty) frequency,
      if (duration.isNotEmpty) duration,
    ];
    return parts.join(', ');
  }

  @override
  List<Object?> get props => <Object?>[drug, dose, frequency, duration];
}

/// Tipo de documento emitido no atendimento.
enum ClinicalDocumentType {
  prescription,
  certificate,
  referral,
  report,
  dischargeSummary,
  examRequest;

  static ClinicalDocumentType fromName(String? value) =>
      ClinicalDocumentType.values.firstWhere(
        (ClinicalDocumentType t) => t.name == value,
        orElse: () => ClinicalDocumentType.report,
      );

  String get label => switch (this) {
        ClinicalDocumentType.prescription => 'Receita',
        ClinicalDocumentType.certificate => 'Atestado',
        ClinicalDocumentType.referral => 'Encaminhamento',
        ClinicalDocumentType.report => 'Relatório médico',
        ClinicalDocumentType.dischargeSummary => 'Sumário de alta',
        ClinicalDocumentType.examRequest => 'Solicitação de exames',
      };

  String get icon => switch (this) {
        ClinicalDocumentType.prescription => 'medication',
        ClinicalDocumentType.certificate => 'description',
        ClinicalDocumentType.referral => 'send',
        ClinicalDocumentType.report => 'article',
        ClinicalDocumentType.dischargeSummary => 'assignment_turned_in',
        ClinicalDocumentType.examRequest => 'science',
      };
}

/// Documento emitido — receita, atestado, encaminhamento, relatório, alta.
///
/// ## Assinatura digital
///
/// O campo [signatureProvider] registra como o documento foi assinado. Para
/// validade legal plena no Brasil, receita e atestado precisam de certificado
/// **ICP-Brasil** (padrão CFM). A plataforma armazena o documento e o hash; a
/// assinatura em si é feita por provedor credenciado — ver a nota de
/// conformidade no README.
class ClinicalDocument extends Equatable {
  const ClinicalDocument({
    required this.id,
    required this.encounterId,
    required this.patientId,
    required this.professionalId,
    required this.type,
    required this.issuedAt,
    required this.content,
    this.professionalName,
    this.professionalCrm,
    this.patientName,
    this.items = const <PrescriptionItem>[],
    this.validUntil,
    this.pdfUrl,
    this.contentHash,
    this.signatureProvider,
    this.signedAt,
    this.verificationCode,
    this.cancelled = false,
    this.cancellationReason,
  });

  final String id;
  final String encounterId;
  final String patientId;
  final String professionalId;
  final ClinicalDocumentType type;
  final DateTime issuedAt;

  /// Corpo do documento. Para receita, o texto é gerado a partir de [items].
  final String content;

  final String? professionalName;
  final String? professionalCrm;
  final String? patientName;

  /// Itens prescritos, quando o documento é uma receita.
  final List<PrescriptionItem> items;

  /// Validade. Receita comum vale 30 dias; atestado tem prazo próprio.
  final DateTime? validUntil;

  final String? pdfUrl;

  /// Hash do conteúdo, para detectar adulteração.
  final String? contentHash;

  /// Provedor da assinatura digital, quando houver.
  final String? signatureProvider;

  final DateTime? signedAt;

  /// Código para conferência de autenticidade por terceiros — escola,
  /// empregador, farmácia.
  final String? verificationCode;

  final bool cancelled;
  final String? cancellationReason;

  bool get isSigned => signedAt != null;

  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  bool get isValid => !cancelled && !isExpired;

  /// `true` se contém medicamento de controle especial.
  bool get hasControlledDrug =>
      items.any((PrescriptionItem i) => i.isControlled);

  @override
  List<Object?> get props =>
      <Object?>[id, type, issuedAt, signedAt, cancelled];
}

/// Resultado de exame registrado.
///
/// ## O que este registro é — e o que não é
///
/// É um **registro estruturado de valores**: analito, resultado, unidade,
/// faixa de referência, data. A plataforma sinaliza quando um valor está fora
/// da faixa para a idade.
///
/// **A plataforma não interpreta exames.** Sinalizar "hemoglobina abaixo da
/// faixa" é comparação numérica. Dizer o que isso significa naquela criança é
/// ato médico, e fica com o médico.
class LabResult extends Equatable {
  const LabResult({
    required this.id,
    required this.patientId,
    required this.analyte,
    required this.collectedAt,
    this.value,
    this.textValue,
    this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.laboratory,
    this.panel,
    this.encounterId,
    this.attachmentUrl,
    this.note,
  });

  final String id;
  final String patientId;

  /// Nome do analito: "Hemoglobina", "Leucócitos", "PCR".
  final String analyte;

  final DateTime collectedAt;

  /// Resultado numérico.
  final double? value;

  /// Resultado textual, para exames qualitativos ("Reagente", "Ausente").
  final String? textValue;

  final String? unit;

  /// Faixa de referência **para a idade da criança** — a mesma hemoglobina é
  /// normal aos 6 meses e anêmica aos 6 anos.
  final double? referenceLow;
  final double? referenceHigh;

  final String? laboratory;

  /// Painel a que pertence: "Hemograma", "Função renal".
  final String? panel;

  final String? encounterId;
  final String? attachmentUrl;
  final String? note;

  /// `true` se está fora da faixa. Comparação numérica, não interpretação.
  bool get isOutOfRange {
    if (value == null) return false;
    if (referenceLow != null && value! < referenceLow!) return true;
    if (referenceHigh != null && value! > referenceHigh!) return true;
    return false;
  }

  /// Direção do desvio, quando houver.
  String? get deviation {
    if (value == null) return null;
    if (referenceLow != null && value! < referenceLow!) return 'abaixo';
    if (referenceHigh != null && value! > referenceHigh!) return 'acima';
    return null;
  }

  String get displayValue {
    if (textValue != null && textValue!.isNotEmpty) return textValue!;
    if (value == null) return '—';
    final String formatted = value! % 1 == 0
        ? value!.toStringAsFixed(0)
        : value!.toStringAsFixed(2).replaceAll('.', ',');
    return unit == null ? formatted : '$formatted $unit';
  }

  String? get referenceLabel {
    if (referenceLow == null && referenceHigh == null) return null;
    final String low = referenceLow?.toStringAsFixed(1).replaceAll('.', ',') ?? '';
    final String high = referenceHigh?.toStringAsFixed(1).replaceAll('.', ',') ?? '';
    if (referenceLow != null && referenceHigh != null) return '$low – $high';
    if (referenceLow != null) return '> $low';
    return '< $high';
  }

  @override
  List<Object?> get props => <Object?>[id, analyte, collectedAt, value];
}
