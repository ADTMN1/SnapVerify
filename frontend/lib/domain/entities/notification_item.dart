import 'package:intl/intl.dart';

/// A single notification derived from real organization activity.
class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String entityId;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.entityId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          (created is String ? DateTime.tryParse(created) : null)?.toLocal() ??
              DateTime.now(),
      read: json['read'] == true,
      entityId: (json['entityId'] ?? '').toString(),
    );
  }

  bool get isPayment => type.startsWith('payment_');

  bool get isUnread => !read;

  /// Compact relative time, e.g. "Just now", "14:32", "Mon, 09:12",
  /// "Nov 12, 2026 · 14:32".
  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 24 && createdAt.day == now.day) {
      return DateFormat('HH:mm').format(createdAt);
    }
    if (diff.inDays < 7) {
      return DateFormat('EEE, HH:mm').format(createdAt);
    }
    return DateFormat('MMM d, yyyy · HH:mm').format(createdAt);
  }
}

/// Payload returned by `GET /notifications`.
class NotificationsData {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final DateTime? lastReadAt;

  const NotificationsData({
    required this.notifications,
    required this.unreadCount,
    required this.lastReadAt,
  });

  factory NotificationsData.fromJson(Map<String, dynamic> json) {
    final rawList = json['notifications'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <NotificationItem>[];

    final rawLastRead = json['lastReadAt'];
    final lastRead = rawLastRead is String
        ? DateTime.tryParse(rawLastRead)?.toLocal()
        : null;

    return NotificationsData(
      notifications: items,
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount'] as int
          : items.where((n) => n.isUnread).length,
      lastReadAt: lastRead,
    );
  }
}