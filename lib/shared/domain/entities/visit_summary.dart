import 'package:equatable/equatable.dart';

/// Status do resumo — três estados reais, não dois.
///
/// `draft`: o profissional escreve e reescreve livremente.
/// `finalized`: conteúdo revisado e travado — o profissional confirmou que
/// está pronto, mas a família ainda não vê. É o "confirmar antes de
/// liberar" que existe como passo próprio, não só um checkbox.
/// `released`: a família vê. Depois disso, o documento não é mais
/// editável — correção passa a ser retificação versionada
/// (`amendsSummaryId`/`amendmentReason`, mesmo padrão já usado em
/// `Encounter`), nunca sobrescrita silenciosa do que a família já leu.
enum VisitSummaryStatus {
  draft,
  finalized,
  released;

  static VisitSummaryStatus fromName(String? value) =>
      VisitSummaryStatus.values.firstWhere(
        (VisitSummaryStatus s) => s.name == value,
        orElse: () => VisitSummaryStatus.draft,
      );
}

/// Resumo pós-consulta, em linguagem para a família — não é o prontuário
/// técnico, é o que a família precisa saber depois de sair do consultório.
///
/// ## Por que referencia documentos em vez de copiar o conteúdo
///
/// Receita, pedido de exame e encaminhamento já existem como
/// `ClinicalDocument`, emitidos durante o atendimento. Copiar o texto de
/// novo aqui criaria duas fontes da mesma informação — se o profissional
/// cancelar ou retificar um documento depois, o resumo ficaria
/// desatualizado sem ninguém perceber. Em vez disso,
/// [releasedDocumentIds] só guarda referência: a tela busca o documento de
/// verdade na hora de mostrar, sempre atual.
///
/// O que preenche embora não seja duplicação de nada: orientação, cuidado,
/// sinal de alerta, informação de retorno — não existem em lugar nenhum
/// além daqui, são o valor real deste registro.
class VisitSummary extends Equatable {
  const VisitSummary({
    required this.encounterId,
    required this.patientId,
    required this.professionalId,
    required this.createdAt,
    this.status = VisitSummaryStatus.draft,
    this.guidance = '',
    this.careInstructions = '',
    this.warningSigns = const <String>[],
    this.followUpNotes = '',
    this.followUpDate,
    this.releasedDocumentIds = const <String>[],
    this.releasedAt,
    this.finalizedAt,
    this.amendsSummaryId,
    this.amendmentReason,
  });

  final String encounterId;
  final String patientId;
  final String professionalId;
  final DateTime createdAt;
  final VisitSummaryStatus status;

  /// Orientação geral — o que fazer, em linguagem simples.
  final String guidance;

  /// Cuidados específicos (curativo, dieta, repouso...).
  final String careInstructions;

  /// Cada item é um sinal concreto de quando procurar ajuda de novo — não
  /// texto livre, uma lista, porque a família vai reler isso em casa, sob
  /// estresse, e uma lista é mais fácil de escanear que um parágrafo.
  final List<String> warningSigns;

  final String followUpNotes;
  final DateTime? followUpDate;

  /// IDs de `ClinicalDocument` já emitidos nesta consulta que o
  /// profissional decidiu incluir no resumo — não é automático incluir
  /// todo documento da consulta, é escolha de quem libera.
  final List<String> releasedDocumentIds;

  final DateTime? releasedAt;

  /// Quando o conteúdo foi travado (status virou `finalized`) — antes
  /// disso, `saveVisitSummaryDraft` reescreve livremente.
  final DateTime? finalizedAt;

  /// Preenchido quando este documento é uma retificação de outro já
  /// liberado — mesmo padrão de `Encounter.amendsEncounterId`. O
  /// documento original nunca é apagado nem sobrescrito; este é um novo
  /// documento, começando em `draft` de novo.
  final String? amendsSummaryId;
  final String? amendmentReason;

  bool get isReleased => status == VisitSummaryStatus.released;

  /// Verdadeiro se há algo além do rascunho vazio — mesmo princípio já
  /// usado em `PreVisitQuestionnaire.hasContent`.
  bool get hasContent =>
      guidance.isNotEmpty ||
      careInstructions.isNotEmpty ||
      warningSigns.isNotEmpty ||
      followUpNotes.isNotEmpty ||
      followUpDate != null ||
      releasedDocumentIds.isNotEmpty;

  VisitSummary copyWith({
    VisitSummaryStatus? status,
    String? guidance,
    String? careInstructions,
    List<String>? warningSigns,
    String? followUpNotes,
    DateTime? followUpDate,
    List<String>? releasedDocumentIds,
    DateTime? releasedAt,
    DateTime? finalizedAt,
    String? amendsSummaryId,
    String? amendmentReason,
  }) =>
      VisitSummary(
        encounterId: encounterId,
        patientId: patientId,
        professionalId: professionalId,
        createdAt: createdAt,
        status: status ?? this.status,
        guidance: guidance ?? this.guidance,
        careInstructions: careInstructions ?? this.careInstructions,
        warningSigns: warningSigns ?? this.warningSigns,
        followUpNotes: followUpNotes ?? this.followUpNotes,
        followUpDate: followUpDate ?? this.followUpDate,
        releasedDocumentIds: releasedDocumentIds ?? this.releasedDocumentIds,
        releasedAt: releasedAt ?? this.releasedAt,
        finalizedAt: finalizedAt ?? this.finalizedAt,
        amendsSummaryId: amendsSummaryId ?? this.amendsSummaryId,
        amendmentReason: amendmentReason ?? this.amendmentReason,
      );

  @override
  List<Object?> get props => <Object?>[
        encounterId,
        patientId,
        professionalId,
        createdAt,
        status,
        guidance,
        careInstructions,
        warningSigns,
        followUpNotes,
        followUpDate,
        releasedDocumentIds,
        releasedAt,
        finalizedAt,
        amendsSummaryId,
        amendmentReason,
      ];
}
