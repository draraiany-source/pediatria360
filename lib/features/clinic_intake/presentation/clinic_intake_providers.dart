import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../clinic_org/data/clinic_team_repository.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../data/clinic_intake_repository.dart';
import '../domain/clinic_intake.dart';

final Provider<ClinicIntakeRepository> clinicIntakeRepositoryProvider =
    Provider<ClinicIntakeRepository>(
  (Ref ref) => ClinicIntakeRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final Provider<ClinicTeamRepository> clinicTeamRepositoryProvider =
    Provider<ClinicTeamRepository>(
  (Ref ref) => ClinicTeamRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

/// Solicitações visíveis: as da clínica ativa ou, sem clínica, as do
/// próprio profissional.
final StreamProvider<List<ClinicIntake>> visibleIntakesProvider =
    StreamProvider<List<ClinicIntake>>((Ref ref) {
  final ClinicMembership? m = ref.watch(activeClinicMembershipProvider);
  final String? uid = ref.watch(currentUserProvider)?.uid;
  final ClinicIntakeRepository repo = ref.watch(clinicIntakeRepositoryProvider);
  if (m != null) return repo.watchClinicIntakes(m.clinicId);
  if (uid != null) return repo.watchProfessionalIntakes(uid);
  return Stream<List<ClinicIntake>>.value(const <ClinicIntake>[]);
});

final StreamProviderFamily<List<ClinicTeamMember>, String> clinicTeamProvider =
    StreamProvider.family<List<ClinicTeamMember>, String>(
  (Ref ref, String clinicId) =>
      ref.watch(clinicTeamRepositoryProvider).watchMembers(clinicId),
);
