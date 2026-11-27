import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/toast_service.dart';
import '../../theme/app_tokens.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'manage/payment_activity_screen.dart';
import '../widgets/sv_loader.dart';
import 'manage/staff_management_screen.dart';

/// Professional notification feed backed by real activity.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTokens.headerBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, asyncData),
            Expanded(
              child: asyncData.when(
                data: (data) => _buildList(context, ref, data),
                loading: () => const Center(child: SvLoader.page()),
                error: (e, _) => _buildError(context, ref, e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NotificationsData> asyncData,
  ) {
    final unread = asyncData.valueOrNull?.unreadCount ?? 0;

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
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: AppTokens.manrope(
                    size: AppTokens.textSubtitle,
                    weight: FontWeight.w700,
                    color: AppTokens.white,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  'Updates from your business',
                  style: AppTokens.dmSans(
                    size: AppTokens.textCaption,
                    weight: FontWeight.w400,
                    color: AppTokens.ice400,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: AppTokens.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTokens.manrope(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w700,
                  color: AppTokens.accent,
                ),
              ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    NotificationsData data,
  ) {
    if (data.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.space2xl),
        children: [
          const SizedBox(height: AppTokens.loaderLargeSize),
          _EmptyState(
            icon: Icons.notifications_none_rounded,
            color: AppTokens.accent,
            title: "You're all caught up",
            subtitle:
                'New payment and staff updates will appear here as they happen.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsProvider);
        try {
          await ref.read(notificationsProvider.future);
        } catch (_) {
          // Surfaced by the error state below.
        }
      },
      color: AppTokens.accent,
      backgroundColor: AppTokens.obsidian900,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceLg,
          AppTokens.spaceLg,
          AppTokens.space2xl,
        ),
        itemCount: data.notifications.length,
        itemBuilder: (context, index) {
          final item = data.notifications[index];
          return _NotificationTile(
            item: item,
            onTap: () => _open(context, item),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTokens.space2xl),
      children: [
        const SizedBox(height: AppTokens.loaderLargeSize),
        _EmptyState(
          icon: Icons.error_outline_rounded,
          color: AppTokens.error,
          title: 'Could not load notifications',
          subtitle: error.toString().replaceFirst('Exception: ', ''),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(notificationsProvider),
        ),
      ],
    );
  }

  void _open(BuildContext context, NotificationItem item) {
    if (item.isPayment) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PaymentActivityScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final token = await ref
        .read(authNotifierProvider.notifier)
        .ensureFreshAccessToken();
    if (token == null) return;

    try {
      await ref
          .read(notificationsDatasourceProvider)
          .markAllRead(accessToken: token);
      ref.invalidate(notificationsProvider);
      ToastService.showSuccess('All notifications marked as read');
    } catch (e) {
      ToastService.showError('Failed to mark as read: $e');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTokens.badgeSmallPaddingH),
        padding: const EdgeInsets.all(AppTokens.badgePaddingH),
        decoration: BoxDecoration(
          color: AppTokens.obsidian950,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: item.isUnread
                ? AppTokens.accent.withValues(alpha: AppTokens.alphaStrong)
                : AppTokens.obsidian700,
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
                color: color.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                _iconFor(item.type),
                color: color,
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.manrope(
                            size: AppTokens.textBodySmall,
                            weight: FontWeight.w600,
                            color: AppTokens.white,
                          ),
                        ),
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(width: AppTokens.spaceSm),
                        Container(
                          width: AppTokens.spaceSm,
                          height: AppTokens.spaceSm,
                          decoration: const BoxDecoration(
                            color: AppTokens.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.dmSans(
                      size: AppTokens.textLabel,
                      weight: FontWeight.w400,
                      color: AppTokens.white.withValues(
                        alpha: AppTokens.alphaTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.statTitleGap),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: AppTokens.textCaption,
                        color: AppTokens.textSecondary,
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(
                        item.timeLabel,
                        style: AppTokens.dmSans(
                          size: AppTokens.textOverline,
                          weight: FontWeight.w400,
                          color: AppTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'payment_verified':
        return Icons.verified_rounded;
      case 'payment_failed':
        return Icons.error_outline_rounded;
      case 'payment_rejected':
        return Icons.block_rounded;
      case 'payment_pending':
        return Icons.schedule_rounded;
      case 'invitation_created':
        return Icons.person_add_alt_1_rounded;
      case 'invitation_revoked':
        return Icons.person_remove_alt_1_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'payment_verified':
        return AppTokens.accent;
      case 'payment_failed':
        return AppTokens.error;
      case 'payment_rejected':
        return AppTokens.warning;
      case 'payment_pending':
        return AppTokens.ice400;
      case 'invitation_created':
        return AppTokens.primary;
      case 'invitation_revoked':
        return AppTokens.error;
      default:
        return AppTokens.primary;
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(
          icon,
          color: AppTokens.white,
          size: AppTokens.checkIconSize,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            textAlign: TextAlign.center,
            style: AppTokens.manrope(
              size: AppTokens.textBodyLarge,
              weight: FontWeight.w600,
              color: AppTokens.white,
            ),
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.spaceLg),
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
