/// Liberação de documentos emitidos para a área da família.
///
/// Emitir não basta: quem emitiu escolhe o que a família vê. Rascunhos e
/// versões em revisão nunca aparecem; se o documento ganhar uma versão nova
/// ainda não emitida, a família continua vendo a última emitida. Retirar a
/// liberação esconde o documento de novo e exige motivo. Tudo fica no
/// histórico da liberação.
library;

import 'clinical_documents.dart';

class FamilyReleaseEvent {
  const FamilyReleaseEvent({
    required this.at,
    required this.actor,
    required this.released,
    this.reason,
  });

  final DateTime at;
  final String actor;

  /// `true` liberou; `false` retirou.
  final bool released;
  final String? reason;
}

class FamilyRelease {
  FamilyRelease(this.docId);

  final String docId;
  final List<FamilyReleaseEvent> events = <FamilyReleaseEvent>[];

  bool get isReleased => events.isNotEmpty && events.last.released;

  FamilyReleaseEvent? get lastRelease {
    for (final FamilyReleaseEvent e in events.reversed) {
      if (e.released) return e;
    }
    return null;
  }
}

class FamilyReleaseException implements Exception {
  const FamilyReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FamilyReleaseRules {
  const FamilyReleaseRules._();

  static const int minReasonLength = 5;

  /// Motivo para liberar ou retirar; `null` quando pode.
  static String? blockToRelease(
    ClinicalDocRecord doc, {
    required bool isOwner,
    FamilyRelease? current,
  }) {
    if (!isOwner) return 'Só quem emitiu o documento pode liberá-lo.';
    if (lastIssuedIndex(doc) < 0) {
      return 'Emita o documento antes de liberar para a família.';
    }
    if (current?.isReleased ?? false) return 'O documento já está liberado.';
    return null;
  }

  static String? blockToRevoke(
    ClinicalDocRecord doc, {
    required bool isOwner,
    required String reason,
    FamilyRelease? current,
  }) {
    if (!isOwner) return 'Só quem emitiu o documento pode retirá-lo.';
    if (!(current?.isReleased ?? false)) {
      return 'O documento não está liberado para a família.';
    }
    if (reason.trim().length < minReasonLength) {
      return 'Informe o motivo da retirada.';
    }
    return null;
  }

  static int lastIssuedIndex(ClinicalDocRecord doc) => doc.versions
      .lastIndexWhere((DocVersion v) => v.status == DocStatus.issued);

  /// O que a família vê: a última versão emitida, só se liberado.
  static ClinicalDocRecord? visibleToFamily(
    ClinicalDocRecord doc,
    FamilyRelease? release,
  ) {
    if (release == null || !release.isReleased) return null;
    final int i = lastIssuedIndex(doc);
    return i < 0 ? null : doc.upTo(i);
  }

  /// Orientações são escritas para a família: a emissão já sugere liberar.
  /// Receitas, atestados, encaminhamentos e exames começam desmarcados.
  static bool releaseOnIssueByDefault(DocKind kind) =>
      kind == DocKind.orientacoes;

  /// Grupos do pós-consulta, na ordem em que a família costuma procurar.
  static const List<(String, List<DocKind>)> groups = <(String, List<DocKind>)>[
    ('Receitas', <DocKind>[DocKind.receituario]),
    ('Orientações', <DocKind>[DocKind.orientacoes]),
    ('Exames solicitados', <DocKind>[DocKind.exames]),
    ('Encaminhamentos', <DocKind>[DocKind.encaminhamento]),
    (
      'Atestados e declarações',
      <DocKind>[DocKind.atestado, DocKind.comparecimento],
    ),
  ];

  static String groupOf(DocKind kind) =>
      groups.firstWhere(((String, List<DocKind>) g) => g.$2.contains(kind)).$1;
}

/// O que a família vê de uma consulta concluída: data, tipo, quem atendeu,
/// retorno combinado e documentos liberados. Anamnese, exame físico,
/// avaliação, hipóteses e conduta ficam só no prontuário.
class FamilyVisit {
  const FamilyVisit({
    required this.id,
    required this.date,
    required this.kindLabel,
    required this.professional,
    required this.clinic,
    this.returnDate,
    this.documents = const <ClinicalDocRecord>[],
  });

  final String id;
  final DateTime date;
  final String kindLabel;
  final String professional;
  final String clinic;

  /// Retorno combinado na consulta; `null` = sem retorno marcado.
  final DateTime? returnDate;

  /// Só a versão liberada de cada documento.
  final List<ClinicalDocRecord> documents;
}
