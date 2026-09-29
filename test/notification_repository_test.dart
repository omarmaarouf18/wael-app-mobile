import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/repositories/notification_repository.dart';

ApiClient apiFor(MockClient mock) => ApiClient(
  baseUrl: 'https://localhost:8080',
  client: mock,
  accessTokenReader: () async => 'access-1',
);

void main() {
  test('list parses notifications newest-first', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/api/v1/notifications/list');
      expect(req.headers['Authorization'], 'Bearer access-1');
      return http.Response(
        jsonEncode({
          'notifications': [
            {
              'id': 'n2',
              'title': 'Second',
              'body': 'b2',
              'read': false,
              'type': 'system',
            },
            {
              'id': 'n1',
              'title': 'First',
              'body': 'b1',
              'read': true,
              'type': 'payment',
            },
          ],
          'page': 1,
        }),
        200,
      );
    });
    final repo = HttpNotificationRepository(apiFor(mock));
    final items = await repo.list();
    expect(items.length, 2);
    expect(items.first.id, 'n2');
    expect(items.first.isRead, isFalse);
    expect(items.last.isRead, isTrue);
  });

  test('markRead posts the id', () async {
    String? posted;
    final mock = MockClient((req) async {
      posted = req.body;
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    });
    final repo = HttpNotificationRepository(apiFor(mock));
    await repo.markRead('n9');
    expect(jsonDecode(posted!)['id'], 'n9');
  });

  test('list failure surfaces ApiException for quiet backoff', () async {
    final mock = MockClient((_) async {
      return http.Response(jsonEncode({'error': 'down'}), 503);
    });
    final repo = HttpNotificationRepository(apiFor(mock));
    try {
      await repo.list();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 503);
    }
  });
}
