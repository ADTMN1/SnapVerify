import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../presentation/providers/auth_provider.dart';
import 'profile_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

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

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _selectedBranchId != null
        ? _staff.where((s) => s['branchId'] == _selectedBranchId).toList()
        : _staff;
    final onlineStaff = filteredStaff.where((s) => s['status'] == 'active').length;
    final selectedBranchName = _selectedBranchId != null
        ? _branches.firstWhere((b) => b['id'] == _selectedBranchId, orElse: () => null)
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
                _HeroSection(),
                const SizedBox(height: 24),
                if (_branches.isNotEmpty) _BranchSelector(
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
                _SectionLabel(label: branchName != null ? "Today's Performance ($branchName)" : "Today's Performance"),
                const SizedBox(height: 12),
                const _TodayPaymentsCard(),
                const SizedBox(height: 24),
                const _SectionLabel(label: 'Quick Actions'),
                const SizedBox(height: 12),
                const _QuickActionsGrid(),
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
        color: TwColors.slate800,
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
              border: Border.all(
                color: TwColors.slate700,
                width: 1,
              ),
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
                              color: TwColors.lime400,
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
            child: const Icon(Icons.verified_rounded, color: Colors.black, size: 18),
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
          _TopBarIcon(icon: Icons.notifications_none_rounded, badge: true, onTap: () {}),
          const SizedBox(width: 8),
          _TopBarIcon(
            icon: Icons.person_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, required this.onTap, this.badge = false});

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
          if (badge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: TwColors.brightGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: TwColors.slate900, width: 2),
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

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final statusColor = TwColors.brightGreen;
    final statusLabel = 'System Operational';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1F0A), Color(0xFF050D18)],
        ),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [statusColor.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Snap',
                      style: TextStyle(
                        color: TwColors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    TextSpan(
                      text: 'Verify',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your business verification dashboard.',
                style: TextStyle(
                  color: TwColors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _HeroStat(
                    value: '0',
                    label: 'Verified Today',
                    color: statusColor,
                  ),
                  const SizedBox(width: 24),
                  _HeroStat(
                    value: '0',
                    label: 'Staff Online',
                    color: TwColors.sky500,
                  ),
                  const SizedBox(width: 24),
                  _HeroStat(
                    value: '0',
                    label: 'Active Branches',
                    color: TwColors.lime400,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _HeroStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
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
    );
  }
}

class _LiveStatsRow extends StatelessWidget {
  final int staffOnline;
  final int totalStaff;
  const _LiveStatsRow({required this.staffOnline, required this.totalStaff});

  @override
  Widget build(BuildContext context) {
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
          value: '0',
          label: 'Flagged',
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _LiveStatCard(
          icon: Icons.receipt_long_rounded,
          value: '0',
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

class _TodayPaymentsCard extends StatelessWidget {
  const _TodayPaymentsCard();

  @override
  Widget build(BuildContext context) {
    final scopeLabel = 'Your Business';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: TwColors.brightGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded, color: TwColors.brightGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Verified Payments",
                      style: TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: TwColors.brightGreen.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          scopeLabel,
                          style: TextStyle(
                            color: TwColors.brightGreen.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'ETB 0',
            style: const TextStyle(
              color: TwColors.brightGreen,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '0 total transactions processed',
            style: TextStyle(color: TwColors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 6,
              backgroundColor: TwColors.slate800,
              valueColor: const AlwaysStoppedAnimation<Color>(TwColors.brightGreen),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PaymentStat(label: 'Verified', value: '0', color: TwColors.brightGreen),
              const SizedBox(width: 24),
              _PaymentStat(label: 'Flagged', value: '0', color: Colors.orange),
              const SizedBox(width: 24),
              _PaymentStat(
                label: 'Avg Amount',
                value: 'ETB 0',
                color: TwColors.sky500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PaymentStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: TwColors.white.withOpacity(0.45), fontSize: 11)),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(Icons.qr_code_scanner_rounded, 'Scan QR', TwColors.brightGreen),
      _ActionItem(Icons.receipt_long_rounded, 'Payments', TwColors.sky500),
      _ActionItem(Icons.people_rounded, 'Staff', TwColors.lime400),
      _ActionItem(Icons.bar_chart_rounded, 'Reports', Colors.orange),
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
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  _ActionItem(this.icon, this.label, this.color);
}

class _QuickActionCard extends StatelessWidget {
  final _ActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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
              style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: TwColors.white.withOpacity(0.25), size: 13),
          ],
        ),
      ),
    );
  }
}

