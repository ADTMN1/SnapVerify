import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:snapverify/data/datasources/auth_remote_datasource.dart';
import 'package:snapverify/data/repositories/auth_repository_impl.dart';

class FakeLogoutClient extends http.BaseClient {
  final bool shouldThrow;

  FakeLogoutClient(this.shouldThrow);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (shouldThrow) {
      throw TimeoutException('offline');
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{}')),
      200,
    );
  }
}

void main() {
  late Map<String, String> storageData;

  setUp(() {
    storageData = {
      'sv_access_token': 'access-token',
      'sv_refresh_token': 'refresh-token',
    };
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(storageData);
  });

  AuthRepositoryImpl makeRepo({required bool failRemote}) {
    return AuthRepositoryImpl(
      remoteDatasource: AuthRemoteDatasource(
        client: FakeLogoutClient(failRemote),
      ),
      secureStorage: const FlutterSecureStorage(),
    );
  }

  test('successful remote logout clears local tokens', () async {
    final repo = makeRepo(failRemote: false);

    await repo.logout('refresh-token');

    expect(storageData['sv_access_token'], isNull);
    expect(storageData['sv_refresh_token'], isNull);
  });

  test('failed remote logout still clears local tokens', () async {
    final repo = makeRepo(failRemote: true);

    await expectLater(repo.logout('refresh-token'), throwsA(isA<Exception>()));

    expect(storageData, isEmpty);
  });

  test('repeated offline logout is safe', () async {
    final repo = makeRepo(failRemote: true);

    for (var i = 0; i < 2; i++) {
      await expectLater(repo.logout('refresh-token'), throwsA(isA<Exception>()));
    }

    expect(storageData, isEmpty);
  });

  test('cold start after offline logout has no stored session', () async {
    final first = makeRepo(failRemote: true);
    await expectLater(first.logout('refresh-token'), throwsA(isA<Exception>()));

    final restarted = makeRepo(failRemote: false);
    expect(await restarted.getTokens(), isNull);
  });
}
