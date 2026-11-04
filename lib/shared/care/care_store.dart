import 'care_model.dart';
import 'care_policy.dart';

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
  final List<CareRecordGrant> grants = <CareRecordGrant>[];
  final List<CareSummary> summaries = <CareSummary>[];
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
        (action.startsWith('visualizou') ||
            action.startsWith('abriu') ||
            action.startsWith('acessou'))) {
      for (final CareAuditEntry e in audit.reversed) {
        if (now.difference(e.at).inSeconds.abs() >= 60) break;
        if (e.actorId == actor.id &&
            e.action == action &&
            e.target == target &&
            e.childId == childId) {
          return;
        }
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

  /// Outros profissionais com vínculo ativo na clínica do autor: os únicos
  /// que podem receber resumo ou acesso concedido.
  List<CareLink> colleaguesOf(CareActor actor, String childId) {
    final CareLink? link = linkOf(actor, childId);
    if (link == null) return const <CareLink>[];
    return <CareLink>[
      for (final CareLink l in links)
        if (l.childId == childId &&
            l.active &&
            l.clinicId == link.clinicId &&
            l.professionalId != actor.id)
          l,
    ];
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
  /// os registros nem os resumos da equipe anterior; a família mantém o que
  /// foi liberado.
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

  /// Registros que o profissional pode ler: os próprios e os concedidos.
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
                  CarePolicy.canRead(actor, r, links, grants),
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

  CareRecord _record(String recordId) => records.firstWhere(
    (CareRecord r) => r.id == recordId,
    orElse: () => throw const CareAccessDenied('Registro inexistente.'),
  );

  /// Leitura de um registro específico, com recusa registrada.
  CareRecord open(CareActor actor, String recordId) {
    final CareRecord r = _record(recordId);
    if (!CarePolicy.canRead(actor, r, links, grants)) {
      _deny(
        actor,
        'abrir registro completo',
        '${r.kind.label} (${r.specialty.area})',
        r.childId,
        'Registro completo restrito ao autor e a acessos concedidos com '
            'justificativa.',
      );
    }
    _log(actor, 'abriu registro', '${r.kind.label} - ${r.origin}', r.childId);
    return r;
  }

  /// Seções que o leitor pode ver. Quem recebeu acesso concedido não vê
  /// anotação privada, transcrição nem conversa.
  List<CareSection> sectionsFor(CareActor actor, CareRecord record) {
    if (record.authorId == actor.id) return record.sections;
    if (!CarePolicy.canRead(actor, record, links, grants)) {
      _deny(
        actor,
        'abrir registro completo',
        '${record.kind.label} (${record.specialty.area})',
        record.childId,
        'Registro completo restrito ao autor e a acessos concedidos com '
            'justificativa.',
      );
    }
    if (!actor.isProfessional) return const <CareSection>[];
    return <CareSection>[
      for (final CareSection s in record.sections)
        if (s.kind.shareable) s,
    ];
  }

  CareRecord addRecord(
    CareActor actor, {
    required String childId,
    required CareRecordKind kind,
    required String title,
    required String body,
    CareVisibility visibility = CareVisibility.privado,
    String? measure,
    int? sessionNumber,
    List<CareSectionInput> sections = const <CareSectionInput>[],
  }) {
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
      sections: <CareSection>[
        for (final CareSectionInput s in sections)
          if (s.text.trim().isNotEmpty)
            CareSection(
              id: newId('sec'),
              kind: s.kind,
              label: s.label,
              text: s.text.trim(),
            ),
      ],
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
    return r;
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

  /// Retirar da família devolve o registro ao autor (privado), não à equipe.
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
    record.visibility = CareVisibility.privado;
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
    if (!CarePolicy.canRead(actor, record, links, grants)) {
      _deny(
        actor,
        'abrir anexos',
        record.title,
        record.childId,
        'Anexo protegido pelas mesmas regras do registro completo.',
      );
    }
    if (record.authorId != actor.id) {
      _log(actor, 'abriu anexos do registro', record.title, record.childId);
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

  // ---------------------------------------------------- Acesso concedido

  CareLink _requireAuthor(CareActor actor, CareRecord record, String action) {
    final CareLink? link = linkOf(actor, record.childId);
    if (record.authorId != actor.id ||
        link == null ||
        link.clinicId != record.clinicId) {
      _deny(
        actor,
        action,
        '${record.kind.label} - ${record.origin}',
        record.childId,
        'Só o autor do registro, com vínculo ativo, faz isso.',
      );
    }
    return link;
  }

  CareLink _requireColleague(
    CareActor actor,
    CareRecord record,
    String professionalId,
    String action,
  ) {
    final CareLink? target = colleaguesOf(actor, record.childId)
        .where((CareLink l) => l.professionalId == professionalId)
        .firstOrNull;
    if (target == null || target.clinicId != record.clinicId) {
      _deny(
        actor,
        action,
        professionalId,
        record.childId,
        'Só profissionais com vínculo ativo na equipe da criança podem '
            'receber.',
      );
    }
    return target;
  }

  /// O autor concede acesso ao registro completo (sem as seções privadas) a
  /// um profissional da equipe, com justificativa.
  CareRecordGrant grantAccess(
    CareActor actor,
    CareRecord record, {
    required String granteeId,
    required String justification,
  }) {
    _requireAuthor(actor, record, 'conceder acesso');
    final CareLink target = _requireColleague(
      actor,
      record,
      granteeId,
      'conceder acesso',
    );
    final String why = justification.trim();
    if (why.length < CareRecordGrant.minJustification) {
      throw const CareAccessDenied(
        'Justifique o acesso ao registro completo (mínimo de '
        '${CareRecordGrant.minJustification} caracteres).',
      );
    }
    if (grants.any(
      (CareRecordGrant g) =>
          g.recordId == record.id && g.granteeId == granteeId && g.active,
    )) {
      throw const CareAccessDenied('Este profissional já tem acesso.');
    }
    final CareRecordGrant g = CareRecordGrant(
      id: newId('g'),
      recordId: record.id,
      childId: record.childId,
      granteeId: granteeId,
      granteeName: target.professionalName,
      granteeSpecialty: target.specialty,
      justification: why,
      grantedAt: clock(),
      grantedBy: actor.name,
    );
    grants.add(g);
    _log(
      actor,
      'concedeu acesso ao registro completo a ${target.professionalName} '
          '($why)',
      '${record.kind.label}: ${record.title}',
      record.childId,
      clinicId: record.clinicId,
    );
    return g;
  }

  /// Retirar o acesso vale também depois do fim do vínculo do autor.
  void revokeGrant(CareActor actor, CareRecordGrant grant, String reason) {
    final CareRecord record = _record(grant.recordId);
    if (record.authorId != actor.id || !grant.active) {
      _deny(
        actor,
        'retirar acesso',
        grant.granteeName,
        record.childId,
        'Só o autor retira um acesso concedido.',
      );
    }
    grant
      ..revokedAt = clock()
      ..revokedBy = actor.name
      ..revokeReason = reason;
    _log(
      actor,
      'retirou acesso de ${grant.granteeName} ao registro completo ($reason)',
      '${record.kind.label}: ${record.title}',
      record.childId,
      clinicId: record.clinicId,
    );
  }

  List<CareRecordGrant> grantsFor(CareActor actor, CareRecord record) {
    if (record.authorId != actor.id) {
      _deny(
        actor,
        'consultar acessos concedidos',
        record.title,
        record.childId,
        'Só o autor consulta os acessos ao registro.',
      );
    }
    return grants.where((CareRecordGrant g) => g.recordId == record.id).toList();
  }

  CareRecordGrant? grantOf(CareActor actor, CareRecord record) =>
      CarePolicy.activeGrant(actor, record, links, grants);

  // -------------------------------------------------- Resumo para a equipe

  CareSummary? summaryOf(String recordId) => summaries
      .where((CareSummary s) => s.recordId == recordId)
      .firstOrNull;

  /// Começa um resumo. O primeiro começa vazio; a atualização parte do que
  /// está publicado.
  CareSummaryDraft startSummary(CareActor actor, CareRecord record) {
    _requireAuthor(actor, record, 'preparar resumo');
    final CareSummaryDraft d = CareSummaryDraft(recordId: record.id);
    final CareSummary? current = summaryOf(record.id);
    if (current != null && current.published) {
      final Set<String> still = <String>{
        for (final CareShareItem i in record.shareableItems) i.id,
      };
      d.itemIds.addAll(
        current.items.map((CareShareItem i) => i.id).where(still.contains),
      );
      d.attachmentIds.addAll(current.attachmentIds);
      d.audience = current.audience;
      if (current.audience == CareAudience.selecionados) {
        d.recipientIds.addAll(current.recipientIds);
      }
      d.note = current.note;
    }
    return d;
  }

  /// Confere as escolhas e mostra exatamente o que será enviado.
  CareSummaryPreview previewSummary(
    CareActor actor,
    CareRecord record,
    CareSummaryDraft draft,
  ) {
    _requireAuthor(actor, record, 'compartilhar resumo');
    if (draft.recordId != record.id) {
      throw const CareAccessDenied('O resumo não é deste registro.');
    }
    final Map<String, CareShareItem> allowed = <String, CareShareItem>{
      for (final CareShareItem i in record.shareableItems) i.id: i,
    };
    final Set<String> locked = <String>{
      for (final CareSection s in record.lockedSections) s.id,
    };
    for (final String id in draft.itemIds) {
      if (locked.contains(id)) {
        _deny(
          actor,
          'incluir no resumo',
          record.title,
          record.childId,
          'Anotação privada, transcrição e conversa não entram no resumo.',
        );
      }
      if (!allowed.containsKey(id)) {
        throw const CareAccessDenied('Informação inexistente no registro.');
      }
    }
    final String note = draft.note.trim();
    if (draft.itemIds.isEmpty && note.isEmpty) {
      throw const CareAccessDenied(
        'Escolha ao menos uma informação para o resumo.',
      );
    }
    final List<CareAttachment> files = <CareAttachment>[];
    for (final String id in draft.attachmentIds) {
      final CareAttachment? a = attachments
          .where((CareAttachment a) => a.id == id && a.recordId == record.id)
          .firstOrNull;
      if (a == null) {
        throw const CareAccessDenied('Anexo inexistente neste registro.');
      }
      files.add(a);
    }
    final CareAudience? audience = draft.audience;
    if (audience == null) {
      throw const CareAccessDenied('Escolha os destinatários do resumo.');
    }
    final List<CareLink> recipients = switch (audience) {
      CareAudience.equipe => colleaguesOf(actor, record.childId)
          .where((CareLink l) => l.clinicId == record.clinicId)
          .toList(),
      CareAudience.selecionados => <CareLink>[
        for (final String id in draft.recipientIds)
          _requireColleague(actor, record, id, 'compartilhar resumo'),
      ],
    };
    if (recipients.isEmpty) {
      throw const CareAccessDenied(
        'Escolha ao menos um profissional da equipe.',
      );
    }
    if (draft.aiAssisted && !draft.aiReviewed) {
      throw const CareAccessDenied(
        'Revise o texto sugerido pela IA antes de compartilhar.',
      );
    }
    final CareSummary? current = summaryOf(record.id);
    return CareSummaryPreview(
      recordId: record.id,
      recordTitle: record.title,
      items: <CareShareItem>[
        for (final CareShareItem i in record.shareableItems)
          if (draft.itemIds.contains(i.id)) i,
      ],
      attachments: files,
      recipients: recipients,
      audience: audience,
      note: note,
      version: (current?.version ?? 0) + 1,
      aiAssisted: draft.aiAssisted,
    );
  }

  /// Publica (ou atualiza) o resumo depois da prévia e da confirmação.
  CareSummary publishSummary(
    CareActor actor,
    CareRecord record,
    CareSummaryDraft draft, {
    required bool confirmed,
  }) {
    final CareSummaryPreview p = previewSummary(actor, record, draft);
    if (!confirmed) {
      throw const CareAccessDenied(
        'Confira a prévia e confirme o compartilhamento.',
      );
    }
    final DateTime now = clock();
    final CareSummary s =
        summaryOf(record.id) ??
        CareSummary(
          id: newId('s'),
          recordId: record.id,
          childId: record.childId,
          clinicId: record.clinicId,
          authorId: actor.id,
          authorName: actor.name,
          specialty: record.specialty,
          recordTitle: record.title,
          createdAt: now,
        );
    if (!summaries.contains(s)) summaries.add(s);
    s
      ..status = CareSummaryStatus.publicado
      ..audience = p.audience
      ..recipientIds = <String>[
        for (final CareLink l in p.recipients) l.professionalId,
      ]
      ..recipientNames = <String, String>{
        for (final CareLink l in p.recipients)
          l.professionalId: '${l.professionalName} (${l.specialty.area})',
      }
      ..items = List<CareShareItem>.of(p.items)
      ..attachmentIds = <String>[
        for (final CareAttachment a in p.attachments) a.id,
      ]
      ..note = p.note
      ..version = p.version
      ..updatedAt = now
      ..aiAssisted = p.aiAssisted
      ..reviewedBy = p.aiAssisted ? actor.name : null;
    s.versions.add(
      CareSummaryVersion(
        version: s.version,
        at: now,
        actorName: actor.name,
        status: s.status,
        audience: s.audience,
        recipientNames: s.recipientNames.values.toList(),
        items: s.items,
        attachmentNames: <String>[
          for (final CareAttachment a in p.attachments) a.fileName,
        ],
        note: s.note,
        aiAssisted: s.aiAssisted,
      ),
    );
    _log(
      actor,
      '${p.isUpdate ? 'atualizou' : 'compartilhou'} resumo (versão '
          '${s.version}) com ${s.recipientNames.values.join(', ')}',
      '${record.kind.label}: ${record.title}',
      record.childId,
      clinicId: record.clinicId,
    );
    return s;
  }

  /// Encerra o acesso dos destinatários. As versões continuam com o autor.
  void endSummary(CareActor actor, CareSummary summary, String reason) {
    if (summary.authorId != actor.id || !summary.published) {
      _deny(
        actor,
        'encerrar acesso ao resumo',
        summary.recordTitle,
        summary.childId,
        'Só o autor encerra o acesso a um resumo compartilhado.',
      );
    }
    final DateTime now = clock();
    summary
      ..status = CareSummaryStatus.encerrado
      ..version = summary.version + 1
      ..updatedAt = now;
    summary.versions.add(
      CareSummaryVersion(
        version: summary.version,
        at: now,
        actorName: actor.name,
        status: summary.status,
        audience: summary.audience,
        recipientNames: summary.recipientNames.values.toList(),
        items: summary.items,
        attachmentNames: <String>[
          for (final CareAttachment a in attachments)
            if (summary.attachmentIds.contains(a.id)) a.fileName,
        ],
        note: summary.note,
        reason: reason,
        aiAssisted: summary.aiAssisted,
      ),
    );
    _log(
      actor,
      'encerrou acesso ao resumo de ${summary.recipientNames.values.join(', ')} '
          '($reason)',
      summary.recordTitle,
      summary.childId,
      clinicId: summary.clinicId,
    );
  }

  void _recordAccess(CareActor actor, CareSummary s) {
    if (s.authorId == actor.id) return;
    final DateTime now = clock();
    final bool repeated = s.accessLog.any(
      (CareSummaryAccess a) =>
          a.actorId == actor.id &&
          a.version == s.version &&
          now.difference(a.at).inSeconds.abs() < 60,
    );
    if (!repeated) {
      s.accessLog.add(
        CareSummaryAccess(
          at: now,
          actorId: actor.id,
          actorName: actor.name,
          version: s.version,
        ),
      );
    }
    _log(
      actor,
      'acessou resumo',
      '${s.specialty.area} - ${s.authorName}: ${s.recordTitle} (versão '
          '${s.version})',
      s.childId,
      clinicId: s.clinicId,
    );
  }

  /// Resumos que o profissional pode ler: os que escreveu e os publicados
  /// para ele. Mostrar um resumo ao destinatário conta como acesso.
  List<CareSummary> summariesFor(CareActor actor, String childId) {
    if (!actor.isProfessional || !canOpenChild(actor, childId)) {
      _deny(
        actor,
        'abrir resumos da equipe',
        'criança $childId',
        childId,
        'Resumos da equipe ficam só com o autor e os destinatários.',
      );
    }
    final List<CareSummary> visible =
        summaries
            .where(
              (CareSummary s) =>
                  s.childId == childId &&
                  CarePolicy.canReadSummary(actor, s, links),
            )
            .toList()
          ..sort(
            (CareSummary a, CareSummary b) =>
                (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
          );
    for (final CareSummary s in visible) {
      _recordAccess(actor, s);
    }
    return visible;
  }

  CareSummary openSummary(CareActor actor, String summaryId) {
    final CareSummary s = summaries.firstWhere(
      (CareSummary s) => s.id == summaryId,
      orElse: () => throw const CareAccessDenied('Resumo inexistente.'),
    );
    if (!CarePolicy.canReadSummary(actor, s, links)) {
      _deny(
        actor,
        'abrir resumo',
        '${s.specialty.area} - ${s.authorName}',
        s.childId,
        s.published
            ? 'Este resumo não foi compartilhado com você.'
            : 'O autor encerrou o acesso a este resumo.',
      );
    }
    _recordAccess(actor, s);
    return s;
  }

  /// Anexos que o autor escolheu incluir no resumo, e só esses.
  List<CareAttachment> summaryAttachments(CareActor actor, CareSummary s) {
    if (!CarePolicy.canReadSummary(actor, s, links)) {
      _deny(
        actor,
        'abrir anexos do resumo',
        s.recordTitle,
        s.childId,
        'Anexos do resumo só para o autor e os destinatários.',
      );
    }
    return attachments
        .where((CareAttachment a) => s.attachmentIds.contains(a.id))
        .toList();
  }

  /// Quem acessou: só o autor do resumo (a família e a gestão veem a trilha
  /// geral).
  List<CareSummaryAccess> accessesOf(CareActor actor, CareSummary s) {
    if (s.authorId != actor.id) {
      _deny(
        actor,
        'consultar acessos do resumo',
        s.recordTitle,
        s.childId,
        'Só o autor consulta quem acessou o resumo.',
      );
    }
    return s.accessLog.reversed.toList();
  }

  /// Itens que o autor marcou, já conferidos: a única entrada da IA ao
  /// redigir um resumo.
  List<CareShareItem> selectedItems(
    CareActor actor,
    CareRecord record,
    CareSummaryDraft draft,
  ) {
    _requireAuthor(actor, record, 'sugerir resumo');
    final Set<String> locked = <String>{
      for (final CareSection s in record.lockedSections) s.id,
    };
    if (draft.itemIds.any(locked.contains)) {
      _deny(
        actor,
        'sugerir resumo',
        record.title,
        record.childId,
        'Anotação privada, transcrição e conversa não vão para a IA.',
      );
    }
    return <CareShareItem>[
      for (final CareShareItem i in record.shareableItems)
        if (draft.itemIds.contains(i.id)) i,
    ];
  }

  // --------------------------------------------- Plano terapêutico conjunto

  CareLink _requirePlanMember(CareActor actor, String childId, String action) {
    final CareLink link = _requireLink(actor, childId, action);
    if (!CarePolicy.allows(link.specialty, CareAction.planoCompartilhado)) {
      _deny(
        actor,
        action,
        'plano terapêutico conjunto',
        childId,
        'Especialidade sem permissão para o plano conjunto.',
      );
    }
    return link;
  }

  CarePlan? planFor(CareActor actor, String childId) {
    final CareLink link = _requireLink(
      actor,
      childId,
      'abrir plano terapêutico',
    );
    _log(
      actor,
      'visualizou plano terapêutico conjunto',
      'equipe',
      childId,
      clinicId: link.clinicId,
    );
    return plans[planKey(childId, link.clinicId)];
  }

  CarePlan _planOf(CareLink link) => plans.putIfAbsent(
    planKey(link.childId, link.clinicId),
    () => CarePlan(childId: link.childId, clinicId: link.clinicId),
  );

  (CarePlan, CareLink) _goalContext(
    CareActor actor,
    CarePlanGoal goal,
    String action,
  ) {
    for (final CarePlan p in plans.values) {
      if (!p.goals.contains(goal)) continue;
      final CareLink link = _requirePlanMember(actor, p.childId, action);
      if (link.clinicId != p.clinicId) {
        _deny(
          actor,
          action,
          goal.objective,
          p.childId,
          'Plano de outra clínica.',
        );
      }
      return (p, link);
    }
    throw const CareAccessDenied('Objetivo inexistente.');
  }

  CarePlanGoal addGoal(
    CareActor actor,
    String childId, {
    required String objective,
    required String responsibleId,
    required DateTime dueDate,
    required DateTime reassessAt,
    String firstAction = '',
  }) {
    final CareLink link = _requirePlanMember(actor, childId, 'criar objetivo');
    final CareLink? responsible = responsibleId == actor.id
        ? link
        : colleaguesOf(actor, childId)
              .where((CareLink l) => l.professionalId == responsibleId)
              .firstOrNull;
    if (responsible == null) {
      throw const CareAccessDenied(
        'O responsável precisa estar na equipe ativa da criança.',
      );
    }
    if (objective.trim().isEmpty) {
      throw const CareAccessDenied('Descreva o objetivo.');
    }
    final DateTime now = clock();
    final CarePlan plan = _planOf(link);
    final CarePlanGoal g = CarePlanGoal(
      id: newId('o'),
      objective: objective.trim(),
      responsibleId: responsible.professionalId,
      responsibleName: responsible.professionalName,
      responsibleSpecialty: responsible.specialty,
      dueDate: dueDate,
      reassessAt: reassessAt,
      createdBy: actor.name,
      createdAt: now,
    );
    plan.goals.add(g);
    if (firstAction.trim().isNotEmpty) {
      g.contributions.add(
        CarePlanContribution(
          id: newId('c'),
          authorId: actor.id,
          authorName: actor.name,
          specialty: link.specialty,
          kind: CareContributionKind.acao,
          text: firstAction.trim(),
          at: now,
        ),
      );
    }
    plan.history.add(
      CarePlanChange(
        at: now,
        actorName: actor.name,
        specialty: link.specialty,
        description:
            'Novo objetivo: ${g.objective} (responsável: '
            '${g.responsibleName})',
      ),
    );
    _log(
      actor,
      'criou objetivo no plano terapêutico',
      link.specialty.area,
      childId,
      clinicId: link.clinicId,
    );
    return g;
  }

  /// O profissional escreve o que decide compartilhar no plano.
  CarePlanContribution contribute(
    CareActor actor,
    CarePlanGoal goal, {
    required CareContributionKind kind,
    required String text,
  }) {
    final (CarePlan plan, CareLink link) = _goalContext(
      actor,
      goal,
      'contribuir com o plano',
    );
    if (text.trim().isEmpty) {
      throw const CareAccessDenied('Escreva a contribuição.');
    }
    final DateTime now = clock();
    final CarePlanContribution c = CarePlanContribution(
      id: newId('c'),
      authorId: actor.id,
      authorName: actor.name,
      specialty: link.specialty,
      kind: kind,
      text: text.trim(),
      at: now,
    );
    goal.contributions.add(c);
    plan.history.add(
      CarePlanChange(
        at: now,
        actorName: actor.name,
        specialty: link.specialty,
        description: '${kind.label} em "${goal.objective}"',
      ),
    );
    _log(
      actor,
      'contribuiu com o plano (${kind.label.toLowerCase()})',
      goal.objective,
      plan.childId,
      clinicId: plan.clinicId,
    );
    return c;
  }

  /// Reavaliação: só o profissional responsável pelo objetivo.
  void reassess(
    CareActor actor,
    CarePlanGoal goal, {
    required CareGoalStatus status,
    required String note,
    required DateTime nextReassessAt,
  }) {
    final (CarePlan plan, CareLink link) = _goalContext(
      actor,
      goal,
      'reavaliar objetivo',
    );
    if (goal.responsibleId != actor.id) {
      _deny(
        actor,
        'reavaliar objetivo',
        goal.objective,
        plan.childId,
        'Só o profissional responsável reavalia o objetivo.',
      );
    }
    final DateTime now = clock();
    goal
      ..status = status
      ..reassessAt = nextReassessAt;
    goal.reassessments.add(
      CareReassessment(
        at: now,
        actorName: actor.name,
        status: status,
        note: note.trim(),
        nextReassessAt: nextReassessAt,
      ),
    );
    plan.history.add(
      CarePlanChange(
        at: now,
        actorName: actor.name,
        specialty: link.specialty,
        description: 'Reavaliou "${goal.objective}": ${status.label}',
      ),
    );
    _log(
      actor,
      'reavaliou objetivo (${status.label.toLowerCase()})',
      goal.objective,
      plan.childId,
      clinicId: plan.clinicId,
    );
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

  void _requireDocAuthor(CareActor actor, CareDocument d, String action) {
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
    _requireDocAuthor(actor, d, 'revisar documento');
    if (d.status == CareDocStatus.issued) {
      throw const CareAccessDenied('Documento emitido não muda.');
    }
    if (body != null) d.body = body;
    d.status = CareDocStatus.reviewed;
    _log(actor, 'revisou documento', d.kind.label, d.childId);
  }

  void issueDocument(CareActor actor, CareDocument d) {
    _requireDocAuthor(actor, d, 'emitir documento');
    if (d.status != CareDocStatus.reviewed) {
      throw const CareAccessDenied('Revise o documento antes de emitir.');
    }
    d.status = CareDocStatus.issued;
    d.issuedAt = clock();
    _log(actor, 'emitiu documento', d.kind.label, d.childId);
  }

  void releaseDocument(CareActor actor, CareDocument d) {
    _requireDocAuthor(actor, d, 'liberar documento');
    if (d.status != CareDocStatus.issued) {
      throw const CareAccessDenied('Só documento emitido vai para a família.');
    }
    d.releasedAt = clock();
    _log(actor, 'liberou documento para a família', d.kind.label, d.childId);
  }

  /// Documentos são do autor; a família vê só os liberados.
  List<CareDocument> documentsFor(CareActor actor, String childId) => documents
      .where(
        (CareDocument d) =>
            d.childId == childId &&
            ((actor.isProfessional && d.authorId == actor.id) ||
                (_isGuardian(actor, childId) && d.releasedAt != null)),
      )
      .toList();

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
                  r.childId == childId &&
                  CarePolicy.canRead(actor, r, links, grants),
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
