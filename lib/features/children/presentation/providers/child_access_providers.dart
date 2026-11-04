import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/child_access_repository.dart';
import '../../domain/child_access_grant.dart';

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
