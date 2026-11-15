import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../data/child_access_repository.dart';
import '../../domain/child_access_grant.dart';
import 'children_providers.dart';

final Provider<ChildAccessRepository> childAccessRepositoryProvider =
    Provider<ChildAccessRepository>(
  (Ref ref) => ChildAccessRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

typedef ChildAccessKey = ({String ownerId, String childId});

final StreamProviderFamily<List<ChildAccessGrant>, ChildAccessKey>
    childAccessGrantsProvider =
    StreamProvider.family<List<ChildAccessGrant>, ChildAccessKey>(
  (Ref ref, ChildAccessKey key) =>
      ref.watch(childAccessRepositoryProvider).watchGrants(
            ownerId: key.ownerId,
            childId: key.childId,
          ),
);

/// Resolve o dono da criança para profissional com concessão ativa.
///
/// Família: devolve o próprio uid se a criança for dela.
/// Profissional: chama `checkChildAccess` (só devolve ownerUid com grant).
final FutureProviderFamily<String?, String> childOwnerForAccessProvider =
    FutureProvider.family<String?, String>((Ref ref, String childId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || childId.isEmpty) return null;

  final Child? own = await ref.watch(childProvider(childId).future);
  if (own != null) return user.uid;

  if (!user.role.isProfessional) return null;

  final String? clinicId =
      ref.watch(activeClinicIdProvider).valueOrNull;
  final Result<ChildAccessCheck> checked =
      await ref.read(childAccessRepositoryProvider).checkAccess(
            childId: childId,
            clinicId: clinicId,
          );
  return checked.fold(
    (ChildAccessCheck c) => c.canReadCadastro ? c.ownerUid : null,
    (_) => null,
  );
});

/// Cadastro da criança para linha do tempo / 360.
///
/// Responsável: caminho próprio. Profissional: caminho do dono só depois de
/// `checkChildAccess` confirmar concessão — sem grant, stream vazio (não
/// consulta `users/{eu}/children/{id}` com id de outra família).
final StreamProviderFamily<Child?, String> clinicalChildProvider =
    StreamProvider.family<Child?, String>((Ref ref, String childId) {
  final user = ref.watch(currentUserProvider);
  if (user == null || childId.isEmpty) {
    return Stream<Child?>.value(null);
  }

  if (!user.role.isProfessional) {
    return ref.watch(childrenRepositoryProvider).watchChild(childId);
  }

  final AsyncValue<String?> ownerAsync =
      ref.watch(childOwnerForAccessProvider(childId));
  return ownerAsync.when(
    data: (String? ownerId) {
      if (ownerId == null) return Stream<Child?>.value(null);
      if (ownerId == user.uid) {
        return ref.watch(childrenRepositoryProvider).watchChild(childId);
      }
      return ref.watch(childrenRepositoryProvider).watchChildOfOwner(
            ownerId: ownerId,
            childId: childId,
          );
    },
    loading: () => Stream<Child?>.value(null),
    error: (Object _, StackTrace __) => Stream<Child?>.value(null),
  );
});
