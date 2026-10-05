import '../core/api_client.dart';
import '../models/notification_model.dart';

/// Notification data contract.
///
/// [HttpNotificationRepository] talks to the gateway
/// (`/api/v1/notifications/*`). [EmptyNotificationRepository] is the binding
/// before login (and in tests): it has nothing and never invents anything.
/// Swapping bindings is one construction site in [NotificationsProvider].
abstract class NotificationRepository {
  List<NotificationModel> initial();
  Future<List<NotificationModel>> list({int page = 1, int limit = 20});
  Future<void> markRead(String id);
}

NotificationModel _fromJson(Map<String, dynamic> json) {
  final title = (json['title'] ?? '').toString();
  // The backend sends no subject id today; parsed defensively so subject
  // notifications deep-link once it does (see Backend follow-ups).
  final subjectId = json['subject_id']?.toString();
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
    arguments: subjectId != null && subjectId.isNotEmpty
        ? {'subject_id': subjectId}
        : null,
  );
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

/// Repository with no notifications: used before the session is bound.
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
