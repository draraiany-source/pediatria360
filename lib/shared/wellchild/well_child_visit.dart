/// Consulta de puericultura: campos do modelo, marcos, dúvidas dos
/// responsáveis, orientações dadas, próxima consulta e itens de
/// acompanhamento, com histórico de cada alteração.
///
/// Dart puro. Nada aqui gera conduta: o texto é sempre do profissional, e
/// dados informados pela família só entram depois de revisados.
library;

import '../routine/child_routine.dart' show formatDmy, formatHm, dayOf;
import 'milestones.dart';

enum WellChildSection {
  historia(
    'historia',
    'História',
    'Intercorrências e queixas desde a última consulta',
  ),
  alimentacao(
    'alimentacao',
    'Alimentação',
    'Aleitamento, introdução e aceitação alimentar',
  ),
  sono('sono', 'Sono', 'Rotina, local e forma de dormir, despertares'),
  eliminacoes('eliminacoes', 'Eliminações', 'Diurese e evacuações'),
  vacinacao('vacinacao', 'Vacinação', 'Situação da carteira e doses pendentes'),
  exameFisico('exame', 'Exame físico', 'Achados do exame'),
  crescimento(
    'crescimento',
    'Crescimento',
    'Comentário sobre as medidas e as curvas',
  ),
  desenvolvimento(
    'desenvolvimento',
    'Desenvolvimento',
    'Comentário sobre os marcos observados',
  ),
  avaliacao('avaliacao', 'Avaliação', 'Síntese da consulta'),
  plano('plano', 'Plano de acompanhamento', 'Condutas, exames e retorno');

  const WellChildSection(this.slug, this.label, this.hint);

  final String slug;
  final String label;
  final String hint;

  bool get required => this == avaliacao || this == plano;

  static WellChildSection? fromSlug(String? s) {
    for (final WellChildSection x in WellChildSection.values) {
      if (x.slug == s) return x;
    }
    return null;
  }
}

class GuardianQuestion {
  const GuardianQuestion({required this.question, this.answer = ''});

  final String question;

  /// Resposta ou orientação dada na consulta.
  final String answer;

  bool sameAs(GuardianQuestion o) =>
      question.trim() == o.question.trim() && answer.trim() == o.answer.trim();
}

class FollowUpItem {
  const FollowUpItem({
    required this.id,
    required this.title,
    required this.due,
  });

  final String id;
  final String title;
  final DateTime due;

  bool sameAs(FollowUpItem o) =>
      id == o.id &&
      title.trim() == o.title.trim() &&
      dayOf(due) == dayOf(o.due);
}

/// Dado informado pela família e incorporado à consulta pelo profissional.
class FamilyImport {
  const FamilyImport({
    required this.section,
    required this.source,
    required this.period,
    required this.text,
    required this.reviewedBy,
    required this.at,
  });

  final WellChildSection section;

  /// Ex.: "Diário do sono".
  final String source;
  final String period;

  /// Texto como ficou depois da revisão.
  final String text;
  final String reviewedBy;
  final DateTime at;
}

class VisitRevision {
  const VisitRevision({
    required this.at,
    required this.author,
    required this.action,
    this.changes = const <String>[],
    this.reason = '',
    this.before,
  });

  final DateTime at;
  final String author;
  final String action;
  final List<String> changes;
  final String reason;

  /// Conteúdo antes da alteração (a versão anterior fica guardada).
  final WellChildVisit? before;
}

class WellChildVisit {
  const WellChildVisit({
    this.fields = const <WellChildSection, String>{},
    this.milestones = const <MilestoneObservation>[],
    this.questions = const <GuardianQuestion>[],
    this.guidance = '',
    this.nextVisit,
    this.followUps = const <FollowUpItem>[],
    this.imports = const <FamilyImport>[],
    this.history = const <VisitRevision>[],
    this.templateName,
    this.logoId,
  });

  final Map<WellChildSection, String> fields;
  final List<MilestoneObservation> milestones;
  final List<GuardianQuestion> questions;

  /// Orientações dadas nesta consulta (resumo livre).
  final String guidance;

  /// Data sugerida para a próxima consulta.
  final DateTime? nextVisit;
  final List<FollowUpItem> followUps;
  final List<FamilyImport> imports;
  final List<VisitRevision> history;

  /// Modelo de evolução usado como ponto de partida, se houver.
  final String? templateName;

  /// Logomarca gravada ao finalizar (o resumo em PDF não muda depois).
  final String? logoId;

  static const String placeholderOpen = '[preencher';
  static const String placeholderDefine = '[a definir';

  String field(WellChildSection s) => fields[s] ?? '';

