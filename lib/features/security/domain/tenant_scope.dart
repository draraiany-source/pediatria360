import '../../../shared/domain/entities/clinic_organization.dart';

/// Violacao de isolamento multitenant (clinica / unidade).
class TenantScopeException implements Exception {
  TenantScopeException(this.message);

  final String message;

  @override
  String toString() => 'TenantScopeException: $message';
}

/// Helpers puros para RBAC por clinica e unidade (FASE 9).
class TenantScope {
  TenantScope._();

  /// Exige membership ativo na [clinicId] informada.
  static void requireClinicAccess(
    ClinicMembership? membership,
    String clinicId,
  ) {
    if (membership == null || !membership.active) {
      throw TenantScopeException('not an active clinic member');
    }
    if (membership.clinicId != clinicId) {
      throw TenantScopeException('membership clinic mismatch');
    }
  }

  /// Documento legado sem clinica: nao cruza tenant.
  static void assertSameClinic(
    String? docClinicId,
    String? membershipClinicId,
  ) {
    if (docClinicId == null || docClinicId.isEmpty) {
      return;
    }
    if (membershipClinicId == null || membershipClinicId.isEmpty) {
      throw TenantScopeException('document requires clinic membership');
    }
    if (docClinicId != membershipClinicId) {
      throw TenantScopeException('cross-clinic access denied');
    }
  }

  /// [unitIds] vazio + [ClinicRole.clinicAdmin] = todas as unidades da clinica.
  /// Caso contrario, [unitId] deve estar em [membership.unitIds] (se informado).
  static bool canAccessUnit(
    ClinicMembership? membership,
    String? unitId,
  ) {
    if (membership == null || !membership.active) {
      return false;
    }
    if (unitId == null || unitId.isEmpty) {
      return true;
    }
    if (membership.role == ClinicRole.clinicAdmin &&
        membership.unitIds.isEmpty) {
      return true;
    }
    if (membership.unitIds.isEmpty) {
      return false;
    }
    return membership.unitIds.contains(unitId);
  }

  /// Carimba `clinicId` / `unitId` no payload Firestore sem apagar valores existentes.
  static Map<String, dynamic> stampLedgerMap(
    Map<String, dynamic> data, {
    ClinicMembership? membership,
    String? unitId,
  }) {
    if (membership == null || !membership.active) {
      return data;
    }
    requireClinicAccess(membership, membership.clinicId);
    data.putIfAbsent('clinicId', () => membership.clinicId);
    final String? resolvedUnit = unitId ??
        (membership.unitIds.length == 1 ? membership.unitIds.first : null);
    if (resolvedUnit != null && resolvedUnit.isNotEmpty) {
      data.putIfAbsent('unitId', () => resolvedUnit);
    }
    return data;
  }
}
