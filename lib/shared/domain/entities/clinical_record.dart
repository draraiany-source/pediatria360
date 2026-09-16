import 'package:equatable/equatable.dart';

/// Tipo de atendimento registrado.
enum EncounterType {
  routine,
  acute,
  followUp,
  emergency,
  telemedicine,
  procedure;

  static EncounterType fromName(String? value) =>
      EncounterType.values.firstWhere(
        (EncounterType t) => t.name == value,
        orElse: () => EncounterType.routine,
      );

  String get label => switch (this) {
        EncounterType.routine => 'Consulta de rotina',
        EncounterType.acute => 'Intercorrência',
        EncounterType.followUp => 'Retorno',
        EncounterType.emergency => 'Urgência',
        EncounterType.telemedicine => 'Teleconsulta',
        EncounterType.procedure => 'Procedimento',
      };
}

/// Situação do atendimento no fluxo de trabalho.
enum EncounterStatus {
  draft,
  signed,
  amended;

  static EncounterStatus fromName(String? value) =>
      EncounterStatus.values.firstWhere(
        (EncounterStatus s) => s.name == value,
        orElse: () => EncounterStatus.draft,
      );

  String get label => switch (this) {
        EncounterStatus.draft => 'Rascunho',
        EncounterStatus.signed => 'Assinado',
        EncounterStatus.amended => 'Retificado',
      };
}

/// Anamnese estruturada.
///
/// ## Por que campos separados em vez de um texto livre
///
/// Um bloco único de texto é mais rápido de escrever e inútil depois: não dá
/// para buscar "quem tem histórico familiar de asma", não dá para o assistente
/// clínico usar como contexto, e a próxima consulta começa do zero.
///
/// Os campos seguem a estrutura clássica da anamnese pediátrica, incluindo os
/// que só existem em pediatria — gestação, parto, desenvolvimento neuropsicomotor
/// e alimentação — que em adulto não fariam sentido.
class Anamnesis extends Equatable {
  const Anamnesis({
    this.chiefComplaint = '',
    this.historyOfPresentIllness = '',
    this.pastMedicalHistory = '',
    this.gestationalHistory = '',
    this.birthHistory = '',
    this.developmentHistory = '',
    this.feedingHistory = '',
    this.sleepHistory = '',
    this.eliminationHistory = '',
    this.immunizationStatus = '',
    this.allergies = const <String>[],
    this.currentMedications = const <String>[],
    this.familyHistory = '',
    this.socialHistory = '',
    this.reviewOfSystems = const <String, String>{},
  });

  factory Anamnesis.fromMap(Map<String, dynamic> map) => Anamnesis(
        chiefComplaint: (map['chiefComplaint'] as String?) ?? '',
        historyOfPresentIllness:
            (map['historyOfPresentIllness'] as String?) ?? '',
        pastMedicalHistory: (map['pastMedicalHistory'] as String?) ?? '',
        gestationalHistory: (map['gestationalHistory'] as String?) ?? '',
        birthHistory: (map['birthHistory'] as String?) ?? '',
        developmentHistory: (map['developmentHistory'] as String?) ?? '',
        feedingHistory: (map['feedingHistory'] as String?) ?? '',
        sleepHistory: (map['sleepHistory'] as String?) ?? '',
        eliminationHistory: (map['eliminationHistory'] as String?) ?? '',
        immunizationStatus: (map['immunizationStatus'] as String?) ?? '',
        allergies: _strings(map['allergies']),
        currentMedications: _strings(map['currentMedications']),
        familyHistory: (map['familyHistory'] as String?) ?? '',
        socialHistory: (map['socialHistory'] as String?) ?? '',
        reviewOfSystems:
            ((map['reviewOfSystems'] as Map<dynamic, dynamic>?) ??
                    const <dynamic, dynamic>{})
                .map(
          (dynamic k, dynamic v) =>
              MapEntry<String, String>(k.toString(), v.toString()),
        ),
      );

  /// Queixa principal, nas palavras de quem trouxe a criança.
  final String chiefComplaint;

  /// História da doença atual.
  final String historyOfPresentIllness;

  final String pastMedicalHistory;

  /// Pré-natal, intercorrências na gestação, uso de medicação.
  final String gestationalHistory;

