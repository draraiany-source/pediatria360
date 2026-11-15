import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/doc_templates.dart';
import 'package:pediatria360/shared/clinical/template_library.dart';

final DateTime _now = DateTime(2026, 10, 2, 10);

DocContext _luna({DateTime? consultation}) => DocContext(
  patientName: 'Luna Exemplo Souza',
  patientBirthDate: DateTime(2024, 3, 10),
  guardianName: 'Responsável Exemplo A',
  allergies: const <String>['Alergia fictícia'],
  weightKg: 10.2,
  weighedAt: DateTime(2026, 9, 20),
  professionalName: 'Dra. Exemplo',
  professionalRegistry: 'CRM-EX 0000',
  professionalSpecialty: 'Pediatria',
  clinicName: 'Consultório Exemplo',
  city: 'Cidade Exemplo',
  date: consultation ?? DateTime(2026, 10, 2),
  consultationDate: consultation,
  clinicalSummary: consultation == null ? null : 'Avaliação fictícia da Luna',
);

DocContext _maya() => DocContext(
  patientName: 'Maya Exemplo Lima',
  patientBirthDate: DateTime(2025, 1, 5),
  professionalName: 'Dra. Exemplo',
  professionalRegistry: 'CRM-EX 0000',
  date: DateTime(2026, 10, 2),
);

DocTemplate _atestado() => DocTemplate.create(
  id: 'm1',
  kind: DocKind.atestado,
  name: 'Atestado escolar',
  fields: <String, String>{
    'dias': '1',
    'inicio': '{{data_consulta}}',
    'finalidade': 'escolares',
    'incluirCid': 'Sim',
    'cid': 'X00',
    DocumentTemplates.freeTextKey:
        'Atesto que {{crianca}} ({{idade}}), acompanhada de {{responsavel}}, '
        'foi atendida em {{data_consulta}}. Peso: {{peso}}.\n'
        'CID X00\n'
        '[preencher: orientação para o retorno]',
  },
  author: 'Dra. Exemplo',
  now: _now,
);

