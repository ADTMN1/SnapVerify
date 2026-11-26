import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snapverify/data/datasources/auth_remote_datasource.dart';
import 'package:snapverify/domain/entities/auth_tokens.dart';
import 'package:snapverify/domain/entities/subscription.dart';
import 'package:snapverify/domain/repositories/auth_repository.dart';
import 'package:snapverify/presentation/providers/auth_provider.dart';

String _token({
  required String organizationId,
  String role = 'OWNER',
  String? branchId,
}) {
  final payload = <String, dynamic>{
    'role': role,
    'organizationId': organizationId,
    if (branchId != null) 'branchId': branchId,
    'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  };
  final segment = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'header.$segment.signature';
}

String _expiredToken({
  required String organizationId,
  String role = 'OWNER',
  String? branchId,
}) {
  final payload = <String, dynamic>{
    'role': role,
    'organizationId': organizationId,
    if (branchId != null) 'branchId': branchId,
    'exp': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
  };
  final segment = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'header.$segment.signature';
}

Map<String, dynamic> _user() => {
      'id': 'user-1',
      'fullName': 'Owner',
      'email': 'owner@example.com',
      'status': 'active',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _organization(String id) => {
      'id': id,
      'name': 'Business $id',
      'type': 'restaurant',
      'phone': '',
      'status': 'active',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _authData(String organizationId, {String? branchId}) => {
      'tokens': {
        'accessToken': _token(
          organizationId: organizationId,
          branchId: branchId,
        ),
        'refreshToken': 'refresh-$organizationId',
      },
      'user': _user(),
      'organization': _organization(organizationId),
      'roles': [
        {'businessId': 'org-1', 'role': 'OWNER'},
        {'businessId': 'org-2', 'role': 'MANAGER'},
      ],
    };

Map<String, dynamic> _paidSubscription() => {
      'id': 'sub-1',
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

class FakeAuthRepository implements AuthRepository {

  Map<String, dynamic>? loginResult;
  Map<String, dynamic>? selectResult;
  Map<String, dynamic>? challengeResult;
  Map<String, dynamic>? refreshResult;
  Object? selectError;

  String? lastSelectionToken;
  String? lastOrganizationId;
  bool? lastRememberMe;
  int clearTokensCalls = 0;
  AuthTokens? storedTokens;
  Map<String, dynamic>? getMeResult;
  int refreshCalls = 0;
  final List<String> refreshTokensUsed = [];

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
  Future<Map<String, dynamic>> selectBusiness({
    required String selectionToken,
    required String organizationId,
    required bool rememberMe,
  }) async {
    lastSelectionToken = selectionToken;
    lastOrganizationId = organizationId;
    lastRememberMe = rememberMe;
    if (selectError != null) throw selectError!;
    if (selectResult == null) throw StateError('no selection result');
    return selectResult!;
  }

  @override
  Future<Map<String, dynamic>> getBusinessSelectionChallenge(
    String accessToken,
  ) async {
    if (challengeResult == null) throw StateError('no challenge result');
    return challengeResult!;
  }

  @override
  Future<bool> getRememberMe() async => true;

  @override
  Future<AuthTokens?> getTokens() async => storedTokens;

  @override
  Future<Map<String, dynamic>> refreshToken(String currentRefreshToken) async {
    refreshCalls++;
    refreshTokensUsed.add(currentRefreshToken);
    if (refreshResult == null) throw StateError('no refresh result');
    return refreshResult!;
  }

  @override
  Future<Map<String, dynamic>> getMe(String accessToken) async {
    if (getMeResult == null) throw StateError('no getMe result');
    return getMeResult!;
  }

  @override
  Future<void> clearTokens() async {
    clearTokensCalls++;
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<void> setSessionOnly(bool value) async {}

  @override
  Future<void> saveRememberedLogin(String identifier) async {}

  @override
  Future<void> forgetRememberedLogin() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  AuthNotifier notifier() => container.read(authNotifierProvider.notifier);
  AuthState state() => container.read(authNotifierProvider);

  setUp(() async {
    repo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => container.dispose());

  test('single-business login authenticates without a selection token', () async {
    repo.loginResult = _authData('org-1');

    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    expect(state().status, AuthStatus.authenticated);
    expect(state().pendingSelectionToken, isNull);
    expect(state().organization?.id, 'org-1');
  });

  test('multi-business login preserves the selection token and businesses', () async {
    repo.loginResult = {
      'requiresBusinessSelection': true,
      'selectionToken': 'selection-1',
      'businesses': [
        {
          'organizationId': 'org-1',
          'organizationName': 'Business org-1',
          'role': 'OWNER',
        },
        {
          'organizationId': 'org-2',
          'organizationName': 'Business org-2',
          'role': 'MANAGER',
        },
      ],
      'user': _user(),
    };

    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    expect(state().status, AuthStatus.requiresBusinessSelection);
    expect(state().pendingSelectionToken, 'selection-1');
    expect(state().availableOrganizations, hasLength(2));
  });

  test('successful selection uses selectionToken and clears pending state', () async {
    repo.loginResult = {
      'requiresBusinessSelection': true,
      'selectionToken': 'selection-1',
      'businesses': [
        {
          'organizationId': 'org-1',
          'organizationName': 'Business org-1',
          'role': 'OWNER',
        },
      ],
      'user': _user(),
    };
    repo.selectResult = _authData('org-2', branchId: 'branch-1');
    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    await notifier().selectBusiness('org-2');

    expect(repo.lastSelectionToken, 'selection-1');
    expect(repo.lastOrganizationId, 'org-2');
    expect(repo.lastRememberMe, isTrue);
    expect(state().status, AuthStatus.authenticated);
    expect(state().pendingSelectionToken, isNull);
    expect(state().pendingUser, isNull);
    expect(state().availableOrganizations, hasLength(1));
    expect(state().currentBranchId, 'branch-1');
  });

  test('invalid or expired selection token keeps the user on selection', () async {
    repo.loginResult = {
      'requiresBusinessSelection': true,
      'selectionToken': 'selection-1',
      'businesses': [
        {
          'organizationId': 'org-1',
          'organizationName': 'Business org-1',
          'role': 'OWNER',
        },
      ],
      'user': _user(),
    };
    repo.selectError = ApiException('Business selection session expired', statusCode: 401);
    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    await notifier().selectBusiness('org-1');

    expect(state().status, AuthStatus.error);
    expect(state().pendingSelectionToken, 'selection-1');
  });

  test('switching businesses requests a fresh challenge and uses its token', () async {
    repo.loginResult = _authData('org-1');
    repo.challengeResult = {
      'selectionToken': 'switch-token',
      'businesses': [
        {
          'organizationId': 'org-1',
          'organizationName': 'Business org-1',
          'role': 'OWNER',
        },
        {
          'organizationId': 'org-2',
          'organizationName': 'Business org-2',
          'role': 'MANAGER',
        },
      ],
    };
    repo.selectResult = _authData('org-2');
    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    await notifier().switchBusiness('org-2');

    expect(repo.lastSelectionToken, 'switch-token');
    expect(repo.lastOrganizationId, 'org-2');
    expect(state().organization?.id, 'org-2');
    expect(state().pendingSelectionToken, isNull);
    expect(state().availableOrganizations, hasLength(2));
  });

  test('silent refresh preserves organizations, user, organization and branch', () async {
    repo.loginResult = _authData('org-1', branchId: 'branch-1');
    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);
    final before = state();
    repo.refreshResult = {
      'tokens': {
        'accessToken': _token(
          organizationId: 'org-1',
          branchId: 'branch-1',
        ),
        'refreshToken': 'refreshed-refresh',
      },
    };

    final refreshed = await notifier().silentRefresh();

    expect(refreshed, isNotNull);
    expect(state().status, AuthStatus.authenticated);
    expect(state().availableOrganizations, before.availableOrganizations);
    expect(state().user?.id, before.user?.id);
    expect(state().organization?.id, 'org-1');
    expect(state().currentBranchId, 'branch-1');
  });

  test('cold restore refreshes stored tokens exactly once', () async {
    repo.storedTokens = AuthTokens(
      accessToken: _expiredToken(
        organizationId: 'org-1',
        branchId: 'branch-1',
      ),
      refreshToken: 'stored-refresh',
      role: 'OWNER',
      organizationId: 'org-1',
    );
    repo.refreshResult = {
      'tokens': {
        'accessToken': _token(
          organizationId: 'org-1',
          branchId: 'branch-1',
        ),
        'refreshToken': 'fresh-refresh',
      },
      'roles': [
        {'businessId': 'org-1', 'role': 'OWNER', 'branchId': 'branch-1'},
        {'businessId': 'org-2', 'role': 'MANAGER'},
      ],
    };
    repo.getMeResult = {
      'user': _user(),
      'organization': _organization('org-1'),
    };

    await notifier().retryRestore();

    expect(repo.refreshCalls, 1);
    expect(repo.refreshTokensUsed, ['stored-refresh']);
    expect(state().status, AuthStatus.authenticated);
    expect(state().tokens?.refreshToken, 'fresh-refresh');
    expect(state().roles, hasLength(2));
    expect(state().currentBranchId, 'branch-1');
  });

  test('concurrent silent refresh shares one token request', () async {
    await notifier().retryRestore();

    repo.storedTokens = AuthTokens(
      accessToken: _expiredToken(organizationId: 'org-1'),
      refreshToken: 'stored-refresh',
      role: 'OWNER',
      organizationId: 'org-1',
    );
    repo.refreshResult = {
      'tokens': {
        'accessToken': _token(organizationId: 'org-1'),
        'refreshToken': 'fresh-refresh',
      },
    };

    final results = await Future.wait([
      notifier().silentRefresh(),
      notifier().silentRefresh(),
      notifier().silentRefresh(),
    ]);

    expect(repo.refreshCalls, 1);
    expect(results.every((tokens) => tokens?.refreshToken == 'fresh-refresh'), isTrue);
  });

  test('refreshSubscription rechecks paid status via auth/me', () async {
    repo.loginResult = _authData('org-1');
    await notifier().loginWithPassword('owner@example.com', 'pw', rememberMe: true);

    repo.getMeResult = {
      'user': _user(),
      'organization': _organization('org-1'),
      'subscription': _paidSubscription(),
    };

    final refreshed = await notifier().refreshSubscription();

    expect(refreshed?.status, SubscriptionStatus.active);
    expect(refreshed?.isActive, isTrue);
    expect(refreshed?.isQuotaExceeded, isFalse);
    expect(state().subscription?.id, 'sub-1');
    expect(state().subscription?.verificationRemaining, 40);
  });
}
