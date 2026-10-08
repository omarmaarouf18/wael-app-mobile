import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/notification_time.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/notification_repository.dart';
import 'package:wael_app/screens/notifications_screen.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

class _FixedListRepository implements NotificationRepository {
  _FixedListRepository(this.items);
  final List<NotificationModel> items;

  @override
  List<NotificationModel> initial() => items;

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async =>
      items;

  @override
  Future<void> markRead(String id) async {}
}

void main() {
  group('formatNotificationTime boundaries', () {
    // October is daylight-saving time in Cairo (UTC+3).
    final octNow = DateTime.utc(2026, 10, 8, 12, 0, 0);
    String at(Duration d, {required bool ar, DateTime? clock}) =>
        formatNotificationTime(
          (clock ?? octNow).subtract(d).toIso8601String(),
          isArabic: ar,
          clock: clock ?? octNow,
        );

    test('59 seconds renders as now', () {
      expect(at(const Duration(seconds: 59), ar: true), 'الآن');
      expect(at(const Duration(seconds: 59), ar: false), 'Just now');
    });

    test('minutes use singular, dual and plural forms', () {
      expect(at(const Duration(minutes: 1), ar: true), 'منذ دقيقة');
      expect(at(const Duration(minutes: 1), ar: false), '1 minute ago');
      expect(at(const Duration(minutes: 2), ar: true), 'منذ دقيقتين');
      expect(at(const Duration(minutes: 5), ar: true), 'منذ ٥ دقائق');
      expect(at(const Duration(minutes: 5), ar: false), '5 minutes ago');
    });

    test('59 minutes renders with the 11+ singular', () {
      expect(at(const Duration(minutes: 59), ar: true), 'منذ ٥٩ دقيقة');
      expect(at(const Duration(minutes: 59), ar: false), '59 minutes ago');
    });

    test('hours use singular, dual and plural forms', () {
      expect(at(const Duration(hours: 1), ar: true), 'منذ ساعة');
      expect(at(const Duration(hours: 1), ar: false), '1 hour ago');
      expect(at(const Duration(hours: 2), ar: true), 'منذ ساعتين');
      expect(at(const Duration(hours: 2), ar: false), '2 hours ago');
      expect(at(const Duration(hours: 5), ar: true), 'منذ ٥ ساعات');
    });

    test('23 hours still renders relative, not yesterday', () {
      expect(at(const Duration(hours: 23), ar: true), 'منذ ٢٣ ساعة');
      expect(at(const Duration(hours: 23), ar: false), '23 hours ago');
    });

    test('yesterday renders أمس / Yesterday', () {
      expect(
        formatNotificationTime(
          '2026-10-07T10:00:00Z',
          isArabic: true,
          clock: octNow,
        ),
        'أمس',
      );
      expect(
        formatNotificationTime(
          '2026-10-07T10:00:00Z',
          isArabic: false,
          clock: octNow,
        ),
        'Yesterday',
      );
    });

    test('last year renders the full date', () {
      expect(
        formatNotificationTime(
          '2025-05-01T10:00:00Z',
          isArabic: true,
          clock: octNow,
        ),
        '١ مايو ٢٠٢٥، ١:٠٠ م',
      );
      expect(
        formatNotificationTime(
          '2025-05-01T10:00:00Z',
          isArabic: false,
          clock: octNow,
        ),
        '1 May 2025, 1:00 PM',
      );
    });

    test('matches the approved example shapes exactly', () {
      const lateOctober = '2026-10-20T00:00:00Z';
      final lateClock = DateTime.parse(lateOctober);
      expect(
        formatNotificationTime(
          '2026-10-08T12:40:00Z',
          isArabic: true,
          clock: lateClock,
        ),
        '٨ أكتوبر ٢٠٢٦، ٣:٤٠ م',
      );
      expect(
        formatNotificationTime(
          '2026-10-08T12:40:00Z',
          isArabic: false,
          clock: lateClock,
        ),
        '8 Oct 2026, 3:40 PM',
      );
    });

    test('future times and garbage fall back safely', () {
      expect(
        formatNotificationTime(
          '2026-10-08T13:00:00Z',
          isArabic: true,
          clock: octNow,
        ),
        'الآن',
      );
      expect(
        formatNotificationTime('25m ago', isArabic: true, clock: octNow),
        '25m ago',
      );
      expect(formatNotificationTime('', isArabic: false, clock: octNow), '');
      expect(
        formatNotificationTime(':::not-a-date:::', isArabic: true),
        ':::not-a-date:::',
      );
    });
  });

  group('cairoOffsetHours', () {
    test('standard time outside daylight saving', () {
      expect(cairoOffsetHours(DateTime.utc(2026, 1, 15)), 2);
      expect(cairoOffsetHours(DateTime.utc(2026, 12, 15)), 2);
    });

    test('daylight saving inside the window', () {
      expect(cairoOffsetHours(DateTime.utc(2026, 7, 15)), 3);
      expect(cairoOffsetHours(DateTime.utc(2026, 10, 8, 12)), 3);
    });

    test('switch moments in 2026 (last Fri of April, last Thu of Oct)', () {
      // DST starts 2026-04-24 00:00 +02:00 == 2026-04-23 22:00Z.
      expect(cairoOffsetHours(DateTime.utc(2026, 4, 23, 21, 59)), 2);
      expect(cairoOffsetHours(DateTime.utc(2026, 4, 23, 22, 0)), 3);
      // DST ends 2026-10-29 24:00 +03:00 == 2026-10-29 21:00Z.
      expect(cairoOffsetHours(DateTime.utc(2026, 10, 29, 20, 59)), 3);
      expect(cairoOffsetHours(DateTime.utc(2026, 10, 29, 21, 0)), 2);
    });
  });

  group('ensureNotificationTimeInitialized', () {
    test('is safe to call again', () async {
      await ensureNotificationTimeInitialized();
      await ensureNotificationTimeInitialized();
    });
  });

  for (final (name, locale, _) in kLocales) {
    final isArabic = locale.languageCode == 'ar';

    group('notification times on screen [$name]', () {
      NotificationModel item(String id, String timestamp) => NotificationModel(
        id: id,
        title: 'Title $id',
        body: 'Body $id',
        timestamp: timestamp,
        type: 'course',
      );

      Future<void> pumpWithStamps(
        WidgetTester tester,
        List<String> stamps,
      ) async {
        final provider = NotificationsProvider(
          repository: _FixedListRepository([
            for (var i = 0; i < stamps.length; i++) item('n$i', stamps[i]),
          ]),
        );
        await pumpScreen(
          tester,
          locale,
          const NotificationsScreen(),
          notifications: provider,
        );
      }

      testWidgets('recent, dated and unparsable times render', (tester) async {
        final now = DateTime.now().toUtc();
        await pumpWithStamps(tester, [
          now.subtract(const Duration(seconds: 30)).toIso8601String(),
          '2020-06-15T10:00:00Z',
          'not-a-time',
        ]);
        expect(find.text(isArabic ? 'الآن' : 'Just now'), findsOneWidget);
        expect(
          find.text(
            isArabic ? '١٥ يونيو ٢٠٢٠، ١:٠٠ م' : '15 Jun 2020, 1:00 PM',
          ),
          findsOneWidget,
        );
        expect(find.text('not-a-time'), findsOneWidget);
      });
    });
  }
}
