/// Paths Firestore — suplementacao pediatrica.
abstract final class SupplementPaths {
  static const String root = 'supplementation';

  /// Catalogo CMS (admin) — preparado para edicao futura.
  static String contentMicronutrients() => '$root/content_micronutrients';
  static String contentExams() => '$root/content_exams';
  static String contentFoods() => '$root/content_foods';
  static String contentProtocols() => '$root/content_protocols';

  /// Dados clinicos por paciente (colecoes top-level, padrao do app).
  static String labResults() => 'supplement_lab_results';
  static String labResult(String id) => '${labResults()}/$id';
  static String prescriptions() => 'supplement_prescriptions';
  static String prescription(String id) => '${prescriptions()}/$id';
  static String timeline() => 'supplement_timeline';
  static String timelineEvent(String id) => '${timeline()}/$id';
  static String clinicalNotes() => 'supplement_clinical_notes';
  static String clinicalNote(String id) => '${clinicalNotes()}/$id';
  static String aiDrafts() => 'supplement_ai_drafts';
  static String aiDraft(String id) => '${aiDrafts()}/$id';

  static String favoritesDoc(String professionalId) =>
      'users/$professionalId/$root/favorites';
  static String recentDoc(String professionalId) =>
      'users/$professionalId/$root/recent';
  static String auditLogs() => 'supplement_audit_logs';
}
