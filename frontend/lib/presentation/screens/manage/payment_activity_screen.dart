import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/sv_loader.dart';
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
    final token = await ref
        .read(authNotifierProvider.notifier)
        .ensureFreshAccessToken();
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
        .where(
          (e) => (e['status']?.toString().toUpperCase() ?? '') == 'VERIFIED',
        )
        .length;
    final totalAmount = _items.fold<double>(0, (sum, e) {
      final status = (e['status']?.toString().toUpperCase() ?? '');
      if (status != 'VERIFIED') return sum;
      final a = e['amount'];
      if (a is num) return sum + a.toDouble();
      if (a is String) return sum + (double.tryParse(a) ?? 0);
      return sum;
    });
    final currency = _items.isNotEmpty
        ? (_items.first['currency']?.toString() ?? 'ETB')
        : 'ETB';

    return Scaffold(
      backgroundColor: AppTokens.headerBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppTokens.accent,
                backgroundColor: AppTokens.obsidian900,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppTokens.backButtonSize,
              height: AppTokens.backButtonSize,
              decoration: BoxDecoration(
                color: AppTokens.obsidian900,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                  color: AppTokens.obsidian700,
                  width: AppTokens.componentBorderWidth,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTokens.white,
                size: AppTokens.backButtonIconSize,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Activity',
                  style: AppTokens.manrope(
                    size: AppTokens.textSubtitle,
                    weight: FontWeight.w600,
                    color: AppTokens.white,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  'Verification results and totals',
                  style: AppText.caption.copyWith(color: AppTokens.ice400),
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
          SizedBox(height: AppTokens.authTopBarHeight),
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
          _emptyState(
            icon: Icons.error_outline_rounded,
            color: AppTokens.error,
            title: 'Failed to load activity',
            subtitle: _error!,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
      ),
      children: [
        _buildStatistics(verifiedCount, totalAmount, currency),
        const SizedBox(height: AppTokens.spaceXl),
        Text(
          'Recent Payments',
          style: AppText.titleSmall.copyWith(color: AppTokens.white),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        if (_items.isEmpty)
          _emptyState(
            icon: Icons.receipt_long_rounded,
            color: AppTokens.accent,
            title: 'No payment activity yet',
            subtitle:
                'Completed verification attempts for this business will appear here.',
          )
        else
          ..._items.map(_buildItem),
      ],
    );
  }

  Widget _buildStatistics(
    int verifiedCount,
    double totalAmount,
    String currency,
  ) {
    final amountText = NumberFormat.decimalPattern().format(totalAmount);
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppTokens.accent,
            label: 'Verified',
            value: '$verifiedCount',
            valueColor: AppTokens.white,
          ),
        ),
        const SizedBox(width: AppTokens.badgeSmallPaddingH),
        Expanded(
          child: _statCard(
            icon: Icons.attach_money_rounded,
            iconColor: AppTokens.primary,
            label: 'Confirmed Amount',
            value: '$currency $amountText',
            valueColor: AppTokens.accent,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.heroStatusPaddingH,
        vertical: AppTokens.spaceMd,
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
                width: AppTokens.loaderPageSize,
                height: AppTokens.loaderPageSize,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: AppTokens.alphaMedium),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: AppTokens.checkIconSize,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  label,
                  style: AppText.labelSmall.copyWith(
                    color: AppTokens.white.withValues(
                      alpha: AppTokens.alphaPrimaryMuted,
                    ),
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
              size: compact ? AppTokens.textBodyLarge : AppTokens.textSubtitle,
              weight: FontWeight.w700,
              color: valueColor,
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
      margin: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      padding: const EdgeInsets.all(AppTokens.heroStatusPaddingH),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: AppTokens.obsidian700,
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppTokens.backButtonSize,
            height: AppTokens.backButtonSize,
            decoration: BoxDecoration(
              color: (isVerified ? AppTokens.accent : AppTokens.error)
                  .withValues(alpha: AppTokens.alphaLow),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: isVerified ? AppTokens.accent : AppTokens.error,
              size: AppTokens.componentIconMd,
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.manrope(
                          size: AppTokens.textBody,
                          weight: FontWeight.w600,
                          color: AppTokens.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    SVStatusBadge(
                      text: isVerified
                          ? 'Verified'
                          : (status.isEmpty ? 'Failed' : status),
                      type: isVerified ? BadgeType.success : BadgeType.error,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  '$currency $amountText  ·  $methodLabel',
                  style: AppText.labelMedium.copyWith(color: AppTokens.accent),
                ),
                if (tx.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    tx,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: AppTokens.ice400),
                  ),
                ],
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  byName != null ? '$timeLabel  ·  by $byName' : timeLabel,
                  style: AppText.caption.copyWith(
                    color: AppTokens.textSecondary,
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space3xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            decoration: BoxDecoration(
              color: color.withValues(alpha: AppTokens.alphaLow),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: AppTokens.heroIndicatorActiveWidth,
            ),
          ),
          const SizedBox(height: AppTokens.badgePaddingH),
          Text(
            title,
            style: AppText.titleSmall.copyWith(color: AppTokens.white),
          ),
          const SizedBox(height: AppTokens.statTitleGap),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTokens.dmSans(
              size: AppTokens.textLabel,
              weight: FontWeight.w400,
              color: AppTokens.ice400,
              height: AppTokens.lineHeightRelaxed,
            ),
          ),
        ],
      ),
    );
  }
}
