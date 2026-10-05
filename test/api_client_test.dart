import 'dart:async' show Completer;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';

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

  test('concurrent 401s share one failed refresh and log out once', () async {
    final mock = MockClient((_) async {
      return http.Response(jsonEncode({'error': 'expired'}), 401);
    });
    var refreshCalls = 0;
    var logouts = 0;
    final api = clientFor(
      mock,
      refresh: () async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return false;
      },
      logout: () async => logouts++,
    );
    final outcomes = await Future.wait(
      List.generate(5, (_) async {
        try {
          await api.get('/api/v1/auth/me');
          return 'ok';
        } on ApiException catch (e) {
          return 'error:${e.statusCode}';
        }
      }),
    );
    expect(refreshCalls, 1);
    expect(outcomes, everyElement('error:401'));
    expect(logouts, 1);
  });

  test('concurrent 401s share one refresh and retry once each', () async {
    var refreshCalls = 0;
    var token = 'old-access';
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      if (calls <= 5) {
        return http.Response(jsonEncode({'error': 'expired'}), 401);
      }
      expect(req.headers['Authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiClient(
      baseUrl: 'https://localhost:8080',
      client: mock,
      accessTokenReader: () async => token,
      refreshTokens: () async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        token = 'new-access';
        return true;
      },
    );
    final results = await Future.wait(
      List.generate(5, (_) => api.get('/api/v1/auth/me')),
    );
    expect(refreshCalls, 1);
    expect(results, everyElement({'ok': true}));
    expect(calls, 10);
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

  group('request timeouts', () {
    MockClient hangingClient() =>
        MockClient((_) => Completer<http.Response>().future);

    test('a hanging request fails as ApiException(-1, timeout)', () async {
      final api = ApiClient(
        baseUrl: 'https://localhost:8080',
        client: hangingClient(),
        timeout: const Duration(milliseconds: 100),
      );
      try {
        await api.get('/api/v1/auth/me');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, -1);
        expect(e.code, 'timeout');
        expect(
          ErrorMessages.forApiError(e, isArabic: false),
          ErrorMessages.networkError(false),
        );
        expect(
          ErrorMessages.forApiError(e, isArabic: true),
          ErrorMessages.networkError(true),
        );
      }
    });

    test('/play uses the longer play budget, not the default', () async {
      final api = ApiClient(
        baseUrl: 'https://localhost:8080',
        client: hangingClient(),
        // If the default applied to /play, this test would take 5 seconds.
        timeout: const Duration(seconds: 5),
        playTimeout: const Duration(milliseconds: 100),
      );
      final sw = Stopwatch()..start();
      try {
        await api.post('/api/v1/academy/videos/v1/play');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'timeout');
      }
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('other paths use the default budget, not the play one', () async {
      final api = ApiClient(
        baseUrl: 'https://localhost:8080',
        client: hangingClient(),
        timeout: const Duration(milliseconds: 100),
        playTimeout: const Duration(seconds: 5),
      );
      final sw = Stopwatch()..start();
      try {
        await api.get('/api/v1/academy/subjects');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'timeout');
      }
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
