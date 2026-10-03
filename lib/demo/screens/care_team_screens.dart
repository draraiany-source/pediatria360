import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/care/care_ai.dart';
import '../../shared/care/care_model.dart';
import '../../shared/care/care_policy.dart';
import '../../shared/care/care_store.dart';
import '../demo_care.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_workspace.dart' show DemoWorkspace;
import '../widgets/demo_widgets.dart';

enum CareTab {
  equipe('Equipe'),
  pediatria('Pediatria'),
  psicologia('Psicologia'),
  fisioterapia('Fisioterapia'),
  comunicacao('Comunicação'),
  documentos('Documentos'),
  familia('Família'),
  acessos('Acessos');

  const CareTab(this.label);

  final String label;

  static CareTab? fromSlug(String? s) {
    for (final CareTab t in CareTab.values) {
      if (t.name == s) return t;
    }
    return null;
  }

  CareSpecialty? get specialty => switch (this) {
    CareTab.pediatria => CareSpecialty.pediatria,
    CareTab.psicologia => CareSpecialty.psicologia,
    CareTab.fisioterapia => CareSpecialty.fisioterapia,
    _ => null,
  };

  static CareTab? forSpecialty(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => CareTab.pediatria,
    CareSpecialty.psicologia => CareTab.psicologia,
    CareSpecialty.fisioterapia => CareTab.fisioterapia,
    _ => null,
  };
}

String carePath(String childId, {CareTab? tab}) =>
    tab == null ? '/cuidado/$childId' : '/cuidado/$childId?aba=${tab.name}';

const String professionalProfilePath = '/profissional';

String careTileSubtitle(String childId) {
  final DemoCare care = demoSession.care;
  final List<CareLink> active = care.store.links
      .where((CareLink l) => l.childId == childId && l.active)
      .toList();
  final int pending = care.store.links
      .where((CareLink l) => l.childId == childId && l.pending)
      .length;
  final String areas = active
      .map((CareLink l) => l.specialty.area)
      .toSet()
      .join(', ');
  return '${active.length} profissional(is): $areas'
      '${pending == 0 ? '' : ' - $pending aguardando autorização'}';
}

String _dt(DateTime d) => '${demoDate(d)} ${demoTime(d)}';

void _run(BuildContext context, void Function() action, {String? ok}) {
  try {
    action();
    demoSession.changed();
    if (ok != null) showDemoSnack(context, ok);
  } on CareAccessDenied catch (e) {
    demoSession.changed();
    showDemoSnack(context, e.message);
  }
}

Color _visibilityColor(CareVisibility v) => switch (v) {
  CareVisibility.privado => AppColors.navy,
  CareVisibility.familia => AppColors.success,
};

IconData _visibilityIcon(CareVisibility v) => switch (v) {
  CareVisibility.privado => Icons.lock_outline_rounded,
  CareVisibility.familia => Icons.family_restroom_outlined,
};

/// Assistente do resumo para a equipe de um registro.
String careSummaryPath(String childId, String recordId) =>
    '/cuidado/$childId/resumo/$recordId';

/// Ficha multidisciplinar da criança.
class DemoCareScreen extends StatelessWidget {
  const DemoCareScreen({required this.childId, this.tab, super.key});

  final String childId;
  final String? tab;

