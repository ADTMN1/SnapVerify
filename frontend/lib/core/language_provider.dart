import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/providers/auth_provider.dart';

/// Languages shipped by SnapVerify.
enum AppLanguage {
  english('en', 'EN', 'English'),
  amharic('am', 'AM', 'አማርኛ'),
  oromo('om', 'OM', 'Afaan Oromoo');

  const AppLanguage(this.code, this.shortName, this.displayName);

  /// BCP-47 code used by ARB files, `MaterialApp` and `intl`.
  final String code;

  /// Compact label used by the inline language switcher.
  final String shortName;

  /// Native name of the language, shown in the language settings screen.
  final String displayName;

  Locale get locale => Locale(code);

  /// Locale used for `intl` date/number/currency formatting.
  ///
  /// `intl` 0.20.x ships `en` and `am` data but not `om`; Oromo falls back to
  /// `en` (Latin script) instead of throwing `Invalid locale "om"`.
  String get formatterLocale => this == oromo ? 'en' : code;

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Maps a device locale tag (e.g. `am-ET`) to the closest supported language.
  static AppLanguage fromLocale(Locale? locale) {
    if (locale == null) return AppLanguage.english;
    return fromCode(locale.languageCode) ?? AppLanguage.english;
  }
}

/// Holds the active UI language and persists the selection.
///
/// Two preference scopes are used:
/// - `snapverify.language` is the device default, applied before login and for
///   users who never chose a language.
/// - `snapverify.language.user.<userId>` stores each authenticated user's own
///   choice, so two users sharing one device keep independent preferences.
class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier(this._ref) : super(AppLanguage.english) {
    _ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) restore();
    });
    restore();
  }

  static const defaultPreferencesKey = 'snapverify.language';

  static String userPreferencesKey(String userId) =>
      '$defaultPreferencesKey.user.$userId';

  final Ref _ref;

  /// Guards against a pending [restore] overwriting a newer [select].
  int _revision = 0;

  /// Loads the persisted preference for the current context.
  Future<void> restore() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || revision != _revision) return;
    final userId = _ref.read(currentUserIdProvider);
    final stored =
        (userId == null ? null : prefs.getString(userPreferencesKey(userId))) ??
        prefs.getString(defaultPreferencesKey);
    _apply(AppLanguage.fromCode(stored) ?? AppLanguage.english);
  }

  /// Persists [language] for this device and, when signed in, for this user.
  Future<void> select(AppLanguage language) async {
    _revision++;
    _apply(language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(defaultPreferencesKey, language.code);
    final userId = _ref.read(currentUserIdProvider);
    if (userId != null) {
      await prefs.setString(userPreferencesKey(userId), language.code);
    }
  }

  void _apply(AppLanguage language) {
    state = language;
    Intl.defaultLocale = language.formatterLocale;
  }
}

/// The id of the signed-in user, or `null` when signed out.
///
/// Exposed separately so the language layer can be tested without booting the
/// full authentication stack.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authNotifierProvider.select((state) => state.user?.id)),
);

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) => LanguageNotifier(ref),
);

/// Convenience accessor for the active [Locale].
final localeProvider = Provider<Locale>(
  (ref) => ref.watch(languageProvider).locale,
);
