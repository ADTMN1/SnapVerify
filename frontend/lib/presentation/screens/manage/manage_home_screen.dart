import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../theme/app_tokens.dart';
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() => _loadError = null);
      }
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
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst(
            RegExp(r'^[A-Za-z]+\(?\d*\)?:\s*'),
            '',
          );
        });
      }
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.errorPadding),
                    decoration: BoxDecoration(
                      color: AppTokens.error.withValues(
                        alpha: AppTokens.alphaSubtle,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTokens.errorRadius,
                      ),
                      border: Border.all(
                        color: AppTokens.error.withValues(
                          alpha: AppTokens.alphaStrong,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Could not load branches and staff: $_loadError',
                            style: AppTokens.dmSans(
                              size: AppTokens.textLabel,
                              weight: FontWeight.w500,
                              color: AppTokens.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadData,
                          child: Text(
                            'Retry',
                            style: AppTokens.manrope(
                              size: AppTokens.textLabel,
                              weight: FontWeight.w700,
                              color: AppTokens.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceLg),
                ],
                _buildStatisticsGrid(todaySummary),
                const SizedBox(height: AppTokens.spaceXl),
                _buildQuickActions(role),
                const SizedBox(height: AppTokens.spaceXl),
                _buildRecentActivity(todaySummary),
                const SizedBox(height: AppTokens.spaceXl),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.obsidian800,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName,
            style: AppTokens.manrope(
              size: AppTokens.textSubtitle,
              weight: FontWeight.w700,
              color: AppTokens.white,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Overview of your business performance',
            style: AppTokens.dmSans(
              size: AppTokens.textLabel,
              weight: FontWeight.w400,
              color: AppTokens.ice400,
            ),
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
              backgroundColor: AppTokens.obsidian900,
              title: Text(
                'Logout',
                style: AppTokens.manrope(
                  size: AppTokens.textSubtitle,
                  weight: FontWeight.w700,
                  color: AppTokens.white,
                ),
              ),
              content: Text(
                'Are you sure you want to logout?',
                style: AppTokens.dmSans(
                  size: AppTokens.textBodySmall,
                  weight: FontWeight.w400,
                  color: AppTokens.ice400,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTokens.dmSans(
                      size: AppTokens.textBodySmall,
                      weight: FontWeight.w400,
                      color: AppTokens.ice400,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Logout',
                    style: AppTokens.manrope(
                      size: AppTokens.textBodySmall,
                      weight: FontWeight.w600,
                      color: AppTokens.error,
                    ),
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
          backgroundColor: AppTokens.headerFacetA,
          foregroundColor: AppTokens.ice200,
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          side: const BorderSide(color: AppTokens.obsidian700),
          elevation: AppTokens.cardElevation,
        ),
        icon: const Icon(Icons.logout_rounded, size: AppTokens.progressSize),
        label: Text(
          'Logout',
          style: AppTokens.manrope(
            size: AppTokens.textBody,
            weight: FontWeight.w600,
          ),
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
        : '$currency ${summary.verifiedAmount.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatItem(
              title: 'Total Branches',
              value: _isLoading ? '...' : _branches.length.toString(),
              icon: Icons.storefront_rounded,
              color: AppTokens.accent,
            ),
            const SizedBox(width: AppTokens.statChangePaddingH),
            _StatItem(
              title: 'Total Staff',
              value: _isLoading ? '...' : _staff.length.toString(),
              icon: Icons.people_rounded,
              color: AppTokens.success,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.statChangePaddingH),
        Row(
          children: [
            _StatItem(
              title: 'Online Staff',
              value: _isLoading ? '...' : onlineStaff.toString(),
              icon: Icons.wifi_rounded,
              color: AppTokens.accent,
            ),
            const SizedBox(width: AppTokens.statChangePaddingH),
            _StatItem(
              title: 'Offline Staff',
              value: _isLoading ? '...' : offlineStaff.toString(),
              icon: Icons.signal_wifi_off_rounded,
              color: AppTokens.warning,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Container(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          decoration: BoxDecoration(
            color: AppTokens.obsidian950,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(
              color: AppTokens.obsidian700,
              width: AppTokens.componentBorderWidth,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppTokens.tapTarget,
                height: AppTokens.tapTarget,
                decoration: BoxDecoration(
                  color: AppTokens.accent.withValues(alpha: AppTokens.alphaLow),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppTokens.accent,
                  size: AppTokens.componentIconLg,
                ),
              ),
              const SizedBox(width: AppTokens.heroStatusPaddingH),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Verified Payments",
                      style: AppTokens.dmSans(
                        size: AppTokens.textCaption,
                        weight: FontWeight.w500,
                        color: AppTokens.white.withValues(
                          alpha: AppTokens.alphaTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.statTitleGap),
                    Text(
                      '$verifiedCount payments',
                      style: AppTokens.manrope(
                        size: AppTokens.textSubtitle,
                        weight: FontWeight.w700,
                        color: AppTokens.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Amount',
                    style: AppTokens.dmSans(
                      size: AppTokens.textOverline,
                      weight: FontWeight.w500,
                      color: AppTokens.white.withValues(
                        alpha: AppTokens.alphaSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    verifiedAmount,
                    style: AppTokens.manrope(
                      size: AppTokens.textSubtitle,
                      weight: FontWeight.w700,
                      color: AppTokens.accent,
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
          color: AppTokens.accent,
          onTap: () => _navigateAndRefresh(const BranchManagementScreen()),
        ),
      );
    }

    if (role.canAddStaff) {
      actions.add(
        _QuickAction(
          icon: Icons.person_add_rounded,
          label: 'Staff',
          color: AppTokens.success,
          onTap: () => _navigateAndRefresh(const StaffManagementScreen()),
        ),
      );
    }

    if (role.canAddPaymentAccount) {
      actions.add(
        _QuickAction(
          icon: Icons.account_balance_rounded,
          label: 'Accounts',
          color: AppTokens.primary,
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
        color: AppTokens.primary,
        onTap: () => _navigateAndRefresh(const PaymentActivityScreen()),
      ),
    );

    if (role.canExportReports) {
      actions.add(
        _QuickAction(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          color: AppTokens.warning,
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
        Text(
          'Quick Actions',
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w600,
            color: AppTokens.white,
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppTokens.statChangePaddingH,
          crossAxisSpacing: AppTokens.statChangePaddingH,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(AsyncValue<ReportSummary> todaySummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w600,
            color: AppTokens.white,
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
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
                  margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.heroStatusPaddingH,
                    vertical: AppTokens.spaceMd,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.obsidian950,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: AppTokens.obsidian700,
                      width: AppTokens.componentBorderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: AppTokens.heroDotSize,
                        height: AppTokens.heroDotSize,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTokens.statChangePaddingH),
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
                              style: AppTokens.manrope(
                                size: AppTokens.textLabel,
                                weight: FontWeight.w600,
                                color: AppTokens.white,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceXs),
                            Text(
                              '${p.status} · $time',
                              style: AppTokens.dmSans(
                                size: AppTokens.textOverline,
                                weight: FontWeight.w400,
                                color: AppTokens.white.withValues(
                                  alpha: AppTokens.alphaSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${p.currency} ${p.amount.toStringAsFixed(2)}',
                        style: AppTokens.manrope(
                          size: AppTokens.textLabel,
                          weight: FontWeight.w600,
                          color: statusColor,
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
              padding: EdgeInsets.symmetric(vertical: AppTokens.space2xl),
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
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space3xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTokens.dmSans(
                size: AppTokens.textBodySmall,
                weight: FontWeight.w400,
                color: AppTokens.white.withValues(
                  alpha: AppTokens.alphaSecondary,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.accent,
                  textStyle: AppTokens.manrope(
                    size: AppTokens.textLabel,
                    weight: FontWeight.w700,
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
        return AppTokens.success;
      case 'FAILED':
        return AppTokens.error;
      case 'REJECTED':
        return AppTokens.warning;
      default:
        return AppTokens.ice400;
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
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          color: AppTokens.obsidian950,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: AppTokens.obsidian700,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppTokens.handleWidth,
                  height: AppTokens.handleWidth,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: AppTokens.alphaLow),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: AppTokens.componentIconMd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: AppTokens.dmSans(
                size: AppTokens.textCaption,
                weight: FontWeight.w500,
                color: AppTokens.white.withValues(
                  alpha: AppTokens.alphaTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              value,
              style: AppTokens.manrope(
                size: AppTokens.textSubtitle,
                weight: FontWeight.w700,
                color: AppTokens.white,
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
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          color: AppTokens.obsidian950,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: AppTokens.obsidian700,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppTokens.tapTarget,
              height: AppTokens.tapTarget,
              decoration: BoxDecoration(
                color: color.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                icon,
                color: color,
                size: AppTokens.formPrefixIconSize,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              label,
              style: AppTokens.manrope(
                size: AppTokens.textLabel,
                weight: FontWeight.w600,
                color: AppTokens.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
