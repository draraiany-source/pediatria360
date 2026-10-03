import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/care/care_ai.dart';
import 'package:pediatria360/shared/care/care_model.dart';
import 'package:pediatria360/shared/care/care_policy.dart';
import 'package:pediatria360/shared/care/care_store.dart';

const String kChild = 'luna';
const String kSecret = 'CONTEUDO-RESERVADO-FICTICIO';

const CareActor ped = CareActor(
  id: 'ped',
  name: 'Pediatra Exemplo',
  role: CareActorRole.profissional,
  specialty: CareSpecialty.pediatria,
  clinicId: 'clinica-a',
);
const CareActor psi = CareActor(
  id: 'psi',
  name: 'Psicóloga Exemplo',
  role: CareActorRole.profissional,
  specialty: CareSpecialty.psicologia,
  clinicId: 'clinica-a',
);
const CareActor fis = CareActor(
  id: 'fis',
  name: 'Fisioterapeuta Exemplo',
  role: CareActorRole.profissional,
  specialty: CareSpecialty.fisioterapia,
  clinicId: 'clinica-a',
);
const CareActor psi2 = CareActor(
  id: 'psi2',
  name: 'Outro Psicólogo da Clínica',
  role: CareActorRole.profissional,
  specialty: CareSpecialty.psicologia,
  clinicId: 'clinica-a',
);
const CareActor pedB = CareActor(
  id: 'pedB',
  name: 'Pediatra da Clínica Dois',
  role: CareActorRole.profissional,
  specialty: CareSpecialty.pediatria,
  clinicId: 'clinica-b',
);
const CareActor manager = CareActor(
  id: 'gestao',
  name: 'Gestão Exemplo',
  role: CareActorRole.gestaoClinica,
  clinicId: 'clinica-a',
);
const CareActor reception = CareActor(
  id: 'recepcao',
  name: 'Recepção Exemplo',
  role: CareActorRole.recepcao,
  clinicId: 'clinica-a',
);
const CareActor family = CareActor(
  id: 'familia',
  name: 'Responsável Exemplo',
  role: CareActorRole.familia,
  guardianOf: <String>{kChild},
);
const CareActor otherFamily = CareActor(
  id: 'outra-familia',
  name: 'Outro Responsável',
  role: CareActorRole.familia,
  guardianOf: <String>{'outra'},
);

/// Pediatra, psicóloga e fisioterapeuta com vínculo ativo com a Luna.
CareStore seeded() {
  final CareStore s = CareStore(clock: () => DateTime(2026, 10, 2, 10));
  for (final CareActor a in <CareActor>[ped, psi, fis]) {
    final CareLink l = s.requestLink(
      manager,
      childId: kChild,
      professionalId: a.id,
      professionalName: a.name,
      specialty: a.specialty!,
      clinicId: 'clinica-a',
      clinicName: 'Clínica A',
      reason: 'Motivo fictício (${a.specialty!.area})',
    );
    s.authorize(family, l);
  }
  return s;
}

