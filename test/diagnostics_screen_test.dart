import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/debug/diagnostics_screen.dart';
import 'package:wael_app/debug/diagnostics_tracker.dart';
import 'package:wael_app/providers/auth_provider.dart';

import 'fakes.dart';

void main() {
  group('DiagnosticsTracker', () {
    setUp(() {
      DiagnosticsTracker.instance.clear();
    });

    test('strips query strings and does not store bodies or tokens', () {
      DiagnosticsTracker.instance.recordCall(
        method: 'GET',
        path: '/api/v1/notifications/list?page=1&limit=20',
        status: 200,
        latencyMs: 35,
      );

      final calls = DiagnosticsTracker.instance.calls;
      expect(calls.length, 1);
      expect(calls.first.method, 'GET');
      expect(calls.first.path, '/api/v1/notifications/list');
      expect(calls.first.status, 200);
      expect(calls.first.latencyMs, 35);
    });

    test('keeps only the last 50 calls in circular buffer', () {
      for (int i = 0; i < 60; i++) {
        DiagnosticsTracker.instance.recordCall(
          method: 'GET',
          path: '/api/v1/call/$i',
          status: 200,
          latencyMs: i,
        );
      }

      final calls = DiagnosticsTracker.instance.calls;
      expect(calls.length, 50);
      expect(calls.first.path, '/api/v1/call/59');
      expect(calls.last.path, '/api/v1/call/10');
    });

    test('masks token to first 6 chars + ellipsis', () {
      expect(
        DiagnosticsTracker.maskToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'),
        'eyJhbG...',
      );
      expect(DiagnosticsTracker.maskToken(''), 'none');
      expect(DiagnosticsTracker.maskToken(null), 'none');
      expect(DiagnosticsTracker.maskToken('123'), '***');
    });

    test('tracks and updates SSE state', () {
      expect(DiagnosticsTracker.instance.sseState, 'disconnected');
      DiagnosticsTracker.instance.updateSseState('connected');
      expect(DiagnosticsTracker.instance.sseState, 'connected');
    });
  });

  group('DiagnosticsScreen Widget', () {
    setUp(() {
      DiagnosticsTracker.instance.clear();
    });

    testWidgets('asserts diagnostics is absent in release mode', (
      WidgetTester tester,
    ) async {
      final store = MemoryTokenStore();
      final auth = AuthProvider(
        repository: FakeAuthRepository(),
        tokenStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const DiagnosticsScreen(debugModeOverride: false),
          ),
        ),
      );

      // In release mode (debugModeOverride: false), screen is completely absent.
      expect(find.text('Diagnostics (Debug Only)'), findsNothing);
      expect(find.text('Base URL'), findsNothing);
      expect(find.text('Recent API Calls'), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('displays diagnostics data in debug mode', (
      WidgetTester tester,
    ) async {
      DiagnosticsTracker.instance.recordCall(
        method: 'POST',
        path: '/api/v1/auth/login?client=test',
        status: 200,
        latencyMs: 48,
      );
      DiagnosticsTracker.instance.updateSseState('connected');

      final store = MemoryTokenStore();
      final auth = AuthProvider(
        repository: FakeAuthRepository(),
        tokenStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const DiagnosticsScreen(debugModeOverride: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics (Debug Only)'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('SSE Stream State'), findsOneWidget);
      expect(find.text('connected'), findsOneWidget);
      expect(find.textContaining('Recent API Calls'), findsOneWidget);
      expect(find.text('/api/v1/auth/login'), findsOneWidget);
      expect(find.text('48ms'), findsOneWidget);
      expect(find.text('POST'), findsOneWidget);
    });
  });
}
