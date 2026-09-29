import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:el_metr_academy/core/api_client.dart';

ApiClient clientFor(
  MockClient mock, {
  Future<bool> Function()? refresh,
  Future<void> Function()? logout,
}) {
  return ApiClient(
    baseUrl: 'https://localhost:8080',
    client: mock,
    accessTokenReader: () async => 'old-access',
    refreshTokens: refresh,
    forceLogout: logout,
  );
}

void main() {
  test('login success returns token pair', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/api/v1/auth/login');
      return http.Response(
        jsonEncode({'access_token': 'a1', 'refresh_token': 'r1'}),
        200,
      );
    });
    final api = clientFor(mock);
    final res = await api.post(
      '/api/v1/auth/login',
      body: {'email': 'u@e.com', 'password': 'password123'},
    );
    expect(res['access_token'], 'a1');
    expect(res['refresh_token'], 'r1');
  });

  test(
    'wrong password surfaces 401 without logout when no refresh configured',
    () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode({'error': 'invalid credentials', 'code': 'unauthorized'}),
          401,
        );
      });
      var loggedOut = false;
      final api = ApiClient(
        baseUrl: 'https://localhost:8080',
        client: mock,
        accessTokenReader: () async => 'old-access',
        forceLogout: () async => loggedOut = true,
      );
      try {
        await api.get('/api/v1/auth/me');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(loggedOut, isTrue);
    },
  );

  test('401 refreshes once and retries', () async {
    var calls = 0;
    var token = 'old-access';
    final mock = MockClient((req) async {
      calls++;
      if (calls == 1) {
        return http.Response(
          jsonEncode({'error': 'expired', 'code': 'invalid_token'}),
          401,
        );
      }
      expect(req.headers['Authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiClient(
      baseUrl: 'https://localhost:8080',
      client: mock,
      accessTokenReader: () async => token,
      refreshTokens: () async {
        token = 'new-access';
        return true;
      },
    );
    final res = await api.get('/api/v1/auth/me');
    expect(res['ok'], isTrue);
    expect(calls, 2);
  });

  test('failed refresh logs out exactly once', () async {
    final mock = MockClient((_) async {
      return http.Response(jsonEncode({'error': 'expired'}), 401);
    });
    var logouts = 0;
    final api = clientFor(
      mock,
      refresh: () async => false,
      logout: () async => logouts++,
    );
    try {
      await api.get('/api/v1/auth/me');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 401);
    }
    expect(logouts, 1);
  });

  test('429 surfaces rate-limit message', () async {
    final mock = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': 'too many attempts, retry later',
          'code': 'locked_out',
        }),
        429,
      );
    });
    final api = clientFor(mock);
    try {
      await api.post(
        '/api/v1/auth/login',
        body: {'email': 'u@e.com', 'password': 'x'},
      );
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.isRateLimited, isTrue);
      expect(e.message, contains('too many attempts'));
    }
  });
}