void main() {
  group('Matriz de permissões por especialidade', () {
    test('só a pediatria prescreve, pede exames e emite atestado médico', () {
      for (final CareSpecialty s in CareSpecialty.values) {
        final bool ped = s == CareSpecialty.pediatria;
        expect(CarePolicy.allows(s, CareAction.prescrever), ped, reason: s.area);
        expect(CarePolicy.allows(s, CareAction.solicitarExames), ped);
        expect(CarePolicy.allows(s, CareAction.atestadoMedico), ped);
        expect(
          CarePolicy.docsFor(s).contains(CareDocKind.receituario),
          ped,
          reason: s.area,
        );
        expect(CarePolicy.docsFor(s).contains(CareDocKind.atestadoMedico), ped);
      }
    });

    test('registro reservado: só a psicologia', () {
      expect(
        CareSpecialty.values.where(CarePolicy.canReserve),
        <CareSpecialty>[CareSpecialty.psicologia],
      );
    });

    test('documentos próprios de cada área', () {
      expect(
        CarePolicy.docsFor(CareSpecialty.psicologia),
        contains(CareDocKind.relatorioPsicologico),
      );
      expect(
        CarePolicy.docsFor(CareSpecialty.fisioterapia),
        containsAll(<CareDocKind>[
          CareDocKind.relatorioFisioterapeutico,
          CareDocKind.planoExerciciosCasa,
        ]),
      );
      expect(
        CarePolicy.docsFor(CareSpecialty.fisioterapia),
        isNot(contains(CareDocKind.relatorioPsicologico)),
      );
    });

    test('fono, terapia ocupacional e nutrição: perfis prontos para expansão', () {
      for (final CareSpecialty s in <CareSpecialty>[
        CareSpecialty.fonoaudiologia,
        CareSpecialty.terapiaOcupacional,
        CareSpecialty.nutricao,
      ]) {
        expect(s.active, isFalse);
        expect(CarePolicy.kindsFor(s), isNotEmpty);
        expect(CarePolicy.docsFor(s), isNotEmpty);
        expect(CarePolicy.allows(s, CareAction.prescrever), isFalse);
      }
      expect(CareSpecialty.fromText('Fonoaudiologia'), CareSpecialty.fonoaudiologia);
      expect(CareSpecialty.fromText('Nutrição'), CareSpecialty.nutricao);
    });
  });

  group('Vínculo real, não pertencer à clínica', () {
    test('profissional da mesma clínica sem vínculo não abre nada', () {
      final CareStore s = seeded();
      expect(s.canOpenChild(psi2, kChild), isFalse);
      expect(() => s.recordsFor(psi2, kChild), throwsA(isA<CareAccessDenied>()));
      expect(() => s.sharedView(psi2, kChild), throwsA(isA<CareAccessDenied>()));
      expect(() => s.messagesFor(psi2, kChild), throwsA(isA<CareAccessDenied>()));
      expect(
        s.audit.where((CareAuditEntry e) => e.actorId == 'psi2' && !e.allowed),
        hasLength(3),
      );
    });

    test('gestão organiza a equipe, mas não lê registros', () {
      final CareStore s = seeded();
      expect(s.team(manager, kChild), hasLength(3));
      expect(() => s.recordsFor(manager, kChild), throwsA(isA<CareAccessDenied>()));
      expect(() => s.sharedView(manager, kChild), throwsA(isA<CareAccessDenied>()));
    });

    test('recepção e outra família não abrem a ficha', () {
      final CareStore s = seeded();
      expect(() => s.recordsFor(reception, kChild), throwsA(isA<CareAccessDenied>()));
      expect(() => s.familyView(otherFamily, kChild), throwsA(isA<CareAccessDenied>()));
    });

    test('vínculo pendente não dá acesso até a família autorizar', () {
      final CareStore s = seeded();
      final CareLink l = s.requestLink(
        manager,
        childId: kChild,
        professionalId: psi2.id,
        professionalName: psi2.name,
        specialty: CareSpecialty.psicologia,
        clinicId: 'clinica-a',
        clinicName: 'Clínica A',
        reason: 'Fictício',
      );
      expect(l.pending, isTrue);
      expect(s.canOpenChild(psi2, kChild), isFalse);
      expect(() => s.authorize(psi2, l), throwsA(isA<CareAccessDenied>()));
      expect(() => s.authorize(manager, l), throwsA(isA<CareAccessDenied>()));
      s.authorize(family, l);
      expect(s.canOpenChild(psi2, kChild), isTrue);
    });

    test('profissional não se designa sozinho em outra clínica', () {
      final CareStore s = seeded();
      expect(
        () => s.requestLink(
          pedB,
          childId: kChild,
          professionalId: pedB.id,
          professionalName: pedB.name,
          specialty: CareSpecialty.pediatria,
          clinicId: 'clinica-a',
          clinicName: 'Clínica A',
          reason: 'Fictício',
        ),
        throwsA(isA<CareAccessDenied>()),
      );
    });
  });

  group('Informação reservada', () {
    test('reservado só para a autora; equipe vê só o resumo compartilhado', () {
      final CareStore s = seeded();
      final CareRecord r = s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.sessao,
        title: 'Sessão 1',
        body: kSecret,
        visibility: CareVisibility.reservado,
        teamSummary: 'Acompanhamento semanal, sem sinais de alerta.',
      );
      expect(s.recordsFor(psi, kChild).map((CareRecord x) => x.body), contains(kSecret));
      for (final CareActor other in <CareActor>[ped, fis]) {
        expect(
          s.recordsFor(other, kChild).map((CareRecord x) => x.body),
          isNot(contains(kSecret)),
        );
        expect(() => s.open(other, r.id), throwsA(isA<CareAccessDenied>()));
        final CareSharedView view = s.sharedView(other, kChild);
        expect(view.items.map((CareSharedItem i) => i.text), isNot(contains(kSecret)));
        expect(
          view.items.where((CareSharedItem i) => i.fromReserved).single.text,
          'Acompanhamento semanal, sem sinais de alerta.',
        );
      }
      expect(s.familyView(family, kChild).released, isEmpty);
      final List<CareAuditEntry> denied = s.audit
          .where((CareAuditEntry e) => !e.allowed && e.action == 'abrir registro')
          .toList();
      expect(denied.map((CareAuditEntry e) => e.actorId), <String>['ped', 'fis']);
    });

    test('anexo de registro reservado segue a mesma regra', () {
      final CareStore s = seeded();
      final CareRecord r = s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.avaliacao,
        title: 'Avaliação',
        body: kSecret,
        visibility: CareVisibility.reservado,
      );
      s.attach(psi, r, 'desenho.png');
      expect(s.attachmentsFor(psi, r), hasLength(1));
      expect(() => s.attachmentsFor(ped, r), throwsA(isA<CareAccessDenied>()));
      expect(() => s.attachmentsFor(family, r), throwsA(isA<CareAccessDenied>()));
      expect(() => s.attach(fis, r, 'x.pdf'), throwsA(isA<CareAccessDenied>()));
    });

    test('fisioterapia e pediatria não criam registro reservado', () {
      final CareStore s = seeded();
      for (final CareActor a in <CareActor>[fis, ped]) {
        expect(
          () => s.addRecord(
            a,
            childId: kChild,
            kind: CareRecordKind.evolucao,
            title: 'x',
            body: 'y',
            visibility: CareVisibility.reservado,
          ),
          throwsA(isA<CareAccessDenied>()),
        );
      }
    });
  });

  group('Registros compatíveis com a especialidade', () {
    test('cada área só cria os próprios tipos de registro', () {
      final CareStore s = seeded();
      expect(
        () => s.addRecord(fis, childId: kChild, kind: CareRecordKind.sessao, title: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );
      expect(
        () => s.addRecord(ped, childId: kChild, kind: CareRecordKind.planoSessoes, title: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );
      expect(
        () => s.addRecord(psi, childId: kChild, kind: CareRecordKind.medida, title: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );
      final CareRecord m = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.medida,
        title: 'Apoio num pé só',
        body: 'Sessão 5',
        measure: '4 s',
      );
      expect(m.specialty, CareSpecialty.fisioterapia);
      expect(m.origin, 'Fisioterapia - Fisioterapeuta Exemplo');
    });

    test('só orientação e atividade para casa vão para a família', () {
      final CareStore s = seeded();
      expect(
        () => s.addRecord(
          fis,
          childId: kChild,
          kind: CareRecordKind.evolucao,
          title: 'x',
          body: 'y',
          visibility: CareVisibility.familia,
        ),
        throwsA(isA<CareAccessDenied>()),
      );
    });

    test('evolução individual: só a autora altera, e a versão anterior fica', () {
      final CareStore s = seeded();
      final CareRecord r = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.evolucao,
        title: 'Sessão 4',
        body: 'Texto inicial',
      );
      expect(
        () => s.edit(ped, r, body: 'outra coisa', note: 'tentativa'),
        throwsA(isA<CareAccessDenied>()),
      );
      s.edit(fis, r, body: 'Texto corrigido', note: 'Correção');
      expect(r.body, 'Texto corrigido');
      expect(r.revisions.single.previousBody, 'Texto inicial');
      expect(r.revisions.single.actorName, fis.name);
    });
  });

  group('Plano compartilhado', () {
    test('equipe edita, cada objetivo tem a origem e o histórico guarda versões', () {
      final CareStore s = seeded();
      s.updatePlan(ped, kChild, text: 'Plano 1', newGoal: 'Crescimento');
      s.updatePlan(psi, kChild, text: 'Plano 2', newGoal: 'Sono');
      final CarePlan plan = s.sharedView(fis, kChild).plan!;
      expect(plan.text, 'Plano 2');
      expect(plan.updatedBy, psi.name);
      expect(plan.updatedBySpecialty, CareSpecialty.psicologia);
      expect(plan.history.single.text, 'Plano 1');
      expect(
        plan.goals.map((CarePlanGoal g) => '${g.specialty.area}:${g.text}'),
        <String>['Pediatria:Crescimento', 'Psicologia:Sono'],
      );
      expect(() => s.updatePlan(psi2, kChild, text: 'x'), throwsA(isA<CareAccessDenied>()));
    });
  });

  group('Área da família', () {
    test('orientação liberada aparece; não liberada e reservada não', () {
      final CareStore s = seeded();
      final CareRecord home = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.atividadeCasa,
        title: 'Flamingo',
        body: 'Exercício fictício',
      );
      s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.sessao,
        title: 'Sessão',
        body: kSecret,
        visibility: CareVisibility.reservado,
      );
      expect(s.familyView(family, kChild).released, isEmpty);
      expect(() => s.release(ped, home), throwsA(isA<CareAccessDenied>()));
      s.release(fis, home);
      final CareFamilyView v = s.familyView(family, kChild);
      expect(v.released.map((CareRecord r) => r.title), <String>['Flamingo']);
      expect(v.released.map((CareRecord r) => r.body), isNot(contains(kSecret)));
      s.withdraw(fis, home, 'Revisar o exercício');
      expect(s.familyView(family, kChild).released, isEmpty);
    });
  });

  group('Documentos por especialidade', () {
    test('psicologia não prepara receita; documento só emite revisado', () {
      final CareStore s = seeded();
      expect(
        () => s.createDocument(
          psi,
          childId: kChild,
          kind: CareDocKind.receituario,
          title: 'x',
          body: 'y',
          registry: 'CRP',
        ),
        throwsA(isA<CareAccessDenied>()),
      );
      expect(
        () => s.createDocument(
          fis,
          childId: kChild,
          kind: CareDocKind.atestadoMedico,
          title: 'x',
          body: 'y',
          registry: 'CREFITO',
        ),
        throwsA(isA<CareAccessDenied>()),
      );
      final CareDocument d = s.createDocument(
        psi,
        childId: kChild,
        kind: CareDocKind.relatorioPsicologico,
        title: 'Relatório',
        body: 'Texto fictício',
        registry: 'CRP',
      );
      expect(s.documentsFor(ped, kChild), isEmpty, reason: 'rascunho é da autora');
      expect(() => s.issueDocument(psi, d), throwsA(isA<CareAccessDenied>()));
      s.reviewDocument(psi, d);
      s.issueDocument(psi, d);
      expect(s.documentsFor(ped, kChild), contains(d));
      expect(s.documentsFor(family, kChild), isEmpty);
      s.releaseDocument(psi, d);
      expect(s.documentsFor(family, kChild), contains(d));
      expect(() => s.reviewDocument(fis, d), throwsA(isA<CareAccessDenied>()));
    });

    test('modelos próprios: cada um vê os seus e só do tipo permitido', () {
      final CareStore s = seeded();
      expect(
        () => s.saveTemplate(psi, kind: CareDocKind.receituario, title: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );
      final CareTemplate t = s.saveTemplate(
        psi,
        kind: CareDocKind.declaracaoComparecimento,
        title: 'Comparecimento',
        body: '{crianca} compareceu em {data}. {profissional} - {registro}',
      );
      expect(s.templatesOf(psi), <CareTemplate>[t]);
      expect(s.templatesOf(fis), isEmpty);
      expect(
        CareStore.applyTemplate(
          t,
          childName: 'Luna',
          guardianName: 'R',
          professionalName: 'Psi',
          registry: 'CRP 0',
          date: '02/10/2026',
        ),
        'Luna compareceu em 02/10/2026. Psi - CRP 0',
      );
    });
  });

  group('Comunicação da equipe', () {
    test('encaminhamento interno, parecer e resposta com autor, data e histórico', () {
      final CareStore s = seeded();
      final CareMessage p = s.send(
        fis,
        childId: kChild,
        kind: CareMessageKind.parecer,
        subject: 'Calçados',
        body: 'Há restrição?',
        toSpecialty: CareSpecialty.pediatria,
      );
      s.send(
        ped,
        childId: kChild,
        kind: CareMessageKind.mensagem,
        subject: 'Re: Calçados',
        body: 'Sem restrição.',
        replyTo: p.id,
      );
      expect(p.status, CareMessageStatus.respondido);
      expect(
        p.events.map((CareMessageEvent e) => '${e.actorName}:${e.status.name}'),
        <String>['${fis.name}:aberto', '${ped.name}:respondido'],
      );
      expect(s.messagesFor(psi, kChild), hasLength(2));
      expect(() => s.messagesFor(family, kChild), throwsA(isA<CareAccessDenied>()));
      expect(
        () => s.send(ped, childId: kChild, kind: CareMessageKind.encaminhamento, subject: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );
    });

    test('encaminhamento aceito vira vínculo pendente até a família autorizar', () {
      final CareStore s = seeded();
      final CareMessage ref = s.send(
        ped,
        childId: kChild,
        kind: CareMessageKind.encaminhamento,
        subject: 'Segunda opinião em psicologia',
        body: 'Fictício',
        toSpecialty: CareSpecialty.psicologia,
      );
      expect(s.referralsFor(psi2), <CareMessage>[ref]);
      expect(s.referralsFor(fis), isEmpty);
      expect(
        () => s.acceptReferral(fis, ref, clinicName: 'Clínica A'),
        throwsA(isA<CareAccessDenied>()),
      );
      final CareLink l = s.acceptReferral(psi2, ref, clinicName: 'Clínica A');
      expect(ref.status, CareMessageStatus.aceito);
      expect(l.pending, isTrue);
      expect(s.canOpenChild(psi2, kChild), isFalse);
      s.authorize(family, l);
      expect(s.canOpenChild(psi2, kChild), isTrue);
    });
  });

  group('Troca de profissional e de clínica', () {
    test('psicóloga sai: perde a equipe, mantém só os próprios registros', () {
      final CareStore s = seeded();
      s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.sessao,
        title: 'Sessão',
        body: kSecret,
        visibility: CareVisibility.reservado,
      );
      final CareRecord team = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.evolucao,
        title: 'Evolução da fisio',
        body: 'Fictício',
      );
      final CareLink old = s.linkOf(psi, kChild)!;
      s.endLink(manager, old, 'Troca de profissional');
      expect(() => s.sharedView(psi, kChild), throwsA(isA<CareAccessDenied>()));
      final List<CareRecord> mine = s.recordsFor(psi, kChild);
      expect(mine.map((CareRecord r) => r.body), <String>[kSecret]);
      expect(mine, isNot(contains(team)));
      expect(
        () => s.addRecord(psi, childId: kChild, kind: CareRecordKind.sessao, title: 'x', body: 'y'),
        throwsA(isA<CareAccessDenied>()),
      );

      final CareLink next = s.requestLink(
        manager,
        childId: kChild,
        professionalId: psi2.id,
        professionalName: psi2.name,
        specialty: CareSpecialty.psicologia,
        clinicId: 'clinica-a',
        clinicName: 'Clínica A',
        reason: 'Assume a psicologia',
      );
      s.authorize(family, next);
      final List<CareRecord> seen = s.recordsFor(psi2, kChild);
      expect(seen, contains(team));
      expect(seen.map((CareRecord r) => r.body), isNot(contains(kSecret)));
    });

    test('troca de clínica: nova equipe não vê a anterior; família mantém o liberado', () {
      final CareStore s = seeded();
      final CareRecord home = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.atividadeCasa,
        title: 'Flamingo',
        body: 'Fictício',
        visibility: CareVisibility.familia,
      );
      s.addRecord(
        ped,
        childId: kChild,
        kind: CareRecordKind.resumoEquipe,
        title: 'Resumo',
        body: 'Fictício',
      );
      final List<CareLink> ended = s.transferClinic(
        family,
        kChild,
        toClinicName: 'Clínica B',
      );
      expect(ended, hasLength(3));
      expect(s.linkOf(ped, kChild), isNull);
      final CareLink b = s.requestLink(
        pedB,
        childId: kChild,
        professionalId: pedB.id,
        professionalName: pedB.name,
        specialty: CareSpecialty.pediatria,
        clinicId: 'clinica-b',
        clinicName: 'Clínica B',
        reason: 'Novo pediatra',
      );
      expect(s.canOpenChild(pedB, kChild), isFalse);
      s.authorize(family, b);
      expect(s.recordsFor(pedB, kChild), isEmpty);
      expect(s.sharedView(pedB, kChild).items, isEmpty);
      expect(s.sharedView(pedB, kChild).plan, isNull);
      expect(s.familyView(family, kChild).released, <CareRecord>[home]);
      expect(() => s.transferClinic(ped, kChild, toClinicName: 'x'), throwsA(isA<CareAccessDenied>()));
    });
  });

  group('IA: rascunho identificado, sem reservado e com revisão', () {
    test('rascunho não inclui reservado, nem para a autora, e não se salva sozinho', () {
      final CareStore s = seeded();
      s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.sessao,
        title: 'Sessão',
        body: kSecret,
        visibility: CareVisibility.reservado,
        teamSummary: 'Resumo compartilhado fictício',
      );
      final int before = s.records.length;
      final CareAiDraft d = CareAi.teamSummary(s, psi, kChild);
      expect(d.text, isNot(contains(kSecret)));
      expect(d.text, contains('Resumo compartilhado fictício'));
      expect(CareAiDraft.label, contains('Rascunho'));
      expect(s.records.length, before, reason: 'gerar o rascunho não salva nada');
      expect(
        () => CareAi.saveReviewed(s, psi, d, reviewedText: d.text, reviewed: false),
        throwsA(isA<CareAccessDenied>()),
      );
      expect(
        () => CareAi.saveReviewed(s, ped, d, reviewedText: d.text, reviewed: true),
        throwsA(isA<CareAccessDenied>()),
      );
      final CareRecord saved = CareAi.saveReviewed(
        s,
        psi,
        d,
        reviewedText: 'Texto revisado pela psicóloga',
        reviewed: true,
      );
      expect(saved.fromAi, isTrue);
      expect(saved.reviewedBy, psi.name);
      expect(saved.visibility, CareVisibility.equipe);
      expect(
        () => s.addRecord(
          psi,
          childId: kChild,
          kind: CareRecordKind.resumoEquipe,
          title: 'x',
          body: 'y',
          fromAi: true,
        ),
        throwsA(isA<CareAccessDenied>()),
      );
    });

    test('quem não tem vínculo não pede rascunho', () {
      final CareStore s = seeded();
      expect(() => CareAi.teamSummary(s, psi2, kChild), throwsA(isA<CareAccessDenied>()));
    });
  });

  group('Trilha de acessos', () {
    test('família e gestão veem a trilha; profissional não', () {
      final CareStore s = seeded();
      s.recordsFor(ped, kChild);
      expect(() => s.recordsFor(psi2, kChild), throwsA(isA<CareAccessDenied>()));
      final List<CareAuditEntry> all = s.auditFor(family, kChild);
      expect(all.any((CareAuditEntry e) => e.actorName == ped.name && e.allowed), isTrue);
      expect(all.any((CareAuditEntry e) => e.actorName == psi2.name && !e.allowed), isTrue);
      expect(s.auditFor(manager, kChild), isNotEmpty);
      expect(() => s.auditFor(psi, kChild), throwsA(isA<CareAccessDenied>()));
    });

    test('reabrir a mesma tela não duplica a linha', () {
      final CareStore s = seeded();
      final int before = s.audit.length;
      s.recordsFor(ped, kChild);
      s.recordsFor(ped, kChild);
      expect(s.audit.length, before + 1);
    });
  });
}
