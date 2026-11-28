import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/reports_remote_datasource.dart';
import '../../domain/entities/report_summary.dart';
import 'auth_provider.dart';

final reportsDatasourceProvider = Provider<ReportsRemoteDatasource>((ref) {
  return ReportsRemoteDatasource(client: ref.watch(httpClientProvider));
});

final reportSummaryProvider =
    FutureProvider.family<ReportSummary, ({String from, String to})>((
      ref,
      range,
    ) async {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();

      if (token == null) {
        throw const ReportsException('Not authenticated. Please log in again.');
      }

      return ref
          .read(reportsDatasourceProvider)
          .getSummary(accessToken: token, from: range.from, to: range.to);
    });
