import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/ui.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/sv_app_shell.dart';
import '../../widgets/sv_loader.dart';

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
    } catch (e) {
      debugPrint('[PaymentActivityScreen] load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _userFriendlyErrorMessage(e);
      });
    }
  }

  /// Converts technical exceptions into user-friendly messages. Debug
  /// details are still logged via `debugPrint` above.
  String _userFriendlyErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('session has expired') ||
        message.contains('401') ||
        message.contains('Unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }
    if (message.contains('connection') ||
        message.contains('network') ||
        message.contains('SocketException')) {
      return 'Unable to connect. Check your internet and try again.';
    }
    if (message.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    if (message.contains('404') || message.contains('not found')) {
      return 'The requested item was not found.';
    }
    return 'Something went wrong. Please try again.';
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
      backgroundColor: AppTokens.ice50,
      body: Column(
        children: [
          _PaymentActivityHeader(loading: _loading, onRefresh: _load),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppTokens.inkMuted,
              backgroundColor: AppTokens.white,
              child: _buildBody(verifiedCount, totalAmount, currency),
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
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.space3xl),
            child: Center(child: SvLoader.page(color: AppTokens.inkMuted)),
          ),
        ],
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceXl,
          AppTokens.spaceLg,
          AppTokens.space3xl,
        ),
        children: [
          SvSurfaceCard(
            color: AppTokens.dangerBg,
            borderColor: AppTokens.danger,
            padding: const EdgeInsets.all(AppTokens.errorPadding),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTokens.ink,
                  size: AppTokens.componentIconMd,
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    _error!,
                    style: AppText.bodySmall.copyWith(color: AppTokens.danger),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.errorStrong,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppText.labelLarge,
                  ),
                  child: Text(
                    'Retry',
                    style: AppText.labelLarge.copyWith(
                      color: AppTokens.errorStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.spaceLg,
        AppTokens.sheetHorizontalPadding,
        AppTokens.sheetBottomPadding,
      ),
      children: [
        _buildStatistics(verifiedCount, totalAmount, currency),
        const SizedBox(height: AppTokens.spaceXl),
        const SvSectionLabel('Recent Payments'),
        const SizedBox(height: AppTokens.spaceMd),
        if (_items.isEmpty)
          const SvSurfaceCard(
            child: SvEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No payment activity yet',
              subtitle:
                  'Completed verification attempts for this business will appear here.',
            ),
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
        _statCard(
          icon: Icons.check_circle_outline_rounded,
          label: 'Verified',
          value: '$verifiedCount',
          valueColor: AppTokens.accent,
        ),
        const SizedBox(width: AppTokens.spaceMd),
        _statCard(
          icon: Icons.attach_money_rounded,
          label: 'Confirmed Amount',
          value: '$currency $amountText',
          valueColor: AppTokens.ink,
          compact: true,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool compact = false,
  }) {
    return Expanded(
      child: SvSurfaceCard(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppTokens.inkMuted,
              size: AppTokens.componentIconMd,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppTokens.inkMuted),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? AppText.titleSmall : AppText.titleMedium)
                  .copyWith(color: valueColor),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: SvSurfaceCard(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: AppTokens.inkMuted,
              size: AppTokens.componentIconMd,
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
                          style: AppText.labelLarge.copyWith(
                            color: AppTokens.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceSm),
                      SvStatusPill(
                        isVerified
                            ? 'Verified'
                            : (status.isEmpty ? 'Failed' : status),
                        tone: isVerified ? SvTone.success : SvTone.error,
                        small: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    '$currency $amountText  ·  $methodLabel',
                    style: AppText.labelMedium.copyWith(color: AppTokens.ink),
                  ),
                  if (tx.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.spaceXs),
                    Text(
                      tx,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: AppTokens.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    byName != null ? '$timeLabel  ·  by $byName' : timeLabel,
                    style: AppText.caption.copyWith(color: AppTokens.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentActivityHeader extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onRefresh;

  const _PaymentActivityHeader({
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SvDashboardHeader(
      title: 'Payment Activity',
      titleSize: AppTokens.textSubtitle,
      onBack: () => Navigator.of(context).pop(),
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
