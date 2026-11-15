/// Modelos de atestado, declaração, encaminhamento e solicitação de exames.
///
/// Regras:
/// - o modelo guarda texto e campos com marcadores ({{crianca}}, {{peso}}...),
///   nunca dados de uma criança;
/// - aplicar o modelo preenche só dados confirmados: cadastro do paciente e do
///   responsável, dados do profissional e a consulta registrada a que o
///   documento está vinculado. O que falta vira "[conferir: ...]" e o que o
///   modelo deixou em aberto vira "[preencher: ...]"; os dois impedem a
///   revisão até serem resolvidos;
/// - atestado nunca recebe CID ou diagnóstico do modelo;
/// - editar o modelo cria nova versão e não altera documentos já gerados, que
///   guardam cópia própria dos campos.
library;

import 'clinical_documents.dart';
import 'dose_calculator.dart';
import 'rx_templates.dart' show normalizeSearch;

/// Marcador que o modelo pode usar e o dado confirmado que o substitui.
class DocMarker {
  const DocMarker(this.token, this.label, this.resolve);

  final String token;
  final String label;
  final String? Function(DocContext c, DateTime now) resolve;
}

String? _nonEmpty(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();

final List<DocMarker> kDocMarkers = <DocMarker>[
  DocMarker('{{crianca}}', 'nome da criança', (DocContext c, _) {
    return _nonEmpty(c.patientName);
  }),
  DocMarker('{{nascimento}}', 'data de nascimento', (DocContext c, _) {
    return c.patientBirthDate == null
        ? null
        : formatDocDate(c.patientBirthDate!);
  }),
  DocMarker('{{idade}}', 'idade', (DocContext c, DateTime now) {
    return c.patientBirthDate == null
        ? null
        : formatAgeMonths(ageInMonths(c.patientBirthDate!, c.date));
  }),
  DocMarker('{{responsavel}}', 'responsável', (DocContext c, _) {
    return _nonEmpty(c.guardianName);
  }),
  DocMarker('{{peso}}', 'peso', (DocContext c, _) {
    return c.weightKg == null || c.weighedAt == null
        ? null
        : '${formatDoseNumber(c.weightKg!)} kg em ${formatDocDate(c.weighedAt!)}';
  }),
  DocMarker('{{alergias}}', 'alergias', (DocContext c, _) {
    return c.allergies.isEmpty ? null : c.allergies.join(', ');
  }),
  DocMarker('{{data_consulta}}', 'data da consulta', (DocContext c, _) {
    return c.consultationDate == null
        ? null
        : formatDocDate(c.consultationDate!);
  }),
  DocMarker('{{data}}', 'data do documento', (DocContext c, _) {
    return formatDocDate(c.date);
  }),
  DocMarker('{{profissional}}', 'nome do profissional', (DocContext c, _) {
    return _nonEmpty(c.professionalName);
  }),
  DocMarker('{{registro}}', 'registro profissional', (DocContext c, _) {
    return _nonEmpty(c.professionalRegistry);
  }),
  DocMarker('{{especialidade}}', 'especialidade', (DocContext c, _) {
    return _nonEmpty(c.professionalSpecialty);
  }),
  DocMarker('{{clinica}}', 'clínica', (DocContext c, _) {
    return _nonEmpty(c.clinicName);
  }),
  DocMarker('{{cidade}}', 'cidade', (DocContext c, _) {
    return _nonEmpty(c.city);
  }),
];

class DocTemplateVersion {
  const DocTemplateVersion({
    required this.number,
    required this.name,
    required this.fields,
    required this.savedAt,
    required this.savedBy,
    this.note,
  });

  final int number;
  final String name;
  final Map<String, String> fields;
  final DateTime savedAt;
  final String savedBy;
  final String? note;
}

class DocTemplate {
  const DocTemplate({
    required this.id,
    required this.kind,
    required this.versions,
    this.isExample = false,
  });

  final String id;
  final DocKind kind;
  final List<DocTemplateVersion> versions;

  /// Modelo de exemplo, com texto fictício a revisar.
  final bool isExample;

  DocTemplateVersion get current => versions.last;
  String get name => current.name;
  Map<String, String> get fields => current.fields;
  DateTime get updatedAt => current.savedAt;

  /// Como o documento gerado identifica a origem.
  String get originLabel => 'Modelo "$name" · v${current.number}';

  static DocTemplate create({
    required String id,
    required DocKind kind,
    required String name,
    required Map<String, String> fields,
    required String author,
    required DateTime now,
    String? note,
    bool isExample = false,
  }) {
    if (!DocTemplates.supports(kind)) {
      throw ArgumentError('Tipo sem modelo de documento: ${kind.label}');
    }
    return DocTemplate(
      id: id,
      kind: kind,
      isExample: isExample,
      versions: <DocTemplateVersion>[
        DocTemplateVersion(
          number: 1,
          name: name.trim(),
          fields: DocTemplates.clean(kind, fields),
          savedAt: now,
          savedBy: author,
          note: note,
        ),
      ],
    );
  }

  /// Nova versão; as anteriores e os documentos já gerados ficam como estão.
  DocTemplate edit({
    required String name,
    required Map<String, String> fields,
    required String author,
    required DateTime now,
    String? note,
  }) => DocTemplate(
    id: id,
    kind: kind,
    isExample: isExample,
    versions: <DocTemplateVersion>[
      ...versions,
      DocTemplateVersion(
        number: current.number + 1,
        name: name.trim(),
        fields: DocTemplates.clean(kind, fields),
        savedAt: now,
        savedBy: author,
        note: (note ?? '').trim().isEmpty
            ? 'Edição a partir da v${current.number}'
            : note!.trim(),
      ),
    ],
  );

  DocTemplate duplicate({
    required String id,
    required String author,
    required DateTime now,
    String? name,
  }) => DocTemplate.create(
    id: id,
    kind: kind,
    name: name ?? 'Cópia de ${this.name}',
    fields: fields,
    author: author,
    now: now,
    note: 'Cópia de "${this.name}" (v${current.number})',
  );

  List<String> problems() => <String>[
    if (name.trim().isEmpty) 'Dê um nome ao modelo',
    if (fields.values.every((String v) => v.trim().isEmpty))
      'Preencha ao menos um campo ou o texto',
  ];

  bool matches(String query) {
    final String q = normalizeSearch(query);
    if (q.isEmpty) return true;
    final String hay = normalizeSearch(
      <String>[name, kind.label, ...fields.values].join(' '),
    );
    return q.split(' ').where((String w) => w.isNotEmpty).every(hay.contains);
  }

  /// Resumo curto do conteúdo para listas.
  String get summary {
    final String free = (fields[DocumentTemplates.freeTextKey] ?? '').trim();
    final String base = free.isNotEmpty
        ? free
        : <String>[
            for (final DocFieldSpec s in DocumentTemplates.fields(kind))
              if (s.options == null && (fields[s.key] ?? '').trim().isNotEmpty)
                '${s.label}: ${fields[s.key]!.trim()}',
          ].join(' · ');
    final String one = base.replaceAll(RegExp(r'\s+'), ' ');
    return one.length > 140 ? '${one.substring(0, 137)}...' : one;
  }
}

/// Resultado de aplicar um modelo a um paciente.
class DocTemplateApplication {
  const DocTemplateApplication({
    required this.fields,
    required this.autoFilled,
    required this.toReview,
  });

  final Map<String, String> fields;

  /// Campo → dados confirmados que entraram automaticamente.
  final Map<String, List<String>> autoFilled;

  /// Campo → o que ainda precisa ser preenchido ou conferido.
  final Map<String, List<String>> toReview;
}

class DocTemplates {
  const DocTemplates._();

  /// Tipos com modelo próprio. Receitas usam os modelos de receita e
  /// orientações os modelos de orientação.
  static bool supports(DocKind k) =>
      k == DocKind.atestado ||
      k == DocKind.comparecimento ||
      k == DocKind.encaminhamento ||
      k == DocKind.exames;

  /// Campos que um modelo guarda para o tipo.
  static List<String> keys(DocKind k) => <String>[
    for (final DocFieldSpec s in DocumentTemplates.fields(k)) s.key,
    if (DocumentTemplates.supportsFreeText(k)) DocumentTemplates.freeTextKey,
  ];

  static String _labelOf(DocKind k, String key) {
    if (key == DocumentTemplates.freeTextKey) return 'Texto do documento';
    for (final DocFieldSpec s in DocumentTemplates.fields(k)) {
      if (s.key == key) return s.label;
    }
    return key;
  }

  static final RegExp _cidLine = RegExp(
    r'^[^\S\n]*CID\b.*$\n?',
    multiLine: true,
    caseSensitive: false,
  );

  /// Campos guardados no modelo: só os do tipo, e atestado sem CID.
  static Map<String, String> clean(DocKind k, Map<String, String> f) {
    final Map<String, String> out = <String, String>{
      for (final String key in keys(k)) key: (f[key] ?? '').trim(),
    };
    if (k == DocKind.atestado) {
      out['incluirCid'] = 'Não';
      out['cid'] = '';
      out[DocumentTemplates.freeTextKey] = out[DocumentTemplates.freeTextKey]!
          .replaceAll(_cidLine, '')
          .trim();
    }
    return out;
  }

  /// Transforma os campos de um documento em modelo: o que é do paciente
  /// vira marcador e o que é próprio do atendimento fica em aberto.
  static Map<String, String> generalize(
    DocKind k,
    Map<String, String> fields,
    DocContext c,
  ) {
    final List<(String, String)> swaps = <(String, String)>[
      (c.patientName, '{{crianca}}'),
      if (_nonEmpty(c.guardianName) != null) (c.guardianName!, '{{responsavel}}'),
      if (c.weightKg != null && c.weighedAt != null)
        (
          '${formatDoseNumber(c.weightKg!)} kg em ${formatDocDate(c.weighedAt!)}',
          '{{peso}}',
        ),
      if (c.patientBirthDate != null)
        (formatDocDate(c.patientBirthDate!), '{{nascimento}}'),
      if (c.consultationDate != null)
        (formatDocDate(c.consultationDate!), '{{data_consulta}}'),
      (formatDocDate(c.date), '{{data}}'),
      if (_nonEmpty(c.professionalName) != null)
        (c.professionalName, '{{profissional}}'),
      if (_nonEmpty(c.professionalRegistry) != null)
        (c.professionalRegistry, '{{registro}}'),
      if (_nonEmpty(c.clinicName) != null) (c.clinicName!, '{{clinica}}'),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    String g(String t) {
      String out = t;
      for (final (String from, String to) in swaps) {
        out = out.replaceAll(from, to);
      }
      return out;
    }

    final Map<String, String> out = <String, String>{
      for (final String key in keys(k)) key: g(fields[key] ?? ''),
    };
    String dateOrOpen(String key) {
      final String v = out[key]!.trim();
      return v == '{{data_consulta}}' || v == '{{data}}'
          ? '{{data_consulta}}'
          : '';
    }

    switch (k) {
      case DocKind.atestado:
        out['inicio'] = dateOrOpen('inicio');
      case DocKind.comparecimento:
        out['data'] = dateOrOpen('data');
        out['horaInicio'] = '';
        out['horaFim'] = '';
      case DocKind.encaminhamento:
        // Resumo, exames e tratamentos são da criança atendida.
        out['resumo'] = '';
        out['exames'] = '';
        out['tratamentos'] = '';
      case DocKind.exames:
      case DocKind.orientacoes:
      case DocKind.receituario:
        break;
    }
    return clean(k, out);
  }

  /// Dado confirmado usado quando o modelo deixou o campo vazio.
  static (String, String)? _confirmed(DocKind k, String key, DocContext c) {
    switch ((k, key)) {
      case (DocKind.atestado, 'inicio'):
      case (DocKind.comparecimento, 'data'):
        return c.consultationDate == null
            ? null
            : (formatDocDate(c.consultationDate!), 'data da consulta');
      case (DocKind.comparecimento, 'acompanhante'):
        return _nonEmpty(c.guardianName) == null
            ? null
            : (c.guardianName!, 'responsável');
      case (DocKind.encaminhamento, 'resumo'):
      case (DocKind.exames, 'indicacao'):
        return c.consultationDate == null || _nonEmpty(c.clinicalSummary) == null
            ? null
            : (c.clinicalSummary!, 'avaliação registrada na consulta');
      default:
        return null;
    }
  }

  /// Gera os campos do documento para o paciente atual.
  static DocTemplateApplication apply(
    DocTemplate t,
    DocContext c,
    DateTime now,
  ) {
    final Map<String, String> out = <String, String>{};
    final Map<String, List<String>> auto = <String, List<String>>{};
    final Map<String, List<String>> review = <String, List<String>>{};

    for (final String key in keys(t.kind)) {
      String v = (t.fields[key] ?? '').trim();
      final List<String> filled = <String>[];
      final List<String> pending = <String>[];
      DocFieldSpec? spec;
      for (final DocFieldSpec s in DocumentTemplates.fields(t.kind)) {
        if (s.key == key) spec = s;
      }
      if (v.isEmpty) {
        final (String, String)? conf = _confirmed(t.kind, key, c);
        if (conf != null) {
          v = conf.$1;
          filled.add(conf.$2);
        } else if (spec?.options != null) {
          v = spec!.options!.first;
        } else if (spec?.required == true) {
          pending.add('${_labelOf(t.kind, key)} a preencher');
        }
      } else {
        for (final DocMarker m in kDocMarkers) {
          if (!v.contains(m.token)) continue;
          final String? r = m.resolve(c, now);
          if (r == null) {
            v = v.replaceAll(m.token, '[conferir: ${m.label}]');
            pending.add('${m.label} não registrado(a)');
          } else {
            v = v.replaceAll(m.token, r);
            filled.add(m.label);
          }
        }
      }
      for (final RegExpMatch m in DocumentTemplates.placeholder.allMatches(v)) {
        final String what = m.group(1)!;
        if (!what.startsWith('conferir')) pending.add('campo variável: $what');
      }
      out[key] = v;
      if (filled.isNotEmpty) auto[key] = filled;
      if (pending.isNotEmpty) review[key] = pending;
    }
    if (t.kind == DocKind.atestado) {
      out['incluirCid'] = 'Não';
      out['cid'] = '';
    }
    out[DocumentTemplates.originKey] = t.originLabel;
    return DocTemplateApplication(
      fields: out,
      autoFilled: auto,
      toReview: review,
    );
  }
}
