import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/payment_account.dart';

class PaymentRemoteDatasource {
  final http.Client client;

  // Must be > backend timeout (90s) + network margin
  static const _timeout = Duration(seconds: 100);

  PaymentRemoteDatasource({required this.client});

  // ── Compress before sending — smaller = faster OCR ───────────────────────
  Future<Uint8List> _compress(Uint8List bytes) async {
    dev.log('[PaymentDS] original size: ${bytes.length} bytes');
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 600,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    dev.log('[PaymentDS] compressed size: ${compressed.length} bytes '
        '(${((1 - compressed.length / bytes.length) * 100).toStringAsFixed(0)}% smaller)');
    return Uint8List.fromList(compressed);
  }

  // ── Verify by captured image ──────────────────────────────────────────────
  Future<VerificationResult> verifyByImage({
    required String accessToken,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payments/verify-image');

    dev.log('[PaymentDS] verifyByImage → $uri');

    // Compress first
    final compressed = await _compress(imageBytes);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        compressed,
        filename: 'capture.jpg',
      ));

    http.Response response;
    try {
      final streamed = await request.send().timeout(
        _timeout,
        onTimeout: () => throw Exception(
          'Timed out after ${_timeout.inSeconds}s — '
          'verify.leul.et OCR is taking too long. Please try again.',
        ),
      );
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      dev.log('[PaymentDS] verifyByImage network/timeout error: $e');
      rethrow;
    }

    dev.log('[PaymentDS] verifyByImage HTTP ${response.statusCode}');
    dev.log('[PaymentDS] verifyByImage body: ${response.body}');

    _throwIfError(response);

    try {
      return VerificationResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      dev.log('[PaymentDS] parse error: $e  body=${response.body}');
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
    dev.log('[PaymentDS] verifyByReference → $uri ref=$referenceNumber');

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
      dev.log('[PaymentDS] verifyByReference error: $e');
      rethrow;
    }

    dev.log('[PaymentDS] verifyByReference HTTP ${response.statusCode}');
    dev.log('[PaymentDS] verifyByReference body: ${response.body}');

    _throwIfError(response);

    try {
      return VerificationResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Could not parse response: $e');
    }
  }

  // ── Payment Account Methods ────────────────────────────────────────────────
  Future<List<PaymentAccount>> getPaymentAccounts({
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts');
    dev.log('[PaymentDS] getPaymentAccounts → $uri');

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
      dev.log('[PaymentDS] getPaymentAccounts parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<PaymentAccount> createPaymentAccount({
    required String accessToken,
    required String provider,
    String? accountNumber,
    String? suffix,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts');
    dev.log('[PaymentDS] createPaymentAccount → $uri');

    final response = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'provider': provider,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (suffix != null) 'suffix': suffix,
      }),
    ).timeout(_timeout);

    _throwIfError(response);

    try {
      return PaymentAccount.fromJson(jsonDecode(response.body));
    } catch (e) {
      dev.log('[PaymentDS] createPaymentAccount parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<PaymentAccount> updatePaymentAccount({
    required String accessToken,
    required String provider,
    String? accountNumber,
    String? suffix,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts/$provider');
    dev.log('[PaymentDS] updatePaymentAccount → $uri');

    final response = await client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (suffix != null) 'suffix': suffix,
      }),
    ).timeout(_timeout);

    _throwIfError(response);

    try {
      return PaymentAccount.fromJson(jsonDecode(response.body));
    } catch (e) {
      dev.log('[PaymentDS] updatePaymentAccount parse error: $e');
      throw Exception('Could not parse response: $e');
    }
  }

  Future<void> deletePaymentAccount({
    required String accessToken,
    required String provider,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/payment-accounts/$provider');
    dev.log('[PaymentDS] deletePaymentAccount → $uri');

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
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      errorMsg = msg is List
          ? msg.join(', ')
          : (msg?.toString() ?? 'HTTP ${response.statusCode}');
    } catch (_) {
      errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
    }
    dev.log('[PaymentDS] error: $errorMsg');
    throw Exception(errorMsg);
  }
}
