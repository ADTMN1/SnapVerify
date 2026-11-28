import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:snapverify/data/datasources/reports_remote_datasource.dart';
import 'package:snapverify/domain/entities/report_summary.dart';

class _ThrowingClient extends http.BaseClient {
  final Object error;

  _ThrowingClient(this.error);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw error;
}

void main() {
  const range = (from: '2026-11-26', to: '2026-11-26');

  ReportsRemoteDatasource datasourceFor(http.Client client) =>
      ReportsRemoteDatasource(client: client);

  Future<ReportSummary> fetch(ReportsRemoteDatasource datasource) =>
      datasource.getSummary(
        accessToken: 'token-1',
        from: range.from,
        to: range.to,
      );

  test('requests the summary with encoded dates and a bearer token', () async {
    Uri? capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      expect(request.headers['Authorization'], 'Bearer token-1');
      return http.Response(
        '{"range":{"from":"2026-11-26","to":"2026-11-26"},"summary":{"total":1},"byStatus":[],"byProvider":[],"byStaff":[],"daily":[],"recent":[],"highRiskPayments":[]}',
        200,
      );
    });

    final summary = await fetch(datasourceFor(client));

    expect(summary.summary.total, 1);
    expect(capturedUri!.path, '/reports/summary');
    expect(
      capturedUri!.queryParameters,
      {'from': '2026-11-26', 'to': '2026-11-26'},
    );
  });

  test('maps a connection reset to a friendly network exception', () async {
    final datasource = datasourceFor(
      _ThrowingClient(http.ClientException('Connection reset by peer')),
    );

    await expectLater(
      fetch(datasource),
      throwsA(
        isA<ReportsNetworkException>().having(
          (e) => e.message,
          'message',
          contains('Connection lost while loading reports'),
        ),
      ),
    );
  });

  test('preserves HTTP status and server message for failures', () async {
    final datasource = datasourceFor(
      MockClient(
        (_) async => http.Response('{"message":"Database is busy"}', 500),
      ),
    );

    await expectLater(
      fetch(datasource),
      throwsA(
        isA<ReportsHttpException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Database is busy'),
      ),
    );
  });

  test('gives a session-specific message for 401 responses', () async {
    final datasource = datasourceFor(
      MockClient(
        (_) async => http.Response('{"message":"Unauthorized"}', 401),
      ),
    );

    await expectLater(
      fetch(datasource),
      throwsA(
        isA<ReportsHttpException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having(
              (e) => e.message,
              'message',
              'Your session expired. Please log in again.',
            ),
      ),
    );
  });
}
