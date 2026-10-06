import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/services/notification_stream.dart';

void main() {
  group('NotificationStream', () {
    test('backoff formula caps at 30 seconds', () {
      expect(NotificationStream.backoffDelay(0), const Duration(seconds: 1));
      expect(NotificationStream.backoffDelay(1), const Duration(seconds: 2));
      expect(NotificationStream.backoffDelay(2), const Duration(seconds: 4));
      expect(NotificationStream.backoffDelay(3), const Duration(seconds: 8));
      expect(NotificationStream.backoffDelay(4), const Duration(seconds: 16));
      expect(NotificationStream.backoffDelay(5), const Duration(seconds: 30));
      expect(NotificationStream.backoffDelay(10), const Duration(seconds: 30));
    });

    test('reads fresh token on initial connect and delivers frames', () async {
      int tokenReads = 0;
      final mock = MockClient.streaming((req, bodyStream) async {
        expect(req.headers['Authorization'], 'Bearer token-1');
        return http.StreamedResponse(
          Stream.fromIterable([
            'data: {"id":"1","title":"Hello","body":"World"}\n\n'.codeUnits,
          ]),
          200,
        );
      });
      final api = ApiClient(baseUrl: 'https://test', client: mock);
      final received = <NotificationModel>[];
      final stream = NotificationStream(
        api,
        tokenReader: () async {
          tokenReads++;
          return 'token-1';
        },
      );

      await stream.connect(onItem: received.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tokenReads, 1);
      expect(received.length, 1);
      expect(received.first.title, 'Hello');
      await stream.stop();
    });

    test('403 stops permanently with no retry loop', () async {
      int sendCalls = 0;
      final mock = MockClient.streaming((req, bodyStream) async {
        sendCalls++;
        return http.StreamedResponse(const Stream.empty(), 403);
      });
      final api = ApiClient(baseUrl: 'https://test', client: mock);
      final stream = NotificationStream(
        api,
        tokenReader: () async => 'forbidden-token',
      );

      await stream.connect(onItem: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sendCalls, 1);
      expect(stream.isStopped, isTrue);
      expect(stream.isActive, isFalse);
      await stream.stop();
    });

    test('401 refreshes once and retries with newly obtained token', () async {
      int sendCalls = 0;
      int refreshCalls = 0;
      String currentToken = 'stale-token';

      final mock = MockClient.streaming((req, bodyStream) async {
        sendCalls++;
        if (req.headers['Authorization'] == 'Bearer stale-token') {
          return http.StreamedResponse(const Stream.empty(), 401);
        }
        expect(req.headers['Authorization'], 'Bearer fresh-token');
        return http.StreamedResponse(
          Stream.fromIterable([
            'data: {"id":"2","title":"Refreshed","body":"Item"}\n\n'.codeUnits,
          ]),
          200,
        );
      });
      final api = ApiClient(baseUrl: 'https://test', client: mock);
      final received = <NotificationModel>[];
      final stream = NotificationStream(
        api,
        tokenReader: () async => currentToken,
        refreshToken: () async {
          refreshCalls++;
          currentToken = 'fresh-token';
          return true;
        },
      );

      await stream.connect(onItem: received.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sendCalls, 2);
      expect(refreshCalls, 1);
      expect(received.length, 1);
      expect(received.first.title, 'Refreshed');
      await stream.stop();
    });

    test('401 when refresh fails stops permanently', () async {
      int sendCalls = 0;
      int refreshCalls = 0;

      final mock = MockClient.streaming((req, bodyStream) async {
        sendCalls++;
        return http.StreamedResponse(const Stream.empty(), 401);
      });
      final api = ApiClient(baseUrl: 'https://test', client: mock);
      final stream = NotificationStream(
        api,
        tokenReader: () async => 'bad-token',
        refreshToken: () async {
          refreshCalls++;
          return false;
        },
      );

      await stream.connect(onItem: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sendCalls, 1);
      expect(refreshCalls, 1);
      expect(stream.isStopped, isTrue);
      await stream.stop();
    });

    test(
      '401 second failure after successful refresh stops permanently',
      () async {
        int sendCalls = 0;
        int refreshCalls = 0;

        final mock = MockClient.streaming((req, bodyStream) async {
          sendCalls++;
          // Both initial and retried request fail with 401
          return http.StreamedResponse(const Stream.empty(), 401);
        });
        final api = ApiClient(baseUrl: 'https://test', client: mock);
        final stream = NotificationStream(
          api,
          tokenReader: () async => 'token',
          refreshToken: () async {
            refreshCalls++;
            return true;
          },
        );

        await stream.connect(onItem: (_) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Initial 401 + 1 retry = 2 send calls
        expect(sendCalls, 2);
        expect(refreshCalls, 1);
        expect(stream.isStopped, isTrue);
        await stream.stop();
      },
    );

    test('calling stop() cancels active subscription', () async {
      final mock = MockClient.streaming((req, bodyStream) async {
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      final api = ApiClient(baseUrl: 'https://test', client: mock);
      final stream = NotificationStream(api, tokenReader: () async => 'tok');

      await stream.connect(onItem: (_) {});
      expect(stream.isStopped, isFalse);
      await stream.stop();
      expect(stream.isStopped, isTrue);
      expect(stream.isActive, isFalse);
    });
  });
}
