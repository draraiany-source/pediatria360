import 'care_model.dart';
import 'care_policy.dart';

/// Item da visão compartilhada, sempre com a origem.
class CareSharedItem {
  const CareSharedItem({
    required this.recordId,
    required this.specialty,
    required this.authorName,
    required this.kind,
    required this.title,
    required this.text,
    required this.at,
    this.fromReserved = false,
  });

  final String recordId;
  final CareSpecialty specialty;
  final String authorName;
  final CareRecordKind kind;
  final String title;
  final String text;
  final DateTime at;

  /// Resumo que o autor escreveu a partir de um registro reservado.
  final bool fromReserved;
}

class CareSharedView {
  const CareSharedView({
    required this.team,
    required this.plan,
    required this.items,
  });

  final List<CareLink> team;
  final CarePlan? plan;
  final List<CareSharedItem> items;
}

class CareFamilyView {
  const CareFamilyView({
    required this.released,
    required this.documents,
    required this.pendingLinks,
    required this.team,
  });

  /// Orientações e atividades liberadas, por profissional.
  final List<CareRecord> released;
  final List<CareDocument> documents;
  final List<CareLink> pendingLinks;
  final List<CareLink> team;
}

/// Estado do cuidado multidisciplinar com as regras aplicadas em cada
/// operação e o registro de acessos e alterações.
class CareStore {
  CareStore({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  DateTime Function() clock;
  final List<CareLink> links = <CareLink>[];
  final List<CareRecord> records = <CareRecord>[];
  final List<CareAttachment> attachments = <CareAttachment>[];
  final Map<String, CarePlan> plans = <String, CarePlan>{};
  final List<CareMessage> messages = <CareMessage>[];
  final List<CareDocument> documents = <CareDocument>[];
  final List<CareTemplate> templates = <CareTemplate>[];
  final List<CareAuditEntry> audit = <CareAuditEntry>[];
  int _seq = 1;

  String newId(String prefix) => '$prefix${_seq++}';

  static String planKey(String childId, String clinicId) =>
      '$childId|$clinicId';

  // ---------------------------------------------------------------- Trilha

  void _log(
    CareActor actor,
    String action,
    String target,
    String childId, {
    bool allowed = true,
    String? clinicId,
  }) {
    final DateTime now = clock();
    // Reabrir a mesma tela em sequência não gera uma linha nova por quadro.
    if (allowed &&
        (action.startsWith('visualizou') || action.startsWith('abriu')) &&
        audit.isNotEmpty) {
      final CareAuditEntry last = audit.last;
      if (last.actorId == actor.id &&
          last.action == action &&
          last.target == target &&
          last.childId == childId &&
          now.difference(last.at).inSeconds.abs() < 60) {
        return;
      }
    }
    audit.add(
      CareAuditEntry(
        at: now,
        actorId: actor.id,
        actorName: actor.name,
        action: action,
        target: target,
        childId: childId,
        allowed: allowed,
        clinicId: clinicId ?? actor.clinicId,
      ),
    );
  }

  Never _deny(
    CareActor actor,
    String action,
    String target,
    String childId,
    String message,
  ) {
    _log(actor, action, target, childId, allowed: false);
    throw CareAccessDenied(message);
  }

  // ---------------------------------------------------------------- Equipe

  CareLink? linkOf(CareActor actor, String childId) =>
      CarePolicy.activeLink(links, actor, childId);

  CareLink _requireLink(CareActor actor, String childId, String action) {
    final CareLink? link = linkOf(actor, childId);
    if (link == null) {
      _deny(
        actor,
        action,
        'criança $childId',
        childId,
        'Sem vínculo ativo com a criança.',
      );
    }
    return link;
  }

  bool _isGuardian(CareActor actor, String childId) =>
      actor.isFamily && actor.guardianOf.contains(childId);

  bool _manages(CareActor actor, String clinicId) =>
      actor.role == CareActorRole.gestaoClinica && actor.clinicId == clinicId;

  /// Abre a ficha multidisciplinar: vínculo ativo, autoria anterior (só os
  /// próprios registros) ou responsável pela criança.
  bool canOpenChild(CareActor actor, String childId) =>
      linkOf(actor, childId) != null ||
      _isGuardian(actor, childId) ||
      (actor.isProfessional &&
          records.any(
            (CareRecord r) => r.childId == childId && r.authorId == actor.id,
          ));

  /// Composição da equipe. Profissional vê a equipe da própria clínica;
  /// a família vê todos os vínculos; a gestão, os da clínica dela.
  List<CareLink> team(CareActor actor, String childId) {
    final Iterable<CareLink> mine = links.where(
      (CareLink l) => l.childId == childId,
    );
    final CareLink? link = linkOf(actor, childId);
    if (link != null) {
      return mine
          .where((CareLink l) => l.clinicId == link.clinicId && l.endedAt == null)
          .toList();
    }
    if (_isGuardian(actor, childId)) return mine.toList();
    if (actor.role == CareActorRole.gestaoClinica) {
      return mine.where((CareLink l) => l.clinicId == actor.clinicId).toList();
    }
    _deny(
      actor,
      'consultar equipe',
      'criança $childId',
      childId,
      'Sem vínculo com a criança.',
    );
  }

  /// Crianças com vínculo ativo do profissional.
  Set<String> childrenOf(String professionalId) => <String>{
    for (final CareLink l in links)
      if (l.professionalId == professionalId && l.active) l.childId,
  };

  /// Vínculo pendente criado pela gestão da clínica (designação) ou pelo
  /// próprio profissional ao aceitar um encaminhamento.
  CareLink requestLink(
    CareActor actor, {
    required String childId,
    required String professionalId,
    required String professionalName,
    required CareSpecialty specialty,
    required String clinicId,
    required String clinicName,
    required String reason,
    String registry = '',
  }) {
    final bool self =
        actor.isProfessional &&
        actor.id == professionalId &&
        actor.clinicId == clinicId;
    if (!_manages(actor, clinicId) && !self) {
      _deny(
        actor,
        'solicitar vínculo',
        professionalName,
        childId,
        'Só a gestão da clínica designa profissionais.',
      );
    }
    final bool already = links.any(
      (CareLink l) =>
          l.childId == childId &&
          l.professionalId == professionalId &&
          l.endedAt == null,
    );
    if (already) {
      throw const CareAccessDenied('Este profissional já está na equipe.');
    }
    final CareLink link = CareLink(
      id: newId('v'),
      childId: childId,
      professionalId: professionalId,
      professionalName: professionalName,
      specialty: specialty,
      clinicId: clinicId,
      clinicName: clinicName,
      since: clock(),
      reason: reason,
      requestedBy: actor.name,
      registry: registry,
    );
    links.add(link);
    _log(
      actor,
      'solicitou vínculo (aguarda a família)',
      '$professionalName - ${specialty.area}',
      childId,
      clinicId: clinicId,
    );
    return link;
  }

  /// O profissional da especialidade encaminhada aceita e passa a aguardar
  /// a autorização da família.
  CareLink acceptReferral(
    CareActor actor,
    CareMessage referral, {
    required String clinicName,
    String registry = '',
  }) {
    final bool addressed =
        referral.toProfessionalId == actor.id ||
        (referral.toProfessionalId == null &&
            referral.toSpecialty == actor.specialty);
    if (referral.kind != CareMessageKind.encaminhamento ||
        referral.status != CareMessageStatus.aberto ||
        !actor.isProfessional ||
        !addressed ||
        actor.clinicId != referral.clinicId) {
      _deny(
        actor,
        'aceitar encaminhamento',
        referral.subject,
        referral.childId,
        'Este encaminhamento não é para você.',
      );
    }
    final CareLink link = requestLink(
      actor,
      childId: referral.childId,
      professionalId: actor.id,
      professionalName: actor.name,
      specialty: actor.specialty!,
      clinicId: referral.clinicId,
      clinicName: clinicName,
      reason: '${referral.subject} (encaminhado por ${referral.authorName})',
      registry: registry,
    );
    referral.status = CareMessageStatus.aceito;
    referral.events.add(
      CareMessageEvent(
        at: clock(),
        actorName: actor.name,
        status: CareMessageStatus.aceito,
      ),
    );
    return link;
  }

  void authorize(CareActor actor, CareLink link) {
    if (!_isGuardian(actor, link.childId) || !link.pending) {
      _deny(
        actor,
        'autorizar vínculo',
        link.professionalName,
        link.childId,
        'Só o responsável autoriza o acesso de um profissional.',
      );
    }
    link.authorizedAt = clock();
    link.authorizedBy = actor.name;
    _log(
      actor,
      'autorizou vínculo',
      '${link.professionalName} - ${link.specialty.area}',
      link.childId,
      clinicId: link.clinicId,
    );
  }

  /// Encerram: o próprio profissional, a família ou a gestão da clínica.
  void endLink(CareActor actor, CareLink link, String reason) {
    final bool ok =
        actor.id == link.professionalId ||
        _isGuardian(actor, link.childId) ||
        _manages(actor, link.clinicId);
    if (!ok || link.endedAt != null) {
      _deny(
        actor,
        'encerrar vínculo',
        link.professionalName,
        link.childId,
        'Sem permissão para encerrar este vínculo.',
      );
    }
    link.endedAt = clock();
    link.endedBy = actor.name;
    link.endReason = reason;
    _log(
      actor,
      'encerrou vínculo ($reason)',
      '${link.professionalName} - ${link.specialty.area}',
      link.childId,
      clinicId: link.clinicId,
    );
  }

  /// A família leva o acompanhamento para outra clínica: todos os vínculos
  /// atuais são encerrados. A nova equipe precisa de vínculos novos e não vê
  /// os registros da equipe anterior; a família mantém o que foi liberado.
  List<CareLink> transferClinic(
    CareActor actor,
    String childId, {
    required String toClinicName,
  }) {
    if (!_isGuardian(actor, childId)) {
      _deny(
        actor,
        'trocar de clínica',
        'criança $childId',
        childId,
        'Só o responsável troca a clínica da criança.',
      );
    }
    final List<CareLink> ended = <CareLink>[
      for (final CareLink l in links)
        if (l.childId == childId && l.endedAt == null) l,
    ];
    for (final CareLink l in ended) {
      l.endedAt = clock();
      l.endedBy = actor.name;
      l.endReason = 'Troca de clínica pela família: $toClinicName';
    }
    _log(
      actor,
      'trocou de clínica (${ended.length} vínculo(s) encerrado(s))',
      toClinicName,
      childId,
    );
    return ended;
  }

  // ------------------------------------------------------------- Registros

  List<CareRecord> recordsFor(
    CareActor actor,
    String childId, {
    CareSpecialty? specialty,
  }) {
    if (!canOpenChild(actor, childId)) {
      _deny(
        actor,
        'abrir registros',
        specialty?.area ?? 'cuidado multidisciplinar',
        childId,
        'Sem vínculo com a criança.',
      );
    }
    final List<CareRecord> visible =
        records
            .where(
              (CareRecord r) =>
                  r.childId == childId &&
                  (specialty == null || r.specialty == specialty) &&
                  CarePolicy.canRead(actor, r, links),
            )
            .toList()
          ..sort((CareRecord a, CareRecord b) => b.createdAt.compareTo(a.createdAt));
    _log(
      actor,
      'visualizou registros (${visible.length})',
      specialty?.area ?? 'todas as áreas',
      childId,
    );
    return visible;
  }

  /// Leitura de um registro específico, com recusa registrada.
  CareRecord open(CareActor actor, String recordId) {
    final CareRecord r = records.firstWhere(
      (CareRecord r) => r.id == recordId,
      orElse: () => throw const CareAccessDenied('Registro inexistente.'),
    );
    if (!CarePolicy.canRead(actor, r, links)) {
      _deny(
        actor,
        'abrir registro',
        '${r.kind.label} (${r.specialty.area})',
        r.childId,
        r.visibility == CareVisibility.reservado
            ? 'Registro reservado ao profissional responsável.'
            : 'Sem acesso a este registro.',
      );
    }
    _log(actor, 'abriu registro', '${r.kind.label} - ${r.origin}', r.childId);
    return r;
  }

  CareRecord addRecord(
    CareActor actor, {
    required String childId,
    required CareRecordKind kind,
    required String title,
    required String body,
    CareVisibility visibility = CareVisibility.equipe,
    String? teamSummary,
    String? measure,
    int? sessionNumber,
    bool fromAi = false,
    String? reviewedBy,
  }) {
    if (fromAi && (reviewedBy ?? '').isEmpty) {
      throw const CareAccessDenied('Texto da IA só é salvo depois de revisado.');
    }
    final CareLink? link = linkOf(actor, childId);
    final String? why = CarePolicy.denyCreate(
      link: link,
      kind: kind,
      visibility: visibility,
    );
    if (why != null) _deny(actor, 'criar registro', kind.label, childId, why);
    final DateTime now = clock();
    final CareRecord r = CareRecord(
      id: newId('r'),
      childId: childId,
      clinicId: link!.clinicId,
      authorId: actor.id,
      authorName: actor.name,
      specialty: link.specialty,
      kind: kind,
      title: title,
      body: body,
      visibility: visibility,
      createdAt: now,
      measure: measure,
      sessionNumber: sessionNumber,
      fromAi: fromAi,
      reviewedBy: reviewedBy,
    );
    if (visibility == CareVisibility.familia) r.releasedAt = now;
    records.add(r);
    _log(
      actor,
      'criou registro (${visibility.label.toLowerCase()})',
      '${kind.label} - ${link.specialty.area}',
      childId,
      clinicId: link.clinicId,
    );
    final String summary = (teamSummary ?? '').trim();
    if (visibility == CareVisibility.reservado && summary.isNotEmpty) {
      _addSummary(actor, link, r, summary);
    }
    return r;
  }

  CareRecord _addSummary(
    CareActor actor,
    CareLink link,
    CareRecord source,
    String text,
  ) {
    final CareRecord s = CareRecord(
      id: newId('r'),
      childId: source.childId,
      clinicId: link.clinicId,
      authorId: actor.id,
      authorName: actor.name,
      specialty: link.specialty,
      kind: CareRecordKind.resumoEquipe,
      title: 'Resumo para a equipe: ${source.title}',
      body: text,
      visibility: CareVisibility.equipe,
      createdAt: clock(),
      sourceId: source.id,
    );
    records.add(s);
    _log(
      actor,
      'compartilhou resumo de registro reservado',
      source.title,
      source.childId,
      clinicId: link.clinicId,
    );
    return s;
  }

  /// Resumo compartilhado de um registro reservado (cria ou atualiza).
  CareRecord shareSummary(CareActor actor, CareRecord reserved, String text) {
    final CareLink link = _requireLink(
      actor,
      reserved.childId,
      'compartilhar resumo',
    );
    if (reserved.authorId != actor.id ||
        reserved.visibility != CareVisibility.reservado) {
      _deny(
        actor,
        'compartilhar resumo',
        reserved.title,
        reserved.childId,
        'Só o autor compartilha o resumo do registro reservado.',
      );
    }
    final CareRecord? existing = records
        .where((CareRecord r) => r.sourceId == reserved.id)
        .firstOrNull;
    if (existing == null) return _addSummary(actor, link, reserved, text);
    return edit(actor, existing, body: text, note: 'Resumo atualizado');
  }

  CareRecord edit(
    CareActor actor,
    CareRecord record, {
    String? title,
    String? body,
    String? measure,
    required String note,
  }) {
    final CareLink? link = linkOf(actor, record.childId);
    if (record.authorId != actor.id ||
        link == null ||
        link.clinicId != record.clinicId) {
      _deny(
        actor,
        'alterar registro',
        '${record.kind.label} - ${record.origin}',
        record.childId,
        'Só o autor, com vínculo ativo, altera o registro.',
      );
    }
    final DateTime now = clock();
    record.revisions.add(
      CareRevision(
        at: now,
        actorName: actor.name,
        note: note,
        previousBody: record.body,
      ),
    );
    if (title != null) record.title = title;
    if (body != null) record.body = body;
    if (measure != null) record.measure = measure;
    record.updatedAt = now;
    _log(
      actor,
      'alterou registro ($note)',
      record.kind.label,
      record.childId,
      clinicId: record.clinicId,
    );
    return record;
  }

  void release(CareActor actor, CareRecord record) {
    final CareLink? link = linkOf(actor, record.childId);
    if (record.authorId != actor.id ||
        link == null ||
        !record.kind.canGoToFamily ||
        record.visibility == CareVisibility.reservado ||
        !CarePolicy.allows(link.specialty, CareAction.liberarFamilia)) {
      _deny(
        actor,
        'liberar para a família',
        record.kind.label,
        record.childId,
        'Só o autor libera orientações e atividades para a família.',
      );
    }
    record.visibility = CareVisibility.familia;
    record.releasedAt = clock();
    _log(
      actor,
      'liberou para a família',
      '${record.kind.label}: ${record.title}',
      record.childId,
      clinicId: record.clinicId,
    );
  }

  void withdraw(CareActor actor, CareRecord record, String reason) {
    if (record.authorId != actor.id ||
        record.visibility != CareVisibility.familia) {
      _deny(
        actor,
        'retirar da família',
        record.title,
        record.childId,
        'Só o autor retira o conteúdo da família.',
      );
    }
    record.visibility = CareVisibility.equipe;
    record.releasedAt = null;
    _log(
      actor,
      'retirou da família ($reason)',
      record.title,
      record.childId,
      clinicId: record.clinicId,
    );
  }

  // ---------------------------------------------------------------- Anexos

  List<CareAttachment> attachmentsFor(CareActor actor, CareRecord record) {
    if (!CarePolicy.canRead(actor, record, links)) {
      _deny(
        actor,
        'abrir anexos',
        record.title,
        record.childId,
        'Anexo protegido pelas mesmas regras do registro.',
      );
    }
    return attachments
        .where((CareAttachment a) => a.recordId == record.id)
        .toList();
  }

  CareAttachment attach(CareActor actor, CareRecord record, String fileName) {
    final CareLink? link = linkOf(actor, record.childId);
    if (record.authorId != actor.id || link == null) {
      _deny(
        actor,
        'anexar arquivo',
        fileName,
        record.childId,
        'Só o autor, com vínculo ativo, anexa arquivos ao registro.',
      );
    }
    final CareAttachment a = CareAttachment(
      id: newId('f'),
      recordId: record.id,
      fileName: fileName,
      addedBy: actor.name,
      at: clock(),
    );
    attachments.add(a);
    _log(actor, 'anexou arquivo', fileName, record.childId);
    return a;
  }

  // ------------------------------------------------------- Visão da equipe

  CareSharedView sharedView(CareActor actor, String childId) {
    final CareLink link = _requireLink(actor, childId, 'abrir visão da equipe');
    const Set<CareRecordKind> relevant = <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.evolucao,
      CareRecordKind.medida,
      CareRecordKind.objetivos,
      CareRecordKind.planoTerapeutico,
      CareRecordKind.planoSessoes,
    };
    final List<CareSharedItem> items =
        <CareSharedItem>[
          for (final CareRecord r in records)
            if (r.childId == childId &&
                r.clinicId == link.clinicId &&
                r.visibility != CareVisibility.reservado &&
                relevant.contains(r.kind))
              CareSharedItem(
                recordId: r.id,
                specialty: r.specialty,
                authorName: r.authorName,
                kind: r.kind,
                title: r.title,
                text: r.measure == null ? r.body : '${r.body} (${r.measure})',
                at: r.updatedAt ?? r.createdAt,
                fromReserved: r.sourceId != null,
              ),
        ]..sort(
          (CareSharedItem a, CareSharedItem b) => b.at.compareTo(a.at),
        );
    _log(
      actor,
      'visualizou visão compartilhada',
      'equipe',
      childId,
      clinicId: link.clinicId,
    );
    return CareSharedView(
      team: team(actor, childId),
      plan: plans[planKey(childId, link.clinicId)],
      items: items,
    );
  }

  CarePlan updatePlan(
    CareActor actor,
    String childId, {
    required String text,
    String? newGoal,
  }) {
    final CareLink link = _requireLink(actor, childId, 'editar plano');
    if (!CarePolicy.allows(link.specialty, CareAction.planoCompartilhado)) {
      _deny(
        actor,
        'editar plano',
        'plano compartilhado',
        childId,
        'Especialidade sem permissão para editar o plano.',
      );
    }
    final DateTime now = clock();
    final String key = planKey(childId, link.clinicId);
    final CarePlan? current = plans[key];
    final CarePlan plan =
        current ??
        CarePlan(
          childId: childId,
          clinicId: link.clinicId,
          text: '',
          updatedAt: now,
          updatedBy: actor.name,
          updatedBySpecialty: link.specialty,
        );
    if (current != null) {
      plan.history.add(
        CarePlanVersion(
          at: plan.updatedAt,
          actorName: plan.updatedBy,
          specialty: plan.updatedBySpecialty,
          text: plan.text,
        ),
      );
    }
    plan
      ..text = text
      ..updatedAt = now
      ..updatedBy = actor.name
      ..updatedBySpecialty = link.specialty;
    final String goal = (newGoal ?? '').trim();
    if (goal.isNotEmpty) {
      plan.goals.add(
        CarePlanGoal(
          text: goal,
          specialty: link.specialty,
          ownerName: actor.name,
        ),
      );
    }
    plans[key] = plan;
    _log(
      actor,
      'alterou plano compartilhado',
      link.specialty.area,
      childId,
      clinicId: link.clinicId,
    );
    return plan;
  }

  // ------------------------------------------------------------ Comunicação

  List<CareMessage> messagesFor(CareActor actor, String childId) {
    final CareLink link = _requireLink(actor, childId, 'abrir comunicação');
    final List<CareMessage> list =
        messages
            .where(
              (CareMessage m) =>
                  m.childId == childId && m.clinicId == link.clinicId,
            )
            .toList()
          ..sort((CareMessage a, CareMessage b) => b.at.compareTo(a.at));
    _log(
      actor,
      'visualizou comunicação (${list.length})',
      'equipe',
      childId,
      clinicId: link.clinicId,
    );
    return list;
  }

  /// Encaminhamentos abertos para a especialidade do profissional, mesmo
  /// antes de ele ter vínculo com a criança.
  List<CareMessage> referralsFor(CareActor actor) => <CareMessage>[
    for (final CareMessage m in messages)
      if (m.kind == CareMessageKind.encaminhamento &&
          m.status == CareMessageStatus.aberto &&
          m.clinicId == actor.clinicId &&
          (m.toProfessionalId == actor.id ||
              (m.toProfessionalId == null &&
                  m.toSpecialty == actor.specialty)))
        m,
  ];

  CareMessage send(
    CareActor actor, {
    required String childId,
    required CareMessageKind kind,
    required String subject,
    required String body,
    CareSpecialty? toSpecialty,
    String? toProfessionalId,
    String? replyTo,
  }) {
    final CareLink link = _requireLink(actor, childId, 'enviar mensagem');
    final CareAction needed = switch (kind) {
      CareMessageKind.encaminhamento => CareAction.encaminhar,
      CareMessageKind.parecer => CareAction.solicitarParecer,
      CareMessageKind.mensagem => CareAction.mensagemEquipe,
    };
    if (!CarePolicy.allows(link.specialty, needed)) {
      _deny(actor, kind.label, subject, childId, 'Ação não permitida.');
    }
    if (kind == CareMessageKind.encaminhamento && toSpecialty == null) {
      throw const CareAccessDenied('Escolha a especialidade do encaminhamento.');
    }
    if (subject.trim().isEmpty || body.trim().isEmpty) {
      throw const CareAccessDenied('Preencha assunto e mensagem.');
    }
    final CareMessage m = CareMessage(
      id: newId('m'),
      childId: childId,
      clinicId: link.clinicId,
      kind: kind,
      authorId: actor.id,
      authorName: actor.name,
      authorSpecialty: link.specialty,
      subject: subject.trim(),
      body: body.trim(),
      at: clock(),
      toSpecialty: toSpecialty,
      toProfessionalId: toProfessionalId,
      replyTo: replyTo,
    );
    m.events.add(
      CareMessageEvent(
        at: m.at,
        actorName: actor.name,
        status: CareMessageStatus.aberto,
      ),
    );
    messages.add(m);
    if (replyTo != null) {
      final CareMessage? original = messages
          .where((CareMessage o) => o.id == replyTo)
          .firstOrNull;
      if (original != null && original.status == CareMessageStatus.aberto) {
        original.status = CareMessageStatus.respondido;
        original.events.add(
          CareMessageEvent(
            at: m.at,
            actorName: actor.name,
            status: CareMessageStatus.respondido,
          ),
        );
      }
    }
    _log(
      actor,
      replyTo == null ? 'enviou ${kind.label.toLowerCase()}' : 'respondeu',
      subject,
      childId,
      clinicId: link.clinicId,
    );
    return m;
  }

  // ------------------------------------------------------------- Documentos

  CareDocument createDocument(
    CareActor actor, {
    required String childId,
    required CareDocKind kind,
    required String title,
    required String body,
    required String registry,
    String? templateId,
  }) {
    final CareLink link = _requireLink(actor, childId, 'preparar documento');
    if (!CarePolicy.docsFor(link.specialty).contains(kind)) {
      _deny(
        actor,
        'preparar documento',
        kind.label,
        childId,
        '${kind.label} não é documento da ${link.specialty.area}.',
      );
    }
    final CareDocument d = CareDocument(
      id: newId('d'),
      childId: childId,
      clinicId: link.clinicId,
      kind: kind,
      authorId: actor.id,
      authorName: actor.name,
      authorRegistry: registry,
      specialty: link.specialty,
      title: title,
      body: body,
      createdAt: clock(),
      templateId: templateId,
    );
    documents.add(d);
    _log(
      actor,
      'preparou documento (rascunho)',
      kind.label,
      childId,
      clinicId: link.clinicId,
    );
    return d;
  }

  void _requireAuthor(CareActor actor, CareDocument d, String action) {
    if (d.authorId != actor.id || linkOf(actor, d.childId) == null) {
      _deny(
        actor,
        action,
        d.kind.label,
        d.childId,
        'Só o autor, com vínculo ativo, altera o documento.',
      );
    }
  }

  void reviewDocument(CareActor actor, CareDocument d, {String? body}) {
    _requireAuthor(actor, d, 'revisar documento');
    if (d.status == CareDocStatus.issued) {
      throw const CareAccessDenied('Documento emitido não muda.');
    }
    if (body != null) d.body = body;
    d.status = CareDocStatus.reviewed;
    _log(actor, 'revisou documento', d.kind.label, d.childId);
  }

  void issueDocument(CareActor actor, CareDocument d) {
    _requireAuthor(actor, d, 'emitir documento');
    if (d.status != CareDocStatus.reviewed) {
      throw const CareAccessDenied('Revise o documento antes de emitir.');
    }
    d.status = CareDocStatus.issued;
    d.issuedAt = clock();
    _log(actor, 'emitiu documento', d.kind.label, d.childId);
  }

  void releaseDocument(CareActor actor, CareDocument d) {
    _requireAuthor(actor, d, 'liberar documento');
    if (d.status != CareDocStatus.issued) {
      throw const CareAccessDenied('Só documento emitido vai para a família.');
    }
    d.releasedAt = clock();
    _log(actor, 'liberou documento para a família', d.kind.label, d.childId);
  }

  /// Autor vê os próprios; a equipe da mesma clínica vê os emitidos.
  List<CareDocument> documentsFor(CareActor actor, String childId) {
    final CareLink? link = linkOf(actor, childId);
    return documents
        .where(
          (CareDocument d) =>
              d.childId == childId &&
              (d.authorId == actor.id ||
                  (link != null &&
                      d.clinicId == link.clinicId &&
                      d.status == CareDocStatus.issued) ||
                  (_isGuardian(actor, childId) && d.releasedAt != null)),
        )
        .toList();
  }

  // ---------------------------------------------------------------- Modelos

  List<CareTemplate> templatesOf(CareActor actor) =>
      templates.where((CareTemplate t) => t.ownerId == actor.id).toList();

  CareTemplate saveTemplate(
    CareActor actor, {
    required CareDocKind kind,
    required String title,
    required String body,
  }) {
    final CareSpecialty? s = actor.specialty;
    if (!actor.isProfessional ||
        s == null ||
        !CarePolicy.docsFor(s).contains(kind)) {
      throw CareAccessDenied(
        '${kind.label} não é documento da ${s?.area ?? 'conta atual'}.',
      );
    }
    final CareTemplate t = CareTemplate(
      id: newId('t'),
      ownerId: actor.id,
      specialty: s,
      kind: kind,
      title: title,
      body: body,
    );
    templates.add(t);
    return t;
  }

  static String applyTemplate(
    CareTemplate t, {
    required String childName,
    required String guardianName,
    required String professionalName,
    required String registry,
    required String date,
  }) => t.body
      .replaceAll('{crianca}', childName)
      .replaceAll('{responsavel}', guardianName)
      .replaceAll('{profissional}', professionalName)
      .replaceAll('{registro}', registry)
      .replaceAll('{data}', date);

  // ----------------------------------------------------------------- Família

  CareFamilyView familyView(CareActor actor, String childId) {
    if (!_isGuardian(actor, childId)) {
      _deny(
        actor,
        'abrir área da família',
        'criança $childId',
        childId,
        'Área disponível só para o responsável da criança.',
      );
    }
    final List<CareRecord> released =
        records
            .where(
              (CareRecord r) =>
                  r.childId == childId && CarePolicy.canRead(actor, r, links),
            )
            .toList()
          ..sort(
            (CareRecord a, CareRecord b) =>
                (b.releasedAt ?? b.createdAt).compareTo(a.releasedAt ?? a.createdAt),
          );
    _log(actor, 'abriu área da família', 'cuidado', childId);
    return CareFamilyView(
      released: released,
      documents: documentsFor(actor, childId),
      pendingLinks: links
          .where((CareLink l) => l.childId == childId && l.pending)
          .toList(),
      team: links
          .where((CareLink l) => l.childId == childId && l.active)
          .toList(),
    );
  }

  // ------------------------------------------------------------------ Trilha

  /// Família vê toda a trilha da criança; a gestão, a da clínica dela.
  List<CareAuditEntry> auditFor(CareActor actor, String childId) {
    final Iterable<CareAuditEntry> all = audit.where(
      (CareAuditEntry e) => e.childId == childId,
    );
    if (_isGuardian(actor, childId)) return all.toList().reversed.toList();
    if (actor.role == CareActorRole.gestaoClinica) {
      return all
          .where((CareAuditEntry e) => e.clinicId == actor.clinicId)
          .toList()
          .reversed
          .toList();
    }
    throw const CareAccessDenied(
      'O registro de acessos fica com a família e a gestão da clínica.',
    );
  }
}
