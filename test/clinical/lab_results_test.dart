import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/lab_results.dart';
import 'package:pediatria360/shared/clinical/supplement_library.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 20, 10);

  LabValues v(
    String name,
    String value,
    String unit,
    DateTime date, {
    String lab = 'Laboratório Exemplo',
    ReportedRange range = const ReportedRange(),
  }) => LabValues(
    testName: name,
    value: value,
    unit: unit,
    collectedAt: date,
    laboratory: lab,
    range: range,
  );

  final LabAttachment pdf = LabAttachment(
    name: 'laudo.pdf',
    mimeType: 'application/pdf',
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
  );

  group('lançamento e conferência', () {
    test('digitado entra conferido e exige os campos do laudo', () {
      final LabResult r = LabResult.manual(
        id: 'l1',
        patientId: 'p1',
        values: v('Ferritina', '18', 'ng/mL', DateTime(2026, 9, 1)),
        author: 'Dra. Teste',
        now: now,
      );
      expect(r.inRecord, isTrue);
      expect(r.source, LabSource.manual);
      expect(
        () => LabResult.manual(
          id: 'l2',
          patientId: 'p1',
          values: v('Ferritina', '18', '', DateTime(2026, 9, 1), lab: ''),
          author: 'x',
          now: now,
        ),
        throwsStateError,
      );
    });

    test('importado de PDF fica pendente e fora das comparações', () {
      final LabResult r = LabResult.imported(
        id: 'l3',
        patientId: 'p1',
        attachment: pdf,
        author: 'Dra. Teste',
        now: now,
      );
      expect(r.isPending, isTrue);
      expect(r.inRecord, isFalse);
      expect(r.source, LabSource.importedPdf);
      expect(LabSeries.group(<LabResult>[r]), isEmpty);

      final LabResult draft = r.saveReview(
        values: v('Ferritina', '20', 'ng/mL', DateTime(2026, 9, 2)),
        author: 'Dra. Teste',
        at: now,
      );
      expect(draft.isPending, isTrue);

      final LabResult ok = draft.confirm(
        values: draft.values,
        reviewer: 'Dra. Teste',
        at: now,
      );
      expect(ok.inRecord, isTrue);
      expect(ok.revisions.last.action, contains('Conferido'));
      expect(LabSeries.group(<LabResult>[ok]).single.count, 1);
    });

    test('imagem vira importação de imagem; outro tipo é recusado', () {
      final LabResult img = LabResult.imported(
        id: 'l4',
        patientId: 'p1',
        attachment: LabAttachment(
          name: 'foto.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List(1),
        ),
        author: 'x',
        now: now,
      );
      expect(img.source, LabSource.importedImage);
      expect(
        () => LabResult.imported(
          id: 'l5',
          patientId: 'p1',
          attachment: LabAttachment(
            name: 'a.txt',
            mimeType: 'text/plain',
            bytes: Uint8List(1),
          ),
          author: 'x',
          now: now,
        ),
        throwsStateError,
      );
    });

    test('conferência não libera resultado incompleto', () {
      final LabResult r = LabResult.imported(
        id: 'l6',
        patientId: 'p1',
        attachment: pdf,
        author: 'x',
        now: now,
      );
      expect(
        () => r.confirm(values: r.values, reviewer: 'x', at: now),
        throwsStateError,
      );
    });

    test('correção mantém o valor anterior e exige motivo', () {
      final LabResult r = LabResult.manual(
        id: 'l7',
        patientId: 'p1',
        values: v('Zinco', '70', 'µg/dL', DateTime(2026, 8, 1)),
        author: 'x',
        now: now,
      );
      final LabResult fixed = r.correct(
        values: v('Zinco', '77', 'µg/dL', DateTime(2026, 8, 1)),
        reason: 'Digitação',
        author: 'y',
        at: now,
      );
      expect(fixed.values.value, '77');
      expect(fixed.revisions.last.before!.value, '70');
      expect(
        () => r.correct(values: fixed.values, reason: '', author: 'y', at: now),
        throwsStateError,
      );
    });
  });

  group('intervalo de referência do laudo', () {
    test('compara só com o intervalo informado no próprio laudo', () {
      LabResult withRange(String value, ReportedRange range) =>
          LabResult.manual(
            id: 'r$value',
            patientId: 'p1',
            values: v(
              'Hemoglobina',
              value,
              'g/dL',
              DateTime(2026, 9, 1),
              range: range,
            ),
            author: 'x',
            now: now,
          );
      const ReportedRange range = ReportedRange(
        text: '11,5 a 13,5',
        low: 11.5,
        high: 13.5,
      );
      expect(withRange('10,9', range).rangePosition, RangePosition.below);
      expect(withRange('12,1', range).rangePosition, RangePosition.within);
      expect(withRange('14', range).rangePosition, RangePosition.above);
      expect(withRange('12,1', const ReportedRange()).rangePosition, isNull);
      expect(
        withRange('12,1', const ReportedRange(text: 'ver laudo')).rangePosition,
        isNull,
      );
    });
  });

  group('séries', () {
    test('agrupa o mesmo exame e separa unidades diferentes', () {
      final List<LabResult> list = <LabResult>[
        LabResult.manual(
          id: 'a',
          patientId: 'p1',
          values: v(
            '25-hidroxivitamina D',
            '18',
            'ng/mL',
            DateTime(2026, 1, 5),
          ),
          author: 'x',
          now: now,
        ),
        LabResult.manual(
          id: 'b',
          patientId: 'p1',
          values: v(
            '25-Hidroxivitamina  D',
            '32',
            'ng/mL',
            DateTime(2026, 6, 5),
          ),
          author: 'x',
          now: now,
        ),
        LabResult.manual(
          id: 'c',
          patientId: 'p1',
          values: v(
            '25-hidroxivitamina D',
            '75',
            'nmol/L',
            DateTime(2026, 8, 5),
          ),
          author: 'x',
          now: now,
        ),
      ];
      final LabSeries s = LabSeries.group(list).single;
      expect(s.count, 3);
      expect(s.hasMixedUnits, isTrue);
      expect(s.byUnit['ng/mL']!.map((LabResult r) => r.id), <String>['a', 'b']);
    });

    test('números no formato brasileiro', () {
      expect(parseLabNumber('12,4'), 12.4);
      expect(parseLabNumber('12.4'), 12.4);
      expect(parseLabNumber('250.000'), 250000);
      expect(parseLabNumber('1.234,5'), 1234.5);
      expect(parseLabNumber('não reagente'), isNull);
    });

    test('sugestão de vínculo com temas de suplementação', () {
      expect(suggestedTopicsFor('ferritina'), contains('ferro'));
      expect(suggestedTopicsFor('Exame inexistente'), isEmpty);
      final Set<String> ids = kSupplementSheets
          .map((SupplementSheet s) => s.id)
          .toSet();
      for (final LabTestSuggestion s in kLabTestSuggestions) {
        expect(ids, containsAll(s.topicIds), reason: s.name);
      }
    });
  });

  group('decisão de suplementação', () {
    SupplementDecisionVersion ver(SupplementDecisionKind k, String note) =>
        SupplementDecisionVersion(
          kind: k,
          note: note,
          author: 'Dra. Teste',
          at: now,
          sheetStatus: SheetStatus.draft,
          labResultIds: const <String>['a'],
        );

    test('exige justificativa e guarda versões', () {
      expect(
        () => SupplementDecision.create(
          id: 'd',
          patientId: 'p1',
          topicId: 'ferro',
          first: ver(SupplementDecisionKind.monitor, ' '),
        ),
        throwsStateError,
      );
      final SupplementDecision d = SupplementDecision.create(
        id: 'd',
        patientId: 'p1',
        topicId: 'ferro',
        first: ver(SupplementDecisionKind.monitor, 'Reavaliar'),
      );
      final SupplementDecision d2 = d.revise(
        ver(SupplementDecisionKind.indicated, 'Indicado após exame'),
      );
      expect(d2.versions, hasLength(2));
      expect(d2.current.kind, SupplementDecisionKind.indicated);
    });

    test('só a indicação vai ao receituário', () {
      final SupplementDecision monitor = SupplementDecision.create(
        id: 'd',
        patientId: 'p1',
        topicId: 'ferro',
        first: ver(SupplementDecisionKind.monitor, 'Reavaliar'),
      );
      expect(() => monitor.withPrescription('doc'), throwsStateError);
      final SupplementDecision ok = monitor
          .revise(ver(SupplementDecisionKind.indicated, 'Indicado'))
          .withPrescription('doc');
      expect(ok.prescriptionDocIds, <String>['doc']);
    });
  });
}
