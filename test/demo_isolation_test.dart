import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A demonstracao web nao pode alcancar Firebase, rede, IA, pagamentos nem
/// codigo de `lib/features/` (onde vivem repositorios com acesso a dados).
///
/// O teste segue todas as importacoes relativas a partir de
/// `lib/main_demo.dart` e exige que todo pacote externo esteja numa lista
/// fechada de pacotes de apresentacao.
void main() {
  const Set<String> allowedPackages = <String>{
    'flutter',
    'flutter_localizations',
    'go_router',
    'google_fonts',
    'flutter_svg',
    'lottie',
    'equatable',
    'shimmer',
    'pediatria360',
  };

  final RegExp importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true);

  Set<String> collectGraph() {
    final Set<String> visited = <String>{};
    final List<String> queue = <String>[File('lib/main_demo.dart').absolute.path];
    while (queue.isNotEmpty) {
      final String path = File(queue.removeLast()).absolute.path;
      if (!visited.add(path)) continue;
      final String source = File(path).readAsStringSync();
      for (final RegExpMatch m in importRe.allMatches(source)) {
        final String uri = m.group(1)!;
        if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
        queue.add(File(path).parent.uri.resolve(uri).toFilePath());
      }
    }
    return visited;
  }

  test('grafo da demo so usa pacotes de apresentacao', () {
    final Set<String> files = collectGraph();
    final List<String> violations = <String>[];
    for (final String path in files) {
      final String source = File(path).readAsStringSync();
      for (final RegExpMatch m in importRe.allMatches(source)) {
        final String uri = m.group(1)!;
        if (!uri.startsWith('package:')) continue;
        final String pkg = uri.substring('package:'.length).split('/').first;
        if (!allowedPackages.contains(pkg)) violations.add('$path -> $uri');
      }
    }
    expect(violations, isEmpty,
        reason: 'A demo passou a importar pacotes fora da lista.');
  });

  test('grafo da demo nao alcanca features nem configuracao do Firebase', () {
    final Iterable<String> bad = collectGraph()
        .map((String p) => p.replaceAll(r'\', '/'))
        .where((String p) =>
            p.contains('/lib/features/') ||
            p.contains('firebase') ||
            p.contains('/services/') ||
            p.contains('/providers/'));
    expect(bad, isEmpty);
  });
}
