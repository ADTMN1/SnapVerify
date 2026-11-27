import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_tokens.dart';
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
    } catch (e) {
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
            color: AppTokens.accent,
            backgroundColor: AppTokens.obsidian900,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.obsidian900,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification History',
                  style: AppTokens.manrope(
                    size: AppTokens.textSubtitle,
                    weight: FontWeight.w700,
                    color: AppTokens.white,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  'Recent payment verification activity',
                  style: AppTokens.dmSans(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w400,
                    color: AppTokens.ice400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? AppTokens.inkMuted : AppTokens.accent,
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
          SizedBox(height: AppTokens.loaderLargeSize),
          Center(child: SvLoader.page()),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.space2xl),
        children: [
          const SizedBox(height: AppTokens.loaderLargeSize),
          _StateCard(
            icon: Icons.error_outline_rounded,
            iconColor: AppTokens.error,
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
        padding: const EdgeInsets.all(AppTokens.space2xl),
        children: const [
          SizedBox(height: AppTokens.loaderLargeSize),
          _StateCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AppTokens.accent,
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
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceLg,
        AppTokens.spaceLg,
        AppTokens.spaceLg,
        AppTokens.space2xl,
      ),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceLg),
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
            color: AppTokens.accent,
          ),
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        Expanded(
          child: _MetricCard(
            label: 'Failed',
            value: '$failed',
            icon: Icons.cancel_rounded,
            color: AppTokens.error,
          ),
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        Expanded(
          child: _MetricCard(
            label: 'Confirmed',
            value: '$currency $amountText',
            icon: Icons.payments_rounded,
            color: AppTokens.primary,
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
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppTokens.obsidian700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppTokens.checkIconSize, color: color),
              const SizedBox(width: AppTokens.statTitleGap),
              Expanded(
                child: Text(
                  label,
                  style: AppTokens.dmSans(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w400,
                    color: AppTokens.ice400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.manrope(
              size: compactValue
                  ? AppTokens.textBodySmall
                  : AppTokens.textSubtitle,
              weight: FontWeight.w700,
              color: AppTokens.white,
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
      margin: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      padding: const EdgeInsets.all(AppTokens.badgePaddingH),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppTokens.obsidian700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppTokens.backButtonSize,
            height: AppTokens.backButtonSize,
            decoration: BoxDecoration(
              color: item.isVerified
                  ? AppTokens.accent.withValues(alpha: AppTokens.alphaLow)
                  : AppTokens.error.withValues(alpha: AppTokens.alphaLow),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              item.isVerified ? Icons.verified_rounded : Icons.error_rounded,
              color: item.isVerified ? AppTokens.accent : AppTokens.error,
              size: AppTokens.formPrefixIconSize,
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
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
                        style: AppTokens.manrope(
                          size: AppTokens.textBodySmall,
                          weight: FontWeight.w600,
                          color: AppTokens.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    SVStatusBadge(
                      text: item.statusLabel,
                      type: item.isVerified
                          ? BadgeType.success
                          : BadgeType.error,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  '${item.currency} $amountFmt  ·  $methodLabel',
                  style: AppTokens.manrope(
                    size: AppTokens.textLabel,
                    weight: FontWeight.w600,
                    color: AppTokens.accent,
                  ),
                ),
                const SizedBox(height: AppTokens.statTitleGap),
                Text(
                  item.transactionId.isEmpty
                      ? 'No transaction reference'
                      : item.transactionId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.dmSans(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w400,
                    color: AppTokens.ice400,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.dmSans(
                      size: AppTokens.textCaption,
                      weight: FontWeight.w400,
                      color: AppTokens.ice400,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.statTitleGap),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: AppTokens.componentIconSm,
                      color: AppTokens.textSecondary,
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    Expanded(
                      child: Text(
                        item.timeLabel,
                        style: AppTokens.dmSans(
                          size: AppTokens.textCaption,
                          weight: FontWeight.w400,
                          color: AppTokens.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.verifiedByName != null) ...[
                      const SizedBox(width: AppTokens.spaceSm),
                      Flexible(
                        child: Text(
                          'by ${item.verifiedByName}',
                          style: AppTokens.dmSans(
                            size: AppTokens.textCaption,
                            weight: FontWeight.w400,
                            color: AppTokens.textSecondary,
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
      padding: const EdgeInsets.all(AppTokens.space2xl),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.obsidian700),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: AppTokens.alphaLow),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: AppTokens.optionIconSize),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTokens.manrope(
              size: AppTokens.textBodyLarge,
              weight: FontWeight.w700,
              color: AppTokens.white,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTokens.dmSans(
              size: AppTokens.textBodySmall,
              weight: FontWeight.w400,
              color: AppTokens.ice400,
              height: AppTokens.lineHeightRelaxed,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.statGap),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.accent,
                foregroundColor: AppTokens.obsidian900,
                elevation: AppTokens.cardElevation,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.statCardPadding,
                  vertical: AppTokens.spaceMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              child: Text(
                actionLabel!,
                style: AppTokens.manrope(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w700,
                  color: AppTokens.obsidian900,
                ),
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
      case 'ALREADY_VERIFIED':
      case 'PREVIOUSLY_VERIFIED':
        return 'Previously verified';
      case 'PROVIDER_DUPLICATE':
        return 'Provider duplicate';
      case 'IDENTITY_MISMATCH':
        return 'Details mismatch';
      case 'RECHECK_FAILED':
        return 'Recheck inconclusive';
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
    if (receiverName != null && receiverName!.trim().isNotEmpty) {
      return receiverName!;
    }
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
