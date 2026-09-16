import '../../../../core/utils/validators.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../tools/domain/calculators.dart';

/// Texto do indicador de crescimento no Resumo 360° — peso, altura, IMC
/// (quando os dois anteriores existem), perímetro cefálico, data da medição.
///
/// Função pura, sem widget, para poder testar "com dado"/"sem dado"/"dado
/// parcial" sem precisar montar árvore de widget nenhuma.
String formatGrowthSummary(GrowthRecord? latest) {
  if (latest == null) return 'Sem registro';

  final List<String> parts = <String>[
    if (latest.weightKg != null) '${Formatters.decimal(latest.weightKg!)} kg',
    if (latest.heightCm != null) '${Formatters.decimal(latest.heightCm!)} cm',
  ];

  if (latest.weightKg != null && latest.heightCm != null) {
    final double bmi = PediatricCalculators.bmi(
      weightKg: latest.weightKg!,
      heightCm: latest.heightCm!,
    );
    if (bmi > 0) parts.add('IMC ${Formatters.decimal(bmi)}');
  }

  if (latest.headCircumferenceCm != null) {
    parts.add('PC ${Formatters.decimal(latest.headCircumferenceCm!)} cm');
  }

  if (parts.isEmpty) return 'Registro sem valores';
  return '${parts.join(' · ')} · ${Formatters.date(latest.measuredAt)}';
}

/// Texto do indicador de consultas — última consulta e contagem total.
///
/// "Próxima consulta" fica de fora de propósito: viria de `Appointment`,
/// não de `Encounter`, e este resumo não recebe agendamentos hoje. Melhor
/// omitir do que inventar uma data que não existe.
String formatConsultationsSummary(List<Encounter> encounters) {
  if (encounters.isEmpty) return 'Sem registro';

  final Encounter last = encounters.reduce(
    (Encounter a, Encounter b) => a.startedAt.isAfter(b.startedAt) ? a : b,
  );

  final String plural = encounters.length == 1 ? 'atendimento' : 'atendimentos';
  return 'Última: ${Formatters.date(last.startedAt)} · '
      '${encounters.length} $plural';
}

/// Texto do indicador de exames — último exame e contagem total.
String formatLabsSummary(List<LabResult> labs) {
  if (labs.isEmpty) return 'Sem registro';

  final LabResult last = labs.reduce(
    (LabResult a, LabResult b) =>
        a.collectedAt.isAfter(b.collectedAt) ? a : b,
  );

  final String plural = labs.length == 1 ? 'exame' : 'exames';
  return '${last.analyte} · ${Formatters.date(last.collectedAt)} · '
      '${labs.length} $plural';
}

/// Texto do indicador de documentos — contagem de documentos ativos
/// (cancelado não conta, mas continua existindo no histórico da timeline).
String formatDocumentsSummary(List<ClinicalDocument> documents) {
  final List<ClinicalDocument> active =
      documents.where((ClinicalDocument d) => !d.cancelled).toList();
  if (active.isEmpty) return 'Sem registro';

  final ClinicalDocument last = active.reduce(
    (ClinicalDocument a, ClinicalDocument b) =>
        a.issuedAt.isAfter(b.issuedAt) ? a : b,
  );

  final String plural = active.length == 1 ? 'documento' : 'documentos';
  return '${Formatters.date(last.issuedAt)} · ${active.length} $plural';
}
