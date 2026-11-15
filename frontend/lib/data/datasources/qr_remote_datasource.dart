import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/qr_account.dart';

/// Error raised by the QR API, carrying the HTTP status so callers can react
/// to 401 (refresh the session), 403 (branch scope) and 410 (disabled account).
class QrApiException implements Exception {
  final String message;
  final int statusCode;

  QrApiException(this.message, this.statusCode);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class QrRemoteDatasource {
  final http.Client client;

  static const _timeout = Duration(seconds: 30);

  QrRemoteDatasource({required this.client});

  // ── List QR codes for the caller's business ────────────────────────────────
  Future<List<QrAccountInfo>> listQrAccounts({
    required String accessToken,
    String? branchId,
    String? provider,
    bool? isActive,
    String? search,
  }) async {
    final params = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
      if (isActive != null) 'isActive': isActive.toString(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final uri = Uri.parse(
      '${AppConstants.baseUrl}/qr',
    ).replace(queryParameters: params.isEmpty ? null : params);
    dev.log('[QrDS] listQrAccounts → $uri');

    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    _throwIfError(response);

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>? ?? const []);
      return items
          .whereType<Map>()
          .map((e) => QrAccountInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      dev.log('[QrDS] listQrAccounts parse error: $e');
      throw QrApiException('Could not parse QR response: $e', 0);
    }
  }

  // ── QR information for one payment account ─────────────────────────────────
  Future<QrAccountInfo> getAccountQr({
    required String accessToken,
    required String accountId,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/qr/accounts/$accountId');
    dev.log('[QrDS] getAccountQr → $uri');

    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    _throwIfError(response);

    try {
      return QrAccountInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      dev.log('[QrDS] getAccountQr parse error: $e');
      throw QrApiException('Could not parse QR response: $e', 0);
    }
  }

  // ── Resolve a scanned public identifier ────────────────────────────────────
  Future<QrScanResult> resolveQr({
    required String accessToken,
    required String publicId,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/qr/resolve/$publicId');
    dev.log('[QrDS] resolveQr → $uri');

    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(_timeout);

    _throwIfError(response);

    try {
      return QrScanResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      dev.log('[QrDS] resolveQr parse error: $e');
      throw QrApiException('Could not parse QR response: $e', 0);
    }
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) return;

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['message'];
      message = raw is List
          ? raw.join(', ')
          : (raw?.toString() ?? 'HTTP ${response.statusCode}');
    } catch (_) {
      message = 'HTTP ${response.statusCode}';
    }
    dev.log('[QrDS] error ${response.statusCode}: $message');
    throw QrApiException(message, response.statusCode);
  }
}