  List<CareTab> _tabs(CareActor actor, CareStore store) {
    final DemoCare care = demoSession.care;
    switch (actor.role) {
      case CareActorRole.profissional:
        final CareLink? link = store.linkOf(actor, childId);
        if (link == null) {
          final CareTab? own = actor.specialty == null
              ? null
              : CareTab.forSpecialty(actor.specialty!);
          return <CareTab>[if (own != null) own];
        }
        final Set<CareSpecialty> inTeam = <CareSpecialty>{
          for (final CareLink l in store.team(actor, childId))
            if (l.active) l.specialty,
          link.specialty,
        };
        return <CareTab>[
          CareTab.equipe,
          for (final CareTab t in const <CareTab>[
            CareTab.pediatria,
            CareTab.psicologia,
            CareTab.fisioterapia,
          ])
            if (inTeam.contains(t.specialty)) t,
          CareTab.comunicacao,
          CareTab.documentos,
        ];
      case CareActorRole.familia:
        return care.canOpen(childId)
            ? const <CareTab>[CareTab.familia, CareTab.acessos]
            : const <CareTab>[];
      case CareActorRole.gestaoClinica:
        return care.canOpen(childId)
            ? const <CareTab>[CareTab.equipe, CareTab.acessos]
            : const <CareTab>[];
      case CareActorRole.recepcao:
      case CareActorRole.financeiro:
      case CareActorRole.adminPlataforma:
        return const <CareTab>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoCare care = demoSession.care;
        final CareActor actor = care.actor;
        final DemoPatient? child = demoSession.patients
            .where((DemoPatient p) => p.id == childId)
            .firstOrNull;
        final List<CareTab> tabs = child == null
            ? const <CareTab>[]
            : _tabs(actor, care.store);
        if (child == null || tabs.isEmpty || !care.canOpen(childId)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cuidado multidisciplinar')),
            body: DemoEmpty(
              title: 'Acesso restrito',
              message:
                  'A ficha multidisciplinar abre só para profissionais com '
                  'vínculo ativo com a criança e para o responsável. '
                  'Pertencer à mesma clínica não dá acesso.',
              actionLabel: 'Voltar ao início',
              onAction: () => context.go('/inicio'),
            ),
          );
        }
        final CareTab current =
            CareTab.fromSlug(tab) != null &&
                tabs.contains(CareTab.fromSlug(tab))
            ? CareTab.fromSlug(tab)!
            : tabs.first;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: Text(
              actor.isFamily
                  ? 'Equipe e atividades'
                  : 'Cuidado multidisciplinar',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Header(child: child, actor: actor),
                    const SizedBox(height: AppSpacing.md),
                    if (tabs.length > 1)
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final CareTab t in tabs)
                            ChoiceChip(
                              key: ValueKey<String>('aba-${t.name}'),
                              label: Text(t.label),
                              selected: t == current,
                              onSelected: (_) =>
                                  context.go(carePath(childId, tab: t)),
                            ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),
                    ..._body(context, current, child, actor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    CareTab tab,
    DemoPatient child,
    CareActor actor,
  ) {
    final DemoCare care = demoSession.care;
    final CareStore store = care.store;
    return switch (tab) {
      CareTab.equipe =>
        actor.role == CareActorRole.gestaoClinica
            ? _manageTeam(context, child, actor, store)
            : _sharedView(context, child, actor, store),
      CareTab.pediatria ||
      CareTab.psicologia ||
      CareTab.fisioterapia => _area(context, child, actor, tab.specialty!),
      CareTab.comunicacao => _communication(context, child, actor, store),
      CareTab.documentos => _documents(context, child, actor, store),
      CareTab.familia => _family(context, child, actor, store),
      CareTab.acessos => _audit(context, child, actor, store),
    };
  }

  // ------------------------------------------------------------- Equipe

  List<Widget> _sharedView(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final CareLink link = store.linkOf(actor, child.id)!;
    final List<CareLink> team = store.team(actor, child.id);
    final CarePlan? plan = store.planFor(actor, child.id);
    final List<CareSummary> visible = store.summariesFor(actor, child.id);
    final List<CareSummary> received = visible
        .where((CareSummary s) => s.authorId != actor.id)
        .toList();
    final List<CareSummary> mine = visible
        .where((CareSummary s) => s.authorId == actor.id)
        .toList();
    final bool canPlan = CarePolicy.allows(
      link.specialty,
      CareAction.planoCompartilhado,
    );
    return <Widget>[
      const DemoSectionTitle('Profissionais envolvidos'),
      for (final CareLink l in team) _LinkCard(link: l),
      DemoSectionTitle(
        'Plano terapêutico conjunto',
        trailing: canPlan
            ? TextButton.icon(
                key: const ValueKey<String>('novo-objetivo'),
                onPressed: () => _newGoal(context, child.id),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo objetivo'),
              )
            : null,
      ),
      const DemoNotice(
        icon: Icons.handshake_outlined,
        text:
            'Cada profissional contribui com o que escolhe escrever aqui. O '
            'registro completo de cada atendimento não aparece no plano.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (plan == null || plan.goals.isEmpty)
        const Text('Ainda sem objetivos no plano conjunto.'),
      if (plan != null)
        for (final CarePlanGoal g in plan.goals)
          _GoalCard(goal: g, actor: actor, canPlan: canPlan),
      if (plan != null && plan.history.isNotEmpty)
        Semantics(
          container: true,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Histórico do plano (${plan.history.length})'),
            children: <Widget>[
              for (final CarePlanChange c in plan.history.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(c.description),
                  subtitle: Text(
                    '${c.actorName} (${c.specialty.area}) - ${_dt(c.at)}',
                  ),
                ),
            ],
          ),
        ),
      const DemoSectionTitle('Próximos atendimentos'),
      ..._sessions(context, demoSession.care.nextSessions(child.id)),
      DemoSectionTitle(
        'Resumos compartilhados com você',
        trailing: CarePolicy.allows(link.specialty, CareAction.rascunhoIa)
            ? TextButton.icon(
                key: const ValueKey<String>('ia-visao'),
                onPressed: () => _aiOverview(context, child.id),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Visão com IA'),
              )
            : null,
      ),
      const DemoNotice(
        icon: Icons.lock_outline_rounded,
        text:
            'Aqui aparece só o que cada autor escolheu compartilhar com você. '
            'O registro completo, as anotações privadas e os anexos não '
            'escolhidos ficam com quem atendeu.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (received.isEmpty) const Text('Nenhum resumo compartilhado com você.'),
      for (final CareSummary s in received) _SummaryCard(summary: s),
      const DemoSectionTitle('Resumos que você compartilhou'),
      if (mine.isEmpty)
        const Text(
          'Você ainda não compartilhou resumos. Crie um a partir de um '
          'registro seu.',
        ),
      for (final CareSummary s in mine) _SummaryCard(summary: s),
    ];
  }

  List<Widget> _sessions(BuildContext context, List<DemoAppointment> list) {
    if (list.isEmpty) {
      return const <Widget>[Text('Nenhum atendimento agendado.')];
    }
    return <Widget>[
      for (final DemoAppointment a in list)
        PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              const Icon(Icons.event_outlined, color: AppColors.brand),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '${_dt(a.start)} - '
                  '${DemoCare.specialtyOf(a.professionalId).area} com '
                  '${DemoProfessional.byId(a.professionalId).name}',
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _newGoal(BuildContext context, String childId) async {
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final CareLink me = store.linkOf(actor, childId)!;
    final List<CareLink> options = <CareLink>[
      me,
      ...store.colleaguesOf(actor, childId),
    ];
    CareLink responsible = me;
    int due = 60;
    int reassess = 30;
    final TextEditingController objective = TextEditingController();
    final TextEditingController action = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: const Text('Novo objetivo do plano'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: const ValueKey<String>('objetivo-texto'),
                  controller: objective,
                  decoration: const InputDecoration(labelText: 'Objetivo *'),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Profissional responsável'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final CareLink l in options)
                      ChoiceChip(
                        key: ValueKey<String>('resp-${l.professionalId}'),
                        label: Text(
                          '${l.professionalName} (${l.specialty.area})',
                        ),
                        selected: l == responsible,
                        onSelected: (_) => set(() => responsible = l),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Prazo'),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int days in const <int>[30, 60, 90, 120])
                      ChoiceChip(
                        key: ValueKey<String>('prazo-$days'),
                        label: Text('$days dias'),
                        selected: due == days,
                        onSelected: (_) => set(() => due = days),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Reavaliação'),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int days in const <int>[15, 30, 45])
                      ChoiceChip(
                        key: ValueKey<String>('reav-$days'),
                        label: Text('em $days dias'),
                        selected: reassess == days,
                        onSelected: (_) => set(() => reassess = days),
                      ),
                  ],
                ),
                TextField(
                  key: const ValueKey<String>('objetivo-acao'),
                  controller: action,
                  decoration: const InputDecoration(
                    labelText: 'Primeira ação (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('salvar-objetivo'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Salvar objetivo'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final DateTime now = demoSession.now;
    _run(
      context,
      () => store.addGoal(
        actor,
        childId,
        objective: objective.text,
        responsibleId: responsible.professionalId,
        dueDate: now.add(Duration(days: due)),
        reassessAt: now.add(Duration(days: reassess)),
        firstAction: action.text,
      ),
      ok: 'Objetivo incluído no plano conjunto.',
    );
  }

  Future<void> _aiOverview(BuildContext context, String childId) async {
    final CareAiDraft draft;
    try {
      draft = CareAi.teamOverview(
        demoSession.care.store,
        demoSession.care.actor,
        childId,
      );
    } on CareAccessDenied catch (e) {
      showDemoSnack(context, e.message);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Visão da equipe com IA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DemoTag(CareAiDraft.label),
              const SizedBox(height: AppSpacing.sm),
              const DemoNotice(
                icon: Icons.lock_outline_rounded,
                text:
                    'A IA usou só os resumos compartilhados com você e o plano '
                    'conjunto. Registros completos, anotações privadas e '
                    'anexos não entram. Este texto não é salvo.',
              ),
              const SizedBox(height: AppSpacing.md),
              SelectionArea(
                child: Text(
                  draft.text,
                  key: const ValueKey<String>('ia-texto'),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            key: const ValueKey<String>('ia-fechar'),
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  List<Widget> _manageTeam(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final List<CareLink> team = store.team(actor, child.id);
    return <Widget>[
      const DemoNotice(
        icon: Icons.shield_outlined,
        text:
            'A gestão organiza a equipe (designa e encerra vínculos), mas não '
            'lê registros clínicos. Todo vínculo novo aguarda a autorização '
            'da família.',
      ),
      DemoSectionTitle(
        'Equipe da clínica',
        trailing: TextButton.icon(
          key: const ValueKey<String>('designar'),
          onPressed: () => _assign(context, child),
          icon: const Icon(Icons.person_add_alt_outlined, size: 18),
          label: const Text('Designar profissional'),
        ),
      ),
      for (final CareLink l in team)
        _LinkCard(
          link: l,
          onEnd: l.endedAt == null ? () => _endLink(context, l) : null,
        ),
    ];
  }

  Future<void> _assign(BuildContext context, DemoPatient child) async {
    final CareActor actor = demoSession.care.actor;
    final List<DemoAccount> options = DemoProfessional.accounts
        .where(
          (DemoAccount a) =>
              a.clinicId == actor.clinicId &&
              !demoSession.care.store.links.any(
                (CareLink l) =>
                    l.childId == child.id &&
                    l.professionalId == a.id &&
                    l.endedAt == null,
              ),
        )
        .toList();
    if (options.isEmpty) {
      showDemoSnack(
        context,
        'Todos os profissionais da clínica já estão na equipe.',
      );
      return;
    }
    DemoAccount selected = options.first;
    final TextEditingController reason = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: const Text('Designar profissional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final DemoAccount a in options)
                      ChoiceChip(
                        label: Text('${a.name} (${a.specialty})'),
                        selected: a.id == selected.id,
                        onSelected: (_) => set(() => selected = a),
                      ),
                  ],
                ),
                TextField(
                  key: const ValueKey<String>('designar-motivo'),
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo do encaminhamento *',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Designar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (reason.text.trim().isEmpty) {
      showDemoSnack(context, 'Informe o motivo do encaminhamento.');
      return;
    }
    _run(
      context,
      () => demoSession.care.store.requestLink(
        actor,
        childId: child.id,
        professionalId: selected.id,
        professionalName: selected.name,
        specialty: CareSpecialty.fromText(selected.specialty)!,
        clinicId: selected.clinicId!,
        clinicName: selected.clinic,
        reason: reason.text.trim(),
        registry: selected.registry,
      ),
      ok: '${selected.name} designado. Aguarda a autorização da família.',
    );
  }

  Future<void> _endLink(BuildContext context, CareLink link) async {
    final String? reason = await _askReason(
      context,
      title: 'Encerrar vínculo de ${link.professionalName}',
      label: 'Motivo do encerramento *',
      confirm: 'Encerrar vínculo',
    );
    if (reason == null || !context.mounted) return;
    _run(
      context,
      () =>
          demoSession.care.store.endLink(demoSession.care.actor, link, reason),
      ok: 'Vínculo encerrado. O acesso de ${link.professionalName} foi retirado.',
    );
  }

  // --------------------------------------------------------- Áreas

  List<Widget> _area(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareSpecialty s,
  ) {
    final CareStore store = demoSession.care.store;
    final CareLink? link = store.linkOf(actor, child.id);
    final bool own = link != null && link.specialty == s;
    final bool authorArea = own || (link == null && actor.specialty == s);
    final List<CareRecord> records = store.recordsFor(
      actor,
      child.id,
      specialty: s,
    );
    final List<CareRecord> mine = records
        .where((CareRecord r) => r.authorId == actor.id)
        .toList();
    final List<CareRecord> granted = records
        .where((CareRecord r) => r.authorId != actor.id)
        .toList();
    final List<CareSummary> fromArea = link == null || own
        ? const <CareSummary>[]
        : store
              .summariesFor(actor, child.id)
              .where(
                (CareSummary x) => x.specialty == s && x.authorId != actor.id,
              )
              .toList();
    final List<CareRecord> measures =
        mine.where((CareRecord r) => r.kind == CareRecordKind.medida).toList()
          ..sort(
            (CareRecord a, CareRecord b) => a.createdAt.compareTo(b.createdAt),
          );
    final List<DemoAppointment> agenda = own
        ? demoSession.care
              .nextSessions(child.id)
              .where((DemoAppointment a) => a.professionalId == actor.id)
              .toList()
        : const <DemoAppointment>[];
    return <Widget>[
      if (link == null)
        const DemoNotice(
          icon: Icons.history_rounded,
          color: AppColors.warning,
          text:
              'Seu vínculo com a criança foi encerrado. Você vê apenas os '
              'registros que fez, somente para leitura.',
        ),
      if (own)
        const DemoNotice(
          icon: Icons.lock_outline_rounded,
          text:
              'Seus registros ficam só com você. Para a equipe, crie um resumo '
              'escolhendo exatamente o que compartilhar; anotações privadas, '
              'transcrições e conversas nunca entram.',
        ),
      if (!authorArea)
        DemoNotice(
          icon: Icons.lock_outline_rounded,
          text:
              'Registros da ${s.area.toLowerCase()} ficam com quem atendeu. '
              'Aqui aparecem só os resumos compartilhados com você e registros '
              'com acesso concedido.',
        ),
      if (own) ...<Widget>[
        DemoSectionTitle('Agenda da ${s.area.toLowerCase()}'),
        ..._sessions(context, agenda),
      ],
      if (measures.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Medidas de acompanhamento'),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final CareRecord m in measures)
                Text(
                  '${demoDate(m.createdAt)} - ${m.title}: ${m.measure ?? '-'}',
                ),
            ],
          ),
        ),
      ],
      if (authorArea) ...<Widget>[
        DemoSectionTitle(
          'Meus registros da ${s.area.toLowerCase()}',
          trailing: own
              ? FilledButton.icon(
                  key: const ValueKey<String>('novo-registro'),
                  onPressed: () => _newRecord(context, child.id, s),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Novo registro'),
                )
              : null,
        ),
        if (mine.isEmpty) const Text('Nenhum registro seu nesta área.'),
        for (final CareRecord r in mine) _RecordCard(record: r, editable: own),
      ] else ...<Widget>[
        DemoSectionTitle('Resumos da ${s.area.toLowerCase()} para você'),
        if (fromArea.isEmpty)
          const Text('Nada desta área foi compartilhado com você.'),
        for (final CareSummary x in fromArea) _SummaryCard(summary: x),
      ],
      if (granted.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Registros com acesso concedido a você'),
        for (final CareRecord r in granted)
          _RecordCard(record: r, editable: false),
      ],
    ];
  }

  Future<void> _newRecord(
    BuildContext context,
    String childId,
    CareSpecialty s,
  ) async {
    final List<CareRecordKind> kinds = CarePolicy.kindsFor(s).toList();
    CareRecordKind kind = kinds.first;
    CareVisibility visibility = CareVisibility.privado;
    final TextEditingController title = TextEditingController();
    final TextEditingController body = TextEditingController();
    final TextEditingController clinical = TextEditingController();
    final TextEditingController privateNote = TextEditingController();
    final TextEditingController measure = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) {
          final List<CareVisibility> allowed = <CareVisibility>[
            CareVisibility.privado,
            if (kind.canGoToFamily) CareVisibility.familia,
          ];
          if (!allowed.contains(visibility)) {
            visibility = CareVisibility.privado;
          }
          return AlertDialog(
            title: Text('Novo registro - ${s.area}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Tipo'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CareRecordKind k in kinds)
                        ChoiceChip(
                          key: ValueKey<String>('tipo-${k.name}'),
                          label: Text(k.label),
                          selected: k == kind,
                          onSelected: (_) => set(() => kind = k),
                        ),
                    ],
                  ),
                  TextField(
                    key: const ValueKey<String>('registro-titulo'),
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título *'),
                  ),
                  TextField(
                    key: const ValueKey<String>('registro-texto'),
                    controller: body,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Registro completo do atendimento *',
                    ),
                  ),
                  if (kind == CareRecordKind.medida)
                    TextField(
                      key: const ValueKey<String>('registro-medida'),
                      controller: measure,
                      decoration: const InputDecoration(
                        labelText: 'Medida (valor e unidade)',
                      ),
                    ),
                  TextField(
                    key: const ValueKey<String>('registro-clinica'),
                    controller: clinical,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText:
                          'Síntese clínica (pode ser escolhida para um resumo)',
                    ),
                  ),
                  TextField(
                    key: const ValueKey<String>('registro-privada'),
                    controller: privateNote,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Anotação privada (nunca entra em resumo)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Quem pode ver'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CareVisibility v in allowed)
                        ChoiceChip(
                          key: ValueKey<String>('visibilidade-${v.name}'),
                          avatar: Icon(_visibilityIcon(v), size: 16),
                          label: Text(v.label),
                          selected: v == visibility,
                          onSelected: (_) => set(() => visibility = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const DemoNotice(
                    icon: Icons.lock_outline_rounded,
                    text:
                        'Nada vai para a equipe ao salvar. Para compartilhar, '
                        'crie depois um resumo e escolha o que entra.',
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey<String>('salvar-registro'),
                onPressed: () => Navigator.of(d).pop(true),
                child: const Text('Salvar registro'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !context.mounted) return;
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      showDemoSnack(context, 'Preencha título e registro.');
      return;
    }
    _run(
      context,
      () => demoSession.care.store.addRecord(
        demoSession.care.actor,
        childId: childId,
        kind: kind,
        title: title.text.trim(),
        body: body.text.trim(),
        visibility: visibility,
        measure: measure.text.trim().isEmpty ? null : measure.text.trim(),
        sections: <CareSectionInput>[
          (
            kind: CareSectionKind.clinica,
            label: 'Síntese clínica',
            text: clinical.text,
          ),
          (
            kind: CareSectionKind.anotacaoPrivada,
            label: 'Anotação privada',
            text: privateNote.text,
          ),
        ],
      ),
      ok:
          'Registro salvo (${visibility.label.toLowerCase()}). Nada foi '
          'compartilhado com a equipe.',
    );
  }

  // --------------------------------------------------- Comunicação

  List<Widget> _communication(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final List<CareMessage> all = store.messagesFor(actor, child.id);
    final List<CareMessage> roots = all
        .where((CareMessage m) => m.replyTo == null)
        .toList();
    return <Widget>[
      DemoSectionTitle(
        'Comunicação da equipe',
        trailing: FilledButton.icon(
          key: const ValueKey<String>('nova-mensagem'),
          onPressed: () => _compose(context, child.id),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Nova mensagem'),
        ),
      ),
      const DemoNotice(
        icon: Icons.groups_2_outlined,
        text:
            'Encaminhamentos, pareceres e mensagens ficam com a equipe que '
            'atende a criança, com autor, data e histórico. A família não '
            'vê esta área.',
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final CareMessage m in roots)
        _MessageCard(
          message: m,
          replies: all.where((CareMessage r) => r.replyTo == m.id).toList()
            ..sort((CareMessage a, CareMessage b) => a.at.compareTo(b.at)),
          onReply: () => _compose(context, child.id, replyTo: m),
        ),
    ];
  }

  Future<void> _compose(
    BuildContext context,
    String childId, {
    CareMessage? replyTo,
  }) async {
    CareMessageKind kind = replyTo == null
        ? CareMessageKind.mensagem
        : CareMessageKind.mensagem;
    CareSpecialty? to = replyTo?.authorSpecialty;
    final TextEditingController subject = TextEditingController(
      text: replyTo == null ? '' : 'Re: ${replyTo.subject}',
    );
    final TextEditingController body = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: Text(replyTo == null ? 'Nova mensagem' : 'Responder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (replyTo == null) ...<Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CareMessageKind k in CareMessageKind.values)
                        ChoiceChip(
                          key: ValueKey<String>('msg-${k.name}'),
                          label: Text(k.label),
                          selected: k == kind,
                          onSelected: (_) => set(() => kind = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Para'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CareSpecialty s in CareSpecialty.values)
                        ChoiceChip(
                          key: ValueKey<String>('para-${s.name}'),
                          label: Text(
                            s.active ? s.area : '${s.area} (em breve)',
                          ),
                          selected: s == to,
                          onSelected: (_) => set(() => to = s),
                        ),
                    ],
                  ),
                ],
                TextField(
                  key: const ValueKey<String>('msg-assunto'),
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Assunto *'),
                ),
                TextField(
                  key: const ValueKey<String>('msg-texto'),
                  controller: body,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Mensagem *'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('enviar-mensagem'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    _run(
      context,
      () => demoSession.care.store.send(
        demoSession.care.actor,
        childId: childId,
        kind: replyTo == null ? kind : CareMessageKind.mensagem,
        subject: subject.text,
        body: body.text,
        toSpecialty: to,
        replyTo: replyTo?.id,
      ),
      ok: replyTo == null ? 'Mensagem enviada à equipe.' : 'Resposta enviada.',
    );
  }

  // ------------------------------------------------------ Documentos

  List<Widget> _documents(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final CareLink link = store.linkOf(actor, child.id)!;
    final List<CareDocument> docs = store.documentsFor(actor, child.id);
    final Set<CareDocKind> allowed = CarePolicy.docsFor(link.specialty);
    final List<CareDocKind> blocked = CareDocKind.values
        .where((CareDocKind k) => !allowed.contains(k))
        .toList();
    return <Widget>[
      DemoSectionTitle(
        'Meus documentos',
        trailing: FilledButton.icon(
          key: const ValueKey<String>('novo-documento'),
          onPressed: () => _newDocument(context, child, link),
          icon: const Icon(Icons.note_add_outlined, size: 18),
          label: const Text('Novo documento'),
        ),
      ),
      DemoNotice(
        icon: Icons.rule_rounded,
        text:
            '${link.specialty.area} prepara: '
            '${allowed.map((CareDocKind k) => k.label).join(', ')}. '
            'Não disponível para esta especialidade: '
            '${blocked.map((CareDocKind k) => k.label).join(', ')}. '
            'Documentos ficam com o autor; a família recebe só os que você '
            'liberar.',
      ),
      if (link.specialty == CareSpecialty.pediatria) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        const DemoNotice(
          text:
              'Receitas, atestados e pedidos de exame da pediatria continuam '
              'em Documentos da consulta, com versões e PDF.',
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      if (docs.isEmpty) const Text('Nenhum documento visível para você.'),
      for (final CareDocument d in docs)
        _DocCard(doc: d, mine: d.authorId == actor.id),
      const DemoSectionTitle('Meus modelos'),
      for (final CareTemplate t in store.templatesOf(actor))
        PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('${t.title} (${t.kind.label})'),
        ),
      if (store.templatesOf(actor).isEmpty)
        const Text('Nenhum modelo próprio nesta especialidade.'),
    ];
  }

  Future<void> _newDocument(
    BuildContext context,
    DemoPatient child,
    CareLink link,
  ) async {
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final List<CareDocKind> kinds = CarePolicy.docsFor(link.specialty).toList();
    final List<CareTemplate> mine = store.templatesOf(actor);
    CareDocKind kind = kinds.first;
    CareTemplate? template;
    final TextEditingController body = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: Text('Novo documento - ${link.specialty.area}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final CareDocKind k in kinds)
                      ChoiceChip(
                        key: ValueKey<String>('doc-${k.name}'),
                        label: Text(k.label),
                        selected: k == kind,
                        onSelected: (_) => set(() {
                          kind = k;
                          template = null;
                        }),
                      ),
                  ],
                ),
                if (mine.any((CareTemplate t) => t.kind == kind)) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Meus modelos'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CareTemplate t in mine.where(
                        (CareTemplate t) => t.kind == kind,
                      ))
                        ActionChip(
                          key: ValueKey<String>('usar-modelo-${t.id}'),
                          label: Text('Usar modelo: ${t.title}'),
                          onPressed: () => set(() {
                            template = t;
                            body.text = CareStore.applyTemplate(
                              t,
                              childName: child.name,
                              guardianName: child.guardianName,
                              professionalName: actor.name,
                              registry: link.registry,
                              date: demoDate(demoSession.now),
                            );
                          }),
                        ),
                    ],
                  ),
                ],
                TextField(
                  key: const ValueKey<String>('doc-texto'),
                  controller: body,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Texto *'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('salvar-documento'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Salvar rascunho'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (body.text.trim().isEmpty) {
      showDemoSnack(context, 'Preencha o texto do documento.');
      return;
    }
    _run(
      context,
      () => store.createDocument(
        actor,
        childId: child.id,
        kind: kind,
        title: kind.label,
        body: body.text.trim(),
        registry: link.registry,
        templateId: template?.id,
      ),
      ok: 'Rascunho salvo. Revise antes de emitir.',
    );
  }

  // --------------------------------------------------------- Família

  List<Widget> _family(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final CareFamilyView view = store.familyView(actor, child.id);
    final Map<String, List<CareRecord>> byProfessional =
        <String, List<CareRecord>>{};
    for (final CareRecord r in view.released) {
      byProfessional.putIfAbsent(r.origin, () => <CareRecord>[]).add(r);
    }
    return <Widget>[
      if (view.pendingLinks.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Autorizações pendentes'),
        for (final CareLink l in view.pendingLinks)
          PremiumCard(
            borderColor: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l.professionalName} (${l.specialty.profession}) pediu '
                  'acesso ao acompanhamento.',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text('Motivo: ${l.reason}'),
                Text(
                  '${l.clinicName} - pedido por ${l.requestedBy} em '
                  '${demoDate(l.since)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    FilledButton(
                      key: ValueKey<String>('autorizar-${l.id}'),
                      onPressed: () => _run(
                        context,
                        () => store.authorize(actor, l),
                        ok:
                            '${l.professionalName} passa a fazer parte da '
                            'equipe.',
                      ),
                      child: const Text('Autorizar acesso'),
                    ),
                    OutlinedButton(
                      onPressed: () => _run(
                        context,
                        () => store.endLink(actor, l, 'Recusado pela família'),
                        ok: 'Pedido recusado.',
                      ),
                      child: const Text('Recusar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
      const DemoSectionTitle('Próximas sessões'),
      ..._sessions(context, demoSession.care.nextSessions(child.id)),
      const DemoSectionTitle('Orientações e atividades para casa'),
      const DemoNotice(
        icon: Icons.verified_user_outlined,
        text:
            'Aqui aparece só o que cada profissional liberou para a família. '
            'Registros completos, anotações privadas e resumos da equipe não '
            'aparecem.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (view.released.isEmpty) const Text('Nada liberado ainda.'),
      for (final MapEntry<String, List<CareRecord>> e in byProfessional.entries)
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(e.key, style: Theme.of(context).textTheme.titleSmall),
              for (final CareRecord r in e.value) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${r.kind.label}: ${r.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(r.body),
                Text(
                  'Liberado em ${demoDate(r.releasedAt ?? r.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      if (view.documents.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Documentos liberados'),
        for (final CareDocument d in view.documents)
          _DocCard(doc: d, mine: false),
      ],
      const DemoSectionTitle('Equipe que acompanha'),
      for (final CareLink l in view.team)
        _LinkCard(link: l, onEnd: () => _endLink(context, l)),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        key: const ValueKey<String>('trocar-clinica'),
        onPressed: () => _transfer(context, child),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Trocar de clínica'),
      ),
    ];
  }

  Future<void> _transfer(BuildContext context, DemoPatient child) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Trocar de clínica'),
        content: Text(
          'O acompanhamento de ${child.name} passa para '
          '${DemoProfessional.colleague.clinic}. Todos os vínculos atuais são '
          'encerrados; a nova equipe precisa da sua autorização e não vê os '
          'registros da equipe anterior. O que foi liberado para você '
          'continua aqui.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-troca'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Confirmar troca'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _run(context, () {
      final CareStore store = demoSession.care.store;
      store.transferClinic(
        demoSession.care.actor,
        child.id,
        toClinicName: DemoProfessional.colleague.clinic,
      );
      // A nova clínica pede o vínculo da pediatra dela; a família autoriza.
      store.requestLink(
        CareActor(
          id: DemoProfessional.colleague.id,
          name: DemoProfessional.colleague.name,
          role: CareActorRole.profissional,
          specialty: CareSpecialty.pediatria,
          clinicId: DemoProfessional.colleague.clinicId,
        ),
        childId: child.id,
        professionalId: DemoProfessional.colleague.id,
        professionalName: DemoProfessional.colleague.name,
        specialty: CareSpecialty.pediatria,
        clinicId: DemoProfessional.colleague.clinicId!,
        clinicName: DemoProfessional.colleague.clinic,
        reason: 'Novo pediatra após a troca de clínica',
        registry: DemoProfessional.colleague.registry,
      );
    }, ok: 'Clínica trocada. Autorize a nova equipe quando quiser.');
  }

  // ----------------------------------------------------------- Acessos

  List<Widget> _audit(
    BuildContext context,
    DemoPatient child,
    CareActor actor,
    CareStore store,
  ) {
    final List<CareAuditEntry> entries = store.auditFor(actor, child.id);
    return <Widget>[
      const DemoSectionTitle('Registro de acessos e alterações'),
      const DemoNotice(
        icon: Icons.manage_search_rounded,
        text:
            'Quem abriu, criou, alterou, liberou ou tentou acessar sem '
            'permissão. A trilha não mostra o conteúdo clínico.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (entries.isEmpty) const Text('Nenhum acesso registrado ainda.'),
      for (final CareAuditEntry e in entries.take(60))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            e.allowed ? Icons.check_circle_outline : Icons.block_rounded,
            color: e.allowed ? AppColors.success : AppColors.danger,
          ),
          title: Text('${e.actorName} ${e.action}'),
          subtitle: Text(
            '${e.target} - ${_dt(e.at)}${e.allowed ? '' : ' - acesso bloqueado'}',
          ),
        ),
    ];
  }
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String initial = '',
}) async {
  final TextEditingController c = TextEditingController(text: initial);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext d) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey<String>('motivo'),
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey<String>('confirmar-motivo'),
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  final String v = c.text.trim();
  if (v.isEmpty) {
    if (context.mounted) showDemoSnack(context, 'Informe o motivo.');
    return null;
  }
  return v;
}

