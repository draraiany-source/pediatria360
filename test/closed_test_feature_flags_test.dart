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

    test('Termos, Privacidade e controlador vem do build, sem valor inventado',
        () {
      for (final String url in <String>[
        AppConfig.termsOfServiceUrl,
        AppConfig.privacyPolicyUrl,
      ]) {
        if (url.isNotEmpty) expect(url, startsWith('https://'));
      }
      if (AppConfig.termsOfServiceUrl.isEmpty ||
          AppConfig.privacyPolicyUrl.isEmpty ||
          AppConfig.dataControllerCnpj.isEmpty) {
        expect(AppConfig.legalConfigured, isFalse);
      }
    });
  });
}