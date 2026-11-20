import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapverify/core/language_provider.dart';
import 'package:snapverify/l10n/app_localizations.dart';
import 'package:snapverify/l10n/fallback_localizations.dart';
import 'package:snapverify/presentation/screens/language_settings_screen.dart';

/// Minimal app that mirrors the real `MaterialApp` localization wiring so the
/// language switch can be exercised end to end.
const _localizationDelegates = <LocalizationsDelegate<dynamic>>[
  ...AppLocalizations.localizationsDelegates,
  ...fallbackLocalizationsDelegates,
];

class _LanguageProbe extends ConsumerWidget {
  const _LanguageProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return MaterialApp(
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) return candidate;
        }
        return const Locale('en');
      },
      localizationsDelegates: _localizationDelegates,
      home: const _ProbeHome(),
    );
  }
}

class _ProbeHome extends ConsumerWidget {
  const _ProbeHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          Text(l10n.welcomeBack),
          for (final option in AppLanguage.values)
            TextButton(
              onPressed: () =>
                  ref.read(languageProvider.notifier).select(option),
              child: Text(option.code),
            ),
        ],
      ),
    );
  }
}

ProviderContainer _container({String? userId}) {
  return ProviderContainer(
    overrides: [currentUserIdProvider.overrideWithValue(userId)],
  );
}

Map<String, dynamic> _readArb(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((key) => !key.startsWith('@@')).toSet();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Intl.defaultLocale = null;
  });

  group('ARB files', () {
    test('en, am and om define exactly the same keys', () {
      final en = _readArb('lib/l10n/app_en.arb');
      final am = _readArb('lib/l10n/app_am.arb');
      final om = _readArb('lib/l10n/app_om.arb');

      final enKeys = _messageKeys(en);
      expect(enKeys, isNotEmpty);
      expect(_messageKeys(am), enKeys);
      expect(_messageKeys(om), enKeys);

      expect(en['@@locale'], 'en');
      expect(am['@@locale'], 'am');
      expect(om['@@locale'], 'om');
    });

    test('every message has a non-empty translation', () {
      for (final path in [
        'lib/l10n/app_en.arb',
        'lib/l10n/app_am.arb',
        'lib/l10n/app_om.arb',
      ]) {
        final arb = _readArb(path);
        arb.forEach((key, value) {
          if (key.startsWith('@@')) return;
          expect(value, isA<String>());
          expect((value as String).trim(), isNotEmpty, reason: '$path:$key');
        });
      }
    });
  });

  group('AppLocalizations', () {
    test('loads every supported locale', () async {
      for (final language in AppLanguage.values) {
        final l10n = await AppLocalizations.delegate.load(language.locale);
        expect(l10n.localeName, language.code);
        expect(l10n.welcomeBack, isNotEmpty);
      }
    });

    test('supportedLocales covers en, am and om', () {
      final codes = AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet();
      expect(codes, containsAll(<String>['en', 'am', 'om']));
    });

    test('unsupported locales are not claimed by the delegate', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    });
  });

  group('LanguageNotifier', () {
    test('defaults to English when nothing is stored', () {
      final container = _container();
      addTearDown(container.dispose);
      expect(container.read(languageProvider), AppLanguage.english);
    });

    test('persists the selected language', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(languageProvider.notifier).select(AppLanguage.amharic);

      expect(container.read(languageProvider), AppLanguage.amharic);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LanguageNotifier.defaultPreferencesKey), 'am');
    });

    test('restores the language after a restart', () async {
      final first = _container();
      await first.read(languageProvider.notifier).select(AppLanguage.oromo);
      first.dispose();

      final second = _container();
      addTearDown(second.dispose);
      await second.read(languageProvider.notifier).restore();

      expect(second.read(languageProvider), AppLanguage.oromo);
    });

    test('keeps preferences independent per authenticated user', () async {
      final owner = _container(userId: 'user-owner');
      await owner.read(languageProvider.notifier).select(AppLanguage.amharic);
      owner.dispose();

      final manager = _container(userId: 'user-manager');
      await manager.read(languageProvider.notifier).select(AppLanguage.oromo);
      manager.dispose();

      final ownerAgain = _container(userId: 'user-owner');
      addTearDown(ownerAgain.dispose);
      await ownerAgain.read(languageProvider.notifier).restore();
      expect(ownerAgain.read(languageProvider), AppLanguage.amharic);

      final managerAgain = _container(userId: 'user-manager');
      addTearDown(managerAgain.dispose);
      await managerAgain.read(languageProvider.notifier).restore();
      expect(managerAgain.read(languageProvider), AppLanguage.oromo);
    });

    test('per-user keys are scoped by user id', () {
      expect(
        LanguageNotifier.userPreferencesKey('user-1'),
        isNot(LanguageNotifier.defaultPreferencesKey),
      );
      expect(
        LanguageNotifier.userPreferencesKey('user-1'),
        isNot(LanguageNotifier.userPreferencesKey('user-2')),
      );
    });
  });

  testWidgets('language switching updates the app immediately', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _LanguageProbe(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back!'), findsOneWidget);

    await tester.tap(find.text('am'));
    await tester.pumpAndSettle();
    expect(find.text('እንኳን ደህና መጡ!'), findsOneWidget);
    expect(container.read(languageProvider), AppLanguage.amharic);

    await tester.tap(find.text('om'));
    await tester.pumpAndSettle();
    expect(find.text('Galatoomi!'), findsOneWidget);
    expect(container.read(languageProvider), AppLanguage.oromo);
  });

  testWidgets('falls back to English for unsupported device locales',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (locale, supported) {
            if (locale == null) return const Locale('en');
            for (final candidate in supported) {
              if (candidate.languageCode == locale.languageCode) {
                return candidate;
              }
            }
            return const Locale('en');
          },
          localizationsDelegates: _localizationDelegates,
          home: const _ProbeHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  group('intl formatting', () {
    test('every language has a usable formatting locale', () async {
      await initializeDateFormatting();
      for (final language in AppLanguage.values) {
        Intl.defaultLocale = language.formatterLocale;
        expect(
          () => DateFormat('MMM d, yyyy').format(DateTime.utc(2026, 11, 17)),
          returnsNormally,
          reason: language.code,
        );
        expect(
          () => NumberFormat.decimalPattern().format(1234567.89),
          returnsNormally,
          reason: language.code,
        );
        expect(
          () => NumberFormat.currency(symbol: 'ETB').format(1234567.89),
          returnsNormally,
          reason: language.code,
        );
      }
    });

    test('Oromo uses the English formatter fallback', () {
      expect(AppLanguage.english.formatterLocale, 'en');
      expect(AppLanguage.amharic.formatterLocale, 'am');
      expect(AppLanguage.oromo.formatterLocale, 'en');
    });
  });

  testWidgets('language settings screen lists and applies every language',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LanguageSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('አማርኛ'), findsOneWidget);
    expect(find.text('Afaan Oromoo'), findsOneWidget);

    await tester.tap(find.text('አማርኛ'));
    await tester.pumpAndSettle();
    expect(container.read(languageProvider), AppLanguage.amharic);
  });
}