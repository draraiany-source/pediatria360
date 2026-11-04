import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/care/care_ai.dart';
import 'package:pediatria360/shared/care/care_model.dart';
import 'package:pediatria360/shared/care/care_policy.dart';
import 'package:pediatria360/shared/care/care_store.dart';

const String kChild = 'luna';
const String kFull = 'EVOLUCAO-COMPLETA-FICTICIA';
const String kPrivate = 'ANOTACAO-PRIVADA-FICTICIA';
const String kTranscript = 'TRANSCRICAO-FICTICIA';
const String kShared = 'Ansiedade de separação na hora de dormir (fictício).';

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

DateTime clockNow = DateTime(2026, 10, 2, 10);

/// Pediatra, psicóloga e fisioterapeuta com vínculo ativo com a Luna.
CareStore seeded() {
  clockNow = DateTime(2026, 10, 2, 10);
  final CareStore s = CareStore(clock: () => clockNow);
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

/// Sessão privada da psicóloga: texto completo, síntese clínica, anotação
/// privada, transcrição e um anexo.
CareRecord privateSession(CareStore s) {
  final CareRecord r = s.addRecord(
    psi,
    childId: kChild,
    kind: CareRecordKind.sessao,
    title: 'Sessão 1',
    body: kFull,
    sections: <CareSectionInput>[
      (kind: CareSectionKind.clinica, label: 'Síntese clínica', text: kShared),
      (
        kind: CareSectionKind.anotacaoPrivada,
        label: 'Anotação privada',
        text: kPrivate,
      ),
      (kind: CareSectionKind.transcricao, label: 'Transcrição', text: kTranscript),
    ],
  );
  s.attach(psi, r, 'desenho-sessao-1.png');
  return r;
}

String sectionId(CareRecord r, CareSectionKind kind) =>
    r.sections.firstWhere((CareSection x) => x.kind == kind).id;

/// Resumo só com a síntese clínica, só para a pediatra.
CareSummary shareWithPediatrician(CareStore s, CareRecord r) {
  final CareSummaryDraft d = s.startSummary(psi, r)
    ..itemIds.add(sectionId(r, CareSectionKind.clinica))
    ..audience = CareAudience.selecionados
    ..recipientIds.add(ped.id);
  return s.publishSummary(psi, r, d, confirmed: true);
}

Iterable<String> texts(CareSummary s) => <String>[
  for (final CareShareItem i in s.items) i.text,
  s.note,
];

Matcher get denied => throwsA(isA<CareAccessDenied>());

void main() {
  group('Cenário: psicóloga, pediatra, fisioterapeuta e família', () {
    test('psicóloga registra sessão privada e compartilha só um resumo com a '
        'pediatra', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      expect(r.visibility, CareVisibility.privado);
      expect(s.summaries, isEmpty, reason: 'nada é compartilhado ao salvar');

      final CareSummary sum = shareWithPediatrician(s, r);
      expect(sum.items.map((CareShareItem i) => i.text), <String>[kShared]);
      expect(sum.recipientIds, <String>['ped']);
      expect(sum.attachmentIds, isEmpty);
      for (final String t in texts(sum)) {
        expect(t, isNot(contains(kFull)));
        expect(t, isNot(contains(kPrivate)));
        expect(t, isNot(contains(kTranscript)));
      }
    });

    test('pediatra lê o resumo, mas não a evolução completa nem os anexos', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummary sum = shareWithPediatrician(s, r);

      final List<CareSummary> forPed = s.summariesFor(ped, kChild);
      expect(forPed, <CareSummary>[sum]);
      expect(forPed.single.items.single.text, kShared);
      expect(s.summaryAttachments(ped, sum), isEmpty);

      expect(s.recordsFor(ped, kChild), isEmpty);
      expect(() => s.open(ped, r.id), denied);
      expect(() => s.sectionsFor(ped, r), denied);
      expect(() => s.attachmentsFor(ped, r), denied);
      expect(
        s.audit.where(
          (CareAuditEntry e) =>
              e.actorId == 'ped' &&
              !e.allowed &&
              e.action == 'abrir registro completo',
        ),
        hasLength(2),
      );
    });

    test('fisioterapeuta vê apenas o que foi compartilhado com ela', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummary toPed = shareWithPediatrician(s, r);
      expect(s.summariesFor(fis, kChild), isEmpty);
      expect(() => s.openSummary(fis, toPed.id), denied);
      expect(() => s.summaryAttachments(fis, toPed), denied);
      expect(s.recordsFor(fis, kChild), isEmpty);
      expect(() => s.open(fis, r.id), denied);

      // A psicóloga passa a incluir a fisioterapeuta (nova versão).
      final CareSummaryDraft d = s.startSummary(psi, r);
      expect(d.recipientIds, <String>{'ped'});
      d.recipientIds.add(fis.id);
      s.publishSummary(psi, r, d, confirmed: true);
      final CareSummary forFis = s.summariesFor(fis, kChild).single;
      expect(forFis.version, 2);
      expect(forFis.items.single.text, kShared);
      expect(s.recordsFor(fis, kChild), isEmpty);
    });

    test('família vê somente as orientações liberadas para a área dela', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      shareWithPediatrician(s, r);
      final CareRecord orientation = s.addRecord(
        psi,
        childId: kChild,
        kind: CareRecordKind.orientacao,
        title: 'Rotina do sono',
        body: 'Orientação fictícia para casa.',
      );
      expect(s.familyView(family, kChild).released, isEmpty);
      s.release(psi, orientation);

      final CareFamilyView v = s.familyView(family, kChild);
      expect(v.released, <CareRecord>[orientation]);
      expect(v.documents, isEmpty);
      expect(() => s.summariesFor(family, kChild), denied);
      expect(() => s.open(family, r.id), denied);
      expect(() => s.attachmentsFor(family, r), denied);
      expect(() => s.planFor(family, kChild), denied);
      expect(() => s.familyView(otherFamily, kChild), denied);
    });

    test('retirada do acesso: o resumo some para a pediatra e o histórico '
        'fica com a autora', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummary sum = shareWithPediatrician(s, r);
      s.summariesFor(ped, kChild);

      clockNow = clockNow.add(const Duration(hours: 1));
      expect(() => s.endSummary(ped, sum, 'x'), denied);
      s.endSummary(psi, sum, 'Conduta revista');
      expect(sum.status, CareSummaryStatus.encerrado);
      expect(s.summariesFor(ped, kChild), isEmpty);
      expect(() => s.openSummary(ped, sum.id), denied);
      expect(() => s.summaryAttachments(ped, sum), denied);

      expect(
        sum.versions.map((CareSummaryVersion v) => '${v.version}:${v.status.name}'),
        <String>['1:publicado', '2:encerrado'],
      );
      expect(sum.versions.last.reason, 'Conduta revista');
      expect(s.summariesFor(psi, kChild), <CareSummary>[sum]);
      expect(s.accessesOf(psi, sum).single.actorName, ped.name);
      expect(() => s.accessesOf(ped, sum), denied);

      final List<String> trail = s
          .auditFor(family, kChild)
          .map((CareAuditEntry e) => '${e.actorName}|${e.action}')
          .toList();
      expect(
        trail,
        contains('${psi.name}|compartilhou resumo (versão 1) com '
            '${ped.name} (Pediatria)'),
      );
      expect(trail, contains('${ped.name}|acessou resumo'));
      expect(
        trail.any(
          (String t) => t.startsWith('${psi.name}|encerrou acesso ao resumo'),
        ),
        isTrue,
      );
    });

    test('vínculo encerrado também retira o resumo do destinatário', () {
      final CareStore s = seeded();
      final CareSummary sum = shareWithPediatrician(s, privateSession(s));
      s.endLink(manager, s.linkOf(ped, kChild)!, 'Troca de pediatra');
      expect(() => s.summariesFor(ped, kChild), denied);
      expect(() => s.openSummary(ped, sum.id), denied);
    });
  });

  group('Resumo: escolhas, prévia e confirmação', () {
    test('rascunho começa vazio: nenhuma informação, anexo ou destinatário', () {
      final CareStore s = seeded();
      final CareSummaryDraft d = s.startSummary(psi, privateSession(s));
      expect(d.itemIds, isEmpty);
      expect(d.attachmentIds, isEmpty);
      expect(d.recipientIds, isEmpty);
      expect(d.audience, isNull);
      expect(d.note, isEmpty);
    });

    test('anotação privada, transcrição e conversa não entram no resumo', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      expect(
        r.shareableItems.map((CareShareItem i) => i.text),
        <String>[kFull, kShared],
      );
      for (final CareSectionKind k in <CareSectionKind>[
        CareSectionKind.anotacaoPrivada,
        CareSectionKind.transcricao,
      ]) {
        final CareSummaryDraft d = s.startSummary(psi, r)
          ..itemIds.add(sectionId(r, k))
          ..audience = CareAudience.equipe;
        expect(() => s.previewSummary(psi, r, d), denied, reason: k.name);
      }
    });

    test('sem informação ou sem destinatário a prévia é recusada', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummaryDraft d = s.startSummary(psi, r)
        ..audience = CareAudience.equipe;
      expect(() => s.previewSummary(psi, r, d), denied);
      d
        ..itemIds.add(CareRecord.bodyItemId)
        ..audience = null;
      expect(() => s.previewSummary(psi, r, d), denied);
      d.audience = CareAudience.selecionados;
      expect(() => s.previewSummary(psi, r, d), denied);
    });

    test('só profissionais da equipe ativa recebem; família e outra clínica '
        'não', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      for (final String id in <String>['psi2', 'pedB', 'familia', 'psi']) {
        final CareSummaryDraft d = s.startSummary(psi, r)
          ..itemIds.add(CareRecord.bodyItemId)
          ..audience = CareAudience.selecionados
          ..recipientIds.add(id);
        expect(() => s.previewSummary(psi, r, d), denied, reason: id);
      }
    });

    test('a prévia mostra exatamente o que vai; sem confirmação nada é '
        'publicado', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareAttachment file = s.attachments.single;
      final CareSummaryDraft d = s.startSummary(psi, r)
        ..itemIds.add(sectionId(r, CareSectionKind.clinica))
        ..attachmentIds.add(file.id)
        ..audience = CareAudience.equipe
        ..note = 'Observação fictícia';
      final CareSummaryPreview p = s.previewSummary(psi, r, d);
      expect(p.items.map((CareShareItem i) => i.text), <String>[kShared]);
      expect(p.attachments, <CareAttachment>[file]);
      expect(
        p.recipients.map((CareLink l) => l.professionalId),
        unorderedEquals(<String>['ped', 'fis']),
      );
      expect(p.version, 1);
      expect(() => s.publishSummary(psi, r, d, confirmed: false), denied);
      expect(s.summaries, isEmpty);
      s.publishSummary(psi, r, d, confirmed: true);
      expect(s.summaryAttachments(fis, s.summaries.single), <CareAttachment>[file]);
      expect(() => s.attachmentsFor(fis, r), denied);
    });

    test('equipe autorizada é a do momento da publicação', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummaryDraft d = s.startSummary(psi, r)
        ..itemIds.add(sectionId(r, CareSectionKind.clinica))
        ..audience = CareAudience.equipe;
      final CareSummary sum = s.publishSummary(psi, r, d, confirmed: true);
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
      s.authorize(family, l);
      expect(s.summariesFor(psi2, kChild), isEmpty);
      expect(sum.recipientIds, unorderedEquals(<String>['ped', 'fis']));
    });

    test('só a autora prepara, atualiza ou encerra o resumo', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      expect(() => s.startSummary(ped, r), denied);
      final CareSummary sum = shareWithPediatrician(s, r);
      expect(() => s.endSummary(fis, sum, 'x'), denied);
    });

    test('atualizar parte do que está publicado e guarda a versão anterior', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      shareWithPediatrician(s, r);
      final CareSummaryDraft d = s.startSummary(psi, r);
      expect(d.itemIds, <String>{sectionId(r, CareSectionKind.clinica)});
      d.note = 'Nova orientação fictícia';
      final CareSummary sum = s.publishSummary(psi, r, d, confirmed: true);
      expect(sum.version, 2);
      expect(sum.versions.first.note, isEmpty);
      expect(sum.versions.last.note, 'Nova orientação fictícia');
    });
  });

  group('Acesso concedido ao registro completo', () {
    test('exige justificativa, mostra o registro sem as partes privadas e '
        'pode ser retirado', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      expect(
        () => s.grantAccess(psi, r, granteeId: ped.id, justification: 'curta'),
        denied,
      );
      expect(
        () => s.grantAccess(
          ped,
          r,
          granteeId: fis.id,
          justification: 'Justificativa suficiente e fictícia',
        ),
        denied,
      );
      expect(
        () => s.grantAccess(
          psi,
          r,
          granteeId: psi2.id,
          justification: 'Justificativa suficiente e fictícia',
        ),
        denied,
        reason: 'sem vínculo',
      );
      final CareRecordGrant g = s.grantAccess(
        psi,
        r,
        granteeId: ped.id,
        justification: 'Avaliar interação com a medicação (fictício)',
      );
      expect(s.open(ped, r.id).body, kFull);
      final List<CareSection> seen = s.sectionsFor(ped, r);
      expect(seen.map((CareSection x) => x.text), <String>[kShared]);
      expect(s.attachmentsFor(ped, r), hasLength(1));
      expect(() => s.open(fis, r.id), denied);
      expect(() => s.grantsFor(ped, r), denied);

      s.revokeGrant(psi, g, 'Avaliação concluída');
      expect(() => s.open(ped, r.id), denied);
      expect(() => s.attachmentsFor(ped, r), denied);
      expect(s.grantsFor(psi, r).single.revokeReason, 'Avaliação concluída');
      expect(
        s.audit.where(
          (CareAuditEntry e) => e.action.startsWith('concedeu acesso') ||
              e.action.startsWith('retirou acesso'),
        ),
        hasLength(2),
      );
    });

    test('concessão não vale depois do fim do vínculo de quem recebeu', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      s.grantAccess(
        psi,
        r,
        granteeId: fis.id,
        justification: 'Planejar exercícios em conjunto (fictício)',
      );
      expect(s.open(fis, r.id).id, r.id);
      s.endLink(manager, s.linkOf(fis, kChild)!, 'Alta da fisioterapia');
      expect(() => s.open(fis, r.id), denied);
    });
  });

  group('Matriz de permissões por especialidade', () {
    test('só a pediatria prescreve, pede exames e emite atestado médico', () {
      for (final CareSpecialty s in CareSpecialty.values) {
        final bool isPed = s == CareSpecialty.pediatria;
        expect(CarePolicy.allows(s, CareAction.prescrever), isPed, reason: s.area);
        expect(CarePolicy.allows(s, CareAction.solicitarExames), isPed);
        expect(CarePolicy.allows(s, CareAction.atestadoMedico), isPed);
        expect(CarePolicy.docsFor(s).contains(CareDocKind.receituario), isPed);
        expect(CarePolicy.docsFor(s).contains(CareDocKind.atestadoMedico), isPed);
      }
    });

    test('toda especialidade guarda registro privado e compartilha por '
        'escolha', () {
      for (final CareSpecialty s in CareSpecialty.values) {
        expect(CarePolicy.allows(s, CareAction.compartilharResumo), isTrue);
        expect(CarePolicy.allows(s, CareAction.concederAcesso), isTrue);
      }
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

  group('Registro de cada profissional', () {
    test('o padrão é privado: a equipe não lê registros de outros', () {
      final CareStore s = seeded();
      final CareRecord evo = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.evolucao,
        title: 'Sessão 4',
        body: 'Evolução fictícia',
      );
      expect(evo.visibility, CareVisibility.privado);
      for (final CareActor other in <CareActor>[ped, psi]) {
        expect(s.recordsFor(other, kChild), isEmpty, reason: other.id);
        expect(() => s.open(other, evo.id), denied);
      }
      expect(s.recordsFor(fis, kChild), <CareRecord>[evo]);
    });

    test('cada área só cria os próprios tipos de registro', () {
      final CareStore s = seeded();
      expect(
        () => s.addRecord(fis, childId: kChild, kind: CareRecordKind.sessao, title: 'x', body: 'y'),
        denied,
      );
      expect(
        () => s.addRecord(ped, childId: kChild, kind: CareRecordKind.planoSessoes, title: 'x', body: 'y'),
        denied,
      );
      final CareRecord m = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.medida,
        title: 'Apoio num pé só',
        body: 'Sessão 5',
        measure: '4 s',
      );
      expect(m.origin, 'Fisioterapia - Fisioterapeuta Exemplo');
      expect(m.shareableItems.map((CareShareItem i) => i.id), <String>[
        CareRecord.bodyItemId,
        CareRecord.measureItemId,
      ]);
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
        denied,
      );
    });

    test('só o autor altera, e a versão anterior fica', () {
      final CareStore s = seeded();
      final CareRecord r = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.evolucao,
        title: 'Sessão 4',
        body: 'Texto inicial',
      );
      expect(() => s.edit(ped, r, body: 'outra coisa', note: 'tentativa'), denied);
      s.edit(fis, r, body: 'Texto corrigido', note: 'Correção');
      expect(r.revisions.single.previousBody, 'Texto inicial');
    });

    test('retirar da família devolve ao autor, não à equipe', () {
      final CareStore s = seeded();
      final CareRecord home = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.atividadeCasa,
        title: 'Flamingo',
        body: 'Exercício fictício',
      );
      expect(() => s.release(ped, home), denied);
      s.release(fis, home);
      expect(s.familyView(family, kChild).released, <CareRecord>[home]);
      s.withdraw(fis, home, 'Revisar o exercício');
      expect(home.visibility, CareVisibility.privado);
      expect(s.familyView(family, kChild).released, isEmpty);
      expect(s.recordsFor(ped, kChild), isEmpty);
    });
  });

  group('Vínculo real, não pertencer à clínica', () {
    test('profissional da mesma clínica sem vínculo não abre nada', () {
      final CareStore s = seeded();
      expect(s.canOpenChild(psi2, kChild), isFalse);
      expect(() => s.recordsFor(psi2, kChild), denied);
      expect(() => s.summariesFor(psi2, kChild), denied);
      expect(() => s.planFor(psi2, kChild), denied);
      expect(() => s.messagesFor(psi2, kChild), denied);
    });

    test('gestão organiza a equipe, mas não lê registros nem resumos', () {
      final CareStore s = seeded();
      shareWithPediatrician(s, privateSession(s));
      expect(s.team(manager, kChild), hasLength(3));
      expect(() => s.recordsFor(manager, kChild), denied);
      expect(() => s.summariesFor(manager, kChild), denied);
      expect(() => s.planFor(manager, kChild), denied);
    });

    test('recepção e outra família não abrem a ficha', () {
      final CareStore s = seeded();
      expect(() => s.recordsFor(reception, kChild), denied);
      expect(() => s.familyView(otherFamily, kChild), denied);
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
      expect(s.canOpenChild(psi2, kChild), isFalse);
      expect(() => s.authorize(psi2, l), denied);
      expect(() => s.authorize(manager, l), denied);
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
        denied,
      );
    });
  });

  group('Plano terapêutico conjunto', () {
    test('objetivo com responsável, ação, prazo e reavaliação', () {
      final CareStore s = seeded();
      final CarePlanGoal g = s.addGoal(
        ped,
        kChild,
        objective: 'Dormir no próprio quarto',
        responsibleId: psi.id,
        dueDate: DateTime(2026, 12, 1),
        reassessAt: DateTime(2026, 11, 1),
        firstAction: 'Sessões semanais (fictício)',
      );
      expect(g.responsibleName, psi.name);
      expect(g.responsibleSpecialty, CareSpecialty.psicologia);
      expect(g.actions.single.text, 'Sessões semanais (fictício)');

      s.contribute(
        fis,
        g,
        kind: CareContributionKind.informacao,
        text: 'Cansaço após as sessões de quinta (fictício)',
      );
      expect(() => s.reassess(ped, g, status: CareGoalStatus.atingido, note: 'x', nextReassessAt: DateTime(2026, 12, 1)), denied);
      s.reassess(
        psi,
        g,
        status: CareGoalStatus.revisar,
        note: 'Ajustar a rotina (fictício)',
        nextReassessAt: DateTime(2026, 11, 15),
      );
      final CarePlan plan = s.planFor(fis, kChild)!;
      expect(plan.goals.single.status, CareGoalStatus.revisar);
      expect(plan.goals.single.reassessAt, DateTime(2026, 11, 15));
      expect(plan.goals.single.shared.single.authorName, fis.name);
      expect(plan.history, hasLength(3));
    });

    test('contribuição não expõe o registro completo', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CarePlanGoal g = s.addGoal(
        psi,
        kChild,
        objective: 'Sono',
        responsibleId: psi.id,
        dueDate: DateTime(2026, 12, 1),
        reassessAt: DateTime(2026, 11, 1),
      );
      s.contribute(psi, g, kind: CareContributionKind.informacao, text: kShared);
      final CarePlan plan = s.planFor(ped, kChild)!;
      final String all = plan.goals
          .expand((CarePlanGoal x) => x.contributions)
          .map((CarePlanContribution c) => c.text)
          .join(' ');
      expect(all, isNot(contains(kFull)));
      expect(all, isNot(contains(kPrivate)));
      expect(() => s.open(ped, r.id), denied);
    });

    test('responsável precisa estar na equipe; sem vínculo não contribui', () {
      final CareStore s = seeded();
      expect(
        () => s.addGoal(
          ped,
          kChild,
          objective: 'x',
          responsibleId: psi2.id,
          dueDate: DateTime(2026, 12, 1),
          reassessAt: DateTime(2026, 11, 1),
        ),
        denied,
      );
      final CarePlanGoal g = s.addGoal(
        ped,
        kChild,
        objective: 'Crescimento',
        responsibleId: ped.id,
        dueDate: DateTime(2026, 12, 1),
        reassessAt: DateTime(2026, 11, 1),
      );
      expect(
        () => s.contribute(psi2, g, kind: CareContributionKind.acao, text: 'x'),
        denied,
      );
    });
  });

  group('Documentos', () {
    test('ficam com a autora; a família vê só os liberados', () {
      final CareStore s = seeded();
      expect(
        () => s.createDocument(psi, childId: kChild, kind: CareDocKind.receituario, title: 'x', body: 'y', registry: 'CRP'),
        denied,
      );
      final CareDocument d = s.createDocument(
        psi,
        childId: kChild,
        kind: CareDocKind.relatorioPsicologico,
        title: 'Relatório',
        body: 'Texto fictício',
        registry: 'CRP',
      );
      expect(() => s.issueDocument(psi, d), denied);
      s.reviewDocument(psi, d);
      s.issueDocument(psi, d);
      expect(s.documentsFor(ped, kChild), isEmpty, reason: 'emitido não vai à equipe');
      expect(s.documentsFor(family, kChild), isEmpty);
      s.releaseDocument(psi, d);
      expect(s.documentsFor(family, kChild), contains(d));
      expect(s.documentsFor(ped, kChild), isEmpty);
      expect(() => s.reviewDocument(fis, d), denied);
    });

    test('modelos próprios: cada um vê os seus e só do tipo permitido', () {
      final CareStore s = seeded();
      expect(
        () => s.saveTemplate(psi, kind: CareDocKind.receituario, title: 'x', body: 'y'),
        denied,
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
    test('parecer e resposta com autor, data e histórico', () {
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
      expect(s.messagesFor(psi, kChild), hasLength(2));
      expect(() => s.messagesFor(family, kChild), denied);
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
      expect(() => s.acceptReferral(fis, ref, clinicName: 'Clínica A'), denied);
      final CareLink l = s.acceptReferral(psi2, ref, clinicName: 'Clínica A');
      expect(l.pending, isTrue);
      s.authorize(family, l);
      expect(s.canOpenChild(psi2, kChild), isTrue);
    });
  });

  group('Troca de profissional e de clínica', () {
    test('psicóloga sai: mantém os próprios registros e resumos, sem equipe', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummary sum = shareWithPediatrician(s, r);
      s.endLink(manager, s.linkOf(psi, kChild)!, 'Troca de profissional');
      expect(s.recordsFor(psi, kChild), <CareRecord>[r]);
      expect(s.summariesFor(psi, kChild), <CareSummary>[sum]);
      expect(() => s.planFor(psi, kChild), denied);
      expect(() => s.startSummary(psi, r), denied);
      // A autora ainda encerra o acesso ao que compartilhou.
      s.endSummary(psi, sum, 'Saída da equipe');
      expect(s.summariesFor(ped, kChild), isEmpty);

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
      expect(s.recordsFor(psi2, kChild), isEmpty);
      expect(s.summariesFor(psi2, kChild), isEmpty);
    });

    test('troca de clínica: nova equipe não vê a anterior; família mantém o '
        'liberado', () {
      final CareStore s = seeded();
      final CareRecord home = s.addRecord(
        fis,
        childId: kChild,
        kind: CareRecordKind.atividadeCasa,
        title: 'Flamingo',
        body: 'Fictício',
        visibility: CareVisibility.familia,
      );
      shareWithPediatrician(s, privateSession(s));
      expect(s.transferClinic(family, kChild, toClinicName: 'Clínica B'), hasLength(3));
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
      s.authorize(family, b);
      expect(s.recordsFor(pedB, kChild), isEmpty);
      expect(s.summariesFor(pedB, kChild), isEmpty);
      expect(s.planFor(pedB, kChild), isNull);
      expect(s.familyView(family, kChild).released, <CareRecord>[home]);
    });
  });

  group('IA só com o que foi compartilhado', () {
    test('visão da equipe usa só os resumos endereçados a quem pede', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummary sum = shareWithPediatrician(s, r);
      final int before = s.summaries.length + s.records.length;

      final CareAiDraft forPed = CareAi.teamOverview(s, ped, kChild);
      expect(forPed.text, contains(kShared));
      expect(forPed.sourceIds, <String>[sum.id]);
      for (final String secret in <String>[kFull, kPrivate, kTranscript]) {
        expect(forPed.text, isNot(contains(secret)));
      }
      final CareAiDraft forFis = CareAi.teamOverview(s, fis, kChild);
      expect(forFis.text, isNot(contains(kShared)));
      expect(forFis.sourceIds, isEmpty);
      expect(s.summaries.length + s.records.length, before, reason: 'nada é salvo');
      expect(() => CareAi.teamOverview(s, psi2, kChild), denied);
      expect(() => CareAi.teamOverview(s, family, kChild), denied);

      s.endSummary(psi, sum, 'Encerrado');
      expect(CareAi.teamOverview(s, ped, kChild).text, isNot(contains(kShared)));
    });

    test('sugestão do resumo usa só os itens marcados pela autora', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummaryDraft d = s.startSummary(psi, r);
      expect(() => CareAi.suggestSummaryNote(s, psi, r, d), denied);
      d.itemIds.add(sectionId(r, CareSectionKind.clinica));
      final CareAiDraft ai = CareAi.suggestSummaryNote(s, psi, r, d);
      expect(ai.text, contains(kShared));
      expect(ai.text, isNot(contains(kFull)));
      expect(ai.text, isNot(contains(kPrivate)));
      expect(CareAiDraft.label, contains('Rascunho'));
      expect(() => CareAi.suggestSummaryNote(s, ped, r, d), denied);
      d.itemIds.add(sectionId(r, CareSectionKind.anotacaoPrivada));
      expect(() => CareAi.suggestSummaryNote(s, psi, r, d), denied);
    });

    test('texto da IA só é publicado depois de revisado', () {
      final CareStore s = seeded();
      final CareRecord r = privateSession(s);
      final CareSummaryDraft d = s.startSummary(psi, r)
        ..itemIds.add(sectionId(r, CareSectionKind.clinica))
        ..audience = CareAudience.selecionados
        ..recipientIds.add(ped.id);
      d
        ..note = CareAi.suggestSummaryNote(s, psi, r, d).text
        ..aiAssisted = true;
      expect(() => s.publishSummary(psi, r, d, confirmed: true), denied);
      d.aiReviewed = true;
      final CareSummary sum = s.publishSummary(psi, r, d, confirmed: true);
      expect(sum.aiAssisted, isTrue);
      expect(sum.reviewedBy, psi.name);
    });
  });

  group('Trilha de acessos', () {
    test('família e gestão veem a trilha; profissional não', () {
      final CareStore s = seeded();
      s.recordsFor(ped, kChild);
      expect(() => s.recordsFor(psi2, kChild), denied);
      final List<CareAuditEntry> all = s.auditFor(family, kChild);
      expect(all.any((CareAuditEntry e) => e.actorName == ped.name && e.allowed), isTrue);
      expect(all.any((CareAuditEntry e) => e.actorName == psi2.name && !e.allowed), isTrue);
      expect(s.auditFor(manager, kChild), isNotEmpty);
      expect(() => s.auditFor(psi, kChild), denied);
    });

    test('reabrir a mesma tela não duplica a linha nem o acesso', () {
      final CareStore s = seeded();
      final CareSummary sum = shareWithPediatrician(s, privateSession(s));
      final int before = s.audit.length;
      s.recordsFor(ped, kChild);
      s.summariesFor(ped, kChild);
      s.recordsFor(ped, kChild);
      s.summariesFor(ped, kChild);
      expect(s.audit.length, before + 2);
      expect(sum.accessLog, hasLength(1));
      clockNow = clockNow.add(const Duration(minutes: 5));
      s.summariesFor(ped, kChild);
      expect(sum.accessLog, hasLength(2));
    });
  });
}
