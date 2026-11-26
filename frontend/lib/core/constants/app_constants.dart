import 'package:flutter/foundation.dart';

/// Centralized, environment-based API configuration.
///
/// The backend base URL is resolved from `APP_ENV` and an optional
/// `--dart-define=API_BASE_URL=...` override.
///
/// Build variants:
///   * Local development:
///       flutter run
///       flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   * Staging:
///       flutter run --dart-define=APP_ENV=staging
///   * Production:
///       flutter build apk --release --dart-define=APP_ENV=prod
///
/// Release builds must declare APP_ENV explicitly. Dev builds keep the LAN
/// fallback so plain `flutter run` still works during local development.
class AppConstants {
  AppConstants._();

  // ── Known environment presets ──────────────────────────────────────────────

  /// Android emulator reaches the host loopback via this alias.
  static const String emulatorBaseUrl = 'http://10.0.2.2:3000';

  /// Current development machine's LAN IP. Used as the default for physical
  /// devices and plain runs. Update if your machine IP changes.
  static const String devDeviceBaseUrl = 'http://192.168.1.5:3000';

  static const String prodBaseUrl = 'https://snapverify.onrender.com';

  static const String stagingBaseUrl =
      'https://snapverify-backend-staging.onrender.com';

  // ── Resolved configuration ─────────────────────────────────────────────────

  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _envAppEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  static String get environment {
    final raw = _envAppEnv.trim().toLowerCase();
    if (raw.isEmpty) {
      if (kReleaseMode) {
        throw ArgumentError(
          'APP_ENV must be set for release builds. Use --dart-define=APP_ENV=dev|staging|prod.',
        );
      }
      return 'dev';
    }
    if (raw != 'dev' && raw != 'staging' && raw != 'prod') {
      throw ArgumentError(
        'Invalid APP_ENV: "$raw". Expected dev, staging, or prod.',
      );
    }
    return raw;
  }

  static bool get hasExplicitBaseUrl => _envBaseUrl.trim().isNotEmpty;

  static String get environmentSummary =>
      '${environment.toUpperCase()} ${hasExplicitBaseUrl ? 'custom' : 'preset'} $baseUrl';

  /// The backend base URL used by every API client in the app.
  static String get baseUrl {
    final provided = _envBaseUrl.trim();
    if (provided.isNotEmpty) {
      _validateBaseUrl(provided);
      return provided;
    }

    if (isProduction) {
      _validateBaseUrl(prodBaseUrl);
      return prodBaseUrl;
    }
    if (isStaging) {
      _validateBaseUrl(stagingBaseUrl);
      return stagingBaseUrl;
    }

    _validateBaseUrl(devDeviceBaseUrl);
    return devDeviceBaseUrl;
  }

  static bool get isProduction => environment == 'prod';

  static bool get isStaging => environment == 'staging';

  static bool get isReleaseBuild => environment != 'dev';

  static void _validateBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError(
        'Invalid API_BASE_URL: "$url". Must be a fully-qualified http(s) URL '
        'with a host (e.g. https://api.example.com).',
      );
    }

    if (isReleaseBuild && uri.scheme != 'https') {
      throw ArgumentError(
        '${environment.toUpperCase()} API_BASE_URL must use HTTPS. Got: "$url".',
      );
    }
  }

  // ── Auth / token lifetimes ─────────────────────────────────────────────────

  static const Duration accessTokenExpiry = Duration(minutes: 15);
}
