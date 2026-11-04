import 'care_model.dart';
import 'care_store.dart';

/// Texto preparado pela IA (simulada nesta versão).
///
/// A IA só recebe o que quem pede já pode ver por escolha de outra pessoa:
/// os resumos compartilhados com ele e o plano conjunto, ou, ao redigir um
/// resumo, os itens que o próprio autor marcou. Registro completo, anotação
/// privada, transcrição, conversa e anexos nunca entram. Nada é salvo ou
/// enviado sem a revisão de quem pediu.
class CareAiDraft {
  const CareAiDraft({
    required this.childId,
    required this.requestedBy,
    required this.text,
    required this.sourceIds,
  });

  static const String label =
      'Rascunho da IA (simulado) - revisar antes de usar';

  final String childId;
  final String requestedBy;
  final String text;

  /// Resumos ou itens usados, para a origem de cada frase poder ser
  /// conferida.
  final List<String> sourceIds;
}

class CareAi {
  const CareAi._();

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _short(String text, [int max = 180]) {
    final String t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '${t.substring(0, max - 3)}...';
  }

  /// Visão da equipe para quem pede: só resumos publicados que ele pode ler
  /// e o plano conjunto. Não é salva.
  static CareAiDraft teamOverview(
    CareStore store,
    CareActor actor,
    String childId,
  ) {
    final List<CareSummary> shared = store
        .summariesFor(actor, childId)
        .where((CareSummary s) => s.published)
        .toList();
    final CarePlan? plan = store.planFor(actor, childId);
    final StringBuffer b = StringBuffer()
      ..writeln('Visão da equipe (rascunho para leitura, não é salvo)');
    final List<String> sources = <String>[];
    for (final CareSummary s in shared) {
      sources.add(s.id);
      final String items = <String>[
        for (final CareShareItem i in s.items) '${i.label}: ${_short(i.text)}',
        if (s.note.isNotEmpty) _short(s.note),
      ].join(' | ');
      b
        ..writeln()
        ..writeln(
          '${s.specialty.area} (${s.authorName}, versão ${s.version}, '
          '${_date(s.updatedAt ?? s.createdAt)}): $items',
        );
    }
    if (plan != null && plan.goals.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Plano terapêutico conjunto:');
      for (final CarePlanGoal g in plan.goals) {
        b.writeln(
          '- ${g.objective} (${g.responsibleName}, prazo ${_date(g.dueDate)}, '
          '${g.status.label.toLowerCase()})',
        );
      }
    }
    if (sources.isEmpty && (plan == null || plan.goals.isEmpty)) {
      b
        ..writeln()
        ..writeln('Nada foi compartilhado com você ainda.');
    }
    return CareAiDraft(
      childId: childId,
      requestedBy: actor.id,
      text: b.toString().trim(),
      sourceIds: sources,
    );
  }

  /// Sugestão de observação para o resumo, feita só com os itens que o
  /// autor marcou. Ao usar, o resumo fica marcado como preparado com IA e
  /// exige revisão antes de publicar.
  static CareAiDraft suggestSummaryNote(
    CareStore store,
    CareActor actor,
    CareRecord record,
    CareSummaryDraft draft,
  ) {
    final List<CareShareItem> items = store.selectedItems(actor, record, draft);
    if (items.isEmpty) {
      throw const CareAccessDenied(
        'Marque primeiro as informações que deseja resumir.',
      );
    }
    final String text = <String>[
      'Para a continuidade do cuidado:',
      for (final CareShareItem i in items) '${i.label}: ${_short(i.text, 140)}',
    ].join(' ');
    return CareAiDraft(
      childId: record.childId,
      requestedBy: actor.id,
      text: text,
      sourceIds: <String>[for (final CareShareItem i in items) i.id],
    );
  }
}
