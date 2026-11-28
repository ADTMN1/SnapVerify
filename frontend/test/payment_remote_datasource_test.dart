import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapverify/data/datasources/payment_remote_datasource.dart';

void main() {
  http.Response _json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status);

  Map<String, dynamic> _okBody() => {
        'verified': false,
        'status': 'FAILED',
        'paymentId': 'p1',
        'amount': 0,
        'currency': 'ETB',
        'transactionId': 'FT1',
        'riskScore': 0,
        'message': 'Transaction not found.',
      };

  group('PaymentRemoteDatasource provider/account error mapping', () {
    test('PAYMENT_ACCOUNT_NOT_CONFIGURED is surfaced (never invalid receipt)',
        () async {
      final ds = PaymentRemoteDatasource(
        client: MockClient((request) async => _json(400, {
              'verified': false,
              'status': 'PAYMENT_ACCOUNT_NOT_CONFIGURED',
              'message':
                  'No active CBE BIRR receiving account is configured for your business.',
            })),
      );

      await expectLater(
        ds.verifyByReference(
          accessToken: 't',
          referenceNumber: 'FT1',
          provider: 'CBEBIRR',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No active CBE BIRR'),
          ),
        ),
      );
    });

    test('PAYMENT_PROVIDER_UNDETECTED is surfaced as a selection request',
        () async {
      final ds = PaymentRemoteDatasource(
        client: MockClient((request) async => _json(400, {
              'verified': false,
              'status': 'PAYMENT_PROVIDER_UNDETECTED',
              'message':
                  'Could not determine the payment provider from this receipt.',
            })),
      );

      await expectLater(
        ds.verifyByReference(accessToken: 't', referenceNumber: 'FT1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not determine'),
          ),
        ),
      );
    });

    test('UNSUPPORTED_PAYMENT_PROVIDER is surfaced as unsupported', () async {
      final ds = PaymentRemoteDatasource(
        client: MockClient((request) async => _json(400, {
              'verified': false,
              'status': 'UNSUPPORTED_PAYMENT_PROVIDER',
              'message': 'The payment provider "WECHAT" is not supported.',
            })),
      );

      await expectLater(
        ds.verifyByReference(
          accessToken: 't',
          referenceNumber: 'FT1',
          provider: 'WECHAT',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not supported'),
          ),
        ),
      );
    });

    test('sends the detected provider to the backend', () async {
      http.BaseRequest? captured;
      final ds = PaymentRemoteDatasource(
        client: MockClient((request) async {
          captured = request;
          return _json(200, _okBody());
        }),
      );

      await ds.verifyByReference(
        accessToken: 't',
        referenceNumber: 'FT1',
        provider: 'CBEBIRR',
      );

      expect(captured, isNotNull);
      final body = jsonDecode((captured! as http.Request).body);
      expect(body['provider'], 'CBEBIRR');
    });
  });
}