import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/tailwind.dart';
import '../../domain/entities/report_summary.dart';
import '../../presentation/providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/notifications_provider.dart';
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
  String? _selectedBranchId;

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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
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
                if (_branches.isNotEmpty) const SizedBox(height: 20),
                const _SectionLabel(label: 'Live Overview'),
                const SizedBox(height: 12),
                _LiveStatsRow(
                  staffOnline: onlineStaff,
                  totalStaff: filteredStaff.length,
                ),
                const SizedBox(height: 24),
                _SectionLabel(
                  label: branchName != null
                      ? "Today's Performance ($branchName)"
                      : "Today's Performance",
                ),
                const SizedBox(height: 12),
                const _TodayPaymentsCard(),
                const SizedBox(height: 24),
                const _SectionLabel(label: 'Quick Actions'),
                const SizedBox(height: 12),
                _QuickActionsGrid(onScan: widget.onScan),
                const SizedBox(height: 32),
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
              Icon(
                Icons.location_city_rounded,
                color: TwColors.brightGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Branch Overview',
                style: TextStyle(
                  color: TwColors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TwColors.slate700, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedBranchId,
                isExpanded: true,
                dropdownColor: Colors.black,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TwColors.slate800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: TwColors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ),
                style: const TextStyle(
                  color: TwColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: TwColors.brightGreen,
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
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: TwColors.brightGreen,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TwColors.brightGreen, TwColors.lime400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.black,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'SnapVerify',
            style: TextStyle(
              color: TwColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          const _NotificationsBell(),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TwColors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TwColors.slate700, width: 1),
            ),
            child: Icon(icon, color: TwColors.white, size: 22),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: TwColors.red500,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TwColors.slate900, width: 2),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
      style: const TextStyle(
        color: TwColors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
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
          color: TwColors.brightGreen,
          isLive: true,
        ),
        const SizedBox(width: 10),
        _LiveStatCard(
          icon: Icons.warning_amber_rounded,
          value: flagged,
          label: 'Flagged',
          color: TwColors.amber500,
        ),
        const SizedBox(width: 10),
        _LiveStatCard(
          icon: Icons.receipt_long_rounded,
          value: txns,
          label: 'Txns Today',
          color: TwColors.sky500,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (isLive) ...[
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: TwColors.brightGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: TwColors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TwColors.slate700, width: 1),
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
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: TwColors.brightGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: TwColors.brightGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Verified Payments",
                    style: TextStyle(
                      color: TwColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your business · today',
                    style: TextStyle(
                      color: TwColors.brightGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${s.currency} ${s.verifiedAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: TwColors.brightGreen,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${s.total} total transactions processed',
          style: TextStyle(
            color: TwColors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: TwColors.slate800,
            valueColor: const AlwaysStoppedAnimation<Color>(
              TwColors.brightGreen,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PaymentStat(
              label: 'Verified',
              value: '${s.verified}',
              color: TwColors.brightGreen,
            ),
            const SizedBox(width: 24),
            _PaymentStat(
              label: 'Flagged',
              value: '${s.highRisk}',
              color: TwColors.amber500,
            ),
            const SizedBox(width: 24),
            _PaymentStat(
              label: 'Avg Amount',
              value: '${s.currency} ${s.averageAmount.toStringAsFixed(2)}',
              color: TwColors.sky500,
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
        const SizedBox(width: 12),
        Text(
          "Loading today's activity...",
          style: TextStyle(
            color: TwColors.white.withValues(alpha: 0.6),
            fontSize: 13,
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
              color: TwColors.red500,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Could not load today's activity",
                style: TextStyle(
                  color: TwColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                error.toString().replaceFirst('Exception: ', ''),
                style: TextStyle(
                  color: TwColors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: TwColors.brightGreen,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: TwColors.white.withOpacity(0.45),
            fontSize: 11,
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
        TwColors.brightGreen,
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
        TwColors.sky500,
        onTap: () => _navigate(context, 1),
      ),
      if (canManage)
        _ActionItem(
          Icons.people_rounded,
          'Staff',
          TwColors.lime400,
          onTap: () => _push(context, const StaffManagementScreen()),
        ),
      if (canManage)
        _ActionItem(
          Icons.bar_chart_rounded,
          'Reports',
          TwColors.amber500,
          onTap: () => _push(context, const ReportsScreen()),
        ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: TwColors.white.withOpacity(0.25),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}
