/// Documentos vinculados à consulta: modelos, versões, revisão e assinatura.
///
/// Regras que valem para todos os tipos:
/// - o documento nasce como rascunho preenchido com dados do paciente e do
///   profissional, e só é emitido depois de revisado por quem assina;
/// - emitir não é assinar: o estado de assinatura só vira "assinado" com
///   provedor e data registrados;
/// - editar um documento emitido cria uma nova versão, preservando a anterior.
library;

enum DocKind {
  atestado('Atestado médico', 'atestado'),
  comparecimento('Declaração de comparecimento', 'declaracao'),
  encaminhamento('Encaminhamento', 'encaminhamento'),
  orientacoes('Orientações ao responsável', 'orientacoes'),
  exames('Solicitação de exames', 'exames'),
  receituario('Receituário', 'receituario');

  const DocKind(this.label, this.slug);

  final String label;
  final String slug;

  static DocKind? fromSlug(String? slug) {
    for (final DocKind k in DocKind.values) {
      if (k.slug == slug) return k;
    }
    return null;
  }

  SignatureRequirement get signatureRequirement => switch (this) {
        DocKind.receituario => const SignatureRequirement(
            printed: 'Assinatura manual e carimbo com CRM.',
            digital: 'Assinatura digital qualificada ICP-Brasil.',
            restrictions: 'Medicamentos de controle especial exigem '
                'receituário próprio e não são emitidos por este modelo.',
          ),
        DocKind.atestado => const SignatureRequirement(
            printed: 'Assinatura manual e carimbo com CRM.',
            digital: 'Assinatura digital qualificada ICP-Brasil.',
            restrictions: 'CID somente com autorização do responsável.',
          ),
        DocKind.comparecimento => const SignatureRequirement(
            printed: 'Assinatura manual do profissional ou da unidade.',
            digital: 'Assinatura digital ICP-Brasil.',
            restrictions: 'Não informa diagnóstico nem CID.',
          ),
        DocKind.encaminhamento ||
        DocKind.exames ||
        DocKind.orientacoes =>
          const SignatureRequirement(
            printed: 'Assinatura manual e carimbo com CRM.',
            digital: 'Assinatura digital ICP-Brasil.',
          ),
      };
}

/// Requisitos de emissão por modalidade. Devem ser confirmados com a norma
/// vigente (CFM/ANVISA) antes do uso em produção.
class SignatureRequirement {
  const SignatureRequirement({
    required this.printed,
    required this.digital,
    this.restrictions,
  });

  final String printed;
  final String digital;
  final String? restrictions;
}

enum DocStatus {
  draft('Rascunho'),
  reviewed('Revisado'),
  issued('Emitido');

  const DocStatus(this.label);

  final String label;
}

enum SignatureState { notSigned, pendingProvider, signed }

class SignatureInfo {
  const SignatureInfo.notSigned()
      : state = SignatureState.notSigned,
        provider = null,
        signedAt = null;

  const SignatureInfo.pending(String this.provider)
      : state = SignatureState.pendingProvider,
        signedAt = null;

  /// Só existe com provedor e data: é o registro da assinatura que define o
  /// estado, nunca a tela.
  const SignatureInfo.signed({
    required String this.provider,
    required DateTime this.signedAt,
  }) : state = SignatureState.signed;

  final SignatureState state;
  final String? provider;
  final DateTime? signedAt;

  bool get isSigned => state == SignatureState.signed;

  String get label => switch (state) {
        SignatureState.notSigned => 'Não assinado',
        SignatureState.pendingProvider =>
          'Aguardando assinatura digital ($provider)',
        SignatureState.signed =>
          'Assinado digitalmente ($provider) em ${formatDocDate(signedAt!)}',
      };
}

/// Dados já existentes usados para preencher os modelos.
class DocContext {
  const DocContext({
    required this.patientName,
    required this.professionalName,
    required this.professionalRegistry,
    required this.date,
    this.patientBirthDate,
    this.guardianName,
    this.allergies = const <String>[],
    this.weightKg,
    this.weighedAt,
    this.professionalSpecialty,
    this.clinicName,
    this.clinicAddress,
    this.city,
    this.clinicalSummary,
  });

  final String patientName;
  final DateTime? patientBirthDate;
  final String? guardianName;
  final List<String> allergies;
  final double? weightKg;
  final DateTime? weighedAt;
  final String professionalName;
  final String professionalRegistry;
  final String? professionalSpecialty;
  final String? clinicName;
  final String? clinicAddress;
  final String? city;

