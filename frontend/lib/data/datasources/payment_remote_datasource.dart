import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/ocr_parser.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/payment_account.dart';

class PaymentRemoteDatasource {
  final http.Client client;

  // The backend retries a slow provider up to 3 times, so its worst-case
  // response time is 3 × CHECK_ET_TIMEOUT_MS + backoff (~138s at the 45s
  // default, ~363s at the 120s maximum). The client must stay above that
  // worst case or it gives up while the backend is still legitimately working.
  //
  // Override when raising the backend timeout, e.g.:
  //   --dart-define=VERIFY_TIMEOUT_SECONDS=370
  static final Duration _timeout = Duration(seconds: _verifyTimeoutSeconds);

  static int get _verifyTimeoutSeconds {
    const fallback = 150;
    final parsed = int.tryParse(
      const String.fromEnvironment('VERIFY_TIMEOUT_SECONDS', defaultValue: ''),
    );
    if (parsed == null) return fallback;
    return parsed.clamp(30, 600);
  }

  PaymentRemoteDatasource({required this.client});

  // ── Compress before sending — smaller = faster OCR ───────────────────────
  Future<Uint8List> _compress(Uint8List bytes) async {
    debugPrint('[PaymentDS] original size: ${bytes.length} bytes');
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 600,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    debugPrint('[PaymentDS] compressed size: ${compressed.length} bytes '
        '(${((1 - compressed.length / bytes.length) * 100).toStringAsFixed(0)}% smaller)');
    return Uint8List.fromList(compressed);
  }

  // ── Verify by captured image ──────────────────────────────────────────────
  /// [ocrText] is required by the backend for image receipts (the provider
  /// verifies images against on-device OCR text; PDFs are parsed server-side).
  Future<VerificationResult> verifyByImage({
    required String accessToken,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? ocrText,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payments/verify-image');

    debugPrint('[PaymentDS] verifyByImage → $uri');

    // Compress first
    final compressed = await _compress(imageBytes);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        compressed,
        filename: 'capture.jpg',
      ));
    if (ocrText != null && ocrText.trim().isNotEmpty) {
      request.fields['receiptText'] = ocrText;
    }

    http.Response response;
    try {
      final streamed = await request.send().timeout(
        _timeout,
        onTimeout: () => throw Exception(
          'Timed out after ${_timeout.inSeconds}s — '
          'receipt verification is taking too long. Please try again.',
        ),
      );
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      debugPrint('[PaymentDS] verifyByImage network/timeout error: $e');
      rethrow;
    }

    debugPrint('[PaymentDS] verifyByImage HTTP ${response.statusCode}');

    _throwIfError(response);

    try {
      return VerificationResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PaymentDS] verifyByImage parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  // ── Verify by reference number ────────────────────────────────────────────
  Future<VerificationResult> verifyByReference({
    required String accessToken,
    required String referenceNumber,
    double? amount,
    String? provider,
    String? suffix,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payments/verify');
    debugPrint('[PaymentDS] verifyByReference → $uri '
        'ref=${OcrParser.maskReference(referenceNumber)}'
        '${provider != null ? ' provider=$provider' : ''}');

    http.Response response;
    try {
      response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'referenceNumber': referenceNumber,
          if (amount != null) 'amount': amount,
          if (provider != null) 'provider': provider,
          if (suffix != null) 'suffix': suffix,
        }),
      ).timeout(
        _timeout,
        onTimeout: () => throw Exception(
            'Timed out after ${_timeout.inSeconds}s. Please try again.'),
      );
    } catch (e) {
      debugPrint('[PaymentDS] verifyByReference error: $e');
      rethrow;
    }

    debugPrint('[PaymentDS] verifyByReference HTTP ${response.statusCode}');

    _throwIfError(response);

    try {
      return VerificationResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PaymentDS] verifyByReference parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  // ── Verification history ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVerificationHistory({
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payments/history');
    debugPrint('[PaymentDS] getVerificationHistory → $uri');

    final response = await client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(_timeout);

    debugPrint('[PaymentDS] getVerificationHistory HTTP ${response.statusCode}');
    _throwIfError(response);

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[PaymentDS] getVerificationHistory parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  // ── Payment Account Methods ────────────────────────────────────────────────
  Future<List<PaymentAccount>> getPaymentAccounts({
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts');
    debugPrint('[PaymentDS] getPaymentAccounts → $uri');

    final response = await client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(_timeout);

    _throwIfError(response);

    try {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => PaymentAccount.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[PaymentDS] getPaymentAccounts parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<PaymentAccount> createPaymentAccount({
    required String accessToken,
    required String provider,
    String? accountNumber,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts');
    debugPrint('[PaymentDS] createPaymentAccount → $uri');

    final response = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'provider': provider,
        if (accountNumber != null) 'accountNumber': accountNumber,
      }),
    ).timeout(_timeout);

    _throwIfError(response);

    try {
      return PaymentAccount.fromJson(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[PaymentDS] createPaymentAccount parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<PaymentAccount> updatePaymentAccount({
    required String accessToken,
    required String provider,
    String? accountNumber,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts/$provider');
    debugPrint('[PaymentDS] updatePaymentAccount → $uri');

    final response = await client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (accountNumber != null) 'accountNumber': accountNumber,
      }),
    ).timeout(_timeout);

    _throwIfError(response);

    try {
      return PaymentAccount.fromJson(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[PaymentDS] updatePaymentAccount parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<void> deletePaymentAccount({
    required String accessToken,
    required String provider,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts/$provider');
    debugPrint('[PaymentDS] deletePaymentAccount → $uri');

    final response = await client.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(_timeout);

    _throwIfError(response);
  }

  // ── Extract error message from NestJS error shape ─────────────────────────
  void _throwIfError(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) return;

    String errorMsg;
    String? statusCode;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      statusCode = (body['status'] as String?)?.toUpperCase();
      final msg = body['message'];
      errorMsg = msg is List
          ? msg.join(', ')
          : (msg?.toString() ?? 'HTTP ${response.statusCode}');
    } catch (_) {
      errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
    }
    debugPrint('[PaymentDS] error: $errorMsg');

    // Provider detection/configuration errors are never "invalid receipt".
    if (statusCode == 'PAYMENT_PROVIDER_UNDETECTED' ||
        statusCode == 'UNSUPPORTED_PAYMENT_PROVIDER' ||
        statusCode == 'PAYMENT_ACCOUNT_NOT_CONFIGURED') {
      throw Exception(
        errorMsg.isEmpty
            ? 'Unable to verify this payment. Please check the receipt and try again.'
            : errorMsg,
      );
    }

    // Provider outages/connectivity failures must never be presented to users
    // as an invalid receipt or invalid transaction.
    if (response.statusCode == 503 ||
        statusCode == 'PROVIDER_UNAVAILABLE' ||
        statusCode == 'SERVICE_UNAVAILABLE') {
      throw Exception(
        'Verification service is temporarily unavailable. Please try again in a few minutes.',
      );
    }
    if (statusCode == 'QUOTA_EXHAUSTED') {
      throw Exception(
        'Verification quota exhausted. Please contact your administrator.',
      );
    }
    if (statusCode == 'PROVIDER_CONFIG_ERROR') {
      throw Exception(
        'Payment verification is temporarily misconfigured. Please contact your administrator.',
      );
    }

    throw Exception(errorMsg);
  }
}
