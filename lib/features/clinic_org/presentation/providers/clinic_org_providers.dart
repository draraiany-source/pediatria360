import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/clinic_organization_repository.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';

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
  return ref.watch(clinicOrganizationRepositoryProvider).watchUserMemberships(uid);
});
