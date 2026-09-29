import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository})
    : _notifications = List.of(
        (repository ?? MockNotificationRepository()).initial(),
      );

  final List<NotificationModel> _notifications;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
