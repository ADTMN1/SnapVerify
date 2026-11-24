import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../core/language_provider.dart';
import '../../core/utils/toast_service.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/sv_loader.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  static const double _screenPadding = 20;
  static const double _blockGap = 24;
  static const double _sectionGap = 20;
  static const double _fieldGap = 12;
  static const double _inputRadius = 10;
  static const double _smallIconSize = 16;
  static const double _mediumIconSize = 18;
  static const double _smallTextSize = 11;
  static const double _bodyTextSize = 13;
  static const double _buttonTextSize = 14;
  static const double _titleSize = 24;
  static const double _sectionTitleSize = 18;

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
      ToastService.showError(
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _screenPadding,
              vertical: _screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Language Switcher
                _buildHeader(size),

                const SizedBox(height: _blockGap),

                // Animated Logo
                _buildAnimatedLogo(),

                const SizedBox(height: _sectionGap),

                // Current Step Content
                _buildCurrentStep(),

                const SizedBox(height: _sectionGap),

                // Navigation
                _buildNavigationButtons(authState),

                const SizedBox(height: _sectionGap),

                // Login Link
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TwColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TwColors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: TwColors.white,
              size: _mediumIconSize,
            ),
          ),
        ),
        _buildLanguageSwitcher(),
      ],
    );
  }

  Widget _buildLanguageSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TwColors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: AppLanguage.values.map((lang) {
          final isSelected = lang == ref.watch(languageProvider);
          return GestureDetector(
            onTap: () => ref.read(languageProvider.notifier).select(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: EdgeInsets.only(
                right: lang == AppLanguage.values.last ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? TwColors.brightGreen.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(
                        color: TwColors.brightGreen.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              child: Text(
                lang.shortName,
                style: TextStyle(
                  color: isSelected ? TwColors.brightGreen : TwColors.slate400,
                  fontSize: _bodyTextSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TwColors.brightGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: TwColors.brightGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 44,
                  color: TwColors.brightGreen,
                ),
              ),
            ),
          ),
        );
      },
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        const SizedBox(height: _sectionGap),
        _buildEmailField(),
        const SizedBox(height: _fieldGap),
        _buildFullNameField(),
        const SizedBox(height: _fieldGap),
        _buildBusinessNameField(),
        const SizedBox(height: _fieldGap),
        _buildBusinessTypeDropdown(),
        const SizedBox(height: _fieldGap),
        _buildCityDropdown(),
        const SizedBox(height: _fieldGap),
        _buildPasswordField(),
        const SizedBox(height: _fieldGap),
        _buildConfirmPasswordField(),
      ],
    );
  }

  Widget _buildVerifyEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        const SizedBox(height: _fieldGap),
        Text(
          'We sent a 6-digit code to $_registeredEmail. Enter it below to verify your email.',
          style: TextStyle(
            color: TwColors.slate400,
            fontSize: _bodyTextSize,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: _sectionGap),
        _buildOtpField(),
        const SizedBox(height: _fieldGap),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _canResendOtp ? _resendOtp : null,
            child: Text(
              _canResendOtp ? 'Resend code' : 'Resend code ($_resendTimer)',
              style: TextStyle(
                color: _canResendOtp ? TwColors.brightGreen : TwColors.slate400,
                fontSize: _bodyTextSize,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
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
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _otpError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.createAccount,
          style: const TextStyle(
            color: TwColors.white,
            fontSize: _titleSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _currentStep == 0
              ? AppLocalizations.of(context)!.createNewAccount
              : 'Verify your email',
          style: TextStyle(
            color: TwColors.slate400,
            fontSize: _bodyTextSize,
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
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _emailError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUniqueInput(
          controller: _fullNameController,
          focusNode: _fullNameFocusNode,
          isFocused: _fullNameFocused,
          label: AppLocalizations.of(context)!.fullName,
          hint: 'John Doe',
          icon: Icons.person_outline_rounded,
          hasError: _fullNameError != null,
          onChanged: (_) => _clearFullNameError(),
        ),
        if (_fullNameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _fullNameError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBusinessNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _businessNameError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      isOpen: _businessTypePickerOpen,
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
      isOpen: _cityPickerOpen,
      onTap: _openCityPicker,
    );
  }

  Widget _buildOptionDropdown({
    required String label,
    required String placeholder,
    required IconData icon,
    required String? value,
    required String? error,
    required bool isOpen,
    required VoidCallback onTap,
  }) {
    final hasError = error != null;
    final hasValue = value != null;
    final borderColor = hasError
        ? TwColors.red500
        : isOpen
        ? TwColors.brightGreen
        : TwColors.white.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: TwColors.cardBg,
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_inputRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: TwColors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: hasValue
                            ? TwColors.brightGreen
                            : TwColors.slate400,
                        size: _smallIconSize,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: hasValue
                                  ? TwColors.brightGreen
                                  : TwColors.slate400,
                              fontSize: _smallTextSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasValue ? value : placeholder,
                            style: TextStyle(
                              color: hasValue
                                  ? TwColors.white
                                  : TwColors.white.withValues(alpha: 0.35),
                              fontSize: _bodyTextSize,
                              fontWeight: hasValue
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: TwColors.slate400,
                      size: _mediumIconSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              error,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openBusinessTypePicker() async {
    if (_businessTypePickerOpen) return;
    setState(() => _businessTypePickerOpen = true);

    final selected = await _showOptionPicker(
      title: AppLocalizations.of(context)!.businessType,
      subtitle: 'Choose the category that best fits your business.',
      icon: Icons.storefront_outlined,
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
      subtitle: 'Choose the city where your business operates.',
      icon: Icons.location_on_outlined,
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
    required String subtitle,
    required IconData icon,
    required List<String> options,
    required String? selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TwColors.primaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TwColors.slate700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: TwColors.white,
                          fontSize: _sectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: TwColors.slate400,
                          fontSize: _bodyTextSize,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: _mediumIconSize,
                      color: TwColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: TwColors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: TwColors.white.withValues(alpha: 0.04),
                ),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return InkWell(
                    onTap: () => Navigator.of(sheetContext).pop(option),
                    borderRadius: BorderRadius.circular(_inputRadius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TwColors.brightGreen.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(_inputRadius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: TwColors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? TwColors.brightGreen
                                  : TwColors.slate400,
                              size: _smallIconSize,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? TwColors.brightGreen
                                    : TwColors.white,
                                fontSize: _bodyTextSize,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? TwColors.brightGreen
                                    : TwColors.slate500,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: TwColors.brightGreen,
                                    size: 12,
                                  )
                                : null,
                          ),
                        ],
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
              size: _smallIconSize,
            ),
            onPressed: () {
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
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _passwordError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
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
              size: _smallIconSize,
            ),
            onPressed: () {
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
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _confirmPasswordError!,
              style: TextStyle(
                color: TwColors.red500,
                fontSize: _smallTextSize,
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
    ValueChanged<String>? onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(_inputRadius),
        border: Border.all(
          color: hasError
              ? TwColors.red500
              : isFocused
              ? TwColors.brightGreen
              : TwColors.white.withValues(alpha: 0.08),
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: hasError
                      ? TwColors.red500.withValues(alpha: 0.1)
                      : TwColors.brightGreen.withValues(alpha: 0.1),
                  blurRadius: 8,
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
        autocorrect: !obscureText,
        enableSuggestions: !obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        style: const TextStyle(
          color: TwColors.white,
          fontSize: _bodyTextSize,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4, right: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isFocused
                  ? TwColors.brightGreen.withValues(alpha: 0.1)
                  : TwColors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              size: _smallIconSize,
            ),
          ),
          suffixIcon: suffixIcon,
          label: Text(
            label,
            style: TextStyle(
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              fontSize: _smallTextSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: TwColors.white.withValues(alpha: 0.3),
            fontSize: _bodyTextSize,
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TwColors.red500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: TwColors.red500.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TwColors.red500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: TwColors.red500,
                  size: _mediumIconSize,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.error,
                      style: TextStyle(
                        color: TwColors.red500,
                        fontSize: _bodyTextSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authState.errorMessage ??
                          AppLocalizations.of(context)!.anErrorOccurred,
                      style: TextStyle(
                        color: TwColors.red500.withValues(alpha: 0.8),
                        fontSize: _bodyTextSize,
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
                          fontSize: _bodyTextSize,
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
        const SizedBox(height: _fieldGap),
        _buildNextButton(
          onPressed: () {
            // Clear error state
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 44),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: _buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
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
            fontSize: _bodyTextSize,
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
              fontSize: _bodyTextSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
