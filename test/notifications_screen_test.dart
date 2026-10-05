import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/notification_repository.dart';
import 'package:wael_app/screens/notifications_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/icon_tile.dart';
import 'package:wael_app/widgets/status_dot.dart';
import 'package:wael_app/widgets/themed_card.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

class _ListRepository implements NotificationRepository {
  _ListRepository(this.items);
  final List<NotificationModel> items;
  final List<String> markedRead = [];

  @override
  List<NotificationModel> initial() => items;

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async =>
      items;

  @override
  Future<void> markRead(String id) async => markedRead.add(id);
}

const _items = [
  NotificationModel(
    id: 'n1',
    title: 'Payment verified',
    titleAr: 'تم التحقق من السداد',
    body: 'Your transfer was approved.',
    bodyAr: 'تم قبول التحويل.',
    timestamp: '25m ago',
    timestampAr: 'منذ ٢٥ دقيقة',
    type: 'payment',
    targetRoute: '/settings',
  ),
  NotificationModel(
    id: 'n2',
    title: 'Seminar today',
    titleAr: 'ندوة اليوم',
    body: 'Live session at 20:00.',
    bodyAr: 'جلسة مباشرة الساعة الثامنة.',
    timestamp: '2h ago',
    timestampAr: 'منذ ساعتين',
    type: 'event',
  ),
];

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';

    Future<void> pump(WidgetTester tester, NotificationsProvider provider) =>
        pumpScreen(
          tester,
          locale,
          const NotificationsScreen(),
          notifications: provider,
        );

    NotificationsProvider withItems() =>
        NotificationsProvider(repository: _ListRepository(List.of(_items)));

    group('NotificationsScreen [$name]', () {
      testWidgets('shell, title with pip and a mark-all-read action', (
        tester,
      ) async {
        await pump(tester, withItems());
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byTooltip(l10n.back), findsOneWidget);
        expect(find.text(l10n.dispatchesTitle.toUpperCase()), findsOneWidget);
        expect(find.text(l10n.markAllRead.toUpperCase()), findsOneWidget);
        expect(find.byType(IconTile), findsNWidgets(2));
        expect(
          find.text(isArabic ? 'تم التحقق من السداد' : 'Payment verified'),
          findsOneWidget,
        );
      });

      testWidgets('header and cards mirror ($direction)', (tester) async {
        await pump(tester, withItems());
        final title = find.text(l10n.dispatchesTitle.toUpperCase());
        // Back button, then the title, then the action at the end edge.
        expect(
          startsBefore(tester, find.byTooltip(l10n.back), title, direction),
          isTrue,
        );
        expect(
          startsBefore(
            tester,
            title,
            find.text(l10n.markAllRead.toUpperCase()),
            direction,
          ),
          isTrue,
        );
        // Inside a card: unread pip, then icon tile, then the title text.
        final card = find
            .ancestor(
              of: find.byType(IconTile).first,
              matching: find.byType(Row),
            )
            .first;
        final pip = find
            .descendant(of: card, matching: find.byType(StatusDot))
            .first;
        final tile = find.descendant(of: card, matching: find.byType(IconTile));
        final cardTitle = find.text(
          isArabic ? 'تم التحقق من السداد' : 'Payment verified',
        );
        expect(startsBefore(tester, pip, tile, direction), isTrue);
        expect(startsBefore(tester, tile, cardTitle, direction), isTrue);
        // The timestamp is at the end of the title row.
        final stamp = find.text(isArabic ? 'منذ ٢٥ دقيقة' : '25m ago');
        expect(startsBefore(tester, cardTitle, stamp, direction), isTrue);
      });

      testWidgets('mark all read clears the unread count', (tester) async {
        final provider = withItems();
        await pump(tester, provider);
        expect(provider.unreadCount, 2);
        await tester.tap(find.text(l10n.markAllRead.toUpperCase()));
        await tester.pump();
        expect(provider.unreadCount, 0);
      });

      testWidgets('tapping a card marks it read and opens its route', (
        tester,
      ) async {
        final repo = _ListRepository(List.of(_items));
        final provider = NotificationsProvider(repository: repo);
        await pump(tester, provider);
        await tester.tap(
          find.text(isArabic ? 'تم التحقق من السداد' : 'Payment verified'),
        );
        await tester.pumpAndSettle();
        expect(provider.unreadCount, 1);
        expect(find.text('route:/settings'), findsOneWidget);
      });

      testWidgets('tapping a subject notification opens its detail', (
        tester,
      ) async {
        const subjectItem = NotificationModel(
          id: 'n-subject',
          title: 'Approved',
          body: 'Your request was approved.',
          timestamp: 'now',
          type: 'course',
          targetRoute: '/notifications',
          arguments: {'subject_id': 'subject-1'},
        );
        final provider = NotificationsProvider(
          repository: _ListRepository(const [subjectItem]),
        );
        await pump(tester, provider);
        await tester.tap(find.text('Approved'));
        await tester.pumpAndSettle();
        expect(provider.unreadCount, 0);
        expect(find.text('route:/course-details:subject-1'), findsOneWidget);
      });

      testWidgets('notification tap gives light haptic feedback', (
        tester,
      ) async {
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
        final provider = withItems();
        await pump(tester, provider);
        await tester.tap(
          find.text(isArabic ? 'تم التحقق من السداد' : 'Payment verified'),
        );
        await tester.pumpAndSettle();
        expect(vibrated, contains('HapticFeedback.vibrate'));
      });

      testWidgets(
        'debug mode: a failed load shows the error state, not sample items',
        (tester) async {
          expect(kDebugMode, isTrue);
          final api = ApiClient(
            baseUrl: 'https://localhost:8080',
            client: MockClient(
              (_) async => http.Response(jsonEncode({'error': 'down'}), 503),
            ),
          );
          final provider = NotificationsProvider()
            ..attachRemote(HttpNotificationRepository(api));
          await provider.loadRemote();

          await pump(tester, provider);
          expect(find.byType(ThemedErrorBanner), findsOneWidget);
          expect(
            find.text(ErrorMessages.notificationLoadFailed(isArabic)),
            findsOneWidget,
          );
          expect(find.byType(ThemedCard), findsNothing);
          expect(find.byType(IconTile), findsNothing);
          for (final sample in [
            'Payment Verified & Enrolment Active',
            'Crisis Communication Seminar',
            'تم التحقق من إشعار السداد وتفعيل الاشتراك',
            'ندوة إدارة الأزمات والخطاب السيادي',
          ]) {
            expect(find.text(sample), findsNothing);
          }
        },
      );

      testWidgets('a default provider shows the empty state, not samples', (
        tester,
      ) async {
        await pump(tester, NotificationsProvider());
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        expect(find.text(l10n.noNotifications), findsOneWidget);
        expect(find.byType(ThemedCard), findsNothing);
      });

      testWidgets('no notifications shows the empty state', (tester) async {
        await pump(
          tester,
          NotificationsProvider(
            repository: const EmptyNotificationRepository(),
          ),
        );
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        expect(find.text(l10n.noNotifications), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('a failed load shows a persistent banner; retry reloads', (
        tester,
      ) async {
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          return http.Response(jsonEncode({'error': 'server down'}), 503);
        });
        final provider =
            NotificationsProvider(
              repository: const EmptyNotificationRepository(),
            )..attachRemote(
              HttpNotificationRepository(
                ApiClient(baseUrl: 'https://localhost:8080', client: client),
              ),
            );
        await provider.loadRemote();
        expect(requests, 1);

        await pump(tester, provider);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(
          find.text(ErrorMessages.notificationLoadFailed(isArabic)),
          findsOneWidget,
        );
        expect(find.byType(ThemedEmptyState), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(requests, 2);
      });
    });
  }
}