  /// Tipo de parto, idade gestacional, Apgar, peso ao nascer, intercorrências.
  final String birthHistory;

  /// Marcos do desenvolvimento neuropsicomotor.
  final String developmentHistory;

  /// Aleitamento, introdução alimentar, hábitos atuais.
  final String feedingHistory;

  /// Qualidade e rotina de sono.
  final String sleepHistory;

  /// Diurese, evacuações e padrões de eliminação.
  final String eliminationHistory;

  final String immunizationStatus;
  final List<String> allergies;
  final List<String> currentMedications;
  final String familyHistory;

  /// Moradia, escolaridade, cuidadores, exposições ambientais.
  final String socialHistory;

  /// Revisão de sistemas: aparelho → achados.
  final Map<String, String> reviewOfSystems;

  bool get isEmpty =>
      chiefComplaint.isEmpty &&
      historyOfPresentIllness.isEmpty &&
      pastMedicalHistory.isEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'chiefComplaint': chiefComplaint,
        'historyOfPresentIllness': historyOfPresentIllness,
        'pastMedicalHistory': pastMedicalHistory,
        'gestationalHistory': gestationalHistory,
        'birthHistory': birthHistory,
        'developmentHistory': developmentHistory,
        'feedingHistory': feedingHistory,
        'sleepHistory': sleepHistory,
        'eliminationHistory': eliminationHistory,
        'immunizationStatus': immunizationStatus,
        'allergies': allergies,
        'currentMedications': currentMedications,
        'familyHistory': familyHistory,
        'socialHistory': socialHistory,
        'reviewOfSystems': reviewOfSystems,
      };

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>?)?.whereType<String>().toList(growable: false) ??
      const <String>[];

  @override
  List<Object?> get props => <Object?>[
        chiefComplaint,
        historyOfPresentIllness,
        pastMedicalHistory,
        gestationalHistory,
        birthHistory,
        developmentHistory,
        feedingHistory,
        sleepHistory,
        eliminationHistory,
        immunizationStatus,
        allergies,
        currentMedications,
        familyHistory,
        socialHistory,
        reviewOfSystems,
      ];
}

/// Sinais vitais aferidos no atendimento.
///
/// Separado do exame físico porque são valores numéricos que entram em
/// gráficos, alertas e cálculos — e porque, ao contrário do exame descritivo,
/// podem ser aferidos por enfermagem antes da consulta.
class VitalSigns extends Equatable {
  const VitalSigns({
    this.temperatureC,
    this.heartRate,
    this.respiratoryRate,
    this.systolicBp,
    this.diastolicBp,
    this.oxygenSaturation,
    this.weightKg,
    this.heightCm,
    this.headCircumferenceCm,
    this.painScore,
    this.capillaryRefillSeconds,
  });

  factory VitalSigns.fromMap(Map<String, dynamic> map) => VitalSigns(
        temperatureC: (map['temperatureC'] as num?)?.toDouble(),
        heartRate: (map['heartRate'] as num?)?.toInt(),
        respiratoryRate: (map['respiratoryRate'] as num?)?.toInt(),
        systolicBp: (map['systolicBp'] as num?)?.toInt(),
        diastolicBp: (map['diastolicBp'] as num?)?.toInt(),
        oxygenSaturation: (map['oxygenSaturation'] as num?)?.toInt(),
        weightKg: (map['weightKg'] as num?)?.toDouble(),
        heightCm: (map['heightCm'] as num?)?.toDouble(),
        headCircumferenceCm: (map['headCircumferenceCm'] as num?)?.toDouble(),
        painScore: (map['painScore'] as num?)?.toInt(),
        capillaryRefillSeconds:
            (map['capillaryRefillSeconds'] as num?)?.toDouble(),
      );

  final double? temperatureC;
  final int? heartRate;
  final int? respiratoryRate;
  final int? systolicBp;
  final int? diastolicBp;

  /// Saturação de oxigênio em ar ambiente.
  final int? oxygenSaturation;

  final double? weightKg;
  final double? heightCm;
  final double? headCircumferenceCm;

  /// Escala de dor de 0 a 10, adequada à idade.
  final int? painScore;

  /// Tempo de enchimento capilar — sinal precoce de má perfusão.
  final double? capillaryRefillSeconds;

