import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/language_provider.dart';
import 'core/tailwind.dart';
import 'core/utils/toast_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localizations.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/notifications_provider.dart';
import 'presentation/providers/reports_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/business_switcher_screen.dart';
import 'presentation/widgets/sv_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data so DateFormat can format am/om dates. Only the locales
  // the app can actually format are loaded — bare `initializeDateFormatting()`
  // pulls in every locale and adds avoidable time before the first frame.
  await Future.wait([
    initializeDateFormatting('en'),
    initializeDateFormatting('am'),
  ]);
  // Warm the prefs cache so the stored language is applied before first paint.
  await SharedPreferences.getInstance();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isNavigating = false;
  bool _hasNavigatedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthChange(ref.read(authNotifierProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh today's activity when returning to the app: the access token
    // may have expired while backgrounded, and cached report errors should
    // not outlive the trip to the background.
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).ensureFreshAccessToken();
      ref.invalidate(reportSummaryProvider);
      ref.invalidate(notificationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      debugPrint(
        '[Main] Auth state changed: ${previous?.status} → ${next.status}',
      );
      final previousStatus = previous?.status;
      if (previousStatus == next.status) return;
      _handleAuthChange(
        next,
        showWelcome:
            _hasNavigatedOnce &&
            previousStatus != AuthStatus.authenticated &&
            next.status == AuthStatus.authenticated,
      );
    });

    return MaterialApp(
      title: 'SnapVerify',
      locale: ref.watch(languageProvider).locale,
      supportedLocales: AppLocalizations.supportedLocales,
      // `AppLocalizations.supportedLocales` is alphabetical (am, en, om), so
      // the default resolution would fall back to Amharic. Pin English.
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) return candidate;
        }
        return const Locale('en');
      },
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        // `om` is a SnapVerify locale but not a Flutter Material/Cupertino
        // locale; these adapters keep Material/Cupertino widgets resolvable.
        ...fallbackLocalizationsDelegates,
      ],
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: ToastService.scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TwColors.primaryBg,
        cardColor: TwColors.cardBg,
        dividerColor: TwColors.slate700,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TwColors.sky500,
          brightness: Brightness.dark,
          surface: TwColors.cardBg,
        ),
        // Poppins stays the primary typeface; Noto Sans Ethiopic is only a
        // fallback so Amharic glyphs render on devices without a system
        // Ethiopic font.
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).apply(fontFamilyFallback: const ['NotoSansEthiopic', 'sans-serif']),
      ),
      // Shown while the stored session is being restored. A bare `Scaffold()`
      // here looked like a black screen and made a slow/timed-out restore
      // indistinguishable from a frozen app.
      home: const _StartupSplash(),
    );
  }

  void _handleAuthChange(AuthState authState, {bool showWelcome = false}) {
    if (authState.status == AuthStatus.initial) return; // Splash handles it
    if (_isNavigating) return; // Prevent navigation loops

    // Set guard BEFORE scheduling callback, so rapid successive calls
    // (same frame) are all gated correctly.
    _isNavigating = true;

    debugPrint('[Main] Handling auth change: ${authState.status}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigatorKey.currentState == null) {
        _isNavigating = false;
        return;
      }

      try {
        if (authState.status == AuthStatus.authenticated) {
          debugPrint('[Main] Navigating to HomeScreen');
          if (showWelcome) ToastService.showSuccess('Welcome back!');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else if (authState.status == AuthStatus.requiresBusinessSelection) {
          debugPrint(
            '[Main] Navigating to BusinessSwitcherScreen (initial selection)',
          );
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  const BusinessSwitcherScreen(isInitialSelection: true),
            ),
            (route) => false,
          );
        } else if (authState.status == AuthStatus.reconnecting) {
          debugPrint('[Main] Navigating to ReconnectScreen');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const _ReconnectScreen()),
            (route) => false,
          );
        } else if (authState.status == AuthStatus.unauthenticated) {
          debugPrint('[Main] Navigating to LoginScreen');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        // Error is displayed by individual screens via _buildErrorState widgets
        // No duplicate toast needed here
        if (authState.status != AuthStatus.initial) {
          _hasNavigatedOnce = true;
        }
      } finally {
        _isNavigating = false;
      }
    });
  }
}

/// First screen shown while `AuthNotifier` restores the stored session.
class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B1B2B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SnapVerify',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            SvLoader.page(),
          ],
        ),
      ),
    );
  }
}

/// Shown when a stored session exists but the backend could not be reached.
/// The tokens are kept, so retrying restores the session without re-entering
/// credentials once connectivity returns.
class _ReconnectScreen extends ConsumerWidget {
  const _ReconnectScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B2B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Reconnecting…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your session is saved. Check your connection and retry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).retryRestore(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