  /// Data da consulta a que o documento se vincula.
  final DateTime date;

  /// Avaliação registrada na consulta, usada como ponto de partida do
  /// resumo clínico do encaminhamento.
  final String? clinicalSummary;
}

class RxItem {
  const RxItem({
    required this.drug,
    required this.presentation,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.duration,
    this.quantity = '',
    this.notes = '',
    this.calculation,
  });

  final String drug;
  final String presentation;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String quantity;
  final String notes;

  /// Conta conferida na calculadora, quando o item veio dela.
  final String? calculation;

  bool get isComplete =>
      drug.trim().isNotEmpty &&
      presentation.trim().isNotEmpty &&
      dose.trim().isNotEmpty &&
      frequency.trim().isNotEmpty &&
      duration.trim().isNotEmpty;

  String get posology => <String>[
        dose,
        route,
        frequency,
        if (duration.trim().isNotEmpty) 'por $duration',
      ].where((String s) => s.trim().isNotEmpty).join(', ');
}

class DocFieldSpec {
  const DocFieldSpec(
    this.key,
    this.label, {
    this.required = false,
    this.lines = 1,
    this.hint,
    this.options,
  });

  final String key;
  final String label;
  final bool required;
  final int lines;
  final String? hint;
  final List<String>? options;
}

class DocVersion {
  const DocVersion({
    required this.number,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.fields,
    required this.items,
    required this.body,
    required this.status,
    this.reviewedAt,
    this.reviewedBy,
    this.issuedAt,
    this.changeNote,
  });

  final int number;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> fields;
  final List<RxItem> items;
  final String body;
  final DocStatus status;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? issuedAt;
  final String? changeNote;

  DocVersion copyWith({
    DateTime? updatedAt,
    Map<String, String>? fields,
    List<RxItem>? items,
    String? body,
    DocStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    DateTime? issuedAt,
    bool clearReview = false,
  }) =>
      DocVersion(
        number: number,
        author: author,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fields: fields ?? this.fields,
        items: items ?? this.items,
        body: body ?? this.body,
        status: status ?? this.status,
        reviewedAt: clearReview ? null : reviewedAt ?? this.reviewedAt,
        reviewedBy: clearReview ? null : reviewedBy ?? this.reviewedBy,
        issuedAt: issuedAt ?? this.issuedAt,
        changeNote: changeNote,
      );
}

