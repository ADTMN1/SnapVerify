import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/ui.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/reports_provider.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';
import 'branch_management_screen.dart';
import 'staff_management_screen.dart';
import 'payment_activity_screen.dart';
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
    final unread = ref.watch(unreadNotificationCountProvider);

    return Column(
      children: [
        _buildHeader(unread),
        Expanded(child: _buildSheet(role, todaySummary)),
      ],
    );
  }

  Widget _buildHeader(int unread) {
    return SvDashboardHeader(
      title: 'Manage',
      actions: [
        SvDashboardHeaderButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: unread,
          tooltip: 'Notifications',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        SvDashboardHeaderButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Profile',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
      ],
    );
  }

  Widget _buildSheet(UserRole role, AsyncValue<ReportSummary> todaySummary) {
    return Container(
      color: AppTokens.ice50,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTokens.formMaxWidth),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sheetHorizontalPadding,
              AppTokens.spaceLg,
              AppTokens.sheetHorizontalPadding,
              AppTokens.sheetBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeading(),
                const SizedBox(height: AppTokens.space2xl),
                if (_loadError != null) ...[
                  _buildLoadError(),
                  const SizedBox(height: AppTokens.spaceXl),
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
      ),
    );
  }

  Widget _buildHeading() {
    final authState = ref.watch(authNotifierProvider);
    final businessName = authState.organization?.name ?? 'Your Business';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          businessName,
          style: AppTokens.poppins(
            size: AppTokens.textHeadline,
            weight: FontWeight.w800,
            color: AppTokens.ink,
            letterSpacing: AppTokens.trackingTight,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          'Overview of your business performance',
          style: AppText.caption.copyWith(color: AppTokens.inkMuted),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return _ManageCard(
      backgroundColor: AppTokens.dangerBg,
      borderColor: AppTokens.danger,
      padding: const EdgeInsets.all(AppTokens.errorPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Could not load branches and staff: $_loadError',
              style: AppText.bodySmall.copyWith(color: AppTokens.danger),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.danger,
              textStyle: AppText.labelLarge,
            ),
            child: Text(
              'Retry',
              style: AppText.labelLarge.copyWith(color: AppTokens.danger),
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
              backgroundColor: AppTokens.ice50,
              elevation: AppTokens.dialogElevation,
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
                    style: AppText.bodySmall.copyWith(
                      color: AppTokens.inkMuted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Logout',
                    style: AppText.labelLarge.copyWith(color: AppTokens.danger),
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
          backgroundColor: AppTokens.white,
          foregroundColor: AppTokens.danger,
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          ),
          side: BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
          textStyle: AppText.labelLarge,
        ),
        icon: const Icon(
          Icons.logout_rounded,
          color: AppTokens.ink,
          size: AppTokens.progressSize,
        ),
        label: const Text('Logout'),
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
              color: AppTokens.ink,
            ),
            const SizedBox(width: AppTokens.statChangePaddingH),
            _StatItem(
              title: 'Total Staff',
              value: _isLoading ? '...' : _staff.length.toString(),
              icon: Icons.people_rounded,
              color: AppTokens.ink,
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
              color: AppTokens.ink,
            ),
            const SizedBox(width: AppTokens.statChangePaddingH),
            _StatItem(
              title: 'Offline Staff',
              value: _isLoading ? '...' : offlineStaff.toString(),
              icon: Icons.signal_wifi_off_rounded,
              color: AppTokens.ink,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        _ManageCard(
          backgroundColor: AppTokens.white,
          child: Row(
            children: [
              const Icon(
                Icons.payments_rounded,
                color: AppTokens.ink,
                size: AppTokens.componentIconMd,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Verified Payments",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSmall.copyWith(
                        color: AppTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppTokens.statTitleGap),
                    Text(
                      '$verifiedCount payments',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelLarge.copyWith(
                        color: AppTokens.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppTokens.trackingTight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Amount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.overline.copyWith(
                        color: AppTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                    Text(
                      verifiedAmount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.labelLarge.copyWith(
                        color: AppTokens.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppTokens.trackingTight,
                      ),
                    ),
                  ],
                ),
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
          color: AppTokens.ink,
          onTap: () => _navigateAndRefresh(const BranchManagementScreen()),
        ),
      );
    }

    if (role.canAddStaff) {
      actions.add(
        _QuickAction(
          icon: Icons.person_add_rounded,
          label: 'Staff',
          color: AppTokens.ink,
          onTap: () => _navigateAndRefresh(const StaffManagementScreen()),
        ),
      );
    }

    if (role.canAddPaymentAccount) {
      actions.add(
        _QuickAction(
          icon: Icons.account_balance_rounded,
          label: 'Accounts',
          color: AppTokens.ink,
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
        color: AppTokens.ink,
        onTap: () => _navigateAndRefresh(const PaymentActivityScreen()),
      ),
    );

    if (role.canExportReports) {
      actions.add(
        _QuickAction(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          color: AppTokens.ink,
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
        const SvSectionLabel('Quick Actions'),
        const SizedBox(height: AppTokens.spaceMd),
        GridView.count(
          crossAxisCount: 2,
          mainAxisExtent: AppTokens.tapTarget + AppTokens.space2xl,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppTokens.spaceMd,
          crossAxisSpacing: AppTokens.spaceMd,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(AsyncValue<ReportSummary> todaySummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SvSectionLabel('Recent Activity'),
        const SizedBox(height: AppTokens.spaceMd),
        todaySummary.when(
          data: (data) {
            if (data.recent.isEmpty) {
              return _emptyActivity('No recent activity');
            }
            return Column(
              children: data.recent.take(3).map((p) {
                final time = DateFormat('h:mm a').format(p.createdAt);
                return _ManageCard(
                  margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  backgroundColor: AppTokens.surfaceLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.heroStatusPaddingH,
                    vertical: AppTokens.spaceMd,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: AppTokens.heroDotSize,
                        height: AppTokens.heroDotSize,
                        decoration: const BoxDecoration(
                          color: AppTokens.inkMuted,
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
                              style: AppText.labelMedium.copyWith(
                                color: AppTokens.ink,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceXs),
                            Text(
                              '${p.status} · $time',
                              style: AppText.overline.copyWith(
                                color: AppTokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${p.currency} ${p.amount.toStringAsFixed(2)}',
                        style: AppText.labelMedium.copyWith(
                          color: AppTokens.ink,
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
              child: SvLoader.page(color: AppTokens.inkMuted),
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
              style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  textStyle: AppText.labelLarge,
                ),
                child: Text(
                  'Retry',
                  style: AppText.labelLarge.copyWith(color: AppTokens.inkMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceLg),
    this.margin,
    this.onTap,
    this.backgroundColor = AppTokens.white,
    this.borderColor = AppTokens.ice200,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    Widget card = SvSurfaceCard(
      color: backgroundColor,
      borderColor: borderColor,
      padding: padding,
      onTap: onTap,
      child: child,
    );

    final cardMargin = margin;
    if (cardMargin != null) {
      card = Padding(padding: cardMargin, child: card);
    }
    return card;
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
      child: _ManageCard(
        backgroundColor: AppTokens.surfaceLight,
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTokens.poppins(
                size: AppTokens.textHeadline,
                weight: FontWeight.w800,
                color: color,
                letterSpacing: AppTokens.trackingTight,
              ),
            ),
            const SizedBox(height: AppTokens.focusBorderWidth),
            Row(
              children: [
                Icon(
                  icon,
                  size: AppTokens.componentIconSm,
                  color: AppTokens.inkMuted,
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.overline.copyWith(
                      color: AppTokens.inkMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppTokens.trackingNormal,
                    ),
                  ),
                ),
              ],
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
    return _ManageCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceMd,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: AppTokens.componentIconSm + AppTokens.spaceXs,
          ),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelLarge.copyWith(
                color: AppTokens.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: AppTokens.trackingTight,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),
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
