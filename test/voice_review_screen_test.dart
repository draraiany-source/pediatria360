import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/voice_consultation.dart';
import 'package:pediatria360/features/clinic/presentation/providers/clinic_providers.dart';
import 'package:pediatria360/features/clinic/presentation/screens/voice_review_screen.dart';

void main() {
  final VoiceConsultationSession session = VoiceConsultationSession.fromMap(
    <String, dynamic>{
      'childId': 'crianca-ficticia',
      'professionalId': 'medica-ficticia',
      'status': 'draftReady',
      'draft': <String, dynamic>{
        'chiefComplaint': 'Febre ha dois dias',
        'assessment': 'Sugestao ficticia',
        'plan': 'Plano ficticio',
        'hypotheses': <String>['Hipotese ficticia'],
      },
    },
    id: 's1',
  );

  testWidgets('Ignorar grava a recusa para a confirmacao final',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        voiceSessionProvider('s1').overrideWith(
          (Ref ref) => Stream<VoiceConsultationSession?>.value(session),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VoiceReviewScreen(sessionId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aceitar'), findsNothing);
    expect(
      find.text('Sugestao da IA para consulta. Nao e gravada no prontuario.'),
      findsWidgets,
    );

    final Finder assessmentCard = find.ancestor(
      of: find.text('Avaliacao'),
      matching: find.byType(Column),
    );
    await tester.tap(
      find.descendant(of: assessmentCard.first, matching: find.text('Ignorar')),
    );
    await tester.pumpAndSettle();

    expect(container.read(voiceIgnoredFieldsProvider('s1')), <String>{'assessment'});
    expect(find.text('Ignorado'), findsOneWidget);

    await tester.tap(find.text('Incluir'));
    await tester.pumpAndSettle();
    expect(container.read(voiceIgnoredFieldsProvider('s1')), isEmpty);
  });
}
