import 'package:snapverify/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('baseUrl is never empty and is a valid http(s) URL', () {
    final url = AppConstants.baseUrl;
    expect(url, isNotEmpty);
    expect(url, matches(r'^https?://'));
  });

  test('preset constants are correct', () {
    expect(AppConstants.emulatorBaseUrl, 'http://10.0.2.2:3000');
    expect(AppConstants.devDeviceBaseUrl, 'http://192.168.100.93:3000');
    expect(AppConstants.prodBaseUrl, startsWith('https://'));
  });

  test('token durations are unchanged', () {
    expect(AppConstants.accessTokenExpiry, const Duration(minutes: 15));
  });
}