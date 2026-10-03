import '../shared/care/care_model.dart';
import '../shared/care/care_store.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';
import 'demo_session.dart';

/// Equipe multidisciplinar fictícia: a Luna (p1) é atendida pela pediatra,
/// por uma psicóloga e por um fisioterapeuta do Consultório Exemplo.
class DemoCareTeam {
  const DemoCareTeam._();

  static const String childId = 'p1';

  static const DemoAccount psychologist = DemoAccount(
    id: 'psi-a',
    name: 'Psicóloga Exemplo Ramos',
    registry: 'CRP 00/00000 (fictício)',
    specialty: 'Psicologia',
    clinic: DemoProfessional.clinic,
    address: DemoProfessional.address,
    city: DemoProfessional.city,
    email: 'psicologa.exemplo@exemplo.invalid',
    clinicId: DemoProfessional.clinicId,
  );

  /// Assume a psicologia na troca de profissional.
  static const DemoAccount psychologist2 = DemoAccount(
    id: 'psi-c',
    name: 'Psicólogo Exemplo Teixeira',
    registry: 'CRP 00/11111 (fictício)',
    specialty: 'Psicologia',
    clinic: DemoProfessional.clinic,
    address: DemoProfessional.address,
    city: DemoProfessional.city,
    email: 'psicologo.exemplo@exemplo.invalid',
    clinicId: DemoProfessional.clinicId,
  );

  static const DemoAccount physio = DemoAccount(
    id: 'fis-a',
    name: 'Fisioterapeuta Exemplo Moura',
    registry: 'CREFITO 0-000000-F (fictício)',
    specialty: 'Fisioterapia',
    clinic: DemoProfessional.clinic,
    address: DemoProfessional.address,
    city: DemoProfessional.city,
    email: 'fisio.exemplo@exemplo.invalid',
    clinicId: DemoProfessional.clinicId,
  );

  static const List<DemoAccount> accounts = <DemoAccount>[
    psychologist,
    psychologist2,
    physio,
  ];

  /// Marca a anotação privada, a transcrição e a conversa nos testes.
  static const String privateMarker = 'Anotação privada (fictícia)';

  /// Marca o texto completo do registro (evolução) nos testes.
  static const String fullRecordMarker = 'Evolução completa (fictícia)';
}

/// Cuidado multidisciplinar na demonstração: liga a sessão ao [CareStore].
class DemoCare {
  DemoCare(this._s) {
    store.clock = () => _s.now;
    _seed();
  }

  final DemoSession _s;
  final CareStore store = CareStore();

  /// Quem age, conforme o perfil e a conta em uso.
  CareActor get actor {
    switch (_s.profile) {
      case DemoProfile.profissional:
        final DemoAccount a = _s.account;
        return CareActor(
          id: a.id,
          name: a.name,
          role: CareActorRole.profissional,
          specialty: CareSpecialty.fromText(a.specialty),
          clinicId: a.clinicId,
        );
      case DemoProfile.responsavel:
        return CareActor(
          id: 'familia-a',
          name: DemoSession.guardianOfDemo,
          role: CareActorRole.familia,
          guardianOf: <String>{
            for (final DemoPatient p in _s.patients)
              if (p.guardianName == DemoSession.guardianOfDemo) p.id,
          },
        );
      case DemoProfile.administrador:
        return const CareActor(
          id: DemoProfessional.managerId,
          name: DemoProfessional.managerName,
          role: CareActorRole.gestaoClinica,
          clinicId: DemoProfessional.clinicId,
        );
      case DemoProfile.recepcao:
        return const CareActor(
          id: 'recepcao-a',
          name: 'Recepção Exemplo',
          role: CareActorRole.recepcao,
          clinicId: DemoProfessional.clinicId,
        );
      case DemoProfile.financeiro:
        return const CareActor(
          id: 'financeiro-a',
          name: 'Financeiro Exemplo',
          role: CareActorRole.financeiro,
          clinicId: DemoProfessional.clinicId,
        );
      case null:
        return const CareActor(
          id: 'anonimo',
          name: 'Sem perfil',
          role: CareActorRole.recepcao,
        );
    }
  }