  bool get isEmpty =>
      temperatureC == null &&
      heartRate == null &&
      respiratoryRate == null &&
      oxygenSaturation == null &&
      weightKg == null;

  bool get hasFever => temperatureC != null && temperatureC! >= 37.8;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'temperatureC': temperatureC,
        'heartRate': heartRate,
        'respiratoryRate': respiratoryRate,
        'systolicBp': systolicBp,
        'diastolicBp': diastolicBp,
        'oxygenSaturation': oxygenSaturation,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'headCircumferenceCm': headCircumferenceCm,
        'painScore': painScore,
        'capillaryRefillSeconds': capillaryRefillSeconds,
      };

  @override
  List<Object?> get props => <Object?>[
        temperatureC,
        heartRate,
        respiratoryRate,
        systolicBp,
        diastolicBp,
        oxygenSaturation,
        weightKg,
        heightCm,
        headCircumferenceCm,
        painScore,
        capillaryRefillSeconds,
      ];
}

/// Aparelhos avaliados no exame físico.
///
/// A lista é fixa e ordenada na sequência em que o exame é feito — não em
/// ordem alfabética. Um formulário que segue a mão do examinador é preenchido;
/// um que obriga a pular de um lado para o outro, não.
enum ExamSystem {
  generalAppearance,
  skin,
  headAndNeck,
  eyes,
  earsNoseThroat,
  respiratory,
  cardiovascular,
  abdomen,
  genitourinary,
  musculoskeletal,
  neurological,
  lymphNodes;

  String get label => switch (this) {
        ExamSystem.generalAppearance => 'Estado geral',
        ExamSystem.skin => 'Pele e mucosas',
        ExamSystem.headAndNeck => 'Cabeça e pescoço',
        ExamSystem.eyes => 'Olhos',
        ExamSystem.earsNoseThroat => 'Otorrino',
        ExamSystem.respiratory => 'Aparelho respiratório',
        ExamSystem.cardiovascular => 'Aparelho cardiovascular',
        ExamSystem.abdomen => 'Abdome',
        ExamSystem.genitourinary => 'Geniturinário',
        ExamSystem.musculoskeletal => 'Osteoarticular',
        ExamSystem.neurological => 'Neurológico',
        ExamSystem.lymphNodes => 'Linfonodos',
      };

  /// Texto pré-preenchido de normalidade.
  ///
  /// Registrar o normal importa tanto quanto registrar o alterado: um exame em
  /// branco não distingue "estava normal" de "não foi examinado" — e essa
  /// distinção é o que se discute quando algo dá errado.
  String get normalFinding => switch (this) {
        ExamSystem.generalAppearance =>
          'Bom estado geral, ativo, reativo, hidratado, corado, anictérico, '
              'acianótico, afebril ao toque.',
        ExamSystem.skin =>
          'Pele íntegra, sem lesões, sem exantemas. Mucosas úmidas e coradas. '
              'Enchimento capilar menor que 2 segundos.',
        ExamSystem.headAndNeck =>
          'Crânio normocefálico. Fontanelas normotensas quando presentes. '
              'Pescoço livre, sem rigidez.',
        ExamSystem.eyes =>
          'Pupilas isocóricas e fotorreagentes. Conjuntivas coradas. '
              'Sem secreção.',
        ExamSystem.earsNoseThroat =>
          'Membranas timpânicas translúcidas bilateralmente. Orofaringe sem '
              'hiperemia ou exsudato. Rinoscopia sem alterações.',
        ExamSystem.respiratory =>
          'Murmúrio vesicular presente e simétrico, sem ruídos adventícios. '
              'Sem sinais de esforço respiratório. Eupneico.',
        ExamSystem.cardiovascular =>
          'Ritmo cardíaco regular em dois tempos, bulhas normofonéticas, sem '
              'sopros. Pulsos periféricos cheios e simétricos.',
        ExamSystem.abdomen =>
          'Abdome plano, flácido, indolor à palpação. Ruídos hidroaéreos '
              'presentes. Sem visceromegalias ou massas.',
        ExamSystem.genitourinary =>
          'Genitália externa de aspecto habitual para idade e sexo.',
        ExamSystem.musculoskeletal =>
          'Sem deformidades. Mobilidade preservada. Marcha adequada para '
              'a idade.',
        ExamSystem.neurological =>
          'Consciente, orientado, ativo. Tônus e reflexos adequados para a '
              'idade. Sem sinais meníngeos ou déficits focais.',
        ExamSystem.lymphNodes =>
          'Sem linfonodomegalias palpáveis nas cadeias acessíveis.',
      };
}