class _Header extends StatelessWidget {
  const _Header({required this.child, required this.actor});

  final DemoPatient child;
  final CareActor actor;

  @override
  Widget build(BuildContext context) {
    final CareLink? link = demoSession.care.store.linkOf(actor, child.id);
    final String who = switch (actor.role) {
      CareActorRole.profissional =>
        '${actor.name} - ${link?.specialty.area ?? actor.specialty?.area ?? ''}'
            '${link == null ? ' (sem vínculo ativo)' : ''}',
      _ => '${actor.name} - ${actor.role.label}',
    };
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            child.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('${child.ageLabel} - Responsável: ${child.guardianName}'),
          const SizedBox(height: AppSpacing.xs),
          Text('Você: $who', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, this.onEnd});

  final CareLink link;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Color color = link.active
        ? AppColors.success
        : link.pending
        ? AppColors.warning
        : AppColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(link.professionalName, style: t.titleSmall),
                DemoTag(link.statusLabel, color: color),
              ],
            ),
            Text(
              '${link.specialty.profession}'
              '${link.registry.isEmpty ? '' : ' - ${link.registry}'}',
            ),
            Text('Motivo do encaminhamento: ${link.reason}'),
            Text(
              '${link.clinicName} - desde ${demoDate(link.since)}, pedido por '
              '${link.requestedBy}'
              '${link.authorizedBy == null ? '' : '; autorizado por ${link.authorizedBy}'}',
              style: t.bodySmall,
            ),
            if (link.endedAt != null)
              Text(
                'Encerrado em ${demoDate(link.endedAt!)} por ${link.endedBy}: '
                '${link.endReason}',
                style: t.bodySmall,
              ),
            if (onEnd != null && link.endedAt == null)
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  container: true,
                  button: true,
                  excludeSemantics: true,
                  onTap: onEnd,
                  label:
                      '${link.pending ? 'Cancelar pedido' : 'Encerrar vínculo'} '
                      'de ${link.professionalName}',
                  child: TextButton(
                    key: ValueKey<String>('encerrar-${link.id}'),
                    onPressed: onEnd,
                    child: Text(
                      link.pending ? 'Cancelar pedido' : 'Encerrar vínculo',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Resumo para a equipe: o destinatário vê só o que o autor escolheu; o autor
/// vê também destinatários, versões e quem acessou.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final CareSummary summary;

  @override
  Widget build(BuildContext context) {
    final CareSummary s = summary;
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final bool mine = s.authorId == actor.id;
    final List<CareAttachment> files = store.summaryAttachments(actor, s);
    final List<CareSummaryAccess> accesses = mine
        ? store.accessesOf(actor, s)
        : const <CareSummaryAccess>[];
    final TextTheme t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      identifier: 'resumo:${s.recordTitle}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor: mine ? null : AppColors.brand.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('Resumo: ${s.recordTitle}', style: t.titleSmall),
                  DemoTag(
                    mine ? s.status.label : 'Compartilhado com você',
                    color: s.published ? AppColors.brand : AppColors.inkMuted,
                  ),
                  DemoTag('Versão ${s.version}', color: AppColors.inkMuted),
                  if (s.aiAssisted)
                    DemoTag(
                      'Preparado com IA, revisado por ${s.reviewedBy}',
                      color: AppColors.warning,
                    ),
                ],
              ),
              for (final CareShareItem i in s.items) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  i.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(i.text),
              ],
              if (s.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text('Observação: ${s.note}'),
              ],
              for (final CareAttachment f in files)
                Text(
                  'Anexo escolhido: ${f.fileName}',
                  style: t.bodySmall?.copyWith(color: AppColors.brand),
                ),
              const SizedBox(height: 4),
              Text(
                'Origem: ${s.specialty.area} - ${s.authorName} - '
                '${_dt(s.updatedAt ?? s.createdAt)}',
                style: t.bodySmall,
              ),
              if (mine) ...<Widget>[
                Text('Destinatários: ${s.recipientsLabel}', style: t.bodySmall),
                Semantics(
                  container: true,
                  child: ExpansionTile(
                    key: ValueKey<String>('versoes-${s.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text('Versões (${s.versions.length})'),
                    children: <Widget>[
                      for (final CareSummaryVersion v in s.versions.reversed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            'Versão ${v.version} - ${v.status.label}'
                            '${v.reason == null ? '' : ': ${v.reason}'}',
                          ),
                          subtitle: Text(
                            '${_dt(v.at)} - ${v.actorName} - para '
                            '${v.recipientNames.join(', ')} - itens: '
                            '${v.items.map((CareShareItem i) => i.label).join(', ')}'
                            '${v.note.isEmpty ? '' : ', observação'}'
                            '${v.attachmentNames.isEmpty ? '' : ' - anexos: ${v.attachmentNames.join(', ')}'}',
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  child: ExpansionTile(
                    key: ValueKey<String>('acessos-${s.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text('Quem acessou (${accesses.length})'),
                    children: <Widget>[
                      if (accesses.isEmpty)
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nenhum acesso ainda.'),
                        ),
                      for (final CareSummaryAccess a in accesses)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(a.actorName),
                          subtitle: Text('${_dt(a.at)} - versão ${a.version}'),
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    TextButton(
                      key: ValueKey<String>('atualizar-resumo-${s.id}'),
                      onPressed: () =>
                          context.go(careSummaryPath(s.childId, s.recordId)),
                      child: Text(
                        s.published ? 'Atualizar resumo' : 'Publicar novamente',
                      ),
                    ),
                    if (s.published)
                      TextButton(
                        key: ValueKey<String>('encerrar-resumo-${s.id}'),
                        onPressed: () async {
                          final String? why = await _askReason(
                            context,
                            title: 'Encerrar acesso ao resumo',
                            label: 'Motivo *',
                            confirm: 'Encerrar acesso',
                          );
                          if (why == null || !context.mounted) return;
                          _run(
                            context,
                            () => store.endSummary(actor, s, why),
                            ok:
                                'Acesso encerrado. As versões continuam no '
                                'histórico.',
                          );
                        },
                        child: const Text('Encerrar acesso'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.editable});

  final CareRecord record;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final CareRecord r = record;
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final bool mine = r.authorId == actor.id;
    final List<CareSection> sections = store.sectionsFor(actor, r);
    final List<CareAttachment> files = store.attachmentsFor(actor, r);
    final CareRecordGrant? grant = mine ? null : store.grantOf(actor, r);
    final CareSummary? summary = mine ? store.summaryOf(r.id) : null;
    final List<CareRecordGrant> grants = mine
        ? store.grantsFor(actor, r)
        : const <CareRecordGrant>[];
    final int hidden = mine ? 0 : r.lockedSections.length;
    final TextTheme t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      identifier: 'registro:${r.title}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(r.kind.label, style: t.labelMedium),
                  DemoTag(
                    r.visibility.label,
                    color: _visibilityColor(r.visibility),
                  ),
                  if (grant != null)
                    const DemoTag('Acesso concedido', color: AppColors.warning),
                  if (summary != null && summary.published)
                    DemoTag(
                      'Resumo v${summary.version} compartilhado',
                      color: AppColors.brand,
                    ),
                  if (summary != null && !summary.published)
                    const DemoTag(
                      'Resumo encerrado',
                      color: AppColors.inkMuted,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.title, style: t.titleSmall),
              Text(r.body),
              if (r.measure != null) Text('Medida: ${r.measure}'),
              for (final CareSection sec in sections)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: sec.kind.shareable
                        ? AppColors.softBlue
                        : AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            sec.kind.shareable
                                ? Icons.notes_rounded
                                : Icons.lock_outline_rounded,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              sec.kind.shareable
                                  ? sec.label
                                  : '${sec.label} - só você vê; nunca entra em '
                                        'resumo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(sec.text),
                    ],
                  ),
                ),
              if (hidden > 0)
                Text(
                  '$hidden parte(s) privada(s) do autor não aparecem para você.',
                  style: t.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(
                'Origem: ${r.origin} - ${demoDate(r.createdAt)}'
                '${r.updatedAt == null ? '' : ' (alterado em ${demoDate(r.updatedAt!)})'}',
                style: t.bodySmall,
              ),
              if (grant != null)
                Text(
                  'Acesso concedido por ${grant.grantedBy} em '
                  '${demoDate(grant.grantedAt)}: ${grant.justification}',
                  style: t.bodySmall,
                ),
              for (final CareAttachment f in files)
                Text(
                  'Anexo: ${f.fileName}',
                  style: t.bodySmall?.copyWith(color: AppColors.brand),
                ),
              if (summary != null)
                Text(
                  'Resumo ${summary.status.label.toLowerCase()} - versão '
                  '${summary.version} - ${summary.recipientsLabel}',
                  style: t.bodySmall,
                ),
              if (mine && r.revisions.isNotEmpty)
                Semantics(
                  container: true,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Histórico de alterações (${r.revisions.length})',
                    ),
                    children: <Widget>[
                      for (final CareRevision v in r.revisions.reversed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${v.actorName} - ${v.note}'),
                          subtitle: Text(
                            '${_dt(v.at)} - antes: ${v.previousBody}',
                          ),
                        ),
                    ],
                  ),
                ),
              if (grants.isNotEmpty)
                Semantics(
                  container: true,
                  child: ExpansionTile(
                    key: ValueKey<String>('concessoes-${r.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Acessos concedidos ao registro completo (${grants.length})',
                    ),
                    children: <Widget>[
                      for (final CareRecordGrant g in grants)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${g.granteeName} (${g.granteeSpecialty.area})',
                          ),
                          subtitle: Text(
                            '${g.justification} - ${_dt(g.grantedAt)}'
                            '${g.active ? '' : ' - retirado em ${_dt(g.revokedAt!)}: ${g.revokeReason}'}',
                          ),
                          trailing: g.active
                              ? TextButton(
                                  key: ValueKey<String>('revogar-${g.id}'),
                                  onPressed: () async {
                                    final String? why = await _askReason(
                                      context,
                                      title:
                                          'Retirar acesso de ${g.granteeName}',
                                      label: 'Motivo *',
                                      confirm: 'Retirar acesso',
                                    );
                                    if (why == null || !context.mounted) return;
                                    _run(
                                      context,
                                      () => store.revokeGrant(actor, g, why),
                                      ok: 'Acesso de ${g.granteeName} retirado.',
                                    );
                                  },
                                  child: const Text('Retirar'),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              if (editable)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    TextButton(
                      key: ValueKey<String>('resumo-${r.id}'),
                      onPressed: () =>
                          context.go(careSummaryPath(r.childId, r.id)),
                      child: Text(
                        summary == null
                            ? 'Criar resumo para a equipe'
                            : summary.published
                            ? 'Atualizar resumo'
                            : 'Publicar novo resumo',
                      ),
                    ),
                    TextButton(
                      key: ValueKey<String>('conceder-${r.id}'),
                      onPressed: () => _grant(context, r),
                      child: const Text('Conceder acesso ao registro'),
                    ),
                    TextButton(
                      key: ValueKey<String>('alterar-${r.id}'),
                      onPressed: () => _edit(context, r),
                      child: const Text('Alterar'),
                    ),
                    if (r.kind.canGoToFamily &&
                        r.visibility == CareVisibility.privado)
                      TextButton(
                        key: ValueKey<String>('liberar-${r.id}'),
                        onPressed: () => _run(
                          context,
                          () => store.release(actor, r),
                          ok: 'Liberado para a família.',
                        ),
                        child: const Text('Liberar para a família'),
                      ),
                    if (r.visibility == CareVisibility.familia)
                      TextButton(
                        key: ValueKey<String>('retirar-${r.id}'),
                        onPressed: () async {
                          final String? why = await _askReason(
                            context,
                            title: 'Retirar da família',
                            label: 'Motivo *',
                            confirm: 'Retirar',
                          );
                          if (why == null || !context.mounted) return;
                          _run(
                            context,
                            () => store.withdraw(actor, r, why),
                            ok: 'Retirado da área da família.',
                          );
                        },
                        child: const Text('Retirar da família'),
                      ),
                    TextButton(
                      onPressed: () => _run(
                        context,
                        () => store.attach(
                          actor,
                          r,
                          'anexo-exemplo-${files.length + 1}.pdf',
                        ),
                        ok: 'Anexo fictício adicionado (simulado).',
                      ),
                      child: const Text('Anexar arquivo (simulado)'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _grant(BuildContext context, CareRecord r) async {
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final List<CareLink> team = store.colleaguesOf(actor, r.childId);
    if (team.isEmpty) {
      showDemoSnack(context, 'Não há outros profissionais na equipe.');
      return;
    }
    CareLink? to;
    final TextEditingController why = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: const Text('Acesso ao registro completo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.policy_outlined,
                  text:
                      'Use só quando o resumo não basta. A pessoa verá o '
                      'registro e os anexos, nunca as anotações privadas, '
                      'transcrições e conversas. Fica registrado com a '
                      'justificativa e você pode retirar a qualquer momento.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Profissional'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final CareLink l in team)
                      ChoiceChip(
                        key: ValueKey<String>(
                          'conceder-para-${l.professionalId}',
                        ),
                        label: Text(
                          '${l.professionalName} (${l.specialty.area})',
                        ),
                        selected: l == to,
                        onSelected: (_) => set(() => to = l),
                      ),
                  ],
                ),
                TextField(
                  key: const ValueKey<String>('justificativa'),
                  controller: why,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa * (mínimo de 15 caracteres)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('salvar-concessao'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Conceder acesso'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final CareLink? target = to;
    if (target == null) {
      showDemoSnack(context, 'Escolha o profissional.');
      return;
    }
    _run(
      context,
      () => store.grantAccess(
        actor,
        r,
        granteeId: target.professionalId,
        justification: why.text,
      ),
      ok:
          'Acesso concedido a ${target.professionalName}. Fica registrado na '
          'trilha.',
    );
  }

  Future<void> _edit(BuildContext context, CareRecord r) async {
    final TextEditingController body = TextEditingController(text: r.body);
    final TextEditingController note = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text('Alterar: ${r.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('alterar-texto'),
                controller: body,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Registro'),
              ),
              TextField(
                key: const ValueKey<String>('alterar-motivo'),
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Motivo da alteração *',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey<String>('salvar-alteracao'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Salvar alteração'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (note.text.trim().isEmpty) {
      showDemoSnack(context, 'Informe o motivo da alteração.');
      return;
    }
    _run(
      context,
      () => demoSession.care.store.edit(
        demoSession.care.actor,
        r,
        body: body.text.trim(),
        note: note.text.trim(),
      ),
      ok: 'Alteração salva. A versão anterior fica no histórico.',
    );
  }
}

/// Objetivo do plano terapêutico conjunto.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.actor,
    required this.canPlan,
  });

  final CarePlanGoal goal;
  final CareActor actor;
  final bool canPlan;

  @override
  Widget build(BuildContext context) {
    final CarePlanGoal g = goal;
    final TextTheme t = Theme.of(context).textTheme;
    final Color statusColor = switch (g.status) {
      CareGoalStatus.atingido => AppColors.success,
      CareGoalStatus.revisar => AppColors.warning,
      CareGoalStatus.emAndamento => AppColors.brand,
    };
    Widget line(CarePlanContribution c) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '- ${c.text} (${c.specialty.area} - ${c.authorName}, ${demoDate(c.at)})',
      ),
    );
    return Semantics(
      container: true,
      identifier: 'objetivo:${g.objective}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(g.objective, style: t.titleSmall),
                  DemoTag(g.status.label, color: statusColor),
                ],
              ),
              Text(
                'Responsável: ${g.responsibleName} (${g.responsibleSpecialty.area})',
              ),
              Text(
                'Prazo: ${demoDate(g.dueDate)} - Reavaliação: '
                '${demoDate(g.reassessAt)}',
                style: t.bodySmall,
              ),
              if (g.actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                const Text(
                  'Ações',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final CarePlanContribution c in g.actions) line(c),
              ],
              if (g.shared.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                const Text(
                  'Informações compartilhadas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final CarePlanContribution c in g.shared) line(c),
              ],
              if (g.reassessments.isNotEmpty)
                Semantics(
                  container: true,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Reavaliações (${g.reassessments.length})'),
                    children: <Widget>[
                      for (final CareReassessment r in g.reassessments.reversed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${r.status.label}${r.note.isEmpty ? '' : ': ${r.note}'}',
                          ),
                          subtitle: Text(
                            '${r.actorName} - ${_dt(r.at)} - próxima em '
                            '${demoDate(r.nextReassessAt)}',
                          ),
                        ),
                    ],
                  ),
                ),
              if (canPlan)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    TextButton(
                      key: ValueKey<String>('contribuir-${g.id}'),
                      onPressed: () => _contribute(context),
                      child: const Text('Contribuir'),
                    ),
                    if (g.responsibleId == actor.id)
                      TextButton(
                        key: ValueKey<String>('reavaliar-${g.id}'),
                        onPressed: () => _reassess(context),
                        child: const Text('Reavaliar'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contribute(BuildContext context) async {
    CareContributionKind kind = CareContributionKind.acao;
    final TextEditingController text = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: Text('Contribuir: ${goal.objective}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final CareContributionKind k
                        in CareContributionKind.values)
                      ChoiceChip(
                        key: ValueKey<String>('contrib-${k.name}'),
                        label: Text(k.label),
                        selected: k == kind,
                        onSelected: (_) => set(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const DemoNotice(
                  icon: Icons.lock_outline_rounded,
                  text:
                      'Escreva só o que deseja compartilhar com a equipe. Seu '
                      'registro completo não é anexado.',
                ),
                TextField(
                  key: const ValueKey<String>('contrib-texto'),
                  controller: text,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Texto *'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('salvar-contribuicao'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    _run(
      context,
      () => demoSession.care.store.contribute(
        demoSession.care.actor,
        goal,
        kind: kind,
        text: text.text,
      ),
      ok: 'Contribuição registrada no plano.',
    );
  }

  Future<void> _reassess(BuildContext context) async {
    CareGoalStatus status = goal.status;
    int next = 30;
    final TextEditingController note = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: Text('Reavaliar: ${goal.objective}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final CareGoalStatus s in CareGoalStatus.values)
                      ChoiceChip(
                        key: ValueKey<String>('status-${s.name}'),
                        label: Text(s.label),
                        selected: s == status,
                        onSelected: (_) => set(() => status = s),
                      ),
                  ],
                ),
                TextField(
                  key: const ValueKey<String>('reaval-nota'),
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'O que mudou (compartilhado com a equipe)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Próxima reavaliação'),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int days in const <int>[15, 30, 60])
                      ChoiceChip(
                        key: ValueKey<String>('proxima-$days'),
                        label: Text('em $days dias'),
                        selected: next == days,
                        onSelected: (_) => set(() => next = days),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('salvar-reavaliacao'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Salvar reavaliação'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    _run(
      context,
      () => demoSession.care.store.reassess(
        demoSession.care.actor,
        goal,
        status: status,
        note: note.text,
        nextReassessAt: demoSession.now.add(Duration(days: next)),
      ),
      ok: 'Reavaliação registrada.',
    );
  }
}

/// Resumo para a equipe em quatro passos: escolher as informações, escolher
/// os destinatários, conferir a prévia e confirmar.
class DemoCareSummaryScreen extends StatefulWidget {
  const DemoCareSummaryScreen({
    required this.childId,
    required this.recordId,
    super.key,
  });

  final String childId;
  final String recordId;

  @override
  State<DemoCareSummaryScreen> createState() => _DemoCareSummaryScreenState();
}

class _DemoCareSummaryScreenState extends State<DemoCareSummaryScreen> {
  static const List<String> _steps = <String>[
    'Informações',
    'Destinatários',
    'Prévia e confirmação',
  ];

  final TextEditingController _note = TextEditingController();
  CareSummaryDraft? _draft;
  CareSummaryPreview? _preview;
  CareSummary? _published;
  String? _error;
  int _step = 0;

  CareStore get _store => demoSession.care.store;
  CareActor get _actor => demoSession.care.actor;

  CareRecord? get _record => _store.records
      .where(
        (CareRecord r) =>
            r.id == widget.recordId && r.childId == widget.childId,
      )
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    final CareRecord? r = _record;
    if (r == null) {
      _error = 'Registro não encontrado.';
      return;
    }
    try {
      _draft = _store.startSummary(_actor, r);
      _note.text = _draft!.note;
    } on CareAccessDenied catch (e) {
      _error = e.message;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _snack(String text) {
    demoSession.changed();
    showDemoSnack(context, text);
  }

  void _toArea() => context.go(
    carePath(widget.childId, tab: CareTab.forSpecialty(_record!.specialty)),
  );

  void _next() {
    final CareSummaryDraft d = _draft!..note = _note.text;
    if (_step == 0) {
      if (d.itemIds.isEmpty && d.note.trim().isEmpty) {
        _snack('Escolha ao menos uma informação para o resumo.');
        return;
      }
      if (d.aiAssisted && !d.aiReviewed) {
        _snack('Revise o texto sugerido pela IA antes de continuar.');
        return;
      }
      setState(() => _step = 1);
      return;
    }
    try {
      final CareSummaryPreview p = _store.previewSummary(_actor, _record!, d);
      setState(() {
        _preview = p;
        _step = 2;
      });
    } on CareAccessDenied catch (e) {
      _snack(e.message);
    }
  }

  void _suggest() {
    final CareSummaryDraft d = _draft!;
    try {
      final CareAiDraft ai = CareAi.suggestSummaryNote(
        _store,
        _actor,
        _record!,
        d,
      );
      setState(() {
        _note.text = ai.text;
        d
          ..aiAssisted = true
          ..aiReviewed = false;
      });
    } on CareAccessDenied catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _confirm() async {
    final CareSummaryPreview p = _preview!;
    final String names = p.recipients
        .map((CareLink l) => l.professionalName)
        .join(', ');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          p.isUpdate ? 'Atualizar o resumo?' : 'Compartilhar o resumo?',
        ),
        content: Text(
          '${p.items.length + (p.note.isEmpty ? 0 : 1)} informação(ões) e '
          '${p.attachments.length} anexo(s) para $names. O registro completo '
          'continua só com você.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Voltar à prévia'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-compartilhamento'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Confirmar compartilhamento'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final CareSummary s = _store.publishSummary(
        _actor,
        _record!,
        _draft!,
        confirmed: true,
      );
      demoSession.changed();
      setState(() {
        _published = s;
        _step = 3;
      });
    } on CareAccessDenied catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CareRecord? r = _record;
    final CareSummaryDraft? d = _draft;
    if (_error != null || r == null || d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumo para a equipe')),
        body: DemoEmpty(
          title: 'Acesso restrito',
          message: _error ?? 'Só o autor do registro prepara o resumo.',
          actionLabel: 'Voltar à ficha',
          onAction: () => context.go(carePath(widget.childId)),
        ),
      );
    }
    final TextTheme t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Resumo para a equipe')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          DemoContent(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        r.title,
                        style: t.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${r.kind.label} - ${r.origin} - ${demoDate(r.createdAt)}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _step > 2
                            ? 'Concluído'
                            : 'Passo ${_step + 1} de 3: ${_steps[_step]}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...switch (_step) {
                  0 => _itemsStep(r, d),
                  1 => _recipientsStep(r, d),
                  2 => _previewStep(r, _preview!),
                  _ => _doneStep(_published!),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _itemsStep(CareRecord r, CareSummaryDraft d) {
    final List<CareAttachment> files = _store.attachments
        .where((CareAttachment a) => a.recordId == r.id)
        .toList();
    void toggle(Set<String> set, String id, bool? on) => setState(() {
      on == true ? set.add(id) : set.remove(id);
      if (d.aiAssisted) d.aiReviewed = false;
    });
    return <Widget>[
      const DemoNotice(
        icon: Icons.lock_outline_rounded,
        text:
            'Nada vem marcado. Escolha exatamente o que entra no resumo. '
            'Anotações privadas, transcrições e conversas não podem ser '
            'incluídas.',
      ),
      const DemoSectionTitle('Informações do registro'),
      for (final CareShareItem i in r.shareableItems)
        CheckboxListTile(
          key: ValueKey<String>('item-${i.id}'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.itemIds.contains(i.id),
          onChanged: (bool? v) => toggle(d.itemIds, i.id, v),
          title: Text(i.label),
          subtitle: Text(i.text, maxLines: 4, overflow: TextOverflow.ellipsis),
        ),
      for (final CareSection s in r.lockedSections)
        ListTile(
          key: ValueKey<String>('bloqueado-${s.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.danger,
          ),
          title: Text('${s.label} (${s.kind.label})'),
          subtitle: const Text('Fica só com você. Não pode entrar no resumo.'),
        ),
      if (files.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Anexos'),
        for (final CareAttachment a in files)
          CheckboxListTile(
            key: ValueKey<String>('anexo-${a.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: d.attachmentIds.contains(a.id),
            onChanged: (bool? v) => toggle(d.attachmentIds, a.id, v),
            title: Text(a.fileName),
            subtitle: const Text('Só entra se você marcar.'),
          ),
      ],
      DemoSectionTitle(
        'Observação para a equipe (opcional)',
        trailing: TextButton.icon(
          key: const ValueKey<String>('ia-sugerir'),
          onPressed: _suggest,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('Sugerir com IA'),
        ),
      ),
      TextField(
        key: const ValueKey<String>('resumo-nota'),
        controller: _note,
        minLines: 2,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Só o necessário para a continuidade do cuidado',
        ),
      ),
      if (d.aiAssisted) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        const DemoTag(CareAiDraft.label, color: AppColors.warning),
        const Text('A IA usou só as informações marcadas acima.'),
        CheckboxListTile(
          key: const ValueKey<String>('ia-revisado'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.aiReviewed,
          onChanged: (bool? v) => setState(() => d.aiReviewed = v ?? false),
          title: const Text('Revisei o texto sugerido pela IA'),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton(onPressed: _toArea, child: const Text('Cancelar')),
          FilledButton(
            key: const ValueKey<String>('proximo-1'),
            onPressed: _next,
            child: const Text('Escolher destinatários'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _recipientsStep(CareRecord r, CareSummaryDraft d) {
    final List<CareLink> team = _store
        .colleaguesOf(_actor, r.childId)
        .where((CareLink l) => l.clinicId == r.clinicId)
        .toList();
    return <Widget>[
      const DemoNotice(
        icon: Icons.groups_2_outlined,
        text:
            'Ninguém vem marcado. Escolha profissionais da equipe ou a equipe '
            'de cuidado autorizada (quem está na equipe agora; quem entrar '
            'depois não recebe este resumo).',
      ),
      const DemoSectionTitle('Para quem'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          ChoiceChip(
            key: const ValueKey<String>('publico-selecionados'),
            label: Text(CareAudience.selecionados.label),
            selected: d.audience == CareAudience.selecionados,
            onSelected: (_) =>
                setState(() => d.audience = CareAudience.selecionados),
          ),
          ChoiceChip(
            key: const ValueKey<String>('publico-equipe'),
            label: Text('${CareAudience.equipe.label} (${team.length})'),
            selected: d.audience == CareAudience.equipe,
            onSelected: (_) => setState(() => d.audience = CareAudience.equipe),
          ),
        ],
      ),
      if (team.isEmpty)
        const Text('Não há outros profissionais na equipe ativa.'),
      if (d.audience == CareAudience.selecionados)
        for (final CareLink l in team)
          CheckboxListTile(
            key: ValueKey<String>('dest-${l.professionalId}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: d.recipientIds.contains(l.professionalId),
            onChanged: (bool? v) => setState(
              () => v == true
                  ? d.recipientIds.add(l.professionalId)
                  : d.recipientIds.remove(l.professionalId),
            ),
            title: Text(l.professionalName),
            subtitle: Text(l.specialty.profession),
          ),
      if (d.audience == CareAudience.equipe)
        for (final CareLink l in team)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.check_rounded, color: AppColors.success),
            title: Text('${l.professionalName} (${l.specialty.area})'),
          ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'A família não recebe resumos da equipe. Para a família, libere '
        'orientações e documentos na área própria.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton(
            key: const ValueKey<String>('voltar-1'),
            onPressed: () => setState(() => _step = 0),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const ValueKey<String>('proximo-2'),
            onPressed: _next,
            child: const Text('Ver prévia'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _previewStep(CareRecord r, CareSummaryPreview p) {
    final TextTheme t = Theme.of(context).textTheme;
    return <Widget>[
      const DemoNotice(
        icon: Icons.visibility_outlined,
        text: 'Prévia: é exatamente isto que os destinatários vão ver.',
      ),
      const SizedBox(height: AppSpacing.sm),
      PremiumCard(
        key: const ValueKey<String>('previa'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('Resumo: ${p.recordTitle}', style: t.titleSmall),
                DemoTag('Versão ${p.version}', color: AppColors.inkMuted),
                if (p.aiAssisted)
                  const DemoTag(
                    'Preparado com IA, revisado por você',
                    color: AppColors.warning,
                  ),
              ],
            ),
            for (final CareShareItem i in p.items) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                i.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(i.text),
            ],
            if (p.note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('Observação: ${p.note}'),
            ],
            const SizedBox(height: 4),
            if (p.attachments.isEmpty) const Text('Sem anexos.'),
            for (final CareAttachment a in p.attachments)
              Text('Anexo: ${a.fileName}'),
            const Divider(),
            Text(
              'Para: ${p.audience.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final CareLink l in p.recipients)
              Text('- ${l.professionalName} (${l.specialty.area})'),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Não vai junto: o registro completo, '
        '${r.lockedSections.isEmpty ? '' : 'as partes privadas, '}'
        'as informações e os anexos não marcados.',
        style: t.bodySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton(
            key: const ValueKey<String>('voltar-2'),
            onPressed: () => setState(() => _step = 1),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const ValueKey<String>('compartilhar'),
            onPressed: _confirm,
            child: const Text('Compartilhar'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _doneStep(CareSummary s) => <Widget>[
    PremiumCard(
      borderColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resumo compartilhado',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Versão ${s.version} para ${s.recipientNames.values.join(', ')}. '
            'Você pode atualizar ou encerrar o acesso na visão da equipe.',
          ),
        ],
      ),
    ),
    const SizedBox(height: AppSpacing.md),
    FilledButton(
      key: const ValueKey<String>('voltar-ficha'),
      onPressed: () =>
          context.go(carePath(widget.childId, tab: CareTab.equipe)),
      child: const Text('Voltar à ficha'),
    ),
  ];
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.replies,
    required this.onReply,
  });

  final CareMessage message;
  final List<CareMessage> replies;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final CareMessage m = message;
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DemoTag(m.kind.label, color: AppColors.brand),
                DemoTag(
                  m.status.label,
                  color: m.status == CareMessageStatus.aberto
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(m.subject, style: t.titleSmall),
            Text(m.body),
            Text(
              'De: ${m.authorName} (${m.authorSpecialty.area}) - ${_dt(m.at)}'
              '${m.toSpecialty == null ? '' : ' - Para: ${m.toSpecialty!.area}'}',
              style: t.bodySmall,
            ),
            for (final CareMessage r in replies)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(r.body),
                    Text(
                      '${r.authorName} (${r.authorSpecialty.area}) - ${_dt(r.at)}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            Semantics(
              container: true,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Histórico (${m.events.length})'),
                children: <Widget>[
                  for (final CareMessageEvent e in m.events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${e.actorName}: ${e.status.label}'),
                      subtitle: Text(_dt(e.at)),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey<String>('responder-${m.id}'),
                onPressed: onReply,
                child: const Text('Responder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.mine});

  final CareDocument doc;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final CareDocument d = doc;
    final CareStore store = demoSession.care.store;
    final CareActor actor = demoSession.care.actor;
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(d.kind.label, style: t.titleSmall),
                DemoTag(
                  d.status.label,
                  color: d.status == CareDocStatus.issued
                      ? AppColors.success
                      : AppColors.warning,
                ),
                if (d.releasedAt != null)
                  const DemoTag('Liberado à família', color: AppColors.success),
              ],
            ),
            const SizedBox(height: 4),
            Text(d.body),
            Text(
              '${d.authorName} (${d.specialty.area}) - ${d.authorRegistry} - '
              '${demoDate(d.issuedAt ?? d.createdAt)}',
              style: t.bodySmall,
            ),
            if (mine)
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  if (d.status == CareDocStatus.draft)
                    TextButton(
                      key: ValueKey<String>('revisar-${d.id}'),
                      onPressed: () => _run(
                        context,
                        () => store.reviewDocument(actor, d),
                        ok: 'Documento revisado.',
                      ),
                      child: const Text('Marcar como revisado'),
                    ),
                  if (d.status == CareDocStatus.reviewed)
                    TextButton(
                      key: ValueKey<String>('emitir-${d.id}'),
                      onPressed: () => _run(
                        context,
                        () => store.issueDocument(actor, d),
                        ok: 'Documento emitido.',
                      ),
                      child: const Text('Emitir documento'),
                    ),
                  if (d.status == CareDocStatus.issued && d.releasedAt == null)
                    TextButton(
                      key: ValueKey<String>('liberar-doc-${d.id}'),
                      onPressed: () => _run(
                        context,
                        () => store.releaseDocument(actor, d),
                        ok: 'Documento liberado para a família.',
                      ),
                      child: const Text('Liberar para a família'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Perfil profissional: identificação, registro, agenda, pacientes
/// vinculados, encaminhamentos recebidos, modelos, documentos e histórico.
class DemoProfessionalProfileScreen extends StatelessWidget {
  const DemoProfessionalProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoAccount account = demoSession.account;
        final DemoCare care = demoSession.care;
        final CareActor actor = care.actor;
        final CareSpecialty s =
            CareSpecialty.fromText(account.specialty) ??
            CareSpecialty.pediatria;
        final DateTime now = demoSession.now;
        final List<DemoAppointment> mine =
            demoSession.appointments
                .where((DemoAppointment a) => a.professionalId == account.id)
                .toList()
              ..sort(
                (DemoAppointment a, DemoAppointment b) =>
                    a.start.compareTo(b.start),
              );
        final List<DemoAppointment> upcoming = mine
            .where(
              (DemoAppointment a) => a.start.isAfter(now) && a.status.holdsSlot,
            )
            .toList();
        final List<DemoAppointment> past = mine
            .where((DemoAppointment a) => !a.start.isAfter(now))
            .toList()
            .reversed
            .toList();
        final Set<String> children = care.store.childrenOf(account.id);
        final List<CareMessage> referrals = care.store.referralsFor(actor);
        final List<CareDocument> docs = care.store.documents
            .where((CareDocument d) => d.authorId == account.id)
            .toList();
        final int shared = care.store.summaries
            .where((CareSummary x) => x.authorId == account.id && x.published)
            .length;
        final int authored = care.store.records
            .where((CareRecord r) => r.authorId == account.id)
            .length;
        String childName(String id) =>
            demoSession.patients
                .where((DemoPatient p) => p.id == id)
                .firstOrNull
                ?.name ??
            id;
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(title: const Text('Perfil profissional')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            account.name,
                            style: t.titleLarge?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('${s.profession} - ${s.area}'),
                          Text('Registro profissional: ${account.registry}'),
                          Text(account.clinic, style: t.bodySmall),
                          Text(account.email, style: t.bodySmall),
                        ],
                      ),
                    ),
                    const DemoSectionTitle('O que este perfil pode fazer'),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final CareAction a in CareAction.values)
                            Row(
                              children: <Widget>[
                                Icon(
                                  CarePolicy.allows(s, a)
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  size: 18,
                                  color: CarePolicy.allows(s, a)
                                      ? AppColors.success
                                      : AppColors.inkMuted,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(a.label)),
                              ],
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Documentos: ${CarePolicy.docsFor(s).map((CareDocKind k) => k.label).join(', ')}.',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (referrals.isNotEmpty) ...<Widget>[
                      const DemoSectionTitle('Encaminhamentos recebidos'),
                      for (final CareMessage m in referrals)
                        PremiumCard(
                          borderColor: AppColors.warning,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${m.subject} - ${childName(m.childId)}',
                                style: t.titleSmall,
                              ),
                              Text(m.body),
                              Text(
                                'De: ${m.authorName} (${m.authorSpecialty.area}) - ${_dt(m.at)}',
                                style: t.bodySmall,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  key: ValueKey<String>('aceitar-${m.id}'),
                                  onPressed: () => _run(
                                    context,
                                    () => care.store.acceptReferral(
                                      actor,
                                      m,
                                      clinicName: account.clinic,
                                      registry: account.registry,
                                    ),
                                    ok:
                                        'Encaminhamento aceito. O acesso '
                                        'começa quando a família autorizar.',
                                  ),
                                  child: const Text('Aceitar encaminhamento'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    DemoSectionTitle(
                      'Agenda',
                      trailing: TextButton(
                        onPressed: () => context.go('/agenda'),
                        child: const Text('Abrir agenda'),
                      ),
                    ),
                    if (upcoming.isEmpty) const Text('Nenhum horário futuro.'),
                    for (final DemoAppointment a in upcoming.take(6))
                      Text(
                        '${_dt(a.start)} - ${childName(a.patientId)} - ${a.reason}',
                      ),
                    const DemoSectionTitle('Pacientes vinculados'),
                    if (children.isEmpty)
                      const Text('Nenhuma criança com vínculo ativo.'),
                    for (final String id in children)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.child_care_rounded),
                        title: Text(childName(id)),
                        subtitle: Text(careTileSubtitle(id)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(carePath(id)),
                      ),
                    const DemoSectionTitle('Modelos próprios'),
                    for (final CareTemplate tp in care.store.templatesOf(actor))
                      Text('${tp.title} (${tp.kind.label})'),
                    if (s == CareSpecialty.pediatria)
                      TextButton(
                        onPressed: () => context.go('/modelos'),
                        child: const Text('Modelos de documentos da pediatria'),
                      )
                    else if (care.store.templatesOf(actor).isEmpty)
                      const Text('Nenhum modelo próprio.'),
                    const DemoSectionTitle('Documentos'),
                    if (docs.isEmpty)
                      const Text(
                        'Nenhum documento do cuidado multidisciplinar.',
                      ),
                    for (final CareDocument d in docs)
                      Text(
                        '${d.kind.label} - ${childName(d.childId)} - ${d.status.label}',
                      ),
                    const DemoSectionTitle('Histórico de atendimentos'),
                    Text(
                      '$authored registro(s) feitos no cuidado '
                      'multidisciplinar; $shared resumo(s) compartilhado(s).',
                    ),
                    if (past.isEmpty)
                      const Text('Nenhum atendimento anterior.'),
                    for (final DemoAppointment a in past.take(8))
                      Text(
                        '${_dt(a.start)} - ${childName(a.patientId)} - '
                        '${DemoWorkspace.statusLabel(a.status)}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
