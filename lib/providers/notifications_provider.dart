import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository})
    : _repository = repository ?? MockNotificationRepository(),
      _notifications = List.of(
        (repository ?? MockNotificationRepository()).initial(),
      );

  NotificationRepository _repository;
  final List<NotificationModel> _notifications;
  bool _remote = false;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Binds the real HTTP repository after login. Keeps quiet backoff: a
  /// failed first load leaves the bundled list in place.
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
      notifyListeners();
    } catch (_) {
      // Quiet backoff: keep current list until the service is reachable.
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
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
