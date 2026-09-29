import '../models/notification_model.dart';

/// Notification data contract. The mock below serves the current bundled
/// list; swapping in the real notification-service later means replacing the
/// single construction site in [NotificationsProvider] (one file).
abstract class NotificationRepository {
  List<NotificationModel> initial();
}

/// Bundled mock used until the notification-service ships list/send APIs.
/// Live inserts still arrive via the SSE stream after login (see
/// `NotificationStream`), which calls `addNotification` on the provider.
class MockNotificationRepository implements NotificationRepository {
  @override
  List<NotificationModel> initial() => const [
    NotificationModel(
      id: 'notif-1',
      title: 'Payment Verified & Enrolment Active',
      titleAr: 'تم التحقق من إشعار السداد وتفعيل الاشتراك',
      body:
          'Your transfer has been approved by the office. Full syllabus unlocked.',
      bodyAr:
          'تم قبول إشعار السداد من قِبل إدارة الأكاديمية. تم فتح المحتوى كاملاً.',
      timestamp: '25m ago',
      timestampAr: 'منذ ٢٥ دقيقة',
      isRead: false,
      type: 'payment',
      targetRoute: '/courses',
    ),
    NotificationModel(
      id: 'notif-2',
      title: 'Crisis Communication Seminar',
      titleAr: 'ندوة إدارة الأزمات والخطاب السيادي',
      body: 'Live closed-door session commences today at 20:00 GMT.',
      bodyAr: 'تنطلق الجلسة المغلقة الحية اليوم في تمام الساعة الثامنة مساءً.',
      timestamp: '2h ago',
      timestampAr: 'منذ ساعتين',
      isRead: false,
      type: 'event',
      targetRoute: '/home',
    ),
  ];
}
