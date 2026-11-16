import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../core/locales.dart';
import '../../core/utils/toast_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'activate_invitation_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  Language _selectedLanguage = Language.english;

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Validation Errors
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });

    // Add listeners to clear error state when user starts typing
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
  }

  @override
  void dispose() {
    ref.read(authNotifierProvider.notifier).clearError();
    _emailController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    ref.read(authNotifierProvider.notifier).clearError();
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  String _t(String key) {
    return LocaleStrings.strings[_selectedLanguage]?[key] ?? key;
  }

  void _toggleLanguage(Language lang) {
    setState(() => _selectedLanguage = lang);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    // Validate inputs
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return;
    }

    await ref.read(authNotifierProvider.notifier).loginWithPassword(
      email,
      password,
    );
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
                // Language Switcher
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildLanguageSwitcher(),
                ),
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildForm(authState),
                const SizedBox(height: 24),
                _buildCreateAccount(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: Language.values.map((lang) {
          final isSelected = lang == _selectedLanguage;
          return GestureDetector(
            onTap: () => _toggleLanguage(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(
                right: lang == Language.values.last ? 0 : 4,
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
                LocaleStrings.languageNames[lang]!,
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('welcome_back'),
          style: const TextStyle(
            color: TwColors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t('sign_in_continue'),
          style: TextStyle(
            color: TwColors.slate400,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEmailField(),
        const SizedBox(height: 20),
        _buildPasswordField(),
        const SizedBox(height: 8),
        _buildForgotPassword(),
        const SizedBox(height: 32),
        if (authState.status == AuthStatus.error)
          _buildErrorState()
        else
          _buildSubmitButton(),
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
          label: _t('email'),
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
          label: _t('password'),
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _passwordFocused ? TwColors.brightGreen : TwColors.slate400,
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
                )
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildSubmitButton() {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: TwColors.brightGreen,
          foregroundColor: TwColors.primaryBg,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(TwColors.primaryBg),
                ),
              )
            : Text(
                _t('sign_in'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
          );
        },
        child: Text(
          _t('forgot_password'),
          style: TextStyle(
            color: TwColors.brightGreen,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccount() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _t('no_account'),
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
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                _t('create_account'),
                style: TextStyle(
                  color: TwColors.brightGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _t('received_invitation'),
              style: TextStyle(
                color: TwColors.slate400,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActivateInvitationScreen()),                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                _t('activate_invitation'),
                style: TextStyle(
                  color: TwColors.brightGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final authState = ref.watch(authNotifierProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwColors.red500.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TwColors.red500.withOpacity(0.3),
        ),
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
                  _t('error'),
                  style: TextStyle(
                    color: TwColors.red500,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authState.errorMessage ?? _t('an_error_occurred'),
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
                    _t('retry'),
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
    );
  }
}





