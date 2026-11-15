import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/module_flags.dart';

void main() {
  test('flags M2/M3 desligadas sem remote e sem dart-define', () {
    expect(ModuleFlags.kidsSpaceEnabled(), isFalse);
    expect(ModuleFlags.kidsKioskEnabled(), isFalse);
    expect(ModuleFlags.tiaCrisRuntimeEnabled(), isFalse);
    expect(ModuleFlags.tiaCrisBookingEnabled(), isFalse);
  });
}
