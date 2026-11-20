import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/report_summary.dart';

class ReportsRemoteDatasource {
  final http.Client client;

  static const _timeout = Duration(seconds: 30);

  ReportsRemoteDatasource({required this.client});

  /// Real aggregates for the caller's organization over [from]..[to]
  /// (both `YYYY-MM-DD`, inclusive).
  Future<ReportSummary> getSummary({
    required String accessToken,
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/reports/summary').replace(
      queryParameters: {'from': from, 'to': to},
    );
    debugPrint('[ReportsDS] getSummary → $uri');

    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    _throwIfError(response);

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ReportSummary.fromJson(decoded);
    } catch (e) {
      debugPrint('[ReportsDS] getSummary parse error: $e');
      throw Exception('Could not parse report response: $e');
    }
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      message = msg is List
          ? msg.join(', ')
          : (msg?.toString() ?? 'HTTP ${response.statusCode}');
    } catch (_) {
      message = 'HTTP ${response.statusCode}';
    }
    debugPrint('[ReportsDS] error: $message');
    throw Exception(message);
  }
}