import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/dev_mode.dart';

void main() {
  test('DevMode permanece ativo em debug', () {
    expect(DevMode.isEnabled, isTrue);
    expect(DevMode.user.role.isProfessional, isTrue);
  });
}
