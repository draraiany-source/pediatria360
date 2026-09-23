import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/security/domain/blocked_access_tracker.dart';

void main() {
  group('BlockedAccessTracker', () {
    test('fires after three events within window', () {
      final BlockedAccessTracker tracker = BlockedAccessTracker(
        window: const Duration(minutes: 5),
        threshold: 3,
      );
      final DateTime t0 = DateTime.utc(2026, 1, 1, 12, 0);
      expect(tracker.record('uid-a', t0), isFalse);
      expect(tracker.record('uid-a', t0.add(const Duration(seconds: 30))),
          isFalse);
      expect(tracker.record('uid-a', t0.add(const Duration(minutes: 1))),
          isTrue);
    });

    test('does not count events outside window', () {
      final BlockedAccessTracker tracker = BlockedAccessTracker(
        window: const Duration(minutes: 5),
        threshold: 3,
      );
      final DateTime t0 = DateTime.utc(2026, 1, 1, 12, 0);
      tracker.record('uid-b', t0);
      tracker.record('uid-b', t0.add(const Duration(minutes: 2)));
      expect(
        tracker.record('uid-b', t0.add(const Duration(minutes: 6))),
        isFalse,
      );
    });
  });
}
