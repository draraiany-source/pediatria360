import 'dart:convert';

import 'package:flutter/services.dart';

import '../shared/clinical/growth.dart';
import '../shared/clinical/lab_results.dart';
import '../shared/clinical/supplement_library.dart';
import 'demo_clinical.dart';
import 'demo_data.dart';

/// Tabelas LMS oficiais da OMS, carregadas uma vez por aba.
Future<WhoGrowthTables>? _tables;

WhoGrowthTables? _loaded;

/// Tabelas já carregadas nesta aba (evita o indicador de carregamento ao
/// voltar para a curva).
WhoGrowthTables? get loadedWhoTables => _loaded;

Future<WhoGrowthTables> loadWhoTables() => _tables ??= rootBundle
    .loadString('assets/data/who_growth_lms.json')
    .then(
      (String s) => _loaded = WhoGrowthTables.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      ),
    );

/// Medidas, exames e decisões fictícias da demonstração.
///
/// Os números foram escolhidos para exercitar as curvas, a idade corrigida,
/// as correções e a conferência de laudos. Não representam pacientes reais.
class DemoGrowthSeed {
  const DemoGrowthSeed._();

  /// Idade gestacional ao nascer (dias), por paciente.
  static const Map<String, int> gestationalAgeDays = <String, int>{
    'p1': 34 * 7 + 2,
    'p2': 39 * 7,
    'p5': 38 * 7 + 4,
  };

