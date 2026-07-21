import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../core/locales.dart';
import '../../core/utils/toast_service.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ActivateInvitationScreen extends ConsumerStatefulWidget {
  const ActivateInvitationScreen({super.key});

  @override
  ConsumerState<ActivateInvitationScreen> createState() =>
      _ActivateInvitationScreenState();
}

class _ActivateInvitationScreenState
    extends ConsumerState<ActivateInvitationScreen>
    with SingleTickerProviderStateMixin {
  // State
  Language _selectedLanguage = Language.english;
  int _currentStep = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _otpSent = false;
  bool _canResendOtp = true;
  int _resendTimer = 60;
  List<dynamic> _invitations = [];
  dynamic _selectedInvitation;

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  final _fullNameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Focus States
  bool _phoneFocused = false;
  bool _otpFocused = false;
  bool _fullNameFocused = false;
  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _phoneController.addListener(_clearError);
    _otpController.addListener(_clearError);
    _fullNameController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
  }

  void _clearError() {
    ref.read(authNotifierProvider.notifier).clearError();
  }

  void _setupFocusListeners() {
    _phoneFocusNode.addListener(() {
      setState(() => _phoneFocused = _phoneFocusNode.hasFocus);
    });
    _otpFocusNode.addListener(() {
      setState(() => _otpFocused = _otpFocusNode.hasFocus);
    });
    _fullNameFocusNode.addListener(() {
      setState(() => _fullNameFocused = _fullNameFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
    _confirmPasswordFocusNode.addListener(() {
      setState(() => _confirmPasswordFocused = _confirmPasswordFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_clearError);
    _otpController.removeListener(_clearError);
    _fullNameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _confirmPasswordController.removeListener(_clearError);
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String _t(String key) {
    return LocaleStrings.strings[_selectedLanguage]?[key] ?? key;
  }

  void _toggleLanguage(Language lang) {
    setState(() => _selectedLanguage = lang);
  }

  Future<void> _checkInvitations() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    
    try {
      final invitations = await ref
          .read(authRemoteDatasourceProvider)
          .getInvitations(phone);
      
      setState(() {
        _invitations = invitations;
        _currentStep = 1;
      });
    } catch (e) {
      ToastService.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    
    await ref.read(authNotifierProvider.notifier).sendOtp(phone);
    
    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.error) {
      setState(() => _otpSent = true);
      _startResendTimer();
      ToastService.showSuccess('OTP sent successfully!');
    }
  }

  Future<void> _startResendTimer() async {
    setState(() {
      _canResendOtp = false;
      _resendTimer = 60;
    });
    
    for (int i = 59; i >= 0; i--) {
      if (!mounted) return;
      setState(() => _resendTimer = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) {
      setState(() => _canResendOtp = true);
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      await _checkInvitations();
    } else if (_currentStep == 1) {
      if (_selectedInvitation == null) {
        ToastService.showError('Please select an invitation');
        return;
      }
      if (!_otpSent) {
        await _sendOtp();
      } else {
        final otp = _otpController.text.trim();
        if (otp.isEmpty) return;
        setState(() => _currentStep = 2);
      }
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        ToastService.showError('Passwords do not match!');
        return;
      }
      
      final phone = _phoneController.text.trim();
      final otp = _otpController.text.trim();
      final fullName = _fullNameController.text.trim();
      final password = _passwordController.text.trim();
      final organizationId = _selectedInvitation['organizationId'];
      
      await ref.read(authNotifierProvider.notifier).activateInvitation(
        phone: phone,
        otpCode: otp,
        fullName: fullName,
        password: password,
        organizationId: organizationId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(size),
              const SizedBox(height: 24),
              _buildStepsIndicator(),
              const SizedBox(height: 28),
              _buildCurrentStep(),
              const SizedBox(height: 32),
              _buildNavigationButtons(authState),
              const SizedBox(height: 32),
              _buildLoginLink(),
            ],
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
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.white.withOpacity(0.08)),
      ),
      child: Row(
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

  Widget _buildStepsIndicator() {
    return Row(
      children: [
        Expanded(
          child: _buildStepIndicator(
            index: 0,
            title: 'Phone',
          ),
        ),
        Container(
          width: 40,
          height: 2,
          color: _currentStep > 0
              ? TwColors.brightGreen
              : TwColors.white.withOpacity(0.1),
        ),
        Expanded(
          child: _buildStepIndicator(
            index: 1,
            title: 'Select Invitation',
          ),
        ),
        Container(
          width: 40,
          height: 2,
          color: _currentStep > 1
              ? TwColors.brightGreen
              : TwColors.white.withOpacity(0.1),
        ),
        Expanded(
          child: _buildStepIndicator(
            index: 2,
            title: 'Set Password',
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator({
    required int index,
    required String title,
  }) {
    final isActive = _currentStep >= index;
    final isCompleted = _currentStep > index;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? TwColors.brightGreen.withOpacity(0.15)
                : TwColors.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive
                  ? TwColors.brightGreen.withOpacity(0.5)
                  : TwColors.white.withOpacity(0.08),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    Icons.check_rounded,
                    color: TwColors.brightGreen,
                    size: 22,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? TwColors.brightGreen : TwColors.slate400,
                      fontSize: 18,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isActive ? TwColors.brightGreen : TwColors.slate400,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _buildPhoneStep();
    } else if (_currentStep == 1) {
      return _buildSelectInvitationStep();
    } else {
      return _buildActivateStep();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('Activate Invitation', 'Enter your phone number to check for invitations'),
        const SizedBox(height: 28),
        _buildPhoneNumberField(),
      ],
    );
  }

  Widget _buildSelectInvitationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('Select Invitation', 'Choose which invitation to activate'),
        const SizedBox(height: 28),
        ..._invitations.map((invitation) {
          final isSelected = invitation == _selectedInvitation;
          final organization = invitation['organization'];
          final branch = invitation['branch'];
          final role = invitation['role'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedInvitation = invitation);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? TwColors.brightGreen.withOpacity(0.1)
                    : TwColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? TwColors.brightGreen.withOpacity(0.4)
                      : TwColors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization['name'],
                    style: TextStyle(
                      color: isSelected ? TwColors.brightGreen : TwColors.white,
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.toString().toLowerCase().capitalize(),
                    style: const TextStyle(
                      color: TwColors.slate400,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  if (branch != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        branch['name'],
                        style: const TextStyle(
                          color: TwColors.slate500,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActivateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('Set Password', 'Enter your details to activate your account'),
        const SizedBox(height: 28),
        _buildFullNameField(),
        const SizedBox(height: 20),
        _buildOtpField(),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _canResendOtp ? _sendOtp : null,
            child: Text(
              _canResendOtp ? _t('resend_otp') : '${_t('resend_otp')} ($_resendTimer)',
              style: TextStyle(
                color: _canResendOtp ? TwColors.brightGreen : TwColors.slate400,
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

  Widget _buildPhoneNumberField() {
    return _buildUniqueInput(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      isFocused: _phoneFocused,
      label: _t('phone_number'),
      hint: '+251 9XX XXX XXX',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildOtpField() {
    return _buildUniqueInput(
      controller: _otpController,
      focusNode: _otpFocusNode,
      isFocused: _otpFocused,
      label: _t('otp_code'),
      hint: '123456',
      icon: Icons.pin_outlined,
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildFullNameField() {
    return _buildUniqueInput(
      controller: _fullNameController,
      focusNode: _fullNameFocusNode,
      isFocused: _fullNameFocused,
      label: _t('full_name'),
      hint: 'John Doe',
      icon: Icons.person_outline_rounded,
    );
  }

  Widget _buildPasswordField() {
    return _buildUniqueInput(
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
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildUniqueInput(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocusNode,
      isFocused: _confirmPasswordFocused,
      label: _t('confirm_password'),
      hint: '••••••••',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscureConfirmPassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureConfirmPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _confirmPasswordFocused ? TwColors.brightGreen : TwColors.slate400,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          });
        },
      ),
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
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? TwColors.brightGreen : TwColors.white.withOpacity(0.08),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: TwColors.brightGreen.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
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
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isFocused
                  ? TwColors.brightGreen.withOpacity(0.1)
                  : TwColors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              size: 20,
            ),
          ),
          suffixIcon: suffixIcon,
          label: Text(
            label,
            style: TextStyle(
              color: isFocused ? TwColors.brightGreen : TwColors.slate400,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: TwColors.white.withOpacity(0.3),
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(AuthState authState) {
    if (authState.status == AuthStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: TwColors.brightGreen,
          strokeWidth: 3,
        ),
      );
    }

    if (authState.status == AuthStatus.error) {
      return _buildErrorState(authState);
    }

    String buttonText;
    if (_currentStep == 0) {
      buttonText = 'Check Invitations';
    } else if (_currentStep == 1) {
      buttonText = _otpSent ? _t('verify_continue') : _t('send_otp');
    } else {
      buttonText = 'Activate Account';
    }

    return _buildNextButton(
      onPressed: _nextStep,
      text: buttonText,
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
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
          _t('already_have_account'),
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
            _t('login_now'),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1).toLowerCase();
  }
}
