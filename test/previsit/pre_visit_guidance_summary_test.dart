import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/previsit/pre_visit.dart';
import 'package:pediatria360/shared/previsit/pre_visit_guidance.dart';
import 'package:pediatria360/shared/previsit/pre_visit_summary.dart';

void main() {
  group('orientações antes da consulta', () {
    test('categoria pelo tipo; teleconsulta vale mais que o tipo', () {
      expect(
        VisitCategory.classify(label: 'Retorno (exemplo)'),
        VisitCategory.retorno,
      );
      expect(
        VisitCategory.classify(label: 'Consulta de rotina (exemplo)'),
        VisitCategory.rotina,
      );
      expect(
        VisitCategory.classify(label: 'Puericultura'),
        VisitCategory.rotina,
      );
      expect(
        VisitCategory.classify(label: 'Avaliação (exemplo)'),
        VisitCategory.queixa,
      );
      expect(
        VisitCategory.classify(label: 'Retorno', telehealth: true),
        VisitCategory.teleconsulta,
      );
    });

    test('itens gerais mais os da categoria, sem repetir', () {
      final PreVisitGuidance g = PreVisitGuidance();
      final List<String> items = g.itemsFor(VisitCategory.teleconsulta);
      expect(items.first, PreVisitGuidanceRules.defaultGeneral.first);
      expect(items, contains(startsWith('Teste a conexão')));
      expect(items.toSet().length, items.length);
      expect(g.isReviewed, isFalse);
    });

    test('edição normaliza, valida e marca a revisão', () {
      final PreVisitGuidance g = PreVisitGuidance().edited(
        general: <String>['  Leve a caderneta.  ', '', 'Leve a caderneta.'],
        byCategory: <VisitCategory, List<String>>{
          VisitCategory.retorno: <String>['Leve os exames.'],
        },
        reviewer: 'Profissional Fictício',
        now: DateTime(2026, 9, 1),
      );
      expect(g.general, <String>['Leve a caderneta.']);
      expect(g.byCategory[VisitCategory.rotina], isEmpty);
      expect(g.itemsFor(VisitCategory.retorno), <String>[
        'Leve a caderneta.',
        'Leve os exames.',
      ]);
      expect(g.isReviewed, isTrue);

      expect(
        () => PreVisitGuidance().edited(
          general: List<String>.generate(9, (int i) => 'Item $i'),
          byCategory: const <VisitCategory, List<String>>{},
          reviewer: 'P',
          now: DateTime(2026, 9, 1),
        ),
        throwsArgumentError,
      );
      expect(PreVisitGuidanceRules.validate(<String>['x' * 201]), isNotNull);
    });
  });

  group('resumo organizado da pré-consulta', () {
    PreVisitAttachment att(
      String id,
      PreVisitDocType type, {
      DateTime? date,
      bool sent = true,
    }) => PreVisitAttachment(
      id: id,
      name: '$id.pdf',
      format: PreVisitFormat.pdf,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      type: type,
      addedAt: DateTime(2026, 9, 1),
      date: date,
      sentAt: sent ? DateTime(2026, 9, 1) : null,
    );

    test('separa em tópicos, conta anexos enviados e aponta datas', () {
      final PreVisit v = PreVisit(appointmentId: 'a1', patientId: 'p1')
        ..sentAnswers = const PreVisitAnswers(
          reason: 'Tosse fictícia',
          symptoms: 'Tosse há 3 dias; febre baixa.\n- Coriza',
          medications: 'Medicamento Exemplo A',
        )
        ..sentAt = DateTime(2026, 9, 1);
      v.attachments.addAll(<PreVisitAttachment>[
        att('f1', PreVisitDocType.fotoQueixa),
        att('e1', PreVisitDocType.exame, date: DateTime(2026, 1, 10)),
        att('e2', PreVisitDocType.exame, date: DateTime(2026, 8, 20)),
        att('r1', PreVisitDocType.relatorio, sent: false),
      ]);
      final PreVisitSummary s = PreVisitSummary.of(
        v,
        visitDate: DateTime(2026, 9, 5),
      );
      expect(s.sections.map((PreVisitSummarySection x) => x.title), <String>[
        'Motivo informado',
        'Sintomas e evolução',
        'Medicamentos em uso',
      ]);
      expect(s.sections[1].items, <String>[
        'Tosse há 3 dias',
        'febre baixa',
        'Coriza',
      ]);
      expect(s.attachmentLine, '1 foto da queixa e 2 exames');
      expect(s.checks, contains(startsWith('Conferir com a família')));
      expect(s.checks, contains('Exame de 10/01/2026 tem mais de 6 meses.'));
      expect(s.checks.where((String c) => c.contains('20/08/2026')), isEmpty);
      expect(s.checks.last, startsWith('Abrir os arquivos originais'));
    });

    test('não interpreta: nenhuma hipótese, conduta ou dose no resumo', () {
      final PreVisit v = PreVisit(appointmentId: 'a1', patientId: 'p1')
        ..sentAnswers = const PreVisitAnswers(reason: 'Febre fictícia')
        ..sentAt = DateTime(2026, 9, 1);
      final PreVisitSummary s = PreVisitSummary.of(
        v,
        visitDate: DateTime(2026, 9, 1),
      );
      final String all = <String>[
        for (final PreVisitSummarySection x in s.sections) ...x.items,
        ...s.checks,
      ].join(' ').toLowerCase();
      for (final String w in <String>[
        'hipótese',
        'diagnóstico',
        'dose',
        'mg',
      ]) {
        expect(all.contains(w), isFalse, reason: w);
      }
      expect(PreVisitSummary.notice, contains('sem IA'));
    });

    test('"Nenhum" medicamento não pede conferência de dose', () {
      for (final String m in <String>['Nenhum', 'não usa.', '  ']) {
        final PreVisit v = PreVisit(appointmentId: 'a1', patientId: 'p1')
          ..sentAnswers = PreVisitAnswers(reason: 'Motivo', medications: m)
          ..sentAt = DateTime(2026, 9, 1);
        expect(
          PreVisitSummary.of(v, visitDate: DateTime(2026, 9, 1)).checks,
          isEmpty,
          reason: m,
        );
      }
    });

    test('pré-consulta vazia gera resumo vazio', () {
      final PreVisit v = PreVisit(appointmentId: 'a1', patientId: 'p1')
        ..sentAnswers = const PreVisitAnswers()
        ..sentAt = DateTime(2026, 9, 1);
      expect(
        PreVisitSummary.of(v, visitDate: DateTime(2026, 9, 1)).isEmpty,
        isTrue,
      );
    });
  });
}
