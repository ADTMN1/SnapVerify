import 'dart:async';

import 'package:http/http.dart' as http;

/// Wraps an [http.Client] to automatically retry once on HTTP 401 by
/// refreshing the access token through [onRefresh].
///
/// Multiple concurrent 401 responses share a single refresh because [onRefresh]
/// is expected to be single-flight (e.g. [AuthNotifier.silentRefresh]).
///
/// If the refresh fails or returns null, the original 401 response is returned
/// so the caller can handle session expiry. The request is retried at most once
/// — a second 401 is returned as-is.
class RefreshingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Future<String?> Function() _onRefresh;

  RefreshingHttpClient({
    required http.Client inner,
    required Future<String?> Function() onRefresh,
  })  : _inner = inner,
        _onRefresh = onRefresh;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);

    if (response.statusCode != 401 ||
        request.url.path.endsWith('/auth/refresh-token')) {
      return response;
    }

    String? refreshedToken;
    try {
      refreshedToken = await _onRefresh();
    } catch (_) {
      return response;
    }
    if (refreshedToken == null) return response;

    request.headers['Authorization'] = 'Bearer $refreshedToken';
    try {
      return await _inner.send(request);
    } catch (_) {
      // Request body may already be consumed (e.g. multipart uploads).
      // Return the original 401 so the caller can handle session expiry.
      return response;
    }
  }
}
