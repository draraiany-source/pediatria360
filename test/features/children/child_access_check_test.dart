import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/children/data/child_access_repository.dart';

void main() {
  test('canReadCadastro exige summary ou chartWrite', () {
    expect(
      const ChildAccessCheck(
        summary: false,
        chartWrite: false,
        state: 'none',
        ownerUid: 'dono',
      ).canReadCadastro,
      isFalse,
    );
    expect(
      const ChildAccessCheck(
        summary: true,
        chartWrite: false,
        state: 'active',
        ownerUid: 'dono',
      ).canReadCadastro,
      isTrue,
    );
    expect(
      const ChildAccessCheck(
        summary: false,
        chartWrite: true,
        state: 'active',
        ownerUid: 'dono',
      ).canReadCadastro,
      isTrue,
    );
  });
}