  /// Abre a ficha multidisciplinar da criança.
  bool canOpen(String childId) {
    final CareActor a = actor;
    if (a.role == CareActorRole.gestaoClinica) {
      return store.links.any(
        (CareLink l) => l.childId == childId && l.clinicId == a.clinicId,
      );
    }
    return store.canOpenChild(a, childId);
  }

  /// Próximos atendimentos da criança com a equipe de vínculo ativo, de cada
  /// agenda. A família vê toda a equipe atual; a clínica, só a dela.
  List<DemoAppointment> nextSessions(String childId) {
    final DateTime t = _s.now;
    final CareActor me = actor;
    final Set<String> team = <String>{
      for (final CareLink l in store.links)
        if (l.childId == childId &&
            l.active &&
            (me.isFamily || l.clinicId == me.clinicId))
          l.professionalId,
    };
    return _s.appointments
        .where(
          (DemoAppointment a) =>
              a.patientId == childId &&
              team.contains(a.professionalId) &&
              a.status.holdsSlot &&
              a.status != DemoAppointmentStatus.concluido &&
              a.start.isAfter(t),
        )
        .toList()
      ..sort((DemoAppointment a, DemoAppointment b) => a.start.compareTo(b.start));
  }

  static CareSpecialty specialtyOf(String accountId) =>
      CareSpecialty.fromText(DemoProfessional.byId(accountId).specialty) ??
      CareSpecialty.pediatria;

  // ---------------------------------------------------------- Dados fictícios

  /// Sessões de psicologia e fisioterapia da Luna, cada uma na agenda do
  /// próprio profissional.
  static List<DemoAppointment> appointments(DateTime now) {
    final DateTime d = DateTime(now.year, now.month, now.day);
    DateTime at(int days, int hour) =>
        DateTime(d.year, d.month, d.day + days, hour);
    return <DemoAppointment>[
      DemoAppointment(
        id: 'mp1',
        patientId: DemoCareTeam.childId,
        start: at(2, 15),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.confirmado,
        reason: 'Sessão de psicologia (exemplo)',
        professionalId: DemoCareTeam.psychologist.id,
        durationMinutes: 50,
        typeLabel: 'Psicologia',
      ),
      DemoAppointment(
        id: 'mp2',
        patientId: DemoCareTeam.childId,
        start: at(9, 15),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Sessão de psicologia (exemplo)',
        professionalId: DemoCareTeam.psychologist.id,
        durationMinutes: 50,
        typeLabel: 'Psicologia',
      ),
      DemoAppointment(
        id: 'mf1',
        patientId: DemoCareTeam.childId,
        start: at(3, 16),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.confirmado,
        reason: 'Sessão de fisioterapia (exemplo)',
        professionalId: DemoCareTeam.physio.id,
        durationMinutes: 45,
        typeLabel: 'Fisioterapia',
      ),
      DemoAppointment(
        id: 'mf2',
        patientId: DemoCareTeam.childId,
        start: at(5, 16),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Sessão de fisioterapia (exemplo)',
        professionalId: DemoCareTeam.physio.id,
        durationMinutes: 45,
        typeLabel: 'Fisioterapia',
      ),
    ];
  }

