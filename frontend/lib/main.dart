import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/tailwind.dart';
import 'core/utils/toast_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/business_switcher_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isNavigating = false;
  bool _initialNavigated = false;

  @override
  void initState() {
    super.initState();
    // Initial navigation only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authNotifierProvider);
      _handleAuthChange(authState);
      _initialNavigated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      print('[Main] Auth state changed: ${previous?.status} → ${next.status}');
      _handleAuthChange(next);
    });

    return MaterialApp(
      title: 'SnapVerify',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: ToastService.scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TwColors.sky500,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      home: const Scaffold(),
    );
  }

  void _handleAuthChange(AuthState authState) {
    if (_isNavigating) return; // Prevent navigation loops

    // Set guard BEFORE scheduling callback, so rapid successive calls
    // (same frame) are all gated correctly.
    _isNavigating = true;

    print('[Main] Handling auth change: ${authState.status}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigatorKey.currentState == null) {
        _isNavigating = false;
        return;
      }

      try {
        if (authState.status == AuthStatus.authenticated) {
          print('[Main] Navigating to HomeScreen');
          if (_initialNavigated) ToastService.showSuccess('Welcome back!');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else if (authState.status == AuthStatus.requiresBusinessSelection) {
          print('[Main] Navigating to BusinessSwitcherScreen (initial selection)');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const BusinessSwitcherScreen(isInitialSelection: true)),
            (route) => false,
          );
        } else if (authState.status == AuthStatus.unauthenticated) {
          print('[Main] Navigating to LoginScreen');
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        // Error is displayed by individual screens via _buildErrorState widgets
        // No duplicate toast needed here
      } finally {
        _isNavigating = false;
      }
    });
  }
}
