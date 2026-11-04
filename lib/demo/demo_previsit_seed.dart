import 'dart:convert';
import 'dart:typed_data';

import '../shared/previsit/pre_visit.dart';

/// Pré-consultas fictícias. Imagem desenhada para a demonstração e PDF
/// gerado aqui, sem dados de pacientes.
class DemoPreVisitSeed {
  const DemoPreVisitSeed._();

  static Uint8List samplePhoto() => base64Decode(_photo);

  /// PDF de uma página com texto simples (Helvetica, WinAnsi).
  static Uint8List samplePdf({
    String title = 'Laudo fictício de exemplo',
    List<String> lines = const <String>[
      'Documento gerado para a demonstração do Pedi360.',
      'Não contém dados de pacientes nem resultado real.',
    ],
  }) {
    String esc(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
    final StringBuffer content = StringBuffer()
      ..write('BT /F1 18 Tf 56 770 Td (${esc(title)}) Tj ET\n');
    double y = 740;
    for (final String l in lines) {
      content.write('BT /F1 12 Tf 56 ${y.toStringAsFixed(0)} Td (${esc(l)}) Tj ET\n');
      y -= 18;
    }
    final List<int> stream = latin1.encode(content.toString());
    final List<String> objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
          '/Encoding /WinAnsiEncoding >>',
    ];
    final BytesBuilder out = BytesBuilder();
    final List<int> offsets = <int>[];
    out.add(latin1.encode('%PDF-1.4\n'));
    for (int i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.add(latin1.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
    }
    offsets.add(out.length);
    out
      ..add(latin1.encode('5 0 obj\n<< /Length ${stream.length} >>\nstream\n'))
      ..add(stream)
      ..add(latin1.encode('\nendstream\nendobj\n'));
    final int xref = out.length;
    final StringBuffer tail = StringBuffer('xref\n0 6\n0000000000 65535 f \n');
    for (final int o in offsets) {
      tail.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    tail.write('trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    out.add(latin1.encode(tail.toString()));
    return out.toBytes();
  }

  /// Consulta de hoje da Luna (a1) com pré-consulta já enviada.
  static Map<String, PreVisit> seed(DateTime now) {
    final DateTime sent = now.subtract(const Duration(hours: 20));
    final PreVisit v = PreVisit(appointmentId: 'a1', patientId: 'p1')
      ..answers = const PreVisitAnswers(
        reason: 'Mancha avermelhada no braço (exemplo fictício)',
        symptoms: 'Apareceu há 3 dias, sem febre. Coça um pouco à noite.',
        medications: 'Nenhum',
      )
      ..sentAt = sent;
    v.sentAnswers = v.answers;
    final Uint8List photo = samplePhoto();
    final Uint8List pdf = samplePdf();
    v.attachments.addAll(<PreVisitAttachment>[
      PreVisitAttachment(
        id: 'pa1',
        name: 'foto_braco.png',
        format: PreVisitFormat.png,
        bytes: photo,
        type: PreVisitDocType.fotoQueixa,
        addedAt: sent,
        date: DateTime(now.year, now.month, now.day - 1),
        description: 'Mancha no braço (fictícia)',
        sentAt: sent,
      ),
      PreVisitAttachment(
        id: 'pa2',
        name: 'laudo_hemograma.pdf',
        format: PreVisitFormat.pdf,
        bytes: pdf,
        type: PreVisitDocType.laudo,
        addedAt: sent,
        date: DateTime(now.year, now.month, now.day - 10),
        description: 'Hemograma (fictício)',
        pages: 1,
        sentAt: sent,
      ),
    ]);
    v.history.add(
      PreVisitEvent(sent, 'Enviada pela família com 2 anexos'),
    );
    return <String, PreVisit>{'a1': v};
  }

  static const String _photo =
  'iVBORw0KGgoAAAANSUhEUgAAAUAAAADcCAYAAAABQ3gmAAAAAXNSR0IArs4c6QAAAARnQU1B'
  'AACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAxySURBVHhe7d3vrxRXHcdx/gj/iPu3'
  'mDTRR8Q/QNuo18pVCkWUCrlo8QeFEqpBUWorsaE0NkYTlXJbSgFpTXujhDbYglpt1Ac+8UHT'
  'pON+h/1xdvY7d3dnz/w483k/eBW6O3vmzNk9H878OrPrP2+8mAGAIgIQgCwCEIAsAhCALAIQ'
  'gCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAs'
  'AhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQ'
  'gCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAs'
  'AhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQ'
  'gCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQgCwCEIAsAhCALAIQrfv3zV9m'
  '7196tpS9730OWBUBiNp9cO357K+/OZfdee509uczx3J//P5j2RvHDi7NPjcqw8qzcq18b73A'
  'PAQgonv/8s+zd184k91++nj21skjbpDFZuux9dl6bf1evYAiAhBR/O23P8sDyAunttz6yfey'
  'e7/+qVtfwBCAqMx2Pf/y/A8aG+VV9eYTh/Pd5Q+uXnC3A7oIQCyti6O9Rdmxw3u/OsuJFeQI'
  'QCzMTjjYaMoLltTYyRQ7XuhtJ3QQgJjrH1vn85GTFySp2z61mY9ove1G/xGAKPWvGxezt589'
  '6QZH39gJE44R6iEA4bLdw6rX6iXru9/I7lx4iuODQghATLFRX193dxe1ffooo0ERBCDGrNNv'
  'n9p0Q0GNneyxY59eO6E/CEDk7O4JuV3eeQa7xHbm22sv9AMBiPxuCevsbgiAy2V6jAAUZ3dy'
  'eJ0e0+xsuNd+SBsBKOzuiz9yOzt8djud145IFwEoyi7+Zbd3eXYbndeeSBMBKMjO9nLCo6LB'
  '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';
}
