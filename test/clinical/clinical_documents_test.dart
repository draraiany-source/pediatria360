import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/orientation_templates.dart';
import 'package:pediatria360/shared/clinical/supplement_library.dart';

final DateTime now = DateTime(2026, 9, 27, 10, 30);

final DocContext ctx = DocContext(
  patientName: 'Luna Exemplo Souza',
  patientBirthDate: DateTime(2025, 7, 3),
  guardianName: 'Responsável Exemplo A',
  allergies: const <String>['Proteína do leite (exemplo)'],
  weightKg: 10.2,
  weighedAt: DateTime(2026, 9, 17),
  professionalName: 'Dra. Exemplo Demonstração',
  professionalRegistry: 'CRM 00000-UF (fictício)',
  date: DateTime(2026, 9, 27),
  clinicalSummary: 'Resumo fictício da avaliação.',
);

ClinicalDocRecord draft(DocKind kind, {Map<String, String>? fields, List<RxItem> items = const <RxItem>[]}) =>
    ClinicalDocRecord.createDraft(
      id: 'd1',
      kind: kind,
      patientId: 'p1',
      author: 'Dra. Exemplo Demonstração',
      context: ctx,
      now: now,
      fields: fields,
      items: items,
    );

const RxItem item = RxItem(
  drug: 'Medicamento Exemplo A',
  presentation: 'Suspensão 100 mg/5 mL',
  dose: '7,7 mL (153 mg) por dose',
  route: 'via oral',
  frequency: 'de 6/6h',
  duration: '5 dias',
);

