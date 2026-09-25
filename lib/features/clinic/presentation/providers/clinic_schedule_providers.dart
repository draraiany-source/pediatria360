import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../data/clinic_schedule_repository.dart';
import '../../domain/agenda_scheduling.dart';

final clinicScheduleRepositoryProvider = Provider<ClinicScheduleRepository>(
  (Ref ref) =>
      ClinicScheduleRepository(firestore: ref.watch(firestoreProvider)),
);

final clinicRoomsProvider = StreamProvider<List<ClinicRoom>>((Ref ref) {
  final String? clinicId = ref.watch(activeClinicIdProvider).valueOrNull;
  if (clinicId == null || clinicId.isEmpty) {
    return Stream<List<ClinicRoom>>.value(const <ClinicRoom>[]);
  }
  return ref.watch(clinicScheduleRepositoryProvider).watchRooms(clinicId);
});

final clinicScheduleBlocksProvider =
    StreamProvider<List<ScheduleBlock>>((Ref ref) {
  final String? clinicId = ref.watch(activeClinicIdProvider).valueOrNull;
  if (clinicId == null || clinicId.isEmpty) {
    return Stream<List<ScheduleBlock>>.value(const <ScheduleBlock>[]);
  }
  return ref.watch(clinicScheduleRepositoryProvider).watchBlocks(clinicId);
});