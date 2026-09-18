import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../data/clinic_repository.dart';
import '../../data/voice_consultation_repository.dart';
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

/// Agendamentos de hoje do profissional logado.
final StreamProvider<List<Appointment>> todayClinicAppointmentsProvider =
    StreamProvider<List<Appointment>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<Appointment>>.value(const <Appointment>[]);
  }
  return ref.watch(clinicRepositoryProvider).watchTodayAppointments(uid);
});

final FutureProvider<ClinicDashboardStats> clinicDashboardStatsProvider =
    FutureProvider<ClinicDashboardStats>((Ref ref) async {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return ClinicDashboardStats.empty();
  final result =
      await ref.watch(clinicRepositoryProvider).loadDashboardStats(uid);
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
