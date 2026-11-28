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
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // State
  int _currentStep = 0;
  String _registeredEmail = '';
  bool _canResendOtp = false;
  int _resendTimer = 60;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  final _fullNameFocusNode = FocusNode();
  final _businessNameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Focus States
  bool _emailFocused = false;
  bool _otpFocused = false;
  bool _fullNameFocused = false;
  bool _businessNameFocused = false;
  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;
  bool _businessTypePickerOpen = false;
  bool _cityPickerOpen = false;

  // Validation Errors
  String? _emailError;
  String? _otpError;
  String? _fullNameError;
  String? _businessNameError;
  String? _businessTypeError;
  String? _cityError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Business Type
  final List<String> _businessTypes = [
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
  String? _selectedBusinessType;

  final List<String> _cities = [
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
  String? _selectedCity;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _logoSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    // Focus listeners
    _setupFocusListeners();

    // Error clearing listeners
    _emailController.addListener(_clearError);
    _otpController.addListener(_clearError);
    _fullNameController.addListener(_clearError);
    _businessNameController.addListener(_clearError);
    _businessTypeController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);

    _animationController.forward();
  }

  void _clearError() {
    ref.read(authNotifierProvider.notifier).clearError();
    _clearValidationErrors();
  }

  void _clearValidationErrors() {
    setState(() {
      _emailError = null;
      _fullNameError = null;
      _businessNameError = null;
      _businessTypeError = null;
      _cityError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  void _clearBusinessNameError() {
    if (_businessNameError != null) {
      setState(() => _businessNameError = null);
    }
  }

  void _clearFullNameError() {
    if (_fullNameError != null) {
      setState(() => _fullNameError = null);
    }
  }

  void _clearPasswordError() {
    if (_passwordError != null) {
      setState(() => _passwordError = null);
    }
  }

  void _clearConfirmPasswordError() {
    if (_confirmPasswordError != null) {
      setState(() => _confirmPasswordError = null);
    }
  }

  void _setupFocusListeners() {
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _otpFocusNode.addListener(() {
      setState(() => _otpFocused = _otpFocusNode.hasFocus);
    });
    _fullNameFocusNode.addListener(() {
      setState(() => _fullNameFocused = _fullNameFocusNode.hasFocus);
    });
    _businessNameFocusNode.addListener(() {
      setState(() => _businessNameFocused = _businessNameFocusNode.hasFocus);
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
    _fullNameController.removeListener(_clearError);
    _businessNameController.removeListener(_clearError);
    _businessTypeController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _confirmPasswordController.removeListener(_clearError);
    _emailController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _businessNameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
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

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(
          name: businessName,
          fullName: fullName,
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          type: _selectedBusinessType,
          city: _selectedCity!,
        );

    if (ok && mounted) {
      setState(() {
        _currentStep = 1;
        _registeredEmail = email;
        _canResendOtp = false;
        _resendTimer = 60;
      });
      _startResendTimer();
      ToastService.showSuccess('Verification code sent to your email!');
    }
  }

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

  Future<void> _verifyEmailOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _otpError = 'Verification code is required.');
      return;
    }
    if (otp.length != 6) {
      setState(() => _otpError = 'Verification code must be 6 digits.');
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .verifyEmail(email: _registeredEmail, otpCode: otp);
  }

  Future<void> _resendOtp() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final result = await notifier.resendVerification(_registeredEmail);
    if (result['alreadyVerified'] == true && mounted) {
      ToastService.showInfo(
        'This email is already verified. Please log in instead.',
      );
      // Navigate to login: clear the register stack
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      return;
    }
    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error && mounted) {
      ToastService.showSuccess('New verification code sent!');
      setState(() => _canResendOtp = false);
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
                    painter: const AppHeaderPatternPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + AppTokens.authTopBarInset,
              left: AppTokens.authTopBarInset,
              right: AppTokens.authTopBarInset,
              child: Row(
                children: [
                  AuthBackButton(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  _buildLanguageSwitcher(),
                ],
              ),
            ),
            Positioned(
              top: logoTop,
              left: 0,
              right: 0,
              child: Center(child: _buildAnimatedLogo()),
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

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoScaleAnimation, _logoSlideAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: _logoSlideAnimation.value,
          child: Transform.scale(
            scale: _logoScaleAnimation.value,
            child: Semantics(
              label: 'App logo',
              child: Container(
                width: AppTokens.logoTileSize,
                height: AppTokens.logoTileSize,
                decoration: BoxDecoration(
                  color: AppTokens.obsidian950,
                  borderRadius: BorderRadius.circular(AppTokens.logoTileRadius),
                ),
                child: Center(
                  child: SizedBox(
                    width: AppTokens.logoIconSize,
                    height: AppTokens.logoIconSize,
                    child: const CustomPaint(painter: AppLogoPainter()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(
                                  height: AppTokens.titleToggleGap,
                                ),
                                _buildTitle(),
                                const SizedBox(
                                  height: AppTokens.titleToggleGap,
                                ),
                                _buildCurrentStep(),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _buildRegistrationFormStep();
    }
    return _buildVerifyEmailStep();
  }

  Widget _buildRegistrationFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildFullNameField(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildBusinessNameField(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildBusinessTypeDropdown(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildCityDropdown(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildPasswordField(),
        const SizedBox(height: AppTokens.fieldGap),
        _buildConfirmPasswordField(),
      ],
    );
  }

  Widget _buildVerifyEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a 6-digit code to $_registeredEmail. Enter it below to verify your email.',
          textAlign: TextAlign.center,
          style: AppText.authSubtitle,
        ),
        const SizedBox(height: AppTokens.toggleFieldsGap),
        _buildOtpField(),
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

  Widget _buildOtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_otpError!, style: AppText.authError),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _currentStep == 0
              ? AppLocalizations.of(context)!.createAccount
              : 'Verify your email',
          textAlign: TextAlign.center,
          style: AppText.authTitle,
        ),
        if (_currentStep == 0) ...[
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            AppLocalizations.of(context)!.createNewAccount,
            textAlign: TextAlign.center,
            style: AppText.authSubtitle,
          ),
        ],
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_emailError!, style: AppText.authError),
          ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUniqueInput(
          controller: _fullNameController,
          focusNode: _fullNameFocusNode,
          isFocused: _fullNameFocused,
          label: AppLocalizations.of(context)!.fullName,
          hint: 'e.g. Abebe Bekele',
          icon: Icons.person_outline_rounded,
          hasError: _fullNameError != null,
          onChanged: (_) => _clearFullNameError(),
        ),
        if (_fullNameError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_fullNameError!, style: AppText.authError),
          ),
      ],
    );
  }

  Widget _buildBusinessNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUniqueInput(
          controller: _businessNameController,
          focusNode: _businessNameFocusNode,
          isFocused: _businessNameFocused,
          label: AppLocalizations.of(context)!.businessName,
          hint: 'My Awesome Business',
          icon: Icons.store_outlined,
          hasError: _businessNameError != null,
          onChanged: (_) => _clearBusinessNameError(),
        ),
        if (_businessNameError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_businessNameError!, style: AppText.authError),
          ),
      ],
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return _buildOptionDropdown(
      label: AppLocalizations.of(context)!.businessType,
      placeholder: 'Select business type',
      icon: Icons.category_outlined,
      value: _selectedBusinessType,
      error: _businessTypeError,
      onTap: _openBusinessTypePicker,
    );
  }

  Widget _buildCityDropdown() {
    return _buildOptionDropdown(
      label: AppLocalizations.of(context)!.city,
      placeholder: 'Select city',
      icon: Icons.location_on_outlined,
      value: _selectedCity,
      error: _cityError,
      onTap: _openCityPicker,
    );
  }

  Widget _buildOptionDropdown({
    required String label,
    required String placeholder,
    required IconData icon,
    required String? value,
    required String? error,
    required VoidCallback onTap,
  }) {
    return AuthDropdownField(
      label: label,
      value: value,
      placeholder: placeholder,
      icon: icon,
      error: error,
      onTap: onTap,
    );
  }

  Future<void> _openBusinessTypePicker() async {
    if (_businessTypePickerOpen) return;
    setState(() => _businessTypePickerOpen = true);

    final selected = await _showOptionPicker(
      title: AppLocalizations.of(context)!.businessType,
      options: _businessTypes,
      selected: _selectedBusinessType,
    );
    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _selectedBusinessType = selected;
        _businessTypeError = null;
        _businessTypePickerOpen = false;
      });
      _clearError();
      return;
    }

    setState(() => _businessTypePickerOpen = false);
  }

  Future<void> _openCityPicker() async {
    if (_cityPickerOpen) return;
    setState(() => _cityPickerOpen = true);

    final selected = await _showOptionPicker(
      title: AppLocalizations.of(context)!.city,
      options: _cities,
      selected: _selectedCity,
    );
    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _selectedCity = selected;
        _cityError = null;
        _cityPickerOpen = false;
      });
      _clearError();
      return;
    }

    setState(() => _cityPickerOpen = false);
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUniqueInput(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          isFocused: _passwordFocused,
          label: AppLocalizations.of(context)!.password,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: PasswordVisibilityButton(
            obscure: _obscurePassword,
            onTap: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          hasError: _passwordError != null,
          onChanged: (_) => _clearPasswordError(),
        ),
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_passwordError!, style: AppText.authError),
          ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUniqueInput(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          isFocused: _confirmPasswordFocused,
          label: AppLocalizations.of(context)!.confirmPassword,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPassword,
          suffixIcon: PasswordVisibilityButton(
            obscure: _obscureConfirmPassword,
            onTap: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          hasError: _confirmPasswordError != null,
          onChanged: (_) => _clearConfirmPasswordError(),
        ),
        if (_confirmPasswordError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
            child: Text(_confirmPasswordError!, style: AppText.authError),
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
    ValueChanged<String>? onChanged,
  }) {
    return AuthFieldShell(
      label: label,
      focused: isFocused,
      hasError: hasError,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppTokens.eyeIconSize,
            color: hasError
                ? AppTokens.danger
                : isFocused
                ? AppTokens.ink
                : AppTokens.inkMuted,
          ),
          const SizedBox(width: AppTokens.dropdownIconGap),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: AppTokens.obsidian950,
              enabled: enabled,
              obscureText: obscureText,
              autocorrect: !obscureText,
              enableSuggestions: !obscureText,
              keyboardType: keyboardType,
              maxLength: maxLength,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: AppText.authInput.copyWith(
                color: enabled ? AppTokens.ink : AppTokens.inkMuted,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.authHint.copyWith(
                  color: AppTokens.hintInkMuted,
                ),
                filled: false,
                fillColor: AppTokens.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          ?suffixIcon,
        ],
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

    if (_currentStep == 0) {
      return _buildNextButton(
        onPressed: _submitRegistration,
        text: AppLocalizations.of(context)!.registerNow,
      );
    }
    return _buildNextButton(
      onPressed: _verifyEmailOtp,
      text: AppLocalizations.of(context)!.verifyContinue,
    );
  }

  Widget _buildErrorState(AuthState authState) {
    void clearError() {
      ref.read(authNotifierProvider.notifier).clearError();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _buildNextButton(onPressed: clearError, text: 'Try Again'),
      ],
    );
  }

  Widget _buildNextButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return AuthPrimaryButton(
      label: text,
      loadingLabel: text,
      isLoading: false,
      onPressed: onPressed,
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