  static DateTime _at(DateTime birth, double months) {
    final DateTime d = birth.add(
      Duration(days: (months * daysPerMonth).round()),
    );
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<GrowthMeasurement> measurements(
    List<DemoPatient> patients,
    DateTime now,
  ) {
    DemoPatient p(String id) =>
        patients.firstWhere((DemoPatient x) => x.id == id);
    int n = 0;
    GrowthMeasurement m(
      DemoPatient patient,
      DateTime date, {
      double? w,
      double? l,
      double? hc,
      MeasurePosition pos = MeasurePosition.lying,
      String? consultationId,
    }) => GrowthMeasurement(
      id: 'g${++n}',
      patientId: patient.id,
      values: GrowthValues(
        date: date,
        weightKg: w,
        lengthCm: l,
        headCm: hc,
        position: pos,
      ),
      author: DemoProfessional.name,
      recordedAt: date.add(const Duration(hours: 10)),
      consultationId: consultationId,
    );

    final DemoPatient luna = p('p1');
    final DemoPatient theo = p('p2');
    final DemoPatient davi = p('p4');
    final DemoPatient alice = p('p5');
    final DateTime lb = luna.birthDate;
    final DateTime ab = alice.birthDate;

    final GrowthMeasurement lunaNine = m(
      luna,
      _at(lb, 9),
      w: 7.8,
      l: 86.5,
      hc: 43,
    );
    final GrowthMeasurement aliceWrong = m(
      alice,
      _at(ab, 27),
      w: 14.9,
      l: 96,
      pos: MeasurePosition.standing,
    );

    return <GrowthMeasurement>[
      // Luna: nascida com 34 semanas e 2 dias.
      m(luna, lb, w: 2.25, l: 45, hc: 31.5),
      m(luna, _at(lb, 1), w: 2.95, l: 48.5, hc: 33.5),
      m(luna, _at(lb, 2), w: 3.9, l: 52.5, hc: 36),
      m(luna, _at(lb, 4), w: 5.4, l: 58.5, hc: 39),
      m(luna, _at(lb, 6), w: 6.6, l: 63.5, hc: 41),
      lunaNine.correct(
        values: GrowthValues(
          date: lunaNine.values.date,
          weightKg: 7.8,
          lengthCm: 68.5,
          headCm: 43,
        ),
        reason: 'Dígitos invertidos no comprimento (exemplo)',
        author: DemoProfessional.name,
        at: lunaNine.recordedAt.add(const Duration(days: 1)),
      ),
      m(luna, _at(lb, 12), w: 9.5, l: 73, hc: 44.5),
      m(
        luna,
        _day(luna.weighedAt!),
        w: luna.weightKg,
        l: 75.5,
        hc: 45.3,
        consultationId: 'c1',
      ),
      // Theo: termo.
      m(theo, _at(theo.birthDate, 12), w: 9.9, l: 76, hc: 46.5),
      m(theo, _at(theo.birthDate, 24), w: 12.4, l: 87.5, hc: 48.5),
      m(
        theo,
        _at(theo.birthDate, 36),
        w: 14.5,
        l: 96,
        pos: MeasurePosition.standing,
      ),
      m(
        theo,
        _day(theo.weighedAt!),
        w: theo.weightKg,
        l: 102,
        pos: MeasurePosition.standing,
      ),
      // Davi: acima de 5 anos (Referência 2007).
      m(
        davi,
        _at(davi.birthDate, 60),
        w: 18.8,
        l: 110,
        pos: MeasurePosition.standing,
      ),
      m(
        davi,
        _at(davi.birthDate, 72),
        w: 21.5,
        l: 116.5,
        pos: MeasurePosition.standing,
      ),
      m(
        davi,
        _at(davi.birthDate, 84),
        w: 25,
        l: 123,
        pos: MeasurePosition.standing,
      ),
      m(
        davi,
        _day(davi.weighedAt!),
        w: davi.weightKg,
        l: 130.5,
        pos: MeasurePosition.standing,
      ),
      // Alice: inclui um lançamento anulado.
      m(alice, _at(ab, 12), w: 8.8, l: 73.5, hc: 45),
      m(alice, _at(ab, 18), w: 10.1, l: 80, hc: 46.2),
      m(alice, _at(ab, 24), w: 11.3, l: 85.5, hc: 47),
      aliceWrong.voidEntry(
        reason: 'Lançado no paciente errado (exemplo)',
        author: DemoProfessional.name,
        at: aliceWrong.recordedAt.add(const Duration(hours: 2)),
      ),
      m(
        alice,
        _day(alice.weighedAt!),
        w: alice.weightKg,
        l: 90,
        pos: MeasurePosition.standing,
      ),
    ].where((GrowthMeasurement x) => !x.values.date.isAfter(now)).toList();
  }

  static const String labA = 'Laboratório Exemplo A (fictício)';
  static const String labB = 'Laboratório Exemplo B (fictício)';

  static List<LabResult> labResults(DateTime now) {
    final DateTime recent = _day(now.subtract(const Duration(days: 40)));
    final DateTime older = _day(now.subtract(const Duration(days: 200)));
    LabResult r(
      String id,
      String patientId,
      String test,
      String value,
      String unit,
      DateTime date,
      String lab,
      ReportedRange range, {
      String? consultationId,
    }) => LabResult.manual(
      id: id,
      patientId: patientId,
      values: LabValues(
        testName: test,
        value: value,
        unit: unit,
        collectedAt: date,
        laboratory: lab,
        range: range,
      ),
      author: DemoProfessional.name,
      now: date.add(const Duration(days: 2, hours: 9)),
      consultationId: consultationId,
      topicIds: suggestedTopicsFor(test),
    );

    return <LabResult>[
      r(
        'l1',
        'p1',
        'Ferritina',
        '9',
        'ng/mL',
        older,
        labB,
        const ReportedRange(text: '7 a 140 ng/mL (laudo B)', low: 7, high: 140),
      ),
      r(
        'l2',
        'p1',
        'Ferritina',
        '14',
        'ng/mL',
        recent,
        labA,
        const ReportedRange(
          text: '12 a 150 ng/mL (laudo A)',
          low: 12,
          high: 150,
        ),
        consultationId: 'c1',
      ),
      r(
        'l3',
        'p1',
        'Hemoglobina',
        '10,9',
        'g/dL',
        recent,
        labA,
        const ReportedRange(
          text: '11,1 a 14,1 g/dL (laudo A)',
          low: 11.1,
          high: 14.1,
        ),
        consultationId: 'c1',
      ),
      r(
        'l4',
        'p1',
        '25-hidroxivitamina D',
        '28',
        'ng/mL',
        recent,
        labA,
        const ReportedRange(
          text: 'Conforme laudo: faixas por situação clínica',
        ),
        consultationId: 'c1',
      ),
      r(
        'l5',
        'p5',
        'Hemoglobina',
        '12,0',
        'g/dL',
        _day(now.subtract(const Duration(days: 60))),
        labB,
        const ReportedRange(
          text: '10,5 a 13,5 g/dL (laudo B)',
          low: 10.5,
          high: 13.5,
        ),
      ),
      LabResult.imported(
        id: 'l6',
        patientId: 'p1',
        attachment: LabAttachment(
          name: 'laudo-exemplo-ficticio.pdf',
          mimeType: 'application/pdf',
          bytes: fictitiousLabPdf(),
        ),
        author: DemoProfessional.name,
        now: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<SupplementDecision> decisions(
    DateTime now,
  ) => <SupplementDecision>[
    SupplementDecision.create(
      id: 's1',
      patientId: 'p1',
      topicId: 'ferro',
      first: SupplementDecisionVersion(
        kind: SupplementDecisionKind.monitor,
        note: 'Exemplo fictício: reavaliar na próxima consulta com novo exame.',
        author: DemoProfessional.name,
        at: now.subtract(const Duration(days: 10)),
        sheetStatus: SheetStatus.draft,
        labResultIds: const <String>['l2', 'l3'],
        consultationId: 'c1',
      ),
    ),
  ];
}

/// PDF mínimo de um laudo fictício, para demonstrar a conferência de uma
/// importação sem depender de arquivo externo.
Uint8List fictitiousLabPdf() {
  const List<String> lines = <String>[
    'LAUDO FICTICIO - DEMONSTRACAO - SEM VALIDADE',
    'Paciente: Luna Exemplo Souza',
    'Laboratorio Exemplo A (ficticio)',
    'Exame: Ferritina',
    'Resultado: 16 ng/mL',
    'Intervalo de referencia do laudo: 12 a 150 ng/mL',
  ];
  final StringBuffer text = StringBuffer('BT /F1 12 Tf 56 780 Td 18 TL\n');
  for (final String l in lines) {
    text.write('($l) Tj T*\n');
  }
  text.write('ET\n');
  final String stream = text.toString();
  final List<String> objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n${stream}endstream',
  ];
  final StringBuffer out = StringBuffer('%PDF-1.4\n');
  final List<int> offsets = <int>[];
  for (int i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final int xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final int o in offsets) {
    out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(out.toString()));
}
