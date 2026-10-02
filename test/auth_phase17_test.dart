import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/device_id.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/repositories/auth_repository.dart';
import 'package:wael_app/utils/logout_helper.dart';

import 'fakes.dart';
import 'screen_harness.dart';

void main() {
  group('Phase 1.7: RFC 4122 UUIDv4 Device ID', () {
    bool isValidUUIDv4(String id) {
      if (id.length != 36) return false;
      if (id[8] != '-' || id[13] != '-' || id[18] != '-' || id[23] != '-') {
        return false;
      }
      if (id[14] != '4') return false;
      final variant = id[19].toLowerCase();
      if (variant != '8' &&
          variant != '9' &&
          variant != 'a' &&
          variant != 'b') {
        return false;
      }
      for (var i = 0; i < 36; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) continue;
        final c = id[i].toLowerCase();
        final isHex =
            (c.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
                c.codeUnitAt(0) <= '9'.codeUnitAt(0)) ||
            (c.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
                c.codeUnitAt(0) <= 'f'.codeUnitAt(0));
        if (!isHex) return false;
      }
      return true;
    }

    test('generateUuidV4 generates valid RFC 4122 UUIDv4', () {
      for (var i = 0; i < 20; i++) {
        final id = DeviceIdManager.generateUuidV4();
        expect(isValidUUIDv4(id), isTrue, reason: '$id should be valid UUIDv4');
      }
    });

    test('generateUuidV4 produces distinct IDs on consecutive calls', () {
      final id1 = DeviceIdManager.generateUuidV4();
      final id2 = DeviceIdManager.generateUuidV4();
      expect(id1, isNot(id2));
    });

    test('getOrCreateDeviceId stores new ID if store is empty', () async {
      final store = MemoryTokenStore();
      expect(await store.readDeviceId(), isNull);

      final id = await DeviceIdManager.getOrCreateDeviceId(store);
      expect(isValidUUIDv4(id), isTrue);
      expect(await store.readDeviceId(), id);
    });

    test(
      'getOrCreateDeviceId is stable across restarts (reads existing ID)',
      () async {
        final store = MemoryTokenStore();
        final initialId = await DeviceIdManager.getOrCreateDeviceId(store);

        // Simulate app restart by calling getOrCreateDeviceId again on same store
        final restartedId = await DeviceIdManager.getOrCreateDeviceId(store);
        expect(restartedId, equals(initialId));
      },
    );

    test('TokenStore.clear() preserves device_id across logouts', () async {
      final store = MemoryTokenStore();
      final devId = await DeviceIdManager.getOrCreateDeviceId(store);
      await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

      // Logout triggers clear()
      await store.clear();

      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
      // device_id MUST survive clear()
      expect(await store.readDeviceId(), equals(devId));
    });

    test(
      'SecureTokenStore preserves device_id across clear() in fallback mode',
      () async {
        final store = SecureTokenStore();
        final devId = await DeviceIdManager.getOrCreateDeviceId(store);
        await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

        await store.clear();

        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(await store.readDeviceId(), equals(devId));
      },
    );

    test('AuthProvider.login sends stable device_id', () async {
      final repo = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = AuthProvider(repository: repo, tokenStore: store);

      final ok = await auth.login('test@example.com', 'password123');
      expect(ok, isTrue);
      expect(repo.loginCalls, 1);
      expect(repo.lastLoginDeviceId, isNotNull);
      expect(isValidUUIDv4(repo.lastLoginDeviceId!), isTrue);

      final firstDevId = repo.lastLoginDeviceId;

      // Repeated login from same store retains the exact same device_id
      await auth.login('test2@example.com', 'password123');
      expect(repo.lastLoginDeviceId, equals(firstDevId));
    });

    test('AuthProvider.verifyOtp sends stable device_id', () async {
      final repo = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = AuthProvider(repository: repo, tokenStore: store);

      final ok = await auth.verifyOtp(
        email: 'test@example.com',
        code: '123456',
      );
      expect(ok, isTrue);
      expect(repo.verifyOtpCalls, 1);
      expect(repo.lastVerifyOtpDeviceId, isNotNull);
      expect(isValidUUIDv4(repo.lastVerifyOtpDeviceId!), isTrue);
    });

    test(
      'HttpAuthRepository sends device_id in login and verify-otp payloads',
      () async {
        final recordedRequests = <String, Map<String, dynamic>>{};

        final mockClient = MockClient((request) async {
          final path = request.url.path;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          recordedRequests[path] = body;

          if (path.endsWith('/login') || path.endsWith('/verify-otp')) {
            return http.Response(
              jsonEncode({
                'access_token': 'mock-access',
                'refresh_token': 'mock-refresh',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });

        final client = ApiClient(
          baseUrl: 'http://localhost',
          client: mockClient,
        );
        final httpRepo = HttpAuthRepository(client);

        const testDevId = '44444444-4444-4444-8444-444444444444';

        await httpRepo.login(
          email: 'user@example.com',
          password: 'pass',
          deviceId: testDevId,
        );
        expect(
          recordedRequests['/api/v1/auth/login']?['device_id'],
          equals(testDevId),
        );

        await httpRepo.verifyOtp(
          email: 'user@example.com',
          code: '123456',
          deviceId: testDevId,
        );
        expect(
          recordedRequests['/api/v1/auth/verify-otp']?['device_id'],
          equals(testDevId),
        );
      },
    );
  });

  group('Phase 1.7: 401 session_replaced handling and messages', () {
    const ownerArabicMsg = 'عفوًا، لقد تجاوزت الحد المسموح لاستخدام هذا الحساب';
    const ownerEnglishMsg =
        "Sorry, this account's usage limit has been exceeded";

    test('ErrorMessages has verbatim owner text in Arabic and English', () {
      expect(ErrorMessages.sessionReplaced(true), equals(ownerArabicMsg));
      expect(ErrorMessages.sessionReplaced(false), equals(ownerEnglishMsg));
    });

    test(
      'ErrorMessages.forApiError routes session_replaced code correctly',
      () {
        final ex = ApiException(
          statusCode: 401,
          message: 'Something else',
          code: 'session_replaced',
        );
        expect(
          ErrorMessages.forApiError(ex, isArabic: true),
          equals(ownerArabicMsg),
        );
        expect(
          ErrorMessages.forApiError(ex, isArabic: false),
          equals(ownerEnglishMsg),
        );
      },
    );

    test('AppLocalizations sessionReplaced getter returns owner text', () {
      final l10nAr = AppLocalizations(const Locale('ar'));
      expect(l10nAr.sessionReplaced, equals(ownerArabicMsg));

      final l10nEn = AppLocalizations(const Locale('en'));
      expect(l10nEn.sessionReplaced, equals(ownerEnglishMsg));
    });

    test(
      'session_replaced on refresh clears state and sets Arabic owner message',
      () async {
        final repo = FakeAuthRepository(refreshMode: 'session_replaced_ar');
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'token-1', refresh: 'ref-1');

        final auth = AuthProvider(
          repository: repo,
          tokenStore: store,
          localeReader: () => 'ar',
        );

        final ok = await auth.doRefresh();
        expect(ok, isFalse);
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(auth.errorMessage, equals(ownerArabicMsg));
      },
    );

    test(
      'session_replaced on refresh clears state and sets English owner message',
      () async {
        final repo = FakeAuthRepository(refreshMode: 'session_replaced');
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'token-1', refresh: 'ref-1');

        final auth = AuthProvider(
          repository: repo,
          tokenStore: store,
          localeReader: () => 'en',
        );

        final ok = await auth.doRefresh();
        expect(ok, isFalse);
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(auth.errorMessage, equals(ownerEnglishMsg));
      },
    );

    test(
      'session_replaced on general API call invokes onSessionReplaced and logs out',
      () async {
        String? callbackMsg;
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 'session_replaced', 'error': ownerEnglishMsg}),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          baseUrl: 'http://localhost',
          client: mockClient,
          onSessionReplaced: (msg) async {
            callbackMsg = msg;
          },
        );

        await expectLater(
          client.get('/api/v1/academy/subjects'),
          throwsA(isA<ApiException>()),
        );
        expect(callbackMsg, equals(ownerEnglishMsg));
      },
    );
  });

  group('Phase 1.7: POST /api/v1/auth/logout and unconfirmed notice', () {
    test(
      'HttpAuthRepository.logout issues POST /api/v1/auth/logout with Bearer token',
      () async {
        String? seenMethod;
        String? seenPath;
        String? seenAuthHeader;

        final mockClient = MockClient((request) async {
          seenMethod = request.method;
          seenPath = request.url.path;
          seenAuthHeader = request.headers['authorization'];
          return http.Response('', 204);
        });

        final client = ApiClient(
          baseUrl: 'http://localhost',
          client: mockClient,
        );
        final repo = HttpAuthRepository(client);

        await repo.logout(accessToken: 'my-access-token');

        expect(seenMethod, equals('POST'));
        expect(seenPath, equals('/api/v1/auth/logout'));
        expect(seenAuthHeader, equals('Bearer my-access-token'));
      },
    );

    test(
      'logout on 204: proceeds, clears local tokens, confirmed=true',
      () async {
        final repo = FakeAuthRepository()..logoutMode = 'ok';
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

        final auth = AuthProvider(repository: repo, tokenStore: store);
        expect(await auth.login('test@example.com', 'pass'), isTrue);

        final confirmed = await auth.logout();
        expect(confirmed, isTrue);
        expect(repo.logoutCalls, 1);
        expect(repo.lastLogoutToken, equals('access-1'));
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(auth.logoutNotice, isNull);
      },
    );

    test(
      'logout on 401: proceeds, clears local tokens, confirmed=true',
      () async {
        final repo = FakeAuthRepository()..logoutMode = '401';
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

        final auth = AuthProvider(repository: repo, tokenStore: store);
        expect(await auth.login('test@example.com', 'pass'), isTrue);

        final confirmed = await auth.logout();
        expect(confirmed, isTrue);
        expect(repo.logoutCalls, 1);
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(auth.logoutNotice, isNull);
      },
    );

    test(
      'logout on 503: clears local tokens, confirmed=false, sets notice',
      () async {
        final repo = FakeAuthRepository()..logoutMode = '503';
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

        final auth = AuthProvider(
          repository: repo,
          tokenStore: store,
          localeReader: () => 'ar',
        );
        expect(await auth.login('test@example.com', 'pass'), isTrue);

        final confirmed = await auth.logout();
        expect(confirmed, isFalse);
        expect(repo.logoutCalls, 1);
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(
          auth.logoutNotice,
          equals(ErrorMessages.signOutUnconfirmed(true)),
        );
      },
    );

    test(
      'logout on network error: clears local tokens, confirmed=false, sets notice in English',
      () async {
        final repo = FakeAuthRepository()..logoutMode = 'network';
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

        final auth = AuthProvider(
          repository: repo,
          tokenStore: store,
          localeReader: () => 'en',
        );
        expect(await auth.login('test@example.com', 'pass'), isTrue);

        final confirmed = await auth.logout();
        expect(confirmed, isFalse);
        expect(repo.logoutCalls, 1);
        expect(auth.status, equals(AuthStatus.unauthenticated));
        expect(await store.readAccessToken(), isNull);
        expect(await store.readRefreshToken(), isNull);
        expect(
          auth.logoutNotice,
          equals(ErrorMessages.signOutUnconfirmed(false)),
        );
      },
    );

    testWidgets('LogoutHelper shows SnackBar when logout is unconfirmed', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..logoutMode = '503';
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'acc-1', refresh: 'ref-1');

      final auth = AuthProvider(
        repository: repo,
        tokenStore: store,
        localeReader: () => 'ar',
      );

      await pumpScreen(
        tester,
        const Locale('ar'),
        Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => LogoutHelper.performLogout(context),
                child: const Text('Do Logout'),
              ),
            );
          },
        ),
        auth: auth,
      );

      await tester.tap(find.text('Do Logout'));
      await tester.pumpAndSettle();

      expect(find.text('route:/login'), findsOneWidget);
      expect(find.text(ErrorMessages.signOutUnconfirmed(true)), findsOneWidget);
    });
  });

  group('Phase 1.7: Accept-Language Header matching app locale', () {
    test('ApiClient sends Accept-Language matching localeReader', () async {
      String? seenLang;
      final mockClient = MockClient((request) async {
        seenLang = request.headers['accept-language'];
        return http.Response('{}', 200);
      });

      var currentLocale = 'ar';
      final client = ApiClient(
        baseUrl: 'http://localhost',
        client: mockClient,
        localeReader: () => currentLocale,
      );

      await client.get('/test');
      expect(seenLang, equals('ar'));

      currentLocale = 'en';
      await client.get('/test');
      expect(seenLang, equals('en'));
    });
  });
}
