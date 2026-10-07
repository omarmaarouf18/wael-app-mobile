import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/catalog_cache.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';

import 'fakes.dart';

/// Regression tests for the forced-logout wiring.
///
/// BUG 1: a transient refresh failure (network, 503, timeout, 429) must not
/// log the user out. Only a definitive failure (401/403) or the second-401
/// depth-limit path may trigger [AuthProvider.handleForceLogout].
///
/// BUG 2: [AuthProvider.retryRestore] (offline banner retry, app-resume)
/// must navigate to `/login` when the session turns out revoked.

MockClient _unauthorizedOnce() {
  return MockClient((_) async {
    return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
  });
}

Future<AuthProvider> _loggedInAuth(
  FakeAuthRepository repo,
  MemoryTokenStore store,
) async {
  final auth = AuthProvider(
    repository: repo,
    tokenStore: store,
    catalogCache: MemoryCatalogCache(),
  );
  expect(await auth.login('u@e.com', 'password123'), isTrue);
  expect(auth.isAuthenticated, isTrue);
  return auth;
}

void main() {
  group('BUG 1: transient refresh failure keeps the session (no logout)', () {
    for (final mode in ['network', '503', 'timeout', '429']) {
      testWidgets('refresh $mode -> tokens kept, stays home, 401 surfaces', (
        tester,
      ) async {
        final store = MemoryTokenStore();
        final repo = FakeAuthRepository()..refreshMode = mode;
        final auth = await _loggedInAuth(repo, store);

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

        final api = ApiClient(
          baseUrl: 'https://localhost:8080',
          client: _unauthorizedOnce(),
          accessTokenReader: store.readAccessToken,
          refreshTokens: () => auth.doRefresh(),
          refreshWithOutcome: () => auth.doRefreshWithOutcome(),
          forceLogout: () => auth.handleForceLogout(),
        );

        try {
          await api.get('/api/v1/auth/me');
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.statusCode, 401);
        }

        expect(await store.readAccessToken(), 'access-1', reason: mode);
        expect(await store.readRefreshToken(), 'refresh-1', reason: mode);
        expect(auth.isAuthenticated, isTrue, reason: mode);
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget, reason: mode);
        expect(find.text('Login Screen'), findsNothing, reason: mode);
        expect(loginBuilds, 0, reason: mode);
      });
    }
  });

  group('BUG 1: definitive refresh failure still logs out once', () {
    for (final mode in ['401', '403']) {
      testWidgets('refresh $mode -> tokens cleared, goes to /login once', (
        tester,
      ) async {
        final store = MemoryTokenStore();
        final repo = FakeAuthRepository()..refreshMode = mode;
        final auth = await _loggedInAuth(repo, store);

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

        final api = ApiClient(
          baseUrl: 'https://localhost:8080',
          client: _unauthorizedOnce(),
          accessTokenReader: store.readAccessToken,
          refreshTokens: () => auth.doRefresh(),
          refreshWithOutcome: () => auth.doRefreshWithOutcome(),
          forceLogout: () => auth.handleForceLogout(),
        );

        try {
          await api.get('/api/v1/auth/me');
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.statusCode, 401);
        }

        expect(await store.readAccessToken(), isNull, reason: mode);
        expect(await store.readRefreshToken(), isNull, reason: mode);
        expect(auth.isAuthenticated, isFalse, reason: mode);
        await tester.pumpAndSettle();
        expect(find.text('Login Screen'), findsOneWidget, reason: mode);
        expect(find.text('Home'), findsNothing, reason: mode);
        expect(loginBuilds, 1, reason: mode);
      });
    }

    testWidgets('second-401 depth limit still forces logout (enum path)', (
      tester,
    ) async {
      final store = MemoryTokenStore();
      final repo = FakeAuthRepository()..refreshMode = 'ok';
      final auth = await _loggedInAuth(repo, store);

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

      var refreshCalls = 0;
      final api = ApiClient(
        baseUrl: 'https://localhost:8080',
        client: MockClient((_) async {
          return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
        }),
        accessTokenReader: store.readAccessToken,
        refreshWithOutcome: () async {
          refreshCalls++;
          return RefreshOutcome.success;
        },
        forceLogout: () => auth.handleForceLogout(),
      );

      try {
        await api.get('/api/v1/auth/me');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(refreshCalls, 1);
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);
      expect(loginBuilds, 1);
    });
  });

  group('BUG 2: retryRestore leaves the shell on a revoked session', () {
    testWidgets('offline -> retry with refresh 401 navigates to /login once', (
      tester,
    ) async {
      final store = MemoryTokenStore();
      final repo = FakeAuthRepository()..meMode = 'network';
      await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
      final auth = AuthProvider(
        repository: repo,
        tokenStore: store,
        catalogCache: MemoryCatalogCache(),
      );

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

      // Enter the offline branch (kept tokens, authenticated, banner).
      await auth.tryRestore();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isOffline, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(loginBuilds, 0);

      // The session is revoked while offline: /me 401, refresh 401.
      repo
        ..meMode = '401'
        ..refreshMode = '401';
      await auth.retryRestore();
      await tester.pumpAndSettle();

      expect(auth.isAuthenticated, isFalse);
      expect(await store.readAccessToken(), isNull);
      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(loginBuilds, 1);
    });
  });
}
