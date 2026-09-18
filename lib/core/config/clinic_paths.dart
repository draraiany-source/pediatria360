/// Paths Firestore ? multitenant (FASE 1).
///
/// Isolamento: documentos clinicos futuros devem carregar `clinicId`.
/// Dados legados (sem clinicId) permanecem acessiveis pelas rules atuais.
abstract final class ClinicPaths {
  static const String clinics = 'clinics';
  static String clinic(String clinicId) => '$clinics/$clinicId';

  static String units(String clinicId) => '${clinic(clinicId)}/units';
  static String unit(String clinicId, String unitId) =>
      '${units(clinicId)}/$unitId';

  static String memberships(String clinicId) =>
      '${clinic(clinicId)}/memberships';
  static String membership(String clinicId, String membershipId) =>
      '${memberships(clinicId)}/$membershipId';

  /// Indice invertido: users/{uid}/clinic_memberships/{clinicId}
  static String userMemberships(String uid) =>
      'users/$uid/clinic_memberships';
  static String userMembership(String uid, String clinicId) =>
      '${userMemberships(uid)}/$clinicId';

  static String auditLogs(String clinicId) =>
      '${clinic(clinicId)}/audit_logs';
}
