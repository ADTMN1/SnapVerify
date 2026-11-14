/// Centralized, environment-based API configuration.
///
/// The backend base URL is resolved at compile time via Dart defines
/// (`--dart-define=API_BASE_URL=...`), falling back to a sensible local
/// development default when the define is absent.
///
/// Build variants:
///   * Android emulator:
///       flutter build ... --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   * Physical Android device on the same Wi-Fi as the dev machine:
///       flutter build ... --dart-define=API_BASE_URL=http://192.168.100.93:3000
///   * Production:
///       flutter build ... --dart-define=API_BASE_URL=https://api.snapverify.example
///
/// Without a define, the app defaults to the dev-machine IP so a plain
/// `flutter run` on the development computer keeps working out of the box.
class AppConstants {
  AppConstants._();

  // ── Known environment presets ──────────────────────────────────────────────

  /// Android emulator reaches the host loopback via this alias.
  static const String emulatorBaseUrl = 'http://10.0.2.2:3000';

  /// Current development machine's LAN IP. Used as the default for physical
  /// devices and plain runs. Update if your machine IP changes.
   static const String devDeviceBaseUrl = 'http://192.168.100.93:3000';

  /// Placeholder production domain. Override with --dart-define for real deploys.
  static const String prodBaseUrl = 'https://api.snapverify.example';

  // ── Resolved configuration ─────────────────────────────────────────────────

  /// Base URL supplied at compile time via `--dart-define=API_BASE_URL=...`.
  /// Empty when not supplied, so the default below takes effect.
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Build profile supplied via `--dart-define=APP_ENV=...`.
  /// One of: dev, prod. Defaults to dev.
  static const String _envAppEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// The backend base URL used by every API client in the app.
  ///
  /// Resolution order:
  ///   1. `--dart-define=API_BASE_URL=...` (explicit, wins for any target)
   /// 2. Dev-machine default (`192.168.100.93:3000`)
  static String get baseUrl {
    final provided = _envBaseUrl.trim();
    if (provided.isNotEmpty) {
      _validateBaseUrl(provided);
      return provided;
    }
    _validateBaseUrl(devDeviceBaseUrl);
    return devDeviceBaseUrl;
  }

  /// True when the app was built for a production environment.
  ///
  /// A production build MUST supply an explicit `API_BASE_URL` over HTTPS.
  /// This getter throws at access time if that requirement is violated, so a
  /// misconfigured release build fails loudly instead of silently talking to a
  /// development server over plain HTTP.
  static bool get isProduction => _envAppEnv == 'prod';

  /// Validates a configured base URL.
  ///
  /// In production the scheme MUST be HTTPS. A development build may use HTTP
  /// (emulator loopback or local Wi-Fi). Malformed URLs are rejected so a
  /// typo in `--dart-define` surfaces as a clear error rather than a runtime
  /// network failure.
  static void _validateBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError(
        'Invalid API_BASE_URL: "$url". Must be a fully-qualified URL ' +
            'with a host (e.g. https://api.example.com).',
      );
    }

    if (isProduction && uri.scheme != 'https') {
      throw ArgumentError(
        'Production API_BASE_URL must use HTTPS. Got: "$url".',
      );
    }
  }

  // ── Auth / token lifetimes ─────────────────────────────────────────────────

  static const Duration accessTokenExpiry = Duration(minutes: 15);
  static const Duration otpExpiry = Duration(minutes: 5);
}