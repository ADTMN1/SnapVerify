import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tailwind.dart';
import '../../core/utils/toast_service.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'manage/payment_activity_screen.dart';
import 'manage/staff_management_screen.dart';

/// Professional notification feed backed by real activity.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, asyncData),
            Expanded(
              child: asyncData.when(
                data: (data) => _buildList(context, ref, data),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: TwColors.brightGreen,
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TwColors.slate800, width: 1),
        ),
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: TwColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Updates from your business',
                  style: TextStyle(
                    color: TwColors.slate400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: TwColors.brightGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          _EmptyState(
            icon: Icons.notifications_none_rounded,
            color: TwColors.brightGreen,
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
      color: TwColors.brightGreen,
      backgroundColor: TwColors.slate800,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        _EmptyState(
          icon: Icons.error_outline_rounded,
          color: TwColors.red500,
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentActivityScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StaffManagementScreen()),
      );
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isUnread
                ? TwColors.brightGreen.withValues(alpha: 0.35)
                : TwColors.slate700,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(item.type), color: color, size: 22),
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TwColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: TwColors.brightGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TwColors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: TwColors.slate500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.timeLabel,
                        style: const TextStyle(
                          color: TwColors.slate500,
                          fontSize: 11,
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
        return TwColors.brightGreen;
      case 'payment_failed':
        return TwColors.red500;
      case 'payment_rejected':
        return TwColors.amber500;
      case 'payment_pending':
        return TwColors.slate400;
      case 'invitation_created':
        return TwColors.sky500;
      case 'invitation_revoked':
        return TwColors.red500;
      default:
        return TwColors.sky500;
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: TwColors.slate800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Icon(icon, color: TwColors.white, size: 18),
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
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
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
            style: const TextStyle(
              color: TwColors.slate400,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: TwColors.brightGreen,
                foregroundColor: TwColors.slate900,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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