import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/tailwind.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';
import '../widgets/sv_loader.dart';
import '../widgets/sv_status_badge.dart';

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  bool _loading = true;
  String? _error;
  List<_HistoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await ref
        .read(authNotifierProvider.notifier)
        .ensureFreshAccessToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Not authenticated. Please log in again.';
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
      final items = data.map(_HistoryItem.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[HistoryTab] load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: TwColors.brightGreen,
            backgroundColor: TwColors.slate800,
            child: _buildBody(),
          ),
        ),
      ],
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification History',
                  style: TextStyle(
                    color: TwColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Recent payment verification activity',
                  style: TextStyle(color: TwColors.slate400, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? TwColors.slate600 : TwColors.brightGreen,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: SvLoader.page()),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          _StateCard(
            icon: Icons.error_outline_rounded,
            iconColor: TwColors.red500,
            title: 'Could not load history',
            message: _error!,
            actionLabel: 'Try again',
            onAction: _load,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          _StateCard(
            icon: Icons.receipt_long_rounded,
            iconColor: TwColors.brightGreen,
            title: 'No verifications yet',
            message:
                'Verified and failed payment checks will appear here once you start verifying transactions.',
          ),
        ],
      );
    }

    final verified = _items.where((e) => e.isVerified).length;
    final failed = _items.length - verified;
    final total = _items.fold<double>(
      0,
      (sum, e) => sum + (e.isVerified ? e.amount : 0),
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _SummaryRow(
              total: _items.length,
              verified: verified,
              failed: failed,
              verifiedAmount: total,
              currency: _items.first.currency,
            ),
          );
        }
        return _HistoryTile(item: _items[index - 1]);
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int total;
  final int verified;
  final int failed;
  final double verifiedAmount;
  final String currency;

  const _SummaryRow({
    required this.total,
    required this.verified,
    required this.failed,
    required this.verifiedAmount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = NumberFormat.decimalPattern().format(verifiedAmount);
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Verified',
            value: '$verified',
            icon: Icons.check_circle_rounded,
            color: TwColors.brightGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Failed',
            value: '$failed',
            icon: Icons.cancel_rounded,
            color: TwColors.red500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Confirmed',
            value: '$currency $amountText',
            icon: Icons.payments_rounded,
            color: TwColors.sky500,
            compactValue: true,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compactValue;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: TwColors.slate400,
                    fontSize: 12,
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
              color: TwColors.white,
              fontSize: compactValue ? 14 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final amountFmt = NumberFormat('#,##0.##').format(item.amount);
    final methodLabel = item.methodLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isVerified
                  ? TwColors.brightGreen.withValues(alpha: 0.12)
                  : TwColors.red500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isVerified ? Icons.verified_rounded : Icons.error_rounded,
              color: item.isVerified ? TwColors.brightGreen : TwColors.red500,
              size: 22,
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
                        item.primaryTitle,
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
                      text: item.statusLabel,
                      type: item.isVerified
                          ? BadgeType.success
                          : BadgeType.error,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.currency} $amountFmt  ·  $methodLabel',
                  style: const TextStyle(
                    color: TwColors.brightGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.transactionId.isEmpty
                      ? 'No transaction reference'
                      : item.transactionId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TwColors.slate400,
                    fontSize: 12,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TwColors.slate500,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: TwColors.slate500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.timeLabel,
                        style: const TextStyle(
                          color: TwColors.slate500,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.verifiedByName != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'by ${item.verifiedByName}',
                          style: const TextStyle(
                            color: TwColors.slate500,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TwColors.slate400,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: TwColors.brightGreen,
                foregroundColor: TwColors.slate900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryItem {
  final String id;
  final String status;
  final String currency;
  final double amount;
  final String transactionId;
  final String paymentMethod;
  final DateTime? createdAt;
  final String? senderName;
  final String? receiverName;
  final String? verifiedByName;

  const _HistoryItem({
    required this.id,
    required this.status,
    required this.currency,
    required this.amount,
    required this.transactionId,
    required this.paymentMethod,
    required this.createdAt,
    required this.senderName,
    required this.receiverName,
    required this.verifiedByName,
  });

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    final verifiedBy = json['verifiedBy'];
    String? verifiedByName;
    if (verifiedBy is Map) {
      verifiedByName = (verifiedBy['name'] ?? verifiedBy['phone'])?.toString();
    }
    DateTime? createdAt;
    final created = json['createdAt'];
    if (created is String) {
      createdAt = DateTime.tryParse(created)?.toLocal();
    }

    double amount = 0;
    final a = json['amount'];
    if (a is num) {
      amount = a.toDouble();
    } else if (a is String) {
      amount = double.tryParse(a) ?? 0;
    }

    return _HistoryItem(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString().toUpperCase(),
      currency: (json['currency'] ?? 'ETB').toString(),
      amount: amount,
      transactionId: (json['transactionId'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      createdAt: createdAt,
      senderName: json['senderName']?.toString(),
      receiverName: json['receiverName']?.toString(),
      verifiedByName: verifiedByName,
    );
  }

  bool get isVerified => status == 'VERIFIED' || status == 'SUCCESS';

  String get statusLabel {
    switch (status) {
      case 'VERIFIED':
      case 'SUCCESS':
        return 'Verified';
      case 'FAILED':
        return 'Failed';
      case 'REJECTED':
        return 'Rejected';
      case 'PENDING':
        return 'Pending';
      case 'DUPLICATE_TRANSACTION':
        return 'Duplicate';
      default:
        return status.isEmpty ? 'Unknown' : _titleCase(status);
    }
  }

  String get methodLabel {
    switch (paymentMethod.toUpperCase()) {
      case 'IMAGE_OCR':
        return 'Receipt scan';
      case 'REFERENCE':
        return 'Reference';
      case 'MANUAL':
        return 'Manual';
      default:
        return paymentMethod.isEmpty
            ? 'Verification'
            : _titleCase(paymentMethod);
    }
  }

  String get primaryTitle {
    if (senderName != null && senderName!.trim().isNotEmpty) return senderName!;
    if (receiverName != null && receiverName!.trim().isNotEmpty)
      return receiverName!;
    return 'Payment verification';
  }

  String? get subtitle {
    final parts = <String>[];
    if (senderName != null &&
        receiverName != null &&
        senderName != receiverName) {
      parts.add('To: ${receiverName!}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get timeLabel {
    if (createdAt == null) return 'Unknown time';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 24 && createdAt!.day == now.day) {
      return DateFormat('HH:mm').format(createdAt!);
    }
    if (diff.inDays < 7) {
      return DateFormat('EEE, HH:mm').format(createdAt!);
    }
    return DateFormat('MMM d, yyyy · HH:mm').format(createdAt!);
  }

  static String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[_\s]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }
}
