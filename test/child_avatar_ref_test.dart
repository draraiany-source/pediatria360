import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/app_assets.dart';
import 'package:pediatria360/core/widgets/child_avatar.dart';

void main() {
  group('ChildAvatarRef', () {
    test('encode and pathFrom round-trip asset paths', () {
      const String path = AppAssets.avatarMeninoCachos;
      final String encoded = ChildAvatarRef.encode(path);
      expect(encoded, 'asset:$path');
      expect(ChildAvatarRef.isAsset(encoded), isTrue);
      expect(ChildAvatarRef.pathFrom(encoded), path);
    });

    test('network URLs are not treated as assets', () {
      const String url = 'https://example.com/photo.jpg';
      expect(ChildAvatarRef.isAsset(url), isFalse);
      expect(ChildAvatarRef.pathFrom(url), isNull);
    });

    test('empty and null are not assets', () {
      expect(ChildAvatarRef.isAsset(null), isFalse);
      expect(ChildAvatarRef.isAsset(''), isFalse);
    });
  });
}
