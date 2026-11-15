import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/clinical/clinical_documents.dart';
import 'package:pediatria360/shared/clinical/growth.dart';
import 'package:pediatria360/shared/clinical/orientation_templates.dart';
import 'package:pediatria360/shared/wellchild/age_band.dart';
import 'package:pediatria360/shared/wellchild/guidance_examples.dart';
import 'package:pediatria360/shared/wellchild/milestones.dart';
import 'package:pediatria360/shared/wellchild/well_child_pdf.dart';
import 'package:pediatria360/shared/wellchild/well_child_templates.dart';
import 'package:pediatria360/shared/wellchild/well_child_visit.dart';

import '../support/png_fixture.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 28, 10);

  group('idade da consulta', () {
    test('termo: só a idade cronológica', () {
      final VisitAge a = VisitAge.of(
        birthDate: DateTime(2025, 7, 3),
        at: now,
        gestationalAgeDays: 39 * 7,
      );
      expect(a.usesCorrected, isFalse);
      expect(a.label, 'Idade: 14 meses e 25 dias.');
      expect(a.band, ChildAgeBand.de1a2a);
    });

    test('prematuro: idade corrigida identificada e usada na faixa', () {
      final VisitAge a = VisitAge.of(
        birthDate: DateTime(2025, 12, 1),
        at: now,
        gestationalAgeDays: 30 * 7,
      );
      expect(a.usesCorrected, isTrue);
      expect(a.chronologicalLabel, '9 meses e 27 dias');
      expect(a.correctedLabel, '7 meses e 19 dias');
      expect(a.band, ChildAgeBand.de4a11m);
      expect(a.label, contains('Idade corrigida: 7 meses'));
      expect(a.label, contains('nascimento com 30 semanas'));
      expect(a.shortLabel, contains('(corrigida: 7 meses'));
    });

    test('faixas', () {
      expect(ChildAgeBand.forMonths(0), ChildAgeBand.ate3m);
      expect(ChildAgeBand.forMonths(3), ChildAgeBand.ate3m);
      expect(ChildAgeBand.forMonths(4), ChildAgeBand.de4a11m);
      expect(ChildAgeBand.forMonths(12), ChildAgeBand.de1a2a);
      expect(ChildAgeBand.forMonths(36), ChildAgeBand.de3a5a);
      expect(ChildAgeBand.forMonths(100), ChildAgeBand.de6a);
    });
  });

  group('consulta de puericultura', () {
    test('edição grava o que mudou e a versão anterior', () {
      const WellChildVisit v0 = WellChildVisit();
      final WellChildVisit v1 = v0.revised(
        v0
            .withField(WellChildSection.sono, 'Dorme no berço.')
            .copyWith(nextVisit: () => DateTime(2026, 11, 3)),
        author: 'Dra. Exemplo',
        at: now,
      );
      expect(v1.history.single.changes, <String>['Sono', 'Próxima consulta']);
      expect(v1.history.single.before!.field(WellChildSection.sono), '');
      expect(identical(v1.revised(v1, author: 'x', at: now), v1), isTrue);

      final WellChildVisit v2 = v1.revised(
        v1.withField(WellChildSection.sono, 'Dorme no berço, 2 despertares.'),
        author: 'Dra. Exemplo',
        at: now.add(const Duration(hours: 1)),
        action: 'Corrigido após finalizar',
        reason: 'Informação completada',
      );
      expect(v2.history, hasLength(2));
      expect(
        WellChildVisit.historyLine(v2.history.last),
        '28/09/2026 11:00 - Corrigido após finalizar por Dra. Exemplo: Sono '
        '(motivo: Informação completada)',
      );
      expect(
        v2.history.last.before!.field(WellChildSection.sono),
        'Dorme no berço.',
      );
    });

    test('para finalizar: avaliação, plano e nada entre colchetes', () {
      final WellChildVisit v = const WellChildVisit()
          .withField(WellChildSection.sono, '[preencher]')
          .copyWith(guidance: 'Retorno em [a definir]');
      expect(v.missingToFinish, <String>[
        'Avaliação',
        'Plano de acompanhamento',
      ]);
      expect(v.placeholders, <String>['Sono', 'Orientações dadas']);
    });

    test('dado da família entra no campo e fica registrado', () {
      final WellChildVisit v = const WellChildVisit()
          .withField(WellChildSection.sono, 'Relato na consulta.')
          .incorporate(
            FamilyImport(
              section: WellChildSection.sono,
              source: 'Diário do sono',
              period: '21/09/2026 a 27/09/2026',
              text: 'Diário do sono informado pela família: média 9h30.',
              reviewedBy: 'Dra. Exemplo',
              at: now,
            ),
          );
      expect(
        v.field(WellChildSection.sono),
        'Relato na consulta.\n\nDiário do sono informado pela família: média 9h30.',
      );
      expect(v.imports.single.source, 'Diário do sono');
      expect(
        const WellChildVisit().changesTo(v),
        contains('Dados da família incorporados'),
      );
    });

    test('marcos, dúvidas e itens de acompanhamento', () {
      final List<MilestoneSuggestion> s = milestoneSuggestions(
        ChildAgeBand.de1a2a,
      );
      expect(
        s.map((MilestoneSuggestion x) => x.title),
        contains('Anda sem apoio'),
      );
      final MilestoneObservation m = MilestoneObservation.from(
        s.first,
        MilestoneState.adquirido,
      );
      expect(m.describe(), 'Anda sem apoio (Motor grosso): Adquirido');
      final WellChildVisit v = WellChildVisit(
        milestones: <MilestoneObservation>[m],
        questions: const <GuardianQuestion>[
          GuardianQuestion(question: 'Pode usar travesseiro?'),
        ],
        followUps: <FollowUpItem>[
          FollowUpItem(id: 'f2', title: 'Vacina', due: DateTime(2026, 12, 1)),
          FollowUpItem(id: 'f1', title: 'Exame', due: DateTime(2026, 10, 10)),
        ],
      );
      expect(v.sortedFollowUps.first.title, 'Exame');
      expect(
        v.changesTo(
          v.copyWith(
            milestones: <MilestoneObservation>[
              m.copyWith(state: MilestoneState.seguimento),
            ],
          ),
        ),
        <String>['Marcos do desenvolvimento'],
      );
    });
  });

  group('modelos de evolução', () {
    test('salvar troca nomes por marcadores e não leva dado da família', () {
      final WellChildVisit v = const WellChildVisit()
          .withField(
            WellChildSection.historia,
            'Responsável Exemplo A relata que Luna está bem.',
          )
          .withField(
            WellChildSection.plano,
            'Retorno com Luna Exemplo Souza em 2 meses.',
          )
          .incorporate(
            FamilyImport(
              section: WellChildSection.sono,
              source: 'Diário do sono',
              period: 'x',
              text: 'Texto da família',
              reviewedBy: 'Dra.',
              at: now,
            ),
          );
      final WellChildTemplate t = WellChildTemplate.fromVisit(
        v,
        id: 'w9',
        name: 'Meu modelo',
        author: 'Dra.',
        now: now,
        patientName: 'Luna Exemplo Souza',
        guardianName: 'Responsável Exemplo A',
      );
      expect(
        t.fields[WellChildSection.historia],
        '{{responsavel}} relata que {{crianca}} está bem.',
      );
      expect(
        t.fields[WellChildSection.plano],
        'Retorno com {{crianca}} em 2 meses.',
      );
      expect(t.fields.containsKey(WellChildSection.sono), isFalse);
      expect(t.validate(), isEmpty);
    });

    test(
      'aplicar preenche só campos vazios, salvo se pedir para substituir',
      () {
        final WellChildTemplate t = wellChildTemplateExamples(
          author: 'Dra.',
          now: now,
        ).first;
        final WellChildVisit v = const WellChildVisit().withField(
          WellChildSection.historia,
          'Já escrito.',
        );
        final r = t.applyTo(
          v,
          patientName: 'Maya Exemplo Rocha',
          guardianName: 'Responsável Exemplo C',
        );
        expect(r.visit.field(WellChildSection.historia), 'Já escrito.');
        expect(r.kept, contains('História'));
        expect(r.filled, contains('Sono'));
        expect(
          r.visit.templateName,
          'Puericultura 4 a 11 meses (exemplo) (v1)',
        );
        expect(r.visit.placeholders, isNotEmpty);
        final r2 = t.applyTo(
          v,
          patientName: 'Maya Exemplo Rocha',
          guardianName: 'Responsável Exemplo C',
          overwrite: true,
        );
        expect(
          r2.visit.field(WellChildSection.historia),
          startsWith('Responsável Exemplo C relata'),
        );
      },
    );

    test('edição gera nova versão', () {
      final WellChildTemplate t = wellChildTemplateExamples(
        author: 'Dra.',
        now: now,
      ).first;
      final WellChildTemplate t2 = t.copyWith(
        name: 'Renomeado',
        author: 'Dra. B',
        now: now,
      );
      expect(t2.version, 2);
      expect(t2.isExample, isFalse);
      expect(t2.id, t.id);
    });
  });

  group('orientações de exemplo', () {
    test('separadas por faixa e tema, com colchetes a completar', () {
      final List<OrientationTemplate> all = guidanceExamples(
        author: 'Dra.',
        now: now,
      );
      for (final ChildAgeBand b in ChildAgeBand.values) {
        expect(
          all.where(
            (OrientationTemplate t) =>
                t.band == b && t.topic == OrientationTopic.rotina,
          ),
          hasLength(1),
          reason: 'rotina para ${b.label}',
        );
      }
      final List<OrientationTemplate> safe = all
          .where(
            (OrientationTemplate t) => t.topic == OrientationTopic.sonoSeguro,
          )
          .toList();
      expect(safe, hasLength(3));
      for (final OrientationTemplate t in all) {
        expect(t.isExample, isTrue);
        expect(t.body, contains('[a definir'), reason: t.title);
      }
      for (final OrientationTemplate t in safe) {
        expect(t.body, contains(kSafeSleepNotice));
      }
    });
  });

  group('PDF do resumo', () {
    final DocContext ctx = DocContext(
      patientName: 'Luna Exemplo Souza',
      patientBirthDate: DateTime(2025, 7, 3),
      guardianName: 'Responsável Exemplo A',
      professionalName: 'Dra. Exemplo Demonstração',
      professionalRegistry: 'CRM 00000-UF (fictício)',
      clinicName: 'Consultório Exemplo (fictício)',
      city: 'Cidade Exemplo',
      date: DateTime(2026, 9, 28),
    );
    final WellChildVisit visit = const WellChildVisit()
        .withField(WellChildSection.avaliacao, 'Avaliação fictícia.')
        .withField(WellChildSection.plano, 'Plano fictício.')
        .copyWith(
          nextVisit: () => DateTime(2026, 11, 28),
          questions: const <GuardianQuestion>[
            GuardianQuestion(question: 'Dúvida?', answer: 'Resposta.'),
          ],
        );
    final VisitAge age = VisitAge.of(
      birthDate: DateTime(2025, 7, 3),
      at: DateTime(2026, 9, 28),
      gestationalAgeDays: 34 * 7 + 2,
    );

    Future<Uint8List> build({Uint8List? logo, bool finished = true}) =>
        WellChildPdf.build(
          visit: visit,
          context: ctx,
          age: age,
          finished: finished,
          author: 'Dra. Exemplo Demonstração',
          now: now,
          logo: logo,
          demo: true,
          measures: <ReportMeasure>[
            ReportMeasure(
              GrowthValues(
                date: DateTime(2026, 9, 28),
                weightKg: 10.2,
                lengthCm: 76,
                headCm: 45.5,
              ),
              current: true,
            ),
            ReportMeasure(
              GrowthValues(
                date: DateTime(2026, 6, 20),
                weightKg: 9.1,
                lengthCm: 72,
              ),
            ),
          ],
        );

    test('com logomarca: a imagem entra no cabeçalho', () async {
      final Uint8List pdf = await build(logo: solidPng(320, 120));
      final String raw = latin1.decode(pdf);
      expect(raw, startsWith('%PDF'));
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(raw), isTrue);
      expect(RegExp(r'/Width\s+320').hasMatch(raw), isTrue);
    });

    test('sem logomarca: identidade padrão, sem imagem', () async {
      final Uint8List pdf = await build(finished: false);
      final String raw = latin1.decode(pdf);
      expect(raw, startsWith('%PDF'));
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(raw), isFalse);
    });

    test('nome do arquivo', () {
      expect(
        WellChildPdf.fileName('Luna Exemplo Souza', DateTime(2026, 9, 28)),
        'puericultura-luna-20260928.pdf',
      );
    });
  });
}
