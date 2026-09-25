import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/child_guardians_repository.dart';
import '../../domain/child_guardian.dart';

final childGuardiansRepositoryProvider = Provider<ChildGuardiansRepository>(
  (Ref ref) => ChildGuardiansRepository(firestore: ref.watch(firestoreProvider)),
);

typedef ChildGuardiansKey = ({String ownerId, String childId});

final childGuardiansProvider =
    StreamProvider.family<List<ChildGuardianLink>, ChildGuardiansKey>(
  (Ref ref, ChildGuardiansKey key) =>
      ref.watch(childGuardiansRepositoryProvider).watchGuardians(
            ownerId: key.ownerId,
            childId: key.childId,
          ),
);

final myLinkedChildrenProvider =
    StreamProvider<List<ChildGuardianLink>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<ChildGuardianLink>>.value(const <ChildGuardianLink>[]);
  }
  return ref.watch(childGuardiansRepositoryProvider).watchMyLinkedChildren(uid);
});

class ChildGuardiansController extends StateNotifier<AsyncValue<void>> {
  ChildGuardiansController(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  ChildGuardiansRepository get _repo =>
      _ref.read(childGuardiansRepositoryProvider);

  Future<Result<void>> upsert(ChildGuardianLink link) async {
    final String? actor = _ref.read(currentUserProvider)?.uid;
    if (actor == null) {
      return const Result<void>.failure(
        AuthFailure('Sessao expirada. Entre novamente.'),
      );
    }
    state = const AsyncLoading<void>();
    final Result<void> result =
        await _repo.upsertGuardian(link: link, actorUid: actor);
    state = result.fold(
      (_) => const AsyncData<void>(null),
      (Failure f) => AsyncError<void>(f, StackTrace.current),
    );
    return result;
  }

  Future<Result<void>> revoke({
    required String ownerId,
    required String childId,
    required String guardianUid,
  }) async {
    final String? actor = _ref.read(currentUserProvider)?.uid;
    if (actor == null) {
      return const Result<void>.failure(
        AuthFailure('Sessao expirada. Entre novamente.'),
      );
    }
    return _repo.revokeGuardian(
      ownerId: ownerId,
      childId: childId,
      guardianUid: guardianUid,
      actorUid: actor,
    );
  }
}

final childGuardiansControllerProvider =
    StateNotifierProvider<ChildGuardiansController, AsyncValue<void>>(
  ChildGuardiansController.new,
);