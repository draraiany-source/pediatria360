import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/dose_calculator.dart';
import 'package:pediatria360/shared/clinical/rx_templates.dart';

final DateTime now = DateTime(2026, 9, 27, 10);

final List<DoseReference> refs = <DoseReference>[
  DoseReference(
    id: 'ref-a',
    drugName: 'Medicamento Exemplo A',
    indication: 'Fictícia',
    basis: DoseBasis.perDose,
    mgPerKg: 15,
    minMgPerKg: 10,
    maxMgPerKg: 15,
    dosesPerDay: 4,
    maxSingleDoseMg: 500,
    source: 'Referência fictícia de teste',
    reviewedAt: DateTime(2026, 9, 1),
    validated: true,
    presentations: const <DrugPresentation>[
      DrugPresentation(
        id: 'a-susp',
        label: 'Suspensão 100 mg/5 mL',
        form: PresentationForm.liquid,
        amount: 100,
        perVolumeMl: 5,
      ),
    ],
  ),
  DoseReference(
    id: 'ref-b',
    drugName: 'Medicamento Exemplo B',
    indication: 'Fictícia',
    basis: DoseBasis.perDay,
    mgPerKg: 40,
    dosesPerDay: 2,
    allergyKeywords: const <String>['Exemplo B'],
    source: 'Referência fictícia de teste',
    reviewedAt: DateTime(2026, 9, 1),
    validated: true,
    presentations: const <DrugPresentation>[
      DrugPresentation(
        id: 'b-susp',
        label: 'Suspensão 250 mg/5 mL',
        form: PresentationForm.liquid,
        amount: 250,
        perVolumeMl: 5,
      ),
    ],
  ),
];

DocContext child(
  String name, {
  double? kg,
  DateTime? weighedAt,
  List<String> allergies = const <String>[],
}) => DocContext(
  patientName: name,
  patientBirthDate: DateTime(2023, 3, 10),
  guardianName: 'Responsável de $name',
  allergies: allergies,
  weightKg: kg,
  weighedAt: kg == null ? null : weighedAt ?? DateTime(2026, 9, 20),
  professionalName: 'Dra. Teste',
  professionalRegistry: 'CRM 0',
  date: DateTime(2026, 9, 27),
);

RxTemplate febre() => RxTemplate.create(
  id: 'm1',
  name: 'Febre (exemplo)',
  author: 'Dra. Teste',
  now: now,
  orientations: 'Oferecer líquidos a {{crianca}}.',
  items: const <RxTemplateItem>[
    RxTemplateItem(
      drug: 'Medicamento Exemplo A',
      presentation: 'Suspensão 100 mg/5 mL',
      concentration: '100 mg/5 mL',
      mode: RxDoseMode.weight,
      referenceId: 'ref-a',
      presentationId: 'a-susp',
      mgPerKg: 15,
      frequency: 'de 6/6h',
      duration: '3 dias',
      quantity: '1 frasco',
    ),
    RxTemplateItem(
      drug: 'Soro Exemplo',
      presentation: 'Solução nasal',
      concentration: '0,9%',
      mode: RxDoseMode.fixed,
      fixedDose: '2 jatos em cada narina',
      fixedVolume: 'não se aplica',
      route: 'via nasal',
      frequency: 'até 4 vezes ao dia',
      duration: '5 dias',
      quantity: '1 frasco',
    ),
  ],
);

RxItem confer(RxItem it) => it.copyWith(checked: it.requiredChecks.toSet());

