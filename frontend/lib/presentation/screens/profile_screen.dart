import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/toast_service.dart';
import '../../domain/entities/report_summary.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/sv_app_shell.dart';
import 'business_switcher_screen.dart';
import 'language_settings_screen.dart';
import 'notifications_screen.dart';
import 'subscription_sheet.dart';

Future<void> _openTelegram(BuildContext context) async {
  const url = 'https://t.me/snapverify';
  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ToastService.showError('Could not open Telegram.');
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final organization = authState.organization;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todaySummary = ref.watch(
      reportSummaryProvider((from: today, to: today)),
    );

    final fullName = user?.fullName ?? 'User';
    final role = authState.role.label;
    final phoneNumber = user?.phone ?? '';
    final businessName = organization?.name ?? '';

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: Column(
        children: [
          SvDashboardHeader(
            title: 'Profile',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.sheetHorizontalPadding,
                      AppTokens.spaceLg,
                      AppTokens.sheetHorizontalPadding,
                      AppTokens.sheetBottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAvatar(fullName, role),
                        const SizedBox(height: AppTokens.space2xl),
                        _buildInfoCard(phoneNumber, businessName),
                        const SizedBox(height: AppTokens.spaceLg),
                        _buildSubscriptionCard(context, ref, authState),
                        const SizedBox(height: AppTokens.spaceLg),
                        _buildStatsCard(todaySummary),
                        const SizedBox(height: AppTokens.spaceLg),
                        _buildMenuSection(context, ref),
                        const SizedBox(height: AppTokens.space3xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String fullName, String role) {
    final initials = fullName
        .trim()
        .split(' ')
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
    return Column(
      children: [
        Container(
          width: AppTokens.statTileSize * 2,
          height: AppTokens.statTileSize * 2,
          decoration: BoxDecoration(
            color: AppTokens.obsidian900,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTokens.ice200,
              width: AppTokens.componentBorderWidthStrong,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: AppTokens.poppins(
                size: AppTokens.textHeadline,
                weight: FontWeight.w800,
                color: AppTokens.white,
                letterSpacing: AppTokens.trackingTight,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceLg),
        Text(
          fullName,
          style: AppTokens.poppins(
            size: AppTokens.textHeadline,
            weight: FontWeight.w800,
            color: AppTokens.ink,
            letterSpacing: AppTokens.trackingTight,
          ),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        SvStatusPill(role, tone: SvTone.neutral),
      ],
    );
  }

  Widget _buildInfoCard(String phone, String businessName) {
    return SvSurfaceCard(
      color: AppTokens.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SvSectionLabel('Account Info'),
          const SizedBox(height: AppTokens.spaceLg),
          SvInfoRow(icon: Icons.phone_rounded, label: 'Phone', value: phone),
          const _Divider(),
          SvInfoRow(
            icon: Icons.storefront_rounded,
            label: 'Business',
            value: businessName,
          ),
          const _Divider(),
          const SvInfoRow(icon: Icons.circle, label: 'Status', value: 'Active'),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
  ) {
    final subscription = authState.subscription;
    final isOwner = authState.role == UserRole.owner;
    final healthy =
        subscription != null &&
        subscription.isActive &&
        !subscription.isQuotaExceeded;
    final statusText = subscription == null
        ? 'No plan selected'
        : healthy
        ? subscription.statusLabel
        : subscription.isQuotaExceeded
        ? 'Limit reached'
        : subscription.statusLabel;

    return SvSurfaceCard(
      color: AppTokens.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SvSectionLabel('Subscription'),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppTokens.inkMuted,
                size: AppTokens.componentIconMd,
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Text(
                  subscription?.planLabel ?? 'No plan',
                  style: AppText.titleSmall.copyWith(color: AppTokens.ink),
                ),
              ),
              SvStatusPill(statusText, tone: SvTone.neutral, small: true),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            subscription?.verificationSummary ??
                'Choose a plan to start verifying payments.',
            style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          SvActionButton(
            label: subscription == null ? 'Choose Plan' : 'Change Plan',
            icon: Icons.swap_horiz_rounded,
            tone: SvTone.neutral,
            onPressed: isOwner
                ? () => _openChangePlanSheet(context, ref)
                : null,
          ),
          if (!isOwner) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'Only the owner can change plans.',
              style: AppText.caption.copyWith(color: AppTokens.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openChangePlanSheet(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      useRootNavigator: true,
      builder: (_) => ProviderScope(
        parent: container,
        child: const SubscriptionSheet(startOnPlanList: true),
      ),
    );
    if (!context.mounted) return;
    await ref.read(authNotifierProvider.notifier).refreshSubscription();
  }

  Widget _buildStatsCard(AsyncValue<ReportSummary> todaySummary) {
    final summary = todaySummary.valueOrNull?.summary;
    final verifications = summary == null
        ? (todaySummary.isLoading ? '...' : '—')
        : '${summary.verified}';
    final amount = summary == null
        ? (todaySummary.isLoading ? '...' : '—')
        : '${summary.currency} ${summary.verifiedAmount.toStringAsFixed(2)}';
    final accuracy = (summary == null || summary.total == 0)
        ? (todaySummary.isLoading ? '...' : '—')
        : '${(summary.verified / summary.total * 100).toStringAsFixed(0)}%';

    return SvSurfaceCard(
      color: AppTokens.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SvSectionLabel("Today's Performance"),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            children: [
              _StatTile(
                label: 'Verifications',
                value: verifications,
                color: AppTokens.ink,
              ),
              _StatTile(label: 'Amount', value: amount, color: AppTokens.ink),
              _StatTile(
                label: 'Accuracy',
                value: accuracy,
                color: AppTokens.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final canSwitchBusiness = authState.availableOrganizations.length > 1;

    return Column(
      children: [
        _MenuGroup(
          items: [
            if (canSwitchBusiness)
              _MenuItem(
                icon: Icons.swap_horiz_rounded,
                label: 'Switch Business',
                color: AppTokens.ink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessSwitcherScreen(
                        isInitialSelection: false,
                      ),
                    ),
                  );
                },
              ),
            _MenuItem(
              icon: Icons.edit_rounded,
              label: 'Edit Profile',
              color: AppTokens.ink,
              onTap: () {
                ToastService.showNeutral('Edit Profile coming soon');
              },
            ),
            _MenuItem(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              color: AppTokens.ink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              color: AppTokens.ink,
              badgeCount: ref.watch(unreadNotificationCountProvider),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        _MenuGroup(
          items: [
            _MenuItem(
              icon: Icons.language_rounded,
              label: 'Language',
              color: AppTokens.ink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSettingsScreen(),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.help_outline_rounded,
              label: 'Help & Contact',
              color: AppTokens.ink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpContactScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.info_outline_rounded,
              label: 'About SnapVerify',
              color: AppTokens.ink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        _buildLogoutButton(context, ref),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SvActionButton(
      label: 'Logout',
      icon: Icons.logout_rounded,
      tone: SvTone.neutral,
      onPressed: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTokens.ice50,
            title: Text(
              'Logout',
              style: AppText.titleMedium.copyWith(color: AppTokens.ink),
            ),
            content: Text(
              'Are you sure you want to logout?',
              style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: AppText.labelLarge.copyWith(color: AppTokens.inkMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Logout',
                  style: AppText.labelLarge.copyWith(color: AppTokens.ink),
                ),
              ),
            ],
          ),
        );

        if (shouldLogout == true) {
          await ref.read(authNotifierProvider.notifier).logout();
        }
      },
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authNotifierProvider);
    _nameCtrl = TextEditingController(text: authState.user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: authState.user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final organization = authState.organization;
    final fullName = user?.fullName ?? 'User';

    return SvAppShell(
      title: 'Edit Profile',
      subtitle: fullName,
      onBack: () => Navigator.pop(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    width: AppTokens.logoTileSize,
                    height: AppTokens.logoTileSize,
                    decoration: BoxDecoration(
                      color: AppTokens.obsidian900,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTokens.ice200),
                    ),
                    child: Center(
                      child: Text(
                        fullName
                            .trim()
                            .split(' ')
                            .map((w) => w[0])
                            .take(2)
                            .join()
                            .toUpperCase(),
                        style: AppTokens.poppins(
                          size: AppTokens.textBodyLarge,
                          weight: FontWeight.w800,
                          color: AppTokens.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: AppTokens.statTileSize / 2,
                      height: AppTokens.statTileSize / 2,
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTokens.ice200),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: AppTokens.checkIconSize,
                        color: AppTokens.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2xl),
            SvFormField(
              controller: _nameCtrl,
              label: 'Full Name',
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            SvFormField(
              controller: _phoneCtrl,
              label: 'Phone Number',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().length < 9
                  ? 'Enter a valid number'
                  : null,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            SvFormField(
              controller: TextEditingController(text: organization?.name ?? ''),
              label: 'Business',
              prefixIcon: Icons.storefront_rounded,
              readOnly: true,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            SvFormField(
              controller: TextEditingController(text: authState.role.label),
              label: 'Role',
              prefixIcon: Icons.badge_rounded,
              readOnly: true,
            ),
            const SizedBox(height: AppTokens.space2xl),
            SvActionButton(
              label: 'Save Changes',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  ToastService.showSuccess('Profile updated');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Change Password',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space2xl,
                      AppTokens.spaceXl,
                      AppTokens.space2xl,
                      AppTokens.space3xl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SvSurfaceCard(
                            padding: const EdgeInsets.all(AppTokens.spaceLg),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppTokens.inkMuted,
                                  size: AppTokens.componentIconMd,
                                ),
                                const SizedBox(width: AppTokens.spaceMd),
                                Expanded(
                                  child: Text(
                                    'Use at least 8 characters with a mix of letters and numbers.',
                                    style: AppText.bodySmall.copyWith(
                                      color: AppTokens.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTokens.spaceXl),
                          SvFormField(
                            controller: _currentCtrl,
                            label: 'Current Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: !_showCurrent,
                            suffixIcon: _EyeToggle(
                              show: _showCurrent,
                              onTap: () =>
                                  setState(() => _showCurrent = !_showCurrent),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: AppTokens.spaceLg),
                          SvFormField(
                            controller: _newCtrl,
                            label: 'New Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: !_showNew,
                            suffixIcon: _EyeToggle(
                              show: _showNew,
                              onTap: () => setState(() => _showNew = !_showNew),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 8) return 'At least 8 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTokens.spaceLg),
                          SvFormField(
                            controller: _confirmCtrl,
                            label: 'Confirm New Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: !_showConfirm,
                            suffixIcon: _EyeToggle(
                              show: _showConfirm,
                              onTap: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v != _newCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTokens.space2xl),
                          SvActionButton(
                            label: _saving ? 'Updating...' : 'Update Password',
                            onPressed: _saving
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() => _saving = true);
                                    try {
                                      await ref
                                          .read(authNotifierProvider.notifier)
                                          .changePassword(
                                            currentPassword: _currentCtrl.text,
                                            newPassword: _newCtrl.text,
                                          );
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      ToastService.showSuccess(
                                        'Password changed successfully',
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ToastService.showError(
                                        e.toString().replaceFirst(
                                          RegExp(r'^Exception:\s*'),
                                          '',
                                        ),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _saving = false);
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class HelpContactScreen extends StatelessWidget {
  const HelpContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Help & Contact',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space2xl,
                      AppTokens.spaceXl,
                      AppTokens.space2xl,
                      AppTokens.space3xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          style: AppText.bodyMedium.copyWith(
                            color: AppTokens.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search help articles...',
                            hintStyle: AppText.bodyMedium.copyWith(
                              color: AppTokens.inkMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppTokens.inkMuted,
                              size: AppTokens.componentIconMd,
                            ),
                            filled: true,
                            fillColor: AppTokens.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.spaceLg,
                              vertical: AppTokens.spaceMd,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLg,
                              ),
                              borderSide: const BorderSide(
                                color: AppTokens.ice200,
                                width: AppTokens.componentBorderWidth,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLg,
                              ),
                              borderSide: const BorderSide(
                                color: AppTokens.ice200,
                                width: AppTokens.componentBorderWidth,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLg,
                              ),
                              borderSide: const BorderSide(
                                color: AppTokens.ice200,
                                width: AppTokens.componentBorderWidthStrong,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXl),
                        const SvSectionLabel('Frequently Asked Questions'),
                        const SizedBox(height: AppTokens.spaceMd),
                        const _FaqItem(
                          question: 'How do I verify a payment?',
                          answer:
                              'Open the Camera tab, point it at the customer\'s payment screenshot. The system will automatically scan and verify the transaction within seconds.',
                        ),
                        const _FaqItem(
                          question: 'What does a flagged payment mean?',
                          answer:
                              'A flagged payment has a high risk score — it may be a duplicate, altered, or suspicious screenshot. Review it manually before accepting.',
                        ),
                        const _FaqItem(
                          question: 'How do I add a new staff member?',
                          answer:
                              'Go to Manage → Staff, then tap "Add New Staff". Fill in their name, phone, role and assign them to a branch.',
                        ),
                        const _FaqItem(
                          question:
                              'Can I use SnapVerify for multiple branches?',
                          answer:
                              'Yes. You can manage multiple branches from the Manage tab. Each branch has its own QR code and staff.',
                        ),
                        const SizedBox(height: AppTokens.spaceXl),
                        const SvSectionLabel('Contact Us'),
                        const SizedBox(height: AppTokens.spaceMd),
                        _ContactCard(
                          icon: Icons.send_rounded,
                          label: 'Telegram Support',
                          value: '@snapverify',
                          color: AppTokens.ink,
                          onTap: () => _openTelegram(context),
                        ),
                        const SizedBox(height: AppTokens.spaceSm),
                        _ContactCard(
                          icon: Icons.groups_rounded,
                          label: 'Community Support',
                          value: 't.me/snapverify',
                          color: AppTokens.ink,
                          onTap: () => _openTelegram(context),
                        ),
                        const SizedBox(height: AppTokens.spaceXl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return SvSurfaceCard(
      onTap: () => setState(() => _expanded = !_expanded),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.spaceMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppText.labelLarge.copyWith(color: AppTokens.ink),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTokens.inkMuted,
                  size: AppTokens.componentIconMd,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const _Divider(),
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: Text(
                widget.answer,
                style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SvSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: AppTokens.tapTarget,
            height: AppTokens.tapTarget,
            decoration: const BoxDecoration(color: AppTokens.transparent),
            child: Icon(icon, color: color, size: AppTokens.componentIconMd),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.overline.copyWith(
                    color: AppTokens.inkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: AppTokens.trackingNormal,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  value,
                  style: AppText.labelLarge.copyWith(color: AppTokens.ink),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTokens.inkMuted,
            size: AppTokens.componentIconSm,
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'About SnapVerify',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space2xl,
                      AppTokens.spaceXl,
                      AppTokens.space2xl,
                      AppTokens.space3xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SvSurfaceCard(
                          padding: const EdgeInsets.all(AppTokens.space2xl),
                          child: Column(
                            children: [
                              Container(
                                width:
                                    AppTokens.statTileSize + AppTokens.spaceSm,
                                height:
                                    AppTokens.statTileSize + AppTokens.spaceSm,
                                decoration: BoxDecoration(
                                  color: AppTokens.obsidian900,
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.radiusLg,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: AppTokens.white,
                                  size: AppTokens.heroIndicatorActiveWidth,
                                ),
                              ),
                              const SizedBox(height: AppTokens.spaceLg),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Snap',
                                      style: AppTokens.poppins(
                                        size: AppTokens.textHeadline,
                                        weight: FontWeight.w700,
                                        color: AppTokens.ink,
                                        letterSpacing: AppTokens.trackingTight,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Verify',
                                      style: AppTokens.poppins(
                                        size: AppTokens.textHeadline,
                                        weight: FontWeight.w700,
                                        color: AppTokens.ink,
                                        letterSpacing: AppTokens.trackingTight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTokens.spaceSm),
                              Text(
                                'Version 1.0.0',
                                style: AppText.bodySmall.copyWith(
                                  color: AppTokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceLg),
                        SvSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SvSectionLabel('About'),
                              const SizedBox(height: AppTokens.spaceMd),
                              Text(
                                'SnapVerify is a real-time payment verification platform designed for Ethiopian businesses. It enables staff to instantly verify customer payment screenshots using AI-powered scanning — eliminating fraud and manual errors.',
                                style: AppText.bodySmall.copyWith(
                                  color: AppTokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceMd),
                        SvSurfaceCard(
                          child: Column(
                            children: [
                              const _AboutRow(label: 'Version', value: '1.0.0'),
                              const _Divider(),
                              const _AboutRow(
                                label: 'Platform',
                                value: 'Flutter / Android',
                              ),
                              const _Divider(),
                              const _AboutRow(
                                label: 'Developer',
                                value: 'SnapVerify Team',
                              ),
                              const _Divider(),
                              _AboutRow(
                                label: 'Telegram',
                                value: '@snapverify',
                                onTap: () => _openTelegram(context),
                              ),
                              const _Divider(),
                              const _AboutRow(
                                label: 'Website',
                                value: 'snapverify.com',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXl),
                        Text(
                          '© 2025 SnapVerify. All rights reserved.',
                          style: AppText.caption.copyWith(
                            color: AppTokens.inkMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.spaceLg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _AboutRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
          ),
          Text(value, style: AppText.labelLarge.copyWith(color: AppTokens.ink)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: AppTokens.space2xl,
      thickness: AppTokens.componentBorderWidth,
      color: AppTokens.ice200,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.poppins(
              size: AppTokens.textSubtitle,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: AppTokens.trackingTight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            label,
            style: AppText.caption.copyWith(color: AppTokens.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return SvSurfaceCard(
      color: AppTokens.transparent,
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                const Divider(
                  height: AppTokens.dividerHeight,
                  color: AppTokens.ice200,
                  indent: AppTokens.statTileSize + AppTokens.spaceLg,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badgeCount;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceMd,
        ),
        child: Row(
          children: [
            Container(
              width: AppTokens.statTileSize - AppTokens.spaceSm,
              height: AppTokens.statTileSize - AppTokens.spaceSm,
              decoration: const BoxDecoration(color: AppTokens.transparent),
              child: Icon(icon, color: color, size: AppTokens.componentIconMd),
            ),
            const SizedBox(width: AppTokens.spaceLg),
            Text(
              label,
              style: AppText.bodyMedium.copyWith(color: AppTokens.ink),
            ),
            const Spacer(),
            if (badgeCount > 0) ...[
              SvStatusPill(
                badgeCount > 9 ? '9+' : '$badgeCount',
                tone: SvTone.neutral,
                small: true,
              ),
              const SizedBox(width: AppTokens.spaceSm),
            ],
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTokens.inkMuted,
              size: AppTokens.componentIconSm,
            ),
          ],
        ),
      ),
    );
  }
}
