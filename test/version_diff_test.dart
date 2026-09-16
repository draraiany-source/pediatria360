import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/admin/data/admin_content_repository.dart';

Map<String, dynamic> snapshot({
  String title = 'Febre',
  String summary = 'Resumo original',
  String audience = 'everyone',
  List<Map<String, String>> sections = const <Map<String, String>>[
    <String, String>{'title': 'O que é', 'body': 'Texto A'},
    <String, String>{'title': 'O que fazer', 'body': 'Texto B'},
  ],
}) =>
    <String, dynamic>{
      'title': title,
      'summary': summary,
      'audience': audience,
      'category': 'febre',
      'type': 'article',
      'sections': sections,
    };

void main() {
  group('comparação entre versões', () {
    test('versões idênticas não acusam mudança', () {
      final VersionDiff diff = VersionDiff.between(snapshot(), snapshot());
      expect(diff.isEmpty, isTrue);
      expect(diff.totalChanges, 0);
    });

    test('detecta mudança de título', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(),
        snapshot(title: 'Febre na criança'),
      );
      expect(diff.changedFields, contains('Título'));
      expect(diff.totalChanges, 1);
    });

    test('detecta mudança de público — a mais crítica', () {
      // Passar um conteúdo de "profissionais" para "todos" expõe posologia a
      // responsáveis. Precisa saltar aos olhos no histórico.
      final VersionDiff diff = VersionDiff.between(
        snapshot(audience: 'professionals'),
        snapshot(audience: 'everyone'),
      );
      expect(diff.changedFields, contains('Público'));
    });

    test('detecta seção adicionada', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(),
        snapshot(
          sections: const <Map<String, String>>[
            <String, String>{'title': 'O que é', 'body': 'Texto A'},
            <String, String>{'title': 'O que fazer', 'body': 'Texto B'},
            <String, String>{'title': 'Sinais de alarme', 'body': 'Texto C'},
          ],
        ),
      );
      expect(diff.sectionsAdded, <String>['Sinais de alarme']);
      expect(diff.sectionsRemoved, isEmpty);
    });

    test('detecta seção removida', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(),
        snapshot(
          sections: const <Map<String, String>>[
            <String, String>{'title': 'O que é', 'body': 'Texto A'},
          ],
        ),
      );
      expect(diff.sectionsRemoved, <String>['O que fazer']);
    });

    test('detecta corpo de seção alterado', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(),
        snapshot(
          sections: const <Map<String, String>>[
            <String, String>{'title': 'O que é', 'body': 'Texto A revisado'},
            <String, String>{'title': 'O que fazer', 'body': 'Texto B'},
          ],
        ),
      );
      expect(diff.sectionsChanged, <String>['O que é']);
      expect(diff.sectionsAdded, isEmpty);
      expect(diff.sectionsRemoved, isEmpty);
    });

    test('acumula várias mudanças', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(),
        snapshot(
          title: 'Novo título',
          summary: 'Novo resumo',
          sections: const <Map<String, String>>[
            <String, String>{'title': 'O que é', 'body': 'Alterado'},
            <String, String>{'title': 'Nova seção', 'body': 'C'},
          ],
        ),
      );
      // 2 campos + 1 seção alterada + 1 adicionada + 1 removida
      expect(diff.totalChanges, 5);
      expect(diff.isEmpty, isFalse);
    });

    test('instantâneo vazio não quebra', () {
      final VersionDiff diff =
          VersionDiff.between(const <String, dynamic>{}, snapshot());
      expect(diff.isEmpty, isFalse);
      expect(diff.sectionsAdded.length, 2);
    });

    test('conteúdo sem seções não quebra', () {
      final VersionDiff diff = VersionDiff.between(
        snapshot(sections: const <Map<String, String>>[]),
        snapshot(sections: const <Map<String, String>>[]),
      );
      expect(diff.isEmpty, isTrue);
    });
  });
}
