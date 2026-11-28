import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/report_summary.dart';

class ReportsException implements Exception {
  final String message;

  const ReportsException(this.message);

  @override
  String toString() => message;
}

class ReportsNetworkException extends ReportsException {
  const ReportsNetworkException(String message) : super(message);
}

class ReportsHttpException extends ReportsException {
  final int statusCode;

  const ReportsHttpException(this.statusCode, super.message);
}

class ReportsRemoteDatasource {
  final http.Client client;

  static const _timeout = Duration(seconds: 30);

  ReportsRemoteDatasource({required this.client});

  Future<ReportSummary> getSummary({
    required String accessToken,
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/reports/summary',
    ).replace(queryParameters: {'from': from, 'to': to});
    debugPrint('[ReportsDS] getSummary → $uri');

    try {
      final response = await client
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(_timeout);

      _throwIfError(response);

      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return ReportSummary.fromJson(decoded);
      } catch (e) {
        debugPrint('[ReportsDS] getSummary parse error: $e');
        throw const ReportsException(
          'Could not read the report response. Please try again.',
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('[ReportsDS] getSummary timeout: $e');
      throw const ReportsNetworkException(
        'The report request timed out. Check your connection and try again.',
      );
    } on http.ClientException catch (e) {
      debugPrint('[ReportsDS] getSummary connection error: $e');
      throw ReportsNetworkException(_connectionMessage(e.message));
    }
  }

  String _connectionMessage(String detail) {
    final text = detail.toLowerCase();
    if (text.contains('connection reset') ||
        text.contains('connection closed')) {
      return 'Connection lost while loading reports. Check your internet connection and try again.';
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return 'The report request timed out. Check your connection and try again.';
    }
    if (text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('no route to host')) {
      return 'Unable to reach the server. Check your internet connection and try again.';
    }
    return 'Could not reach the server. Check your internet connection and try again.';
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final message = _responseMessage(response);
    debugPrint('[ReportsDS] error: $message');
    throw ReportsHttpException(response.statusCode, message);
  }

  String _responseMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Your session expired. Please log in again.';
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      if (msg is List) {
        final joined = msg.join(', ');
        if (joined.isNotEmpty) return joined;
      }
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }
}
