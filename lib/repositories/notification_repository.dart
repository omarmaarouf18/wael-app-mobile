import '../core/api_client.dart';
import '../models/notification_model.dart';

/// Notification data contract.
///
/// [MockNotificationRepository] serves the bundled list (offline / service
/// not yet shipped). [HttpNotificationRepository] talks to the gateway
/// (`/api/v1/notifications/*`). Swapping bindings is one construction site
/// in [NotificationsProvider].
abstract class NotificationRepository {
  List<NotificationModel> initial();
  Future<List<NotificationModel>> list({int page = 1, int limit = 20});
  Future<void> markRead(String id);
}

NotificationModel _fromJson(Map<String, dynamic> json) {
  final title = (json['title'] ?? '').toString();
  return NotificationModel(
    id: (json['id'] ?? '').toString(),
    title: title,
    titleAr: (json['title_ar'] ?? title).toString(),
    body: (json['body'] ?? '').toString(),
    bodyAr: (json['body_ar'] ?? '').toString(),
    timestamp: (json['created_at'] ?? '').toString(),
    timestampAr: (json['created_at'] ?? '').toString(),
    isRead: json['read'] == true,
    type: (json['type'] ?? 'system').toString(),
    targetRoute: (json['target_route'] ?? '/notifications').toString(),
  );
}

/// Bundled mock used until the notification-service ships list/send APIs.
/// Live inserts still arrive via the SSE stream after login.
class MockNotificationRepository implements NotificationRepository {
  final List<NotificationModel> _items = const [
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

  @override
  List<NotificationModel> initial() => List.of(_items);

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async =>
      List.of(_items);

  @override
  Future<void> markRead(String id) async {}
}

/// HTTP binding against the gateway notification routes.
class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository(this._api);

  final ApiClient _api;

  @override
  List<NotificationModel> initial() => const [];

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async {
    final res = await _api.get(
      '/api/v1/notifications/list?page=$page&limit=$limit',
    );
    final raw = res['notifications'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(_fromJson).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _api.post('/api/v1/notifications/read', body: {'id': id});
  }
}

/// Empty fallback repository used in release builds or when no notifications exist.
class EmptyNotificationRepository implements NotificationRepository {
  const EmptyNotificationRepository();

  @override
  List<NotificationModel> initial() => const [];

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async =>
      const [];

  @override
  Future<void> markRead(String id) async {}
}
