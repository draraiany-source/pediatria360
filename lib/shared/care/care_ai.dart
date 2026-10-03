import 'care_model.dart';
import 'care_store.dart';

/// Rascunho de resumo preparado pela IA (simulada nesta versão).
///
/// Parte só da visão compartilhada da equipe: registros reservados nunca
/// entram, nem para o próprio autor. Nada é salvo ou enviado sem a revisão
/// de quem pediu.
class CareAiDraft {
  const CareAiDraft({
    required this.childId,
    required this.requestedBy,
    required this.text,
    required this.sourceIds,
  });

  static const String label =
      'Rascunho da IA (simulado) - revisar antes de salvar';

  final String childId;
  final String requestedBy;
  final String text;

  /// Registros usados, para a origem de cada frase poder ser conferida.
  final List<String> sourceIds;
}

class CareAi {
  const CareAi._();

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static CareAiDraft teamSummary(
    CareStore store,
    CareActor actor,
    String childId,
  ) {
    final CareSharedView view = store.sharedView(actor, childId);
    final StringBuffer b = StringBuffer()
      ..writeln('Resumo da equipe (rascunho para revisão)')
      ..writeln()
      ..writeln(
        'Equipe: ${view.team.where((CareLink l) => l.active).map((CareLink l) => '${l.professionalName} (${l.specialty.area})').join('; ')}.',
      );
    if (view.plan != null && view.plan!.text.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Plano combinado: ${view.plan!.text.trim()}');
    }
    final List<String> sources = <String>[];
    final Set<CareSpecialty> seen = <CareSpecialty>{};
    for (final CareSharedItem item in view.items) {
      if (!seen.add(item.specialty)) continue;
      sources.add(item.recordId);
      b
        ..writeln()
        ..writeln(
          '${item.specialty.area} (${item.authorName}, ${_date(item.at)}): '
          '${item.text}',
        );
    }
    return CareAiDraft(
      childId: childId,
      requestedBy: actor.id,
      text: b.toString().trim(),
      sourceIds: sources,
    );
  }

  /// Salva o rascunho revisado como resumo para a equipe. Sem revisão,
  /// recusa.
  static CareRecord saveReviewed(
    CareStore store,
    CareActor actor,
    CareAiDraft draft, {
    required String reviewedText,
    required bool reviewed,
  }) {
    if (!reviewed) {
      throw const CareAccessDenied(
        'Revise o rascunho da IA e confirme antes de salvar.',
      );
    }
    if (draft.requestedBy != actor.id) {
      throw const CareAccessDenied(
        'Só quem pediu o rascunho pode revisá-lo e salvá-lo.',
      );
    }
    return store.addRecord(
      actor,
      childId: draft.childId,
      kind: CareRecordKind.resumoEquipe,
      title: 'Resumo da equipe (preparado com IA, revisado)',
      body: reviewedText.trim(),
      fromAi: true,
      reviewedBy: actor.name,
    );
  }
}
