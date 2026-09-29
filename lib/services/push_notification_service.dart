import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Push Notification Service Boundary
/// Emulates push notification subscriptions and local notification dispatches in Demo Mode.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final _notificationStreamController =
      StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get onNotificationReceived =>
      _notificationStreamController.stream;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('[PushNotificationService] Initialized in offline demo mode.');
  }

  void dispatchMockNotification(NotificationModel notification) {
    debugPrint(
      '[PushNotificationService] Emitting notification: ${notification.title}',
    );
    _notificationStreamController.add(notification);
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
