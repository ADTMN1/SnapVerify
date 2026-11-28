import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/language_provider.dart';
import '../../core/utils/toast_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../ui/ui.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Mode: false = sign in, true = sign up.
  bool _isSignUp = false;
  // Sign-up step: 0 = details, 1 = email OTP.
  int _signUpStep = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _fullNameFocusNode = FocusNode();
  final _businessNameFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _fullNameFocused = false;
  bool _businessNameFocused = false;
  bool _confirmPasswordFocused = false;
  bool _otpFocused = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _emailError;
  String? _passwordError;
  String? _fullNameError;
  String? _businessNameError;
  String? _businessTypeError;
  String? _cityError;
  String? _confirmPasswordError;
  String? _otpError;

  String? _selectedBusinessType;
  String? _selectedCity;
  String _registeredEmail = '';

  bool _canResendOtp = false;
  int _resendTimer = 60;
  Timer? _resendTicker;

  final List<String> _businessTypes = const [
    'Restaurant',
    'Cafe',
    'Hotel',
    'Supermarket',
    'Pharmacy',
    'Retail Shop',
    'Electronics Store',
    'Clothing Store',
    'Other',
  ];

  final List<String> _cities = const [
    'Addis Ababa',
    'Adama',
    'Bahir Dar',
    'Bishoftu',
    'Debre Markos',
    'Dessie',
    'Dire Dawa',
    'Gambela',
    'Gondar',
    'Harar',
    'Hawassa',
    'Jimma',
    'Jijiga',
    'Mekelle',
    'Nekemte',
    'Shashamane',
    'Wolaita Sodo',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
    _fullNameFocusNode.addListener(() {
      setState(() => _fullNameFocused = _fullNameFocusNode.hasFocus);
    });
    _businessNameFocusNode.addListener(() {
      setState(() => _businessNameFocused = _businessNameFocusNode.hasFocus);
    });
    _confirmPasswordFocusNode.addListener(() {
      setState(
        () => _confirmPasswordFocused = _confirmPasswordFocusNode.hasFocus,
      );
    });
    _otpFocusNode.addListener(() {
      setState(() => _otpFocused = _otpFocusNode.hasFocus);
    });

    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _fullNameController.addListener(_clearError);
    _businessNameController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
    _otpController.addListener(_clearError);
  }

  @override
  void dispose() {
    ref.read(authNotifierProvider.notifier).clearError();
    _resendTicker?.cancel();
    for (final c in [
      _emailController,
      _passwordController,
      _fullNameController,
      _businessNameController,
      _confirmPasswordController,
      _otpController,
    ]) {
      c.removeListener(_clearError);
      c.dispose();
    }
    for (final f in [
      _emailFocusNode,
      _passwordFocusNode,
      _fullNameFocusNode,
      _businessNameFocusNode,
      _confirmPasswordFocusNode,
      _otpFocusNode,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearError() {
    ref.read(authNotifierProvider.notifier).clearError();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _fullNameError = null;
      _businessNameError = null;
      _businessTypeError = null;
      _cityError = null;
      _confirmPasswordError = null;
      _otpError = null;
    });
  }

  void _setMode(bool signUp) {
    if (_isSignUp == signUp) return;
    _resendTicker?.cancel();
    setState(() {
      _isSignUp = signUp;
      _signUpStep = 0;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _otpController.clear();
      _obscurePassword = true;
      _obscureConfirmPassword = true;
      _canResendOtp = false;
      _emailError = null;
      _passwordError = null;
      _fullNameError = null;
      _businessNameError = null;
      _businessTypeError = null;
      _cityError = null;
      _confirmPasswordError = null;
      _otpError = null;
    });
    ref.read(authNotifierProvider.notifier).clearError();
    FocusScope.of(context).unfocus();
  }

  Future<void> _submit() async {
    if (_isSignUp) {
      if (_signUpStep == 0) {
        await _signUp();
      } else {
        await _verifyOtp();
      }
    } else {
      await _login();
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Email or username is required.');
      return;
    }
    final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    final isUsername = RegExp(r'^[a-zA-Z0-9._-]{3,30}$').hasMatch(email.trim());
    final isPhone = RegExp(r'^\+?\d[\d\s-]{6,}$').hasMatch(email.trim());
    if (!isEmail && !isUsername && !isPhone) {
      setState(() => _emailError = 'Enter a valid email, username or phone.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .loginWithPassword(email, password, rememberMe: true);
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      setState(() => _fullNameError = 'Full name is required.');
      return;
    }
    final businessName = _businessNameController.text.trim();
    if (businessName.isEmpty) {
      setState(() => _businessNameError = 'Business name is required.');
      return;
    }
    if (_selectedBusinessType == null) {
      setState(() => _businessTypeError = 'Please select a business type.');
      return;
    }
    if (_selectedCity == null) {
      setState(() => _cityError = 'Please select a city.');
      return;
    }
    final password = _passwordController.text;
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
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password.');
      return;
    }
    if (password != confirm) {
      setState(() => _confirmPasswordError = 'Passwords do not match.');
      return;
    }

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(
          name: businessName,
          fullName: fullName,
          email: email,
          password: password,
          confirmPassword: confirm,
          type: _selectedBusinessType,
          city: _selectedCity!,
        );

    if (ok && mounted) {
      setState(() {
        _signUpStep = 1;
        _registeredEmail = email;
        _canResendOtp = false;
        _resendTimer = 60;
      });
      _startResendTimer();
      ToastService.showSuccess(
        'Account created. We sent a verification code to your email.',
      );
    }
  }

  void _startResendTimer() {
    _resendTicker?.cancel();
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendTimer = _resendTimer - 1);
      if (_resendTimer <= 0) {
        timer.cancel();
        setState(() => _canResendOtp = true);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _otpError = 'Verification code is required.');
      return;
    }
    if (otp.length != 6) {
      setState(() => _otpError = 'Verification code must be 6 digits.');
      return;
    }
    final verified = await ref
        .read(authNotifierProvider.notifier)
        .verifyEmail(email: _registeredEmail, otpCode: otp);
    if (verified && mounted) {
      ToastService.showSuccess('Email verified successfully!');
    }
  }

  Future<void> _resendOtp() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final result = await notifier.resendVerification(_registeredEmail);
    if (result['alreadyVerified'] == true && mounted) {
      ToastService.showInfo(
        'This email is already verified. Please log in instead.',
      );
      if (mounted) _setMode(false);
      return;
    }
    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error && mounted) {
      ToastService.showSuccess('New verification code sent!');
      setState(() {
        _canResendOtp = false;
        _resendTimer = 60;
      });
      _startResendTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final headerHeight = AppTokens.headerVisibleHeight + topInset;

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight + AppTokens.sheetTopRadius,
              child: _buildHeader(topInset),
            ),
            Positioned(
              top: headerHeight - AppTokens.sheetOverlap,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSheet(authState, bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double topInset) {
    final logoTop = topInset + AppTokens.logoTopGap;
    final headerHeight =
        AppTokens.headerVisibleHeight + topInset + AppTokens.sheetTopRadius;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppTokens.obsidian950,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTokens.ice50,
      ),
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: const _HeaderPatternPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: logoTop,
              left: 0,
              right: 0,
              child: Center(child: _buildLogo()),
            ),
          ],
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

  Widget _buildLogo() {
    return Semantics(
      label: 'App logo',
      child: SizedBox(
        width: AppTokens.logoTileSize + AppTokens.spaceXs,
        height: AppTokens.logoTileSize + AppTokens.spaceXs,
        child: const CustomPaint(painter: _AppLogoPainter()),
      ),
    );
  }

  bool get _showToggle => !_isSignUp || _signUpStep == 0;
  bool get _showBottomLine => !_isSignUp || _signUpStep == 0;

  Widget _buildSheet(AuthState authState, double bottomInset) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: AppTokens.ice50,
        systemNavigationBarDividerColor: AppTokens.ice50,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTokens.ice50,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTokens.sheetTopRadius),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverFillRemaining(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: AppTokens.formMaxWidth,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    AppTokens.sheetHorizontalPadding,
                                    AppTokens.sheetTopPadding,
                                    AppTokens.sheetHorizontalPadding,
                                    AppTokens.sheetBottomPadding + bottomInset,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(
                                        height:
                                            AppTokens.languageTopPadding +
                                            AppTokens.languageItemHeight +
                                            AppTokens.languagePillPadding * 2 +
                                            AppTokens.titleLanguageGap,
                                      ),
                                      _buildTitle(),
                                      if (_showToggle) ...[
                                        const SizedBox(
                                          height: AppTokens.titleToggleGap,
                                        ),
                                        _buildToggle(),
                                        const SizedBox(
                                          height: AppTokens.toggleFieldsGap,
                                        ),
                                      ],
                                      if (_isSignUp && _signUpStep == 1)
                                        const SizedBox(
                                          height: AppTokens.titleToggleGap,
                                        ),
                                      if (_isSignUp && _signUpStep == 1)
                                        _buildOtpFields()
                                      else
                                        _buildFields(),
                                      if (!_isSignUp) ...[
                                        const SizedBox(
                                          height: AppTokens.fieldGap,
                                        ),
                                        _buildForgotPassword(),
                                      ],
                                      if (authState.status ==
                                          AuthStatus.error) ...[
                                        const SizedBox(
                                          height: AppTokens.fieldGap,
                                        ),
                                        _buildErrorBox(authState),
                                      ],
                                      const SizedBox(
                                        height: AppTokens.buttonGap,
                                      ),
                                      _buildPrimaryButton(authState),
                                      const SizedBox(
                                        height: AppTokens.bottomGap,
                                      ),
                                      if (_showBottomLine) _buildBottomLine(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: AppTokens.languageTopPadding,
              right: AppTokens.languageRightPadding,
              child: _buildLanguageSwitcher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    String title;
    if (_isSignUp && _signUpStep == 1) {
      title = 'Verify your email';
    } else if (_isSignUp) {
      title = AppLocalizations.of(context)!.createAccount;
    } else {
      title = AppLocalizations.of(context)!.signIn;
    }
    return Text(title, textAlign: TextAlign.center, style: AppText.authTitle);
  }

  Widget _buildToggle() {
    return AuthSegmentedToggle(
      items: [
        AuthToggleItem(
          label: 'Sign in',
          selected: !_isSignUp,
          onTap: () => _setMode(false),
        ),
        AuthToggleItem(
          label: 'Sign up',
          selected: _isSignUp,
          onTap: () => _setMode(true),
        ),
      ],
    );
  }

  Widget _buildFields() {
    if (!_isSignUp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            focused: _emailFocused,
            label: AppLocalizations.of(context)!.email,
            hint: 'email, username or phone',
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            autofill: AutofillHints.email,
            textInputAction: TextInputAction.next,
            onNext: () => _passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: AppTokens.fieldGap),
          _buildField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            focused: _passwordFocused,
            label: AppLocalizations.of(context)!.password,
            hint: 'Enter password',
            error: _passwordError,
            obscure: _obscurePassword,
            autofill: AutofillHints.password,
            textInputAction: TextInputAction.done,
            onDone: _submit,
            suffix: _obscureToggle(
              obscure: _obscurePassword,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          controller: _fullNameController,
          focusNode: _fullNameFocusNode,
          focused: _fullNameFocused,
          label: AppLocalizations.of(context)!.fullName,
          hint: 'Meseret Alemu',
          error: _fullNameError,
          autofill: AutofillHints.name,
          textInputAction: TextInputAction.next,
          onNext: () => _emailFocusNode.requestFocus(),
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          focused: _emailFocused,
          label: AppLocalizations.of(context)!.email,
          hint: 'name@business.et',
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          autofill: AutofillHints.email,
          textInputAction: TextInputAction.next,
          onNext: () => _businessNameFocusNode.requestFocus(),
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildField(
          controller: _businessNameController,
          focusNode: _businessNameFocusNode,
          focused: _businessNameFocused,
          label: AppLocalizations.of(context)!.businessName,
          hint: 'My Awesome Business',
          error: _businessNameError,
          textInputAction: TextInputAction.next,
          onNext: () => _passwordFocusNode.requestFocus(),
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildDropdownField(
          label: AppLocalizations.of(context)!.businessType,
          value: _selectedBusinessType,
          placeholder: 'Select business type',
          icon: Icons.category_outlined,
          error: _businessTypeError,
          onTap: _openBusinessTypePicker,
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildDropdownField(
          label: AppLocalizations.of(context)!.city,
          value: _selectedCity,
          placeholder: 'Select city',
          icon: Icons.location_on_outlined,
          error: _cityError,
          onTap: _openCityPicker,
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          focused: _passwordFocused,
          label: AppLocalizations.of(context)!.password,
          hint: 'Enter password',
          error: _passwordError,
          obscure: _obscurePassword,
          autofill: AutofillHints.newPassword,
          textInputAction: TextInputAction.next,
          onNext: () => _confirmPasswordFocusNode.requestFocus(),
          suffix: _obscureToggle(
            obscure: _obscurePassword,
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: AppTokens.fieldGap),
        _buildField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          focused: _confirmPasswordFocused,
          label: AppLocalizations.of(context)!.confirmPassword,
          hint: 'Re-enter password',
          error: _confirmPasswordError,
          obscure: _obscureConfirmPassword,
          autofill: AutofillHints.newPassword,
          textInputAction: TextInputAction.done,
          onDone: _submit,
          suffix: _obscureToggle(
            obscure: _obscureConfirmPassword,
            onTap: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a 6-digit code to $_registeredEmail. Enter it below to verify your email.',
          textAlign: TextAlign.center,
          style: AppText.authSubtitle,
        ),
        const SizedBox(height: AppTokens.toggleFieldsGap),
        _buildField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          focused: _otpFocused,
          label: 'Verification code',
          hint: '123456',
          error: _otpError,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onDone: _submit,
        ),
        const SizedBox(height: AppTokens.fieldGap),
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
      ],
    );
  }

  Widget _obscureToggle({required bool obscure, required VoidCallback onTap}) {
    return _EyeButton(obscure: obscure, onTap: onTap);
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String placeholder,
    required IconData icon,
    String? error,
    required VoidCallback onTap,
  }) {
    return _DropdownBox(
      label: label,
      value: value,
      placeholder: placeholder,
      icon: icon,
      error: error,
      onTap: onTap,
    );
  }

  Future<void> _openBusinessTypePicker() async {
    final selected = await _showOptionPicker(
      title: AppLocalizations.of(context)!.businessType,
      options: _businessTypes,
      selected: _selectedBusinessType,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedBusinessType = selected;
      _businessTypeError = null;
    });
  }

  Future<void> _openCityPicker() async {
    final selected = await _showOptionPicker(
      title: AppLocalizations.of(context)!.city,
      options: _cities,
      selected: _selectedCity,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedCity = selected;
      _cityError = null;
    });
  }

  Future<String?> _showOptionPicker({
    required String title,
    required List<String> options,
    required String? selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTokens.ice50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      builder: (sheetContext) => AuthOptionSheet<String>(
        title: title,
        options: options,
        labelFor: (option) => option,
        selected: selected,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool focused,
    required String label,
    required String hint,
    String? error,
    bool obscure = false,
    TextInputType? keyboardType,
    String? autofill,
    TextInputAction? textInputAction,
    VoidCallback? onNext,
    VoidCallback? onDone,
    Widget? suffix,
    int? maxLength,
  }) {
    return _InputBox(
      controller: controller,
      focusNode: focusNode,
      focused: focused,
      label: label,
      hint: hint,
      error: error,
      obscure: obscure,
      keyboardType: keyboardType,
      autofill: autofill,
      textInputAction: textInputAction,
      onNext: onNext,
      onDone: onDone,
      suffix: suffix,
      maxLength: maxLength,
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: AuthTextLink(
        label: AppLocalizations.of(context)!.forgotPassword,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBox(AuthState authState) {
    return AuthErrorBanner(
      message:
          authState.errorMessage ??
          AppLocalizations.of(context)!.anErrorOccurred,
    );
  }

  Widget _buildPrimaryButton(AuthState authState) {
    final isLoading = authState.status == AuthStatus.loading;
    final label = _isSignUp
        ? (_signUpStep == 0
              ? AppLocalizations.of(context)!.createAccount
              : 'Verify')
        : AppLocalizations.of(context)!.signIn;
    final loadingLabel = _isSignUp
        ? (_signUpStep == 0 ? 'Creating account' : 'Verifying')
        : 'Signing in';

    return AuthPrimaryButton(
      label: label,
      loadingLabel: loadingLabel,
      isLoading: isLoading,
      onPressed: _submit,
    );
  }

  Widget _buildBottomLine() {
    final prompt = _isSignUp
        ? 'Already have an account?'
        : "Don't have an account?";
    final action = _isSignUp ? 'Sign in' : 'Sign up';
    return AuthBottomLine(
      prompt: prompt,
      action: action,
      onTap: () => _setMode(!_isSignUp),
    );
  }
}

class _InputBox extends AuthTextField {
  const _InputBox({
    required super.controller,
    required super.focusNode,
    required super.focused,
    required super.label,
    required super.hint,
    super.error,
    super.obscure,
    super.keyboardType,
    super.autofill,
    super.textInputAction,
    super.onNext,
    super.onDone,
    super.suffix,
    super.maxLength,
  });
}

class _DropdownBox extends AuthDropdownField {
  const _DropdownBox({
    required super.label,
    required super.value,
    required super.placeholder,
    required super.icon,
    super.error,
    required super.onTap,
  });
}

class _EyeButton extends PasswordVisibilityButton {
  const _EyeButton({required super.obscure, required super.onTap});
}

class _HeaderPatternPainter extends AppHeaderPatternPainter {
  const _HeaderPatternPainter() : super();
}

class _AppLogoPainter extends AppLogoPainter {
  const _AppLogoPainter() : super(color: AppTokens.white);
}
