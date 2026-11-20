import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/reports_remote_datasource.dart';
import '../../domain/entities/report_summary.dart';
import 'auth_provider.dart';

final reportsDatasourceProvider = Provider<ReportsRemoteDatasource>((ref) {
  return ReportsRemoteDatasource(client: http.Client());
});

/// Real report summary for a date range, authenticated with a fresh token.
///
/// Watches the current access token so a cached "not authenticated" error is
/// discarded as soon as a session is restored or the user logs in again.
final reportSummaryProvider =
    FutureProvider.family<ReportSummary, ({String from, String to})>(
  (ref, range) async {
    ref.watch(
      authNotifierProvider.select((state) => state.tokens?.accessToken),
    );

    final token = await ref
        .read(authNotifierProvider.notifier)
        .ensureFreshAccessToken();

    if (token == null) {
      throw Exception('Not authenticated. Please log in again.');
    }

    return ref.read(reportsDatasourceProvider).getSummary(
          accessToken: token,
          from: range.from,
          to: range.to,
        );
  },
);