  WellChildVisit copyWith({
    Map<WellChildSection, String>? fields,
    List<MilestoneObservation>? milestones,
    List<GuardianQuestion>? questions,
    String? guidance,
    DateTime? Function()? nextVisit,
    List<FollowUpItem>? followUps,
    List<FamilyImport>? imports,
    List<VisitRevision>? history,
    String? Function()? templateName,
    String? Function()? logoId,
  }) => WellChildVisit(
    fields: fields ?? this.fields,
    milestones: milestones ?? this.milestones,
    questions: questions ?? this.questions,
    guidance: guidance ?? this.guidance,
    nextVisit: nextVisit != null ? nextVisit() : this.nextVisit,
    followUps: followUps ?? this.followUps,
    imports: imports ?? this.imports,
    history: history ?? this.history,
    templateName: templateName != null ? templateName() : this.templateName,
    logoId: logoId != null ? logoId() : this.logoId,
  );

  WellChildVisit withField(WellChildSection s, String text) =>
      copyWith(fields: <WellChildSection, String>{...fields, s: text});

  /// Acrescenta o texto revisado de um dado da família ao campo.
  WellChildVisit incorporate(FamilyImport imp) {
    final String current = field(imp.section).trim();
    return withField(
      imp.section,
      current.isEmpty ? imp.text.trim() : '$current\n\n${imp.text.trim()}',
    ).copyWith(imports: <FamilyImport>[...imports, imp]);
  }

  static bool _sameList<T>(List<T> a, List<T> b, bool Function(T, T) same) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!same(a[i], b[i])) return false;
    }
    return true;
  }

  /// O que mudou de [this] para [next], em palavras.
  List<String> changesTo(WellChildVisit next) => <String>[
    for (final WellChildSection s in WellChildSection.values)
      if (field(s).trim() != next.field(s).trim()) s.label,
    if (!_sameList(
      milestones,
      next.milestones,
      (MilestoneObservation a, MilestoneObservation b) => a.sameAs(b),
    ))
      'Marcos do desenvolvimento',
    if (!_sameList(
      questions,
      next.questions,
      (GuardianQuestion a, GuardianQuestion b) => a.sameAs(b),
    ))
      'Dúvidas dos responsáveis',
    if (guidance.trim() != next.guidance.trim()) 'Orientações dadas',
    if (_day(nextVisit) != _day(next.nextVisit)) 'Próxima consulta',
    if (!_sameList(
      followUps,
      next.followUps,
      (FollowUpItem a, FollowUpItem b) => a.sameAs(b),
    ))
      'Itens de acompanhamento',
    if (imports.length != next.imports.length) 'Dados da família incorporados',
  ];

  static DateTime? _day(DateTime? d) => d == null ? null : dayOf(d);

  /// Grava [next] com uma linha no histórico. Devolve o próprio objeto se
  /// nada mudou.
  WellChildVisit revised(
    WellChildVisit next, {
    required String author,
    required DateTime at,
    String action = 'Editado',
    String reason = '',
  }) {
    final List<String> changes = changesTo(next);
    if (changes.isEmpty) return this;
    return next.copyWith(
      history: <VisitRevision>[
        ...history,
        VisitRevision(
          at: at,
          author: author,
          action: action,
          changes: changes,
          reason: reason.trim(),
          before: this,
        ),
      ],
    );
  }

  WellChildVisit logged(
    String action, {
    required String author,
    required DateTime at,
    String reason = '',
  }) => copyWith(
    history: <VisitRevision>[
      ...history,
      VisitRevision(at: at, author: author, action: action, reason: reason),
    ],
  );

  List<String> get missingToFinish => <String>[
    for (final WellChildSection s in WellChildSection.values)
      if (s.required && field(s).trim().isEmpty) s.label,
  ];

  /// Campos que ainda trazem trechos de modelo a completar.
  List<String> get placeholders => <String>[
    for (final WellChildSection s in WellChildSection.values)
      if (_hasPlaceholder(field(s))) s.label,
    if (_hasPlaceholder(guidance)) 'Orientações dadas',
  ];

  static bool _hasPlaceholder(String t) {
    final String l = t.toLowerCase();
    return l.contains(placeholderOpen) || l.contains(placeholderDefine);
  }

  List<FollowUpItem> get sortedFollowUps =>
      List<FollowUpItem>.of(followUps)
        ..sort((FollowUpItem a, FollowUpItem b) => a.due.compareTo(b.due));

  /// Resumo curto para a lista do prontuário.
  String get summary {
    final String a = field(WellChildSection.avaliacao).trim();
    final String p = field(WellChildSection.plano).trim();
    return <String>[
      if (a.isNotEmpty) 'Avaliação: $a',
      if (p.isNotEmpty) 'Plano: $p',
      if (nextVisit != null) 'Próxima consulta: ${formatDmy(nextVisit!)}',
    ].join('\n');
  }

  static String historyLine(VisitRevision r) =>
      '${formatDmy(r.at)} ${formatHm(r.at)} - ${r.action} por ${r.author}'
      '${r.changes.isEmpty ? '' : ': ${r.changes.join(', ')}'}'
      '${r.reason.isEmpty ? '' : ' (motivo: ${r.reason})'}';
}
