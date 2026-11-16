import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tailwind.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/sv_status_badge.dart';

class PaymentActivityScreen extends ConsumerStatefulWidget {
  const PaymentActivityScreen({super.key});

  @override
  ConsumerState<PaymentActivityScreen> createState() =>
      _PaymentActivityScreenState();
}

class _PaymentActivityScreenState extends ConsumerState<PaymentActivityScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await ref.read(authNotifierProvider.notifier).ensureFreshAccessToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = ref.read(paymentDatasourceProvider);
      final data = await ds.getVerificationHistory(accessToken: token);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[PaymentActivityScreen] load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifiedCount = _items
        .where((e) => (e['status']?.toString().toUpperCase() ?? '') == 'VERIFIED')
        .length;
    final totalAmount = _items.fold<double>(0, (sum, e) {
      final status = (e['status']?.toString().toUpperCase() ?? '');
      if (status != 'VERIFIED') return sum;
      final a = e['amount'];
      if (a is num) return sum + a.toDouble();
      if (a is String) return sum + (double.tryParse(a) ?? 0);
      return sum;
    });
    final currency =
        _items.isNotEmpty ? (_items.first['currency']?.toString() ?? 'ETB') : 'ETB';

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: TwColors.brightGreen,
                backgroundColor: TwColors.slate800,
                child: _buildBody(verifiedCount, totalAmount, currency),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: TwColors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Activity',
                  style: TextStyle(
                    color: TwColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Verification results and totals',
                  style: TextStyle(color: TwColors.slate400, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh_rounded,
                color: _loading ? TwColors.slate600 : TwColors.brightGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int verifiedCount, double totalAmount, String currency) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: TwColors.brightGreen)),
        ],
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          _emptyState(
            icon: Icons.error_outline_rounded,
            color: TwColors.red500,
            title: 'Failed to load activity',
            subtitle: _error!,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildStatistics(verifiedCount, totalAmount, currency),
        const SizedBox(height: 20),
        const Text(
          'Recent Payments',
          style: TextStyle(
            color: TwColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.receipt_long_rounded,
            color: TwColors.brightGreen,
            title: 'No payment activity yet',
            subtitle:
                'Completed verification attempts for this business will appear here.',
          )
        else
          ..._items.map(_buildItem),
      ],
    );
  }

  Widget _buildStatistics(int verifiedCount, double totalAmount, String currency) {
    final amountText = NumberFormat.decimalPattern().format(totalAmount);
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: TwColors.brightGreen,
            label: 'Verified',
            value: '$verifiedCount',
            valueColor: TwColors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.attach_money_rounded,
            iconColor: TwColors.sky500,
            label: 'Confirmed Amount',
            value: '$currency $amountText',
            valueColor: TwColors.brightGreen,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: TwColors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final status = (item['status']?.toString().toUpperCase() ?? '');
    final isVerified = status == 'VERIFIED';
    final amount = item['amount'];
    final amountNum = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0;
    final amountText = NumberFormat('#,##0.##').format(amountNum);
    final currency = item['currency']?.toString() ?? 'ETB';
    final tx = item['transactionId']?.toString() ?? '';
    final method = item['paymentMethod']?.toString() ?? '';
    final methodLabel = method == 'IMAGE_OCR'
        ? 'Receipt scan'
        : method == 'REFERENCE'
            ? 'Reference'
            : method.isEmpty
                ? 'Verification'
                : method;

    DateTime? createdAt;
    final c = item['createdAt'];
    if (c is String) createdAt = DateTime.tryParse(c)?.toLocal();
    final timeLabel = createdAt == null
        ? 'Unknown time'
        : DateFormat('MMM d, yyyy · HH:mm').format(createdAt);

    final verifiedBy = item['verifiedBy'];
    String? byName;
    if (verifiedBy is Map) {
      byName = (verifiedBy['name'] ?? verifiedBy['phone'])?.toString();
    }

    final sender = item['senderName']?.toString();
    final title = (sender != null && sender.trim().isNotEmpty)
        ? sender
        : 'Payment verification';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isVerified ? TwColors.brightGreen : TwColors.red500)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: isVerified ? TwColors.brightGreen : TwColors.red500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TwColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SVStatusBadge(
                      text: isVerified ? 'Verified' : (status.isEmpty ? 'Failed' : status),
                      type: isVerified ? BadgeType.success : BadgeType.error,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency $amountText  ·  $methodLabel',
                  style: const TextStyle(
                    color: TwColors.brightGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tx.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tx,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: TwColors.slate400, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  byName != null ? '$timeLabel  ·  by $byName' : timeLabel,
                  style: const TextStyle(color: TwColors.slate500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: TwColors.slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
