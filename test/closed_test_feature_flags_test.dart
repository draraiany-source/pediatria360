import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/app_config.dart';

void main() {
  group('Closed-test feature flags', () {
    test('recursos incompletos ficam desligados por padrao', () {
      expect(AppConfig.paymentGatewayEnabled, isFalse);
      expect(AppConfig.videoConsultationEnabled, isFalse);
      expect(AppConfig.voiceConsultationEnabled, isFalse);
      expect(AppConfig.tissOperatorEnabled, isFalse);
      expect(AppConfig.icpDigitalSignatureEnabled, isFalse);
    });

    test('App Check nao e obrigatorio sem dart-define', () {
      expect(AppConfig.appCheckEnabled, isFalse);
    });

    test('Termos e Privacidade nao sao URLs inventadas vazias', () {
      expect(AppConfig.termsOfServiceUrl, startsWith('https://'));
      expect(AppConfig.privacyPolicyUrl, startsWith('https://'));
    });
  });
}