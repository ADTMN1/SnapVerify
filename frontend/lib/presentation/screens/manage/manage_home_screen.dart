import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tailwind.dart';
import '../../../presentation/providers/auth_provider.dart';
import 'branch_management_screen.dart';
import 'staff_management_screen.dart';
import 'payment_activity_screen.dart';
import 'qr_management_screen.dart';
import 'reports_screen.dart';
import 'payment_account_management_screen.dart';

class ManageHomeScreen extends ConsumerStatefulWidget {
  const ManageHomeScreen({super.key});

  @override
  ConsumerState<ManageHomeScreen> createState() => _ManageHomeScreenState();
}

class _ManageHomeScreenState extends ConsumerState<ManageHomeScreen> {
  List<dynamic> _branches = [];
  List<dynamic> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        final branches = await ref.read(authRepositoryProvider).getBranches(authState.tokens!.accessToken);
        final staff = await ref.read(authRepositoryProvider).getStaff(authState.tokens!.accessToken);
        if (mounted) {
          setState(() {
            _branches = branches;
            _staff = staff;
          });
        }
      }
    } catch (e) {
      // Ignore error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final role = authState.role;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatisticsGrid(),
                const SizedBox(height: 20),
                _buildQuickActions(role),
                const SizedBox(height: 20),
                _buildRecentActivity(),
                const SizedBox(height: 20),
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final authState = ref.watch(authNotifierProvider);
    final businessName = authState.organization?.name ?? 'Your Business';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: TwColors.slate800,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Overview of your business performance',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // Show confirmation dialog
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: TwColors.slate900,
              title: const Text('Logout', style: TextStyle(color: TwColors.white)),
              content: const Text('Are you sure you want to logout?', style: TextStyle(color: TwColors.slate400)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: TwColors.slate400)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Logout', style: TextStyle(color: TwColors.red500)),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            await ref.read(authNotifierProvider.notifier).logout();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: TwColors.red500.withOpacity(0.1),
          foregroundColor: TwColors.red500,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: TwColors.red500.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Logout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    final onlineStaff = _staff.where((s) => s['status'] == 'active').length;
    final offlineStaff = _staff.length - onlineStaff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatItem(
              title: 'Total Branches',
              value: _isLoading ? '...' : _branches.length.toString(),
              icon: Icons.storefront_rounded,
              color: TwColors.brightGreen,
            ),
            const SizedBox(width: 10),
            _StatItem(
              title: 'Total Staff',
              value: _isLoading ? '...' : _staff.length.toString(),
              icon: Icons.people_rounded,
              color: TwColors.lime400,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatItem(
              title: 'Online Staff',
              value: _isLoading ? '...' : onlineStaff.toString(),
              icon: Icons.wifi_rounded,
              color: Colors.green,
            ),
            const SizedBox(width: 10),
            _StatItem(
              title: 'Offline Staff',
              value: _isLoading ? '...' : offlineStaff.toString(),
              icon: Icons.signal_wifi_off_rounded,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TwColors.slate700,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TwColors.brightGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: TwColors.brightGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Verified Payments",
                      style: TextStyle(
                        color: TwColors.white.withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "0 payments",
                      style: const TextStyle(
                        color: TwColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total Amount",
                    style: TextStyle(
                      color: TwColors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ETB 0.00",
                    style: const TextStyle(
                      color: TwColors.brightGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(UserRole role) {
    final actions = <Widget>[];

    if (role.canAddBranch) {
      actions.add(
        _QuickAction(
          icon: Icons.store_mall_directory_rounded,
          label: 'Branches',
          color: TwColors.brightGreen,
          onTap: () => _navigateAndRefresh(const BranchManagementScreen()),
        ),
      );
    }

    if (role.canAddStaff) {
      actions.add(
        _QuickAction(
          icon: Icons.person_add_rounded,
          label: 'Staff',
          color: TwColors.lime400,
          onTap: () => _navigateAndRefresh(const StaffManagementScreen()),
        ),
      );
    }

    if (role.canAddPaymentAccount) {
      actions.add(
        _QuickAction(
          icon: Icons.account_balance_rounded,
          label: 'Accounts',
          color: TwColors.sky500,
          onTap: () => _navigateAndRefresh(const PaymentAccountManagementScreen()),
        ),
      );
    }

    // Payments is accessible to everyone who can manage
    actions.add(
      _QuickAction(
        icon: Icons.payments_rounded,
        label: 'Payments',
        color: TwColors.sky500,
        onTap: () => _navigateAndRefresh(const PaymentActivityScreen()),
      ),
    );

    if (role.canGenerateQRCode) {
      actions.add(
        _QuickAction(
          icon: Icons.qr_code_2_rounded,
          label: 'QR',
          color: Colors.purple,
          onTap: () => _navigateAndRefresh(const QRManagementScreen()),
        ),
      );
    }

    if (role.canExportReports) {
      actions.add(
        _QuickAction(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          color: Colors.orange,
          onTap: () => _navigateAndRefresh(const ReportsScreen()),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: TwColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            color: TwColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No recent activity',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TwColors.slate700,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: TwColors.white.withOpacity(0.65),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TwColors.slate700,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
