import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tailwind.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import 'branch_management_screen.dart';
import 'staff_management_screen.dart';
import 'payment_activity_screen.dart';
import 'reports_screen.dart';
import '../../widgets/sv_loader.dart';
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
        final branches = await ref
            .read(authRepositoryProvider)
            .getBranches(
              (await ref
                  .read(authNotifierProvider.notifier)
                  .ensureFreshAccessToken())!,
            );
        final staff = await ref
            .read(authRepositoryProvider)
            .getStaff(
              (await ref
                  .read(authNotifierProvider.notifier)
                  .ensureFreshAccessToken())!,
            );
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => screen));
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final role = authState.role;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todaySummary = ref.watch(
      reportSummaryProvider((from: today, to: today)),
    );

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatisticsGrid(todaySummary),
                const SizedBox(height: 20),
                _buildQuickActions(role),
                const SizedBox(height: 20),
                _buildRecentActivity(todaySummary),
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
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Overview of your business performance',
            style: TextStyle(color: TwColors.slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // Show confirmation dialog
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: TwColors.slate900,
              title: const Text(
                'Logout',
                style: TextStyle(color: TwColors.white),
              ),
              content: const Text(
                'Are you sure you want to logout?',
                style: TextStyle(color: TwColors.slate400),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: TwColors.slate400),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: TwColors.red500),
                  ),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            await ref.read(authNotifierProvider.notifier).logout();
          }
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: TwColors.cardBg,
          foregroundColor: TwColors.slate300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: TwColors.slate700),
          elevation: 0,
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(AsyncValue<ReportSummary> todaySummary) {
    final onlineStaff = _staff.where((s) => s['status'] == 'active').length;
    final offlineStaff = _staff.length - onlineStaff;
    final summary = todaySummary.valueOrNull?.summary;
    final verifiedCount = summary == null
        ? (todaySummary.isLoading ? '...' : '—')
        : '${summary.verified}';
    final currency = summary?.currency ?? 'ETB';
    final verifiedAmount = summary == null
        ? (todaySummary.isLoading ? '...' : '—')
        : '${currency} ${summary.verifiedAmount.toStringAsFixed(2)}';

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
              color: TwColors.brightGreen,
            ),
            const SizedBox(width: 10),
            _StatItem(
              title: 'Offline Staff',
              value: _isLoading ? '...' : offlineStaff.toString(),
              icon: Icons.signal_wifi_off_rounded,
              color: TwColors.amber500,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TwColors.slate700, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TwColors.brightGreen.withValues(alpha: 0.12),
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
                        color: TwColors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$verifiedCount payments',
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
                      color: TwColors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verifiedAmount,
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
          onTap: () =>
              _navigateAndRefresh(const PaymentAccountManagementScreen()),
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

    if (role.canExportReports) {
      actions.add(
        _QuickAction(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          color: TwColors.amber500,
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

  Widget _buildRecentActivity(AsyncValue<ReportSummary> todaySummary) {
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
        todaySummary.when(
          data: (data) {
            if (data.recent.isEmpty) {
              return _emptyActivity('No recent activity');
            }
            return Column(
              children: data.recent.take(3).map((p) {
                final statusColor = _statusColor(p.status);
                final time = DateFormat('h:mm a').format(p.createdAt);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TwColors.slate700, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.transactionId?.isNotEmpty == true
                                  ? p.transactionId!
                                  : p.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TwColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.status} · $time',
                              style: TextStyle(
                                color: TwColors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${p.currency} ${p.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SvLoader.page(),
            ),
          ),
          error: (e, _) => _emptyActivity(
            'Could not load activity: '
            '${e.toString().replaceFirst('Exception: ', '')}',
            onRetry: () {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              ref.invalidate(reportSummaryProvider((from: today, to: today)));
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyActivity(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: TwColors.brightGreen,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return TwColors.brightGreen;
      case 'FAILED':
        return TwColors.red500;
      case 'REJECTED':
        return TwColors.amber500;
      default:
        return TwColors.slate400;
    }
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
          border: Border.all(color: TwColors.slate700, width: 1),
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
                  child: Icon(icon, color: color, size: 20),
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
          border: Border.all(color: TwColors.slate700, width: 1),
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
              child: Icon(icon, color: color, size: 22),
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
