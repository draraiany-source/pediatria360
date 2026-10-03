/// Modelos de orientação ao responsável.
///
/// O modelo guarda o texto base com marcadores; a personalização troca os
/// marcadores pelos dados da criança e o profissional ainda edita o resultado
/// antes de emitir.
library;

import '../wellchild/age_band.dart';
import 'clinical_documents.dart';
import 'dose_calculator.dart';

enum OrientationTopic {
  geral('Geral'),
  sonoSeguro('Sono seguro'),
  rotina('Rotina e sono'),
  puericultura('Puericultura');

  const OrientationTopic(this.label);
  final String label;
}

class OrientationTemplate {
  const OrientationTemplate({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.updatedAt,
    this.isExample = false,
    this.topic = OrientationTopic.geral,
    this.band,
    this.ownerId,
  });

  final String id;
  final String title;
  final String body;
  final String author;
  final DateTime updatedAt;

  /// Modelo de exemplo, ainda não revisado por quem vai usar.
  final bool isExample;

  final OrientationTopic topic;

  /// Faixa etária a que o texto se destina; `null` = qualquer idade.
  final ChildAgeBand? band;

  /// Conta que criou o modelo; `null` = exemplo visível a todas.
  final String? ownerId;

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

  /// Rótulo curto de tema e faixa para listas.
  String get tagLabel =>
      <String>[topic.label, if (band != null) band!.label].join(' · ');

  /// Texto e classificação novos. Documentos já gerados guardam cópia
  /// própria do texto e não mudam.
  OrientationTemplate revise({
    required String title,
    required String body,
    required OrientationTopic topic,
    required ChildAgeBand? band,
    required String author,
    required DateTime now,
  }) => OrientationTemplate(
    id: id,
    title: title.trim(),
    body: body.trim(),
    author: author,
    updatedAt: now,
    isExample: false,
    topic: topic,
    band: band,
    ownerId: ownerId,
  );

  OrientationTemplate duplicate({
    required String id,
    required String ownerId,
    required String author,
    required DateTime now,
  }) => OrientationTemplate(
    id: id,
    title: 'Cópia de ${title.replaceFirst('Modelo de exemplo: ', '')}',
    body: body,
    author: author,
    updatedAt: now,
    topic: topic,
    band: band,
    ownerId: ownerId,
  );
}
