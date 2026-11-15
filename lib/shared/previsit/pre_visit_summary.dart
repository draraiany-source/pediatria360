/// Resumo organizado da pré-consulta enviada, para o profissional.
///
/// Feito por regras simples sobre o que a família escreveu e anexou: separa
/// em tópicos, conta os anexos e aponta datas. Não interpreta sintomas, não
/// sugere hipótese nem conduta e não lê o conteúdo dos arquivos. As
/// respostas e os arquivos originais continuam disponíveis ao lado.
library;

import 'pre_visit.dart';

class PreVisitSummarySection {
  const PreVisitSummarySection(this.title, this.items);

  final String title;
  final List<String> items;
}

class PreVisitSummary {
  const PreVisitSummary({
    required this.sections,
    required this.attachmentLine,
    required this.checks,
  });

  final List<PreVisitSummarySection> sections;

  /// "2 fotos da queixa e 1 exame", ou vazio.
  final String attachmentLine;

  /// Pontos para o profissional conferir (fatos, não interpretação).
  final List<String> checks;

  bool get isEmpty => sections.isEmpty && attachmentLine.isEmpty;

  static const String notice =
      'Resumo organizado automaticamente por regras, sem IA. Não é '
      'diagnóstico: confira as respostas e os arquivos originais.';

  /// Anexo com mais de 6 meses na data da consulta.
  static const int oldAttachmentDays = 183;

  static PreVisitSummary of(PreVisit v, {required DateTime visitDate}) {
    final PreVisitAnswers a = v.sentAnswers ?? const PreVisitAnswers();
    final List<PreVisitSummarySection> sections = <PreVisitSummarySection>[
      for (final (String title, String text) in <(String, String)>[
        ('Motivo informado', a.reason),
        ('Sintomas e evolução', a.symptoms),
        ('Medicamentos em uso', a.medications),
        ('Outras informações', a.notes),
      ])
        if (splitItems(text).isNotEmpty)
          PreVisitSummarySection(title, splitItems(text)),
    ];

    final List<PreVisitAttachment> sent = v.sentAttachments;
    final List<String> counts = <String>[
      for (final PreVisitDocType t in PreVisitDocType.values)
        if (sent.any((PreVisitAttachment x) => x.type == t))
          _count(sent.where((PreVisitAttachment x) => x.type == t).length, t),
    ];

    final DateTime day = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
    );
    final List<String> checks = <String>[
      if (!_noMedication(a.medications))
        'Conferir com a família nome, dose e horário dos medicamentos '
            'informados.',
      for (final PreVisitAttachment x in sent)
        if (x.date != null &&
            day.difference(x.date!).inDays > oldAttachmentDays)
          '${x.type.label} de ${_dmy(x.date!)} tem mais de 6 meses.',
      for (final PreVisitAttachment x in sent)
        if (x.date == null && x.type.dateRequired)
          '${x.type.label} "${x.name}" sem data informada.',
      if (sent.isNotEmpty)
        'Abrir os arquivos originais antes de registrar no prontuário.',
    ];

    return PreVisitSummary(
      sections: sections,
      attachmentLine: _join(counts),
      checks: checks,
    );
  }

  /// Uma informação por linha, ponto e vírgula ou ponto final.
  static List<String> splitItems(String text) {
    final List<String> out = <String>[];
    for (final String raw in text.split(RegExp(r'[\n;]|\.\s+'))) {
      final String s = raw.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');
      final String clean = s.endsWith('.') ? s.substring(0, s.length - 1) : s;
      if (clean.isNotEmpty) out.add(clean);
    }
    return out;
  }

  /// Vazio ou "nenhum", "não usa" e parecidos.
  static bool _noMedication(String text) {
    final String s = text.trim().toLowerCase().replaceAll(
      RegExp(r'[.!]+$'),
      '',
    );
    return s.isEmpty ||
        const <String>{
          'nenhum',
          'nenhuma',
          'não',
          'nao',
          'não usa',
          'nao usa',
          'nada',
        }.contains(s);
  }

  static String _count(int n, PreVisitDocType t) =>
      '$n ${(n == 1 ? t.label : t.plural).toLowerCase()}';

  static String _join(List<String> parts) {
    if (parts.length <= 1) return parts.join();
    return '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
