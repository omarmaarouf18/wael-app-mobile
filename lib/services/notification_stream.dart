import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../core/api_client.dart';
import '../models/notification_model.dart';

/// Live notification stream over the gateway.
///
/// Connect after login with a valid access token; cancel on logout.
/// A stream that cannot connect (service down, 404, connection refused) backs
/// off quietly and retries; nothing is shown in its place, and the list screen
/// reports its own load failures.
class NotificationStream {
  NotificationStream(this._api);

  final ApiClient _api;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _retryTimer;
  bool _stopped = false;

  bool get isActive => _sub != null;

  Future<void> connect({
    required String token,
    required void Function(NotificationModel) onItem,
  }) async {
    await stop();
    _stopped = false;
    _listen(token: token, onItem: onItem, attempt: 0);
  }

  Future<void> _listen({
    required String token,
    required void Function(NotificationModel) onItem,
    required int attempt,
  }) async {
    if (_stopped) return;
    try {
      final stream = _api.sse('/api/v1/notifications/stream', token: token);
      _sub = stream.listen(
        (frame) => _handleFrame(frame, onItem),
        onError: (_) => _retry(token: token, onItem: onItem, attempt: attempt),
        onDone: () => _retry(token: token, onItem: onItem, attempt: attempt),
        cancelOnError: false,
      );
    } catch (_) {
      _retry(token: token, onItem: onItem, attempt: attempt);
    }
  }

  void _handleFrame(
    Map<String, dynamic> frame,
    void Function(NotificationModel) onItem,
  ) {
    try {
      final id =
          (frame['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
              .toString();
      final title = (frame['title'] ?? 'New notification').toString();
      onItem(
        NotificationModel(
          id: id,
          title: title,
          titleAr: (frame['title_ar'] ?? title).toString(),
          body: (frame['body'] ?? '').toString(),
          bodyAr: (frame['body_ar'] ?? '').toString(),
          timestamp: 'now',
          timestampAr: 'الآن',
          isRead: false,
          type: (frame['type'] ?? 'system').toString(),
          targetRoute: (frame['target_route'] ?? '/notifications').toString(),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationStream] bad frame: $e');
    }
  }

  Future<void> _retry({
    required String token,
    required void Function(NotificationModel) onItem,
    required int attempt,
  }) async {
    await _sub?.cancel();
    _sub = null;
    if (_stopped) return;
    final delay = Duration(seconds: attempt < 4 ? (1 << attempt) : 30);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_stopped) {
        _listen(token: token, onItem: onItem, attempt: attempt + 1);
      }
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _sub?.cancel();
    _sub = null;
  }
}
