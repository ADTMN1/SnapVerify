import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/language_provider.dart';
import '../../core/utils/toast_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../ui/ui.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Focus States
  bool _emailFocused = false;
  bool _otpFocused = false;
  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;

  // Validation Errors
  String? _emailError;
  String? _otpError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _emailController.addListener(_clearError);
    _otpController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
  }

  void _clearError() {
    ref.read(authNotifierProvider.notifier).clearError();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  void _setupFocusListeners() {
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _otpFocusNode.addListener(() {
      setState(() => _otpFocused = _otpFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
    _confirmPasswordFocusNode.addListener(() {
      setState(
        () => _confirmPasswordFocused = _confirmPasswordFocusNode.hasFocus,
      );
    });
  }

  @override
  void dispose() {
    ref.read(authNotifierProvider.notifier).clearError();
    _emailController.removeListener(_clearError);
    _otpController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _confirmPasswordController.removeListener(_clearError);
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  bool _otpSent = false;
  bool _canResendOtp = false;
  int _resendTimer = 60;

  Future<void> _startResendTimer() async {
    for (int i = 59; i >= 0; i--) {
      if (!mounted) return;
      setState(() => _resendTimer = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() => _canResendOtp = true);
    }
  }

  Future<void> _sendResetOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.forgotPassword(email);
    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error && mounted) {
      setState(() {
        _otpSent = true;
        _canResendOtp = false;
        _resendTimer = 60;
      });
      _startResendTimer();
      ToastService.showSuccess(
        'If the account exists, a reset code has been sent.',
      );
    }
  }

  Future<void> _resendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.forgotPassword(email);
    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error && mounted) {
      setState(() => _canResendOtp = false);
      _startResendTimer();
      ToastService.showSuccess('New reset code sent!');
    }
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim().toLowerCase();

    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _otpError = 'Verification code is required.');
      return;
    }
    if (otp.length != 6) {
      setState(() => _otpError = 'Verification code must be 6 digits.');
      return;
    }

    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return;
    }
    if (password.length < 8) {
      setState(
        () => _passwordError = 'Password must be at least 8 characters.',
      );
      return;
    }

    final confirmPassword = _confirmPasswordController.text.trim();
    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _confirmPasswordError = 'Passwords do not match.');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(email, otp, password);

    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error) {
      ToastService.showSuccess('Password reset successfully!');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sheetHorizontalPadding,
              vertical: AppTokens.sheetBottomPadding,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTokens.formMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTopBar(
                      onBack: () => Navigator.pop(context),
                      trailing: _buildLanguageSwitcher(),
                    ),
                    const SizedBox(height: AppTokens.titleToggleGap),
                    _buildTitle(
                      'Reset Password',
                      'Enter your email and we\'ll send you a verification code',
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _buildEmailField(),
                    if (_otpSent) ...[
                      const SizedBox(height: AppTokens.fieldGap),
                      _buildOtpField(),
                      const SizedBox(height: AppTokens.fieldErrorGap),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AuthTextLink(
                          label: _canResendOtp
                              ? 'Resend code'
                              : 'Resend code ($_resendTimer)',
                          onPressed: _resendOtp,
                          enabled: _canResendOtp,
                        ),
                      ),
                      const SizedBox(height: AppTokens.fieldGap),
                      _buildPasswordField(),
                      const SizedBox(height: AppTokens.fieldGap),
                      _buildConfirmPasswordField(),
                    ],
                    const SizedBox(height: AppTokens.buttonGap),
                    _buildNavigationButtons(authState),
                    const SizedBox(height: AppTokens.bottomGap),
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    final selected = ref.watch(languageProvider);
    return AuthLanguagePill(
      items: [
        for (final lang in AppLanguage.values)
          AuthLanguageItem(
            shortName: lang.shortName,
            label: 'Language ${lang.displayName}',
            selected: lang == selected,
            onTap: () => ref.read(languageProvider.notifier).select(lang),
          ),
      ],
    );
  }

  Widget _buildTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, textAlign: TextAlign.center, style: AppText.authTitle),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppText.authSubtitle,
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    return AuthTextField(
      controller: _otpController,
      focusNode: _otpFocusNode,
      focused: _otpFocused,
      label: 'Verification code',
      hint: '123456',
      error: _otpError,
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildEmailField() {
    return AuthTextField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      focused: _emailFocused,
      label: AppLocalizations.of(context)!.email,
      hint: 'you@example.com',
      error: _emailError,
      keyboardType: TextInputType.emailAddress,
      autofill: AutofillHints.email,
    );
  }

  Widget _buildPasswordField() {
    return AuthTextField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      focused: _passwordFocused,
      label: AppLocalizations.of(context)!.password,
      hint: '••••••••',
      error: _passwordError,
      obscure: _obscurePassword,
      autofill: AutofillHints.password,
      suffix: PasswordVisibilityButton(
        obscure: _obscurePassword,
        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return AuthTextField(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocusNode,
      focused: _confirmPasswordFocused,
      label: AppLocalizations.of(context)!.confirmPassword,
      hint: '••••••••',
      error: _confirmPasswordError,
      obscure: _obscureConfirmPassword,
      autofill: AutofillHints.password,
      suffix: PasswordVisibilityButton(
        obscure: _obscureConfirmPassword,
        onTap: () =>
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      ),
    );
  }

  Widget _buildNavigationButtons(AuthState authState) {
    if (authState.status == AuthStatus.loading) {
      return const Center(child: SvLoader.page());
    }

    if (authState.status == AuthStatus.error) {
      return _buildErrorState(authState);
    }

    final text = _otpSent ? 'Reset Password' : 'Send Code';
    return AuthPrimaryButton(
      label: text,
      loadingLabel: text,
      isLoading: false,
      onPressed: _otpSent ? _submitReset : _sendResetOtp,
    );
  }

  Widget _buildErrorState(AuthState authState) {
    void clearError() {
      ref.read(authNotifierProvider.notifier).clearError();
    }

    return Column(
      children: [
        AuthErrorBanner(
          title: AppLocalizations.of(context)!.error,
          message:
              authState.errorMessage ??
              AppLocalizations.of(context)!.anErrorOccurred,
          retryLabel: AppLocalizations.of(context)!.retry,
          onRetry: clearError,
        ),
        const SizedBox(height: AppTokens.fieldGap),
        AuthPrimaryButton(
          label: 'Try Again',
          loadingLabel: 'Try Again',
          isLoading: false,
          onPressed: clearError,
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return AuthBottomLine(
      prompt: AppLocalizations.of(context)!.alreadyHaveAccount,
      action: AppLocalizations.of(context)!.loginNow,
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
    );
  }
}
