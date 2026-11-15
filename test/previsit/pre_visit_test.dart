import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/demo/demo_previsit_seed.dart';
import 'package:pediatria360/shared/previsit/pre_visit.dart';

import '../support/png_fixture.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 28);
  final DateTime birth = DateTime(2025, 3, 10);

  PreVisitAttachment att(
    String id,
    Uint8List bytes, {
    PreVisitDocType type = PreVisitDocType.exame,
    DateTime? date,
    DateTime? sentAt,
  }) => PreVisitAttachment(
    id: id,
    name: '$id.png',
    format: PreVisitFormat.png,
    bytes: bytes,
    type: type,
    addedAt: today,
    date: date,
    sentAt: sentAt,
  );

  Uint8List pngOfSize(int size) {
    final Uint8List b = Uint8List(size);
    b.setAll(0, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    return b;
  }

  group('formato pelo conteúdo', () {
    test('JPG, PNG, WEBP e PDF reconhecidos; o nome não decide', () {
      expect(PreVisitRules.formatOf(jpegHeader(10, 10)), PreVisitFormat.jpeg);
      expect(PreVisitRules.formatOf(solidPng(4, 4)), PreVisitFormat.png);
      final Uint8List webp = Uint8List.fromList(<int>[
        ...'RIFF'.codeUnits,
        0, 0, 0, 0, //
        ...'WEBPVP8 '.codeUnits,
      ]);
      expect(PreVisitRules.formatOf(webp), PreVisitFormat.webp);
      expect(
        PreVisitRules.formatOf(DemoPreVisitSeed.samplePdf()),
        PreVisitFormat.pdf,
      );
      expect(
        PreVisitRules.formatOf(Uint8List.fromList(utf8.encode('texto'))),
        isNull,
      );
    });

    test('PDF de exemplo é válido: cabeçalho, xref e 1 página', () {
      final Uint8List pdf = DemoPreVisitSeed.samplePdf();
      final String s = latin1.decode(pdf);
      expect(s.startsWith('%PDF-1.4'), isTrue);
      expect(s.trimRight().endsWith('%%EOF'), isTrue);
      final int xref = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(s)!.group(1)!,
      );
      expect(s.substring(xref, xref + 4), 'xref');
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'laudo.pdf',
        bytes: pdf,
      );
      expect(c.ok, isTrue);
      expect(c.pages, 1);
    });

    test('páginas contadas sem confundir /Pages', () {
      final Uint8List pdf = Uint8List.fromList(
        latin1.encode(
          '%PDF-1.4\n<< /Type /Pages /Count 2 >>\n<< /Type /Page >>\n'
          '<< /Type/Page >>\n%%EOF',
        ),
      );
      expect(PreVisitRules.check(name: 'a.pdf', bytes: pdf).pages, 2);
    });
  });

  group('mensagens quando o arquivo não pode ser enviado', () {
    test('vazio', () {
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'vazio.png',
        bytes: Uint8List(0),
      );
      expect(c.ok, isFalse);
      expect(c.error, contains('"vazio.png" está vazio'));
    });

    test('maior que 10 MB por arquivo', () {
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'grande.png',
        bytes: pngOfSize(PreVisitRules.maxFileBytes + 1),
      );
      expect(c.error, contains('O limite é 10 MB por arquivo'));
      expect(c.error, contains('"grande.png" tem 10 MB'));
      expect(
        PreVisitRules.check(
          name: 'limite.png',
          bytes: pngOfSize(PreVisitRules.maxFileBytes),
        ).ok,
        isTrue,
      );
    });

    test('soma acima de 40 MB', () {
      final List<PreVisitAttachment> existing = <PreVisitAttachment>[
        for (int i = 0; i < 4; i++)
          att('a$i', pngOfSize(9 * 1024 * 1024 + i)),
      ];
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'mais.png',
        bytes: pngOfSize(5 * 1024 * 1024),
        existing: existing,
      );
      expect(c.error, contains('40 MB por pré-consulta'));
      expect(
        PreVisitRules.check(
          name: 'cabe.png',
          bytes: pngOfSize(3 * 1024 * 1024),
          existing: existing,
        ).ok,
        isTrue,
      );
    });

    test('limite de 10 anexos', () {
      final List<PreVisitAttachment> existing = <PreVisitAttachment>[
        for (int i = 0; i < PreVisitRules.maxFiles; i++)
          att('a$i', solidPng(2 + i, 2)),
      ];
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'onze.png',
        bytes: solidPng(40, 40),
        existing: existing,
      );
      expect(c.error, contains('Limite de 10 anexos'));
    });

    test('HEIC do iPhone explica como enviar', () {
      final Uint8List heic = Uint8List.fromList(<int>[
        0, 0, 0, 0x18, ...'ftypheic'.codeUnits, 0, 0, 0, 0,
      ]);
      final PreVisitFileCheck c = PreVisitRules.check(
        name: 'IMG_0001.HEIC',
        bytes: heic,
      );
      expect(c.error, contains('formato HEIC'));
      expect(c.error, contains('Mais compatível'));
    });

    test('formato não aceito, inclusive com nome enganoso', () {
      final Uint8List txt = Uint8List.fromList(utf8.encode('não é PDF'));
      expect(
        PreVisitRules.check(name: 'nota.docx', bytes: txt).error,
        allOf(
          contains('não é uma imagem JPG, PNG ou WEBP nem um PDF'),
          isNot(contains('embora')),
        ),
      );
      expect(
        PreVisitRules.check(name: 'exame.pdf', bytes: txt).error,
        contains('embora o nome termine como um deles'),
      );
    });

    test('PDF protegido por senha', () {
      final Uint8List pdf = Uint8List.fromList(
        latin1.encode('%PDF-1.7\ntrailer << /Encrypt 5 0 R >>\n%%EOF'),
      );
      expect(
        PreVisitRules.check(name: 'senha.pdf', bytes: pdf).error,
        contains('protegido por senha'),
      );
    });

    test('arquivo repetido', () {
      final Uint8List png = solidPng(8, 8);
      expect(
        PreVisitRules.check(
          name: 'copia.png',
          bytes: Uint8List.fromList(png),
          existing: <PreVisitAttachment>[att('a', png)],
        ).error,
        '"copia.png" já foi anexado nesta pré-consulta.',
      );
    });
  });

  group('tipo e data', () {
    test('foto da queixa precisa ser imagem', () {
      expect(
        PreVisitRules.typeError(PreVisitDocType.fotoQueixa, PreVisitFormat.pdf),
        contains('precisa ser uma imagem'),
      );
      expect(
        PreVisitRules.typeError(PreVisitDocType.laudo, PreVisitFormat.pdf),
        isNull,
      );
      expect(
        PreVisitRules.typeError(PreVisitDocType.exame, PreVisitFormat.jpeg),
        isNull,
      );
    });

    test('data do exame obrigatória, não futura e não antes do nascimento', () {
      expect(
        PreVisitRules.dateError(PreVisitDocType.exame, null, today: today),
        'Informe a data do exame (dd/mm/aaaa).',
      );
      expect(
        PreVisitRules.dateError(PreVisitDocType.relatorio, null, today: today),
        'Informe a data do relatório (dd/mm/aaaa).',
      );
      expect(
        PreVisitRules.dateError(PreVisitDocType.fotoQueixa, null, today: today),
        isNull,
      );
      expect(
        PreVisitRules.dateError(
          PreVisitDocType.laudo,
          DateTime(2026, 9, 29),
          today: today,
        ),
        'A data não pode ser futura.',
      );
      expect(
        PreVisitRules.dateError(
          PreVisitDocType.laudo,
          DateTime(2026, 9, 28, 23, 59),
          today: today,
        ),
        isNull,
      );
      expect(
        PreVisitRules.dateError(
          PreVisitDocType.exame,
          DateTime(2025, 3, 9),
          today: today,
          birth: birth,
        ),
        'A data é anterior ao nascimento da criança.',
      );
      expect(
        PreVisitRules.dateError(
          PreVisitDocType.exame,
          birth,
          today: today,
          birth: birth,
        ),
        isNull,
      );
    });
  });

  test('tamanho legível', () {
    expect(PreVisitRules.sizeLabel(500), '500 B');
    expect(PreVisitRules.sizeLabel(2000), '2 KB');
    expect(PreVisitRules.sizeLabel(1536 * 1024), '1,5 MB');
    expect(PreVisitRules.sizeLabel(10 * 1024 * 1024), '10 MB');
  });

  group('pré-consulta', () {
    test('clínica vê só o enviado, em dois grupos, do mais recente', () {
      final PreVisit v = PreVisit(appointmentId: 'x', patientId: 'p');
      final DateTime sent = DateTime(2026, 9, 27, 10);
      v.attachments.addAll(<PreVisitAttachment>[
        att('fotoAntiga', solidPng(2, 2),
            type: PreVisitDocType.fotoQueixa,
            date: DateTime(2026, 9, 20),
            sentAt: sent),
        att('fotoNova', solidPng(3, 2),
            type: PreVisitDocType.fotoQueixa,
            date: DateTime(2026, 9, 26),
            sentAt: sent),
        att('laudo', solidPng(4, 2),
            type: PreVisitDocType.laudo,
            date: DateTime(2026, 8, 1),
            sentAt: sent),
        att('rascunho', solidPng(5, 2), type: PreVisitDocType.exame),
      ]);
      final List<(String, List<PreVisitAttachment>)> g =
          groupSentAttachments(v);
      expect(g.map(((String, List<PreVisitAttachment>) e) => e.$1), <String>[
        'Fotos da queixa',
        'Exames, laudos e relatórios',
      ]);
      expect(
        g[0].$2.map((PreVisitAttachment a) => a.id),
        <String>['fotoNova', 'fotoAntiga'],
      );
      expect(g[1].$2.map((PreVisitAttachment a) => a.id), <String>['laudo']);
    });

    test('alterações não enviadas: rascunho, anexo novo ou texto mudado', () {
      final PreVisit v = PreVisit(appointmentId: 'x', patientId: 'p');
      expect(v.hasUnsentChanges, isFalse);
      expect(v.hasContent, isFalse);
      v.answers = const PreVisitAnswers(reason: 'Febre');
      expect(v.hasUnsentChanges, isTrue);
      v
        ..sentAnswers = v.answers
        ..sentAt = today;
      expect(v.hasUnsentChanges, isFalse);
      v.attachments.add(att('novo', solidPng(2, 2)));
      expect(v.hasUnsentChanges, isTrue);
      v.attachments.single.sentAt = today;
      expect(v.hasUnsentChanges, isFalse);
      v.answers = const PreVisitAnswers(reason: 'Febre há 2 dias');
      expect(v.hasUnsentChanges, isTrue);
    });
  });
}
