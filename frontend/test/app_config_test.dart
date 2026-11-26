import 'package:snapverify/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

const String _explicitBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

void main() {
  test('baseUrl is never empty and is a valid http(s) URL', () {
    final url = AppConstants.baseUrl;
    expect(url, isNotEmpty);
    expect(url, matches(r'^https?://'));
  });

  test('preset constants are correct', () {
    expect(AppConstants.emulatorBaseUrl, 'http://10.0.2.2:3000');
    expect(AppConstants.devDeviceBaseUrl, 'http://192.168.1.5:3000');
    expect(AppConstants.prodBaseUrl, 'https://snapverify.onrender.com');
    expect(
      AppConstants.stagingBaseUrl,
      'https://snapverify-backend-staging.onrender.com',
    );
  });

  test('environment flags match the selected environment', () {
    switch (AppConstants.environment) {
      case 'dev':
        expect(AppConstants.isProduction, isFalse);
        expect(AppConstants.isStaging, isFalse);
        expect(AppConstants.isReleaseBuild, isFalse);
        break;
      case 'staging':
        expect(AppConstants.isProduction, isFalse);
        expect(AppConstants.isStaging, isTrue);
        expect(AppConstants.isReleaseBuild, isTrue);
        break;
      case 'prod':
        expect(AppConstants.isProduction, isTrue);
        expect(AppConstants.isStaging, isFalse);
        expect(AppConstants.isReleaseBuild, isTrue);
        break;
    }
  });

  test('environment selects the expected backend', () {
    final expected = _explicitBaseUrl.isNotEmpty
        ? _explicitBaseUrl
        : switch (AppConstants.environment) {
            'prod' => AppConstants.prodBaseUrl,
            'staging' => AppConstants.stagingBaseUrl,
            _ => AppConstants.devDeviceBaseUrl,
          };

    expect(AppConstants.baseUrl, expected);
    if (!AppConstants.hasExplicitBaseUrl && AppConstants.environment == 'dev') {
      expect(AppConstants.baseUrl, 'http://192.168.1.5:3000');
    }
    if (!AppConstants.hasExplicitBaseUrl && AppConstants.environment == 'prod') {
      expect(AppConstants.baseUrl, 'https://snapverify.onrender.com');
    }
    if (!AppConstants.hasExplicitBaseUrl &&
        AppConstants.environment == 'staging') {
      expect(
        AppConstants.baseUrl,
        'https://snapverify-backend-staging.onrender.com',
      );
    }
  });

  test('environment summary is easy to verify', () {
    expect(
      AppConstants.environmentSummary,
      contains(AppConstants.environment.toUpperCase()),
    );
    expect(AppConstants.environmentSummary, contains(AppConstants.baseUrl));
  });

  test('token durations are unchanged', () {
    expect(AppConstants.accessTokenExpiry, const Duration(minutes: 15));
  });
}
