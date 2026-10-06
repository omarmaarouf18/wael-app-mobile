import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/repositories/auth_repository.dart';

import 'fakes.dart';

/// Records platform haptic calls made while [run] executes.
Future<List<String>> recordHaptics(Future<void> Function() run) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vibrated = <String>[];
  final binding = TestDefaultBinaryMessengerBinding.instance;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      vibrated.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await run();
  return vibrated;
}

AuthProvider providerWith(FakeAuthRepository repo, MemoryTokenStore store) {
  return AuthProvider(repository: repo, tokenStore: store);
}

class _TrackingAuthRepository extends FakeAuthRepository {
  _TrackingAuthRepository({
    this.delay = Duration.zero,
    this.onRefresh,
    super.refreshMode,
  });

  final Duration delay;
  final Future<void> Function(String refreshToken)? onRefresh;
  int refreshCalls = 0;

  @override
  Future<AuthTokens> refresh({required String refreshToken}) async {
    refreshCalls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (onRefresh != null) {
      await onRefresh!(refreshToken);
    }
    return super.refresh(refreshToken: refreshToken);
  }
}

void main() {
  test('login success stores session and authenticates', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    final ok = await auth.login('u@e.com', 'password123');
    expect(ok, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(await store.readAccessToken(), 'access-1');
    expect(auth.currentUser.email, 'u@e.com');
  });

  test('wrong password sets error and stays logged out', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(
      FakeAuthRepository(mode: 'wrong-password'),
      store,
    );
    final ok = await auth.login('u@e.com', 'wrong');
    expect(ok, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorMessage, isNotNull);
    expect(await store.readAccessToken(), isNull);
  });

  test('signup moves to verification with pending email', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    final ok = await auth.signup(
      fullName: 'New User',
      phone: '+201000000001',
      email: 'new@e.com',
      password: 'password123',
    );
    expect(ok, isTrue);
    expect(auth.status, AuthStatus.needsVerification);
    expect(auth.pendingVerificationEmail, 'new@e.com');
    expect(auth.pendingVerificationId, 'pending-test-id');
  });

  test('verifyOtp passes the stored pending_id', () async {
    final store = MemoryTokenStore();
    final repo = FakeAuthRepository();
    final auth = providerWith(repo, store);
    await auth.signup(
      fullName: 'New User',
      phone: '+201000000001',
      email: 'new@e.com',
      password: 'password123',
    );
    final ok = await auth.verifyOtp(email: 'new@e.com', code: '123456');
    expect(ok, isTrue);
    expect(repo.lastVerifyOtpPendingId, 'pending-test-id');
    expect(auth.pendingVerificationId, isNull);
  });

  test('logout clears tokens and session', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    await auth.login('u@e.com', 'password123');
    expect(auth.isAuthenticated, isTrue);
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);
    expect(await store.readAccessToken(), isNull);
  });

  test('tryRestore authenticates with a valid stored token', () async {
    final store = MemoryTokenStore();
    await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
    final auth = providerWith(FakeAuthRepository(), store);
    await auth.tryRestore();
    expect(auth.isAuthenticated, isTrue);
  });

  group('tryRestore branches', () {
    test('expired access + valid refresh stays logged in', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final repo = FakeAuthRepository()
        ..meMode = '401-once'
        ..refreshMode = 'ok';
      final auth = providerWith(repo, store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isFalse);
      expect(repo.meCalls, 2);
      expect(await store.readAccessToken(), 'access-2');
      expect(await store.readRefreshToken(), 'refresh-2');
    });

    test('launching offline keeps tokens and enters the app', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository()..meMode = 'network',
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test('server error enters offline, retry recovers', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final repo = FakeAuthRepository()..meMode = '500';
      final auth = providerWith(repo, store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);

      repo.meMode = 'ok';
      await auth.retryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isFalse);
      expect(auth.currentUser.email, 'u@e.com');
    });

    test('refresh rejected with 401 logs out and clears tokens', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository()
          ..meMode = '401'
          ..refreshMode = '401',
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('refresh rejected with 403 logs out and clears tokens', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository()
          ..meMode = '401'
          ..refreshMode = '403',
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
    });

    test('failed refresh on a dead server keeps tokens offline', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository()
          ..meMode = '401'
          ..refreshMode = 'network',
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);
      expect(await store.readAccessToken(), 'access-1');
    });

    test('session_replaced from /me shows the message and logs out', () async {
      // handleSessionReplaced touches the navigator key, which needs the
      // test binding in a plain unit test.
      TestWidgetsFlutterBinding.ensureInitialized();
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository()..meMode = 'session_replaced',
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('usage limit'));
      expect(await store.readAccessToken(), isNull);
    });

    test('other 4xx from /me drops the tokens', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository()..meMode = '403', store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
    });

    test('/me 429 enters offline and keeps tokens', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository()..meMode = '429', store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test('/me 408 enters offline and keeps tokens', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository()..meMode = '408', store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test(
      '/me 429 with Retry-After stores the wait for the retry button',
      () async {
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
        final auth = providerWith(
          FakeAuthRepository()..meMode = '429-retry',
          store,
        );
        await auth.tryRestore();
        expect(auth.isAuthenticated, isTrue);
        expect(auth.isOffline, isTrue);
        expect(auth.retryAfterSeconds, 7);
        expect(await store.readAccessToken(), 'access-1');
      },
    );

    test('unexpected 4xx from /me keeps tokens offline (no logout)', () async {
      for (final mode in ['400', '404']) {
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
        final auth = providerWith(FakeAuthRepository()..meMode = mode, store);
        await auth.tryRestore();
        expect(auth.isAuthenticated, isTrue, reason: 'mode $mode');
        expect(auth.isOffline, isTrue, reason: 'mode $mode');
        expect(await store.readAccessToken(), 'access-1', reason: 'mode $mode');
      }
    });

    test('second /me 401 after a successful refresh logs out', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final repo = FakeAuthRepository()
        ..meMode = '401'
        ..refreshMode = 'ok';
      final auth = providerWith(repo, store);
      await auth.tryRestore();
      // First /me 401 triggers a successful refresh, then the second /me
      // still 401 (fresh tokens rejected): the session is over.
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
    });
  });

  test('successful login gives light haptic feedback', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    final vibrated = await recordHaptics(
      () => auth.login('u@e.com', 'password123'),
    );
    expect(auth.isAuthenticated, isTrue);
    expect(vibrated, contains('HapticFeedback.vibrate'));
  });

  test('failed login gives no haptic feedback', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(
      FakeAuthRepository(mode: 'wrong-password'),
      store,
    );
    final vibrated = await recordHaptics(() => auth.login('u@e.com', 'wrong'));
    expect(auth.isAuthenticated, isFalse);
    expect(vibrated, isEmpty);
  });

  test('error messages never show raw exception text', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(
      FakeAuthRepository(mode: 'wrong-password'),
      store,
    );
    await auth.login('u@e.com', 'wrong');
    expect(auth.errorMessage, isNot(contains('Exception')));
    expect(auth.errorMessage, isNot(contains('SocketException')));
    expect(auth.errorMessage, isNot(contains('instance of')));
    expect(
      auth.errorMessage,
      'Invalid credentials. Please verify your details and try again.',
    );
  });

  group('_doRefresh behavior', () {
    test('logs out and clears tokens on 401', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository(refreshMode: '401'), store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);

      final ok = await auth.doRefresh();
      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('logs out and clears tokens on 403', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository(refreshMode: '403'), store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);

      final ok = await auth.doRefresh();
      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('keeps tokens and preserves session on 500 / 503', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository(refreshMode: '503'), store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);

      final ok = await auth.doRefresh();
      expect(ok, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test('keeps tokens and preserves session on network error', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(
        FakeAuthRepository(refreshMode: 'network'),
        store,
      );
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);

      final ok = await auth.doRefresh();
      expect(ok, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test('rotates tokens and succeeds on 200', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = providerWith(FakeAuthRepository(refreshMode: 'ok'), store);
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);

      final ok = await auth.doRefresh();
      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(await store.readAccessToken(), 'access-2');
      expect(await store.readRefreshToken(), 'refresh-2');
    });

    test('logs out when refresh token is missing or empty', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: '');
      final auth = providerWith(FakeAuthRepository(refreshMode: 'ok'), store);

      final ok = await auth.doRefresh();
      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
    });

    test(
      'concurrent doRefresh calls share the same in-flight Future',
      () async {
        final repo = _TrackingAuthRepository(
          delay: const Duration(milliseconds: 30),
        );
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
        final auth = providerWith(repo, store);

        final results = await Future.wait([
          auth.doRefresh(),
          auth.doRefresh(),
          auth.doRefresh(),
        ]);

        expect(results, [true, true, true]);
        expect(repo.refreshCalls, 1);
      },
    );

    test('interleaving: rotated token prevents clearing on 401', () async {
      final store = MemoryTokenStore();
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      late final _TrackingAuthRepository repo;
      repo = _TrackingAuthRepository(
        refreshMode: '401',
        onRefresh: (token) async {
          // Simulate concurrent successful refresh rotating the token
          await store.writeTokens(
            access: 'access-rotated',
            refresh: 'refresh-rotated',
          );
        },
      );
      final auth = providerWith(repo, store);
      await auth.login('u@e.com', 'password123');
      // Reset store to simulate the starting token of the raced attempt
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');

      final ok = await auth.doRefresh();
      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(await store.readAccessToken(), 'access-rotated');
      expect(await store.readRefreshToken(), 'refresh-rotated');
    });
  });

  group('identity for the video watermark', () {
    test('AuthAccount reads full_name and phone when present, else empty', () {
      final withIdentity = AuthAccount.fromJson({
        'id': 'a',
        'email': 'u@e.com',
        'role': 'user',
        'email_verified': true,
        'full_name': 'Jane Doe',
        'phone': '+201000000000',
      });
      expect(withIdentity.fullName, 'Jane Doe');
      expect(withIdentity.phone, '+201000000000');
      final without = AuthAccount.fromJson({'id': 'a', 'email': 'u@e.com'});
      expect(without.fullName, '');
      expect(without.phone, '');
    });

    test('name and phone from the server make the watermark text', () async {
      final repo = FakeAuthRepository()
        ..meFullName = ' Jane Doe '
        ..mePhone = '+201000000000';
      final auth = providerWith(repo, MemoryTokenStore());
      await auth.login('u@e.com', 'password123');
      expect(auth.watermarkText, 'Jane Doe · +201000000000');
      expect(auth.currentUser.fullName, 'Jane Doe');
    });

    test(
      'only a name, or only a phone, still identifies the student',
      () async {
        final repo = FakeAuthRepository()..meFullName = 'Jane Doe';
        final auth = providerWith(repo, MemoryTokenStore());
        await auth.login('u@e.com', 'password123');
        expect(auth.watermarkText, 'Jane Doe');
      },
    );

    test(
      'the backend sending nothing (today) falls back to the email',
      () async {
        final auth = providerWith(FakeAuthRepository(), MemoryTokenStore());
        await auth.login('u@e.com', 'password123');
        expect(auth.watermarkText, 'u@e.com');
      },
    );

    test('before any session there is nothing to identify', () {
      final auth = providerWith(FakeAuthRepository(), MemoryTokenStore());
      expect(auth.watermarkText, isNull);
    });

    test(
      'a name and phone typed at signup are kept after verification',
      () async {
        final auth = providerWith(FakeAuthRepository(), MemoryTokenStore());
        await auth.signup(
          fullName: 'Jane Doe',
          phone: '+201000000000',
          email: 'u@e.com',
          password: 'password123',
        );
        await auth.verifyOtp(email: 'u@e.com', code: '123456');
        expect(auth.watermarkText, 'Jane Doe · +201000000000');
      },
    );

    test(
      'logout clears the identity so the next student never inherits it',
      () async {
        final repo = FakeAuthRepository()
          ..meFullName = 'Jane Doe'
          ..mePhone = '+201000000000';
        final auth = providerWith(repo, MemoryTokenStore());
        await auth.login('u@e.com', 'password123');
        expect(auth.watermarkText, contains('Jane Doe'));
        await auth.logout();
        expect(auth.watermarkText, isNull);
        expect(auth.currentUser.fullName, '');
        expect(auth.currentUser.phone, '');

        // A different student whose server record has no name: email only.
        repo
          ..meFullName = ''
          ..mePhone = '';
        await auth.login('u@e.com', 'password123');
        expect(auth.watermarkText, 'u@e.com');
      },
    );

    group('forced logout navigation', () {
      testWidgets(
        'handleForceLogout navigates to /login via navigatorKey and is idempotent',
        (tester) async {
          final auth = providerWith(FakeAuthRepository(), MemoryTokenStore());
          int loginBuilds = 0;
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: AuthProvider.navigatorKey,
              initialRoute: '/home',
              routes: {
                '/home': (_) => const Scaffold(body: Text('Home')),
                '/login': (_) {
                  loginBuilds++;
                  return const Scaffold(body: Text('Login Screen'));
                },
              },
            ),
          );
          expect(find.text('Home'), findsOneWidget);
          expect(loginBuilds, 0);

          await auth.handleForceLogout();
          await tester.pumpAndSettle();

          expect(find.text('Login Screen'), findsOneWidget);
          expect(find.text('Home'), findsNothing);
          expect(loginBuilds, 1);

          // Idempotent: second call does not re-push /login
          await auth.handleForceLogout();
          await tester.pumpAndSettle();
          expect(loginBuilds, 1);
        },
      );

      testWidgets('explicit logout does not navigate via navigatorKey', (
        tester,
      ) async {
        final auth = providerWith(FakeAuthRepository(), MemoryTokenStore());
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: AuthProvider.navigatorKey,
            initialRoute: '/home',
            routes: {
              '/home': (_) => const Scaffold(body: Text('Home')),
              '/login': (_) => const Scaffold(body: Text('Login Screen')),
            },
          ),
        );
        expect(find.text('Home'), findsOneWidget);

        await auth.logout();
        await tester.pumpAndSettle();

        // Still on Home screen (LogoutHelper in UI layer navigates explicitly)
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Login Screen'), findsNothing);
      });

      testWidgets('tryRestore failure does not navigate via navigatorKey', (
        tester,
      ) async {
        final repo = FakeAuthRepository()
          ..meMode = '401'
          ..refreshMode = '401';
        final store = MemoryTokenStore();
        await store.writeTokens(access: 'acc', refresh: 'ref');
        final auth = providerWith(repo, store);

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: AuthProvider.navigatorKey,
            initialRoute: '/splash',
            routes: {
              '/splash': (_) => const Scaffold(body: Text('Splash Screen')),
              '/login': (_) => const Scaffold(body: Text('Login Screen')),
            },
          ),
        );
        expect(find.text('Splash Screen'), findsOneWidget);

        await auth.tryRestore();
        await tester.pumpAndSettle();

        // Still on Splash Screen: splash decides route after restore
        expect(find.text('Splash Screen'), findsOneWidget);
        expect(find.text('Login Screen'), findsNothing);
      });
    });
  });
}
