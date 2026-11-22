import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/subscription_checkout.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription.dart';
import 'auth_remote_datasource.dart';

class SubscriptionRemoteDatasource {
  final http.Client client;

  SubscriptionRemoteDatasource({required this.client});

  static const Duration _timeout = Duration(seconds: 150);

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Future<dynamic> _request(
    String method,
    String path,
    String accessToken, {
    Object? body,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    late final http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await client
              .post(uri, headers: _headers(accessToken), body: jsonEncode(body))
              .timeout(_timeout);
          break;
        default:
          response = await client
              .get(uri, headers: _headers(accessToken))
              .timeout(_timeout);
      }
    } catch (e) {
      throw ApiException('Could not reach the server. Check your connection.');
    }

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(decoded, response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<List<SubscriptionPlan>> getPlans(String accessToken) async {
    final data = await _request('GET', '/subscriptions/plans', accessToken);
    final list = (data as List<dynamic>?) ?? const <dynamic>[];
    return list
        .map((item) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Subscription> activateFree(String accessToken) async {
    final data = await _request(
      'POST',
      '/subscriptions/activate-free',
      accessToken,
      body: const {},
    );
    return Subscription.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SubscriptionCheckout> createCheckout(
    String accessToken,
    String planId,
  ) async {
    final data = await _request(
      'POST',
      '/subscriptions/checkout',
      accessToken,
      body: {'planId': planId},
    );
    return SubscriptionCheckout.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SubscriptionCheckout> getCheckout(
    String accessToken,
    String checkoutId,
  ) async {
    final data = await _request(
      'GET',
      '/subscriptions/checkout/$checkoutId',
      accessToken,
    );
    return SubscriptionCheckout.fromJson(Map<String, dynamic>.from(data));
  }

  Future<bool> verifyCheckout(
    String accessToken,
    String checkoutId,
    String referenceNumber,
  ) async {
    await _request(
      'POST',
      '/subscriptions/checkout/$checkoutId/verify',
      accessToken,
      body: {'referenceNumber': referenceNumber.trim()},
    );
    return true;
  }

  String _errorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join(', ');
      }
    }
    return 'Request failed ($statusCode)';
  }
}
