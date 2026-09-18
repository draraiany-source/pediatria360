/// Multitenant ? organizacao (clinica) e unidade.
///
/// FASE 1: modelos de dominio + paths. Migracao gradual: usuarios atuais
/// continuam funcionando sem clinicId (modo legado single-tenant profissional).
library;

import 'package:equatable/equatable.dart';

/// Papel DENTRO de uma clinica (RBAC clinico).
/// Distinto de [UserRole] da plataforma (parent/professional/admin).
enum ClinicRole {
  clinicAdmin,
  physician,
  healthProfessional,
  receptionist,
  finance,
  nursing,
  technician,
  patient;

  static ClinicRole fromName(String? value) => ClinicRole.values.firstWhere(
        (ClinicRole r) => r.name == value,
        orElse: () => ClinicRole.patient,
      );

  String get label => switch (this) {
        ClinicRole.clinicAdmin => 'Administrador da clinica',
        ClinicRole.physician => 'Medico',
        ClinicRole.healthProfessional => 'Outro profissional de saude',
        ClinicRole.receptionist => 'Recepcionista',
        ClinicRole.finance => 'Financeiro',
        ClinicRole.nursing => 'Enfermagem',
        ClinicRole.technician => 'Tecnico',
        ClinicRole.patient => 'Paciente',
      };

  /// Acesso clinico de escrita (prontuario / Rx).
  bool get canAccessClinicalChart =>
      this == ClinicRole.clinicAdmin ||
      this == ClinicRole.physician ||
      this == ClinicRole.healthProfessional ||
      this == ClinicRole.nursing;

  bool get canManageAgenda =>
      canAccessClinicalChart ||
      this == ClinicRole.receptionist ||
      this == ClinicRole.technician;

  bool get canAccessFinance =>
      this == ClinicRole.clinicAdmin || this == ClinicRole.finance;

  bool get canManageStaff => this == ClinicRole.clinicAdmin;
}

class ClinicOrganization extends Equatable {
  const ClinicOrganization({
    required this.id,
    required this.name,
    required this.createdAt,
    this.tradeName = '',
    this.cnpj = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.logoUrl,
    this.active = true,
    this.plan = 'basic',
  });

  factory ClinicOrganization.fromMap(Map<String, dynamic> map, {String? id}) {
    return ClinicOrganization(
      id: id ?? (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      tradeName: (map['tradeName'] as String?) ?? '',
      cnpj: (map['cnpj'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      whatsapp: (map['whatsapp'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      logoUrl: map['logoUrl'] as String?,
      active: (map['active'] as bool?) ?? true,
      plan: (map['plan'] as String?) ?? 'basic',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final String tradeName;
  final String cnpj;
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String? logoUrl;
  final bool active;
  final String plan;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'tradeName': tradeName,
        'cnpj': cnpj,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'address': address,
        'logoUrl': logoUrl,
        'active': active,
        'plan': plan,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => <Object?>[id, name, cnpj, active, plan];
}

class ClinicUnit extends Equatable {
  const ClinicUnit({
    required this.id,
    required this.clinicId,
    required this.name,
    this.address = '',
    this.active = true,
  });

  factory ClinicUnit.fromMap(Map<String, dynamic> map, {String? id}) {
    return ClinicUnit(
      id: id ?? (map['id'] as String?) ?? '',
      clinicId: (map['clinicId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      active: (map['active'] as bool?) ?? true,
    );
  }

  final String id;
  final String clinicId;
  final String name;
  final String address;
  final bool active;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'clinicId': clinicId,
        'name': name,
        'address': address,
        'active': active,
      };

  @override
  List<Object?> get props => <Object?>[id, clinicId, name, active];
}

/// Vinculo usuario ? clinica (isolamento multitenant).
class ClinicMembership extends Equatable {
  const ClinicMembership({
    required this.id,
    required this.clinicId,
    required this.userId,
    required this.role,
    required this.createdAt,
    this.clinicName = '',
    this.unitIds = const <String>[],
    this.active = true,
    this.crm = '',
    this.specialty = '',
  });

  factory ClinicMembership.fromMap(Map<String, dynamic> map, {String? id}) {
    return ClinicMembership(
      id: id ?? (map['id'] as String?) ?? '',
      clinicId: (map['clinicId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      role: ClinicRole.fromName(map['role'] as String?),
      clinicName: (map['clinicName'] as String?) ?? '',
      unitIds: List<String>.from(
        (map['unitIds'] as List<dynamic>?) ?? const <dynamic>[],
      ),
      active: (map['active'] as bool?) ?? true,
      crm: (map['crm'] as String?) ?? '',
      specialty: (map['specialty'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String clinicId;
  final String userId;
  final ClinicRole role;
  final String clinicName;
  final List<String> unitIds;
  final bool active;
  final String crm;
  final String specialty;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'clinicId': clinicId,
        'userId': userId,
        'role': role.name,
        'clinicName': clinicName,
        'unitIds': unitIds,
        'active': active,
        'crm': crm,
        'specialty': specialty,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      <Object?>[id, clinicId, userId, role, active, unitIds];
}
