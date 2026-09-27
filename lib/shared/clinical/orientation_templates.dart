/// Modelos de orientação ao responsável.
///
/// O modelo guarda o texto base com marcadores; a personalização troca os
/// marcadores pelos dados da criança e o profissional ainda edita o resultado
/// antes de emitir.
library;

import 'clinical_documents.dart';
import 'dose_calculator.dart';

class OrientationTemplate {
  const OrientationTemplate({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.updatedAt,
    this.isExample = false,
  });

  final String id;
  final String title;
  final String body;
  final String author;
  final DateTime updatedAt;

  /// Modelo de exemplo, ainda não revisado por quem vai usar.
  final bool isExample;

  static const List<String> markers = <String>[
    '{{crianca}}',
    '{{idade}}',
    '{{responsavel}}',
    '{{peso}}',
    '{{data}}',
  ];

  String personalize(DocContext c, DateTime now) {
    final String age = c.patientBirthDate == null
        ? '[idade]'
        : formatAgeMonths(ageInMonths(c.patientBirthDate!, now));
    final String weight = c.weightKg == null
        ? '[peso]'
        : '${formatDoseNumber(c.weightKg!)} kg'
              '${c.weighedAt == null ? '' : ' em ${formatDocDate(c.weighedAt!)}'}';
    return body
        .replaceAll('{{crianca}}', c.patientName)
        .replaceAll('{{idade}}', age)
        .replaceAll('{{responsavel}}', c.guardianName ?? 'responsável')
        .replaceAll('{{peso}}', weight)
        .replaceAll('{{data}}', formatDocDate(c.date));
  }

  /// Transforma um texto já personalizado de volta em modelo reutilizável,
  /// recolocando os marcadores no lugar do nome da criança e do responsável.
  static String generalize(String text, DocContext c) {
    String out = text.replaceAll(c.patientName, '{{crianca}}');
    if ((c.guardianName ?? '').trim().isNotEmpty) {
      out = out.replaceAll(c.guardianName!, '{{responsavel}}');
    }
    return out;
  }
}