void main() {
  group('biblioteca de modelos: escopo e permissões', () {
    const TemplateActor profA = TemplateActor(
      accountId: 'prof-a',
      name: 'Dra. Exemplo',
      clinicId: 'clinica-a',
    );
    const TemplateActor profB = TemplateActor(
      accountId: 'prof-b',
      name: 'Dr. Colega',
      clinicId: 'clinica-b',
    );
    const TemplateActor colegaA = TemplateActor(
      accountId: 'prof-c',
      name: 'Dra. Colega da clínica A',
      clinicId: 'clinica-a',
    );
    const TemplateActor gestaoA = TemplateActor(
      accountId: 'gestao-a',
      name: 'Gestão',
      clinicId: 'clinica-a',
      managesClinic: true,
    );

    late TemplateLibrary lib;
    setUp(() {
      lib = TemplateLibrary()
        ..register(
          const TemplateOrg(
            id: 'pessoal',
            scope: TemplateScope.personal,
            ownerId: 'prof-a',
            folder: 'Escola',
          ),
        )
        ..register(
          const TemplateOrg(
            id: 'clinica',
            scope: TemplateScope.clinic,
            ownerId: 'clinica-a',
          ),
        )
        ..register(
          const TemplateOrg(
            id: 'exemplo',
            scope: TemplateScope.example,
            ownerId: '',
          ),
        );
    });

    test('modelo pessoal: só o dono vê e organiza', () {
      expect(lib.canSee('pessoal', profA), isTrue);
      expect(lib.canManage('pessoal', profA), isTrue);
      expect(lib.canSee('pessoal', profB), isFalse);
      expect(lib.canSee('pessoal', colegaA), isFalse);
      expect(lib.canSee('pessoal', gestaoA), isFalse);
      expect(
        () => lib.archive('pessoal', profB, _now),
        throwsA(isA<TemplateAccessException>()),
      );
    });

    test('modelo da clínica: a clínica usa, só a gestão altera', () {
      expect(lib.canUse('clinica', profA), isTrue);
      expect(lib.canUse('clinica', colegaA), isTrue);
      expect(lib.canSee('clinica', profB), isFalse);
      expect(lib.canManage('clinica', profA), isFalse);
      expect(lib.canManage('clinica', gestaoA), isTrue);
      expect(
        () => lib.moveTo('clinica', profA, 'Minha pasta'),
        throwsA(isA<TemplateAccessException>()),
      );
    });

    test('exemplo: todos veem, ninguém altera', () {
      expect(lib.canSee('exemplo', profB), isTrue);
      expect(lib.canManage('exemplo', gestaoA), isFalse);
    });

    test('duplicar modelo da clínica gera cópia pessoal sem tocar o '
        'original', () {
      final TemplateOrg copy = lib.registerCopy(
        sourceId: 'clinica',
        newId: 'copia',
        sourceName: 'Atestado da clínica',
        actor: profA,
      );
      expect(copy.scope, TemplateScope.personal);
      expect(copy.ownerId, 'prof-a');
      expect(copy.copiedFrom, 'Modelo da clínica: Atestado da clínica');
      expect(lib.orgOf('clinica')!.scope, TemplateScope.clinic);
      expect(lib.canManage('copia', profA), isTrue);
      expect(lib.canSee('copia', colegaA), isFalse);
    });

    test('quem não vê o modelo não pode duplicá-lo', () {
      expect(
        () => lib.registerCopy(
          sourceId: 'pessoal',
          newId: 'x',
          sourceName: 'x',
          actor: profB,
        ),
        throwsA(isA<TemplateAccessException>()),
      );
    });

    test('gestão cria modelos da clínica; profissional cria pessoais', () {
      expect(lib.registerNew('n1', gestaoA).scope, TemplateScope.clinic);
      expect(lib.registerNew('n2', profA).scope, TemplateScope.personal);
    });

    test('arquivar tira do uso sem apagar; restaurar devolve', () {
      lib.archive('pessoal', profA, _now);
      expect(lib.canSee('pessoal', profA), isTrue);
      expect(lib.canUse('pessoal', profA), isFalse);
      expect(lib.orgOf('pessoal')!.archivedBy, 'Dra. Exemplo');
      lib.restore('pessoal', profA);
      expect(lib.canUse('pessoal', profA), isTrue);
    });

    test('pastas normalizadas e só as de quem organiza', () {
      lib.moveTo('pessoal', profA, '  Escola   infantil ');
      expect(lib.orgOf('pessoal')!.folder, 'Escola infantil');
      expect(lib.foldersFor(profA), <String>['Escola infantil']);
      expect(lib.foldersFor(profB), isEmpty);
    });
  });

  group('modelo de documento', () {
    test('atestado: o modelo nunca guarda CID', () {
      final DocTemplate t = _atestado();
      expect(t.fields['incluirCid'], 'Não');
      expect(t.fields['cid'], '');
      expect(t.fields[DocumentTemplates.freeTextKey], isNot(contains('CID')));
    });

    test('editar cria nova versão e mantém as anteriores', () {
      final DocTemplate t = _atestado();
      final DocTemplate e = t.edit(
        name: 'Atestado escolar 2 dias',
        fields: <String, String>{...t.fields, 'dias': '2'},
        author: 'Dra. Exemplo',
        now: _now.add(const Duration(hours: 1)),
      );
      expect(e.versions.length, 2);
      expect(e.current.number, 2);
      expect(e.versions.first.fields['dias'], '1');
      expect(e.fields['dias'], '2');
      expect(e.current.note, 'Edição a partir da v1');
      expect(e.originLabel, 'Modelo "Atestado escolar 2 dias" · v2');
    });

    test('duplicar gera modelo independente na versão 1', () {
      final DocTemplate d = _atestado().duplicate(
        id: 'm2',
        author: 'Dra. Exemplo',
        now: _now,
      );
      expect(d.id, 'm2');
      expect(d.name, 'Cópia de Atestado escolar');
      expect(d.current.number, 1);
    });

    test('receita e orientações não usam este tipo de modelo', () {
      expect(
        () => DocTemplate.create(
          id: 'x',
          kind: DocKind.receituario,
          name: 'x',
          fields: const <String, String>{},
          author: 'x',
          now: _now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('aplicar modelo: só dados confirmados', () {
    test('criança com consulta e peso: tudo confirmado entra', () {
      final DocTemplateApplication a = DocTemplates.apply(
        _atestado(),
        _luna(consultation: DateTime(2026, 10, 1)),
        _now,
      );
      final String text = a.fields[DocumentTemplates.freeTextKey]!;
      expect(text, contains('Luna Exemplo Souza'));
      expect(text, contains('Responsável Exemplo A'));
      expect(text, contains('01/10/2026'));
      expect(text, contains('10,2 kg em 20/09/2026'));
      expect(text, contains('[preencher: orientação para o retorno]'));
      expect(a.fields['inicio'], '01/10/2026');
      expect(a.autoFilled['inicio'], contains('data da consulta'));
      expect(
        a.toReview[DocumentTemplates.freeTextKey]!.join(' '),
        contains('orientação para o retorno'),
      );
      expect(a.fields[DocumentTemplates.originKey], contains('Atestado escolar'));
    });

    test('outra criança sem peso, responsável nem consulta: campos marcados '
        'para conferir, nada herdado da primeira', () {
      final DocTemplate t = _atestado();
      DocTemplates.apply(t, _luna(consultation: DateTime(2026, 10, 1)), _now);
      final DocTemplateApplication a = DocTemplates.apply(t, _maya(), _now);
      final String text = a.fields[DocumentTemplates.freeTextKey]!;
      expect(text, contains('Maya Exemplo Lima'));
      expect(text, isNot(contains('Luna')));
      expect(text, isNot(contains('10,2')));
      expect(text, contains('[conferir: peso]'));
      expect(text, contains('[conferir: responsável]'));
      expect(text, contains('[conferir: data da consulta]'));
      expect(a.fields['inicio'], '[conferir: data da consulta]');
      expect(
        a.toReview[DocumentTemplates.freeTextKey]!.join(' '),
        contains('peso não registrado'),
      );
    });

    test('atestado aplicado nunca liga o CID', () {
      final DocTemplateApplication a = DocTemplates.apply(
        _atestado(),
        _luna(),
        _now,
      );
      expect(a.fields['incluirCid'], 'Não');
      expect(a.fields['cid'], '');
    });

    test('campos variáveis bloqueiam a revisão até serem resolvidos', () {
      final DocTemplateApplication a = DocTemplates.apply(
        _atestado(),
        _maya(),
        _now,
      );
      final String body = DocumentTemplates.render(
        DocKind.atestado,
        a.fields,
        _maya(),
        const [],
      );
      expect(
        DocumentTemplates.missing(DocKind.atestado, a.fields, const [], body),
        isNotEmpty,
      );
    });

    test('encaminhamento: resumo clínico só vem da consulta vinculada', () {
      final DocTemplate t = DocTemplate.create(
        id: 'e1',
        kind: DocKind.encaminhamento,
        name: 'Fono',
        fields: const <String, String>{
          'especialidade': 'Fonoaudiologia',
          'prioridade': 'Eletivo',
          'motivo': 'Avaliação de fala',
        },
        author: 'Dra. Exemplo',
        now: _now,
      );
      final DocTemplateApplication com = DocTemplates.apply(
        t,
        _luna(consultation: DateTime(2026, 10, 1)),
        _now,
      );
      expect(com.fields['resumo'], 'Avaliação fictícia da Luna');
      final DocTemplateApplication sem = DocTemplates.apply(t, _luna(), _now);
      expect(sem.fields['resumo'], '');
      expect(sem.toReview['resumo']!.join(), contains('a preencher'));
    });
  });

  group('salvar documento como modelo', () {
    test('dados da criança viram marcadores e o específico fica em aberto', () {
      final DocContext c = _luna(consultation: DateTime(2026, 10, 1));
      final Map<String, String> g = DocTemplates.generalize(
        DocKind.encaminhamento,
        <String, String>{
          'especialidade': 'Fonoaudiologia',
          'prioridade': 'Eletivo',
          'motivo': 'Luna Exemplo Souza com atraso de fala',
          'resumo': 'Avaliação fictícia da Luna',
          'exames': 'Audiometria',
          'tratamentos': 'Nenhum',
        },
        c,
      );
      expect(g['motivo'], '{{crianca}} com atraso de fala');
      expect(g['resumo'], '');
      expect(g['exames'], '');
      expect(g['tratamentos'], '');
    });

    test('atestado salvo como modelo perde CID e mantém a data como '
        'marcador', () {
      final DocContext c = _luna(consultation: DateTime(2026, 10, 1));
      final Map<String, String> g = DocTemplates.clean(
        DocKind.atestado,
        DocTemplates.generalize(DocKind.atestado, <String, String>{
          'dias': '2',
          'inicio': '01/10/2026',
          'finalidade': 'escolares',
          'incluirCid': 'Sim',
          'cid': 'X00',
        }, c),
      );
      expect(g['inicio'], '{{data_consulta}}');
      expect(g['incluirCid'], 'Não');
      expect(g['cid'], '');
    });
  });

  group('documento: texto livre, período e emissão', () {
    test('texto editado substitui o gerado; atestado mostra o fim do '
        'período', () {
      final Map<String, String> f = <String, String>{
        'dias': '3',
        'inicio': '01/10/2026',
        'finalidade': 'escolares',
        'incluirCid': 'Não',
      };
      final String gerado = DocumentTemplates.render(
        DocKind.atestado,
        f,
        _luna(),
        const [],
      );
      expect(gerado, contains('(até 03/10/2026)'));
      expect(gerado, isNot(contains('CID')));
      final String livre = DocumentTemplates.render(
        DocKind.atestado,
        <String, String>{...f, DocumentTemplates.freeTextKey: 'Texto livre.'},
        _luna(),
        const [],
      );
      expect(livre, 'Texto livre.');
    });

    test('emissão grava os dados do profissional; mudanças depois não '
        'alteram o emitido', () {
      final DocContext antes = _luna();
      ClinicalDocRecord d = ClinicalDocRecord.createDraft(
        id: 'd1',
        kind: DocKind.atestado,
        patientId: 'p1',
        author: 'Dra. Exemplo',
        context: antes,
        now: _now,
      );
      d = d
          .markReviewed(reviewer: 'Dra. Exemplo', now: _now, context: antes)
          .issue(now: _now, context: antes);
      expect(d.current.status, DocStatus.issued);
      final DocContext depois = DocContext(
        patientName: antes.patientName,
        professionalName: 'Dra. Exemplo Renomeada',
        professionalRegistry: 'CRM-EX 9999',
        date: antes.date,
      );
      expect(d.current.contextOr(depois).professionalName, 'Dra. Exemplo');
      expect(d.current.contextOr(depois).professionalRegistry, 'CRM-EX 0000');
    });

    test('correção de emitido vira nova versão com autor e motivo', () {
      final DocContext c = _luna();
      ClinicalDocRecord d = ClinicalDocRecord.createDraft(
        id: 'd1',
        kind: DocKind.atestado,
        patientId: 'p1',
        author: 'Dra. Exemplo',
        context: c,
        now: _now,
      );
      d = d
          .markReviewed(reviewer: 'Dra. Exemplo', now: _now, context: c)
          .issue(now: _now, context: c);
      final String emitido = d.current.body;
      d = d.saveDraft(
        fields: <String, String>{...d.current.fields, 'dias': '2'},
        items: const [],
        context: c,
        author: 'Dra. Exemplo',
        now: _now.add(const Duration(hours: 2)),
        changeNote: 'Correção: período ajustado',
      );
      expect(d.versions.length, 2);
      expect(d.versions.first.status, DocStatus.issued);
      expect(d.versions.first.body, emitido);
      expect(d.current.status, DocStatus.draft);
      expect(d.current.changeNote, 'Correção: período ajustado');
      expect(d.current.author, 'Dra. Exemplo');
    });
  });
}
