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
  final String areas = active.map((CareLink l) => l.specialty.area).toSet().join(', ');
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
  CareVisibility.reservado => AppColors.danger,
  CareVisibility.equipe => AppColors.brand,
  CareVisibility.familia => AppColors.success,
};

IconData _visibilityIcon(CareVisibility v) => switch (v) {
  CareVisibility.reservado => Icons.lock_outline_rounded,
  CareVisibility.equipe => Icons.groups_2_outlined,
  CareVisibility.familia => Icons.family_restroom_outlined,
};

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
            CareTab.fromSlug(tab) != null && tabs.contains(CareTab.fromSlug(tab))
            ? CareTab.fromSlug(tab)!
            : tabs.first;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: Text(
              actor.isFamily ? 'Equipe e atividades' : 'Cuidado multidisciplinar',
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
    final CareSharedView view = store.sharedView(actor, child.id);
    final CareLink link = store.linkOf(actor, child.id)!;
    final bool canPlan = CarePolicy.allows(
      link.specialty,
      CareAction.planoCompartilhado,
    );
    final CarePlan? plan = view.plan;
    return <Widget>[
      const DemoSectionTitle('Profissionais envolvidos'),
      for (final CareLink l in view.team) _LinkCard(link: l),
      DemoSectionTitle(
        'Plano combinado',
        trailing: canPlan
            ? TextButton.icon(
                key: const ValueKey<String>('editar-plano'),
                onPressed: () => _editPlan(context, child.id, plan),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar plano'),
              )
            : null,
      ),
      PremiumCard(
        child: plan == null
            ? const Text('Ainda sem plano combinado.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(plan.text),
                  if (plan.goals.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Objetivos do cuidado',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final CarePlanGoal g in plan.goals)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '- ${g.text} (${g.specialty.area} - ${g.ownerName})',
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Atualizado por ${plan.updatedBy} '
                    '(${plan.updatedBySpecialty.area}) em '
                    '${_dt(plan.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (plan.history.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Histórico do plano (${plan.history.length})',
                      ),
                      children: <Widget>[
                        for (final CarePlanVersion v in plan.history.reversed)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(v.text),
                            subtitle: Text(
                              '${v.actorName} (${v.specialty.area}) - '
                              '${_dt(v.at)}',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
      ),
      const DemoSectionTitle('Próximos atendimentos'),
      ..._sessions(context, demoSession.care.nextSessions(child.id)),
      DemoSectionTitle(
        'Evolução relevante',
        trailing: CarePolicy.allows(link.specialty, CareAction.rascunhoIa)
            ? TextButton.icon(
                key: const ValueKey<String>('ia-resumo'),
                onPressed: () => _aiSummary(context, child.id),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Resumo com IA'),
              )
            : null,
      ),
      const DemoNotice(
        icon: Icons.lock_outline_rounded,
        text:
            'Registros reservados não aparecem para a equipe: só o resumo '
            'que o próprio autor decidiu compartilhar.',
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final CareSharedItem item in view.items)
        _SharedItemCard(item: item, store: store),
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

  Future<void> _editPlan(
    BuildContext context,
    String childId,
    CarePlan? plan,
  ) async {
    final TextEditingController text = TextEditingController(
      text: plan?.text ?? '',
    );
    final TextEditingController goal = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Plano combinado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('plano-texto'),
                controller: text,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Plano da equipe'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('plano-objetivo'),
                controller: goal,
                decoration: const InputDecoration(
                  labelText: 'Novo objetivo da sua área (opcional)',
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
            key: const ValueKey<String>('salvar-plano'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Salvar plano'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _run(
      context,
      () => demoSession.care.store.updatePlan(
        demoSession.care.actor,
        childId,
        text: text.text.trim(),
        newGoal: goal.text,
      ),
      ok: 'Plano atualizado. A versão anterior fica no histórico.',
    );
  }

  Future<void> _aiSummary(BuildContext context, String childId) async {
    final CareActor actor = demoSession.care.actor;
    final CareAiDraft draft;
    try {
      draft = CareAi.teamSummary(demoSession.care.store, actor, childId);
    } on CareAccessDenied catch (e) {
      showDemoSnack(context, e.message);
      return;
    }
    final TextEditingController text = TextEditingController(text: draft.text);
    bool reviewed = false;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: const Text('Resumo com IA'),
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
                      'O rascunho usa só a visão compartilhada. Registros '
                      'reservados não entram, e nada é salvo ou enviado '
                      'sem a sua revisão.',
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey<String>('ia-texto'),
                  controller: text,
                  minLines: 6,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Rascunho (edite antes de salvar)',
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey<String>('ia-revisado'),
                  contentPadding: EdgeInsets.zero,
                  value: reviewed,
                  onChanged: (bool? v) => set(() => reviewed = v ?? false),
                  title: const Text('Revisei e confirmo o texto'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Descartar rascunho'),
            ),
            FilledButton(
              key: const ValueKey<String>('ia-salvar'),
              onPressed: reviewed ? () => Navigator.of(d).pop(true) : null,
              child: const Text('Salvar resumo revisado'),
            ),
          ],
        ),
      ),
    );
    if (save != true || !context.mounted) return;
    _run(
      context,
      () => CareAi.saveReviewed(
        demoSession.care.store,
        actor,
        draft,
        reviewedText: text.text,
        reviewed: reviewed,
      ),
      ok: 'Resumo revisado salvo para a equipe.',
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
          onEnd: l.endedAt == null
              ? () => _endLink(context, l)
              : null,
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
      showDemoSnack(context, 'Todos os profissionais da clínica já estão na equipe.');
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
      () => demoSession.care.store.endLink(demoSession.care.actor, link, reason),
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
    final List<CareRecord> records = store.recordsFor(
      actor,
      child.id,
      specialty: s,
    );
    final List<CareRecord> measures = records
        .where((CareRecord r) => r.kind == CareRecordKind.medida)
        .toList()
      ..sort((CareRecord a, CareRecord b) => a.createdAt.compareTo(b.createdAt));
    final List<DemoAppointment> agenda = demoSession.care
        .nextSessions(child.id)
        .where((DemoAppointment a) => DemoCare.specialtyOf(a.professionalId) == s)
        .toList();
    return <Widget>[
      if (link == null)
        const DemoNotice(
          icon: Icons.history_rounded,
          color: AppColors.warning,
          text:
              'Seu vínculo com a criança foi encerrado. Você vê apenas os '
              'registros que fez, somente para leitura.',
        ),
      if (s == CareSpecialty.psicologia && !own)
        const DemoNotice(
          icon: Icons.lock_outline_rounded,
          text:
              'Registros reservados da psicologia ficam só com o profissional '
              'responsável. A equipe vê o plano terapêutico e os resumos '
              'compartilhados.',
        ),
      if (own && CarePolicy.canReserve(s))
        const DemoNotice(
          icon: Icons.lock_outline_rounded,
          text:
              'Registros marcados como reservados ficam só com você. Para a '
              'continuidade do cuidado, compartilhe um resumo com a equipe.',
        ),
      DemoSectionTitle('Agenda da ${s.area.toLowerCase()}'),
      ..._sessions(context, agenda),
      if (measures.isNotEmpty) ...<Widget>[
        const DemoSectionTitle('Medidas de acompanhamento'),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final CareRecord m in measures)
                Text('${demoDate(m.createdAt)} - ${m.title}: ${m.measure ?? '-'}'),
            ],
          ),
        ),
      ],
      DemoSectionTitle(
        'Registros da ${s.area.toLowerCase()}',
        trailing: own
            ? FilledButton.icon(
                key: const ValueKey<String>('novo-registro'),
                onPressed: () => _newRecord(context, child.id, s),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo registro'),
              )
            : null,
      ),
      if (records.isEmpty) const Text('Nenhum registro visível para você.'),
      for (final CareRecord r in records)
        _RecordCard(record: r, editable: own && r.authorId == actor.id),
    ];
  }

  Future<void> _newRecord(
    BuildContext context,
    String childId,
    CareSpecialty s,
  ) async {
    final List<CareRecordKind> kinds = CarePolicy.kindsFor(s)
        .where((CareRecordKind k) => k != CareRecordKind.resumoEquipe)
        .toList();
    CareRecordKind kind = kinds.first;
    CareVisibility visibility = CareVisibility.equipe;
    final TextEditingController title = TextEditingController();
    final TextEditingController body = TextEditingController();
    final TextEditingController summary = TextEditingController();
    final TextEditingController measure = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) {
          final List<CareVisibility> allowed = <CareVisibility>[
            if (CarePolicy.canReserve(s)) CareVisibility.reservado,
            CareVisibility.equipe,
            if (kind.canGoToFamily) CareVisibility.familia,
          ];
          if (!allowed.contains(visibility)) visibility = CareVisibility.equipe;
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
                    decoration: const InputDecoration(labelText: 'Registro *'),
                  ),
                  if (kind == CareRecordKind.medida)
                    TextField(
                      key: const ValueKey<String>('registro-medida'),
                      controller: measure,
                      decoration: const InputDecoration(
                        labelText: 'Medida (valor e unidade)',
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
                  if (visibility == CareVisibility.reservado)
                    TextField(
                      key: const ValueKey<String>('registro-resumo'),
                      controller: summary,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText:
                            'Resumo para a equipe (só o necessário, opcional)',
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
        teamSummary: summary.text,
        measure: measure.text.trim().isEmpty ? null : measure.text.trim(),
      ),
      ok: 'Registro salvo (${visibility.label.toLowerCase()}).',
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
          replies: all
              .where((CareMessage r) => r.replyTo == m.id)
              .toList()
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
                          label: Text(s.active ? s.area : '${s.area} (em breve)'),
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
        'Documentos da equipe',
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
            '${blocked.map((CareDocKind k) => k.label).join(', ')}.',
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
                        ok: '${l.professionalName} passa a fazer parte da '
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
            'Anotações reservadas e registros da equipe não aparecem.',
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

class _SharedItemCard extends StatelessWidget {
  const _SharedItemCard({required this.item, required this.store});

  final CareSharedItem item;
  final CareStore store;

  @override
  Widget build(BuildContext context) {
    final CareRecord? r = store.records
        .where((CareRecord r) => r.id == item.recordId)
        .firstOrNull;
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
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                if (item.fromReserved)
                  const DemoTag('Resumo compartilhado', color: AppColors.brand),
                if (r?.fromAi ?? false)
                  DemoTag(
                    'Preparado com IA, revisado por ${r!.reviewedBy}',
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.text),
            const SizedBox(height: 4),
            Text(
              'Origem: ${item.specialty.area} - ${item.authorName} - '
              '${demoDate(item.at)} (${item.kind.label})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
    final List<CareAttachment> files = store.attachments
        .where((CareAttachment a) => a.recordId == r.id)
        .toList();
    final TextTheme t = Theme.of(context).textTheme;
    final Color vc = _visibilityColor(r.visibility);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: r.visibility == CareVisibility.reservado
            ? AppColors.danger.withValues(alpha: 0.4)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(r.kind.label, style: t.labelMedium),
                DemoTag(r.visibility.label, color: vc),
                if (r.sourceId != null)
                  const DemoTag('Resumo compartilhado', color: AppColors.brand),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.title, style: t.titleSmall),
            Text(r.body),
            if (r.measure != null) Text('Medida: ${r.measure}'),
            const SizedBox(height: 4),
            Text(
              'Origem: ${r.origin} - ${demoDate(r.createdAt)}'
              '${r.updatedAt == null ? '' : ' (alterado em ${demoDate(r.updatedAt!)})'}',
              style: t.bodySmall,
            ),
            if (files.isNotEmpty)
              for (final CareAttachment f in files)
                Text(
                  'Anexo: ${f.fileName}',
                  style: t.bodySmall?.copyWith(color: AppColors.brand),
                ),
            if (r.revisions.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Histórico de alterações (${r.revisions.length})'),
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
            if (editable)
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  TextButton(
                    key: ValueKey<String>('alterar-${r.id}'),
                    onPressed: () => _edit(context, r),
                    child: const Text('Alterar'),
                  ),
                  if (r.kind.canGoToFamily &&
                      r.visibility == CareVisibility.equipe)
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
                  if (r.visibility == CareVisibility.reservado)
                    TextButton(
                      key: ValueKey<String>('resumo-${r.id}'),
                      onPressed: () async {
                        final String? text = await _askReason(
                          context,
                          title: 'Resumo para a equipe',
                          label: 'Só o necessário para a continuidade *',
                          confirm: 'Compartilhar resumo',
                        );
                        if (text == null || !context.mounted) return;
                        _run(
                          context,
                          () => store.shareSummary(actor, r, text),
                          ok: 'Resumo compartilhado com a equipe.',
                        );
                      },
                      child: const Text('Resumo para a equipe'),
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
            ExpansionTile(
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
            CareSpecialty.fromText(account.specialty) ?? CareSpecialty.pediatria;
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
              (DemoAppointment a) =>
                  a.start.isAfter(now) && a.status.holdsSlot,
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
                      Text('${_dt(a.start)} - ${childName(a.patientId)} - ${a.reason}'),
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
                      const Text('Nenhum documento do cuidado multidisciplinar.'),
                    for (final CareDocument d in docs)
                      Text(
                        '${d.kind.label} - ${childName(d.childId)} - ${d.status.label}',
                      ),
                    const DemoSectionTitle('Histórico de atendimentos'),
                    Text('$authored registro(s) feitos no cuidado multidisciplinar.'),
                    if (past.isEmpty) const Text('Nenhum atendimento anterior.'),
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
