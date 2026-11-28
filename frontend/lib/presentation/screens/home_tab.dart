import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/report_summary.dart';
import '../../presentation/providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/notifications_provider.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../ui/ui.dart';
import 'manage/staff_management_screen.dart';
import 'manage/reports_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  /// Switches the root bottom-nav tab (indexes from HomeScreen layout).
  final void Function(int tabIndex)? onNavigate;
  final VoidCallback? onScan;
  const HomeTab({super.key, this.onNavigate, this.onScan});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  List<dynamic> _branches = [];
  List<dynamic> _staff = [];
  bool _isLoading = true;
  bool _isRefreshingStaff = false;
  String? _staffError;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isRefreshingStaff) return;
    _isRefreshingStaff = true;
    if (mounted && !_isLoading) setState(() => _isLoading = true);

    try {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();
      if (token == null) {
        throw Exception('Not authenticated. Please log in again.');
      }

      final branches = await ref
          .read(authRepositoryProvider)
          .getBranches(token);
      final staff = await ref.read(authRepositoryProvider).getStaff(token);
      if (mounted) {
        setState(() {
          _branches = branches;
          _staff = staff;
          _staffError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _staffError = _staffErrorMessage(e));
      }
    } finally {
      _isRefreshingStaff = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _staffErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('connection reset') ||
        text.contains('connection closed')) {
      return 'Connection lost while loading staff. Check your internet connection and try again.';
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return 'Loading staff timed out. Check your connection and try again.';
    }
    return 'Could not load branches and staff. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _selectedBranchId != null
        ? _staff.where((s) => s['branchId'] == _selectedBranchId).toList()
        : _staff;
    final onlineStaff = filteredStaff
        .where((s) => s['status'] == 'active')
        .length;
    final selectedBranchName = _selectedBranchId != null
        ? _branches.firstWhere(
            (b) => b['id'] == _selectedBranchId,
            orElse: () => null,
          )
        : null;
    final branchName = selectedBranchName?['name'];

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: _HomeSheet(
        branches: _branches,
        selectedBranchId: _selectedBranchId,
        onSelected: (id) {
          setState(() {
            _selectedBranchId = id;
          });
        },
        staffError: _staffError,
        onRetry: _isLoading ? null : _loadData,
        staffOnline: onlineStaff,
        totalStaff: filteredStaff.length,
        branchName: branchName,
        onScan: widget.onScan,
      ),
    );
  }
}

class _HomeSheet extends StatelessWidget {
  final List<dynamic> branches;
  final String? selectedBranchId;
  final Function(String?) onSelected;
  final String? staffError;
  final VoidCallback? onRetry;
  final int staffOnline;
  final int totalStaff;
  final Object? branchName;
  final VoidCallback? onScan;

  const _HomeSheet({
    required this.branches,
    required this.selectedBranchId,
    required this.onSelected,
    required this.staffError,
    required this.onRetry,
    required this.staffOnline,
    required this.totalStaff,
    required this.branchName,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.ice50,
      child: Column(
        children: [
          const _HomeHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              child: LayoutBuilder(
                builder: (context, _) => Center(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (branches.isNotEmpty)
                            _BranchSelector(
                              branches: branches,
                              selectedBranchId: selectedBranchId,
                              onSelected: onSelected,
                            ),
                          if (branches.isNotEmpty)
                            const SizedBox(height: AppTokens.spaceXl),
                          _SectionLabel(
                            label: branchName != null
                                ? "Today's Performance ($branchName)"
                                : "Today's Performance",
                          ),
                          const SizedBox(height: AppTokens.spaceMd),
                          const _TodayPaymentsCard(),
                          const _HomeDivider(),
                          const _SectionLabel(label: 'Live Overview'),
                          const SizedBox(height: AppTokens.spaceMd),
                          if (staffError != null)
                            _StaffLoadError(
                              message: staffError!,
                              onRetry: onRetry,
                            )
                          else
                            _LiveStatsRow(
                              staffOnline: staffOnline,
                              totalStaff: totalStaff,
                            ),
                          const _HomeDivider(),
                          const _SectionLabel(label: 'Quick Actions'),
                          const SizedBox(height: AppTokens.spaceMd),
                          _QuickActionsGrid(onScan: onScan),
                          const SizedBox(height: AppTokens.space3xl),
                        ],
                      ),
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
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return SvDashboardHeader(
      title: 'SnapVerify',
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
}

class _HomeDivider extends StatelessWidget {
  const _HomeDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: AppTokens.space2xl,
      thickness: AppTokens.componentBorderWidth,
      color: AppTokens.ice200,
    );
  }
}

class _HomeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  const _HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceLg),
    this.color = AppTokens.transparent,
    this.borderColor = AppTokens.ice200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: borderColor == AppTokens.transparent
            ? null
            : Border.all(
                color: borderColor,
                width: AppTokens.componentBorderWidth,
              ),
      ),
      child: SvSurfaceCard(color: color, padding: padding, child: child),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<dynamic> branches;
  final String? selectedBranchId;
  final Function(String?) onSelected;