class DocumentFlowException implements Exception {
  const DocumentFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ClinicalDocRecord {
  const ClinicalDocRecord({
    required this.id,
    required this.kind,
    required this.patientId,
    required this.versions,
    this.consultationId,
    this.signature = const SignatureInfo.notSigned(),
  });

  final String id;
  final DocKind kind;
  final String patientId;
  final String? consultationId;
  final List<DocVersion> versions;
  final SignatureInfo signature;

  DocVersion get current => versions.last;
  DocStatus get status => current.status;

  /// Título curto para listas e histórico.
  String get title {
    final String t = current.fields['titulo'] ?? '';
    if (kind == DocKind.encaminhamento) {
      final String esp = current.fields['especialidade'] ?? '';
      if (esp.trim().isNotEmpty) return '${kind.label} para $esp';
    }
    return t.trim().isEmpty ? kind.label : '${kind.label}: $t';
  }

  ClinicalDocRecord _with(List<DocVersion> versions) => ClinicalDocRecord(
        id: id,
        kind: kind,
        patientId: patientId,
        consultationId: consultationId,
        versions: versions,
        signature: signature,
      );

  static ClinicalDocRecord createDraft({
    required String id,
    required DocKind kind,
    required String patientId,
    required String author,
    required DocContext context,
    required DateTime now,
    String? consultationId,
    Map<String, String>? fields,
    List<RxItem> items = const <RxItem>[],
  }) {
    final Map<String, String> f =
        fields ?? DocumentTemplates.prefill(kind, context);
    return ClinicalDocRecord(
      id: id,
      kind: kind,
      patientId: patientId,
      consultationId: consultationId,
      versions: <DocVersion>[
        DocVersion(
          number: 1,
          author: author,
          createdAt: now,
          updatedAt: now,
          fields: f,
          items: items,
          body: DocumentTemplates.render(kind, f, context, items),
          status: DocStatus.draft,
        ),
      ],
    );
  }

  /// Salva o rascunho. Se a versão atual já foi emitida, abre a versão
  /// seguinte; se estava revisada, a revisão deixa de valer.
  ClinicalDocRecord saveDraft({
    required Map<String, String> fields,
    required List<RxItem> items,
    required DocContext context,
    required String author,
    required DateTime now,
    String? changeNote,
  }) {
    final String body = DocumentTemplates.render(kind, fields, context, items);
    if (current.status == DocStatus.issued) {
      return _with(<DocVersion>[
        ...versions,
        DocVersion(
          number: current.number + 1,
          author: author,
          createdAt: now,
          updatedAt: now,
          fields: Map<String, String>.of(fields),
          items: List<RxItem>.of(items),
          body: body,
          status: DocStatus.draft,
          changeNote: changeNote ?? 'Nova versão a partir da v${current.number}',
        ),
      ]);
    }
    return _with(<DocVersion>[
      ...versions.sublist(0, versions.length - 1),
      current.copyWith(
        updatedAt: now,
        fields: Map<String, String>.of(fields),
        items: List<RxItem>.of(items),
        body: body,
        status: DocStatus.draft,
        clearReview: true,
      ),
    ]);
  }

  /// Pendências que impedem revisar e emitir.
  List<String> get pendingIssues =>
      DocumentTemplates.missing(kind, current.fields, current.items, current.body);

  ClinicalDocRecord markReviewed({required String reviewer, required DateTime now}) {
    if (current.status != DocStatus.draft) {
      throw const DocumentFlowException('Só um rascunho pode ser revisado.');
    }
    final List<String> issues = pendingIssues;
    if (issues.isNotEmpty) {
      throw DocumentFlowException('Resolva antes de revisar: ${issues.join('; ')}.');
    }
    return _with(<DocVersion>[
      ...versions.sublist(0, versions.length - 1),
      current.copyWith(
        status: DocStatus.reviewed,
        reviewedAt: now,
        reviewedBy: reviewer,
        updatedAt: now,
      ),
    ]);
  }

  ClinicalDocRecord issue({required DateTime now}) {
    if (current.status != DocStatus.reviewed) {
      throw const DocumentFlowException(
          'O documento precisa ser revisado antes da emissão.');
    }
    return _with(<DocVersion>[
      ...versions.sublist(0, versions.length - 1),
      current.copyWith(status: DocStatus.issued, issuedAt: now, updatedAt: now),
    ]);
  }
}

String formatDocDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatDocDateTime(DateTime d) =>
    '${formatDocDate(d)} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

DateTime? parseDocDate(String? text) {
  final RegExpMatch? m =
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text?.trim() ?? '');
  if (m == null) return null;
  final int d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
  final DateTime dt = DateTime(y, mo, d);
  return dt.day == d && dt.month == mo ? dt : null;
}

class DocumentTemplates {
  const DocumentTemplates._();

  static List<DocFieldSpec> fields(DocKind kind) => switch (kind) {
        DocKind.atestado => const <DocFieldSpec>[
            DocFieldSpec('dias', 'Dias de afastamento', required: true, hint: '1'),
            DocFieldSpec('inicio', 'A partir de', required: true, hint: 'dd/mm/aaaa'),
            DocFieldSpec('finalidade', 'Atividades', hint: 'escolares'),
            DocFieldSpec('incluirCid', 'Incluir CID',
                required: true, options: <String>['Não', 'Sim']),
            DocFieldSpec('cid', 'CID (só se autorizado)'),
            DocFieldSpec('observacoes', 'Observações', lines: 3),
          ],
        DocKind.comparecimento => const <DocFieldSpec>[
            DocFieldSpec('data', 'Data', required: true, hint: 'dd/mm/aaaa'),
            DocFieldSpec('horaInicio', 'Das', required: true, hint: '08:00'),
            DocFieldSpec('horaFim', 'Às', required: true, hint: '09:00'),
            DocFieldSpec('acompanhante', 'Acompanhante', required: true),
            DocFieldSpec('finalidade', 'Finalidade', hint: 'apresentação no trabalho'),
          ],
        DocKind.encaminhamento => const <DocFieldSpec>[
            DocFieldSpec('especialidade', 'Especialidade de destino', required: true),
            DocFieldSpec('prioridade', 'Prioridade',
                required: true, options: <String>['Eletivo', 'Prioritário']),
            DocFieldSpec('motivo', 'Motivo do encaminhamento', required: true, lines: 3),
            DocFieldSpec('resumo', 'Resumo clínico', required: true, lines: 5),
            DocFieldSpec('exames', 'Exames relevantes', lines: 3),
            DocFieldSpec('tratamentos', 'Tratamentos realizados', lines: 3),
          ],
        DocKind.orientacoes => const <DocFieldSpec>[
            DocFieldSpec('titulo', 'Título', required: true),
            DocFieldSpec('texto', 'Orientações', required: true, lines: 10),
          ],
        DocKind.exames => const <DocFieldSpec>[
            DocFieldSpec('exames', 'Exames (um por linha)', required: true, lines: 6),
            DocFieldSpec('indicacao', 'Indicação clínica', required: true, lines: 3),
            DocFieldSpec('observacoes', 'Observações ao laboratório', lines: 2),
          ],
        DocKind.receituario => const <DocFieldSpec>[
            DocFieldSpec('orientacoes', 'Orientações gerais', lines: 3),
          ],
      };

