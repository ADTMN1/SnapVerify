import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:snapverify/data/datasources/subscription_remote_datasource.dart';
import 'package:snapverify/domain/entities/auth_tokens.dart';
import 'package:snapverify/domain/repositories/auth_repository.dart';
import 'package:snapverify/presentation/providers/auth_provider.dart';
import 'package:snapverify/presentation/providers/subscription_provider.dart';
import 'package:snapverify/presentation/screens/subscription_sheet.dart';

String _token() {
  final payload = {
    'role': 'OWNER',
    'organizationId': 'org-1',
    'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  };
  final segment = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'header.$segment.signature';
}

Map<String, dynamic> _authData() => {
      'tokens': {
        'accessToken': _token(),
        'refreshToken': 'refresh-org-1',
      },
      'user': {
        'id': 'user-1',
        'fullName': 'Owner',
        'email': 'owner@example.com',
        'status': 'active',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      },
      'organization': {
        'id': 'org-1',
        'name': 'Business org-1',
        'type': 'restaurant',
        'phone': '',
        'status': 'active',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      },
      'subscription': {
        'id': 'sub-expired',
        'organizationId': 'org-1',
        'planName': 'one_month',
        'status': 'EXPIRED',
        'startDate': '2026-01-01T00:00:00Z',
        'endDate': '2026-01-02T00:00:00Z',
      },
      'roles': [
        {'businessId': 'org-1', 'role': 'OWNER'},
      ],
    };

Map<String, dynamic> _paidSubscription() => {
      'id': 'sub-paid',
      'organizationId': 'org-1',
      'planName': 'one_month',
      'status': 'ACTIVE',
      'startDate': DateTime.now().toUtc().toIso8601String(),
      'endDate': DateTime
          .now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'verificationLimit': 50,
      'verificationUsed': 10,
      'verificationRemaining': 40,
    };

class _FakeAuthRepository implements AuthRepository {
  Map<String, dynamic>? loginResult;
  Map<String, dynamic>? getMeResult;

  @override
  Future<AuthTokens?> getTokens() async => null;

  @override
  Future<void> clearTokens() async {}

  @override
  Future<Map<String, dynamic>> loginWithPassword(
    String identifier,
    String password, {
    String? organizationId,
    required bool rememberMe,
  }) async {
    if (loginResult == null) throw StateError('no login result');
    return loginResult!;
  }

  @override
  Future<Map<String, dynamic>> getMe(String accessToken) async {
    if (getMeResult == null) throw StateError('no getMe result');
    return getMeResult!;
  }

  @override
  Future<void> setSessionOnly(bool value) async {}

  @override
  Future<bool> getRememberMe() async => true;

  @override
  Future<void> saveRememberedLogin(String identifier) async {}

  @override
  Future<void> forgetRememberedLogin() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _PopObserver extends NavigatorObserver {
  bool popped = false;

  @override
  void didPop(Route route, Route? previousRoute) {
    popped = true;
  }
}

void main() {
  testWidgets('does not modify providers during initState', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SubscriptionSheet()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SubscriptionSheet), findsOneWidget);
  });

  testWidgets('Already paid? Check again closes the sheet when paid', (tester) async {
    final repo = _FakeAuthRepository()
      ..loginResult = _authData()
      ..getMeResult = {
        'user': _authData()['user'],
        'organization': _authData()['organization'],
        'subscription': _paidSubscription(),
      };
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        subscriptionRemoteDatasourceProvider.overrideWithValue(
          SubscriptionRemoteDatasource(
            client: MockClient((request) async {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'one_month',
                    'name': 'one_month',
                    'price': 100,
                    'currency': 'ETB',
                    'durationMonths': 1,
                    'verificationLimit': 50,
                  },
                ]),
                200,
                headers: {'Content-Type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );

    await container.read(authNotifierProvider.notifier).loginWithPassword(
          'owner@example.com',
          'pw',
          rememberMe: true,
        );

    final observer = _PopObserver();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Material(
                    child: SizedBox(
                      height: 700,
                      child: SubscriptionSheet(startOnPlanList: true),
                    ),
                  ),
                ),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Already paid? Check again'), findsOneWidget);

    await tester.tap(find.text('Already paid? Check again'));
    await tester.pumpAndSettle();

    expect(observer.popped, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();

    expect(tester.takeException(), isNull);
  });
}
