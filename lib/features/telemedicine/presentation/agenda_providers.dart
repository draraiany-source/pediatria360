import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/entities/clinic_organization.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../data/telemedicine_repository.dart';
import '../domain/agenda_unit_filter.dart';
import 'telemedicine_screen.dart' show myAgendaProvider;

/// Agenda profissional com filtro soft por unidade (recepcao / BI / financeiro).
final Provider<AsyncValue<List<Appointment>>> unitScopedMyAgendaProvider =
    Provider<AsyncValue<List<Appointment>>>((Ref ref) {
  final AsyncValue<List<Appointment>> agenda = ref.watch(myAgendaProvider);
  final ClinicMembership? membership =
      ref.watch(activeClinicMembershipProvider);
  return agenda.when(
    data: (List<Appointment> data) => AsyncData<List<Appointment>>(
      filterAgendaByMembershipUnits(data, membership),
    ),
    loading: () => const AsyncLoading<List<Appointment>>(),
    error: (Object e, StackTrace st) => AsyncError<List<Appointment>>(e, st),
  );
});