void main() {
  group('preenchimento', () {
    test('atestado usa dados do paciente e da consulta', () {
      final ClinicalDocRecord d = draft(DocKind.atestado);
      expect(d.current.fields['inicio'], '27/09/2026');
      expect(d.current.body, contains('Luna Exemplo Souza, nascido(a) em 03/07/2025'));
      expect(d.current.body, contains('por 1 dia, a partir de 27/09/2026'));
      expect(d.current.body, isNot(contains('CID')));
      expect(d.current.status, DocStatus.draft);
      expect(d.current.number, 1);
      expect(d.current.author, 'Dra. Exemplo Demonstração');
    });

    test('declaração traz o responsável e exige horários', () {
      final ClinicalDocRecord d = draft(DocKind.comparecimento);
      expect(d.current.fields['acompanhante'], 'Responsável Exemplo A');
      expect(d.pendingIssues, contains('Das obrigatório'));
      expect(d.pendingIssues, contains('Há campos entre colchetes a preencher'));
    });

    test('encaminhamento registra todos os campos pedidos', () {
      final ClinicalDocRecord d = draft(DocKind.encaminhamento, fields: <String, String>{
        'especialidade': 'Especialidade Exemplo',
        'prioridade': 'Prioritário',
        'motivo': 'Motivo fictício',
        'resumo': 'Resumo fictício',
        'exames': 'Exame exemplo A',
        'tratamentos': 'Tratamento exemplo',
      });
      final String b = d.current.body;
      expect(b, contains('avaliação em Especialidade Exemplo (Prioritário)'));
      expect(b, contains('Motivo: Motivo fictício'));
      expect(b, contains('Resumo clínico: Resumo fictício'));
      expect(b, contains('Exames relevantes: Exame exemplo A'));
      expect(b, contains('Tratamentos realizados: Tratamento exemplo'));
      expect(b, contains('Alergias registradas: Proteína do leite (exemplo)'));
      expect(d.title, 'Encaminhamento para Especialidade Exemplo');
      expect(d.pendingIssues, isEmpty);
    });

    test('solicitação de exames lista um por linha', () {
      final ClinicalDocRecord d = draft(DocKind.exames, fields: <String, String>{
        'exames': 'Exame A\n\nExame B',
        'indicacao': 'Indicação fictícia',
        'observacoes': '',
      });
      expect(d.current.body, contains('- Exame A\n- Exame B'));
      expect(d.pendingIssues, isEmpty);
    });

    test('receituário sem item não pode ser revisado', () {
      final ClinicalDocRecord d = draft(DocKind.receituario);
      expect(d.pendingIssues, contains('Inclua ao menos um medicamento'));
      expect(() => d.markReviewed(reviewer: 'x', now: now), throwsA(isA<DocumentFlowException>()));
    });
  });

  group('ciclo de vida', () {
    test('emitir exige revisão; emitido não é assinado', () {
      ClinicalDocRecord d = draft(DocKind.receituario, items: const <RxItem>[item]);
      expect(() => d.issue(now: now), throwsA(isA<DocumentFlowException>()));
      d = d.markReviewed(reviewer: 'Dra. Exemplo Demonstração', now: now);
      expect(d.status, DocStatus.reviewed);
      expect(d.current.reviewedBy, 'Dra. Exemplo Demonstração');
      d = d.issue(now: now);
      expect(d.status, DocStatus.issued);
      expect(d.current.issuedAt, now);
      expect(d.signature.isSigned, isFalse);
      expect(d.signature.label, 'Não assinado');
      expect(d.current.body, contains('1. Medicamento Exemplo A - Suspensão 100 mg/5 mL'));
      expect(d.current.body, contains('7,7 mL (153 mg) por dose, via oral, de 6/6h, por 5 dias'));
    });

    test('editar rascunho revisado invalida a revisão na mesma versão', () {
      ClinicalDocRecord d = draft(DocKind.receituario, items: const <RxItem>[item]);
      d = d.markReviewed(reviewer: 'r', now: now);
      d = d.saveDraft(
        fields: <String, String>{'orientacoes': 'Retornar se piora.'},
        items: const <RxItem>[item],
        context: ctx,
        author: 'Dra. Exemplo Demonstração',
        now: now.add(const Duration(minutes: 5)),
      );
      expect(d.versions.length, 1);
      expect(d.status, DocStatus.draft);
      expect(d.current.reviewedBy, isNull);
      expect(d.current.body, contains('Orientações: Retornar se piora.'));
    });

    test('editar documento emitido cria nova versão e preserva a anterior', () {
      ClinicalDocRecord d = draft(DocKind.receituario, items: const <RxItem>[item]);
      d = d.markReviewed(reviewer: 'r', now: now).issue(now: now);
      final String v1Body = d.current.body;
      d = d.saveDraft(
        fields: <String, String>{'orientacoes': 'Nova orientação.'},
        items: const <RxItem>[item],
        context: ctx,
        author: 'Dr. Outro Exemplo',
        now: now.add(const Duration(days: 1)),
      );
      expect(d.versions.length, 2);
      expect(d.versions.first.status, DocStatus.issued);
      expect(d.versions.first.body, v1Body);
      expect(d.current.number, 2);
      expect(d.current.author, 'Dr. Outro Exemplo');
      expect(d.current.status, DocStatus.draft);
      expect(d.current.changeNote, 'Nova versão a partir da v1');
    });

    test('atestado com CID exige o código', () {
      final ClinicalDocRecord d = draft(DocKind.atestado, fields: <String, String>{
        'dias': '2',
        'inicio': '27/09/2026',
        'finalidade': 'escolares',
        'incluirCid': 'Sim',
        'cid': '',
        'observacoes': '',
      });
      expect(d.pendingIssues, contains('Informe o CID ou desmarque a inclusão'));
    });

    test('assinatura só existe com provedor e data', () {
      const SignatureInfo pending = SignatureInfo.pending('Provedor ICP-Brasil exemplo');
      expect(pending.isSigned, isFalse);
      final SignatureInfo signed = SignatureInfo.signed(provider: 'P', signedAt: now);
      expect(signed.isSigned, isTrue);
      expect(signed.label, 'Assinado digitalmente (P) em 27/09/2026');
    });

    test('cada modalidade tem requisito de assinatura configurado', () {
      for (final DocKind k in DocKind.values) {
        expect(k.signatureRequirement.digital, contains('ICP-Brasil'));
      }
      expect(DocKind.receituario.signatureRequirement.restrictions, contains('controle especial'));
    });
  });

  group('orientações', () {
    final OrientationTemplate t = OrientationTemplate(
      id: 'o1',
      title: 'Modelo',
      body: 'Orientações para {{crianca}} ({{idade}}), peso {{peso}}. Responsável: {{responsavel}}.',
      author: 'x',
      updatedAt: DateTime(2026),
    );

    test('personaliza com dados da criança', () {
      final String s = t.personalize(ctx, now);
      expect(s, 'Orientações para Luna Exemplo Souza (14 meses), peso 10,2 kg em 17/09/2026. '
          'Responsável: Responsável Exemplo A.');
    });

    test('texto personalizado volta a ser modelo reutilizável', () {
      final String s = t.personalize(ctx, now);
      final String g = OrientationTemplate.generalize(s, ctx);
      expect(g, contains('{{crianca}}'));
      expect(g, contains('{{responsavel}}'));
      expect(g, isNot(contains('Luna')));
    });
  });

  group('biblioteca de suplementação', () {
    test('17 temas pedidos, todos em rascunho e sem conteúdo', () {
      expect(kSupplementSheets.length, 17);
      expect(kSupplementSheets.map((SupplementSheet s) => s.title), containsAll(<String>[
        'Exames laboratoriais', 'Ferro', 'Vitamina B12', 'Ácido fólico', 'Zinco',
        'Vitamina B6', 'Vitamina A', 'Vitamina D', 'Vitamina E', 'Vitamina K',
        'Vitamina C', 'Magnésio', 'Ômega-3', 'Cálcio', 'Complexo B', 'Selênio', 'Cobre',
      ]));
      for (final SupplementSheet s in kSupplementSheets) {
        expect(s.isDraft, isTrue);
        expect(s.filledFields, 0);
      }
    });

    test('validação exige todos os campos, fonte, revisor e data', () {
      final SupplementSheet s = kSupplementSheets[1];
      expect(() => s.validate(), throwsStateError);
      final SupplementSheet filled = s.edit(
        content: <String, String>{
          for (final SheetField f in kSheetFields) f.key: 'Texto próprio de teste',
        },
        source: 'Fonte de teste',
        reviewedBy: 'Revisor de teste',
        reviewedAt: DateTime(2026, 9, 1),
      );
      expect(filled.missingForValidation, isEmpty);
      final SupplementSheet v = filled.validate();
      expect(v.status, SheetStatus.validated);
      final SupplementSheet edited = v.edit(
        content: v.content,
        source: v.source,
        reviewedBy: v.reviewedBy,
        reviewedAt: v.reviewedAt,
      );
      expect(edited.status, SheetStatus.draft);
    });
  });
}
