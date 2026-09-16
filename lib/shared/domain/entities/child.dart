import 'package:equatable/equatable.dart';

/// Sexo biologico. Obrigatorio porque as curvas de crescimento da OMS e as
/// doses por peso sao estratificadas por sexo — nao e um campo opcional de
/// perfil, e um parametro clinico.
enum ChildSex {
  male,
  female;

  static ChildSex fromName(String? value) => ChildSex.values.firstWhere(
        (ChildSex s) => s.name == value,
        orElse: () => ChildSex.male,
      );

  String get label => this == ChildSex.male ? 'Menino' : 'Menina';
}

/// Crianca acompanhada no app.
class Child extends Equatable {
  const Child({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.birthDate,
    required this.sex,
    required this.updatedAt,
    this.photoUrl,
    this.bloodType,
    this.allergies = const <String>[],
    this.conditions = const <String>[],
    this.medications = const <String>[],
    this.gestationalWeeks,
    this.birthWeightKg,
    this.birthHeightCm,
    this.guardianName,
    this.guardianPhone,
    this.phone,
    this.address,
    this.cpf,
    this.insurance,
    this.pendingSync = false,
  });

  final String id;

  /// Uid do responsavel. Todo dado da crianca vive sob `users/{ownerId}` —
  /// isolar por dono e o que torna as regras de seguranca simples de auditar.
  final String ownerId;

  final String name;
  final DateTime birthDate;
  final ChildSex sex;
  final DateTime updatedAt;

  final String? photoUrl;
  final String? bloodType;
  final List<String> allergies;
  final List<String> conditions;

  /// Medicacoes de uso continuo no cadastro (nao so na anamnese da consulta).
  final List<String> medications;

  /// Nome do responsavel, gravado uma vez no cadastro da crianca — nao lido
  /// do documento do usuario. Ler `users/{ownerId}` do lado do profissional
  /// exigiria outra concessao de acesso (a de `authorized_professionals` só
  /// cobre a criança); denormalizar aqui evita abrir uma segunda pergunta
  /// de privacidade sem necessidade real.
  final String? guardianName;

  /// Telefone do responsavel para contato clinico.
  final String? guardianPhone;

  /// Telefone de contato (pode coincidir com o do responsavel).
  final String? phone;

  /// Endereco residencial.
  final String? address;

  /// CPF da crianca (quando houver).
  final String? cpf;

  /// Convenio / plano de saude.
  final String? insurance;

  /// Semanas de gestacao ao nascer. Abaixo de 37, a idade corrigida passa a
  /// ser usada nas curvas ate os 2 anos.
  final int? gestationalWeeks;

  final double? birthWeightKg;
  final double? birthHeightCm;

  /// `true` quando ha alteracao local ainda nao enviada ao servidor.
  final bool pendingSync;

  bool get isPreterm =>
      gestationalWeeks != null && gestationalWeeks! < 37;

  int get ageInMonths {
    final DateTime now = DateTime.now();
    int months =
        (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    if (now.day < birthDate.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  int get ageInDays => DateTime.now().difference(birthDate).inDays;

  /// Idade corrigida para prematuros: desconta as semanas que faltaram para
  /// as 40. Aplica-se ate os 24 meses de idade cronologica; depois disso a
  /// correcao deixa de ser recomendada.
  int get correctedAgeInMonths {
    if (!isPreterm || ageInMonths > 24) return ageInMonths;
    final int weeksMissing = 40 - gestationalWeeks!;
    final int corrected = ageInMonths - (weeksMissing / 4.345).round();
    return corrected < 0 ? 0 : corrected;
  }

  /// Idade que deve alimentar as curvas e os calculos de dose.
  int get clinicalAgeInMonths =>
      isPreterm ? correctedAgeInMonths : ageInMonths;

  /// Aniversario mais proximo, usado no card da home.
  int get daysUntilBirthday {
    final DateTime now = DateTime.now();
    DateTime next = DateTime(now.year, birthDate.month, birthDate.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, birthDate.month, birthDate.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  String get firstName => name.trim().split(' ').first;

  String get initials =>
      name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  Child copyWith({
    String? name,
    DateTime? birthDate,
    ChildSex? sex,
    DateTime? updatedAt,
    String? photoUrl,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? medications,
    int? gestationalWeeks,
    double? birthWeightKg,
    double? birthHeightCm,
    String? guardianName,
    String? guardianPhone,
    String? phone,
    String? address,
    String? cpf,
    String? insurance,
    bool? pendingSync,
  }) =>
      Child(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        sex: sex ?? this.sex,
        updatedAt: updatedAt ?? this.updatedAt,
        photoUrl: photoUrl ?? this.photoUrl,
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        conditions: conditions ?? this.conditions,
        medications: medications ?? this.medications,
        gestationalWeeks: gestationalWeeks ?? this.gestationalWeeks,
        birthWeightKg: birthWeightKg ?? this.birthWeightKg,
        birthHeightCm: birthHeightCm ?? this.birthHeightCm,
        guardianName: guardianName ?? this.guardianName,
        guardianPhone: guardianPhone ?? this.guardianPhone,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        cpf: cpf ?? this.cpf,
        insurance: insurance ?? this.insurance,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        ownerId,
        name,
        birthDate,
        sex,
        photoUrl,
        bloodType,
        allergies,
        conditions,
        medications,
        gestationalWeeks,
        birthWeightKg,
        birthHeightCm,
        guardianName,
        guardianPhone,
        phone,
        address,
        cpf,
        insurance,
        updatedAt,
        pendingSync,
      ];
}
