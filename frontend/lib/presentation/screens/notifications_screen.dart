import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/toast_service.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/sv_app_shell.dart';
import '../widgets/sv_loader.dart';
import 'manage/payment_activity_screen.dart';
import 'manage/staff_management_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(notificationsProvider);
    final unread = asyncData.valueOrNull?.unreadCount ?? 0;

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Notifications',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                if (unread > 0)
                  TextButton(
                    onPressed: () => _markAllRead(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppText.labelMedium.copyWith(
                        color: AppTokens.white,
                      ),
                    ),
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            Expanded(
              child: Container(
                color: AppTokens.ice50,
                child: asyncData.when(
                  data: (data) => _buildList(context, ref, data),
                  loading: () => const Center(
                    child: SvLoader.page(color: AppTokens.inkMuted),
                  ),
                  error: (e, _) => _buildError(context, ref, e),
                ),
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceXl,
          AppTokens.spaceLg,
          AppTokens.space3xl,
        ),
        children: [
          const SvSurfaceCard(
            child: SvEmptyState(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              subtitle:
                  'New payment and staff updates will appear here as they happen.',
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsProvider);
        try {
          await ref.read(notificationsProvider.future);
        } catch (_) {}
      },
      color: AppTokens.inkMuted,
      backgroundColor: AppTokens.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceXl,
          AppTokens.spaceLg,
          AppTokens.space3xl,
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
                  _userFriendlyErrorMessage(error),
                  style: AppText.bodySmall.copyWith(color: AppTokens.danger),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(notificationsProvider),
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
                  'Try again',
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

  /// Converts technical exceptions into user-friendly messages. Debug
  /// details are still logged by the caller via `debugPrint` if needed.
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
      ToastService.showError(_userFriendlyErrorMessage(e));
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: SvSurfaceCard(
        onTap: onTap,
        borderColor: AppTokens.ice200,
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _iconFor(item.type),
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelLarge.copyWith(
                            color: AppTokens.ink,
                          ),
                        ),
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(width: AppTokens.spaceSm),
                        const SvStatusPill(
                          'New',
                          tone: SvTone.neutral,
                          small: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall.copyWith(
                      color: AppTokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: AppTokens.componentIconSm,
                        color: AppTokens.inkMuted,
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(
                        item.timeLabel,
                        style: AppText.caption.copyWith(
                          color: AppTokens.inkMuted,
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
}
