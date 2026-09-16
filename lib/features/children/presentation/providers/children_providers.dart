import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../../shared/domain/entities/vaccine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../growth/domain/who_reference.dart';
import '../../../vaccines/domain/pni_calendar.dart';
import '../../data/repositories/children_repository_impl.dart';
import '../../domain/repositories/children_repository.dart';

final Provider<ChildrenRepository> childrenRepositoryProvider =
    Provider<ChildrenRepository>(
  (Ref ref) => ChildrenRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
    sync: ref.watch(syncServiceProvider),
    database: ref.watch(localDatabaseProvider),
    currentUserId: () => ref.read(currentUserProvider)?.uid ?? '',
    currentUserName: () => ref.read(currentUserProvider)?.name,
  ),
);

/// Lista de crianças do responsável logado.
final StreamProvider<List<Child>> childrenProvider =
    StreamProvider<List<Child>>((Ref ref) {
  // Sem sessão não há o que observar — evita uma consulta com uid vazio.
  if (ref.watch(currentUserProvider) == null) {
    return Stream<List<Child>>.value(const <Child>[]);
  }
  return ref.watch(childrenRepositoryProvider).watchChildren();
});

final StreamProviderFamily<Child?, String> childProvider =
    StreamProvider.family<Child?, String>(
  (Ref ref, String childId) =>
      ref.watch(childrenRepositoryProvider).watchChild(childId),
);

final StreamProviderFamily<List<GrowthRecord>, String> growthProvider =
    StreamProvider.family<List<GrowthRecord>, String>(
  (Ref ref, String childId) =>
      ref.watch(childrenRepositoryProvider).watchGrowth(childId),
);

final StreamProviderFamily<List<VaccineDose>, String> vaccineDosesProvider =
    StreamProvider.family<List<VaccineDose>, String>(
  (Ref ref, String childId) =>
      ref.watch(childrenRepositoryProvider).watchVaccineDoses(childId),
);

/// Tabela de referência da OMS, carregada uma vez por sessão.
final FutureProvider<WhoReference> whoReferenceProvider =
    FutureProvider<WhoReference>((Ref ref) => WhoReference.load());

/// Resumo vacinal de uma criança: quantas em atraso, quantas próximas.
final ProviderFamily<VaccineSummary, String> vaccineSummaryProvider =
    Provider.family<VaccineSummary, String>((Ref ref, String childId) {
  final List<VaccineDose> doses =
      ref.watch(vaccineDosesProvider(childId)).valueOrNull ??
          const <VaccineDose>[];

  int applied = 0;
  int overdue = 0;
  int upcoming = 0;

  for (final VaccineDose dose in doses) {
    if (dose.isApplied) {
      applied++;
    } else if (dose.isOverdue()) {
      overdue++;
    } else if (dose.isUpcoming()) {
      upcoming++;
    }
  }

  return VaccineSummary(
    total: doses.length,
    applied: applied,
    overdue: overdue,
    upcoming: upcoming,
  );
});

class VaccineSummary {
  const VaccineSummary({
    required this.total,
    required this.applied,
    required this.overdue,
    required this.upcoming,
  });

  final int total;
  final int applied;
  final int overdue;
  final int upcoming;

  double get progress => total == 0 ? 0 : applied / total;
}

/// Avalia a última medição de cada indicador contra a referência da OMS.
final ProviderFamily<List<GrowthAssessment>, String> latestAssessmentsProvider =
    Provider.family<List<GrowthAssessment>, String>((Ref ref, String childId) {
  final Child? child = ref.watch(childProvider(childId)).valueOrNull;
  final WhoReference? who = ref.watch(whoReferenceProvider).valueOrNull;
  final List<GrowthRecord> records =
      ref.watch(growthProvider(childId)).valueOrNull ??
          const <GrowthRecord>[];

  if (child == null || who == null || records.isEmpty) {
    return const <GrowthAssessment>[];
  }

  final List<GrowthAssessment> result = <GrowthAssessment>[];

  // Cada indicador usa a medição mais recente que o contenha — o responsável
  // pode ter pesado hoje e medido a altura na semana passada.
  for (final GrowthIndicator indicator in GrowthIndicator.values) {
    GrowthRecord? source;
    double? value;

    for (final GrowthRecord record in records.reversed) {
      final double? candidate = switch (indicator) {
        GrowthIndicator.weightForAge => record.weightKg,
        GrowthIndicator.heightForAge => record.heightCm,
        GrowthIndicator.headForAge => record.headCircumferenceCm,
        GrowthIndicator.bmiForAge => record.bmi,
      };
      if (candidate != null) {
        source = record;
        value = candidate;
        break;
      }
    }

    if (source == null || value == null) continue;

    // Idade clínica na data da medição: prematuro usa idade corrigida.
    final int ageMonths = _ageMonthsAt(child, source.measuredAt);
    if (ageMonths > indicator.maxAgeMonths) continue;

    final GrowthAssessment? assessment = who.assess(
      indicator: indicator,
      sex: child.sex,
      ageMonths: ageMonths.toDouble(),
      value: value,
    );
    if (assessment != null) result.add(assessment);
  }

  return result;
});