void main() {
  test('dose pelo peso é refeita para cada criança, com a conta', () {
    final RxTemplateDraft a = RxTemplates.instantiate(
      febre(),
      context: child('Criança Um', kg: 10),
      references: refs,
      now: now,
    );
    final RxTemplateDraft b = RxTemplates.instantiate(
      febre(),
      context: child('Criança Dois', kg: 20),
      references: refs,
      now: now,
    );
    expect(a.items.first.dose, '7,5 mL (150 mg) por dose');
    expect(b.items.first.dose, '15 mL (300 mg) por dose');
    expect(a.items.first.volume, '7,5 mL por dose');
    expect(a.items.first.calculation, contains('15 mg/kg/dose × 10 kg'));
    expect(b.items.first.calculation, contains('× 20 kg'));
    expect(b.items.first.calculation, contains('Criança Dois'));
    expect(b.items.first.calculation, isNot(contains('Criança Um')));
    expect(a.items.first.weightDosing!.weightKg, 10);
    expect(a.orientations, 'Oferecer líquidos a Criança Um.');
    expect(a.items.every((RxItem i) => i.needsCheck), isTrue);
    expect(a.items.first.origin, 'Modelo "Febre (exemplo)" · v1');
    expect(a.items[1].dose, '2 jatos em cada narina');
    expect(
      febre().items[1].doseSummary(refs),
      '2 jatos em cada narina (dose fixa)',
    );
  });

  test('sem peso a dose não é calculada e a receita não pode ser revisada', () {
    final DocContext ctx = child('Criança Sem Peso');
    final RxTemplateDraft d = RxTemplates.instantiate(
      febre(),
      context: ctx,
      references: refs,
      now: now,
    );
    expect(d.items.first.dose, isEmpty);
    expect(d.items.first.blockers, contains('Peso não registrado.'));
    expect(d.notices.first, contains('dose não calculada'));
    final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
      id: 'x',
      kind: DocKind.receituario,
      patientId: 'p',
      author: 'Dra. Teste',
      context: ctx,
      now: now,
      items: d.items.map(confer).toList(),
    );
    expect(
      doc.pendingIssues.join(' '),
      contains('Item 1 (Medicamento Exemplo A): dose não calculada'),
    );
    expect(
      () => doc.markReviewed(reviewer: 'Dra. Teste', now: now),
      throwsA(isA<DocumentFlowException>()),
    );
  });

  test('conferência dos nove campos é exigida antes da revisão', () {
    final DocContext ctx = child('Criança Um', kg: 10);
    final RxTemplateDraft d = RxTemplates.instantiate(
      febre(),
      context: ctx,
      references: refs,
      now: now,
    );
    ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
      id: 'x',
      kind: DocKind.receituario,
      patientId: 'p',
      author: 'Dra. Teste',
      context: ctx,
      now: now,
      fields: <String, String>{'orientacoes': d.orientations},
      items: d.items,
    );
    final String issues = doc.issuesFor(ctx).join(' | ');
    expect(
      issues,
      contains(
        'Item 1 (Medicamento Exemplo A): confira medicamento, apresentação, '
        'concentração, dose, volume, via, frequência, duração, quantidade',
      ),
    );
    expect(
      () => doc.markReviewed(reviewer: 'Dra. Teste', now: now, context: ctx),
      throwsA(isA<DocumentFlowException>()),
    );

    final List<RxItem> partial = <RxItem>[
      d.items[0].copyWith(
        checked: RxCheck.values
            .where((RxCheck c) => c != RxCheck.volume)
            .toSet(),
      ),
      confer(d.items[1]),
    ];
    doc = doc.saveDraft(
      fields: doc.current.fields,
      items: partial,
      context: ctx,
      author: 'Dra. Teste',
      now: now,
    );
    expect(doc.issuesFor(ctx), <String>[
      'Item 1 (Medicamento Exemplo A): confira volume',
    ]);

    doc = doc.saveDraft(
      fields: doc.current.fields,
      items: d.items.map(confer).toList(),
      context: ctx,
      author: 'Dra. Teste',
      now: now,
    );
    expect(doc.issuesFor(ctx), isEmpty);
    doc = doc
        .markReviewed(reviewer: 'Dra. Teste', now: now, context: ctx)
        .issue(now: now);
    expect(doc.status, DocStatus.issued);
    expect(doc.current.body, contains('Medicamento Exemplo A'));
    expect(doc.current.body, contains('7,5 mL (150 mg) por dose'));
    expect(doc.current.body, contains('Solução nasal (0,9%)'));
  });

  test('item sem campo da conferência preenchido continua pendente', () {
    const RxItem it = RxItem(
      drug: 'X',
      presentation: 'Gotas',
      dose: '2 gotas',
      route: 'via oral',
      frequency: '1 vez ao dia',
      duration: '10 dias',
      needsCheck: true,
    );
    final RxItem all = confer(it);
    final List<String> issues = DocumentTemplates.missing(
      DocKind.receituario,
      const <String, String>{'orientacoes': ''},
      <RxItem>[all],
      'corpo',
    );
    expect(issues, <String>[
      'Item 1 (X): preencha concentração, volume, quantidade',
    ]);
  });

  test('peso atualizado depois do rascunho exige recalcular', () {
    final DocContext before = child('Criança Um', kg: 10);
    final RxTemplateDraft d = RxTemplates.instantiate(
      febre(),
      context: before,
      references: refs,
      now: now,
    );
    final List<RxItem> items = d.items.map(confer).toList();
    final DocContext after = child(
      'Criança Um',
      kg: 11,
      weighedAt: DateTime(2026, 9, 27),
    );
    final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
      id: 'x',
      kind: DocKind.receituario,
      patientId: 'p',
      author: 'Dra. Teste',
      context: after,
      now: now,
      items: items,
    );
    expect(doc.issuesFor(after).single, contains('conta feita com 10 kg'));
    expect(doc.issuesFor(after).single, contains('peso atual 11 kg'));

    final RxItem again = RxTemplates.recalculate(
      items.first,
      patient: DosePatientData(
        name: after.patientName,
        weightKg: after.weightKg,
        weighedAt: after.weighedAt,
        birthDate: after.patientBirthDate,
      ),
      references: refs,
      now: now,
    );
    expect(again.dose, '8,3 mL (165 mg) por dose');
    expect(again.checked, isEmpty, reason: 'nova conta, nova conferência');
    expect(
      rxWeightIssues(
        <RxItem>[again],
        weightKg: after.weightKg,
        weighedAt: after.weighedAt,
      ),
      isEmpty,
    );
  });

  test('alergia bloqueia a dose pelo peso e alerta nos itens manuais', () {
    final RxTemplate t = RxTemplate.create(
      id: 'm2',
      name: 'B',
      author: 'Dra. Teste',
      now: now,
      items: const <RxTemplateItem>[
        RxTemplateItem(
          drug: 'Medicamento Exemplo B',
          presentation: 'Suspensão 250 mg/5 mL',
          mode: RxDoseMode.weight,
          referenceId: 'ref-b',
          presentationId: 'b-susp',
          mgPerKg: 40,
          duration: '7 dias',
        ),
        RxTemplateItem(
          drug: 'Medicamento Exemplo B',
          presentation: 'Suspensão',
          mode: RxDoseMode.atConsultation,
          frequency: 'de 12/12h',
          duration: '7 dias',
        ),
      ],
    );
    final RxTemplateDraft d = RxTemplates.instantiate(
      t,
      context: child(
        'Criança Alérgica',
        kg: 30,
        allergies: <String>['Medicamento Exemplo B (fictício)'],
      ),
      references: refs,
      now: now,
    );
    expect(d.items[0].dose, isEmpty);
    expect(d.items[0].blockers.join(), contains('Alergia registrada'));
    expect(d.items[1].alerts.single, contains('Alergia registrada'));
    expect(d.items[1].requiredChecks, contains(RxCheck.alerts));
  });

  test('modelo a partir de receita não guarda a dose da outra criança', () {
    final DocContext luna = child('Criança Um', kg: 10);
    final RxTemplateDraft first = RxTemplates.instantiate(
      febre(),
      context: luna,
      references: refs,
      now: now,
    );
    final List<RxItem> issued = <RxItem>[
      ...first.items,
      const RxItem(
        drug: 'Manual Exemplo',
        presentation: 'Xarope',
        dose: '5 mL',
        volume: '5 mL',
        route: 'via oral',
        frequency: 'de 8/8h',
        duration: '5 dias',
        notes: 'Dar a Criança Um após as refeições.',
      ),
    ];
    final RxTemplate t = RxTemplates.fromPrescription(
      id: 'm9',
      name: 'Da receita',
      items: issued,
      orientations:
          'Criança Um deve beber água. Responsável de Criança Um liga.',
      author: 'Dra. Teste',
      now: now,
      context: luna,
      references: refs,
    );
    expect(t.items[0].mode, RxDoseMode.weight);
    expect(t.items[0].mgPerKg, 15);
    expect(t.items[2].mode, RxDoseMode.atConsultation);
    expect(t.items[2].fixedDose, isEmpty);
    expect(t.items[2].fixedVolume, isEmpty);
    expect(t.items[2].notes, 'Dar a {{crianca}} após as refeições.');
    expect(
      t.orientations,
      '{{crianca}} deve beber água. {{responsavel}} liga.',
    );

    final RxTemplateDraft other = RxTemplates.instantiate(
      t,
      context: child('Criança Dois', kg: 20),
      references: refs,
      now: now,
    );
    expect(other.items[0].dose, '15 mL (300 mg) por dose');
    expect(other.items[2].dose, isEmpty);
    expect(other.items[2].volume, isEmpty);
    expect(other.items[2].notes, 'Dar a Criança Dois após as refeições.');
    expect(other.orientations, contains('Criança Dois deve beber água'));
    expect(other.orientations, isNot(contains('Criança Um')));
  });

  test('editar o modelo cria versão e não muda a receita já emitida', () {
    final DocContext ctx = child('Criança Um', kg: 10);
    final RxTemplate v1 = febre();
    final RxTemplateDraft d = RxTemplates.instantiate(
      v1,
      context: ctx,
      references: refs,
      now: now,
    );
    final ClinicalDocRecord doc =
        ClinicalDocRecord.createDraft(
              id: 'x',
              kind: DocKind.receituario,
              patientId: 'p',
              author: 'Dra. Teste',
              context: ctx,
              now: now,
              items: d.items.map(confer).toList(),
            )
            .markReviewed(reviewer: 'Dra. Teste', now: now, context: ctx)
            .issue(now: now);
    final String body = doc.current.body;

    final RxTemplate v2 = v1.edit(
      name: 'Febre (exemplo) revisado',
      items: <RxTemplateItem>[
        const RxTemplateItem(
          drug: 'Medicamento Exemplo A',
          presentation: 'Suspensão 100 mg/5 mL',
          mode: RxDoseMode.weight,
          referenceId: 'ref-a',
          presentationId: 'a-susp',
          mgPerKg: 10,
          duration: '2 dias',
          quantity: '1 frasco',
        ),
      ],
      orientations: 'Nova orientação.',
      author: 'Dra. Teste',
      now: now.add(const Duration(days: 1)),
    );
    expect(v2.versions.length, 2);
    expect(v2.current.number, 2);
    expect(v2.versions.first.items.length, 2);
    expect(v2.current.note, 'Edição a partir da v1');
    expect(doc.current.body, body);
    expect(doc.current.items.first.origin, contains('v1'));
    expect(doc.current.items.first.dose, '7,5 mL (150 mg) por dose');
    final RxTemplateDraft d2 = RxTemplates.instantiate(
      v2,
      context: ctx,
      references: refs,
      now: now,
    );
    expect(d2.items.single.dose, '5 mL (100 mg) por dose');
    expect(d2.items.single.origin, contains('v2'));
  });

  test('duplicar, buscar e validar', () {
    final RxTemplate t = febre();
    final RxTemplate copy = t.duplicate(
      id: 'm3',
      author: 'Dra. Teste',
      now: now,
    );
    expect(copy.id, 'm3');
    expect(copy.name, 'Cópia de Febre (exemplo)');
    expect(copy.versions.length, 1);
    expect(copy.current.note, contains('v1'));
    expect(copy.items.length, t.items.length);

    expect(t.matches('febre'), isTrue);
    expect(t.matches('FEBRE exemplo a'), isTrue);
    expect(t.matches('solucao nasal'), isTrue);
    expect(t.matches('Solução'), isTrue);
    expect(t.matches('tosse'), isFalse);
    expect(t.problems(refs), isEmpty);

    final RxTemplate bad = RxTemplate.create(
      id: 'm4',
      name: '',
      author: 'Dra. Teste',
      now: now,
      items: const <RxTemplateItem>[
        RxTemplateItem(drug: 'Y', presentation: 'Z', mode: RxDoseMode.weight),
      ],
    );
    expect(bad.problems(refs), <String>[
      'Dê um nome ao modelo',
      'Item 1: escolha a referência de dose, informe a dose em mg/kg, '
          'informe a duração',
    ]);
  });
}
