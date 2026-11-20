import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/notifications_remote_datasource.dart';
import '../../domain/entities/notification_item.dart';
import 'auth_provider.dart';

final notificationsDatasourceProvider =
    Provider<NotificationsRemoteDatasource>((ref) {
  return NotificationsRemoteDatasource(client: http.Client());
});

/// Notification feed for the current user.
///
/// Watches the current access token so a cached "not authenticated" error is
/// discarded as soon as a session is restored or the user logs in again.
final notificationsProvider = FutureProvider<NotificationsData>((ref) async {
  ref.watch(
    authNotifierProvider.select((state) => state.tokens?.accessToken),
  );

  final token = await ref
      .read(authNotifierProvider.notifier)
      .ensureFreshAccessToken();

  if (token == null) {
    throw Exception('Not authenticated. Please log in again.');
  }

  return ref
      .read(notificationsDatasourceProvider)
      .getNotifications(accessToken: token);
});

/// Unread notification count for the bell/menu badges.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).valueOrNull?.unreadCount ?? 0;
});