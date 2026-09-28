import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/branding/brand_logo.dart';
import 'package:pediatria360/shared/branding/brand_pdf.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/clinical_pdf.dart';

import 'support/png_fixture.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 28, 10);

  group('conferência do arquivo', () {
    test('PNG e JPG aceitos, lidos pelo conteúdo', () {
      final LogoInspection png = BrandLogoRules.inspect(solidPng(300, 100));
      expect(png.ok, isTrue);
      expect(png.format, LogoFormat.png);
      expect((png.width, png.height), (300, 100));

      final LogoInspection jpg = BrandLogoRules.inspect(jpegHeader(640, 200));
      expect(jpg.ok, isTrue);
      expect(jpg.format, LogoFormat.jpeg);
      expect((jpg.width, jpg.height), (640, 200));
    });

    test('SVG, texto e arquivo vazio são recusados', () {
      final Uint8List svg = Uint8List.fromList(
        utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
      );
      expect(
        BrandLogoRules.inspect(svg).problems.single,
        contains('Formato não aceito'),
      );
      expect(
        BrandLogoRules.inspect(Uint8List(0)).problems.single,
        'Arquivo vazio.',
      );
    });

    test('dimensões e tamanho fora do limite', () {
      expect(
        BrandLogoRules.inspect(solidPng(10, 10)).problems.single,
        contains('pequena demais (10 x 10 px)'),
      );
      expect(
        BrandLogoRules.inspect(pngHeaderOnly(5000, 300)).problems.single,
        contains('grande demais (5000 x 300 px)'),
      );
      final Uint8List big = Uint8List(BrandLogoRules.maxBytes + 1024)
        ..setAll(0, solidPng(100, 100));
      expect(
        BrandLogoRules.inspect(big).problems.single,
        contains('o limite é 2 MB'),
      );
    });

    test('imagem corrompida não entra no PDF', () async {
      expect(await BrandPdf.canEmbed(solidPng(120, 60)), isTrue);
      expect(await BrandPdf.canEmbed(pngHeaderOnly(120, 60)), isFalse);
    });
  });

  group('vínculo com a conta', () {
    BrandLogo upload(BrandLogoStore s, String owner, String id) => s.upload(
      actorId: owner,
      ownerId: owner,
      logoId: id,
      bytes: solidPng(200, 80),
      fileName: '$id.png',
      uploadedBy: owner,
      now: now,
    );

    test('só a própria conta envia, vê, troca e remove', () {
      final BrandLogoStore s = BrandLogoStore();
      upload(s, 'a', 'l1');
      expect(s.currentFor(ownerId: 'a', viewerId: 'a')!.id, 'l1');
      expect(s.currentFor(ownerId: 'a', viewerId: 'b'), isNull);
      expect(s.currentFor(ownerId: 'b', viewerId: 'b'), isNull);
      expect(
        () => s.upload(
          actorId: 'b',
          ownerId: 'a',
          logoId: 'x',
          bytes: solidPng(200, 80),
          fileName: 'x.png',
          uploadedBy: 'b',
          now: now,
        ),
        throwsA(isA<BrandingException>()),
      );
      expect(
        () => s.remove(actorId: 'b', ownerId: 'a'),
        throwsA(isA<BrandingException>()),
      );
      expect(s.currentFor(ownerId: 'a', viewerId: 'a')!.id, 'l1');

      upload(s, 'a', 'l2');
      expect(s.currentFor(ownerId: 'a', viewerId: 'a')!.id, 'l2');
      s.remove(actorId: 'a', ownerId: 'a');
      expect(s.currentFor(ownerId: 'a', viewerId: 'a'), isNull);
    });

    test('arquivo inválido não substitui a logomarca atual', () {
      final BrandLogoStore s = BrandLogoStore();
      upload(s, 'a', 'l1');
      expect(
        () => s.upload(
          actorId: 'a',
          ownerId: 'a',
          logoId: 'l2',
          bytes: Uint8List.fromList(utf8.encode('não é imagem')),
          fileName: 'logo.svg',
          uploadedBy: 'a',
          now: now,
        ),
        throwsA(
          isA<BrandingException>().having(
            (BrandingException e) => e.problems.single,
            'problems',
            contains('PNG ou JPG'),
          ),
        ),
      );
      expect(s.currentFor(ownerId: 'a', viewerId: 'a')!.id, 'l1');
    });

    test('documento emitido guarda a logomarca da emissão', () {
      final BrandLogoStore s = BrandLogoStore();
      upload(s, 'a', 'l1');
      // Rascunho: logomarca vigente, só para o dono.
      expect(
        s.forDocument(ownerId: 'a', viewerId: 'a', issued: false)!.id,
        'l1',
      );
      expect(s.forDocument(ownerId: 'a', viewerId: 'b', issued: false), isNull);

      upload(s, 'a', 'l2');
      s.remove(actorId: 'a', ownerId: 'a');
      expect(
        s
            .forDocument(
              ownerId: 'a',
              viewerId: 'a',
              issued: true,
              issuedLogoId: 'l1',
            )!
            .id,
        'l1',
      );
      // Emitido sem logomarca: identidade padrão.
      expect(s.forDocument(ownerId: 'a', viewerId: 'a', issued: true), isNull);
      // A logomarca de outra conta nunca vai num documento alheio.
      upload(s, 'b', 'lb');
      expect(
        s.forDocument(
          ownerId: 'a',
          viewerId: 'a',
          issued: true,
          issuedLogoId: 'lb',
        ),
        isNull,
      );
      expect(s.forDocument(ownerId: 'a', viewerId: 'a', issued: false), isNull);
    });
  });

  group('documentos', () {
    final DocContext ctx = DocContext(
      patientName: 'Criança Exemplo',
      professionalName: 'Dra. Exemplo',
      professionalRegistry: 'CRM 0 (fictício)',
      clinicName: 'Clínica Exemplo',
      date: DateTime(2026, 9, 28),
    );

    ClinicalDocRecord draft() => ClinicalDocRecord.createDraft(
      id: 'd1',
      kind: DocKind.orientacoes,
      patientId: 'p1',
      ownerId: 'a',
      author: 'Dra. Exemplo',
      context: ctx,
      now: now,
      fields: const <String, String>{'titulo': 'Teste', 'texto': 'Texto.'},
    );

    test('emissão grava a logomarca; a versão seguinte não herda', () {
      final ClinicalDocRecord issued = draft()
          .markReviewed(reviewer: 'Dra. Exemplo', now: now)
          .issue(now: now, logoId: 'l1');
      expect(issued.ownerId, 'a');
      expect(issued.current.logoId, 'l1');
      final ClinicalDocRecord v2 = issued.saveDraft(
        fields: const <String, String>{'titulo': 'Teste', 'texto': 'Novo.'},
        items: const <RxItem>[],
        context: ctx,
        author: 'Dra. Exemplo',
        now: now,
      );
      expect(v2.ownerId, 'a');
      expect(v2.current.logoId, isNull);
      expect(v2.upTo(0).current.logoId, 'l1');
    });

    test('PDF leva a imagem da logomarca no cabeçalho', () async {
      final Uint8List plain = await ClinicalPdf.build(
        doc: draft(),
        context: ctx,
        now: now,
      );
      final Uint8List branded = await ClinicalPdf.build(
        doc: draft(),
        context: ctx,
        now: now,
        logo: solidPng(240, 80),
      );
      final String a = latin1.decode(plain), b = latin1.decode(branded);
      expect(a.startsWith('%PDF-'), isTrue);
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(a), isFalse);
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(b), isTrue);
      expect(RegExp(r'/Width\s*240\b').hasMatch(b), isTrue);
    });
  });
}
