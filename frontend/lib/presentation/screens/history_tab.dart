import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_tokens.dart';
import '../../ui/ui.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';

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
        _HistoryHeader(loading: _loading, onRefresh: _load),
        Expanded(
          child: _HistorySheet(
            loading: _loading,
            error: _error,
            items: _items,
            onRefresh: _load,
          ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _HistoryHeader({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SvDashboardHeader(
      title: 'Verification History',
      actions: [
        SvDashboardHeaderButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          enabled: !loading,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_HistoryItem> items;
  final Future<void> Function() onRefresh;

  const _HistorySheet({
    required this.loading,
    required this.error,
    required this.items,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.ice50,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTokens.inkMuted,
        backgroundColor: AppTokens.white,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: AppTokens.loaderLargeSize),
          Center(child: SvLoader.page(color: AppTokens.inkMuted)),
        ],
      );
    }

    if (error != null && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.space2xl),
        children: [
          const SizedBox(height: AppTokens.loaderLargeSize),
          _StateCard(
            icon: Icons.error_outline_rounded,
            iconColor: AppTokens.ink,
            title: 'Could not load history',
            message: error!,
            actionLabel: 'Try again',
            onAction: onRefresh,
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.space2xl),
        children: const [
          SizedBox(height: AppTokens.loaderLargeSize),
          _StateCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AppTokens.ink,
            title: 'No verifications yet',
            message:
                'Verified and failed payment checks will appear here once you start verifying transactions.',
          ),
        ],
      );
    }

    final verified = items.where((e) => e.isVerified).length;
    final failed = items.length - verified;
    final total = items.fold<double>(
      0,
      (sum, e) => sum + (e.isVerified ? e.amount : 0),
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.spaceLg,
        AppTokens.sheetHorizontalPadding,
        AppTokens.sheetBottomPadding,
      ),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppTokens.spaceMd),
            child: SvSectionLabel('Verification summary'),
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceLg),
            child: _SummaryRow(
              total: items.length,
              verified: verified,
              failed: failed,
              verifiedAmount: total,
              currency: items.first.currency,
            ),
          );
        }
        return _HistoryTile(item: items[index - 2]);
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
            color: AppTokens.inkMuted,
          ),
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        Expanded(
          child: _MetricCard(
            label: 'Failed',
            value: '$failed',
            icon: Icons.cancel_rounded,
            color: AppTokens.inkMuted,
          ),
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        Expanded(
          child: _MetricCard(
            label: 'Confirmed',
            value: '$currency $amountText',
            icon: Icons.payments_rounded,
            color: AppTokens.inkMuted,
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
        color: AppTokens.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: AppTokens.ice200,
          width: AppTokens.componentBorderWidth,
        ),
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
                    size: AppTokens.textOverline,
                    weight: FontWeight.w700,
                    color: AppTokens.inkMuted,
                    letterSpacing: AppTokens.trackingNormal,
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
            style: AppTokens.poppins(
              size: compactValue
                  ? AppTokens.textBodySmall
                  : AppTokens.textSubtitle,
              weight: FontWeight.w800,
              color: AppTokens.ink,
              letterSpacing: AppTokens.trackingTight,
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
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      decoration: BoxDecoration(
        color: AppTokens.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: AppTokens.ice200,
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isVerified ? Icons.verified_rounded : Icons.error_rounded,
            color: AppTokens.ink,
            size: AppTokens.componentIconLg,
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
                          weight: FontWeight.w800,
                          color: AppTokens.ink,
                          letterSpacing: AppTokens.trackingTight,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    SvStatusPill(
                      item.statusLabel,
                      tone: SvTone.neutral,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  '${item.currency} $amountFmt  ·  $methodLabel',
                  style: AppTokens.manrope(
                    size: AppTokens.textLabel,
                    weight: FontWeight.w700,
                    color: AppTokens.ink,
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
                    color: AppTokens.inkMuted,
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
                      color: AppTokens.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.statTitleGap),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: AppTokens.componentIconSm,
                      color: AppTokens.inkMuted,
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    Expanded(
                      child: Text(
                        item.timeLabel,
                        style: AppTokens.dmSans(
                          size: AppTokens.textCaption,
                          weight: FontWeight.w400,
                          color: AppTokens.inkMuted,
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
                            color: AppTokens.inkMuted,
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
        color: AppTokens.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: AppTokens.ice200,
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            decoration: BoxDecoration(
              color: AppTokens.ice100,
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
              weight: FontWeight.w800,
              color: AppTokens.ink,
              letterSpacing: AppTokens.trackingTight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTokens.dmSans(
              size: AppTokens.textBodySmall,
              weight: FontWeight.w400,
              color: AppTokens.inkMuted,
              height: AppTokens.lineHeightRelaxed,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.statGap),
            SvActionButton(
              label: actionLabel!,
              tone: SvTone.neutral,
              onPressed: onAction,
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
