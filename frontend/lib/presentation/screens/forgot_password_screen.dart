import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../core/language_provider.dart';
import '../../core/utils/toast_service.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/sv_loader.dart';
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 24),
                _buildCurrentStep(),
                const SizedBox(height: 32),
                _buildNavigationButtons(authState),
                const SizedBox(height: 32),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TwColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TwColors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: TwColors.white,
              size: 20,
            ),
          ),
        ),
        _buildLanguageSwitcher(),
      ],
    );
  }

  Widget _buildLanguageSwitcher() {
    final selected = ref.watch(languageProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: AppLanguage.values.map((lang) {
          final isSelected = lang == selected;
          return GestureDetector(
            onTap: () => ref.read(languageProvider.notifier).select(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(
                right: lang == AppLanguage.values.last ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? TwColors.brightGreen.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(
                        color: TwColors.brightGreen.withOpacity(0.4),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Text(
                lang.shortName,
                style: TextStyle(
                  color: isSelected ? TwColors.brightGreen : TwColors.slate400,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          'Reset Password',
          'Enter your email and we\'ll send you a verification code',
        ),
        const SizedBox(height: 28),
        _buildEmailField(),
        if (_otpSent) ...[
          const SizedBox(height: 20),
          _buildOtpField(),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _canResendOtp ? _resendOtp : null,
              child: Text(
                _canResendOtp ? 'Resend code' : 'Resend code ($_resendTimer)',
                style: TextStyle(
                  color: _canResendOtp
                      ? TwColors.brightGreen
                      : TwColors.slate400,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPasswordField(),
          const SizedBox(height: 20),
          _buildConfirmPasswordField(),
        ],
      ],
    );
  }

  Widget _buildOtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUniqueInput(
          controller: _otpController,
          focusNode: _otpFocusNode,
          isFocused: _otpFocused,
          label: 'Verification code',
          hint: '123456',
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          hasError: _otpError != null,
        ),
        if (_otpError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _otpError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TwColors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            color: TwColors.slate400,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUniqueInput(
          controller: _emailController,
          focusNode: _emailFocusNode,
          isFocused: _emailFocused,
          label: AppLocalizations.of(context)!.email,
          hint: 'you@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          hasError: _emailError != null,
        ),
        if (_emailError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _emailError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUniqueInput(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          isFocused: _passwordFocused,
          label: AppLocalizations.of(context)!.password,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _passwordFocused
                  ? TwColors.brightGreen
                  : TwColors.slate400,
              size: 16,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          hasError: _passwordError != null,
        ),
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _passwordError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUniqueInput(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          isFocused: _confirmPasswordFocused,
          label: AppLocalizations.of(context)!.confirmPassword,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _confirmPasswordFocused
                  ? TwColors.brightGreen
                  : TwColors.slate400,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          hasError: _confirmPasswordError != null,
        ),
        if (_confirmPasswordError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _confirmPasswordError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUniqueInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    int? maxLength,
    Widget? suffixIcon,
    bool hasError = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? TwColors.red500
              : isFocused
              ? TwColors.brightGreen
              : TwColors.white.withOpacity(0.08),
          width: hasError || isFocused ? 1.2 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: hasError
                      ? TwColors.red500.withOpacity(0.1)
                      : TwColors.brightGreen.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(
          color: TwColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 8, right: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFocused
                  ? TwColors.brightGreen.withOpacity(0.1)
                  : TwColors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              size: 16,
            ),
          ),
          suffixIcon: suffixIcon,
          label: Text(
            label,
            style: TextStyle(
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: TwColors.white.withOpacity(0.3),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          counterText: '',
        ),
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

    return _buildNextButton(
      onPressed: _otpSent ? _submitReset : _sendResetOtp,
      text: _otpSent ? 'Reset Password' : 'Send Code',
    );
  }

  Widget _buildErrorState(AuthState authState) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TwColors.red500.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TwColors.red500.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TwColors.red500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: TwColors.red500,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.error,
                      style: TextStyle(
                        color: TwColors.red500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authState.errorMessage ??
                          AppLocalizations.of(context)!.anErrorOccurred,
                      style: TextStyle(
                        color: TwColors.red500.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(authNotifierProvider.notifier).clearError();
                      },
                      child: Text(
                        AppLocalizations.of(context)!.retry,
                        style: TextStyle(
                          color: TwColors.red500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildNextButton(
          onPressed: () {
            ref.read(authNotifierProvider.notifier).clearError();
          },
          text: 'Try Again',
        ),
      ],
    );
  }

  Widget _buildNextButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: TwColors.brightGreen,
          foregroundColor: TwColors.primaryBg,
          disabledBackgroundColor: TwColors.brightGreen,
          disabledForegroundColor: TwColors.primaryBg,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.alreadyHaveAccount,
          style: TextStyle(
            color: TwColors.slate400,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            AppLocalizations.of(context)!.loginNow,
            style: TextStyle(
              color: TwColors.brightGreen,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
