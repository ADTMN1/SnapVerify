import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/qr_remote_datasource.dart';
import '../../domain/entities/qr_account.dart';
import 'auth_provider.dart';

final qrDatasourceProvider = Provider<QrRemoteDatasource>((ref) {
  return QrRemoteDatasource(client: http.Client());
});

/// Authenticated facade over the QR API.
///
/// Every call uses the access token from the current auth state and silently
/// refreshes it once on a 401, so QR screens never have to manage tokens.
class QrApi {
  final Ref _ref;

  QrApi(this._ref);

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    var token = _ref.read(authNotifierProvider).tokens?.accessToken;
    if (token == null) {
      throw QrApiException('Not authenticated — please log in again', 401);
    }

    try {
      return await action(token);
    } on QrApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      final refreshed = await _ref
          .read(authNotifierProvider.notifier)
          .silentRefresh();
      if (refreshed == null) rethrow;
      return action(refreshed.accessToken);
    }
  }

  Future<List<QrAccountInfo>> list({
    String? branchId,
    String? provider,
    bool? isActive,
    String? search,
  }) {
    return _withAuth(
      (token) => _ref
          .read(qrDatasourceProvider)
          .listQrAccounts(
            accessToken: token,
            branchId: branchId,
            provider: provider,
            isActive: isActive,
            search: search,
          ),
    );
  }

  Future<QrAccountInfo> accountQr(String accountId) {
    return _withAuth(
      (token) => _ref
          .read(qrDatasourceProvider)
          .getAccountQr(accessToken: token, accountId: accountId),
    );
  }

  Future<QrScanResult> resolve(String publicId) {
    return _withAuth(
      (token) => _ref
          .read(qrDatasourceProvider)
          .resolveQr(accessToken: token, publicId: publicId),
    );
  }
}

final qrApiProvider = Provider<QrApi>((ref) => QrApi(ref));
