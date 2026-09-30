import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/notification_repository.dart';

void main() {
  group('NotificationsProvider fallback & deduplication', () {
    test(
      'EmptyNotificationRepository returns empty initial and list',
      () async {
        const repo = EmptyNotificationRepository();
        expect(repo.initial(), isEmpty);
        expect(await repo.list(), isEmpty);
        await repo.markRead('some-id'); // does not throw
      },
    );

    test('deduplicates live notifications by id', () {
      final provider = NotificationsProvider(
        repository: const EmptyNotificationRepository(),
      );
      expect(provider.notifications, isEmpty);

      const item = NotificationModel(
        id: 'notif-100',
        title: 'Welcome',
        titleAr: 'مرحبا',
        body: 'Welcome to Wael Academy',
        bodyAr: 'أهلا بك في أكاديمية وائل',
        timestamp: 'now',
        timestampAr: 'الآن',
        isRead: false,
        type: 'system',
      );

      provider.addNotification(item);
      expect(provider.notifications.length, 1);
      expect(provider.unreadCount, 1);

      // Add identical item again - should be deduplicated
      provider.addNotification(item);
      expect(provider.notifications.length, 1);
    });

    test('loadRemote updates notifications on success', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'notifications': [
              {
                'id': 'remote-1',
                'title': 'Remote Notif',
                'body': 'Body text',
                'read': false,
                'type': 'system',
              },
            ],
            'page': 1,
          }),
          200,
        );
      });
      final api = ApiClient(baseUrl: 'https://localhost:8080', client: mock);
      final repo = HttpNotificationRepository(api);

      final provider = NotificationsProvider(
        repository: const EmptyNotificationRepository(),
      );
      provider.attachRemote(repo);
      await provider.loadRemote();

      expect(provider.hasError, isFalse);
      expect(provider.notifications.length, 1);
      expect(provider.notifications.first.id, 'remote-1');
    });

    test('loadRemote sets hasError on failure', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'error': 'server down'}), 503);
      });
      final api = ApiClient(baseUrl: 'https://localhost:8080', client: mock);
      final repo = HttpNotificationRepository(api);

      final provider = NotificationsProvider(
        repository: const EmptyNotificationRepository(),
      );
      provider.attachRemote(repo);
      await provider.loadRemote();

      expect(provider.hasError, isTrue);
      expect(provider.notifications, isEmpty);
    });
  });
}
