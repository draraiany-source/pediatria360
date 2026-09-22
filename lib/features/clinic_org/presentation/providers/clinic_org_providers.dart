import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/clinic_organization_repository.dart';

const String _kActiveClinicKey = 'p360_active_clinic_id';

final Provider<ClinicOrganizationRepository> clinicOrganizationRepositoryProvider =
    Provider<ClinicOrganizationRepository>(
  (Ref ref) => ClinicOrganizationRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

final StreamProvider<List<ClinicMembership>> myClinicMembershipsProvider =
    StreamProvider<List<ClinicMembership>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<ClinicMembership>>.value(const <ClinicMembership>[]);
  }
  return ref
      .watch(clinicOrganizationRepositoryProvider)
      .watchUserMemberships(uid);
});

/// Clinica ativa do profissional (preferencia local + memberships).
class ActiveClinicController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_kActiveClinicKey);
    final List<ClinicMembership> memberships =
        await ref.watch(myClinicMembershipsProvider.future);
    if (memberships.isEmpty) return null;
    if (saved != null &&
        memberships.any((ClinicMembership m) => m.clinicId == saved)) {
      return saved;
    }
    return memberships.first.clinicId;
  }

  Future<void> select(String clinicId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveClinicKey, clinicId);
    state = AsyncData<String?>(clinicId);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveClinicKey);
    state = const AsyncData<String?>(null);
  }
}

final AsyncNotifierProvider<ActiveClinicController, String?>
    activeClinicIdProvider =
    AsyncNotifierProvider<ActiveClinicController, String?>(
  ActiveClinicController.new,
);

final Provider<ClinicMembership?> activeClinicMembershipProvider =
    Provider<ClinicMembership?>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  final String? clinicId = ref.watch(activeClinicIdProvider).valueOrNull;
  final List<ClinicMembership> memberships =
      ref.watch(myClinicMembershipsProvider).valueOrNull ??
          const <ClinicMembership>[];
  if (uid == null || clinicId == null) return null;
  for (final ClinicMembership m in memberships) {
    if (m.clinicId == clinicId && m.active) return m;
  }
  return null;
});

final FutureProvider<ClinicOrganization?> activeClinicProvider =
    FutureProvider<ClinicOrganization?>((Ref ref) async {
  final String? id = await ref.watch(activeClinicIdProvider.future);
  if (id == null || id.isEmpty) return null;
  final Result<ClinicOrganization?> result =
      await ref.watch(clinicOrganizationRepositoryProvider).getClinic(id);
  return result.valueOrNull;
});
