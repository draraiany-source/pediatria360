/// Modelos de evolução de puericultura.
///
/// O modelo guarda textos com marcadores ({{crianca}}, {{responsavel}},
/// {{idade}}); ao aplicar, os marcadores viram os dados do paciente e o
/// profissional edita tudo antes de finalizar. Trechos "[preencher]" impedem
/// a finalização até serem completados.
library;

import 'age_band.dart';
import 'well_child_visit.dart';

class WellChildTemplate {
  const WellChildTemplate({
    required this.id,
    required this.name,
    required this.fields,
    required this.author,
    required this.updatedAt,
    this.band,
    this.guidance = '',
    this.isExample = false,
    this.version = 1,
  });

  final String id;
  final String name;
  final ChildAgeBand? band;
  final Map<WellChildSection, String> fields;
  final String guidance;
  final String author;
  final DateTime updatedAt;
  final bool isExample;
  final int version;

  static const List<String> markers = <String>[
    '{{crianca}}',
    '{{responsavel}}',
    '{{idade}}',
  ];

  WellChildTemplate copyWith({
    String? name,
    ChildAgeBand? Function()? band,
    Map<WellChildSection, String>? fields,
    String? guidance,
    required String author,
    required DateTime now,
  }) => WellChildTemplate(
    id: id,
    name: name ?? this.name,
    band: band != null ? band() : this.band,
    fields: fields ?? this.fields,
    guidance: guidance ?? this.guidance,
    author: author,
    updatedAt: now,
    version: version + 1,
  );

  List<String> validate() => <String>[
    if (name.trim().isEmpty) 'Dê um nome ao modelo.',
    if (name.trim().length > 80) 'Use um nome de até 80 caracteres.',
    if (fields.values.every((String t) => t.trim().isEmpty) &&
        guidance.trim().isEmpty)
      'O modelo está vazio: preencha ao menos um campo.',
  ];

  /// Cria um modelo a partir da consulta, trocando o nome da criança e do
  /// responsável por marcadores.
  static WellChildTemplate fromVisit(
    WellChildVisit v, {
    required String id,
    required String name,
    required String author,
    required DateTime now,
    required String patientName,
    String? guardianName,
    ChildAgeBand? band,
  }) {
    String g(String t) {
      String out = t.replaceAll(patientName, '{{crianca}}');
      final String first = patientName.split(' ').first;
      if (first.length > 2) {
        out = out.replaceAll(
          RegExp('\\b${RegExp.escape(first)}\\b'),
          '{{crianca}}',
        );
      }
      if ((guardianName ?? '').trim().isNotEmpty) {
        out = out.replaceAll(guardianName!, '{{responsavel}}');
      }
      return out;
    }

    return WellChildTemplate(
      id: id,
      name: name.trim(),
      band: band,
      fields: <WellChildSection, String>{
        for (final MapEntry<WellChildSection, String> e in v.fields.entries)
          if (_withoutFamily(v, e.key, e.value).isNotEmpty)
            e.key: g(_withoutFamily(v, e.key, e.value)),
      },
      guidance: g(v.guidance.trim()),
      author: author,
      updatedAt: now,
    );
  }

  /// Texto da família incorporado não vira modelo: é do paciente.
  static String _withoutFamily(
    WellChildVisit v,
    WellChildSection s,
    String text,
  ) {
    String out = text;
    for (final FamilyImport i in v.imports) {
      if (i.section == s && i.text.trim().isNotEmpty) {
        out = out.replaceAll(i.text.trim(), '');
      }
    }
    return out.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String personalize(
    String text, {
    required String patientName,
    String? guardianName,
    String? ageLabel,
  }) => text
      .replaceAll('{{crianca}}', patientName.split(' ').first)
      .replaceAll('{{responsavel}}', guardianName ?? 'responsável')
      .replaceAll('{{idade}}', ageLabel ?? '[idade]');

  /// Aplica o modelo. Campos já escritos são mantidos, a menos que
  /// [overwrite] seja verdadeiro.
  ({WellChildVisit visit, List<String> filled, List<String> kept}) applyTo(
    WellChildVisit v, {
    required String patientName,
    String? guardianName,
    String? ageLabel,
    bool overwrite = false,
  }) {
    final Map<WellChildSection, String> out = Map<WellChildSection, String>.of(
      v.fields,
    );
    final List<String> filled = <String>[];
    final List<String> kept = <String>[];
    String p(String t) => personalize(
      t,
      patientName: patientName,
      guardianName: guardianName,
      ageLabel: ageLabel,
    );
    for (final MapEntry<WellChildSection, String> e in fields.entries) {
      if (e.value.trim().isEmpty) continue;
      if (!overwrite && v.field(e.key).trim().isNotEmpty) {
        kept.add(e.key.label);
        continue;
      }
      out[e.key] = p(e.value);
      filled.add(e.key.label);
    }
    String guidanceOut = v.guidance;
    if (guidance.trim().isNotEmpty) {
      if (!overwrite && v.guidance.trim().isNotEmpty) {
        kept.add('Orientações dadas');
      } else {
        guidanceOut = p(guidance);
        filled.add('Orientações dadas');
      }
    }
    return (
      visit: v.copyWith(
        fields: out,
        guidance: guidanceOut,
        templateName: () => '$name (v$version)',
      ),
      filled: filled,
      kept: kept,
    );
  }
}
