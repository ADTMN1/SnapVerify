import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/notification_item.dart';

class NotificationsRemoteDatasource {
  final http.Client client;

  static const Duration _timeout = Duration(seconds: 30);

  NotificationsRemoteDatasource({http.Client? client})
    : client = client ?? http.Client();

  Future<NotificationsData> getNotifications({
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/notifications');
    debugPrint('[NotificationsDS] getNotifications → $uri');

    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    debugPrint(
      '[NotificationsDS] getNotifications HTTP ${response.statusCode}',
    );
    _throwIfError(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Could not parse notifications response');
    }
    return NotificationsData.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> markAllRead({required String accessToken}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/notifications/read');
    final response = await client
        .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    debugPrint('[NotificationsDS] markAllRead HTTP ${response.statusCode}');
    _throwIfError(response);
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {
      // keep the status-based message
    }
    throw Exception(message);
  }
}
