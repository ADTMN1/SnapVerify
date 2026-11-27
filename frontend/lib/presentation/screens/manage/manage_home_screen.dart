import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/ui.dart';
import '../../providers/reports_provider.dart';
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
    final headerHeight = AppTokens.headerVisibleHeight;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight + AppTokens.sheetTopRadius,
          child: _buildHeader(),
        ),
        Positioned(
          top: headerHeight - AppTokens.sheetOverlap,
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildSheet(role, todaySummary),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppTokens.radius2xl),
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppTokens.headerVisibleHeight + AppTokens.sheetTopRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: const AppHeaderPatternPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppTokens.logoTopGap,
              left: 0,
              right: 0,
              child: Center(child: _buildLogo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Semantics(
      label: 'App logo',
      child: Container(
        width: AppTokens.logoTileSize,
        height: AppTokens.logoTileSize,
        decoration: BoxDecoration(
          color: AppTokens.white,
          borderRadius: BorderRadius.circular(AppTokens.logoTileRadius),
        ),
        child: Center(
          child: SizedBox(
            width: AppTokens.logoIconSize,
            height: AppTokens.logoIconSize,
            child: const CustomPaint(painter: AppLogoPainter()),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(UserRole role, AsyncValue<ReportSummary> todaySummary) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTokens.ice50,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sheetHorizontalPadding,
          AppTokens.sheetTopPadding + AppTokens.space3xl,
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
    );
  }

  Widget _buildHeading() {
    final authState = ref.watch(authNotifierProvider);
    final businessName = authState.organization?.name ?? 'Your Business';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(businessName, style: AppText.authTitle),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          'Overview of your business performance',
          style: AppText.authSubtitle,
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
                style: AppText.titleMedium.copyWith(color: AppTokens.text),
              ),
              content: Text(
                'Are you sure you want to logout?',
                style: AppText.bodySmall.copyWith(
                  color: AppTokens.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppText.bodySmall.copyWith(
                      color: AppTokens.textSecondary,
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
            color: AppTokens.border,
            width: AppTokens.componentBorderWidth,
          ),
          elevation: AppTokens.cardElevation,
          shadowColor: AppTokens.shadow,
          textStyle: AppText.labelLarge,
        ),
        icon: const Icon(Icons.logout_rounded, size: AppTokens.progressSize),
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
              color: AppTokens.accent,
            ),
            const SizedBox(width: AppTokens.statChangePaddingH),
            _StatItem(
              title: 'Total Staff',
              value: _isLoading ? '...' : _staff.length.toString(),
              icon: Icons.people_rounded,
              color: AppTokens.primary,
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
              color: AppTokens.teal,
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
        _ManageCard(
          backgroundColor: AppTokens.white,
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
                      style: AppText.labelSmall.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.statTitleGap),
                    Text(
                      '$verifiedCount payments',
                      style: AppText.titleMedium.copyWith(
                        color: AppTokens.text,
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
                    style: AppText.overline.copyWith(
                      color: AppTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    verifiedAmount,
                    style: AppText.titleMedium.copyWith(
                      color: AppTokens.primary,
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
          color: AppTokens.primary,
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
          style: AppText.titleSmall.copyWith(color: AppTokens.text),
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
          style: AppText.titleSmall.copyWith(color: AppTokens.text),
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
                              style: AppText.labelMedium.copyWith(
                                color: AppTokens.text,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceXs),
                            Text(
                              '${p.status} · $time',
                              style: AppText.overline.copyWith(
                                color: AppTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${p.currency} ${p.amount.toStringAsFixed(2)}',
                        style: AppText.labelMedium.copyWith(color: statusColor),
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
              child: SvLoader.page(color: AppTokens.primary),
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
              style: AppText.bodySmall.copyWith(color: AppTokens.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.primary,
                  textStyle: AppText.labelLarge,
                ),
                child: Text(
                  'Retry',
                  style: AppText.labelLarge.copyWith(color: AppTokens.primary),
                ),
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
        return AppTokens.teal;
      case 'FAILED':
        return AppTokens.danger;
      case 'REJECTED':
        return AppTokens.warning;
      default:
        return AppTokens.textSecondary;
    }
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceLg),
    this.margin,
    this.onTap,
    this.backgroundColor = AppTokens.white,
    this.borderColor = AppTokens.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppTokens.componentBorderWidth,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: SVCard(
        backgroundColor: backgroundColor,
        borderRadius: AppTokens.radiusCard,
        hasShadow: true,
        onTap: onTap,
        padding: padding,
        child: child,
      ),
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
            Container(
              width: AppTokens.statTileSize,
              height: AppTokens.statTileSize,
              decoration: BoxDecoration(
                color: color.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(icon, color: color, size: AppTokens.componentIconLg),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: AppText.labelSmall.copyWith(
                color: AppTokens.textSecondary,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              value,
              style: AppText.titleMedium.copyWith(color: AppTokens.text),
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
      padding: const EdgeInsets.all(AppTokens.spaceLg),
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
            child: Icon(icon, color: color, size: AppTokens.formPrefixIconSize),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            label,
            style: AppText.labelMedium.copyWith(color: AppTokens.text),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