  void _seed() {
    final DateTime now = _s.now;
    DateTime ago(int days) => now.subtract(Duration(days: days));
    DateTime ahead(int days) => now.add(Duration(days: days));

    CareLink link(
      String child,
      DemoAccount a,
      String reason, {
      required int days,
      String requestedBy = DemoProfessional.name,
    }) {
      final CareLink l = CareLink(
        id: store.newId('v'),
        childId: child,
        professionalId: a.id,
        professionalName: a.name,
        specialty: CareSpecialty.fromText(a.specialty)!,
        clinicId: a.clinicId!,
        clinicName: a.clinic,
        since: ago(days),
        reason: reason,
        requestedBy: requestedBy,
        registry: a.registry,
        authorizedAt: ago(days),
        authorizedBy: DemoSession.guardianOfDemo,
      );
      store.links.add(l);
      return l;
    }

    for (final String id in const <String>['p1', 'p2', 'p3', 'p4', 'p5', 'p6']) {
      link(
        id,
        DemoProfessional.account,
        'Pediatra de referência',
        days: 400,
        requestedBy: 'Família',
      );
    }
    for (final String id in const <String>['p7', 'p8']) {
      link(
        id,
        DemoProfessional.colleague,
        'Pediatra de referência',
        days: 300,
        requestedBy: 'Família',
      );
    }
    const String luna = DemoCareTeam.childId;
    link(
      luna,
      DemoCareTeam.psychologist,
      'Dificuldade para dormir sozinha e ansiedade na separação (exemplo)',
      days: 40,
    );
    link(
      luna,
      DemoCareTeam.physio,
      'Avaliação da marcha e do equilíbrio (exemplo)',
      days: 35,
    );

    CareRecord rec(
      DemoAccount a,
      CareRecordKind kind,
      String title,
      String body, {
      required int days,
      CareVisibility visibility = CareVisibility.privado,
      String? measure,
      int? session,
      List<CareSectionInput> sections = const <CareSectionInput>[],
    }) {
      final CareRecord r = CareRecord(
        id: store.newId('r'),
        childId: luna,
        clinicId: a.clinicId!,
        authorId: a.id,
        authorName: a.name,
        specialty: CareSpecialty.fromText(a.specialty)!,
        kind: kind,
        title: title,
        body: body,
        visibility: visibility,
        createdAt: ago(days),
        measure: measure,
        sessionNumber: session,
        sections: <CareSection>[
          for (final CareSectionInput s in sections)
            CareSection(
              id: store.newId('sec'),
              kind: s.kind,
              label: s.label,
              text: s.text,
            ),
        ],
      );
      if (visibility == CareVisibility.familia) r.releasedAt = ago(days);
      store.records.add(r);
      return r;
    }

    const DemoAccount psi = DemoCareTeam.psychologist;
    const DemoAccount fis = DemoCareTeam.physio;
    const DemoAccount ped = DemoProfessional.account;

    String who(DemoAccount a) =>
        '${a.name} (${CareSpecialty.fromText(a.specialty)!.area})';

    /// Resumo já publicado, com a versão 1 no histórico.
    void share(
      CareRecord r,
      DemoAccount author, {
      required List<String> itemIds,
      required List<DemoAccount> to,
      required CareAudience audience,
      required int days,
      String note = '',
    }) {
      final CareSummary s =
          CareSummary(
              id: store.newId('s'),
              recordId: r.id,
              childId: luna,
              clinicId: author.clinicId!,
              authorId: author.id,
              authorName: author.name,
              specialty: r.specialty,
              recordTitle: r.title,
              createdAt: ago(days),
            )
            ..audience = audience
            ..recipientIds = <String>[for (final DemoAccount a in to) a.id]
            ..recipientNames = <String, String>{
              for (final DemoAccount a in to) a.id: who(a),
            }
            ..items = <CareShareItem>[
              for (final CareShareItem i in r.shareableItems)
                if (itemIds.contains(i.id)) i,
            ]
            ..note = note
            ..version = 1
            ..updatedAt = ago(days);
      s.versions.add(
        CareSummaryVersion(
          version: 1,
          at: ago(days),
          actorName: author.name,
          status: s.status,
          audience: audience,
          recipientNames: s.recipientNames.values.toList(),
          items: s.items,
          attachmentNames: const <String>[],
          note: note,
        ),
      );
      store.summaries.add(s);
    }

    final CareRecord pedEval = rec(
      ped,
      CareRecordKind.avaliacao,
      'Consulta pediátrica',
      'Crescimento adequado para a idade; alergia registrada no cadastro. '
          'Encaminhada para psicologia e fisioterapia. (Registro fictício)',
      days: 38,
    );
    share(
      pedEval,
      ped,
      itemIds: <String>[CareRecord.bodyItemId],
      to: <DemoAccount>[psi, fis],
      audience: CareAudience.equipe,
      days: 38,
    );

    final CareRecord eval = rec(
      psi,
      CareRecordKind.avaliacao,
      'Avaliação inicial',
      '${DemoCareTeam.fullRecordMarker}: entrevista inicial com a família, '
          'histórico do sono e da separação e observação lúdica.',
      days: 30,
      sections: <CareSectionInput>[
        (
          kind: CareSectionKind.clinica,
          label: 'Hipótese de trabalho',
          text:
              'Ansiedade de separação na hora de dormir, sem sinais de '
              'alerta. (Exemplo)',
        ),
        (
          kind: CareSectionKind.clinica,
          label: 'Conduta',
          text: 'Acompanhamento semanal por 8 semanas. (Exemplo)',
        ),
        (
          kind: CareSectionKind.anotacaoPrivada,
          label: 'Anotação privada',
          text:
              '${DemoCareTeam.privateMarker}: impressões da psicóloga sobre '
              'a dinâmica familiar.',
        ),
      ],
    );
    store.attachments.add(
      CareAttachment(
        id: store.newId('f'),
        recordId: eval.id,
        fileName: 'desenho-sessao-1-exemplo.png',
        addedBy: psi.name,
        at: ago(30),
      ),
    );
    share(
      eval,
      psi,
      itemIds: <String>[
        for (final CareSection s in eval.sections)
          if (s.kind.shareable) s.id,
      ],
      to: <DemoAccount>[ped],
      audience: CareAudience.selecionados,
      days: 30,
      note: 'Sugiro reforçar a rotina do sono nas consultas. (Exemplo)',
    );
    rec(
      psi,
      CareRecordKind.sessao,
      'Sessão 2',
      '${DemoCareTeam.fullRecordMarker}: evolução da sessão 2, brincadeira '
          'de despedida e combinados para a noite.',
      days: 16,
      session: 2,
      sections: <CareSectionInput>[
        (
          kind: CareSectionKind.clinica,
          label: 'Evolução para a equipe',
          text:
              'Aceitou dormir com a porta encostada em 3 noites. (Exemplo)',
        ),
        (
          kind: CareSectionKind.transcricao,
          label: 'Transcrição',
          text: '${DemoCareTeam.privateMarker}: trecho transcrito da sessão.',
        ),
        (
          kind: CareSectionKind.conversa,
          label: 'Conversa com a responsável',
          text: '${DemoCareTeam.privateMarker}: conversa ao fim da sessão.',
        ),
      ],
    );
    rec(
      psi,
      CareRecordKind.planoTerapeutico,
      'Plano terapêutico',
      '8 sessões semanais. Objetivos: rotina de sono previsível e mais '
          'autonomia na separação. (Exemplo)',
      days: 28,
    );
    rec(
      psi,
      CareRecordKind.orientacao,
      'Rotina do sono em 3 passos',
      'Banho, história curta e despedida combinada, sempre na mesma ordem. '
          '(Orientação fictícia)',
      days: 14,
      visibility: CareVisibility.familia,
    );

    final CareRecord fisEval = rec(
      fis,
      CareRecordKind.avaliacaoFuncional,
      'Avaliação funcional',
      'Marcha com base alargada e equilíbrio num pé só abaixo do esperado '
          'para a idade. (Exemplo)',
      days: 33,
      sections: <CareSectionInput>[
        (
          kind: CareSectionKind.anotacaoPrivada,
          label: 'Anotação privada',
          text:
              '${DemoCareTeam.privateMarker}: observação da fisioterapeuta '
              'para a próxima sessão.',
        ),
      ],
    );
    share(
      fisEval,
      fis,
      itemIds: <String>[CareRecord.bodyItemId],
      to: <DemoAccount>[ped, psi],
      audience: CareAudience.equipe,
      days: 33,
    );
    rec(
      fis,
      CareRecordKind.planoSessoes,
      'Plano de sessões',
      '10 sessões, 2 vezes por semana, 45 minutos. (Exemplo)',
      days: 33,
    );
    rec(
      fis,
      CareRecordKind.intervencao,
      'Sessão 3',
      'Circuito de equilíbrio e fortalecimento das pernas. (Exemplo)',
      days: 20,
      session: 3,
    );
    rec(
      fis,
      CareRecordKind.medida,
      'Apoio num pé só',
      'Medida inicial.',
      days: 33,
      measure: '2 s (exemplo)',
    );
    rec(
      fis,
      CareRecordKind.medida,
      'Apoio num pé só',
      'Medida na sessão 4.',
      days: 12,
      measure: '3 s (exemplo)',
    );
    rec(
      fis,
      CareRecordKind.evolucao,
      'Sessão 4',
      'Melhor controle no circuito de equilíbrio. (Exemplo)',
      days: 12,
      session: 4,
    );
    rec(
      fis,
      CareRecordKind.atividadeCasa,
      'Brincadeira do flamingo',
      'Ficar num pé só contando até 5, 3 vezes em cada perna, com um adulto '
          'ao lado. (Exercício fictício)',
      days: 12,
      visibility: CareVisibility.familia,
    );
    rec(
      fis,
      CareRecordKind.atividadeCasa,
      'Degraus alternados',
      'Subir 4 degraus alternando os pés, segurando a mão do adulto. '
          '(Exercício fictício, ainda não liberado)',
      days: 5,
    );

    final CarePlan plan = CarePlan(
      childId: luna,
      clinicId: DemoProfessional.clinicId,
    );
    CarePlanGoal goal(
      String objective,
      DemoAccount owner, {
      required int due,
      required int reassess,
      required int days,
    }) {
      final CarePlanGoal g = CarePlanGoal(
        id: store.newId('o'),
        objective: objective,
        responsibleId: owner.id,
        responsibleName: owner.name,
        responsibleSpecialty: CareSpecialty.fromText(owner.specialty)!,
        dueDate: ahead(due),
        reassessAt: ahead(reassess),
        createdBy: ped.name,
        createdAt: ago(days),
      );
      plan.goals.add(g);
      plan.history.add(
        CarePlanChange(
          at: ago(days),
          actorName: ped.name,
          specialty: CareSpecialty.pediatria,
          description:
              'Novo objetivo: $objective (responsável: ${owner.name})',
        ),
      );
      return g;
    }

    void contribution(
      CarePlanGoal g,
      DemoAccount a,
      CareContributionKind kind,
      String text, {
      required int days,
    }) => g.contributions.add(
      CarePlanContribution(
        id: store.newId('c'),
        authorId: a.id,
        authorName: a.name,
        specialty: CareSpecialty.fromText(a.specialty)!,
        kind: kind,
        text: text,
        at: ago(days),
      ),
    );

    final CarePlanGoal sleep = goal(
      'Dormir no próprio quarto 5 noites por semana',
      psi,
      due: 60,
      reassess: 20,
      days: 28,
    );
    contribution(
      sleep,
      psi,
      CareContributionKind.acao,
      'Sessões semanais com combinados de rotina para a noite. (Exemplo)',
      days: 28,
    );
    contribution(
      sleep,
      ped,
      CareContributionKind.informacao,
      'Sem causa clínica para os despertares noturnos. (Exemplo)',
      days: 25,
    );
    final CarePlanGoal balance = goal(
      'Ficar num pé só por 5 segundos',
      fis,
      due: 45,
      reassess: 15,
      days: 28,
    );
    contribution(
      balance,
      fis,
      CareContributionKind.acao,
      'Circuito de equilíbrio 2 vezes por semana e exercício para casa. '
          '(Exemplo)',
      days: 28,
    );
    contribution(
      balance,
      fis,
      CareContributionKind.informacao,
      'Medida atual: 3 segundos. (Exemplo)',
      days: 12,
    );
    goal(
      'Manter crescimento e alimentação adequados',
      ped,
      due: 120,
      reassess: 30,
      days: 28,
    );
    store.plans[CareStore.planKey(luna, DemoProfessional.clinicId)] = plan;

    CareMessage msg(
      DemoAccount from,
      CareMessageKind kind,
      String subject,
      String body, {
      required int days,
      CareSpecialty? to,
      CareMessageStatus status = CareMessageStatus.aberto,
      String? replyTo,
    }) {
      final CareMessage m = CareMessage(
        id: store.newId('m'),
        childId: luna,
        clinicId: from.clinicId!,
        kind: kind,
        authorId: from.id,
        authorName: from.name,
        authorSpecialty: CareSpecialty.fromText(from.specialty)!,
        subject: subject,
        body: body,
        at: ago(days),
        toSpecialty: to,
        replyTo: replyTo,
      )..status = status;
      m.events.add(
        CareMessageEvent(
          at: ago(days),
          actorName: from.name,
          status: CareMessageStatus.aberto,
        ),
      );
      if (status != CareMessageStatus.aberto) {
        m.events.add(
          CareMessageEvent(
            at: ago(days - 1),
            actorName: to == CareSpecialty.psicologia ? psi.name : ped.name,
            status: status,
          ),
        );
      }
      store.messages.add(m);
      return m;
    }

    msg(
      ped,
      CareMessageKind.encaminhamento,
      'Psicologia: sono e separação',
      'Peço avaliação da psicologia: dificuldade para dormir sozinha e '
          'choro na separação. (Exemplo)',
      days: 41,
      to: CareSpecialty.psicologia,
      status: CareMessageStatus.aceito,
    );
    final CareMessage parecer = msg(
      fis,
      CareMessageKind.parecer,
      'Parecer sobre calçados',
      'Há alguma restrição para calçado com palmilha? (Exemplo)',
      days: 6,
      to: CareSpecialty.pediatria,
    );
    msg(
      psi,
      CareMessageKind.mensagem,
      'Horário das sessões',
      'As sessões de psicologia passam para as tardes. (Exemplo)',
      days: 3,
    );

    final CareDocument decl = CareDocument(
      id: store.newId('d'),
      childId: luna,
      clinicId: psi.clinicId!,
      kind: CareDocKind.declaracaoComparecimento,
      authorId: psi.id,
      authorName: psi.name,
      authorRegistry: psi.registry,
      specialty: CareSpecialty.psicologia,
      title: 'Declaração de comparecimento',
      body:
          'Declaro que Luna Exemplo Souza compareceu à sessão de psicologia, '
          'acompanhada por Responsável Exemplo A. (Documento fictício)',
      createdAt: ago(16),
    )
      ..status = CareDocStatus.issued
      ..issuedAt = ago(16);
    store.documents.add(decl);

    store.templates.addAll(<CareTemplate>[
      CareTemplate(
        id: store.newId('t'),
        ownerId: psi.id,
        specialty: CareSpecialty.psicologia,
        kind: CareDocKind.declaracaoComparecimento,
        title: 'Comparecimento à sessão',
        body:
            'Declaro que {crianca} compareceu à sessão de psicologia em '
            '{data}, acompanhada por {responsavel}.\n\n{profissional} - '
            '{registro}',
      ),
      CareTemplate(
        id: store.newId('t'),
        ownerId: fis.id,
        specialty: CareSpecialty.fisioterapia,
        kind: CareDocKind.planoExerciciosCasa,
        title: 'Exercícios de equilíbrio',
        body:
            'Plano de exercícios para {crianca} ({data}):\n'
            '1. Brincadeira do flamingo: 3 vezes em cada perna.\n'
            '2. Andar sobre uma linha no chão: 5 vezes.\n'
            'Sempre com um adulto ao lado.\n\n{profissional} - {registro}',
      ),
    ]);
    // Mantém a referência para os testes acharem o parecer em aberto.
    pendingOpinionId = parecer.id;
  }

  /// Parecer da fisioterapia aguardando a pediatra (dados fictícios).
  late String pendingOpinionId;
}
