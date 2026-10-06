import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// The student's notifications. Everything here comes from the notification
/// service (list over HTTP, live inserts over SSE); before login, or when a
/// load fails, the list is empty. A failed load never leaves stale or sample
/// items on screen, in debug and release alike.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository})
    : _repository = repository ?? const EmptyNotificationRepository(),
      _notifications = List.of(
        (repository ?? const EmptyNotificationRepository()).initial(),
      );

  NotificationRepository _repository;
  final List<NotificationModel> _notifications;
  bool _remote = false;
  bool _hasError = false;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasError => _hasError;

  /// Binds the real HTTP repository after login.
  void attachRemote(HttpNotificationRepository repository) {
    _repository = repository;
    _remote = true;
  }

  /// Loads the list. On failure the list is cleared and [hasError] is set, so
  /// the screen shows the error state instead of anything stale.
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
      _notifications.clear();
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

  /// Clears in-memory notifications on sign-out / account switch.
  void reset({bool notify = true}) {
    _notifications.clear();
    _repository = const EmptyNotificationRepository();
    _remote = false;
    _hasError = false;
    if (notify) notifyListeners();
  }
}
