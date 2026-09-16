import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/domain/entities/content.dart';

void main() {
  group('normalização para busca', () {
    test('remove acentos', () {
      expect(normalizeForSearch('Amamentação'), 'amamentacao');
      expect(normalizeForSearch('Convulsão febril'), 'convulsao febril');
      expect(normalizeForSearch('Icterícia'), 'ictericia');
    });

    test('caixa baixa e pontuação viram espaço', () {
      expect(normalizeForSearch('FEBRE: quando agir?'), 'febre quando agir');
    });

    test('colapsa espaços', () {
      expect(normalizeForSearch('  bebê   chorando  '), 'bebe chorando');
    });

    test('cedilha e til', () {
      expect(normalizeForSearch('Ação; coração'), 'acao coracao');
    });
  });

  group('tokens da busca', () {
    test('descarta palavras com menos de 3 letras', () {
      expect(searchTokens('o meu bebe tem febre'), <String>['meu', 'bebe', 'tem', 'febre']);
    });

    test('consulta curta não gera token', () {
      expect(searchTokens('oi'), isEmpty);
    });

    test('limita a 10 termos para caber no array-contains-any', () {
      final String longQuery =
          List<String>.generate(20, (int i) => 'termo$i').join(' ');
      expect(searchTokens(longQuery).length, 10);
    });
  });

  group('audiência do conteúdo', () {
    test('nome desconhecido cai no padrão mais restritivo de leitura', () {
      expect(ContentAudience.fromName('inexistente'), ContentAudience.everyone);
    });
  });

  group('faixa etária', () {
    Content build({(int, int)? range}) => Content(
          id: 'c1',
          title: 'Teste',
          summary: '',
          type: ContentType.article,
          audience: ContentAudience.everyone,
          category: 'febre',
          updatedAt: DateTime.now(),
          ageRangeMonths: range,
        );

    test('sem faixa vale para qualquer idade', () {
      expect(build().appliesToAge(0), isTrue);
      expect(build().appliesToAge(200), isTrue);
    });

    test('respeita os limites, inclusive', () {
      final Content c = build(range: (0, 24));
      expect(c.appliesToAge(0), isTrue);
      expect(c.appliesToAge(24), isTrue);
      expect(c.appliesToAge(25), isFalse);
    });
  });

  group('seções', () {
    test('detecta posologia e sinais de alarme', () {
      final Content c = Content(
        id: 'c1',
        title: 'Febre',
        summary: '',
        type: ContentType.protocol,
        audience: ContentAudience.professionals,
        category: 'febre',
        updatedAt: DateTime.now(),
        sections: const <ContentSection>[
          ContentSection(title: 'Conduta', body: '...'),
          ContentSection(
            title: 'Procure atendimento',
            body: '...',
            kind: SectionKind.redFlag,
          ),
          ContentSection(
            title: 'Posologia',
            body: '...',
            kind: SectionKind.dosage,
          ),
        ],
      );

      expect(c.hasDosage, isTrue);
      expect(c.redFlags.length, 1);
      expect(c.isProtocol, isTrue);
    });
  });
}