  static Map<String, String> prefill(DocKind kind, DocContext c) => switch (kind) {
        DocKind.atestado => <String, String>{
            'dias': '1',
            'inicio': formatDocDate(c.date),
            'finalidade': 'escolares',
            'incluirCid': 'Não',
            'cid': '',
            'observacoes': '',
          },
        DocKind.comparecimento => <String, String>{
            'data': formatDocDate(c.date),
            'horaInicio': '',
            'horaFim': '',
            'acompanhante': c.guardianName ?? '',
            'finalidade': '',
          },
        DocKind.encaminhamento => <String, String>{
            'especialidade': '',
            'prioridade': 'Eletivo',
            'motivo': '',
            'resumo': c.clinicalSummary ?? '',
            'exames': '',
            'tratamentos': '',
          },
        DocKind.orientacoes => <String, String>{'titulo': '', 'texto': ''},
        DocKind.exames => <String, String>{
            'exames': '',
            'indicacao': c.clinicalSummary ?? '',
            'observacoes': '',
          },
        DocKind.receituario => <String, String>{'orientacoes': ''},
      };

  static String _v(Map<String, String> f, String key, [String fallback = '[preencher]']) {
    final String v = (f[key] ?? '').trim();
    return v.isEmpty ? fallback : v;
  }

  static String _patientLine(DocContext c) {
    final String birth = c.patientBirthDate == null
        ? ''
        : ', nascido(a) em ${formatDocDate(c.patientBirthDate!)}';
    return '${c.patientName}$birth';
  }

