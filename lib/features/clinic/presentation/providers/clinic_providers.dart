import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/domain/agenda_unit_filter.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../data/clinic_repository.dart';
import '../../data/voice_consultation_repository.dart';
import '../../domain/agenda_scope.dart';
import '../../domain/clinic_dashboard_stats.dart';
import '../../domain/triage_record.dart';
import '../../domain/voice_consultation.dart';

final Provider<ClinicRepository> clinicRepositoryProvider =
    Provider<ClinicRepository>(
  (Ref ref) => ClinicRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final Provider<VoiceConsultationRepository>
    voiceConsultationRepositoryProvider =
    Provider<VoiceConsultationRepository>(
  (Ref ref) => VoiceConsultationRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

/// Agendamentos de hoje: a clinica inteira para quem opera a recepcao;
/// para o profissional, apenas os proprios.
final StreamProvider<List<Appointment>> todayClinicAppointmentsProvider =
    StreamProvider<List<Appointment>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<Appointment>>.value(const <Appointment>[]);
  }
  final ClinicMembership? membership =
      ref.watch(activeClinicMembershipProvider);
  if (usesClinicWideAgenda(membership, ref.watch(currentWorkspaceProvider))) {
    return ref
        .watch(clinicRepositoryProvider)
        .watchTodayClinicAppointments(membership!.clinicId);
  }
  return ref.watch(clinicRepositoryProvider).watchTodayAppointments(uid);
});

/// Agenda do dia filtrada pelas unidades do membership ativo (recepcao).
/// Nao amplia acesso — apenas restringe a lista ja autorizada.
final Provider<AsyncValue<List<Appointment>>>
    unitScopedTodayClinicAppointmentsProvider =
    Provider<AsyncValue<List<Appointment>>>((Ref ref) {
  final AsyncValue<List<Appointment>> agenda =
      ref.watch(todayClinicAppointmentsProvider);
  final membership = ref.watch(activeClinicMembershipProvider);
  return agenda.when(
    data: (List<Appointment> data) => AsyncData<List<Appointment>>(
      filterAgendaByMembershipUnits(data, membership),
    ),
    loading: () => const AsyncLoading<List<Appointment>>(),
    error: (Object e, StackTrace st) => AsyncError<List<Appointment>>(e, st),
  );
});

final FutureProvider<ClinicDashboardStats> clinicDashboardStatsProvider =
    FutureProvider<ClinicDashboardStats>((Ref ref) async {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return ClinicDashboardStats.empty();
  // Import circular avoided: unread is read lazily via notifications provider.
  int unread = 0;
  try {
    unread = ref.watch(unreadCountProvider);
  } catch (_) {
    unread = 0;
  }
  final result = await ref
      .watch(clinicRepositoryProvider)
      .loadDashboardStatsWithUnread(uid, unreadMessages: unread);
  return result.valueOrNull ?? ClinicDashboardStats.empty();
});

final StreamProviderFamily<TriageRecord?, String> triageByAppointmentProvider =
    StreamProvider.family<TriageRecord?, String>((Ref ref, String appointmentId) {
  return ref.watch(clinicRepositoryProvider).watchTriage(appointmentId);
});

final StreamProviderFamily<VoiceConsultationSession?, String>
    voiceSessionProvider =
    StreamProvider.family<VoiceConsultationSession?, String>(
  (Ref ref, String sessionId) {
    return ref
        .watch(voiceConsultationRepositoryProvider)
        .watchSession(sessionId);
  },
);
