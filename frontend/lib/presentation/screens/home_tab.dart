import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/report_summary.dart';
import '../../presentation/providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/notifications_provider.dart';
import '../../theme/app_tokens.dart';
import 'manage/staff_management_screen.dart';
import 'manage/reports_screen.dart';
import '../widgets/sv_loader.dart';
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

    return Column(
      children: [
        _HomeTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTokens.spaceLg),
                if (_branches.isNotEmpty)
                  _BranchSelector(
                    branches: _branches,
                    selectedBranchId: _selectedBranchId,
                    onSelected: (id) {
                      setState(() {
                        _selectedBranchId = id;
                      });
                    },
                  ),
                if (_branches.isNotEmpty)
                  const SizedBox(height: AppTokens.spaceXl),
                const _SectionLabel(label: 'Live Overview'),
                const SizedBox(height: AppTokens.spaceMd),
                if (_staffError != null)
                  _StaffLoadError(
                    message: _staffError!,
                    onRetry: _isLoading ? null : _loadData,
                  )
                else
                  _LiveStatsRow(
                    staffOnline: onlineStaff,
                    totalStaff: filteredStaff.length,
                  ),
                const SizedBox(height: AppTokens.space2xl),
                _SectionLabel(
                  label: branchName != null
                      ? "Today's Performance ($branchName)"
                      : "Today's Performance",
                ),
                const SizedBox(height: AppTokens.spaceMd),
                const _TodayPaymentsCard(),
                const SizedBox(height: AppTokens.space2xl),
                const _SectionLabel(label: 'Quick Actions'),
                const SizedBox(height: AppTokens.spaceMd),
                _QuickActionsGrid(onScan: widget.onScan),
                const SizedBox(height: AppTokens.space3xl),
              ],
            ),
          ),
        ),
      ],
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
    return Container(
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
              Icon(
                Icons.location_city_rounded,
                color: AppTokens.accent,
                size: AppTokens.componentIconMd,
              ),
              const SizedBox(width: AppTokens.dropdownIconGap),
              Text(
                'Branch Overview',
                style: AppTokens.manrope(
                  size: AppTokens.textBodySmall,
                  weight: FontWeight.w600,
                  color: AppTokens.white.withValues(
                    alpha: AppTokens.alphaDisabled,
                  ),
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
              color: AppTokens.obsidian950,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: AppTokens.obsidian700,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedBranchId,
                isExpanded: true,
                dropdownColor: AppTokens.obsidian950,
                icon: Container(
                  padding: const EdgeInsets.all(AppTokens.spaceXs),
                  decoration: BoxDecoration(
                    color: AppTokens.obsidian800,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTokens.white.withValues(
                      alpha: AppTokens.alphaPrimaryMuted,
                    ),
                    size: AppTokens.componentIconMd,
                  ),
                ),
                style: AppTokens.manrope(
                  size: AppTokens.textBody,
                  weight: FontWeight.w600,
                  color: AppTokens.white,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Container(
                          width: AppTokens.textCaption,
                          height: AppTokens.textCaption,
                          margin: const EdgeInsets.only(
                            right: AppTokens.dropdownIconGap,
                          ),
                          decoration: BoxDecoration(
                            color: AppTokens.accent,
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
                            width: AppTokens.textCaption,
                            height: AppTokens.textCaption,
                            margin: const EdgeInsets.only(
                              right: AppTokens.dropdownIconGap,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.accent,
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

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.formPaddingH,
        AppTokens.spaceLg,
        AppTokens.spaceLg,
        AppTokens.spaceLg,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.obsidian800,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppTokens.languageItemHeight,
            height: AppTokens.languageItemHeight,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTokens.accent, AppTokens.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppTokens.obsidian950,
              size: AppTokens.errorIconSize,
            ),
          ),
          const SizedBox(width: AppTokens.dropdownIconGap),
          Text(
            'SnapVerify',
            style: AppTokens.poppins(
              size: AppTokens.spaceXl,
              weight: FontWeight.w800,
              color: AppTokens.white,
              letterSpacing: AppTokens.trackingTight,
            ),
          ),
          const Spacer(),
          const _NotificationsBell(),
          const SizedBox(width: AppTokens.spaceSm),
          _TopBarIcon(
            icon: Icons.person_rounded,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return _TopBarIcon(
      icon: Icons.notifications_none_rounded,
      badgeCount: unread,
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  const _TopBarIcon({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.dropdownIconGap),
            decoration: BoxDecoration(
              color: AppTokens.white.withValues(alpha: AppTokens.alphaSubtle),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: AppTokens.obsidian700,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            child: Icon(
              icon,
              color: AppTokens.white,
              size: AppTokens.formPrefixIconSize,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -AppTokens.spaceXs,
              right: -AppTokens.spaceXs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.componentBorderWidth,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.error,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  border: Border.all(
                    color: AppTokens.obsidian950,
                    width: AppTokens.focusBorderWidth,
                  ),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: AppTokens.dmSans(
                    size: AppTokens.textOverline,
                    weight: FontWeight.w700,
                    color: AppTokens.white,
                    height: AppTokens.lineHeightNormal,
                  ),
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
      style: AppTokens.poppins(
        size: AppTokens.textBodyLarge,
        weight: FontWeight.w700,
        color: AppTokens.white,
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

    return Row(
      children: [
        _LiveStatCard(
          icon: Icons.people_rounded,
          value: '$staffOnline/$totalStaff',
          label: 'Staff Online',
          color: AppTokens.accent,
          isLive: true,
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        _LiveStatCard(
          icon: Icons.warning_amber_rounded,
          value: flagged,
          label: 'Flagged',
          color: AppTokens.warning,
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        _LiveStatCard(
          icon: Icons.receipt_long_rounded,
          value: txns,
          label: 'Txns Today',
          color: AppTokens.primary,
        ),
      ],
    );
  }
}

class _LiveStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isLive;

  const _LiveStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.heroStatusPaddingH,
          vertical: AppTokens.spaceLg,
        ),
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
                  padding: const EdgeInsets.all(AppTokens.languageItemPaddingH),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: AppTokens.alphaLow),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: AppTokens.checkIconSize,
                  ),
                ),
                if (isLive) ...[
                  const Spacer(),
                  Container(
                    width: AppTokens.languageItemPaddingH,
                    height: AppTokens.languageItemPaddingH,
                    decoration: const BoxDecoration(
                      color: AppTokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTokens.badgeSmallPaddingH),
            Text(
              value,
              style: AppTokens.poppins(
                size: AppTokens.spaceXl,
                weight: FontWeight.w800,
                color: AppTokens.white,
                letterSpacing: AppTokens.trackingTight,
              ),
            ),
            const SizedBox(height: AppTokens.focusBorderWidth),
            Text(
              label,
              style: AppTokens.dmSans(
                size: AppTokens.textOverline,
                weight: FontWeight.w500,
                color: AppTokens.white.withValues(
                  alpha: AppTokens.alphaSecondary,
                ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: AppTokens.error.withValues(alpha: AppTokens.alphaMuted),
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTokens.error,
                size: AppTokens.errorIconSize,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  'Could not load live overview',
                  style: AppTokens.manrope(
                    size: AppTokens.textLabel,
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
                  message,
                  style: AppTokens.dmSans(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w400,
                    color: AppTokens.white.withValues(
                      alpha: AppTokens.alphaTertiary,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.accent,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.statCardPadding),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: AppTokens.obsidian700,
          width: AppTokens.componentBorderWidth,
        ),
      ),
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
            Container(
              padding: const EdgeInsets.all(AppTokens.languageTopPadding),
              decoration: BoxDecoration(
                color: AppTokens.accent.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppTokens.accent,
                size: AppTokens.componentIconMd,
              ),
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
                      weight: FontWeight.w700,
                      color: AppTokens.white,
                    ),
                  ),
                  const SizedBox(height: AppTokens.focusBorderWidth),
                  Text(
                    'Your business · today',
                    style: AppTokens.dmSans(
                      size: AppTokens.textOverline,
                      weight: FontWeight.w600,
                      color: AppTokens.accent,
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
            color: AppTokens.accent,
            letterSpacing: AppTokens.trackingTight,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          '${s.total} total transactions processed',
          style: AppTokens.dmSans(
            size: AppTokens.textCaption,
            weight: FontWeight.w400,
            color: AppTokens.white.withValues(alpha: AppTokens.alphaSecondary),
          ),
        ),
        const SizedBox(height: AppTokens.spaceXl),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusXs),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: AppTokens.badgePaddingV,
            backgroundColor: AppTokens.obsidian800,
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
              color: AppTokens.warning,
            ),
            const SizedBox(width: AppTokens.space2xl),
            _PaymentStat(
              label: 'Avg Amount',
              value: '${s.currency} ${s.averageAmount.toStringAsFixed(2)}',
              color: AppTokens.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        const SvLoader.inline(),
        const SizedBox(width: AppTokens.spaceMd),
        Text(
          "Loading today's activity...",
          style: AppTokens.dmSans(
            size: AppTokens.textLabel,
            weight: FontWeight.w400,
            color: AppTokens.white.withValues(alpha: AppTokens.alphaTertiary),
          ),
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
              color: AppTokens.error,
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
                style: AppTokens.dmSans(
                  size: AppTokens.textCaption,
                  weight: FontWeight.w400,
                  color: AppTokens.white.withValues(
                    alpha: AppTokens.alphaSecondary,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTokens.accent,
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
          style: AppTokens.dmSans(
            size: AppTokens.textOverline,
            weight: FontWeight.w400,
            color: AppTokens.white.withValues(alpha: AppTokens.alphaOverlay),
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
        Icons.qr_code_scanner_rounded,
        'Scan QR',
        AppTokens.accent,
        onTap: () {
          if (onScan != null) {
            onScan!();
          } else {
            _navigate(context, 2);
          }
        },
      ),
      _ActionItem(
        Icons.receipt_long_rounded,
        'Payments',
        AppTokens.primary,
        onTap: () => _navigate(context, 1),
      ),
      if (canManage)
        _ActionItem(
          Icons.people_rounded,
          'Staff',
          AppTokens.accent,
          onTap: () => _push(context, const StaffManagementScreen()),
        ),
      if (canManage)
        _ActionItem(
          Icons.bar_chart_rounded,
          'Reports',
          AppTokens.warning,
          onTap: () => _push(context, const ReportsScreen()),
        ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppTokens.badgeSmallPaddingH,
      mainAxisSpacing: AppTokens.badgeSmallPaddingH,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: actions.map((a) => _QuickActionCard(item: a)).toList(),
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _ActionItem(this.icon, this.label, this.color, {this.onTap = _noop});
  static void _noop() {}
}

class _QuickActionCard extends StatelessWidget {
  final _ActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.heroStatusPaddingH,
        ),
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
              padding: const EdgeInsets.all(AppTokens.languageTopPadding),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: AppTokens.errorIconSize,
              ),
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Text(
              item.label,
              style: AppTokens.manrope(
                size: AppTokens.textBodySmall,
                weight: FontWeight.w600,
                color: AppTokens.white,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTokens.white.withValues(alpha: AppTokens.alphaMedium),
              size: AppTokens.componentIconSm,
            ),
          ],
        ),
      ),
    );
  }
}
