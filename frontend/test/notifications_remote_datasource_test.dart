import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapverify/data/datasources/notifications_remote_datasource.dart';

void main() {
  group('NotificationsRemoteDatasource', () {
    test('parses the notification feed', () async {
      final ds = NotificationsRemoteDatasource(
        client: MockClient((request) async {
          expect(request.url.path, '/notifications');
          return http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 'payment:p1',
                  'type': 'payment_verified',
                  'title': 'Payment verified',
                  'body': 'ETB 100.00 · FT1 · Payer',
                  'createdAt': '2026-01-15T10:00:00.000Z',
                  'read': false,
                  'entityId': 'p1',
                },
                {
                  'id': 'invitation:i1',
                  'type': 'invitation_created',
                  'title': 'Staff invitation created',
                  'body': 'Alice · CASHIER',
                  'createdAt': '2026-01-16T10:00:00.000Z',
                  'read': true,
                  'entityId': 'i1',
                },
              ],
              'unreadCount': 1,
              'lastReadAt': null,
            }),
            200,
          );
        }),
      );

      final data = await ds.getNotifications(accessToken: 't');

      expect(data.notifications, hasLength(2));
      expect(data.unreadCount, 1);
      expect(data.notifications.first.type, 'payment_verified');
      expect(data.notifications.first.read, isFalse);
      expect(data.notifications.last.read, isTrue);
    });

    test('throws the server message on non-2xx', () async {
      final ds = NotificationsRemoteDatasource(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'message': 'Your session has expired. Please log in again.',
            }),
            401,
          ),
        ),
      );

      await expectLater(
        ds.getNotifications(accessToken: 't'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('session has expired'),
          ),
        ),
      );
    });

    test('markAllRead posts to /notifications/read', () async {
      var called = false;
      final ds = NotificationsRemoteDatasource(
        client: MockClient((request) async {
          called = true;
          expect(request.url.path, '/notifications/read');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({'success': true, 'lastReadAt': '2026-01-17T10:00:00.000Z'}),
            200,
          );
        }),
      );

      await ds.markAllRead(accessToken: 't');
      expect(called, isTrue);
    });
  });
}