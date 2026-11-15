import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/family_release.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 1, 10);
  final DocContext ctx = DocContext(
    patientName: 'Criança Fictícia',
    professionalName: 'Profissional Fictício',
    professionalRegistry: 'CRM 0000',
    clinicName: 'Clínica Fictícia',
    date: DateTime(2026, 9, 1),
  );

  ClinicalDocRecord draft() => ClinicalDocRecord.createDraft(
    id: 'x1',
    kind: DocKind.orientacoes,
    patientId: 'p1',
    author: 'Profissional Fictício',
    context: ctx,
    now: now,
    fields: <String, String>{'titulo': 'Sono', 'texto': 'Texto fictício.'},
  );

  ClinicalDocRecord issued() => draft()
      .markReviewed(reviewer: 'Profissional Fictício', now: now, context: ctx)
      .issue(now: now);

  FamilyRelease released(String id) =>
      FamilyRelease(id)
        ..events.add(FamilyReleaseEvent(at: now, actor: 'P', released: true));

  group('liberação para a família', () {
    test('rascunho e documento revisado não podem ser liberados', () {
      expect(
        FamilyReleaseRules.blockToRelease(draft(), isOwner: true),
        contains('Emita'),
      );
      final ClinicalDocRecord reviewed = draft().markReviewed(
        reviewer: 'P',
        now: now,
        context: ctx,
      );
      expect(
        FamilyReleaseRules.blockToRelease(reviewed, isOwner: true),
        contains('Emita'),
      );
    });

    test('só quem emitiu libera ou retira', () {
      expect(
        FamilyReleaseRules.blockToRelease(issued(), isOwner: false),
        contains('Só quem emitiu'),
      );
      expect(
        FamilyReleaseRules.blockToRevoke(
          issued(),
          isOwner: false,
          reason: 'Motivo suficiente',
          current: released('x1'),
        ),
        contains('Só quem emitiu'),
      );
      expect(
        FamilyReleaseRules.blockToRelease(issued(), isOwner: true),
        isNull,
      );
    });

    test('retirar exige motivo e documento liberado', () {
      expect(
        FamilyReleaseRules.blockToRevoke(
          issued(),
          isOwner: true,
          reason: 'Motivo suficiente',
        ),
        contains('não está liberado'),
      );
      expect(
        FamilyReleaseRules.blockToRevoke(
          issued(),
          isOwner: true,
          reason: ' ab ',
          current: released('x1'),
        ),
        contains('motivo'),
      );
    });

    test('família vê só a última versão emitida, e só se liberado', () {
      final ClinicalDocRecord v1 = issued();
      expect(FamilyReleaseRules.visibleToFamily(v1, null), isNull);
      final FamilyRelease r = released('x1');
      expect(FamilyReleaseRules.visibleToFamily(v1, r)!.current.number, 1);

      // Nova versão em rascunho: a família continua na versão 1.
      final ClinicalDocRecord v2 = v1.saveDraft(
        fields: <String, String>{'titulo': 'Sono', 'texto': 'Texto novo.'},
        items: const <RxItem>[],
        context: ctx,
        author: 'P',
        now: now,
      );
      expect(v2.versions, hasLength(2));
      final ClinicalDocRecord seen = FamilyReleaseRules.visibleToFamily(v2, r)!;
      expect(seen.current.number, 1);
      expect(seen.current.fields['texto'], 'Texto fictício.');

      // Retirada: some de novo.
      r.events.add(
        FamilyReleaseEvent(at: now, actor: 'P', released: false, reason: 'x'),
      );
      expect(r.isReleased, isFalse);
      expect(r.lastRelease, isNotNull);
      expect(FamilyReleaseRules.visibleToFamily(v2, r), isNull);
    });

    test('orientações sugerem liberar na emissão; os demais tipos não', () {
      expect(
        FamilyReleaseRules.releaseOnIssueByDefault(DocKind.orientacoes),
        isTrue,
      );
      for (final DocKind k in DocKind.values) {
        if (k == DocKind.orientacoes) continue;
        expect(FamilyReleaseRules.releaseOnIssueByDefault(k), isFalse);
      }
    });

    test('todo tipo de documento tem grupo no pós-consulta', () {
      for (final DocKind k in DocKind.values) {
        expect(FamilyReleaseRules.groupOf(k), isNotEmpty);
      }
      expect(FamilyReleaseRules.groupOf(DocKind.receituario), 'Receitas');
      expect(
        FamilyReleaseRules.groupOf(DocKind.comparecimento),
        'Atestados e declarações',
      );
    });
  });
}