/// Idade, em meses, na data da medição — com correção para prematuros.
int _ageMonthsAt(Child child, DateTime at) {
  int months = (at.year - child.birthDate.year) * 12 +
      (at.month - child.birthDate.month);
  if (at.day < child.birthDate.day) months -= 1;
  if (months < 0) months = 0;

  if (child.isPreterm && months <= 24) {
    final int weeksMissing = 40 - child.gestationalWeeks!;
    final int corrected = months - (weeksMissing / 4.345).round();
    return corrected < 0 ? 0 : corrected;
  }
  return months;
}

/// Estado das ações de escrita (salvar criança, medição, dose).
class ChildActionState {
  const ChildActionState({this.isLoading = false, this.failure});

  final bool isLoading;
  final Failure? failure;
}

class ChildrenController extends Notifier<ChildActionState> {
  @override
  ChildActionState build() => const ChildActionState();

  Future<Child?> saveChild(Child child) async {
    state = const ChildActionState(isLoading: true);
    final Result<Child> result =
        await ref.read(childrenRepositoryProvider).saveChild(child);
    return _finish<Child>(result);
  }

  Future<bool> deleteChild(String childId) async {
    state = const ChildActionState(isLoading: true);
    final Result<void> result =
        await ref.read(childrenRepositoryProvider).deleteChild(childId);
    _finish<void>(result);
    return result.isSuccess;
  }

  Future<GrowthRecord?> saveGrowth(GrowthRecord record) async {
    state = const ChildActionState(isLoading: true);
    final Result<GrowthRecord> result =
        await ref.read(childrenRepositoryProvider).saveGrowth(record);
    return _finish<GrowthRecord>(result);
  }

  Future<bool> deleteGrowth({
    required String childId,
    required String recordId,
  }) async {
    state = const ChildActionState(isLoading: true);
    final Result<void> result = await ref
        .read(childrenRepositoryProvider)
        .deleteGrowth(childId: childId, recordId: recordId);
    _finish<void>(result);
    return result.isSuccess;
  }

  /// Marca ou desmarca uma dose como aplicada.
  Future<bool> toggleDose({
    required VaccineDose dose,
    required bool applied,
    DateTime? appliedAt,
    String? lot,
    String? clinic,
  }) async {
    state = const ChildActionState(isLoading: true);

    final VaccineDose updated = applied
        ? dose.copyWith(
            appliedAt: appliedAt ?? DateTime.now(),
            lot: lot,
            clinic: clinic,
          )
        : dose.copyWith(clearApplied: true);

    final Result<VaccineDose> result =
        await ref.read(childrenRepositoryProvider).saveVaccineDose(updated);
    _finish<VaccineDose>(result);
    return result.isSuccess;
  }

  /// Recria as doses previstas — usado quando o calendário local está vazio
  /// (criança cadastrada em outro aparelho, por exemplo).
  Future<void> ensureSchedule(Child child) async {
    final List<VaccineDose> existing =
        ref.read(vaccineDosesProvider(child.id)).valueOrNull ??
            const <VaccineDose>[];
    if (existing.isNotEmpty) return;

    for (final VaccineDoseSchedule schedule in PniCalendar.schedule) {
      await ref.read(childrenRepositoryProvider).saveVaccineDose(
            VaccineDose(
              id: '${child.id}-${schedule.vaccineId}-${schedule.doseIndex}',
              childId: child.id,
              vaccineId: schedule.vaccineId,
              doseIndex: schedule.doseIndex,
              dueAt: PniCalendar.dueDateFor(child.birthDate, schedule),
              updatedAt: DateTime.now(),
            ),
          );
    }
  }

  T? _finish<T>(Result<T> result) => result.fold(
        (T value) {
          state = const ChildActionState();
          return value;
        },
        (Failure failure) {
          state = ChildActionState(failure: failure);
          return null;
        },
      );
}

final NotifierProvider<ChildrenController, ChildActionState>
    childrenControllerProvider =
    NotifierProvider<ChildrenController, ChildActionState>(
  ChildrenController.new,
);
