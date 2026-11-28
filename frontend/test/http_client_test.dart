import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:snapverify/core/http_client.dart';

class _MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  _MockClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  group('RefreshingHttpClient', () {
    test('passes through non-401 responses without calling onRefresh', () async {
      var refreshCalled = false;
      final inner = _MockClient((request) async =>
          http.StreamedResponse(Stream.empty(), 200));
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          refreshCalled = true;
          return 'new-token';
        },
      );

      final response = await client.get(Uri.parse('https://api.example.com/'));

      expect(response.statusCode, 200);
      expect(refreshCalled, isFalse);
    });

    test('retries once with refreshed token on 401', () async {
      var refreshCalled = false;
      final inner = _MockClient((request) async {
        final auth = request.headers['Authorization'];
        if (auth != 'Bearer new-token') {
          return http.StreamedResponse(Stream.empty(), 401);
        }
        return http.StreamedResponse(Stream.empty(), 200);
      });
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          refreshCalled = true;
          return 'new-token';
        },
      );

      final response = await client.get(Uri.parse('https://api.example.com/'));

      expect(response.statusCode, 200);
      expect(refreshCalled, isTrue);
    });

    test('updates Authorization header with the refreshed token', () async {
      String? capturedAuth;
      final inner = _MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        if (capturedAuth != 'Bearer refreshed-123') {
          return http.StreamedResponse(Stream.empty(), 401);
        }
        return http.StreamedResponse(Stream.empty(), 200);
      });
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async => 'refreshed-123',
      );

      await client.get(Uri.parse('https://api.example.com/'));

      expect(capturedAuth, 'Bearer refreshed-123');
    });

    test('returns original 401 when refresh returns null', () async {
      final inner = _MockClient((request) async =>
          http.StreamedResponse(Stream.empty(), 401));
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async => null,
      );

      final response = await client.get(Uri.parse('https://api.example.com/'));

      expect(response.statusCode, 401);
    });

    test('does not retry indefinitely — only one retry on 401', () async {
      var requestCount = 0;
      final inner = _MockClient((request) async {
        requestCount++;
        return http.StreamedResponse(Stream.empty(), 401);
      });
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async => 'new-token',
      );

      final response = await client.get(Uri.parse('https://api.example.com/'));

      expect(response.statusCode, 401);
      expect(requestCount, 2); // original + exactly one retry
    });

    test('returns original 401 when onRefresh throws', () async {
      final inner = _MockClient((request) async =>
          http.StreamedResponse(Stream.empty(), 401));
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          throw Exception('refresh failed');
        },
      );

      final response = await client.get(Uri.parse('https://api.example.com/'));

      expect(response.statusCode, 401);
    });

    test('POST requests are retried on 401', () async {
      var refreshCalled = false;
      final inner = _MockClient((request) async {
        if (request.headers['Authorization'] != 'Bearer new-token') {
          return http.StreamedResponse(Stream.empty(), 401);
        }
        return http.StreamedResponse(Stream.empty(), 201);
      });
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          refreshCalled = true;
          return 'new-token';
        },
      );

      final response = await client.post(
        Uri.parse('https://api.example.com/payments/verify'),
        headers: {'Content-Type': 'application/json'},
        body: '{"reference":"FT123"}',
      );

    expect(response.statusCode, 201);
    expect(refreshCalled, isTrue);
  });

    test('does not auto-refresh the refresh endpoint itself', () async {
      var refreshCalled = false;
      var requestCount = 0;
      final inner = _MockClient((request) async {
        requestCount++;
        return http.StreamedResponse(Stream.empty(), 401);
      });
      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          refreshCalled = true;
          return 'new-token';
        },
      );

      final response = await client.post(
        Uri.parse('https://api.example.com/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: '{"refreshToken":"stored-refresh"}',
      );

      expect(response.statusCode, 401);
      expect(refreshCalled, isFalse);
      expect(requestCount, 1);
    });

    test('multipart request is retried with buffered body on 401', () async {
      var refreshCalled = false;
      var requestCount = 0;

      final inner = _MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.StreamedResponse(Stream.empty(), 401);
        }
        return http.StreamedResponse(Stream.empty(), 200);
      });

      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async {
          refreshCalled = true;
          return 'new-token';
        },
      );

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.example.com/upload'),
      );
      request.fields['receipt'] = 'test';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          utf8.encode('fake-image-bytes'),
          filename: 'receipt.jpg',
        ),
      );

      final response = await client.send(request);

      expect(response.statusCode, 200);
      expect(refreshCalled, isTrue);
      expect(requestCount, 2);
    });

    test('multipart request returns 401 when refresh returns null', () async {
      var requestCount = 0;

      final inner = _MockClient((request) async {
        requestCount++;
        return http.StreamedResponse(Stream.empty(), 401);
      });

      final client = RefreshingHttpClient(
        inner: inner,
        onRefresh: () async => null,
      );

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.example.com/upload'),
      );
      request.fields['receipt'] = 'test';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          utf8.encode('fake-image-bytes'),
          filename: 'receipt.jpg',
        ),
      );

      final response = await client.send(request);

      expect(response.statusCode, 401);
      expect(requestCount, 1);
    });
  });
}

