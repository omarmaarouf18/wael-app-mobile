import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import '../core/api_client.dart';
import '../models/notification_model.dart';

/// Live notification stream over the gateway.
///
/// Connect after login with a valid access token; cancel on logout.
/// A stream that cannot connect backs off quietly and retries with fresh tokens:
/// - 401: attempts one token refresh and retries once; if that fails or refresh
///   fails, stops permanently (no infinite loop).
/// - 403: stops permanently (no retry).
/// - 5xx / network error: exponential backoff capped at 30 seconds.
class NotificationStream {
  NotificationStream(
    this._api, {
    Future<String?> Function()? tokenReader,
    Future<bool> Function()? refreshToken,
  }) : _tokenReader = tokenReader ?? _api.accessTokenReader,
       _refreshToken = refreshToken ?? _api.refreshTokens;

  final ApiClient _api;
  final Future<String?> Function()? _tokenReader;
  final Future<bool> Function()? _refreshToken;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _retryTimer;
  bool _stopped = false;
  String? _fallbackToken;

  bool get isActive => _sub != null && !_stopped;
  bool get isStopped => _stopped;

  @visibleForTesting
  static Duration backoffDelay(int attempt) {
    final delaySeconds = attempt < 5 ? (1 << attempt) : 30;
    return Duration(seconds: delaySeconds > 30 ? 30 : delaySeconds);
  }

  Future<void> connect({
    String? token,
    required void Function(NotificationModel) onItem,
  }) async {
    await stop();
    _stopped = false;
    _fallbackToken = token;
    await _listen(onItem: onItem, attempt: 0);
  }

  Future<void> _listen({
    required void Function(NotificationModel) onItem,
    required int attempt,
    bool is401Retry = false,
  }) async {
    if (_stopped) return;
    String? token;
    final reader = _tokenReader;
    if (reader != null) {
      try {
        token = await reader();
      } catch (_) {
        token = null;
      }
    }
    token ??= _fallbackToken;
    if (token == null || token.isEmpty) {
      await stop();
      return;
    }

    try {
      final stream = _api.sse('/api/v1/notifications/stream', token: token);
      _sub = stream.listen(
        (frame) => _handleFrame(frame, onItem),
        onError: (e) => _handleError(
          e,
          onItem: onItem,
          attempt: attempt,
          is401Retry: is401Retry,
        ),
        onDone: () => _handleDone(onItem: onItem, attempt: attempt),
        cancelOnError: false,
      );
    } catch (e) {
      await _handleError(
        e,
        onItem: onItem,
        attempt: attempt,
        is401Retry: is401Retry,
      );
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

  Future<void> _handleError(
    Object error, {
    required void Function(NotificationModel) onItem,
    required int attempt,
    bool is401Retry = false,
  }) async {
    await _sub?.cancel();
    _sub = null;
    if (_stopped) return;

    if (error is ApiException) {
      if (error.statusCode == 403) {
        await stop();
        return;
      }
      if (error.statusCode == 401) {
        final refresh = _refreshToken;
        if (is401Retry || refresh == null) {
          await stop();
          return;
        }
        final refreshed = await refresh();
        if (!refreshed || _stopped) {
          await stop();
          return;
        }
        await _listen(onItem: onItem, attempt: 0, is401Retry: true);
        return;
      }
    }

    _retry(onItem: onItem, attempt: attempt);
  }

  void _handleDone({
    required void Function(NotificationModel) onItem,
    required int attempt,
  }) {
    if (_stopped) return;
    _retry(onItem: onItem, attempt: attempt);
  }

  void _retry({
    required void Function(NotificationModel) onItem,
    required int attempt,
  }) {
    _sub?.cancel();
    _sub = null;
    if (_stopped) return;
    final delay = backoffDelay(attempt);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_stopped) {
        _listen(onItem: onItem, attempt: attempt + 1);
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