/// Exame físico registrado.
class PhysicalExam extends Equatable {
  const PhysicalExam({
    this.findings = const <String, String>{},
    this.systemsExamined = const <String>{},
    this.notes = '',
  });

  factory PhysicalExam.fromMap(Map<String, dynamic> map) => PhysicalExam(
        findings: ((map['findings'] as Map<dynamic, dynamic>?) ??
                const <dynamic, dynamic>{})
            .map(
          (dynamic k, dynamic v) =>
              MapEntry<String, String>(k.toString(), v.toString()),
        ),
        systemsExamined:
            ((map['systemsExamined'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<String>()
                .toSet(),
        notes: (map['notes'] as String?) ?? '',
      );

  /// Aparelho → descrição do achado.
  final Map<String, String> findings;

  /// Aparelhos efetivamente examinados.
  ///
  /// Distinto de `findings.keys`: um aparelho pode ter sido examinado e ter
  /// achado vazio por engano. Este conjunto é o registro explícito do que foi
  /// avaliado.
  final Set<String> systemsExamined;

  final String notes;

  bool get isEmpty => findings.isEmpty && notes.isEmpty;

  /// Aparelhos que não foram avaliados — exibidos ao assinar, como lembrete.
  List<ExamSystem> get notExamined => ExamSystem.values
      .where((ExamSystem s) => !systemsExamined.contains(s.name))
      .toList(growable: false);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'findings': findings,
        'systemsExamined': systemsExamined.toList(growable: false),
        'notes': notes,
      };

  @override
  List<Object?> get props => <Object?>[findings, systemsExamined, notes];
}

/// Diagnóstico codificado.
///
/// O código CID vem de uma tabela carregada como recurso — ver
/// `assets/data/cid10_pediatria.json` e a ressalva no README sobre a
/// necessidade de usar a tabela oficial do Ministério da Saúde.
class Diagnosis extends Equatable {
  const Diagnosis({
    required this.code,
    required this.description,
    this.type = DiagnosisType.primary,
    this.certainty = DiagnosisCertainty.confirmed,
    this.note,
  });

  factory Diagnosis.fromMap(Map<String, dynamic> map) => Diagnosis(
        code: (map['code'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        type: DiagnosisType.fromName(map['type'] as String?),
        certainty: DiagnosisCertainty.fromName(map['certainty'] as String?),
        note: map['note'] as String?,
      );

  final String code;
  final String description;
  final DiagnosisType type;
  final DiagnosisCertainty certainty;
  final String? note;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'code': code,
        'description': description,
        'type': type.name,
        'certainty': certainty.name,
        'note': note,
      };

  @override
  List<Object?> get props => <Object?>[code, type, certainty];
}

enum DiagnosisType {
  primary,
  secondary,
  differential;

  static DiagnosisType fromName(String? value) =>
      DiagnosisType.values.firstWhere(
        (DiagnosisType t) => t.name == value,
        orElse: () => DiagnosisType.primary,
      );

  String get label => switch (this) {
        DiagnosisType.primary => 'Principal',
        DiagnosisType.secondary => 'Secundário',
        DiagnosisType.differential => 'Diferencial',
      };
}

/// Grau de certeza. Registrar "suspeita" como se fosse confirmação distorce o
/// histórico e pode carimbar uma criança com um diagnóstico que nunca teve.
enum DiagnosisCertainty {
  suspected,
  confirmed,
  ruledOut;

  static DiagnosisCertainty fromName(String? value) =>
      DiagnosisCertainty.values.firstWhere(
        (DiagnosisCertainty c) => c.name == value,
        orElse: () => DiagnosisCertainty.suspected,
      );

  String get label => switch (this) {
        DiagnosisCertainty.suspected => 'Suspeita',
        DiagnosisCertainty.confirmed => 'Confirmado',
        DiagnosisCertainty.ruledOut => 'Afastado',
      };
}
