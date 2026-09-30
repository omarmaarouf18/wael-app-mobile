import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode;
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository})
    : _repository = repository ?? _defaultRepository(),
      _notifications = List.of((repository ?? _defaultRepository()).initial());

  static NotificationRepository _defaultRepository() {
    return kDebugMode
        ? MockNotificationRepository()
        : const EmptyNotificationRepository();
  }

  NotificationRepository _repository;
  final List<NotificationModel> _notifications;
  bool _remote = false;
  bool _hasError = false;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasError => _hasError;

  /// Binds the real HTTP repository after login. Keeps quiet backoff: a
  /// failed first load leaves the bundled list in place (in debug only).
  void attachRemote(HttpNotificationRepository repository) {
    _repository = repository;
    _remote = true;
  }

  Future<void> loadRemote() async {
    if (!_remote) return;
    try {
      final items = await _repository.list();
      _notifications
        ..clear()
        ..addAll(items);
      _hasError = false;
      notifyListeners();
    } catch (_) {
      // In release, a failed load shows an error or empty state, never fake items.
      if (!kDebugMode) {
        _notifications.clear();
      }
      _hasError = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (!n.isRead) {
        _notifications[i] = n.copyWith(isRead: true);
        if (_remote) {
          _repository.markRead(n.id).catchError((_) {});
        }
      }
    }
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      if (_remote) {
        _repository.markRead(id).catchError((_) {});
      }
      notifyListeners();
    }
  }

  void addNotification(NotificationModel notification) {
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
