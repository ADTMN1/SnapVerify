import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/payment_remote_datasource.dart';
import '../../domain/entities/verification_result.dart';
import 'auth_provider.dart';

final paymentDatasourceProvider = Provider<PaymentRemoteDatasource>((ref) {
  return PaymentRemoteDatasource(client: http.Client());
});

// ── State ─────────────────────────────────────────────────────────────────────
enum PaymentVerifyStatus { idle, loading, success, error }

class PaymentState {
  final PaymentVerifyStatus status;
  final VerificationResult? result;
  final String? errorMessage;

  const PaymentState({
    this.status = PaymentVerifyStatus.idle,
    this.result,
    this.errorMessage,
  });

  PaymentState copyWith({
    PaymentVerifyStatus? status,
    VerificationResult? result,
    String? errorMessage,
  }) {
    return PaymentState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref ref;

  PaymentNotifier(this.ref) : super(const PaymentState());

  String? _getToken() => ref.read(authNotifierProvider).tokens?.accessToken;

  /// Refresh the access token silently, returns the new token.
  /// Throws (and sets error state) if the refresh token is also expired.
  Future<String?> _refreshToken() async {
    dev.log('[PaymentProvider] access token expired — refreshing');
    try {
      final newTokens =
          await ref.read(authNotifierProvider.notifier).silentRefresh();
      dev.log('[PaymentProvider] token refreshed successfully');
      return newTokens?.accessToken;
    } catch (e) {
      dev.log('[PaymentProvider] token refresh failed: $e');
      state = state.copyWith(
        status: PaymentVerifyStatus.error,
        errorMessage: 'Session expired — please log in again',
      );
      return null;
    }
  }

  bool _is401(Object e) {
    final msg = e.toString();
    return msg.contains('401') ||
        msg.contains('Invalid or expired token') ||
        msg.contains('Unauthorized');
  }

  /// Verify from captured image bytes
  Future<void> verifyImage(Uint8List imageBytes) async {
    var token = _getToken();
    dev.log(
        '[PaymentProvider] verifyImage token=${token != null ? "present" : "MISSING"}');

    if (token == null) {
      state = state.copyWith(
        status: PaymentVerifyStatus.error,
        errorMessage: 'Not authenticated — please log in again',
      );
      return;
    }

    state = state.copyWith(status: PaymentVerifyStatus.loading);
    dev.log(
        '[PaymentProvider] verifyImage → calling datasource (${imageBytes.length} bytes)');

    try {
      final ds = ref.read(paymentDatasourceProvider);

      VerificationResult result;
      try {
        result = await ds.verifyByImage(
          accessToken: token,
          imageBytes: imageBytes,
        );
      } catch (e) {
        // On 401, refresh token once and retry
        if (_is401(e)) {
          dev.log('[PaymentProvider] verifyImage got 401 — refreshing token and retrying');
          token = await _refreshToken();
          if (token == null) return; // refresh failed, error state already set
          result = await ds.verifyByImage(
            accessToken: token,
            imageBytes: imageBytes,
          );
        } else {
          rethrow;
        }
      }

      dev.log('[PaymentProvider] verifyImage success verified=${result.verified}');
      state = state.copyWith(
        status: PaymentVerifyStatus.success,
        result: result,
      );
    } catch (e, st) {
      dev.log('[PaymentProvider] verifyImage error: $e', stackTrace: st);
      state = state.copyWith(
        status: PaymentVerifyStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Verify from reference number
  Future<void> verifyReference(String referenceNumber,
      {double? amount, String? provider, String? suffix}) async {
    var token = _getToken();
    dev.log(
        '[PaymentProvider] verifyReference ref=$referenceNumber provider=$provider suffix=$suffix token=${token != null ? "present" : "MISSING"}');

    if (token == null) {
      state = state.copyWith(
        status: PaymentVerifyStatus.error,
        errorMessage: 'Not authenticated — please log in again',
      );
      return;
    }

    state = state.copyWith(status: PaymentVerifyStatus.loading);

    try {
      final ds = ref.read(paymentDatasourceProvider);

      VerificationResult result;
      try {
        result = await ds.verifyByReference(
          accessToken: token,
          referenceNumber: referenceNumber,
          amount: amount,
          provider: provider,
          suffix: suffix,
        );
      } catch (e) {
        // On 401, refresh token once and retry
        if (_is401(e)) {
          dev.log('[PaymentProvider] verifyReference got 401 — refreshing token and retrying');
          token = await _refreshToken();
          if (token == null) return; // refresh failed, error state already set
          result = await ds.verifyByReference(
            accessToken: token,
            referenceNumber: referenceNumber,
            amount: amount,
            provider: provider,
            suffix: suffix,
          );
        } else {
          rethrow;
        }
      }

      dev.log(
          '[PaymentProvider] verifyReference success verified=${result.verified}');
      state = state.copyWith(
        status: PaymentVerifyStatus.success,
        result: result,
      );
    } catch (e, st) {
      dev.log('[PaymentProvider] verifyReference error: $e', stackTrace: st);
      state = state.copyWith(
        status: PaymentVerifyStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void reset() => state = const PaymentState();
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});
