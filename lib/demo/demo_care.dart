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

  /// Marca o conteúdo reservado da psicóloga nos testes.
  static const String reservedMarker = 'Anotação reservada (fictícia)';
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
      CareVisibility visibility = CareVisibility.equipe,
      String? measure,
      int? session,
      String? sourceId,
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
        sourceId: sourceId,
      );
      if (visibility == CareVisibility.familia) r.releasedAt = ago(days);
      store.records.add(r);
      return r;
    }

    const DemoAccount psi = DemoCareTeam.psychologist;
    const DemoAccount fis = DemoCareTeam.physio;
    const DemoAccount ped = DemoProfessional.account;

    rec(
      ped,
      CareRecordKind.resumoEquipe,
      'Resumo pediátrico para a equipe',
      'Crescimento adequado para a idade; alergia registrada no cadastro. '
          'Encaminhada para psicologia e fisioterapia. (Resumo fictício)',
      days: 38,
    );
    final CareRecord eval = rec(
      psi,
      CareRecordKind.avaliacao,
      'Avaliação inicial',
      '${DemoCareTeam.reservedMarker}: conteúdo da entrevista inicial com a '
          'família, disponível só para a psicóloga responsável.',
      days: 30,
      visibility: CareVisibility.reservado,
    );
    rec(
      psi,
      CareRecordKind.resumoEquipe,
      'Resumo para a equipe: Avaliação inicial',
      'Acompanhamento semanal para ansiedade na separação na hora de dormir. '
          'Sem sinais de alerta. (Resumo fictício)',
      days: 30,
      sourceId: eval.id,
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
    rec(
      psi,
      CareRecordKind.sessao,
      'Sessão 2',
      '${DemoCareTeam.reservedMarker}: evolução da sessão 2.',
      days: 16,
      visibility: CareVisibility.reservado,
      session: 2,
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

    rec(
      fis,
      CareRecordKind.avaliacaoFuncional,
      'Avaliação funcional',
      'Marcha com base alargada e equilíbrio num pé só abaixo do esperado '
          'para a idade. (Exemplo)',
      days: 33,
    );
    rec(
      fis,
      CareRecordKind.objetivos,
      'Objetivos da fisioterapia',
      'Ficar num pé só por 5 segundos e subir degraus alternando os pés. '
          '(Exemplo)',
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

    store.plans[CareStore.planKey(luna, DemoProfessional.clinicId)] =
        CarePlan(
          childId: luna,
          clinicId: DemoProfessional.clinicId,
          text:
              'Psicologia semanal, fisioterapia 2 vezes por semana e '
              'retorno pediátrico em 20 dias. Conversa da equipe a cada 30 '
              'dias. (Plano fictício)',
          updatedAt: ago(28),
          updatedBy: ped.name,
          updatedBySpecialty: CareSpecialty.pediatria,
          goals: <CarePlanGoal>[
            CarePlanGoal(
              text: 'Manter crescimento e sono adequados',
              specialty: CareSpecialty.pediatria,
              ownerName: ped.name,
            ),
            CarePlanGoal(
              text: 'Dormir no próprio quarto 5 noites por semana',
              specialty: CareSpecialty.psicologia,
              ownerName: psi.name,
            ),
            CarePlanGoal(
              text: 'Ficar num pé só por 5 segundos',
              specialty: CareSpecialty.fisioterapia,
              ownerName: fis.name,
            ),
          ],
        );

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
