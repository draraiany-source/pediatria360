import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/supplement_repository.dart';
import '../../domain/lab_result.dart';
import '../../domain/supplement_ai.dart';
import '../../domain/supplement_calculator.dart';
import '../../domain/supplement_prescription.dart';
import '../../domain/supplement_timeline.dart';

final Provider<SupplementRepository> supplementRepositoryProvider =
    Provider<SupplementRepository>(
  (Ref ref) => SupplementRepository(firestore: ref.watch(firestoreProvider)),
);

final Provider<SupplementCalculatorEngine> supplementCalculatorProvider =
    Provider<SupplementCalculatorEngine>(
  (Ref ref) => const SupplementCalculatorEngine(),
);

final Provider<SupplementAiLocalOrganizer> supplementAiOrganizerProvider =
    Provider<SupplementAiLocalOrganizer>(
  (Ref ref) => const SupplementAiLocalOrganizer(),
);

final childLabResultsProvider =
    StreamProvider.family<List<PatientLabResult>, String>(
  (Ref ref, String childId) {
    return ref.watch(supplementRepositoryProvider).watchLabResults(childId);
  },
);

final childSupplementRxProvider =
    StreamProvider.family<List<SupplementPrescription>, String>(
  (Ref ref, String childId) {
    return ref.watch(supplementRepositoryProvider).watchPrescriptions(childId);
  },
);

final childSupplementTimelineProvider =
    StreamProvider.family<List<SupplementTimelineEvent>, String>(
  (Ref ref, String childId) {
    return ref.watch(supplementRepositoryProvider).watchTimeline(childId);
  },
);

final StreamProvider<List<String>> supplementFavoritesProvider =
    StreamProvider<List<String>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<String>>.value(const <String>[]);
  }
  return ref.watch(supplementRepositoryProvider).watchFavorites(uid);
});

final StreamProvider<List<Map<String, dynamic>>> supplementRecentProvider =
    StreamProvider<List<Map<String, dynamic>>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<Map<String, dynamic>>>.value(
      const <Map<String, dynamic>>[],
    );
  }
  return ref.watch(supplementRepositoryProvider).watchRecent(uid);
});