  const _BranchSelector({
    required this.branches,
    required this.selectedBranchId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: AppTokens.ink,
                size: AppTokens.componentIconMd,
              ),
              const SizedBox(width: AppTokens.dropdownIconGap),
              Text(
                'Branch Overview',
                style: AppText.labelMedium.copyWith(
                  color: AppTokens.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.heroStatusPaddingH,
              vertical: AppTokens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: AppTokens.transparent,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: AppTokens.ice200,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedBranchId,
                isExpanded: true,
                dropdownColor: AppTokens.white,
                icon: Container(
                  padding: const EdgeInsets.all(AppTokens.spaceXs),
                  decoration: BoxDecoration(
                    color: AppTokens.ice100,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTokens.inkMuted,
                    size: AppTokens.componentIconMd,
                  ),
                ),
                style: AppTokens.manrope(
                  size: AppTokens.textBody,
                  weight: FontWeight.w700,
                  color: AppTokens.ink,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Container(
                          width: AppTokens.heroDotSize,
                          height: AppTokens.heroDotSize,
                          margin: const EdgeInsets.only(
                            right: AppTokens.dropdownIconGap,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTokens.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Text('All Branches'),
                      ],
                    ),
                  ),
                  ...branches.map((branch) {
                    return DropdownMenuItem<String?>(
                      value: branch['id'],
                      child: Row(
                        children: [
                          Container(
                            width: AppTokens.heroDotSize,
                            height: AppTokens.heroDotSize,
                            margin: const EdgeInsets.only(
                              right: AppTokens.dropdownIconGap,
                            ),
                            decoration: const BoxDecoration(
                              color: AppTokens.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(branch['name']),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppText.titleSmall.copyWith(
        color: AppTokens.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: AppTokens.trackingTight,
      ),
    );
  }
}

class _LiveStatsRow extends ConsumerWidget {
  final int staffOnline;
  final int totalStaff;
  const _LiveStatsRow({required this.staffOnline, required this.totalStaff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final summary = ref
        .watch(reportSummaryProvider((from: today, to: today)))
        .valueOrNull
        ?.summary;
    final flagged = summary == null ? '...' : '${summary.highRisk}';
    final txns = summary == null ? '...' : '${summary.total}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LiveStatCard(
            value: '$staffOnline/$totalStaff',
            label: 'Staff Online',
            color: AppTokens.ink,
          ),
          const SizedBox(width: AppTokens.badgeSmallPaddingH),
          _LiveStatCard(value: flagged, label: 'Flagged', color: AppTokens.ink),
          const SizedBox(width: AppTokens.badgeSmallPaddingH),
          _LiveStatCard(value: txns, label: 'Txns Today', color: AppTokens.ink),
        ],
      ),
    );
  }
}

class _LiveStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _LiveStatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _HomeCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.heroStatusPaddingH,
          vertical: AppTokens.spaceLg,
        ),
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
            Text(
              label,
              style: AppText.overline.copyWith(
                color: AppTokens.inkMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: AppTokens.trackingNormal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffLoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _StaffLoadError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      color: AppTokens.transparent,
      borderColor: AppTokens.ice200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTokens.inkMuted,
                size: AppTokens.errorIconSize,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  'Could not load live overview',
                  style: AppTokens.manrope(
                    size: AppTokens.textLabel,
                    weight: FontWeight.w600,
                    color: AppTokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AppText.caption.copyWith(color: AppTokens.inkMuted),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTokens.manrope(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w700,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayPaymentsCard extends ConsumerWidget {
  const _TodayPaymentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final asyncSummary = ref.watch(
      reportSummaryProvider((from: today, to: today)),
    );

    return _HomeCard(
      color: AppTokens.obsidian950,
      borderColor: AppTokens.obsidian700,
      padding: const EdgeInsets.all(AppTokens.statCardPadding),
      child: asyncSummary.when(
        data: (data) => _buildContent(data),
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(
          e,
          () => ref.invalidate(reportSummaryProvider((from: today, to: today))),
        ),
      ),
    );
  }

  Widget _buildContent(ReportSummary data) {
    final s = data.summary;
    final progress = s.total > 0 ? s.verified / s.total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.payments_rounded,
              color: AppTokens.white,
              size: AppTokens.componentIconLg,
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Verified Payments",
                    style: AppTokens.manrope(
                      size: AppTokens.textBodySmall,
                      weight: FontWeight.w800,
                      color: AppTokens.white,
                    ),
                  ),
                  const SizedBox(height: AppTokens.focusBorderWidth),
                  Text(
                    'Your business · today',
                    style: AppText.overline.copyWith(
                      color: AppTokens.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppTokens.trackingNormal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXl),
        Text(
          '${s.currency} ${s.verifiedAmount.toStringAsFixed(2)}',
          style: AppTokens.poppins(
            size: AppTokens.textDisplay,
            weight: FontWeight.w900,
            color: AppTokens.white,
            letterSpacing: AppTokens.trackingTight,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          '${s.total} total transactions processed',
          style: AppText.caption.copyWith(color: AppTokens.ice400),
        ),
        const SizedBox(height: AppTokens.spaceXl),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusXs),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: AppTokens.badgePaddingV,
            backgroundColor: AppTokens.obsidian700,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.accent),
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Row(
          children: [
            _PaymentStat(
              label: 'Verified',
              value: '${s.verified}',
              color: AppTokens.accent,
            ),
            const SizedBox(width: AppTokens.space2xl),
            _PaymentStat(
              label: 'Flagged',
              value: '${s.highRisk}',
              color: AppTokens.ice400,
            ),
            const SizedBox(width: AppTokens.space2xl),
            _PaymentStat(
              label: 'Avg Amount',
              value: '${s.currency} ${s.averageAmount.toStringAsFixed(2)}',
              color: AppTokens.white,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        const SvLoader.inline(color: AppTokens.ice400),
        const SizedBox(width: AppTokens.spaceMd),
        Text(
          "Loading today's activity...",
          style: AppText.caption.copyWith(color: AppTokens.ice400),
        ),
      ],
    );
  }

  Widget _buildError(Object error, VoidCallback onRetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTokens.ice400,
              size: AppTokens.componentIconMd,
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Text(
                "Could not load today's activity",
                style: AppTokens.manrope(
                  size: AppTokens.textBodySmall,
                  weight: FontWeight.w600,
                  color: AppTokens.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Row(
          children: [
            Expanded(
              child: Text(
                error.toString().replaceFirst('Exception: ', ''),
                style: AppText.caption.copyWith(color: AppTokens.ice400),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTokens.ice400,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTokens.manrope(
                  size: AppTokens.textCaption,
                  weight: FontWeight.w700,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PaymentStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: AppTokens.focusBorderWidth),
        Text(
          label,
          style: AppText.overline.copyWith(
            color: AppTokens.ice400,
            fontWeight: FontWeight.w600,
            letterSpacing: AppTokens.trackingNormal,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  final VoidCallback? onScan;
  const _QuickActionsGrid({this.onScan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final canManage = authState.role.canManage;

    final actions = [
      _ActionItem(
        'Scan QR',
        Icons.qr_code_rounded,
        AppTokens.ink,
        onTap: () {
          if (onScan != null) {
            onScan!();
          } else {
            _navigate(context, 2);
          }
        },
      ),
      _ActionItem(
        'Payments',
        Icons.payments_rounded,
        AppTokens.ink,
        onTap: () => _navigate(context, 1),
      ),
      if (canManage)
        _ActionItem(
          'Staff',
          Icons.groups_outlined,
          AppTokens.ink,
          onTap: () => _push(context, const StaffManagementScreen()),
        ),
      if (canManage)
        _ActionItem(
          'Reports',
          Icons.assessment_outlined,
          AppTokens.ink,
          onTap: () => _push(context, const ReportsScreen()),
        ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTokens.spaceMd,
        mainAxisSpacing: AppTokens.spaceMd,
        mainAxisExtent: 64,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => _QuickActionCard(item: actions[index]),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  static void _navigate(BuildContext context, int tabIndex) {
    // HomeTab's onNavigate is injected by HomeScreen; look it up through the
    // widget tree by finding the HomeTab state via the inherited scope.
    final homeTab = context.findAncestorStateOfType<_HomeTabState>();
    homeTab?.widget.onNavigate?.call(tabIndex);
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionItem(this.label, this.icon, this.color, {this.onTap = _noop});
  static void _noop() {}
}

class _QuickActionCard extends StatelessWidget {
  final _ActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: _HomeCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceMd,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: AppTokens.inkMuted,
              size: AppTokens.componentIconSm + AppTokens.spaceXs,
            ),
            const SizedBox(width: AppTokens.spaceXs),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelLarge.copyWith(
                  color: item.color,
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
      ),
    );
  }
}
