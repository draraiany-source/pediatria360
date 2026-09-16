import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/widgets/skeleton.dart';
import 'package:pediatria360/features/auth/presentation/providers/auth_providers.dart';
import 'package:pediatria360/features/children/presentation/providers/children_providers.dart';
import 'package:pediatria360/features/emr/presentation/screens/patient_timeline_screen.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/child.dart';
import 'package:pediatria360/shared/domain/entities/clinical_record.dart';
import 'package:pediatria360/shared/domain/entities/encounter.dart';
import 'package:pediatria360/shared/domain/entities/growth_record.dart';
import 'package:pediatria360/shared/domain/entities/vaccine.dart';

/// Primeiro harness de teste de widget do projeto com Riverpod mockado —
/// não existia até esta rodada. Sobrescreve os providers de dados
/// diretamente (`ProviderScope(overrides: ...)`), sem tocar Firebase.
///
/// Cobre exatamente o que a Fase 1 pediu para testar em nível de widget,
/// não só de função pura: paciente com dado, paciente sem dado,
/// isolamento entre pacientes, carregamento, erro, filtro.
void main() {
  final AppUser professional = AppUser(
    uid: 'dra-uid',
    email: 'dra@exemplo.com',
    name: 'Dra. Teste',
    role: UserRole.professional,
    plan: UserPlan.pro,
    createdAt: DateTime(2026, 1, 1),
    professionalVerified: true,
  );

  Child child({
    required String id,
    required String name,
    List<String> allergies = const <String>[],
  }) =>
      Child(
        id: id,
        ownerId: 'responsavel-de-$id',
        name: name,
        birthDate: DateTime(2023, 6, 1),
        sex: ChildSex.female,
        updatedAt: DateTime(2026, 1, 1),
        allergies: allergies,
        guardianName: 'Responsável de $name',
      );

  Encounter encounter(String childId) => Encounter(
        id: 'e-$childId',
        patientId: childId,
        professionalId: 'dra-uid',
        professionalName: 'Dra. Teste',
        type: EncounterType.routine,
        status: EncounterStatus.signed,
        startedAt: DateTime(2026, 5, 1),
      );

  /// Constrói o widget sob teste, com todos os providers de dado
  /// sobrescritos para o `childId` dado. `overrides` extra permite cada
  /// teste customizar só o que precisa (erro, vazio, etc.) sem repetir os
  /// outros oito providers toda vez.
  Widget harness({
    required String childId,
    Child? childData,
    List<GrowthRecord> growth = const <GrowthRecord>[],
    List<Encounter> encounters = const <Encounter>[],
    List<Override> extraOverrides = const <Override>[],
  }) {
    return ProviderScope(
      key: ValueKey<String>(childId),
      overrides: <Override>[
        currentUserProvider.overrideWithValue(professional),
        childProvider(childId).overrideWith((Ref ref) => Stream.value(childData)),
        growthProvider(childId).overrideWith((Ref ref) => Stream.value(growth)),
        vaccineDosesProvider(childId)
            .overrideWith((Ref ref) => Stream.value(const <VaccineDose>[])),
        vaccineSummaryProvider(childId).overrideWithValue(
          const VaccineSummary(total: 0, applied: 0, overdue: 0, upcoming: 0),
        ),
        patientEncountersProvider(childId)
            .overrideWith((Ref ref) => Stream.value(encounters)),
        patientDocumentsProvider(childId)
            .overrideWith((Ref ref) => Stream.value(const <ClinicalDocument>[])),
        patientLabsProvider(childId)
            .overrideWith((Ref ref) => Stream.value(const <LabResult>[])),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: PatientTimelineScreen(patientId: childId),
      ),
    );
  }

  group('paciente COM dados', () {
    testWidgets('mostra nome, responsável e consulta reais — nenhum número inventado',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-a',
        childData: child(id: 'crianca-a', name: 'Manuela'),
        growth: <GrowthRecord>[
          GrowthRecord(
            id: 'g1',
            childId: 'crianca-a',
            measuredAt: DateTime(2026, 4, 1),
            updatedAt: DateTime(2026, 4, 1),
            weightKg: 12.5,
          ),
        ],
        encounters: <Encounter>[encounter('crianca-a')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Manuela'), findsWidgets);
      expect(find.textContaining('Responsável de Manuela'), findsWidgets);
      expect(find.textContaining('12,5 kg'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1 atendimento'), findsOneWidget);
    });

    testWidgets('alergia aparece como alerta visível', (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-a',
        childData: child(id: 'crianca-a', name: 'Manuela', allergies: <String>['Dipirona']),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dipirona'), findsWidgets);
    });
  });

  group('paciente SEM dados', () {
    testWidgets('prontuário genuinamente vazio mostra estado vazio, não card fictício',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-b',
        childData: child(id: 'crianca-b', name: 'Pedro'),
      ));
      await tester.pumpAndSettle();

      // Aba Resumo: indicadores sem inventar números.
      expect(find.text('Sem registro'), findsWidgets);

      // Aba Prontuário: estado vazio da timeline.
      await tester.tap(find.text('Prontuário'));
      await tester.pumpAndSettle();
      expect(find.text('Prontuário vazio'), findsOneWidget);
    });
  });

  group('isolamento entre pacientes', () {
    testWidgets('criança A não mistura dado com criança B', (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-a',
        childData: child(id: 'crianca-a', name: 'Manuela'),
        encounters: <Encounter>[encounter('crianca-a')],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Manuela'), findsWidgets);
      expect(find.text('Pedro'), findsNothing);

      // Descarta o primeiro ProviderScope antes de montar o segundo —
      // Riverpod não aceita trocar o conjunto de overrides no mesmo
      // container (childId diferente = providers diferentes).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(harness(
        childId: 'crianca-b',
        childData: child(id: 'crianca-b', name: 'Pedro'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pedro'), findsWidgets);
      expect(find.text('Manuela'), findsNothing);
    });
  });

  group('carregamento', () {
    testWidgets('stream de encounters nunca resolve → skeleton, não tela vazia',
        (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          currentUserProvider.overrideWithValue(professional),
          childProvider('crianca-a')
              .overrideWith((Ref ref) => Stream.value(child(id: 'crianca-a', name: 'Manuela'))),
          growthProvider('crianca-a')
              .overrideWith((Ref ref) => const Stream<List<GrowthRecord>>.empty()),
          vaccineDosesProvider('crianca-a')
              .overrideWith((Ref ref) => const Stream<List<VaccineDose>>.empty()),
          vaccineSummaryProvider('crianca-a').overrideWithValue(
            const VaccineSummary(total: 0, applied: 0, overdue: 0, upcoming: 0),
          ),
          // Nunca emite — simula carregamento que ainda não resolveu.
          patientEncountersProvider('crianca-a')
              .overrideWith((Ref ref) => const Stream<List<Encounter>>.empty()),
          patientDocumentsProvider('crianca-a')
              .overrideWith((Ref ref) => const Stream<List<ClinicalDocument>>.empty()),
          patientLabsProvider('crianca-a')
              .overrideWith((Ref ref) => const Stream<List<LabResult>>.empty()),
        ],
        child: const MaterialApp(
          home: PatientTimelineScreen(patientId: 'crianca-a'),
        ),
      ));
      // Um só pump — não pumpAndSettle, que esperaria o stream "resolver"
      // (nunca resolve de propósito) e travaria o teste.
      await tester.pump();

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.text('Prontuário vazio'), findsNothing);
    });
  });

  group('erro', () {
    testWidgets('stream de encounters falha → ErrorState com retry, não "vazio"',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-a',
        childData: child(id: 'crianca-a', name: 'Manuela'),
        extraOverrides: <Override>[
          patientEncountersProvider('crianca-a').overrideWith(
            (Ref ref) => Stream<List<Encounter>>.error(Exception('falha de rede')),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Prontuário vazio'), findsNothing);
      expect(
        find.text('Não conseguimos carregar essas informações'),
        findsOneWidget,
      );
    });
  });

  group('filtro', () {
    testWidgets('tocar "Crescimento" esconde evento de outro tipo', (WidgetTester tester) async {
      await tester.pumpWidget(harness(
        childId: 'crianca-a',
        childData: child(id: 'crianca-a', name: 'Manuela'),
        growth: <GrowthRecord>[
          GrowthRecord(
            id: 'g1',
            childId: 'crianca-a',
            measuredAt: DateTime(2026, 4, 1),
            updatedAt: DateTime(2026, 4, 1),
            weightKg: 12.5,
          ),
        ],
        encounters: <Encounter>[encounter('crianca-a')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prontuário'));
      await tester.pumpAndSettle();

      // Antes do filtro: os dois tipos de evento aparecem juntos.
      expect(find.text('Medição de crescimento'), findsOneWidget);
      expect(find.text('Consulta de rotina'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Crescimento'));
      await tester.pumpAndSettle();

      // Depois do filtro: crescimento continua, consulta desaparece da
      // timeline — é isto que prova que o filtro fez alguma coisa, não só
      // que a tela renderiza (o resumo no topo não filtra, só a lista).
      expect(find.text('Medição de crescimento'), findsOneWidget);
      expect(find.text('Consulta de rotina'), findsNothing);
    });
  });
}
