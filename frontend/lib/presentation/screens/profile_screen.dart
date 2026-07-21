import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../providers/auth_provider.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final organization = authState.organization;

    final fullName = user?.fullName ?? 'User';
    final role = authState.role.label;
    final phoneNumber = user?.phone ?? '';
    final businessName = organization?.name ?? '';

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildAvatar(fullName, role),
                    const SizedBox(height: 28),
                    _buildInfoCard(phoneNumber, businessName),
                    const SizedBox(height: 16),
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildMenuSection(context, ref),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TwColors.slate800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TwColors.slate700, width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: TwColors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Profile',
              style: TextStyle(color: TwColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String fullName, String role) {
    final initials = fullName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TwColors.brightGreen, TwColors.lime400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: TwColors.slate800, width: 3),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
        ),
        const SizedBox(height: 14),
        Text(fullName,
            style: const TextStyle(
                color: TwColors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: TwColors.brightGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TwColors.brightGreen.withOpacity(0.3), width: 1),
          ),
          child: Text(role,
              style: const TextStyle(color: TwColors.brightGreen, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String phone, String businessName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Info',
              style: TextStyle(
                  color: TwColors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: phone),
          const _Divider(),
          _InfoRow(icon: Icons.storefront_rounded, label: 'Business', value: businessName),
          const _Divider(),
          _InfoRow(
            icon: Icons.circle,
            label: 'Status',
            value: 'Active',
            valueColor: TwColors.brightGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Performance",
              style: TextStyle(
                  color: TwColors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(label: 'Verifications', value: '0', color: TwColors.brightGreen),
              _StatTile(label: 'Amount', value: 'ETB 0', color: TwColors.sky500),
              _StatTile(
                  label: 'Accuracy',
                  value: '100%',
                  color: TwColors.lime400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _MenuGroup(items: [
          _MenuItem(
            icon: Icons.edit_rounded,
            label: 'Edit Profile',
            color: TwColors.sky500,
            onTap: () {
              // TODO: Implement Edit Profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Profile coming soon')),
              );
            },
          ),
          _MenuItem(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            color: TwColors.lime400,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          ),
          _MenuItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            color: Colors.purple,
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 12),
        _MenuGroup(items: [
          _MenuItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Contact',
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpContactScreen())),
          ),
          _MenuItem(
            icon: Icons.info_outline_rounded,
            label: 'About SnapVerify',
            color: TwColors.slate500,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ]),
        const SizedBox(height: 12),
        _MenuGroup(items: [
          _MenuItem(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: TwColors.red500,
            isDestructive: true,
            onTap: () async => await ref.read(authNotifierProvider.notifier).logout(),
          ),
        ]),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── Edit Profile Screen ──────────────────────────────────────────────────────
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

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _SubHeader(title: 'Edit Profile', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [TwColors.brightGreen, TwColors.lime400],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  fullName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                                  style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: TwColors.brightGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: TwColors.primaryBg, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ProfileField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 16),
                      _ProfileField(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().length < 9 ? 'Enter a valid number' : null),
                      const SizedBox(height: 16),
                      _ProfileField(
                        controller: TextEditingController(text: organization?.name ?? ''),
                        label: 'Business', icon: Icons.storefront_rounded, readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        controller: TextEditingController(text: authState.role.label),
                        label: 'Role', icon: Icons.badge_rounded, readOnly: true,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated'), backgroundColor: TwColors.slate700, behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwColors.brightGreen, foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
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

// ─── Change Password Screen ───────────────────────────────────────────────────
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

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
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _SubHeader(title: 'Change Password', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: TwColors.sky500.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TwColors.sky500.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: TwColors.sky500, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Use at least 8 characters with a mix of letters and numbers.',
                                style: TextStyle(color: TwColors.white.withOpacity(0.7), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ProfileField(
                        controller: _currentCtrl,
                        label: 'Current Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: !_showCurrent,
                        suffix: _EyeToggle(show: _showCurrent, onTap: () => setState(() => _showCurrent = !_showCurrent)),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        controller: _newCtrl,
                        label: 'New Password',
                        icon: Icons.lock_rounded,
                        obscureText: !_showNew,
                        suffix: _EyeToggle(show: _showNew, onTap: () => setState(() => _showNew = !_showNew)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'At least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        controller: _confirmCtrl,
                        label: 'Confirm New Password',
                        icon: Icons.lock_rounded,
                        obscureText: !_showConfirm,
                        suffix: _EyeToggle(show: _showConfirm, onTap: () => setState(() => _showConfirm = !_showConfirm)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != _newCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password changed successfully'), backgroundColor: TwColors.slate700, behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwColors.brightGreen, foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                          ),
                          child: const Text('Update Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
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
        padding: const EdgeInsets.only(right: 14),
        child: Icon(
          show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: TwColors.white.withOpacity(0.4), size: 20,
        ),
      ),
    );
  }
}

// ─── Help & Contact Screen ────────────────────────────────────────────────────
class HelpContactScreen extends StatelessWidget {
  const HelpContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _SubHeader(title: 'Help & Contact', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: TextField(
                        style: const TextStyle(color: TwColors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search help articles...',
                          hintStyle: TextStyle(color: TwColors.white.withOpacity(0.3), fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: TwColors.white.withOpacity(0.4), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Frequently Asked Questions'),
                    const SizedBox(height: 12),
                    const _FaqItem(
                      question: 'How do I verify a payment?',
                      answer: 'Open the Camera tab, point it at the customer\'s payment screenshot. The system will automatically scan and verify the transaction within seconds.',
                    ),
                    const _FaqItem(
                      question: 'What does a flagged payment mean?',
                      answer: 'A flagged payment has a high risk score — it may be a duplicate, altered, or suspicious screenshot. Review it manually before accepting.',
                    ),
                    const _FaqItem(
                      question: 'How do I add a new staff member?',
                      answer: 'Go to Manage → Staff, then tap "Add New Staff". Fill in their name, phone, role and assign them to a branch.',
                    ),
                    const _FaqItem(
                      question: 'Can I use SnapVerify for multiple branches?',
                      answer: 'Yes. You can manage multiple branches from the Manage tab. Each branch has its own QR code and staff.',
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Contact Us'),
                    const SizedBox(height: 12),
                    _ContactCard(
                      icon: Icons.email_rounded,
                      label: 'Email Support',
                      value: 'support@snapverify.com',
                      color: TwColors.sky500,
                    ),
                    const SizedBox(height: 10),
                    _ContactCard(
                      icon: Icons.phone_rounded,
                      label: 'Phone Support',
                      value: '+251 911 000 000',
                      color: TwColors.brightGreen,
                    ),
                    const SizedBox(height: 10),
                    _ContactCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Live Chat',
                      value: 'Available Mon–Sat, 8AM–8PM',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 24),
                  ],
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
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: TwColors.white.withOpacity(0.4), size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              Container(height: 1, color: TwColors.slate800),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.answer,
                    style: TextStyle(color: TwColors.white.withOpacity(0.65), fontSize: 13, height: 1.6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ContactCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: TwColors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: TwColors.white.withOpacity(0.2), size: 13),
        ],
      ),
    );
  }
}

// ─── About Screen ─────────────────────────────────────────────────────────────
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _SubHeader(title: 'About SnapVerify', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Logo card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D1F0A), Color(0xFF050D18)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: TwColors.brightGreen.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [TwColors.brightGreen, TwColors.lime400],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.verified_rounded, color: Colors.black, size: 30),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            text: const TextSpan(children: [
                              TextSpan(text: 'Snap', style: TextStyle(color: TwColors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              TextSpan(text: 'Verify', style: TextStyle(color: TwColors.brightGreen, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Text('Version 1.0.0', style: TextStyle(color: TwColors.white.withOpacity(0.5), fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About',
                              style: TextStyle(color: TwColors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'SnapVerify is a real-time payment verification platform designed for Ethiopian businesses. It enables staff to instantly verify customer payment screenshots using AI-powered scanning — eliminating fraud and manual errors.',
                            style: TextStyle(color: TwColors.white.withOpacity(0.75), fontSize: 14, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: Column(
                        children: [
                          _AboutRow(label: 'Version', value: '1.0.0'),
                          const _Divider(),
                          _AboutRow(label: 'Platform', value: 'Flutter / Android'),
                          const _Divider(),
                          _AboutRow(label: 'Developer', value: 'SnapVerify Team'),
                          const _Divider(),
                          _AboutRow(label: 'Contact', value: 'hello@snapverify.com'),
                          const _Divider(),
                          _AboutRow(label: 'Website', value: 'snapverify.com'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '© 2025 SnapVerify. All rights reserved.',
                      style: TextStyle(color: TwColors.white.withOpacity(0.3), fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                  ],
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
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: TwColors.white.withOpacity(0.45), fontSize: 13)),
        Text(value, style: const TextStyle(color: TwColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _SubHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _SubHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: TwColors.slate800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TwColors.slate700, width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: TwColors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(color: TwColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(color: TwColors.white, fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: TwColors.white.withOpacity(0.65), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: readOnly ? TwColors.white.withOpacity(0.45) : TwColors.white,
            fontSize: 14, fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintStyle: TextStyle(color: TwColors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(icon, color: TwColors.white.withOpacity(0.4), size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: TwColors.slate800,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: TwColors.slate700, width: 1)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: TwColors.slate700, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TwColors.brightGreen, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TwColors.red500, width: 1)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TwColors.red500, width: 1.5)),
            errorStyle: const TextStyle(color: TwColors.red500, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: TwColors.slate800, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: TwColors.white.withOpacity(0.5), size: 15),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: TwColors.white.withOpacity(0.45), fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: valueColor ?? TwColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 1, color: TwColors.slate800);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: TwColors.white.withOpacity(0.45), fontSize: 11)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                Container(height: 1, color: TwColors.slate800, margin: const EdgeInsets.only(left: 56)),
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
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon, required this.label, required this.color, required this.onTap, this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: isDestructive ? TwColors.red500 : TwColors.white,
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (!isDestructive)
              Icon(Icons.arrow_forward_ios_rounded, color: TwColors.white.withOpacity(0.2), size: 13),
          ],
        ),
      ),
    );
  }
}
