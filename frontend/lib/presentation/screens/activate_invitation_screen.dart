import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/tailwind.dart';
import '../../../core/utils/toast_service.dart';
import '../providers/auth_provider.dart';

/// Staff activation — QR invitation flow.
///
/// Step 0: scan the invitation QR (or paste the token manually).
/// Step 1: review the assigned staff details (name, role, branch, business).
/// Step 2: create + confirm a password to activate the account.
/// Done: staff logs in with their username and password.
class ActivateInvitationScreen extends ConsumerStatefulWidget {
  final String? initialToken;
  const ActivateInvitationScreen({super.key, this.initialToken});

  @override
  ConsumerState<ActivateInvitationScreen> createState() =>
      _ActivateInvitationScreenState();
}

class _ActivateInvitationScreenState
    extends ConsumerState<ActivateInvitationScreen> {
  int _step = 0;

  String? _token;
  Map<String, dynamic>? _invitation;
  bool _checking = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _step = 1;
      _checkToken(widget.initialToken!);
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
      super.dispose();
  }

  Future<void> _checkToken(String rawToken) async {
    // Accept both the raw token and the full deep link from the QR.
    final match =
        RegExp(r'token=([A-Za-z0-9]+)').firstMatch(rawToken);
    final token = match?.group(1) ?? rawToken.trim();

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final results = await repo.checkInvitation(token);
      if (results.isEmpty) {
        setState(() {
          _error = 'This invitation is not valid anymore.';
          _checking = false;
        });
        return;
      }
      final inv = results.first as Map<String, dynamic>;
      if (inv['status'] != null && inv['status'] != 'PENDING') {
        setState(() {
          _error = _statusMessage(inv['status'].toString());
          _checking = false;
        });
        return;
      }
      setState(() {
        _token = token;
        _invitation = inv;
        _step = 1;
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+\(?\d*\)?:\s*'), '');
        _checking = false;
      });
    }
  }

  String _statusMessage(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVATED':
        return 'This invitation was already activated. Please log in instead.';
      case 'REVOKED':
        return 'This invitation was revoked. Ask your manager for a new one.';
      case 'EXPIRED':
        return 'This invitation expired. Ask your manager to show you a new QR code.';
      default:
        return 'This invitation is not valid anymore.';
    }
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _activating = true);
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      final result = await notifier.activateInvitation(
        token: _token!,
        password: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
      );
      if (!mounted) return;
      if (result['message'] == '') {
        // Error state — message already surfaced via auth state listener.
        setState(() => _activating = false);
        return;
      }
      final username = result['username'] ?? '';
      Navigator.of(context).popUntil((route) => route.isFirst);
      ToastService.showSuccess(
        username.isEmpty
            ? 'Account activated! You can now log in.'
            : 'Account activated! Log in with username "$username".',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+\(?\d*\)?:\s*'), '');
          _activating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      appBar: AppBar(
        backgroundColor: TwColors.primaryBg,
        foregroundColor: TwColors.white,
        elevation: 0,
        title: const Text('Activate Account'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checking) {
      return const Center(child: CircularProgressIndicator(color: TwColors.brightGreen));
    }
    if (_step == 0) return _buildScanStep();
    if (_step == 1) return _buildDetailsStep();
    return _buildPasswordStep();
  }

  // ── Step 0: scan QR ───────────────────────────────────────────────────────

  Widget _buildScanStep() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (_checking) return;
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null && code.isNotEmpty) {
                    _checkToken(code);
                  }
                },
              ),
              // Scan window overlay hint
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: TwColors.brightGreen, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Scan the QR code your manager showed you',
                style: TextStyle(
                  color: TwColors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: TwColors.red500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1: confirm staff details ─────────────────────────────────────────

  String _roleLabel(String? role) {
    if (role == null || role.isEmpty) return 'Staff';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  Widget _buildDetailsStep() {
    final inv = _invitation!;
    final org = inv['organization'] as Map<String, dynamic>?;
    final branch = inv['branch'] as Map<String, dynamic>?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.badge_outlined, color: TwColors.brightGreen, size: 56),
          const SizedBox(height: 16),
          Text(
            'You have been invited to join ${org?['name'] ?? 'the business'}',
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _detailCard('Staff Details', [
            ('Name', inv['fullName'] ?? '—'),
            ('Username', inv['username'] ?? '—'),
            ('Role', _roleLabel(inv['role']?.toString())),
            if (branch != null) ('Branch', branch['name'] ?? '—'),
            ('Business', org?['name'] ?? '—'),
          ]),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Continue',
            onPressed: () => setState(() => _step = 2),
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'Scan a different code',
            onPressed: () => setState(() {
              _step = 0;
              _invitation = null;
              _token = null;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }

  // ── Step 2: create password ───────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline_rounded, color: TwColors.brightGreen, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Create your password',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Use it with your username to log in.',
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _passwordField(_passwordCtrl, 'Password', _obscurePassword, () {
              setState(() => _obscurePassword = !_obscurePassword);
            }, (v) {
              if (v == null || v.isEmpty) return 'Password is required.';
              if (v.length < 8) return 'Password must be at least 8 characters.';
              return null;
            }),
            const SizedBox(height: 16),
            _passwordField(_confirmCtrl, 'Confirm password', _obscureConfirm, () {
              setState(() => _obscureConfirm = !_obscureConfirm);
            }, (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password.';
              if (v != _passwordCtrl.text) return 'Passwords do not match.';
              return null;
            }),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: TwColors.red500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Activate Account',
              loading: _activating,
              onPressed: _activate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, List<(String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: TwColors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          color: TwColors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          color: TwColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback toggle,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: TwColors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: TwColors.white.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwColors.slate700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwColors.slate700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwColors.brightGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwColors.red500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwColors.red500, width: 1.5),
        ),
        errorStyle: const TextStyle(color: TwColors.red500, fontSize: 11),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: TwColors.white.withValues(alpha: 0.5),
            size: 20,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: TwColors.brightGreen,
        foregroundColor: TwColors.primaryBg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: TwColors.primaryBg,
                strokeWidth: 2,
              ),
            )
          : Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: TwColors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }
}
