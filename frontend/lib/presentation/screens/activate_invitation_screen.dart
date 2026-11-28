import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/toast_service.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/sv_app_shell.dart';
import '../widgets/sv_loader.dart';

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
    final match = RegExp(r'token=([A-Za-z0-9]+)').firstMatch(rawToken);
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
        _error = e.toString().replaceFirst(
          RegExp(r'^[A-Za-z]+\(?\d*\)?:\s*'),
          '',
        );
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
          _error = e.toString().replaceFirst(
            RegExp(r'^[A-Za-z]+\(?\d*\)?:\s*'),
            '',
          );
          _activating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvAppShell(
      title: 'Activate Account',
      subtitle: _stepSubtitle,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: _buildBody(),
    );
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0:
        return 'Scan invitation code';
      case 1:
        return 'Review invitation details';
      default:
        return 'Set your password';
    }
  }

  Widget _buildBody() {
    if (_checking) {
      return Center(child: SvLoader.page(color: AppTokens.inkMuted));
    }
    if (_step == 0) return _buildScanStep();
    if (_step == 1) return _buildDetailsStep();
    return _buildPasswordStep();
  }

  Widget _buildScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Center(
                child: Container(
                  width: AppTokens.statTileSize * 5,
                  height: AppTokens.statTileSize * 5,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTokens.cameraActionBackground,
                      width: AppTokens.componentBorderWidthStrong * 2,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radius2xl),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTokens.space2xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvSurfaceCard(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Text(
                  'Scan the QR code your manager showed you',
                  style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTokens.spaceMd),
                SvSurfaceCard(
                  color: AppTokens.dangerBg,
                  borderColor: AppTokens.danger,
                  padding: const EdgeInsets.all(AppTokens.errorPadding),
                  child: Text(
                    _error!,
                    style: AppText.bodySmall.copyWith(color: AppTokens.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _roleLabel(String? role) {
    if (role == null || role.isEmpty) return 'Staff';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  Widget _buildDetailsStep() {
    final inv = _invitation!;
    final org = inv['organization'] as Map<String, dynamic>?;
    final branch = inv['branch'] as Map<String, dynamic>?;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space2xl,
        AppTokens.spaceLg,
        AppTokens.space2xl,
        AppTokens.space3xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: AppTokens.statTileSize * 2,
              height: AppTokens.statTileSize * 2,
              decoration: const BoxDecoration(
                color: AppTokens.ice100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: AppTokens.ink,
                size: AppTokens.statTileSize,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            'You have been invited to join ${org?['name'] ?? 'the business'}',
            style: AppText.titleMedium.copyWith(color: AppTokens.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.space2xl),
          _detailCard('Staff Details', [
            ('Name', inv['fullName'] ?? '—'),
            ('Username', inv['username'] ?? '—'),
            ('Role', _roleLabel(inv['role']?.toString())),
            if (branch != null) ('Branch', branch['name'] ?? '—'),
            ('Business', org?['name'] ?? '—'),
          ]),
          const SizedBox(height: AppTokens.spaceXl),
          SvActionButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            tone: SvTone.neutral,
            onPressed: () => setState(() => _step = 2),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          TextButton(
            onPressed: () => setState(() {
              _step = 0;
              _invitation = null;
              _token = null;
              _error = null;
            }),
            child: Text(
              'Scan a different code',
              style: AppText.labelLarge.copyWith(color: AppTokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space2xl,
        AppTokens.spaceLg,
        AppTokens.space2xl,
        AppTokens.space3xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppTokens.statTileSize * 2,
                height: AppTokens.statTileSize * 2,
                decoration: const BoxDecoration(
                  color: AppTokens.ice100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppTokens.ink,
                  size: AppTokens.statTileSize,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            Text(
              'Create your password',
              style: AppText.titleMedium.copyWith(color: AppTokens.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'Use it with your username to log in.',
              style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space2xl),
            SvFormField(
              controller: _passwordCtrl,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: _EyeToggle(
                show: _obscurePassword,
                onTap: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required.';
                if (v.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceLg),
            SvFormField(
              controller: _confirmCtrl,
              label: 'Confirm password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirm,
              suffixIcon: _EyeToggle(
                show: _obscureConfirm,
                onTap: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (v != _passwordCtrl.text) return 'Passwords do not match.';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTokens.spaceLg),
              SvSurfaceCard(
                color: AppTokens.dangerBg,
                borderColor: AppTokens.danger,
                padding: const EdgeInsets.all(AppTokens.errorPadding),
                child: Text(
                  _error!,
                  style: AppText.bodySmall.copyWith(color: AppTokens.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.space2xl),
            SvActionButton(
              label: 'Activate Account',
              onPressed: _activate,
              loading: _activating,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, List<(String, String)> rows) {
    return SvSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvSectionLabel(title),
          const SizedBox(height: AppTokens.spaceMd),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
              child: SvInfoRow(
                icon: _detailIcon(row.$1),
                label: row.$1,
                value: row.$2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _detailIcon(String label) {
    switch (label) {
      case 'Name':
        return Icons.person_outline_rounded;
      case 'Username':
        return Icons.alternate_email_rounded;
      case 'Role':
        return Icons.badge_outlined;
      case 'Branch':
        return Icons.location_city_outlined;
      case 'Business':
        return Icons.storefront_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

class _EyeToggle extends StatelessWidget {
  final bool show;
  final VoidCallback onTap;

  const _EyeToggle({required this.show, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: AppTokens.spaceLg),
        child: Icon(
          show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppTokens.inkMuted,
          size: AppTokens.componentIconMd,
        ),
      ),
    );
  }
}