  /// Corpo do documento. Cabeçalho, identificação e assinatura ficam no
  /// layout, não no texto.
  static String render(
    DocKind kind,
    Map<String, String> f,
    DocContext c,
    List<RxItem> items,
  ) {
    switch (kind) {
      case DocKind.atestado:
        final String dias = _v(f, 'dias');
        final String plural = dias == '1' ? 'dia' : 'dias';
        final String fin = (f['finalidade'] ?? '').trim();
        final bool cid = f['incluirCid'] == 'Sim';
        final StringBuffer b = StringBuffer()
          ..write('Atesto, para os devidos fins, que ${_patientLine(c)}, foi '
              'atendido(a) por mim em ${formatDocDate(c.date)} e necessita de '
              'afastamento de suas atividades${fin.isEmpty ? '' : ' $fin'} por '
              '$dias $plural, a partir de ${_v(f, 'inicio')}.');
        if (cid) b.write('\n\nCID: ${_v(f, 'cid')} (incluído com autorização do responsável).');
        final String obs = (f['observacoes'] ?? '').trim();
        if (obs.isNotEmpty) b.write('\n\n$obs');
        return b.toString();
      case DocKind.comparecimento:
        final String fin = (f['finalidade'] ?? '').trim();
        return 'Declaro, para os devidos fins, que ${_v(f, 'acompanhante')} '
            'compareceu a esta unidade em ${_v(f, 'data')}, das '
            '${_v(f, 'horaInicio')} às ${_v(f, 'horaFim')}, acompanhando '
            '${c.patientName} em consulta pediátrica.'
            '${fin.isEmpty ? '' : '\n\nFinalidade: $fin.'}';
      case DocKind.encaminhamento:
        final StringBuffer b = StringBuffer()
          ..writeln('Encaminho ${_patientLine(c)}, para avaliação em '
              '${_v(f, 'especialidade')} (${_v(f, 'prioridade', 'Eletivo')}).')
          ..writeln()
          ..writeln('Motivo: ${_v(f, 'motivo')}')
          ..writeln()
          ..writeln('Resumo clínico: ${_v(f, 'resumo')}');
        final String ex = (f['exames'] ?? '').trim();
        final String tr = (f['tratamentos'] ?? '').trim();
        if (ex.isNotEmpty) b..writeln()..writeln('Exames relevantes: $ex');
        if (tr.isNotEmpty) b..writeln()..writeln('Tratamentos realizados: $tr');
        if (c.allergies.isNotEmpty) {
          b..writeln()..writeln('Alergias registradas: ${c.allergies.join(', ')}');
        }
        b..writeln()..write('Agradeço a atenção e coloco-me à disposição.');
        return b.toString();
      case DocKind.orientacoes:
        return _v(f, 'texto');
      case DocKind.exames:
        final List<String> list = (f['exames'] ?? '')
            .split('\n')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        final StringBuffer b = StringBuffer()
          ..writeln('Solicito para ${c.patientName}:')
          ..writeln();
        if (list.isEmpty) b.writeln('- [preencher]');
        for (final String e in list) {
          b.writeln('- $e');
        }
        b..writeln()..write('Indicação clínica: ${_v(f, 'indicacao')}');
        final String obs = (f['observacoes'] ?? '').trim();
        if (obs.isNotEmpty) b.write('\n\nObservações: $obs');
        return b.toString();
      case DocKind.receituario:
        final StringBuffer b = StringBuffer();
        for (int i = 0; i < items.length; i++) {
          final RxItem it = items[i];
          b
            ..writeln('${i + 1}. ${it.drug} - ${it.presentation}'
                '${it.quantity.trim().isEmpty ? '' : ' (${it.quantity})'}')
            ..writeln('   ${it.posology}');
          if (it.notes.trim().isNotEmpty) b.writeln('   ${it.notes}');
          b.writeln();
        }
        if (items.isEmpty) b.writeln('[preencher]');
        final String o = (f['orientacoes'] ?? '').trim();
        if (o.isNotEmpty) b.write('Orientações: $o');
        return b.toString().trimRight();
    }
  }

  static final RegExp _placeholder = RegExp(r'\[(preencher|[^\]]*a definir[^\]]*)\]');

  static List<String> missing(
    DocKind kind,
    Map<String, String> f,
    List<RxItem> items,
    String body,
  ) {
    final List<String> out = <String>[];
    for (final DocFieldSpec s in fields(kind)) {
      if (s.required && (f[s.key] ?? '').trim().isEmpty) out.add('${s.label} obrigatório');
    }
    switch (kind) {
      case DocKind.atestado:
        final int? dias = int.tryParse((f['dias'] ?? '').trim());
        if ((f['dias'] ?? '').trim().isNotEmpty && (dias == null || dias < 1 || dias > 90)) {
          out.add('Dias de afastamento entre 1 e 90');
        }
        if ((f['inicio'] ?? '').trim().isNotEmpty && parseDocDate(f['inicio']) == null) {
          out.add('Data de início inválida');
        }
        if (f['incluirCid'] == 'Sim' && (f['cid'] ?? '').trim().isEmpty) {
          out.add('Informe o CID ou desmarque a inclusão');
        }
      case DocKind.comparecimento:
        if ((f['data'] ?? '').trim().isNotEmpty && parseDocDate(f['data']) == null) {
          out.add('Data inválida');
        }
        final RegExp hour = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
        for (final String k in <String>['horaInicio', 'horaFim']) {
          final String v = (f[k] ?? '').trim();
          if (v.isNotEmpty && !hour.hasMatch(v)) out.add('Horário inválido: $v');
        }
      case DocKind.receituario:
        if (items.isEmpty) out.add('Inclua ao menos um medicamento');
        for (final RxItem it in items) {
          if (!it.isComplete) out.add('Item "${it.drug}" incompleto');
        }
      case DocKind.encaminhamento:
      case DocKind.orientacoes:
      case DocKind.exames:
        break;
    }
    if (_placeholder.hasMatch(body)) out.add('Há campos entre colchetes a preencher');
    return out;
  }
}
